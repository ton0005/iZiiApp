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
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from dependencies import get_sync_repo
from repository.interface import ISyncRepository
from server_config import CONFIG

router = APIRouter(prefix="/peer-sync", tags=["Peer Sync (Server-to-Server)"])


class PeerMutationModel(BaseModel):
    id: str
    client_id: Optional[str] = None
    table: str
    operation: str
    data: dict
    origin_server_id: Optional[str] = None


class PeerPushPayload(BaseModel):
    from_server_id: str
    mutations: List[PeerMutationModel]


@router.get("/pull")
async def peer_pull(
    since: Optional[str] = None,
    requester_server_id: Optional[str] = None,
    repo: ISyncRepository = Depends(get_sync_repo),
):
    """
    Server khác (vd Server-M2) gọi endpoint này trên Server-M1 để hỏi:
    "cho tôi các mutation server_received_at > since".

    requester_server_id: nếu truyền vào, server này sẽ LOẠI BỎ các mutation
    có origin_server_id trùng với requester — vì requester chính là nơi tạo
    ra chúng, gửi lại chỉ tốn băng thông vô ích.
    """
    try:
        updates = repo.pull_mutations(since, exclude_origin_server_id=requester_server_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    print(
        f"🔁 [PEER-SYNC] {requester_server_id or 'unknown-peer'} pulled "
        f"{len(updates)} mutations (since={since})"
    )
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "updates": updates,
        "server_time": datetime.now().isoformat(),
    }


@router.post("/push")
async def peer_push(payload: PeerPushPayload, repo: ISyncRepository = Depends(get_sync_repo)):
    """
    Dự phòng cho Phase 4 (event-based): peer khác chủ động đẩy mutation sang
    ngay khi có thay đổi, thay vì đợi server này polling. Giữ nguyên
    origin_server_id gốc trong mỗi mutation — KHÔNG gán lại thành server
    hiện tại, để tránh vòng lặp relay (A relay cho B, B lại tưởng là của
    mình rồi relay ngược lại A).
    """
    if payload.from_server_id == CONFIG.server_id:
        raise HTTPException(status_code=400, detail="Không thể peer-sync với chính mình.")

    now = datetime.now().isoformat()
    mutations_dicts = [m.model_dump() for m in payload.mutations]

    try:
        # default_origin_server_id để trống — vì mutation từ peer luôn phải
        # có sẵn origin_server_id (được set từ lúc device gốc push vào peer đó).
        count = repo.push_mutations(mutations_dicts, now, default_origin_server_id=payload.from_server_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    print(f"🔁 [PEER-SYNC] Nhận {count} mutations relay từ {payload.from_server_id}")
    return {"status": "success", "message": f"Applied {count} mutations from {payload.from_server_id}"}


@router.get("/health")
async def peer_health(repo: ISyncRepository = Depends(get_sync_repo)):
    status = repo.get_status()
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "peers_configured": CONFIG.peers,
        "sync_status": status,
        "server_time": datetime.now().isoformat(),
    }
