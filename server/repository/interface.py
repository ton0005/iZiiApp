# server/repository/interface.py
"""
Abstract Repository Interfaces.

Architecture Plan Reference: Section 6 — Data Access Layer

These interfaces define the contract for all data access operations.
When migrating from SQLite to PostgreSQL, only the implementation classes
need to change — all endpoint code remains untouched.
"""
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional


class ISyncRepository(ABC):
    """Repository interface for Track 1 — Sync Engine operations."""
    
    @abstractmethod
    def push_mutations(
        self, mutations: List[Dict[str, Any]], timestamp: str,
        default_origin_server_id: Optional[str] = None,
        actor_user_id: Optional[str] = None,
        actor_device_id: Optional[str] = None,
    ) -> int:
        """
        Store a batch of sync mutations from a client device (or relayed
        from a peer server in a multi-server setup).

        default_origin_server_id: server_id to record as the mutation's
        point of origin, used ONLY when a mutation doesn't already carry
        its own origin_server_id (i.e. it came directly from a device,
        not relayed from another server). When relaying from a peer,
        each mutation already has origin_server_id set and it must be
        preserved as-is by the implementation.

        Returns the number of mutations successfully stored.
        """
        pass
    
    @abstractmethod
    def pull_mutations(
        self, since: Optional[str] = None,
        exclude_origin_server_id: Optional[str] = None,
        after_seq: Optional[int] = None,
        limit: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Retrieve a PAGE of mutations. Returns a dict:
            {updates: [...], next_cursor: int|None, has_more: bool, count: int}

        Two cursor modes:
        - after_seq (preferred): filter by the server-assigned monotonic
          sequence. Immune to clock skew between machines, unlike a timestamp
          cursor where a few seconds of drift silently drops mutations.
        - since (legacy): filter by timestamp string. Kept only for clients
          that have not migrated yet. If both are given, after_seq wins.

        exclude_origin_server_id: when set, mutations whose origin_server_id
        matches this value are excluded from the result. Used by peer
        servers pulling delta from each other — the requester doesn't need
        mutations it originated itself, saving bandwidth. Regular device
        clients should leave this as None.

        limit: page size. Implementations MUST enforce a sane upper bound —
        an unbounded pull lets a fresh device drag the entire log in one
        request and blow up memory on both ends.
        """
        pass

    @abstractmethod
    def get_max_seq(self) -> int:
        """Highest sequence number currently in the log (0 if empty)."""
        pass
    
    @abstractmethod
    def get_mutations_by_table(self, table: str) -> List[Dict[str, Any]]:
        """
        Return every mutation for a single table, ordered by server_received_at
        ascending, with `data` already parsed from JSON.

        Used by business-rule validation (e.g. unique room_number) which needs
        chronological order so the newest mutation for a given record wins when
        building a lookup index.
        """
        pass

    @abstractmethod
    def get_status(self) -> Dict[str, Any]:
        """
        Get sync status summary: total records and per-table counts.
        """
        pass

    @abstractmethod
    def update_peer_sync_status(
        self,
        peer_id: str,
        last_synced_at: Optional[str] = None,
        last_seen_online_at: Optional[str] = None,
        zone: Optional[str] = None,
        peer_url: Optional[str] = None,
    ) -> None:
        """
        Persist peer server last synced timestamp in SQLite known_servers table.
        """
        pass

    @abstractmethod
    def get_peer_last_synced(self, peer_id_or_url: str) -> Optional[str]:
        """
        Get last synced timestamp for a peer server from known_servers table.
        """
        pass


class IDeviceRepository(ABC):
    """Repository interface for Track 2 — Device Identity operations."""
    
    @abstractmethod
    def register(self, device_data: Dict[str, Any], timestamp: str) -> Dict[str, Any]:
        """
        Register or update a device in the registry.
        Returns the complete device record including generated fingerprint.
        """
        pass
    
    @abstractmethod
    def heartbeat(self, device_id: str, timestamp: str) -> bool:
        """
        Update the last_seen_at timestamp for a device.
        Returns False if device not found.
        """
        pass
    
    @abstractmethod
    def get_online(self, user_id: Optional[str] = None, 
                   exclude_device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Get list of online/idle devices, optionally filtered by user_id.
        """
        pass
    
    @abstractmethod
    def get_key(self, device_id: str) -> Optional[Dict[str, Any]]:
        """
        Lookup a device's public key and metadata by device_id.
        Returns None if device not found.
        """
        pass


class IMessageRepository(ABC):
    """Repository interface for Track 3 — E2EE Messaging operations."""
    
    @abstractmethod
    def send(self, conversation_id: str, sender_device_id: str,
             payloads: Dict[str, Dict[str, Any]], timestamp: str) -> List[str]:
        """
        Store encrypted message envelopes for each recipient device.
        Returns list of created message IDs.
        """
        pass
    
    @abstractmethod
    def get_pending(self, device_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Get undelivered messages for a specific device, oldest first.

        [limit] là bắt buộc chứ không phải tuỳ chọn: trả về cả hàng đợi khiến
        máy nhận phải xử lý hàng ngàn tin trong một vòng poll 5 giây.
        """
        pass

    @abstractmethod
    def count_pending(self, device_id: str) -> int:
        """Tổng số tin còn chờ — để client biết có cần poll tiếp ngay không."""
        pass

    @abstractmethod
    def acknowledge(self, message_ids: List[str], timestamp: str) -> int:
        """
        Mark messages as delivered.
        Returns the count of messages actually acknowledged.
        """
        pass

    @abstractmethod
    def mark_failed(self, message_ids: List[str], timestamp: str,
                    reason: str = "") -> int:
        """
        Đánh dấu máy nhận đã thử giải mã mà thất bại.

        Vượt ngưỡng thì chuyển sang dead-letter để hàng đợi thoát ra.
        Trả về số tin vừa bị dead-letter.
        """
        pass


class INotificationRepository(ABC):
    """Repository interface for Track 4+5 — Notifications & Settings operations."""
    
    @abstractmethod
    def get_notifications(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all notifications for a user."""
        pass
    
    @abstractmethod
    def create_notification(self, notif_data: Dict[str, Any]) -> str:
        """
        Create a new notification record.
        Returns the notification ID.
        """
        pass
    
    @abstractmethod
    def mark_read(self, user_id: str, notification_ids: List[str], 
                  timestamp: str) -> int:
        """Mark specific notifications as read. Returns count updated."""
        pass
    
    @abstractmethod
    def mark_read_all(self, user_id: str, timestamp: str) -> int:
        """Mark all notifications for a user as read. Returns count updated."""
        pass
    
    @abstractmethod
    def get_settings(self, user_id: str) -> List[Dict[str, Any]]:
        """Get notification settings for a user across all event types."""
        pass
    
    @abstractmethod
    def update_settings(self, setting_data: Dict[str, Any]) -> bool:
        """Update notification settings for a specific user + event_type."""
        pass
    
    @abstractmethod
    def get_recipient_info(self, device_id: str) -> Optional[Dict[str, Any]]:
        """
        Get recipient device info including user_id, device_name, push_token.
        Used for notification dispatch logic.
        """
        pass
    
    @abstractmethod
    def get_notification_setting(self, user_id: str, 
                                  event_type: str) -> Optional[Dict[str, Any]]:
        """Get a specific notification setting for dispatch logic."""
        pass
