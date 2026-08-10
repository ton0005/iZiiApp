# server/event_engine.py
"""
iZiiServer Real-Time Event & Webhook Engine (Track 4 / Event Reaction Architecture).

Features:
1. Maps SQLite database table mutations to structured Domain Events.
2. Broadcasts real-time `event_reaction` payloads via WebSockets to connected client apps.
3. Dispatches HTTP POST Webhooks to external endpoints (CRM/Odoo, Costa internal LAN services, Email triggers).
4. Persists Webhook subscriptions in SQLite database.
"""

import json
import uuid
import asyncio
import fnmatch
import httpx
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional, Sequence, Tuple

from server_config import CONFIG


# ══════════════════════════════════════════════════════════════════════════════
#  Shared HTTP client
# ══════════════════════════════════════════════════════════════════════════════
# Trước đây mỗi event tạo một httpx.AsyncClient riêng (mở/đóng connection pool
# liên tục). Giờ dùng chung 1 client cho cả tiến trình, đóng lại trong
# lifespan() shutdown của app.py qua close_http_client().

_http_client: Optional[httpx.AsyncClient] = None


def get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(timeout=5.0)
    return _http_client


async def close_http_client() -> None:
    global _http_client
    if _http_client is not None and not _http_client.is_closed:
        await _http_client.aclose()
    _http_client = None


# Kiểu dữ liệu 1 dòng webhook_subscriptions đã được đọc sẵn ra khỏi DB:
#   (id, url, event_filter, secret_token)
WebhookRow = Tuple[str, str, str, str]

# Phiên bản của LỚP BỌC sự kiện (các trường event_id/event_type/source/...).
# Khác với `schema_version` vốn nói về cấu trúc bên trong trường `data`.
# Tăng số này khi thay đổi chính cấu trúc envelope.
ENVELOPE_VERSION = 1


class iZiiEventEngine:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(iZiiEventEngine, cls).__new__(cls)
        return cls._instance

    @staticmethod
    def map_mutation_to_domain_event(table: str, operation: str, data: Dict[str, Any]) -> str:
        """
        Maps a database mutation to a high-level Domain Event type.
        """
        op = (operation or "insert").lower()
        
        mapping = {
            "mushroom_jobs": "mushroom.job_added" if op in ("insert", "create") else "mushroom.job_updated",
            "mushroom_employees": "organization.employee_created" if op in ("insert", "create") else "organization.employee_updated",
            "mushroom_departments": "organization.department_created",
            "purchase_orders": "purchase.order_created",
            "purchase_order_lines": "purchase.order_line_updated",
            "contacts": "customer.registered",
            "leads": "customer.lead_created",
            "deals": "sales.deal_updated",
            "chat_messages": "chat.message_sent",
            "service_bookings": "service.booking_created",
            "service_items": "service.item_created",
            "accounts": "financial.account_updated",
            "journal_entries": "financial.journal_posted",
        }
        
        return mapping.get(table, f"{table}.{op}")

    @staticmethod
    def _record_dead_letter(url: str, payload: Dict[str, Any], last_error: str, attempts: int) -> None:
        """
        Lưu event đã thất bại sau khi hết số lần retry vào bảng
        webhook_dead_letters để không mất dấu — có thể replay thủ công sau.
        Bọc try/except toàn bộ: ghi dead-letter thất bại KHÔNG được phép làm
        hỏng luồng dispatch.
        """
        try:
            from database import sql
            from dependencies import open_connection
            with open_connection() as conn:
                conn.execute(
                    sql("""
                    INSERT INTO webhook_dead_letters
                        (id, url, event_id, event_type, payload, last_error, attempts, failed_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """),
                    (
                        f"dl_{uuid.uuid4().hex[:12]}",
                        url,
                        payload.get("event_id"),
                        payload.get("event_type"),
                        json.dumps(payload),
                        last_error[:500],
                        attempts,
                        datetime.now(timezone.utc).isoformat(),
                    ),
                )
                conn.commit()
            print(f"💀 [WEBHOOK] Đã ghi dead-letter cho {url} (event {payload.get('event_id')}).")
        except Exception as e:
            print(f"⚠️ [WEBHOOK] Không ghi được dead-letter cho {url}: {e}")

    async def _send_webhook_http_post(
        self, client: httpx.AsyncClient, url: str, secret_token: str, payload: Dict[str, Any], retries: int = 3
    ) -> None:
        """
        Asynchronously sends an HTTP POST request to an external Webhook URL with retry logic.
        Hết `retries` lần mà vẫn hỏng thì ghi vào dead-letter queue.
        """
        headers = {
            "Content-Type": "application/json",
            "User-Agent": "iZiiServer-EventEngine/2.0",
        }
        if secret_token:
            headers["X-iZii-Secret-Token"] = secret_token

        last_error = "unknown"
        for attempt in range(1, retries + 1):
            try:
                resp = await client.post(url, json=payload, headers=headers, timeout=5.0)
                if resp.status_code < 400:
                    print(f"🌐 [WEBHOOK] Pushed {payload.get('event_type')} to {url} (HTTP {resp.status_code})")
                    return
                else:
                    last_error = f"HTTP {resp.status_code}"
                    print(f"⚠️ [WEBHOOK] HTTP {resp.status_code} from {url} (Attempt {attempt}/{retries})")
            except Exception as e:
                last_error = f"{type(e).__name__}: {e}"
                print(f"⚠️ [WEBHOOK] Failed to push event to {url} (Attempt {attempt}/{retries}): {e}")

            if attempt < retries:
                await asyncio.sleep(0.5 * (2 ** (attempt - 1)))

        # Hết retry -> đưa vào dead-letter queue thay vì mất im lặng.
        await asyncio.to_thread(self._record_dead_letter, url, payload, last_error, retries)

    @staticmethod
    def fetch_webhook_rows(conn: Optional[Any] = None) -> List[WebhookRow]:
        """
        Đọc danh sách webhook đang active và trả về dưới dạng list tuple THUẦN
        (đã tách khỏi connection).

        Vì sao phải tách: `dispatch_event` chạy trong background task, tức là
        SAU khi request đã kết thúc và connection do FastAPI dependency cấp
        (dependencies.get_db) đã bị `conn.close()`. Truyền thẳng connection vào
        task nền sẽ gây `sqlite3.ProgrammingError: Cannot operate on a closed
        database` một cách ngẫu nhiên (race với thời điểm response trả về).

        Cách đúng: gọi hàm này MỘT LẦN trong handler khi connection còn sống,
        rồi truyền kết quả (dữ liệu) vào dispatch_event. Vừa hết lỗi, vừa giảm
        từ N lần đọc bảng (N = số mutation) xuống còn 1 lần cho cả batch.
        """
        query = "SELECT id, url, event_filter, secret_token FROM webhook_subscriptions WHERE is_active = 1"
        try:
            if conn is not None:
                rows = conn.execute(query).fetchall()
            else:
                from dependencies import open_connection
                with open_connection() as own:
                    rows = own.execute(query).fetchall()
            # Truy cập theo TÊN CỘT chứ không theo chỉ số: sqlite3.Row hỗ trợ cả
            # hai, nhưng psycopg dict_row chỉ hỗ trợ tên. Dùng tên là cách duy
            # nhất chạy được trên cả hai backend.
            return [
                (r["id"], r["url"], r["event_filter"], r["secret_token"])
                for r in rows
            ]
        except Exception as e:
            print(f"⚠️ [EVENT-ENGINE] Không đọc được webhook_subscriptions: {e}")
            return []

    async def dispatch_event(
        self,
        event_type: str,
        data: Dict[str, Any],
        ws_manager: Optional[Any] = None,
        origin_table: Optional[str] = None,
        webhook_rows: Optional[Sequence[WebhookRow]] = None,
        schema_version: int = 1,
        actor_user_id: Optional[str] = None,
        actor_device_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Dispatches a domain event:
        1. Broadcasts `event_reaction` JSON to all active WebSocket client connections.
        2. Fires HTTP POST Webhooks to registered external endpoints.

        webhook_rows: danh sách webhook đã được đọc sẵn (xem fetch_webhook_rows).
        Truyền vào khi gọi theo batch để chỉ đọc DB 1 lần. Nếu để None thì hàm
        tự mở connection riêng — KHÔNG bao giờ nhận connection từ bên ngoài.
        """
        timestamp = datetime.now(timezone.utc).isoformat()
        event_id = f"evt_{uuid.uuid4().hex[:12]}"

        # Cấu trúc payload bám theo tinh thần CloudEvents 1.0 nhưng giữ nguyên
        # các trường cũ (event/event_id/event_type/data/...) để client Flutter
        # hiện tại không vỡ.
        #
        # schema_version là trường QUAN TRỌNG NHẤT ở đây: khi adapter SAP hoặc
        # OPC UA bắt đầu tiêu thụ event này, mọi thay đổi cấu trúc `data` về sau
        # đều phải kèm tăng version, nếu không consumer sẽ diễn giải sai một
        # cách âm thầm. Thêm bây giờ thì miễn phí; thêm sau khi đã có consumer
        # thì phải phá vỡ tương thích.
        event_payload = {
            "event": "event_reaction",
            "event_id": event_id,
            "event_type": event_type,
            "origin_table": origin_table or (event_type.split('.')[0] if '.' in event_type else 'unknown'),
            "data": data,
            "timestamp": timestamp,
            "server_id": CONFIG.server_id,
            # ── Trường mới ──────────────────────────────────────────────────
            "schema_version": schema_version,       # phiên bản cấu trúc `data`
            "envelope_version": ENVELOPE_VERSION,   # phiên bản của chính lớp bọc này
            "zone": CONFIG.zone,
            "actor_user_id": actor_user_id,
            "actor_device_id": actor_device_id,
            # Định danh nguồn theo kiểu CloudEvents — giúp adapter phân biệt
            # event đến từ zone/server nào mà không cần parse thêm.
            "source": f"izii://{CONFIG.server_id}/{CONFIG.zone}",
        }

        # 1. WebSocket Broadcast to all active client apps in LAN
        if ws_manager:
            try:
                message_str = json.dumps(event_payload)
                await ws_manager.broadcast(message_str, exclude=None)
                print(f"📡 [EVENT-ENGINE] Broadcasted {event_type} ({event_id}) to connected WebSocket clients.")
            except Exception as e:
                print(f"⚠️ [EVENT-ENGINE] Error broadcasting WebSocket event: {e}")

        # 2. Asynchronous Webhook Dispatching to HTTP Endpoints
        rows = webhook_rows if webhook_rows is not None else self.fetch_webhook_rows()

        if rows:
            matched_webhooks = []
            for row in rows:
                url, event_filter, secret_token = row[1], row[2], row[3]
                if event_filter == "*" or fnmatch.fnmatch(event_type, event_filter or ""):
                    matched_webhooks.append((url, secret_token))

            if matched_webhooks:
                client = get_http_client()
                await asyncio.gather(
                    *(self._send_webhook_http_post(client, url, token, event_payload) for url, token in matched_webhooks),
                    return_exceptions=True,
                )

        return event_payload

    def register_webhook(self, url: str, event_filter: str = "*", secret_token: str = "") -> Dict[str, Any]:
        """
        Registers an external HTTP Webhook endpoint.
        """
        webhook_id = f"wh_{uuid.uuid4().hex[:12]}"
        created_at = datetime.now(timezone.utc).isoformat()
        
        from database import sql
        from dependencies import open_connection
        with open_connection() as conn:
            conn.execute(
                sql("INSERT INTO webhook_subscriptions (id, url, event_filter, secret_token, is_active, created_at) VALUES (?, ?, ?, ?, 1, ?)"),
                (webhook_id, url, event_filter, secret_token, created_at)
            )
            conn.commit()


        print(f"✅ [WEBHOOK] Registered Webhook {webhook_id}: {url} (filter='{event_filter}')")
        return {
            "id": webhook_id,
            "url": url,
            "event_filter": event_filter,
            "is_active": True,
            "created_at": created_at,
        }

    def list_webhooks(self) -> List[Dict[str, Any]]:
        """
        Lists all registered Webhook subscriptions.
        """
        from dependencies import open_connection
        with open_connection() as conn:
            rows = conn.execute(
                "SELECT id, url, event_filter, is_active, created_at FROM webhook_subscriptions"
            ).fetchall()
            return [
                {
                    "id": r["id"],
                    "url": r["url"],
                    "event_filter": r["event_filter"],
                    "is_active": bool(r["is_active"]),
                    "created_at": r["created_at"],
                }
                for r in rows
            ]

    def unregister_webhook(self, webhook_id: str) -> bool:
        """
        Deletes a Webhook subscription.
        """
        from database import sql
        from dependencies import open_connection
        with open_connection() as conn:
            cur = conn.execute(
                sql("DELETE FROM webhook_subscriptions WHERE id = ?"), (webhook_id,)
            )
            deleted = cur.rowcount > 0
            conn.commit()
            return deleted
