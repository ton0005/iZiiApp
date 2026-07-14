# server/routers/__init__.py
"""
API Routers — Organized by Track.

Each router handles one logical domain of the API:
- sync:           Track 1 — Sync Engine (/sync/*)
- devices:        Track 2 — Device Identity (/api/v1/devices/*)
- messages:       Track 3 — E2EE Messaging (/api/v1/messages/*)
- notifications:  Track 4+5 — Notifications & Settings (/api/v1/notifications/*)
"""
from routers import sync, devices, messages, notifications, attachments

__all__ = ["sync", "devices", "messages", "notifications", "attachments"]
