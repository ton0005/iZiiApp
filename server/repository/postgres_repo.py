# server/repository/postgres_repo.py
"""
PostgreSQL Repository Implementations — bản song song của sqlite_repo.py.

Đúng như docstring của interface.py đã dự liệu từ đầu: "when migrating to
PostgreSQL, create a parallel postgres_repo.py implementing the same
interfaces". Nhờ Repository Pattern, KHÔNG có dòng code endpoint nào phải sửa.

BA KHÁC BIỆT CẦN NHỚ SO VỚI BẢN SQLITE:

1. Placeholder là %s chứ không phải ?.
2. `INSERT OR REPLACE` → `INSERT ... ON CONFLICT (id) DO UPDATE SET ...`.
3. `seq` do BIGSERIAL cấp tự động — KHÔNG tự tăng bộ đếm bằng tay như bản
   SQLite. Đây chính là điểm ăn tiền: sequence của Postgres an toàn tuyệt đối
   với nhiều writer đồng thời, còn bảng đếm thủ công thì phải dựa vào việc
   SQLite serialise ghi.

Connection ở đây được MƯỢN TỪ POOL. Không gọi conn.close() — dependency sẽ trả
nó về pool.
"""
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


class PostgresSyncRepository(ISyncRepository):
    """PostgreSQL implementation for Track 1 — Sync Engine."""

    DEFAULT_PULL_LIMIT = 1000
    MAX_PULL_LIMIT = 5000

    def __init__(self, conn):
        self.conn = conn
        self.last_applied_ids: List[str] = []
        self.last_push_rejected: List[Dict[str, Any]] = []
        try:
            from projector import ReadModelProjector
            self.projector = ReadModelProjector()
        except Exception as e:
            logger.warning(f"⚠️ [PROJECTOR] Không thể khởi tạo ReadModelProjector: {e}")
            self.projector = None

    def push_mutations(
        self,
        mutations: List[Dict[str, Any]],
        timestamp: str,
        default_origin_server_id: Optional[str] = None,
        actor_user_id: Optional[str] = None,
        actor_device_id: Optional[str] = None,
    ) -> int:
        applied_ids: List[str] = []
        rejected: List[Dict[str, Any]] = []
        max_seq = 0

        for m in mutations:
            try:
                # A1: Mỗi mutation được bọc trong một savepoint transaction độc lập
                with self.conn.transaction():
                    origin = m.get("origin_server_id") or default_origin_server_id
                    m_data = m.get("data")
                    if isinstance(m_data, str):
                        try:
                            m_data = json.loads(m_data)
                        except Exception:
                            m_data = {}
                    if not isinstance(m_data, dict):
                        m_data = {}

                    cur = self.conn.execute(
                        """
                        INSERT INTO sync_mutations
                            (id, client_id, "table", operation, data, server_received_at,
                             origin_server_id, actor_user_id, actor_device_id, schema_version)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            client_id          = EXCLUDED.client_id,
                            "table"            = EXCLUDED."table",
                            operation          = EXCLUDED.operation,
                            data               = EXCLUDED.data,
                            server_received_at = EXCLUDED.server_received_at,
                            origin_server_id   = EXCLUDED.origin_server_id,
                            actor_user_id      = EXCLUDED.actor_user_id,
                            actor_device_id    = EXCLUDED.actor_device_id,
                            schema_version     = EXCLUDED.schema_version
                        RETURNING seq
                        """,
                        (
                            m["id"], m.get("client_id"), m["table"], m["operation"],
                            json.dumps(m_data), timestamp, origin,
                            m.get("actor_user_id") or actor_user_id,
                            m.get("actor_device_id") or actor_device_id,
                            int(m.get("schema_version") or 1),
                        ),
                    )
                    row = cur.fetchone()
                    seq = (row["seq"] if isinstance(row, dict) else row[0]) if row else 0

                    # Phase 4 Projector (P4.1, P4.2, P4.6): Chiếu dữ liệu vào read model
                    if self.projector:
                        tenant_id = m.get("tenant_id") or m_data.get("tenant_id") or "default"
                        actor = m.get("actor_user_id") or actor_user_id or "system"
                        self.projector.project_mutation(
                            conn=self.conn,
                            table=m["table"],
                            operation=m["operation"],
                            data=m_data,
                            seq=seq,
                            mutation_id=m.get("id"),
                            tenant_id=tenant_id,
                            actor=actor,
                        )

                    if seq > max_seq:
                        max_seq = seq
                    applied_ids.append(m["id"])

            except Exception as pe:
                # Rollback savepoint của mutation này, không làm abort cả lô
                logger.error(f"❌ [PUSH] Lỗi mutation {m.get('id')} ({m.get('table')}): {pe}")
                rejected.append({
                    "id": m.get("id"),
                    "table": m.get("table"),
                    "operation": m.get("operation"),
                    "error": "mutation_failed",
                    "message": str(pe),
                })

        # Cập nhật checkpoint P4.3: Chỉ tiến tới max_seq của các mutation thành công
        if self.projector and max_seq > 0:
            self.projector.update_checkpoint(self.conn, max_seq)

        self.conn.commit()

        self.last_applied_ids = applied_ids
        self.last_push_rejected = rejected
        return len(applied_ids)

    def pull_mutations(
        self,
        since: Optional[str] = None,
        exclude_origin_server_id: Optional[str] = None,
        after_seq: Optional[int] = None,
        limit: Optional[int] = None,
    ) -> Dict[str, Any]:
        eff_limit = limit if limit and limit > 0 else self.DEFAULT_PULL_LIMIT
        eff_limit = min(eff_limit, self.MAX_PULL_LIMIT)

        # Tự phục hồi khi con trỏ client vượt quá log (server vừa bị reset).
        cursor_reset = False
        if after_seq is not None:
            if after_seq > self.get_max_seq():
                cursor_reset = True
                after_seq = None
                since = None

        query = 'SELECT * FROM sync_mutations WHERE TRUE'
        params: list = []

        if after_seq is not None:
            query += ' AND seq IS NOT NULL AND seq > %s'
            params.append(after_seq)
        elif since:
            query += ' AND server_received_at > %s'
            params.append(since)

        if exclude_origin_server_id:
            query += ' AND (origin_server_id IS NULL OR origin_server_id <> %s)'
            params.append(exclude_origin_server_id)

        query += ' ORDER BY seq ASC LIMIT %s'
        params.append(eff_limit + 1)

        rows = self.conn.execute(query, params).fetchall()

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

        next_cursor = updates[-1]["seq"] if updates else after_seq

        return {
            "updates": updates,
            "next_cursor": next_cursor,
            "has_more": has_more,
            "count": len(updates),
            "cursor_reset": cursor_reset,
        }

    def get_mutations_by_table(self, table: str) -> List[Dict[str, Any]]:
        rows = self.conn.execute(
            'SELECT * FROM sync_mutations WHERE "table" = %s ORDER BY server_received_at ASC',
            (table,),
        ).fetchall()

        result: List[Dict[str, Any]] = []
        for r in rows:
            try:
                parsed = json.loads(r["data"])
            except Exception:
                continue
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
        rows = self.conn.execute(
            'SELECT "table" AS t, count(*) AS cnt FROM sync_mutations GROUP BY "table"'
        ).fetchall()
        tables = {r["t"]: r["cnt"] for r in rows}
        total = self.conn.execute(
            'SELECT count(*) AS total FROM sync_mutations'
        ).fetchone()["total"]
        return {"total_records": total, "tables": tables}

    def get_max_seq(self) -> int:
        row = self.conn.execute(
            "SELECT COALESCE(MAX(seq), 0) AS m FROM sync_mutations"
        ).fetchone()
        return int(row["m"])

    def update_peer_sync_status(
        self,
        peer_id: str,
        last_synced_at: Optional[str] = None,
        last_seen_online_at: Optional[str] = None,
        zone: Optional[str] = None,
        peer_url: Optional[str] = None,
        last_synced_seq: Optional[int] = None,
    ) -> None:
        self.conn.execute(
            """
            INSERT INTO known_servers
                (server_id, zone, peer_url, last_synced_at, last_synced_seq, last_seen_online_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (server_id) DO UPDATE SET
                last_synced_at      = COALESCE(EXCLUDED.last_synced_at, known_servers.last_synced_at),
                last_synced_seq     = COALESCE(EXCLUDED.last_synced_seq, known_servers.last_synced_seq),
                last_seen_online_at = COALESCE(EXCLUDED.last_seen_online_at, known_servers.last_seen_online_at),
                zone                = COALESCE(EXCLUDED.zone, known_servers.zone),
                peer_url            = COALESCE(EXCLUDED.peer_url, known_servers.peer_url)
            """,
            (peer_id, zone, peer_url, last_synced_at, last_synced_seq, last_seen_online_at),
        )
        self.conn.commit()

    def get_peer_last_synced(self, peer_id_or_url: str) -> Optional[str]:
        row = self.conn.execute(
            "SELECT last_synced_at FROM known_servers WHERE server_id = %s OR peer_url = %s",
            (peer_id_or_url, peer_id_or_url),
        ).fetchone()
        return row["last_synced_at"] if row else None

    def get_peer_last_seq(self, peer_id_or_url: str) -> Optional[int]:
        row = self.conn.execute(
            "SELECT last_synced_seq FROM known_servers WHERE server_id = %s OR peer_url = %s",
            (peer_id_or_url, peer_id_or_url),
        ).fetchone()
        if not row or row["last_synced_seq"] is None:
            return None
        return int(row["last_synced_seq"])

    def get_record(self, table: str, record_id: str) -> Optional[Dict[str, Any]]:
        """
        Endpoint P0.1c: Lấy snapshot của record kết hợp giữa projected read-model table
        và replay các mutations trong sync_mutations.
        Returns None nếu record không tồn tại hoặc đã bị xóa.
        """
        from projector import TABLE_ALIASES
        target_table = TABLE_ALIASES.get(table.lower(), table.lower())

        table_record = None
        try:
            cur = self.conn.execute(
                f'SELECT * FROM "{target_table}" WHERE id = %s',
                (record_id,)
            )
            row = cur.fetchone()
            if row:
                table_record = dict(row)
                for k, v in table_record.items():
                    if hasattr(v, "isoformat"):
                        table_record[k] = v.isoformat()
        except Exception:
            pass

        rows = self.conn.execute(
            'SELECT operation, data, seq FROM sync_mutations WHERE "table" = %s AND (data::jsonb->>\'id\') = %s ORDER BY seq ASC',
            (table, record_id),
        ).fetchall()
        if not rows:
            # Fallback check if id was stored directly
            rows = self.conn.execute(
                'SELECT operation, data, seq FROM sync_mutations WHERE "table" = %s AND id = %s ORDER BY seq ASC',
                (table, record_id),
            ).fetchall()

        if not rows and not table_record:
            return None

        merged_data: Dict[str, Any] = {}
        is_deleted = False
        last_seq = 0

        # Nếu có bản ghi trong read-model table, dùng làm snapshot cơ sở
        if table_record:
            if table_record.get("deleted_at") is not None:
                is_deleted = True
            else:
                merged_data = dict(table_record)
            if "last_seq" in table_record and table_record["last_seq"]:
                try:
                    last_seq = int(table_record["last_seq"])
                except Exception:
                    pass

        for r in rows:
            op = (r["operation"] or "").lower()
            last_seq = max(last_seq, r["seq"])
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

        if "id" not in merged_data:
            merged_data["id"] = record_id

        return {
            "table": table,
            "id": record_id,
            "data": merged_data,
            "last_seq": last_seq,
        }

    def get_table_snapshot(
        self,
        table: str,
        limit: int = 1000,
        tenant_id: Optional[str] = None,
        after_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        P4.5 Snapshot API: Trả về snapshot đầy đủ của bảng cùng snapshot_seq hiện thời.
        Hỗ trợ Keyset pagination (after_id) và REPEATABLE READ snapshot consistency.
        """
        from projector import TABLE_ALIASES
        target_table = TABLE_ALIASES.get(table.lower(), table.lower())

        # Đảm bảo connection ở trạng thái sạch trước khi bắt đầu REPEATABLE READ
        try:
            self.conn.rollback()
        except Exception:
            pass

        # Thực thi trong transaction REPEATABLE READ để đảm bảo snapshot_seq và data khớp nhau
        with self.conn.transaction():
            try:
                self.conn.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")
            except Exception:
                pass

            max_seq = self.get_max_seq()

            cols = set()
            try:
                cur = self.conn.execute(
                    "SELECT column_name FROM information_schema.columns WHERE table_name = %s",
                    (target_table,),
                )
                cols = {(r["column_name"] if isinstance(r, dict) else r[0]) for r in cur.fetchall()}
            except Exception:
                pass

            if not cols:
                return {
                    "table": table,
                    "target_table": target_table,
                    "snapshot_seq": max_seq,
                    "count": 0,
                    "rows": [],
                    "has_more": False,
                    "next_cursor": None,
                }

            where_clauses = []
            params: list = []
            if "deleted_at" in cols:
                where_clauses.append("deleted_at IS NULL")
            if tenant_id and "tenant_id" in cols:
                where_clauses.append("tenant_id = %s")
                params.append(tenant_id)

            if after_id is not None:
                where_clauses.append('(id COLLATE "C") > (%s COLLATE "C")')
                params.append(after_id)

            where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""
            
            # Luôn ORDER BY id COLLATE "C" ASC để Keyset pagination ổn định và nhất quán theo chuẩn byte-order
            query = f'SELECT * FROM {target_table} {where_sql} ORDER BY (id COLLATE "C") ASC LIMIT %s'
            # Fetch limit + 1 để kiểm tra has_more
            params.append(limit + 1)

            cur = self.conn.execute(query, tuple(params))
            raw_rows = [dict(r) for r in cur.fetchall()]

            has_more = len(raw_rows) > limit
            rows = raw_rows[:limit]
            next_cursor = rows[-1]["id"] if (has_more and rows and "id" in rows[-1]) else None

            # Convert datetime/UUID objects to serializable types
            for r in rows:
                for k, v in r.items():
                    if hasattr(v, "isoformat"):
                        r[k] = v.isoformat()

            return {
                "table": table,
                "target_table": target_table,
                "snapshot_seq": max_seq,
                "count": len(rows),
                "rows": rows,
                "has_more": has_more,
                "next_cursor": next_cursor,
            }

    def get_record_history(self, table: str, record_id: str) -> List[Dict[str, Any]]:
        """
        P4.7 Record History API: Truy vết toàn bộ lịch sử thay đổi của một record từ sync_mutations.
        """
        cur = self.conn.execute(
            """
            SELECT id, client_id, "table", operation, data, server_received_at, seq, actor_user_id
            FROM sync_mutations
            WHERE "table" = %s AND ((data::jsonb->>'id') = %s OR id = %s)
            ORDER BY seq ASC
            """,
            (table, record_id, record_id),
        )
        rows = cur.fetchall()
        result = []
        for r in rows:
            d = r["data"]
            if isinstance(d, str):
                try:
                    d = json.loads(d)
                except Exception:
                    pass
            result.append({
                "mutation_id": r["id"],
                "client_id": r["client_id"],
                "table": r["table"],
                "operation": r["operation"],
                "seq": r["seq"],
                "server_received_at": str(r["server_received_at"]),
                "actor_user_id": r["actor_user_id"],
                "data": d,
            })
        return result




class PostgresDeviceRepository(IDeviceRepository):
    """PostgreSQL implementation for Track 2 — Device Identity."""

    def __init__(self, conn):
        self.conn = conn

    def register(self, device_data: Dict[str, Any], timestamp: str) -> Dict[str, Any]:
        pub_key = device_data.get("public_key") or device_data.get("public_key_base64")
        sig_pub_key = device_data.get("signing_public_key") or device_data.get("signing_public_key_base64")
        if not pub_key:
            raise ValueError("Missing required field: public_key")

        fingerprint = hashlib.sha256(pub_key.encode()).hexdigest()[:8].upper()

        self.conn.execute(
            """
            INSERT INTO devices (device_id, user_id, public_key, signing_public_key,
                                 device_name, platform, push_token, fingerprint,
                                 registered_at, last_seen_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (device_id) DO UPDATE SET
                user_id            = EXCLUDED.user_id,
                public_key         = EXCLUDED.public_key,
                signing_public_key = EXCLUDED.signing_public_key,
                device_name        = EXCLUDED.device_name,
                platform           = EXCLUDED.platform,
                push_token         = EXCLUDED.push_token,
                fingerprint        = EXCLUDED.fingerprint,
                last_seen_at       = EXCLUDED.last_seen_at
            """,
            (device_data["device_id"], device_data["user_id"], pub_key, sig_pub_key,
             device_data["device_name"], device_data["platform"],
             device_data.get("push_token"), fingerprint, timestamp, timestamp),
        )
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
            "last_seen_at": timestamp,
        }

    def heartbeat(self, device_id: str, timestamp: str) -> bool:
        cur = self.conn.execute(
            "UPDATE devices SET last_seen_at = %s WHERE device_id = %s", (timestamp, device_id)
        )
        self.conn.commit()
        return cur.rowcount > 0

    def get_online(self, user_id: Optional[str] = None,
                   exclude_device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        now = datetime.now(timezone.utc)
        online_threshold = timedelta(seconds=45)
        idle_threshold = timedelta(minutes=2)

        if user_id:
            rows = self.conn.execute("SELECT * FROM devices WHERE user_id = %s", (user_id,)).fetchall()
        else:
            rows = self.conn.execute("SELECT * FROM devices").fetchall()

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
                    logger.warning("Không nhận dạng được kiểu last_seen_at cho thiết bị %s: %s", r.get("device_id"), type(raw_last_seen))
                    continue
                if last_seen.tzinfo is None:
                    last_seen = last_seen.replace(tzinfo=timezone.utc)
            except Exception as e:
                logger.warning("Lỗi phân tích last_seen_at cho thiết bị %s: %s", r.get("device_id") if isinstance(r, dict) else r["device_id"], e)
                continue

            elapsed = now - last_seen
            if elapsed <= online_threshold:
                status = "online"
            elif elapsed <= idle_threshold:
                status = "idle"
            else:
                continue

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
                "status": status,
            })
        return devices

    def get_key(self, device_id: str) -> Optional[Dict[str, Any]]:
        r = self.conn.execute(
            "SELECT * FROM devices WHERE device_id = %s", (device_id,)
        ).fetchone()
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
            "last_seen_at": r["last_seen_at"],
        }


class PostgresMessageRepository(IMessageRepository):
    """PostgreSQL implementation for Track 3 — E2EE Messaging."""

    def __init__(self, conn):
        self.conn = conn

    def send(self, conversation_id: str, sender_device_id: str,
             payloads: Dict[str, Dict[str, Any]], timestamp: str) -> List[str]:
        created_ids = []
        for recipient_device_id, payload in payloads.items():
            msg_id = str(uuid.uuid4())
            self.conn.execute(
                """
                INSERT INTO message_queue (id, conversation_id, sender_device_id,
                                           recipient_device_id, ciphertext, nonce,
                                           signature, sent_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (msg_id, conversation_id, sender_device_id, recipient_device_id,
                 payload["ciphertext"], payload["nonce"], payload.get("signature"), timestamp),
            )
            created_ids.append(msg_id)
        self.conn.commit()
        return created_ids

    MAX_FAILED_ATTEMPTS = 5

    def get_pending(self, device_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        # Xem chú thích ở sqlite_repo.get_pending — LIMIT là bắt buộc.
        rows = self.conn.execute(
            "SELECT * FROM message_queue "
            "WHERE recipient_device_id = %s AND delivered_at IS NULL "
            "  AND dead_lettered_at IS NULL "
            "ORDER BY sent_at ASC LIMIT %s",
            (device_id, max(1, min(limit, 200))),
        ).fetchall()
        return [{
            "id": r["id"],
            "conversation_id": r["conversation_id"],
            "sender_device_id": r["sender_device_id"],
            "recipient_device_id": r["recipient_device_id"],
            "ciphertext": r["ciphertext"],
            "nonce": r["nonce"],
            "signature": r["signature"],
            "sent_at": r["sent_at"],
            "delivered_at": r["delivered_at"],
        } for r in rows]

    def count_pending(self, device_id: str) -> int:
        row = self.conn.execute(
            "SELECT COUNT(*) AS c FROM message_queue "
            "WHERE recipient_device_id = %s AND delivered_at IS NULL "
            "  AND dead_lettered_at IS NULL",
            (device_id,),
        ).fetchone()
        return int(row["c"]) if row else 0

    def acknowledge(self, message_ids: List[str], timestamp: str) -> int:
        if not message_ids:
            return 0
        cur = self.conn.execute(
            "UPDATE message_queue SET delivered_at = %s "
            "WHERE id = ANY(%s) AND delivered_at IS NULL",
            (timestamp, list(message_ids)),
        )
        acked = cur.rowcount
        self.conn.commit()
        return acked

    def mark_failed(self, message_ids: List[str], timestamp: str,
                    reason: str = "") -> int:
        if not message_ids:
            return 0
        ids = list(message_ids)
        self.conn.execute(
            "UPDATE message_queue "
            "SET failed_attempts = failed_attempts + 1, last_error = %s "
            "WHERE id = ANY(%s) AND delivered_at IS NULL AND dead_lettered_at IS NULL",
            (reason[:300], ids),
        )
        cur = self.conn.execute(
            "UPDATE message_queue SET dead_lettered_at = %s "
            "WHERE id = ANY(%s) AND dead_lettered_at IS NULL "
            "  AND failed_attempts >= %s",
            (timestamp, ids, self.MAX_FAILED_ATTEMPTS),
        )
        dead = cur.rowcount
        self.conn.commit()
        return dead


class PostgresNotificationRepository(INotificationRepository):
    """PostgreSQL implementation for Track 4+5 — Notifications & Settings."""

    DEFAULT_EVENTS = ['new_message', 'new_group_message', 'mention', 'added_to_group', 'missed_call']

    def __init__(self, conn):
        self.conn = conn

    def get_notifications(self, user_id: str) -> List[Dict[str, Any]]:
        rows = self.conn.execute(
            "SELECT * FROM notifications WHERE user_id = %s", (user_id,)
        ).fetchall()
        return [{
            "id": r["id"],
            "user_id": r["user_id"],
            "title": r["title"],
            "body": r["body"],
            "event_type": r["event_type"],
            "resource_id": r["resource_id"],
            "read_at": r["read_at"],
            "created_at": r["created_at"],
        } for r in rows]

    def create_notification(self, notif_data: Dict[str, Any]) -> str:
        notif_id = notif_data.get("id", str(uuid.uuid4()))
        self.conn.execute(
            """
            INSERT INTO notifications (id, user_id, title, body, event_type, resource_id, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (notif_id, notif_data["user_id"], notif_data["title"], notif_data["body"],
             notif_data["event_type"], notif_data["resource_id"], notif_data["created_at"]),
        )
        self.conn.commit()
        return notif_id

    def mark_read(self, user_id: str, notification_ids: List[str], timestamp: str) -> int:
        if not notification_ids:
            return 0
        cur = self.conn.execute(
            "UPDATE notifications SET read_at = %s "
            "WHERE id = ANY(%s) AND user_id = %s AND read_at IS NULL",
            (timestamp, list(notification_ids), user_id),
        )
        updated = cur.rowcount
        self.conn.commit()
        return updated

    def mark_read_all(self, user_id: str, timestamp: str) -> int:
        cur = self.conn.execute(
            "UPDATE notifications SET read_at = %s WHERE user_id = %s AND read_at IS NULL",
            (timestamp, user_id),
        )
        updated = cur.rowcount
        self.conn.commit()
        return updated

    def get_settings(self, user_id: str) -> List[Dict[str, Any]]:
        settings_list = []
        for event in self.DEFAULT_EVENTS:
            r = self.conn.execute(
                "SELECT * FROM notification_settings WHERE user_id = %s AND event_type = %s",
                (user_id, event),
            ).fetchone()
            if r:
                settings_list.append({
                    "event_type": event,
                    "enable_push": bool(r["enable_push"]),
                    "enable_in_app": bool(r["enable_in_app"]),
                    "enable_email": bool(r["enable_email"]),
                    "digest_frequency": r["digest_frequency"],
                })
            else:
                settings_list.append({
                    "event_type": event,
                    "enable_push": True,
                    "enable_in_app": True,
                    "enable_email": True,
                    "digest_frequency": "instant",
                })
        return settings_list

    def update_settings(self, setting_data: Dict[str, Any]) -> bool:
        self.conn.execute(
            """
            INSERT INTO notification_settings
                (user_id, event_type, enable_push, enable_in_app, enable_email, digest_frequency)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (user_id, event_type) DO UPDATE SET
                enable_push      = EXCLUDED.enable_push,
                enable_in_app    = EXCLUDED.enable_in_app,
                enable_email     = EXCLUDED.enable_email,
                digest_frequency = EXCLUDED.digest_frequency
            """,
            (setting_data["user_id"], setting_data["event_type"],
             int(setting_data.get("enable_push", True)),
             int(setting_data.get("enable_in_app", True)),
             int(setting_data.get("enable_email", True)),
             setting_data.get("digest_frequency", "instant")),
        )
        self.conn.commit()
        return True

    def get_recipient_info(self, device_id: str) -> Optional[Dict[str, Any]]:
        r = self.conn.execute(
            "SELECT user_id, device_name, push_token FROM devices WHERE device_id = %s",
            (device_id,),
        ).fetchone()
        if not r:
            return None
        return {
            "user_id": r["user_id"],
            "device_name": r["device_name"],
            "push_token": r["push_token"],
        }

    def get_notification_setting(self, user_id: str, event_type: str) -> Optional[Dict[str, Any]]:
        r = self.conn.execute(
            "SELECT * FROM notification_settings WHERE user_id = %s AND event_type = %s",
            (user_id, event_type),
        ).fetchone()
        if not r:
            return None
        return {
            "enable_push": r["enable_push"],
            "enable_in_app": r["enable_in_app"],
            "enable_email": r["enable_email"],
            "digest_frequency": r["digest_frequency"],
        }
