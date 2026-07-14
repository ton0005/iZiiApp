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
    def push_mutations(self, mutations: List[Dict[str, Any]], timestamp: str) -> int:
        """
        Store a batch of sync mutations from a client device.
        Returns the number of mutations successfully stored.
        """
        pass
    
    @abstractmethod
    def pull_mutations(self, since: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Retrieve mutations since a given timestamp.
        If since is None, returns all mutations.
        """
        pass
    
    @abstractmethod
    def get_status(self) -> Dict[str, Any]:
        """
        Get sync status summary: total records and per-table counts.
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
    def get_pending(self, device_id: str) -> List[Dict[str, Any]]:
        """
        Get undelivered messages for a specific device.
        """
        pass
    
    @abstractmethod
    def acknowledge(self, message_ids: List[str], timestamp: str) -> int:
        """
        Mark messages as delivered.
        Returns the count of messages actually acknowledged.
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
