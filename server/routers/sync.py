# server/routers/sync.py
"""
Track 1 — Sync Engine Router.

Handles data synchronization between client devices and the server:
- POST /sync/push  — Client pushes local changes to server
- GET  /sync/pull  — Client pulls new changes from server
- GET  /sync/status — Server sync status summary
"""
import asyncio
import json
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import List, Optional, Dict, Tuple
from datetime import datetime, timezone

from dependencies import get_sync_repo
from repository.interface import ISyncRepository
from security_auth import DeviceIdentity, optional_device
from server_config import CONFIG
from event_engine import iZiiEventEngine

router = APIRouter(prefix="/sync", tags=["Sync Engine"])


class MutationModel(BaseModel):
    id: str
    client_id: Optional[str] = None
    table: str
    operation: str
    data: dict
    # Audit — AI đã tạo ra thay đổi này. Optional để bản app cũ chưa gửi vẫn
    # push được, nhưng nên bắt buộc khi tích hợp ERP/kiểm toán ATVSLĐ.
    actor_user_id: Optional[str] = None
    actor_device_id: Optional[str] = None
    # Phiên bản cấu trúc của trường `data`. Cho phép đổi schema về sau mà
    # consumer bên ngoài (adapter SAP/OPC) biết cách diễn giải đúng.
    schema_version: Optional[int] = 1


class PushPayload(BaseModel):
    mutations: List[MutationModel]
    # Cho phép gửi actor ở cấp payload thay vì lặp trong từng mutation.
    actor_user_id: Optional[str] = None
    actor_device_id: Optional[str] = None


_background_tasks = set()


# ══════════════════════════════════════════════════════════════════════════════
#  Ràng buộc nghiệp vụ: Room number là DUY NHẤT trong 1 zone
# ══════════════════════════════════════════════════════════════════════════════
# Đây là tầng chặn cứng duy nhất trong hệ thống. Trước đây logic này chỉ tồn
# tại trong file prototype không được nạp (_reference_sync_server_delta_sync
# .py.bak), nên thực tế KHÔNG có gì ngăn 2 zone tạo trùng số phòng.
#
# LƯU Ý VỀ DỮ LIỆU THẬT: payload `grow_rooms` mà client Flutter đẩy lên
# (xem lib/core/sync/sync_service.dart, hàm _upsertGrowRoom) gồm các field:
#   id, name, status, current_stage, day_in_cycle, targetYield, pickedYield,
#   pickingPlanJson, created_at, updated_at
# — tức là KHÔNG có `room_number` lẫn `zone` như bản thiết kế prototype giả
# định. Định danh phòng trên thực tế chính là `name`. Vì vậy hàm dưới đây ưu
# tiên `room_number` (nếu sau này client bổ sung) và fallback về `name`; zone
# lấy từ payload nếu có, không thì dùng zone của server đang nhận.

ROOM_TABLES = {"grow_rooms", "rooms"}


def _room_identity(data: dict) -> Optional[Tuple[str, str]]:
    """
    Trả về khoá định danh (zone, room_key) đã chuẩn hoá, hoặc None nếu không
    xác định được. Chuẩn hoá bằng strip + casefold để "Room 01", "room 01",
    " Room 01 " được coi là cùng một phòng.
    """
    raw = data.get("room_number") or data.get("roomNumber") or data.get("name")
    if raw is None:
        return None
    room_key = str(raw).strip().casefold()
    if not room_key:
        return None
    zone = str(data.get("zone") or CONFIG.zone).strip().casefold()
    return (zone, room_key)


def _assert_room_numbers_unique(repo: ISyncRepository, mutations: List[MutationModel]) -> None:
    """
    Chặn cứng trước khi ghi bất cứ thứ gì: nếu batch chứa 1 Room có
    (zone, room_number) đã thuộc về một record id KHÁC thì từ chối CẢ batch
    bằng HTTP 409, kèm id của record đang chiếm chỗ để client hiển thị cho
    Manager xử lý.

    Chạy trước repo.push_mutations() nên không có ghi nửa vời.
    """
    room_mutations = [m for m in mutations if m.table in ROOM_TABLES]
    if not room_mutations:
        return

    # Dựng index (zone, room_key) -> record_id từ mutation log hiện có.
    # Duyệt theo server_received_at tăng dần để mutation mới nhất của cùng 1
    # record ghi đè bản cũ (xử lý đúng trường hợp phòng được đổi tên).
    index: Dict[Tuple[str, str], str] = {}
    for table in {m.table for m in room_mutations}:
        for row in repo.get_mutations_by_table(table):
            record = row.get("data") or {}
            record_id = record.get("id")
            key = _room_identity(record)
            if key and record_id:
                index[key] = record_id

    for m in room_mutations:
        key = _room_identity(m.data)
        record_id = m.data.get("id")
        if not key or not record_id:
            # Không đủ thông tin để kiểm tra — để mutation đi qua thay vì
            # chặn nhầm dữ liệu hợp lệ nhưng thiếu field.
            continue

        holder = index.get(key)
        if holder and holder != record_id:
            zone, room_key = key
            print(
                f"⛔ [ROOM] Từ chối: phòng '{room_key}' trong zone '{zone}' đã thuộc "
                f"record id={holder}, không thể gán cho id={record_id}."
            )
            raise HTTPException(
                status_code=409,
                detail={
                    "error": "duplicate_room_number",
                    "message": (
                        f"Phòng '{m.data.get('room_number') or m.data.get('name')}' "
                        f"đã tồn tại trong zone '{zone}'. Cần đổi số phòng hoặc để "
                        f"Manager hợp nhất 2 bản ghi."
                    ),
                    "zone": zone,
                    "room_key": room_key,
                    "existing_record_id": holder,
                    "rejected_record_id": record_id,
                    "table": m.table,
                },
            )

        # Cập nhật index ngay để chặn được cả trùng lặp TRONG CÙNG 1 batch.
        index[key] = record_id


def _assert_alone_worker_has_session(
    mutations: List[MutationModel],
    device: Optional[DeviceIdentity],
) -> None:
    """
    Công việc Alone Worker BẮT BUỘC phải có phiên làm việc đang mở (G1).

    Đây là ràng buộc quan trọng nhất của toàn bộ tính năng điểm danh. Alone
    Worker là cơ chế an toàn lao động: khi công nhân quá giờ trong phòng kín,
    hệ thống phải báo được ĐÍCH DANH ai để đi tìm.

    Nếu chấp nhận tạo công việc mà không biết ai đang làm, cảnh báo sẽ chỉ nói
    được "máy nào" — vô dụng trong tình huống cần cứu người, và không có giá trị
    trong điều tra tai nạn.

    Chỉ ràng buộc đúng loại công việc này. Các công việc khác (tưới, phun thuốc)
    vẫn tạo được bình thường để không cản trở sản xuất.
    """
    alone_jobs = [
        m for m in mutations
        if m.table in ("mushroom_jobs", "jobs")
        and str(m.data.get("job_type", "")).lower() == "alone_worker"
        and str(m.operation).lower() in ("insert", "create")
    ]
    if not alone_jobs:
        return

    # Điều kiện đúng là "có xác định được ĐÍCH DANH ai không", chứ không phải
    # "có phiên hay không". Máy cá nhân của Manager/Supervisor đã biết chủ máy
    # từ lúc cấp nên thoả điều kiện mà không cần điểm danh — bắt họ điểm danh
    # trên iPhone riêng là thủ tục vô nghĩa, không tăng thêm chút an toàn nào.
    if device is None or not device.identity_is_known:
        print("⛔ [SESSION] Từ chối tạo Alone Worker: không xác định được người thực hiện.")
        raise HTTPException(
            status_code=409,
            detail={
                "error": "no_active_work_session",
                "message": (
                    "Chưa điểm danh đầu ca nên không tạo được công việc Làm việc một mình. "
                    "Cảnh báo an toàn cần biết ĐÍCH DANH ai đang trong phòng."
                ),
                "action": "check_in_required",
            },
        )


@router.post("/push")
async def sync_push(
    payload: PushPayload,
    request: Request,
    repo: ISyncRepository = Depends(get_sync_repo),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    now = datetime.now(timezone.utc).isoformat()

    print(f"\n{'='*50}")
    print(f"📥 [PUSH] Received {len(payload.mutations)} changes at {now}")
    print(f"{'='*50}")

    # Validate nghiệp vụ TRƯỚC khi ghi. HTTPException 409 phải thoát ra ngoài
    # nguyên vẹn, nên đặt ngoài khối try/except bên dưới (khối đó bọc mọi lỗi
    # thành 500).
    _assert_room_numbers_unique(repo, payload.mutations)
    _assert_alone_worker_has_session(payload.mutations, device)

    try:
        mutations_dicts = []
        for i, m in enumerate(payload.mutations):
            print(f"   [{i+1}] 🔹 Table: {m.table} | Operation: {m.operation}")
            for key, val in m.data.items():
                val_str = str(val)[:80]
                print(f"       - {key}: {val_str}")
            mutations_dicts.append(m.model_dump())

        # Danh tính LẤY TỪ TOKEN được ưu tiên hơn giá trị client tự khai:
        # client có thể gửi actor_device_id tuỳ ý, còn token thì server xác
        # thực được. Đây là điều làm audit trail đáng tin thay vì chỉ là ghi chú.
        count = repo.push_mutations(
            mutations_dicts,
            now,
            default_origin_server_id=CONFIG.server_id,
            actor_user_id=(device.user_id if device and device.user_id else payload.actor_user_id),
            actor_device_id=(device.device_id if device else payload.actor_device_id),
        )

        # Broadcast real-time domain events & Webhooks
        ws_manager = getattr(request.app.state, "ws_manager", None)
        engine = iZiiEventEngine()

        # Đọc danh sách webhook MỘT LẦN cho cả batch, khi connection của
        # request vẫn còn sống. Tuyệt đối KHÔNG truyền connection vào task nền:
        # dependencies.get_db() sẽ close() nó ngay khi response trả về, task
        # chạy sau đó sẽ gặp "Cannot operate on a closed database".
        webhook_rows = engine.fetch_webhook_rows(getattr(repo, "conn", None))

        for m in payload.mutations:
            event_type = engine.map_mutation_to_domain_event(m.table, m.operation, m.data)
            t = asyncio.create_task(
                engine.dispatch_event(
                    event_type=event_type,
                    data=m.data,
                    ws_manager=ws_manager,
                    origin_table=m.table,
                    webhook_rows=webhook_rows,
                    schema_version=m.schema_version or 1,
                    actor_user_id=m.actor_user_id or payload.actor_user_id,
                    actor_device_id=m.actor_device_id or payload.actor_device_id,
                )
            )
            _background_tasks.add(t)
            t.add_done_callback(_background_tasks.discard)

        if ws_manager:
            tables = list(set(m.table for m in payload.mutations))
            event_data = {
                "event": "sync_trigger",
                "data": {
                    "tables": tables,
                    "timestamp": now
                }
            }
            # Broadcast asynchronously
            t_ws = asyncio.create_task(ws_manager.broadcast(json.dumps(event_data), exclude=None))
            _background_tasks.add(t_ws)
            t_ws.add_done_callback(_background_tasks.discard)
            print(f"📡 [WS] Broadcasted sync_trigger for tables: {tables}")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return {"status": "success", "message": f"Processed {count} mutations"}


@router.get("/pull")
async def sync_pull(since: Optional[str] = None,
                    after_seq: Optional[int] = None,
                    limit: Optional[int] = None,
                    repo: ISyncRepository = Depends(get_sync_repo),
                    device: Optional[DeviceIdentity] = Depends(optional_device)):
    """
    Hai chế độ con trỏ, chọn theo tham số client gửi lên:

      - after_seq (NÊN DÙNG) : số thứ tự đơn điệu do server cấp. Không phụ
                               thuộc đồng hồ nên không bao giờ bỏ sót bản ghi.
      - since     (CŨ)       : chuỗi thời gian. Giữ lại để bản app chưa cập
                               nhật vẫn chạy được.

    Phản hồi LUÔN kèm `next_cursor` và `has_more`. Client PHẢI lặp lại lời gọi
    với `after_seq=next_cursor` cho tới khi `has_more=false`, nếu không sẽ chỉ
    nhận được trang đầu tiên.
    """
    now = datetime.now(timezone.utc).isoformat()

    print(f"\n📤 [PULL] The device is downloading new updates...")
    if after_seq is not None:
        print(f"   🔢 Filtered after_seq: {after_seq}")
    elif since:
        print(f"   🕐 Filtered since: {since} (che do cu — nen chuyen sang after_seq)")

    try:
        page = repo.pull_mutations(since=since, after_seq=after_seq, limit=limit)
        print(f"   📦 Sending {page['count']} records (has_more={page['has_more']})")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return {
        # Giữ nguyên tên trường cũ để client chưa cập nhật không vỡ.
        "updates": page["updates"],
        "timestamp": now,
        # Trường mới.
        "next_cursor": page["next_cursor"],
        "has_more": page["has_more"],
        "count": page["count"],
        # True = con trỏ client vượt quá log của server (thường do server vừa
        # bị reset dữ liệu). Server đã tự phục vụ lại từ đầu.
        "cursor_reset": page.get("cursor_reset", False),
        "server_id": CONFIG.server_id,
    }


@router.get("/status")
async def sync_status(repo: ISyncRepository = Depends(get_sync_repo)):
    try:
        status = repo.get_status()
        # max_seq cho phép client/adapter biết mình còn cách đuôi log bao xa.
        status["max_seq"] = repo.get_max_seq()
        status["server_id"] = CONFIG.server_id
        return status
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
