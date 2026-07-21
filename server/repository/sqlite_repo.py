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
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

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
    
    def push_mutations(
        self, mutations: List[Dict[str, Any]], timestamp: str, default_origin_server_id: Optional[str] = None
    ) -> int:
        """
        default_origin_server_id: dùng khi mutation đến từ DEVICE (chưa có
        origin_server_id) — gán server hiện tại là "nơi đầu tiên" nhận mutation
        này. Khi RELAY từ peer server khác (qua peer_sync router), mutation đã
        có sẵn origin_server_id gốc và PHẢI được giữ nguyên, không ghi đè,
        để tránh vòng lặp relay vô hạn giữa các server.
        """
        cursor = self.conn.cursor()
        count = 0
        for m in mutations:
            origin = m.get("origin_server_id") or default_origin_server_id
            cursor.execute("""
                INSERT OR REPLACE INTO sync_mutations (id, client_id, "table", operation, data, server_received_at, origin_server_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (m["id"], m.get("client_id"), m["table"], m["operation"],
                  json.dumps(m["data"]), timestamp, origin))
            count += 1
        self.conn.commit()
        return count
    
    def pull_mutations(
        self, since: Optional[str] = None, exclude_origin_server_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        exclude_origin_server_id: dùng khi 1 peer server gọi pull — loại bỏ
        các mutation mà chính peer đó là nơi khởi tạo (origin), vì peer đã có
        sẵn dữ liệu này, gửi lại chỉ tốn băng thông. Không dùng khi device
        thường (mobile app) gọi pull.
        """
        cursor = self.conn.cursor()
        query = 'SELECT * FROM sync_mutations WHERE 1=1'
        params: list = []
        if since:
            query += ' AND server_received_at > ?'
            params.append(since)
        if exclude_origin_server_id:
            query += ' AND (origin_server_id IS NULL OR origin_server_id != ?)'
            params.append(exclude_origin_server_id)
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        return [{
            "id": r["id"],
            "client_id": r["client_id"],
            "table": r["table"],
            "operation": r["operation"],
            "data": json.loads(r["data"]),
            "server_received_at": r["server_received_at"],
            "origin_server_id": r["origin_server_id"],
        } for r in rows]
    
    def get_status(self) -> Dict[str, Any]:
        cursor = self.conn.cursor()
        cursor.execute('SELECT "table", count(*) as cnt FROM sync_mutations GROUP BY "table"')
        rows = cursor.fetchall()
        tables = {r["table"]: r["cnt"] for r in rows}
        
        cursor.execute('SELECT count(*) as total FROM sync_mutations')
        total = cursor.fetchone()["total"]
        
        return {"total_records": total, "tables": tables}


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
        now = datetime.now()
        online_threshold = timedelta(seconds=45)
        idle_threshold = timedelta(minutes=2)
        
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
                last_seen = datetime.fromisoformat(r["last_seen_at"])
            except Exception:
                continue
            
            elapsed = now - last_seen
            if elapsed <= online_threshold:
                status = "online"
            elif elapsed <= idle_threshold:
                status = "idle"
            else:
                continue  # Offline devices are skipped
            
            devices.append({
                "device_id": r["device_id"],
                "user_id": r["user_id"],
                "device_name": r["device_name"],
                "platform": r["platform"],
                "public_key_base64": r["public_key"],
                "signing_public_key_base64": r["signing_public_key"],
                "registered_at": r["registered_at"],
                "fingerprint": r["fingerprint"],
                "last_seen_at": r["last_seen_at"],
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
    
    def get_pending(self, device_id: str) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM message_queue WHERE recipient_device_id = ? AND delivered_at IS NULL", (device_id,))
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
    
    def acknowledge(self, message_ids: List[str], timestamp: str) -> int:
        cursor = self.conn.cursor()
        acked_count = 0
        for msg_id in message_ids:
            cursor.execute("UPDATE message_queue SET delivered_at = ? WHERE id = ? AND delivered_at IS NULL", 
                         (timestamp, msg_id))
            acked_count += cursor.rowcount
        self.conn.commit()
        return acked_count


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
