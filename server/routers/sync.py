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
from typing import List, Optional, Dict, Tuple, Any
from datetime import datetime, timezone

from dependencies import get_sync_repo, open_connection
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


def _job_assignee(data: dict) -> str:
    """Tên/mã người được phân công. Chấp nhận vài cách đặt tên trường."""
    for key in ("assignee", "assigned_to", "assignee_id", "employee_id", "user_id"):
        val = data.get(key)
        if val is not None and str(val).strip():
            return str(val).strip()
    return ""


def _filter_valid_mutations(
    conn,
    repo: ISyncRepository,
    mutations: List[MutationModel],
    device: Optional[DeviceIdentity],
) -> tuple[List[MutationModel], List[Dict[str, Any]]]:
    """
    Xác thực từng mutation độc lập (Partial Commit):
    - Các mutation hợp lệ được đưa vào danh sách `valid`.
    - Các mutation vi phạm nghiệp vụ (như Alone Worker chưa điểm danh hoặc trùng số phòng)
      được đưa vào danh sách `rejected` kèm lý do chi tiết.
    - Nhờ vậy, một mutation lỗi sẽ KHÔNG làm hủy toàn bộ các thay đổi hợp lệ khác trong batch.
    """
    valid: List[MutationModel] = []
    rejected: List[Dict[str, Any]] = []

    # 1. Kiểm tra trùng số phòng
    room_mutations = [m for m in mutations if m.table in ROOM_TABLES and str(m.operation).lower() in ("insert", "create")]
    room_index: Dict[Tuple[str, str], str] = {}
    if room_mutations:
        for table in {m.table for m in room_mutations}:
            for row in repo.get_mutations_by_table(table):
                record = row.get("data") or {}
                record_id = record.get("id")
                key = _room_identity(record)
                if key and record_id:
                    room_index[key] = record_id

    from routers.sessions import get_active_session_for_person

    for m in mutations:
        # A. Kiểm tra Room Number
        if m.table in ROOM_TABLES and str(m.operation).lower() in ("insert", "create"):
            key = _room_identity(m.data)
            record_id = m.data.get("id")
            if key and record_id:
                holder = room_index.get(key)
                if holder and holder != record_id:
                    zone, room_key = key
                    print(f"⛔ [ROOM] Từ chối: phòng '{room_key}' zone '{zone}' đã tồn tại id={holder}.")
                    rejected.append({
                        "id": record_id or m.data.get("id"),
                        "table": m.table,
                        "operation": m.operation,
                        "error": "duplicate_room_number",
                        "message": f"Phòng '{m.data.get('room_number') or m.data.get('name')}' đã tồn tại trong zone '{zone}'.",
                    })
                    continue
                room_index[key] = record_id

        # B. Kiểm tra Alone Worker
        if (
            m.table in ("mushroom_jobs", "jobs")
            and str(m.data.get("job_type", "")).lower() == "alone_worker"
            and str(m.operation).lower() in ("insert", "create")
        ):
            assignee = _job_assignee(m.data)
            if assignee:
                session = None
                try:
                    session = get_active_session_for_person(conn, assignee)
                except Exception as e:
                    print(f"⚠️  [SESSION] Không tra được phiên của '{assignee}': {e}")

                if session is None:
                    print(f"⛔ [SESSION] Từ chối Alone Worker: '{assignee}' chưa điểm danh.")
                    rejected.append({
                        "id": m.data.get("id"),
                        "table": m.table,
                        "operation": m.operation,
                        "error": "assignee_not_checked_in",
                        "assignee": assignee,
                        "message": f"'{assignee}' chưa điểm danh đầu ca nên không giao được công việc Làm việc một mình.",
                        "action": "assignee_check_in_required",
                    })
                    continue
                else:
                    print(f"✅ [SESSION] '{session['user_name'] or session['user_id']}' đang trong ca — hợp lệ.")
            else:
                if device is None or not device.identity_is_known:
                    print("⛔ [SESSION] Từ chối Alone Worker: không xác định được người thực hiện.")
                    rejected.append({
                        "id": m.data.get("id"),
                        "table": m.table,
                        "operation": m.operation,
                        "error": "no_active_work_session",
                        "message": "Chưa điểm danh đầu ca nên không tạo được công việc Làm việc một mình.",
                        "action": "check_in_required",
                    })
                    continue

        # Mutation hợp lệ
        valid.append(m)

    return valid, rejected


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

    # Partial commit: Lọc riêng các mutation hợp lệ và các mutation bị từ chối
    with open_connection() as _session_conn:
        valid_mutations, rejected_mutations = _filter_valid_mutations(
            _session_conn, repo, payload.mutations, device
        )

    # Nếu tất cả các item đều bị từ chối và không có item hợp lệ nào
    if not valid_mutations and rejected_mutations:
        first_err = rejected_mutations[0]
        raise HTTPException(
            status_code=409,
            detail={
                "error": first_err.get("error", "all_mutations_rejected"),
                "message": first_err.get("message", "Tất cả các thay đổi đều bị từ chối."),
                "rejected": rejected_mutations,
            },
        )

    count = 0
    try:
        if valid_mutations:
            mutations_dicts = []
            for i, m in enumerate(valid_mutations):
                print(f"   [{i+1}] 🔹 Table: {m.table} | Operation: {m.operation}")
                for key, val in m.data.items():
                    val_str = str(val)[:80]
                    print(f"       - {key}: {val_str}")
                mutations_dicts.append(m.model_dump())

            count = repo.push_mutations(
                mutations_dicts,
                now,
                default_origin_server_id=CONFIG.server_id,
                actor_user_id=(device.user_id if device and device.user_id else payload.actor_user_id),
                actor_device_id=(device.device_id if device else payload.actor_device_id),
            )

            # Broadcast real-time domain events & Webhooks cho các mutation hợp lệ
            ws_manager = getattr(request.app.state, "ws_manager", None)
            engine = iZiiEventEngine()
            webhook_rows = engine.fetch_webhook_rows(getattr(repo, "conn", None))

            for m in valid_mutations:
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
                tables = list(set(m.table for m in valid_mutations))
                event_data = {
                    "event": "sync_trigger",
                    "data": {
                        "tables": tables,
                        "timestamp": now
                    }
                }
                t_ws = asyncio.create_task(ws_manager.broadcast(json.dumps(event_data), exclude=None))
                _background_tasks.add(t_ws)
                t_ws.add_done_callback(_background_tasks.discard)
                print(f"📡 [WS] Broadcasted sync_trigger for tables: {tables}")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return {
        "status": "success" if not rejected_mutations else "partial_success",
        "message": f"Processed {count} mutations ({len(rejected_mutations)} rejected)",
        "accepted_count": count,
        "rejected_count": len(rejected_mutations),
        "rejected": rejected_mutations,
    }


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


@router.get("/record/{table}/{record_id}")
async def get_record_by_id(
    table: str,
    record_id: str,
    repo: ISyncRepository = Depends(get_sync_repo),
):
    """
    Endpoint P0.1c: Lấy bản ghi đầy đủ hiện tại theo table và record_id.
    Dùng cho client/projector khi nhận lệnh UPDATE cho một bản ghi chưa tồn tại
    ở local SQLite, ngăn chặn việc tạo bản ghi ma (Untitled Task / rỗng).
    """
    try:
        record = repo.get_record(table, record_id)
        if not record:
            raise HTTPException(
                status_code=404,
                detail=f"Record '{record_id}' not found in table '{table}'",
            )
        return record
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

