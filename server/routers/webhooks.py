# server/routers/webhooks.py
"""
Webhook Management & Manual Event Dispatch Router.

Endpoints:
- POST   /webhooks/register      — Register external Webhook HTTP POST callback
- GET    /webhooks/subscriptions — List active Webhooks
- DELETE /webhooks/{id}          — Remove Webhook subscription
- POST   /events/emit            — Manually trigger a domain event (support email, external CRM)
"""

from fastapi import APIRouter, HTTPException, Request, Depends
from pydantic import BaseModel
from typing import Optional, Dict, Any, List

from event_engine import iZiiEventEngine
from security_auth import require_admin, validate_outbound_url

# Đăng ký webhook = server sẽ TỰ GỌI RA URL đó → chỉ admin được phép (chống
# SSRF + lạm dụng). Toàn bộ router dưới đây yêu cầu X-iZii-Admin-Token.
router = APIRouter(prefix="/webhooks", tags=["Webhooks & Event Engine"],
                   dependencies=[Depends(require_admin)])
event_router = APIRouter(prefix="/events", tags=["Webhooks & Event Engine"],
                         dependencies=[Depends(require_admin)])

class WebhookRegisterModel(BaseModel):
    url: str
    event_filter: Optional[str] = "*"
    secret_token: Optional[str] = ""

class EventEmitModel(BaseModel):
    event_type: str
    data: Dict[str, Any]


@router.post("/register")
async def register_webhook(payload: WebhookRegisterModel):
    """
    Registers an external HTTP POST callback URL to receive real-time domain events.
    """
    # Chống SSRF: chặn loopback/private/link-local (gồm metadata cloud), resolve
    # DNS và kiểm mọi IP phân giải được. Thay cho denylist 3 host cũ (dễ lách
    # bằng 127.0.0.1, localhost, dải LAN, metadata.google.internal, IP thập phân).
    validate_outbound_url(payload.url)

    engine = iZiiEventEngine()
    res = engine.register_webhook(
        url=payload.url,
        event_filter=payload.event_filter or "*",
        secret_token=payload.secret_token or ""
    )
    return {"status": "success", "subscription": res}


@router.get("/subscriptions")
async def list_webhooks():
    """
    Lists all active Webhook subscriptions.
    """
    engine = iZiiEventEngine()
    subscriptions = engine.list_webhooks()
    return {"subscriptions": subscriptions, "count": len(subscriptions)}


@router.delete("/{webhook_id}")
async def unregister_webhook(webhook_id: str):
    """
    Unregisters/Deletes a Webhook subscription.
    """
    engine = iZiiEventEngine()
    success = engine.unregister_webhook(webhook_id)
    if not success:
        raise HTTPException(status_code=404, detail="Webhook subscription not found")
    return {"status": "success", "message": f"Deleted Webhook {webhook_id}"}


@event_router.post("/emit")
async def emit_event(payload: EventEmitModel, request: Request):
    """
    Manually triggers/emits a domain event (e.g. support email, customer registration, job addition).
    Broadcasts payload via WebSocket and dispatches HTTP Webhooks.
    """
    engine = iZiiEventEngine()
    ws_manager = getattr(request.app.state, "ws_manager", None)
    
    dispatched = await engine.dispatch_event(
        event_type=payload.event_type,
        data=payload.data,
        ws_manager=ws_manager,
    )
    return {"status": "success", "dispatched_event": dispatched}
