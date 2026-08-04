# server/routers/peer_sync.py
"""
Peer Sync Router — Server-to-Server (khác với sync.py là Device-to-Server).

Tái sử dụng đúng "sync_mutations" mutation log đã có, chỉ thêm 1 lớp relay
giữa các server: mỗi server định kỳ hỏi peer "cho tôi mutation từ mốc X",
rồi ghi lại local qua repo.push_mutations() — INSERT OR REPLACE theo id nên
tự động idempotent, không sợ trùng lặp khi gọi lại nhiều lần.

Vì đây là mutation log dạng "record thay đổi" (không phải bảng state), nên
KHÔNG cần thiết kế Last-Write-Wins ở tầng này — client (Drift) đã tự quyết
định cách áp dụng mutation khi pull về. Ràng buộc nghiệp vụ như unique
room_number vẫn cần được validate ở tầng client/business-logic khi tạo mới,
không phải ở tầng relay log này.

Endpoints:
- GET  /peer-sync/pull   — peer khác gọi vào để LẤY delta từ server này
- POST /peer-sync/push   — peer khác chủ động ĐẨY delta sang (dự phòng cho
                            Phase 4 khi chuyển sang event-based thay vì chỉ
                            polling)
- GET  /peer-sync/health — kiểm tra tình trạng + để mDNS/monitor dùng
"""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel

from dependencies import get_sync_repo
from repository.interface import ISyncRepository
from server_config import CONFIG

router = APIRouter(prefix="/peer-sync", tags=["Peer Sync (Server-to-Server)"])


def _verify_server_secret(x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token")):
    if CONFIG.server_secret and x_izii_server_token != CONFIG.server_secret:
        raise HTTPException(status_code=401, detail="Invalid or missing X-iZii-Server-Token")


class PeerMutationModel(BaseModel):
    id: str
    client_id: Optional[str] = None
    table: str
    operation: str
    data: dict
    origin_server_id: Optional[str] = None
    # Audit đi kèm mutation khi relay giữa các server — PHẢI giữ nguyên actor
    # gốc, không gán lại theo server đang relay.
    actor_user_id: Optional[str] = None
    actor_device_id: Optional[str] = None
    schema_version: Optional[int] = 1


class PeerPushPayload(BaseModel):
    from_server_id: str
    mutations: List[PeerMutationModel]


@router.get("/pull")
async def peer_pull(
    since: Optional[str] = None,
    after_seq: Optional[int] = None,
    limit: Optional[int] = None,
    requester_server_id: Optional[str] = None,
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
    repo: ISyncRepository = Depends(get_sync_repo),
):
    """
    Peer khác gọi vào để lấy delta. Ưu tiên `after_seq` — seq ở đây là seq
    TRONG LOG CỦA SERVER NÀY, peer chỉ việc lưu lại và gửi trả cho đúng server
    này ở lần sau. Nhờ vậy hai server lệch đồng hồ vẫn đồng bộ chính xác.
    """
    _verify_server_secret(x_izii_server_token)
    try:
        page = repo.pull_mutations(
            since=since,
            after_seq=after_seq,
            limit=limit,
            exclude_origin_server_id=requester_server_id,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    now_utc = datetime.now(timezone.utc).isoformat()
    if requester_server_id:
        try:
            repo.update_peer_sync_status(requester_server_id, last_seen_online_at=now_utc, zone=None)
        except Exception as e:
            print(f"⚠️  [PEER-SYNC] Could not update peer sync status for {requester_server_id}: {e}")

    print(
        f"🔁 [PEER-SYNC] {requester_server_id or 'unknown-peer'} pulled "
        f"{page['count']} mutations (after_seq={after_seq}, since={since}, "
        f"has_more={page['has_more']})"
    )
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "updates": page["updates"],
        "server_time": now_utc,
        "next_cursor": page["next_cursor"],
        "has_more": page["has_more"],
        "count": page["count"],
        "cursor_reset": page.get("cursor_reset", False),
    }


@router.post("/push")
async def peer_push(
    payload: PeerPushPayload,
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
    repo: ISyncRepository = Depends(get_sync_repo),
):
    _verify_server_secret(x_izii_server_token)
    if payload.from_server_id == CONFIG.server_id:
        raise HTTPException(status_code=400, detail="Không thể peer-sync với chính mình.")

    now_utc = datetime.now(timezone.utc).isoformat()
    mutations_dicts = [m.model_dump() for m in payload.mutations]

    try:
        count = repo.push_mutations(mutations_dicts, now_utc, default_origin_server_id=payload.from_server_id)
        repo.update_peer_sync_status(payload.from_server_id, last_seen_online_at=now_utc, zone=None)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    print(f"🔁 [PEER-SYNC] Nhận {count} mutations relay từ {payload.from_server_id}")
    return {"status": "success", "message": f"Applied {count} mutations from {payload.from_server_id}"}


@router.get("/health")
async def peer_health(
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
    repo: ISyncRepository = Depends(get_sync_repo),
):
    _verify_server_secret(x_izii_server_token)
    status = repo.get_status()
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "peers_configured": CONFIG.peers,
        "sync_status": status,
        "server_time": datetime.now(timezone.utc).isoformat(),
    }
