# server/routers/notifications.py
"""
Track 4+5 — Notifications & Settings Router.

Handles in-app notifications and per-user notification preferences:
- GET  /api/v1/notifications          — Get all notifications for a user
- POST /api/v1/notifications/read     — Mark specific notifications as read
- POST /api/v1/notifications/read-all — Mark all notifications as read
- GET  /api/v1/notification-settings  — Get notification settings
- PUT  /api/v1/notification-settings  — Update notification settings
- POST /api/v1/notification-settings  — Update notification settings (alias)
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from dependencies import get_notification_repo
from repository.interface import INotificationRepository

router = APIRouter(tags=["Notifications"])


class NotificationReadPayload(BaseModel):
    user_id: str
    notification_ids: List[str]


class NotificationReadAllPayload(BaseModel):
    user_id: str


class NotificationSettingUpdatePayload(BaseModel):
    user_id: str
    event_type: str
    enable_push: Optional[bool] = True
    enable_in_app: Optional[bool] = True
    enable_email: Optional[bool] = True
    digest_frequency: Optional[str] = "instant"


@router.get("/api/v1/notifications")
async def notifications_get(user_id: str,
                              repo: INotificationRepository = Depends(get_notification_repo)):
    notifs = repo.get_notifications(user_id)
    return {"notifications": notifs}


@router.post("/api/v1/notifications/read")
async def notifications_read(body: NotificationReadPayload,
                               repo: INotificationRepository = Depends(get_notification_repo)):
    now = datetime.now().isoformat()
    
    try:
        updated_count = repo.mark_read(body.user_id, body.notification_ids, now)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    print(f"\n🔔 [NOTIF] Marked {updated_count} notification(s) as read for user {body.user_id}")
    return {"status": "success", "read_count": updated_count}


@router.post("/api/v1/notifications/read-all")
async def notifications_read_all(body: NotificationReadAllPayload,
                                   repo: INotificationRepository = Depends(get_notification_repo)):
    now = datetime.now().isoformat()
    
    try:
        updated_count = repo.mark_read_all(body.user_id, now)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    print(f"\n🔔 [NOTIF] Marked all ({updated_count}) notifications as read for user {body.user_id}")
    return {"status": "success", "read_count": updated_count}


@router.get("/api/v1/notification-settings")
async def notification_settings_get(user_id: str,
                                      repo: INotificationRepository = Depends(get_notification_repo)):
    settings = repo.get_settings(user_id)
    return {"settings": settings}


@router.put("/api/v1/notification-settings")
@router.post("/api/v1/notification-settings")
async def notification_settings_update(body: NotificationSettingUpdatePayload,
                                         repo: INotificationRepository = Depends(get_notification_repo)):
    try:
        repo.update_settings(body.model_dump())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    print(f"\n⚙️ [SETTINGS] Updated notifications config for user {body.user_id} - event {body.event_type}")
    return {"status": "success"}
