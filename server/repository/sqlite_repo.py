# server/repository/sqlite_repo.py
"""
SQLite Repository Implementations.

Architecture Plan Reference: Section 6 — Data Access Layer

These classes implement the abstract repository interfaces using SQLite.
All SQL queries are encapsulated here — when migrating to PostgreSQL,
create a parallel `postgres_repo.py` implementing the same interfaces.
"""
import sqlite3
import json
import uuid
import hashlib
import logging
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

from repository.interface import (
    ISyncRepository,
    IDeviceRepository,
    IMessageRepository,
    INotificationRepository,
)


class SQLiteSyncRepository(ISyncRepository):
    """SQLite implementation for Track 1 — Sync Engine."""
    
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
    
    # Số bản ghi tối đa trả về trong 1 lần pull nếu client không chỉ định.
    # Không để vô hạn: một thiết bị mới hoặc adapter mới kết nối sẽ kéo TOÀN BỘ
    # mutation log trong một request → nổ RAM cả hai đầu.
    DEFAULT_PULL_LIMIT = 1000
    MAX_PULL_LIMIT = 5000

    def _next_seq(self, cursor) -> int:
        """
        Cấp số thứ tự đơn điệu tiếp theo. Gọi TRONG cùng transaction với INSERT
        để hai connection ghi đồng thời không thể nhận cùng một seq
        (SQLite serialise ghi ở mức transaction).
        """
        cursor.execute(
            "UPDATE sync_sequence SET current = current + 1 WHERE name = 'mutation'"
        )
        row = cursor.execute(
            "SELECT current FROM sync_sequence WHERE name = 'mutation'"
        ).fetchone()
        return int(row[0])

    def push_mutations(
        self,
        mutations: List[Dict[str, Any]],
        timestamp: str,
        default_origin_server_id: Optional[str] = None,
        actor_user_id: Optional[str] = None,
        actor_device_id: Optional[str] = None,
    ) -> int:
        """
        default_origin_server_id: dùng khi mutation đến từ DEVICE (chưa có
        origin_server_id) — gán server hiện tại là "nơi đầu tiên" nhận mutation
        này. Khi RELAY từ peer server khác (qua peer_sync router), mutation đã
        có sẵn origin_server_id gốc và PHẢI được giữ nguyên, không ghi đè,
        để tránh vòng lặp relay vô hạn giữa các server.

        actor_user_id / actor_device_id: ai là người thực hiện thay đổi. Với
        mutation relay từ peer thì giữ nguyên actor gốc trong payload; chỉ dùng
        tham số này khi mutation đến thẳng từ device.

        seq LUÔN do server NÀY cấp mới, kể cả với mutation relay — vì seq là
        "thứ tự trong log của riêng server này", không phải thuộc tính toàn cục
        của mutation. Nhờ vậy peer B pull từ A theo seq của A vẫn nhất quán.
        """
        cursor = self.conn.cursor()
        count = 0
        for m in mutations:
            origin = m.get("origin_server_id") or default_origin_server_id
            seq = self._next_seq(cursor)
            cursor.execute("""
                INSERT OR REPLACE INTO sync_mutations
                    (id, client_id, "table", operation, data, server_received_at,
                     origin_server_id, seq, actor_user_id, actor_device_id, schema_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                m["id"], m.get("client_id"), m["table"], m["operation"],
                json.dumps(m["data"]), timestamp, origin, seq,
                m.get("actor_user_id") or actor_user_id,
                m.get("actor_device_id") or actor_device_id,
                int(m.get("schema_version") or 1),
            ))
            count += 1
        self.conn.commit()
        return count

    def pull_mutations(
        self,
        since: Optional[str] = None,
        exclude_origin_server_id: Optional[str] = None,
        after_seq: Optional[int] = None,
        limit: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Trả về dict: {updates, next_cursor, has_more, ...} — KHÁC bản cũ vốn
        trả thẳng list. Router chịu trách nhiệm giữ tương thích ngược cho client.

        HAI CHẾ ĐỘ CON TRỎ:
          - after_seq (MỚI, nên dùng): lọc theo số thứ tự đơn điệu do server
            cấp. Miễn nhiễm với lệch đồng hồ giữa các máy.
          - since (CŨ, giữ để tương thích): lọc theo chuỗi thời gian. Chỉ dùng
            khi client chưa cập nhật. Nếu truyền cả hai thì after_seq thắng.

        exclude_origin_server_id: dùng khi 1 peer server gọi pull — loại bỏ
        các mutation mà chính peer đó là nơi khởi tạo (origin), vì peer đã có
        sẵn dữ liệu này, gửi lại chỉ tốn băng thông. Không dùng khi device
        thường (mobile app) gọi pull.
        """
        eff_limit = limit if limit and limit > 0 else self.DEFAULT_PULL_LIMIT
        eff_limit = min(eff_limit, self.MAX_PULL_LIMIT)

        # ── Tự phục hồi khi con trỏ vượt quá log ────────────────────────────
        # Tình huống thật: server bị reset dữ liệu (reset_data.ps1 hoặc
        # /admin/reset xoá bảng) nên seq quay về 0, trong khi thiết bị vẫn giữ
        # con trỏ cũ ví dụ 5000. Truy vấn `seq > 5000` sẽ KHÔNG BAO GIỜ trả về
        # gì và thiết bị đứng im vĩnh viễn mà không báo lỗi.
        #
        # Phát hiện và phục vụ lại từ đầu, kèm cờ cursor_reset để client biết
        # mà ghi log. Tự lành trong đúng một vòng gọi.
        cursor_reset = False
        if after_seq is not None:
            max_seq = self.get_max_seq()
            if after_seq > max_seq:
                cursor_reset = True
                after_seq = None
                since = None

        cursor = self.conn.cursor()
        query = 'SELECT * FROM sync_mutations WHERE 1=1'
        params: list = []

        if after_seq is not None:
            # Bản ghi cũ có seq NULL sẽ không lọt vào đây — migration 002 trong
            # db_init.py đã cấp seq cho toàn bộ, nên không mất dữ liệu.
            query += ' AND seq IS NOT NULL AND seq > ?'
            params.append(after_seq)
        elif since:
            query += ' AND server_received_at > ?'
            params.append(since)

        if exclude_origin_server_id:
            query += ' AND (origin_server_id IS NULL OR origin_server_id != ?)'
            params.append(exclude_origin_server_id)

        # ORDER BY seq là bắt buộc khi phân trang — không có thứ tự ổn định thì
        # trang sau có thể bỏ sót hoặc lặp bản ghi.
        # Lấy dư 1 bản ghi để biết còn trang tiếp hay không mà không cần COUNT.
        query += ' ORDER BY seq ASC LIMIT ?'
        params.append(eff_limit + 1)

        cursor.execute(query, params)
        rows = cursor.fetchall()

        has_more = len(rows) > eff_limit
        if has_more:
            rows = rows[:eff_limit]

        updates = [{
            "id": r["id"],
            "client_id": r["client_id"],
            "table": r["table"],
            "operation": r["operation"],
            "data": json.loads(r["data"]),
            "server_received_at": r["server_received_at"],
            "origin_server_id": r["origin_server_id"],
            "seq": r["seq"],
            "actor_user_id": r["actor_user_id"],
            "actor_device_id": r["actor_device_id"],
            "schema_version": r["schema_version"] if r["schema_version"] is not None else 1,
        } for r in rows]

        # next_cursor = seq của bản ghi cuối cùng đã trả. Client lưu lại và gửi
        # làm after_seq cho lần sau. Nếu không có bản ghi nào thì giữ nguyên con
        # trỏ cũ để không nhảy cóc.
        next_cursor = updates[-1]["seq"] if updates else after_seq

        return {
            "updates": updates,
            "next_cursor": next_cursor,
            "has_more": has_more,
            "count": len(updates),
            "cursor_reset": cursor_reset,
        }

    def get_max_seq(self) -> int:
        row = self.conn.execute(
            "SELECT COALESCE(MAX(seq), 0) FROM sync_mutations"
        ).fetchone()
        return int(row[0])
    
    def get_mutations_by_table(self, table: str) -> List[Dict[str, Any]]:
        """
        Lấy toàn bộ mutation của MỘT bảng, sắp xếp theo server_received_at tăng
        dần. Dùng cho validate nghiệp vụ (vd unique room_number) — cần thứ tự
        thời gian để mutation mới nhất của cùng 1 record ghi đè bản cũ khi dựng
        index. Có index idx_sync_mutations_table nên truy vấn này rẻ.
        """
        cursor = self.conn.cursor()
        cursor.execute(
            'SELECT * FROM sync_mutations WHERE "table" = ? ORDER BY server_received_at ASC',
            (table,),
        )
        rows = cursor.fetchall()

        result: List[Dict[str, Any]] = []
        for r in rows:
            try:
                parsed = json.loads(r["data"])
            except Exception:
                continue  # bỏ qua bản ghi data hỏng thay vì làm chết request
            result.append({
                "id": r["id"],
                "table": r["table"],
                "operation": r["operation"],
                "data": parsed,
                "server_received_at": r["server_received_at"],
                "origin_server_id": r["origin_server_id"],
            })
        return result

    def get_status(self) -> Dict[str, Any]:
        cursor = self.conn.cursor()
        cursor.execute('SELECT "table", count(*) as cnt FROM sync_mutations GROUP BY "table"')
        rows = cursor.fetchall()
        tables = {r["table"]: r["cnt"] for r in rows}
        
        cursor.execute('SELECT count(*) as total FROM sync_mutations')
        total = cursor.fetchone()["total"]
        
        return {"total_records": total, "tables": tables}

    def update_peer_sync_status(
        self,
        peer_id: str,
        last_synced_at: Optional[str] = None,
        last_seen_online_at: Optional[str] = None,
        zone: Optional[str] = None,
        peer_url: Optional[str] = None,
        last_synced_seq: Optional[int] = None,
    ) -> None:
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO known_servers
                (server_id, zone, peer_url, last_synced_at, last_synced_seq, last_seen_online_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(server_id) DO UPDATE SET
                last_synced_at = COALESCE(excluded.last_synced_at, known_servers.last_synced_at),
                last_synced_seq = COALESCE(excluded.last_synced_seq, known_servers.last_synced_seq),
                last_seen_online_at = COALESCE(excluded.last_seen_online_at, known_servers.last_seen_online_at),
                zone = COALESCE(excluded.zone, known_servers.zone),
                peer_url = COALESCE(excluded.peer_url, known_servers.peer_url)
        """, (peer_id, zone, peer_url, last_synced_at, last_synced_seq, last_seen_online_at))
        self.conn.commit()

    def get_peer_last_synced(self, peer_id_or_url: str) -> Optional[str]:
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT last_synced_at FROM known_servers WHERE server_id = ? OR peer_url = ?",
            (peer_id_or_url, peer_id_or_url),
        )
        row = cursor.fetchone()
        return row["last_synced_at"] if row else None

    def get_peer_last_seq(self, peer_id_or_url: str) -> Optional[int]:
        """
        Con trỏ seq đã đồng bộ tới với peer. Đây là seq TRONG LOG CỦA PEER, nên
        chỉ có ý nghĩa khi gửi lại đúng peer đó.
        """
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT last_synced_seq FROM known_servers WHERE server_id = ? OR peer_url = ?",
            (peer_id_or_url, peer_id_or_url),
        )
        row = cursor.fetchone()
        if not row or row["last_synced_seq"] is None:
            return None
        return int(row["last_synced_seq"])

    def get_record(self, table: str, record_id: str) -> Optional[Dict[str, Any]]:
        """
        Endpoint P0.1c: Replays all mutations for (table, record_id) in sequential order.
        Returns None if record does not exist or was deleted.
        """
        cursor = self.conn.cursor()
        cursor.execute(
            'SELECT operation, data, seq FROM sync_mutations WHERE "table" = ? AND json_extract(data, "$.id") = ? ORDER BY seq ASC',
            (table, record_id),
        )
        rows = cursor.fetchall()
        if not rows:
            # Fallback check if id was stored directly or payload matches
            cursor.execute(
                'SELECT operation, data, seq FROM sync_mutations WHERE "table" = ? AND id = ? ORDER BY seq ASC',
                (table, record_id),
            )
            rows = cursor.fetchall()

        if not rows:
            return None

        merged_data: Dict[str, Any] = {}
        is_deleted = False
        last_seq = 0
        for r in rows:
            op = (r["operation"] or "").lower()
            last_seq = r["seq"]
            try:
                data = json.loads(r["data"]) if isinstance(r["data"], str) else (r["data"] or {})
            except Exception:
                continue

            if op in ("delete",):
                is_deleted = True
                merged_data = {}
            elif op in ("insert", "create"):
                is_deleted = False
                merged_data = dict(data)
            elif op in ("update",):
                is_deleted = False
                for k, v in data.items():
                    merged_data[k] = v

        if is_deleted or not merged_data:
            return None

        return {
            "table": table,
            "id": record_id,
            "data": merged_data,
            "last_seq": last_seq,
        }



class SQLiteDeviceRepository(IDeviceRepository):
    """SQLite implementation for Track 2 — Device Identity."""
    
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
    
    def register(self, device_data: Dict[str, Any], timestamp: str) -> Dict[str, Any]:
        cursor = self.conn.cursor()
        
        pub_key = device_data.get("public_key") or device_data.get("public_key_base64")
        sig_pub_key = device_data.get("signing_public_key") or device_data.get("signing_public_key_base64")
        
        if not pub_key:
            raise ValueError("Missing required field: public_key")
        
        # Generate human-readable fingerprint
        fp_hash = hashlib.sha256(pub_key.encode()).hexdigest()
        fingerprint = fp_hash[:8].upper()
        
        cursor.execute("""
            INSERT OR REPLACE INTO devices (device_id, user_id, public_key, signing_public_key, device_name, platform, push_token, fingerprint, registered_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (device_data["device_id"], device_data["user_id"], pub_key, sig_pub_key,
              device_data["device_name"], device_data["platform"], 
              device_data.get("push_token"), fingerprint, timestamp, timestamp))
        self.conn.commit()
        
        return {
            "device_id": device_data["device_id"],
            "user_id": device_data["user_id"],
            "public_key": pub_key,
            "signing_public_key": sig_pub_key,
            "device_name": device_data["device_name"],
            "platform": device_data["platform"],
            "push_token": device_data.get("push_token"),
            "fingerprint": fingerprint,
            "registered_at": timestamp,
            "last_seen_at": timestamp
        }
    
    def heartbeat(self, device_id: str, timestamp: str) -> bool:
        cursor = self.conn.cursor()
        cursor.execute("UPDATE devices SET last_seen_at = ? WHERE device_id = ?", (timestamp, device_id))
        self.conn.commit()
        return cursor.rowcount > 0
    
    def get_online(self, user_id: Optional[str] = None, 
                   exclude_device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        now = datetime.now(timezone.utc)
        online_threshold = timedelta(seconds=90)
        idle_threshold = timedelta(minutes=5)
        
        if user_id:
            cursor.execute("SELECT * FROM devices WHERE user_id = ?", (user_id,))
        else:
            cursor.execute("SELECT * FROM devices")
        rows = cursor.fetchall()
        
        devices = []
        for r in rows:
            if exclude_device_id and r["device_id"] == exclude_device_id:
                continue
            
            try:
                raw_last_seen = r["last_seen_at"]
                if not raw_last_seen:
                    continue
                if isinstance(raw_last_seen, datetime):
                    last_seen = raw_last_seen
                elif isinstance(raw_last_seen, str):
                    last_seen = datetime.fromisoformat(raw_last_seen.replace("Z", "+00:00"))
                else:
                    logger.warning("Không nhận dạng được kiểu last_seen_at cho thiết bị %s: %s", r["device_id"], type(raw_last_seen))
                    continue
                if last_seen.tzinfo is None:
                    last_seen = last_seen.replace(tzinfo=timezone.utc)
            except Exception as e:
                logger.warning("Lỗi phân tích last_seen_at cho thiết bị %s: %s", r["device_id"], e)
                continue
            
            elapsed = now - last_seen
            if elapsed <= online_threshold:
                status = "online"
            elif elapsed <= idle_threshold:
                status = "idle"
            else:
                continue  # Offline devices are skipped

            reg_at = r["registered_at"]
            if isinstance(reg_at, datetime):
                reg_at = reg_at.isoformat()
            
            devices.append({
                "device_id": r["device_id"],
                "user_id": r["user_id"],
                "device_name": r["device_name"],
                "platform": r["platform"],
                "public_key_base64": r["public_key"],
                "signing_public_key_base64": r["signing_public_key"],
                "registered_at": reg_at,
                "fingerprint": r["fingerprint"],
                "last_seen_at": last_seen.isoformat(),
                "status": status
            })
        
        return devices
    
    def get_key(self, device_id: str) -> Optional[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,))
        r = cursor.fetchone()
        if not r:
            return None
        
        return {
            "device_id": r["device_id"],
            "user_id": r["user_id"],
            "public_key_base64": r["public_key"],
            "signing_public_key_base64": r["signing_public_key"],
            "device_name": r["device_name"],
            "platform": r["platform"],
            "registered_at": r["registered_at"],
            "fingerprint": r["fingerprint"],
            "last_seen_at": r["last_seen_at"]
        }


class SQLiteMessageRepository(IMessageRepository):
    """SQLite implementation for Track 3 — E2EE Messaging."""
    
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
    
    def send(self, conversation_id: str, sender_device_id: str,
             payloads: Dict[str, Dict[str, Any]], timestamp: str) -> List[str]:
        cursor = self.conn.cursor()
        created_ids = []
        
        for recipient_device_id, payload in payloads.items():
            msg_id = str(uuid.uuid4())
            cursor.execute("""
                INSERT INTO message_queue (id, conversation_id, sender_device_id, recipient_device_id, ciphertext, nonce, signature, sent_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (msg_id, conversation_id, sender_device_id, recipient_device_id,
                  payload["ciphertext"], payload["nonce"], payload.get("signature"), timestamp))
            created_ids.append(msg_id)
        
        self.conn.commit()
        return created_ids
    
    # Quá số lần này thì coi như không bao giờ giải mã được — chuyển sang
    # dead-letter để hàng đợi thoát ra, thay vì gửi lại mãi mãi.
    MAX_FAILED_ATTEMPTS = 5

    def get_pending(self, device_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        # LIMIT là bắt buộc: trước đây trả về TOÀN BỘ hàng đợi, có lúc 1173 tin,
        # và máy nhận gọi một request lấy khoá cho từng tin — 1173 round-trip
        # mỗi 5 giây. Lấy theo lô nhỏ, cũ trước.
        cursor.execute(
            "SELECT * FROM message_queue "
            "WHERE recipient_device_id = ? AND delivered_at IS NULL "
            "  AND dead_lettered_at IS NULL "
            "ORDER BY sent_at ASC LIMIT ?",
            (device_id, max(1, min(limit, 200))),
        )
        rows = cursor.fetchall()

        return [{
            "id": r["id"],
            "conversation_id": r["conversation_id"],
            "sender_device_id": r["sender_device_id"],
            "recipient_device_id": r["recipient_device_id"],
            "ciphertext": r["ciphertext"],
            "nonce": r["nonce"],
            "signature": r["signature"],
            "sent_at": r["sent_at"],
            "delivered_at": r["delivered_at"]
        } for r in rows]

    def count_pending(self, device_id: str) -> int:
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) AS c FROM message_queue "
            "WHERE recipient_device_id = ? AND delivered_at IS NULL "
            "  AND dead_lettered_at IS NULL",
            (device_id,),
        )
        row = cursor.fetchone()
        return int(row["c"]) if row else 0

    def acknowledge(self, message_ids: List[str], timestamp: str) -> int:
        cursor = self.conn.cursor()
        acked_count = 0
        for msg_id in message_ids:
            cursor.execute("UPDATE message_queue SET delivered_at = ? WHERE id = ? AND delivered_at IS NULL",
                         (timestamp, msg_id))
            acked_count += cursor.rowcount
        self.conn.commit()
        return acked_count

    def mark_failed(self, message_ids: List[str], timestamp: str,
                    reason: str = "") -> int:
        """
        Ghi nhận máy nhận đã thử giải mã mà không được.

        Quá MAX_FAILED_ATTEMPTS thì đánh dấu dead-letter: tin vẫn nằm trong
        database để điều tra, nhưng không được trả về cho máy nhận nữa. Nếu
        không có bước này, một tin hỏng đủ để làm hàng đợi không bao giờ rỗng.
        """
        if not message_ids:
            return 0
        cursor = self.conn.cursor()
        dead = 0
        for msg_id in message_ids:
            cursor.execute(
                "UPDATE message_queue "
                "SET failed_attempts = failed_attempts + 1, last_error = ? "
                "WHERE id = ? AND delivered_at IS NULL AND dead_lettered_at IS NULL",
                (reason[:300], msg_id),
            )
            cursor.execute(
                "UPDATE message_queue SET dead_lettered_at = ? "
                "WHERE id = ? AND dead_lettered_at IS NULL "
                "  AND failed_attempts >= ?",
                (timestamp, msg_id, self.MAX_FAILED_ATTEMPTS),
            )
            dead += cursor.rowcount
        self.conn.commit()
        return dead


class SQLiteNotificationRepository(INotificationRepository):
    """SQLite implementation for Track 4+5 — Notifications & Settings."""
    
    DEFAULT_EVENTS = ['new_message', 'new_group_message', 'mention', 'added_to_group', 'missed_call']
    
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
    
    def get_notifications(self, user_id: str) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM notifications WHERE user_id = ?", (user_id,))
        rows = cursor.fetchall()
        
        return [{
            "id": r["id"],
            "user_id": r["user_id"],
            "title": r["title"],
            "body": r["body"],
            "event_type": r["event_type"],
            "resource_id": r["resource_id"],
            "read_at": r["read_at"],
            "created_at": r["created_at"]
        } for r in rows]
    
    def create_notification(self, notif_data: Dict[str, Any]) -> str:
        cursor = self.conn.cursor()
        notif_id = notif_data.get("id", str(uuid.uuid4()))
        cursor.execute("""
            INSERT INTO notifications (id, user_id, title, body, event_type, resource_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (notif_id, notif_data["user_id"], notif_data["title"], notif_data["body"],
              notif_data["event_type"], notif_data["resource_id"], notif_data["created_at"]))
        self.conn.commit()
        return notif_id
    
    def mark_read(self, user_id: str, notification_ids: List[str], timestamp: str) -> int:
        cursor = self.conn.cursor()
        updated_count = 0
        for notif_id in notification_ids:
            cursor.execute("UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL", 
                         (timestamp, notif_id, user_id))
            updated_count += cursor.rowcount
        self.conn.commit()
        return updated_count
    
    def mark_read_all(self, user_id: str, timestamp: str) -> int:
        cursor = self.conn.cursor()
        cursor.execute("UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL", 
                     (timestamp, user_id))
        updated_count = cursor.rowcount
        self.conn.commit()
        return updated_count
    
    def get_settings(self, user_id: str) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        settings_list = []
        
        for event in self.DEFAULT_EVENTS:
            cursor.execute("SELECT * FROM notification_settings WHERE user_id = ? AND event_type = ?", 
                         (user_id, event))
            r = cursor.fetchone()
            if r:
                settings_list.append({
                    "event_type": event,
                    "enable_push": bool(r["enable_push"]),
                    "enable_in_app": bool(r["enable_in_app"]),
                    "enable_email": bool(r["enable_email"]),
                    "digest_frequency": r["digest_frequency"]
                })
            else:
                settings_list.append({
                    "event_type": event,
                    "enable_push": True,
                    "enable_in_app": True,
                    "enable_email": True,
                    "digest_frequency": "instant"
                })
        
        return settings_list
    
    def update_settings(self, setting_data: Dict[str, Any]) -> bool:
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO notification_settings (user_id, event_type, enable_push, enable_in_app, enable_email, digest_frequency)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (setting_data["user_id"], setting_data["event_type"],
              int(setting_data.get("enable_push", True)),
              int(setting_data.get("enable_in_app", True)),
              int(setting_data.get("enable_email", True)),
              setting_data.get("digest_frequency", "instant")))
        self.conn.commit()
        return True
    
    def get_recipient_info(self, device_id: str) -> Optional[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT user_id, device_name, push_token FROM devices WHERE device_id = ?", (device_id,))
        r = cursor.fetchone()
        if not r:
            return None
        return {
            "user_id": r["user_id"],
            "device_name": r["device_name"],
            "push_token": r["push_token"]
        }
    
    def get_notification_setting(self, user_id: str, event_type: str) -> Optional[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM notification_settings WHERE user_id = ? AND event_type = ?", 
                     (user_id, event_type))
        r = cursor.fetchone()
        if not r:
            return None
        return {
            "enable_push": r["enable_push"],
            "enable_in_app": r["enable_in_app"],
            "enable_email": r["enable_email"],
            "digest_frequency": r["digest_frequency"]
        }
