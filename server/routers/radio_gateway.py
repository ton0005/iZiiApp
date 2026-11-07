# server/routers/radio_gateway.py
"""
Tích hợp bộ đàm Hytera (DMR: HP68X/HP70X/HP78X/HP79XEx — TETRA: PT580H) với
tính năng Alone Worker.

LUỒNG:

    [Bộ đàm] --RF--> [Repeater RD98X / HR1062] --IP--> [Gateway điều phối]
        --HTTP POST /api/v1/radio/events (X-iZii-Radio-Token)--> [iZiiServer]

Bộ đàm tự đếm Lone Worker (Response Time + Reminder) và tự phát hiện Man Down
bằng cảm biến nghiêng; khi hết giờ mà công nhân không bấm phím, máy kích hoạt
Emergency System và gửi Radio ID (+ GPS nếu có) về gateway. Server KHÔNG đếm
giờ thay bộ đàm — chỉ nhận kết quả và nối nó vào luồng Alone Worker có sẵn:

  1. Lưu cảnh báo vào radio_events TRƯỚC mọi việc khác — mất kết nối DB phía
     sau cũng không được làm mất cảnh báo tính mạng.
  2. Tra Radio ID → nhân viên (radio_devices) → công việc Alone Worker đang
     chạy của người đó.
  3. Có job: đẩy mutation bật `mushroom_jobs.alarm_triggered` + đưa phòng về
     `alone_timeout` + ghi `mushroom_safety_checkin_logs`. Đây đúng là các cờ
     mà UI cảnh báo Alone Worker trên app đang theo dõi, nên mọi máy hiện báo
     động ngay khi đồng bộ, kể cả máy đang offline lúc sự kiện xảy ra.
  4. Không có job / bộ đàm chưa gán: VẪN là báo động. Phát `mushroom.radio_alarm`
     qua WebSocket + webhook để màn hình trực ban hiển thị — một nút SOS không
     được phép bị nuốt chỉ vì thiếu cấu hình.

PHẠM VI BÍ MẬT: gateway dùng IZIIAPP_RADIO_GATEWAY_SECRET riêng (fail-closed).
Xem bảng ba phạm vi trong security_auth.py — đây là phạm vi thứ tư, cố ý không
dùng lại admin/server secret vì gateway là phần mềm bên thứ ba.
"""
from __future__ import annotations

import asyncio
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

import radio_events as re_
from database import sql
from dependencies import make_sync_repo, open_connection
from event_engine import iZiiEventEngine
from security_auth import _constant_time_eq, lookup_device_by_token
from server_config import CONFIG

router = APIRouter(prefix="/api/v1/radio", tags=["Radio Gateway (Hytera)"])

MAX_BATCH = 100
# Trạng thái cảnh báo còn cần người xử lý.
ACTIVE_STATUSES = ("open", "cancelled_on_radio")
# Dùng toạ độ cuối cùng đã biết khi gói báo động không kèm GPS, nếu nó đủ mới.
LAST_KNOWN_LOCATION_MAX_AGE = timedelta(minutes=15)

_background_tasks: set = set()


# ── Xác thực ────────────────────────────────────────────────────────────────

async def require_radio_gateway(
    x_izii_radio_token: Optional[str] = Header(None, alias="X-iZii-Radio-Token"),
    authorization: Optional[str] = Header(None),
) -> None:
    """
    Nhận token qua X-iZii-Radio-Token HOẶC `Authorization: Bearer <token>` —
    nhiều phần mềm điều phối chỉ cho cấu hình Bearer trên webhook, không cho
    thêm header tuỳ ý.
    """
    if not x_izii_radio_token and authorization and authorization.lower().startswith("bearer "):
        x_izii_radio_token = authorization[7:].strip()
    if not CONFIG.radio_gateway_secret:
        raise HTTPException(
            503,
            "Server chưa cấu hình IZIIAPP_RADIO_GATEWAY_SECRET — từ chối sự kiện bộ đàm.",
        )
    if not _constant_time_eq(x_izii_radio_token, CONFIG.radio_gateway_secret):
        raise HTTPException(401, "Invalid or missing X-iZii-Radio-Token")


def _admin_ok(token: Optional[str]) -> bool:
    return bool(CONFIG.admin_secret) and _constant_time_eq(token, CONFIG.admin_secret)


async def require_admin_token(
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
) -> str:
    if not _admin_ok(x_izii_admin_token):
        raise HTTPException(401, "Invalid or missing X-iZii-Admin-Token")
    return "admin"


async def require_operator(
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
) -> str:
    """
    Xem / xác nhận cảnh báo: máy đã enroll (device token) hoặc quản trị. Khác
    /sync/* ở chỗ KHÔNG có chế độ mở — xác nhận cảnh báo phải ghi được ai làm.
    Trả về tên người thao tác để ghi audit.
    """
    if _admin_ok(x_izii_admin_token):
        return "admin"
    if x_izii_device_token:
        try:
            with open_connection() as conn:
                ident = lookup_device_by_token(conn, x_izii_device_token)
        except Exception as e:
            print(f"⚠️  [RADIO] Lỗi tra device token: {e}")
            ident = None
        if ident is not None:
            return ident.user_name or ident.user_id or ident.device_id
    raise HTTPException(401, "Cần X-iZii-Device-Token hoặc X-iZii-Admin-Token hợp lệ.")


# ── Tiện ích DB (chạy được trên cả SQLite lẫn Postgres) ─────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _one(conn, query: str, params: tuple = ()) -> Optional[Dict[str, Any]]:
    row = conn.execute(sql(query), params).fetchone()
    return dict(row) if row is not None else None


def _all(conn, query: str, params: tuple = ()) -> List[Dict[str, Any]]:
    return [dict(r) for r in conn.execute(sql(query), params).fetchall()]


def _parse_iso(value: Any) -> Optional[datetime]:
    try:
        dt = datetime.fromisoformat(str(value))
    except (TypeError, ValueError):
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _alarm_view(row: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(row)
    out.pop("payload", None)
    out["is_alarm"] = bool(out.get("is_alarm"))
    out["unbound"] = not (out.get("employee_id") or out.get("employee_name"))
    return out


# ── Nghiệp vụ ───────────────────────────────────────────────────────────────

def _touch_device(conn, ev: Dict[str, Any], now: str) -> Dict[str, Any]:
    """
    Cập nhật "lần cuối thấy" của bộ đàm. Bộ đàm lạ được TỰ THÊM (chưa gán
    người) để quản lý thấy nó trong danh sách và gán — thay vì phải gõ tay
    Radio ID đúng từng chữ số.
    """
    radio_id = ev["radio_id"]
    dev = _one(conn, "SELECT * FROM radio_devices WHERE radio_id = ?", (radio_id,))
    has_fix = ev["latitude"] is not None
    if dev is None:
        conn.execute(
            sql(
                "INSERT INTO radio_devices (radio_id, system, model, label, active, last_seen_at, "
                "last_event_type, last_latitude, last_longitude, last_located_at, last_battery, "
                "created_at, updated_at, updated_by) VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            ),
            (
                radio_id, ev["system"] or "dmr", ev["model"], ev.get("alias"), now, ev["event_type"],
                ev["latitude"], ev["longitude"], now if has_fix else None, ev["battery"],
                now, now, "radio-gateway",
            ),
        )
    else:
        conn.execute(
            sql(
                "UPDATE radio_devices SET last_seen_at = ?, last_event_type = ?, "
                "last_latitude = COALESCE(?, last_latitude), last_longitude = COALESCE(?, last_longitude), "
                "last_located_at = COALESCE(?, last_located_at), last_battery = COALESCE(?, last_battery), "
                "model = COALESCE(model, ?), system = COALESCE(system, ?), label = COALESCE(label, ?) "
                "WHERE radio_id = ?"
            ),
            (
                now, ev["event_type"], ev["latitude"], ev["longitude"],
                now if has_fix else None, ev["battery"], ev["model"], ev["system"], ev.get("alias"), radio_id,
            ),
        )
    return _one(conn, "SELECT * FROM radio_devices WHERE radio_id = ?", (radio_id,)) or {}


def _build_alarm_mutations(
    repo, alarm: Dict[str, Any], device: Dict[str, Any], now: str,
) -> tuple[Optional[Dict[str, Any]], List[Dict[str, Any]]]:
    """Tìm job Alone Worker đang chạy của người cầm máy → mutation bật báo động."""
    emp_id, emp_name = device.get("employee_id"), device.get("employee_name")
    if not (emp_id or emp_name):
        return None, []

    jobs = re_.fold_records(repo.get_mutations_by_table("mushroom_jobs"))
    job = re_.find_active_solo_job(jobs, emp_id, emp_name)
    if job is None:
        return None, []

    label = {re_.SOS: "SOS", re_.MAN_DOWN: "MAN DOWN", re_.LONE_WORKER: "LONE WORKER TIMEOUT"}
    model = device.get("model") or "Hytera"
    notes = (
        f"Radio alarm {label.get(alarm['event_type'], alarm['event_type'])} "
        f"from {model} radio {alarm['radio_id']}"
    )
    if alarm.get("latitude") is not None:
        notes += f" @ {alarm['latitude']:.6f},{alarm['longitude']:.6f}"

    mutations = [
        {
            "id": f"radio-{uuid.uuid4().hex}",
            "table": "mushroom_jobs",
            "operation": "update",
            "data": {"id": job["id"], "alarm_triggered": True, "updated_at": now},
        },
        {
            "id": f"radio-{uuid.uuid4().hex}",
            "table": "mushroom_safety_checkin_logs",
            "operation": "insert",
            "data": {
                "id": f"radio_{alarm['id']}",
                "job_id": job["id"],
                "worker_id": str(job.get("assignee") or emp_name or emp_id),
                "event_type": alarm["event_type"],
                "gps_latitude": alarm.get("latitude"),
                "gps_longitude": alarm.get("longitude"),
                "notes": notes,
                "timestamp": now,
            },
        },
    ]
    room_id = job.get("room_id")
    if room_id:
        rooms = re_.fold_records(repo.get_mutations_by_table("grow_rooms"))
        room_name = (rooms.get(room_id) or {}).get("name")
        room_data = {
            "id": room_id, "status": "active", "current_stage": "alone_timeout", "updated_at": now,
        }
        # Client chặn trùng số phòng theo tên — không gửi tên rỗng.
        if room_name and str(room_name).strip():
            room_data["name"] = str(room_name).strip()
        mutations.append({
            "id": f"radio-{uuid.uuid4().hex}", "table": "grow_rooms",
            "operation": "update", "data": room_data,
        })
    return job, mutations


def ingest_event(conn, repo, ev: Dict[str, Any], raw: Dict[str, Any]) -> Dict[str, Any]:
    """
    Xử lý MỘT sự kiện đã chuẩn hoá. Trả về:
      {result: created|repeat|duplicate|updated|logged, alarm?, pushed_tables}
    """
    now = _now()
    radio_id, etype = ev["radio_id"], ev["event_type"]

    # Gateway gửi lại khi timeout (retry) → cùng gateway_event_id → bỏ qua.
    # Khoá gồm cả loại sự kiện: điều phối thường dùng lại eventId của báo động
    # cho gói "CLEARED" — gói kết thúc đó phải được xử lý, không bị coi là trùng.
    event_key = (
        f"gw:{radio_id}:{ev['gateway_event_id']}:{etype}" if ev["gateway_event_id"] else None
    )
    if event_key:
        dup = _one(conn, "SELECT * FROM radio_events WHERE event_key = ?", (event_key,))
        if dup:
            return {"result": "duplicate", "alarm": _alarm_view(dup), "pushed_tables": []}

    device = _touch_device(conn, ev, now)

    if etype in (re_.LOCATION, re_.PRESENCE):
        # Không lưu từng gói GPS định kỳ thành sự kiện — 100 máy báo 30 giây
        # một lần sẽ làm phình bảng; vị trí cuối đã nằm trong radio_devices.
        conn.commit()
        return {"result": "updated", "pushed_tables": []}

    if etype == re_.EMERGENCY_CANCEL:
        # Công nhân huỷ khẩn cấp trên máy: ghi nhận, nhưng KHÔNG tự đóng cảnh
        # báo — giám sát vẫn phải xác nhận đã liên lạc được người đó.
        conn.execute(
            sql(
                "UPDATE radio_events SET status = 'cancelled_on_radio', last_received_at = ? "
                "WHERE radio_id = ? AND status = 'open'"
            ),
            (now, radio_id),
        )

    if ev["is_alarm"]:
        cutoff = (datetime.now(timezone.utc) - timedelta(seconds=CONFIG.radio_alarm_dedup_seconds)).isoformat()
        existing = _one(
            conn,
            "SELECT * FROM radio_events WHERE radio_id = ? AND event_type = ? AND status = 'open' "
            "AND last_received_at >= ? ORDER BY received_at DESC LIMIT 1",
            (radio_id, etype, cutoff),
        )
        if existing:
            # Gói phát lại theo Tx Cycles — gộp, chỉ bổ sung toạ độ nếu có.
            conn.execute(
                sql(
                    "UPDATE radio_events SET repeat_count = repeat_count + 1, last_received_at = ?, "
                    "latitude = COALESCE(?, latitude), longitude = COALESCE(?, longitude) WHERE id = ?"
                ),
                (now, ev["latitude"], ev["longitude"], existing["id"]),
            )
            conn.commit()
            row = _one(conn, "SELECT * FROM radio_events WHERE id = ?", (existing["id"],))
            return {"result": "repeat", "alarm": _alarm_view(row or existing), "pushed_tables": []}

    lat, lng = ev["latitude"], ev["longitude"]
    if ev["is_alarm"] and lat is None and device.get("last_latitude") is not None:
        located = _parse_iso(device.get("last_located_at"))
        if located and datetime.now(timezone.utc) - located <= LAST_KNOWN_LOCATION_MAX_AGE:
            lat, lng = device["last_latitude"], device["last_longitude"]

    alarm = {
        "id": f"ralm_{uuid.uuid4().hex[:16]}",
        "event_key": event_key,
        "radio_id": radio_id,
        "system": ev["system"] or device.get("system"),
        "event_type": etype,
        "raw_event_type": ev["raw_event_type"],
        "is_alarm": 1 if ev["is_alarm"] else 0,
        "status": "open" if ev["is_alarm"] else "info",
        "occurred_at": ev["occurred_at"],
        "received_at": now,
        "last_received_at": now,
        "repeat_count": 0,
        "latitude": lat,
        "longitude": lng,
        "employee_id": device.get("employee_id"),
        "employee_name": device.get("employee_name"),
        "job_id": None,
        "room_id": None,
        "payload": json.dumps(raw, ensure_ascii=False, default=str)[:8000],
    }
    cols = list(alarm.keys())
    conn.execute(
        sql(f"INSERT INTO radio_events ({', '.join(cols)}) VALUES ({', '.join('?' for _ in cols)})"),
        tuple(alarm[c] for c in cols),
    )
    # Commit NGAY: từ đây cảnh báo đã bền vững dù bước nối job phía sau lỗi.
    conn.commit()

    if not ev["is_alarm"]:
        return {"result": "logged", "alarm": _alarm_view(alarm), "pushed_tables": []}

    pushed: List[str] = []
    try:
        job, mutations = _build_alarm_mutations(repo, alarm, device, now)
        if job is not None:
            alarm["job_id"], alarm["room_id"] = job["id"], job.get("room_id")
            conn.execute(
                sql("UPDATE radio_events SET job_id = ?, room_id = ? WHERE id = ?"),
                (alarm["job_id"], alarm["room_id"], alarm["id"]),
            )
            conn.commit()
            repo.push_mutations(
                mutations, now,
                default_origin_server_id=CONFIG.server_id,
                actor_user_id=f"radio:{radio_id}",
                actor_device_id="radio-gateway",
            )
            pushed = sorted({m["table"] for m in mutations})
    except Exception as e:
        # Cảnh báo đã lưu và vẫn được phát qua WebSocket; chỉ mất phần gắn job.
        print(f"⛔ [RADIO] Không gắn được báo động {alarm['id']} vào job Alone Worker: {e}")

    print(
        f"🚨 [RADIO] {etype.upper()} radio={radio_id} "
        f"employee={alarm['employee_name'] or alarm['employee_id'] or 'CHƯA GÁN'} job={alarm['job_id']}"
    )
    return {"result": "created", "alarm": _alarm_view(alarm), "pushed_tables": pushed}


def _ingest_batch(items: List[tuple[Dict[str, Any], Dict[str, Any]]]) -> List[Dict[str, Any]]:
    with open_connection() as conn:
        repo = make_sync_repo(conn)
        return [ingest_event(conn, repo, ev, raw) for ev, raw in items]


async def _broadcast(request: Request, results: List[Dict[str, Any]], actor: str) -> None:
    ws_manager = getattr(request.app.state, "ws_manager", None)
    engine = iZiiEventEngine()

    def _spawn(coro):
        t = asyncio.create_task(coro)
        _background_tasks.add(t)
        t.add_done_callback(_background_tasks.discard)

    tables: set = set()
    for r in results:
        tables.update(r.get("pushed_tables") or [])
        alarm = r.get("alarm")
        if alarm and r["result"] in ("created", "acknowledged"):
            # Tiền tố 'mushroom.' để MushroomsBloc tự tải lại phòng; webhook
            # lọc 'mushroom.radio_*' để nối SMS / còi đèn bên ngoài.
            event_type = "mushroom.radio_alarm" if r["result"] == "created" else "mushroom.radio_alarm_acknowledged"
            _spawn(engine.dispatch_event(
                event_type=event_type, data=alarm, ws_manager=ws_manager,
                origin_table="radio_events", actor_user_id=actor, actor_device_id="radio-gateway",
            ))
    if ws_manager and tables:
        msg = {"event": "sync_trigger", "data": {"tables": sorted(tables), "timestamp": _now()}}
        _spawn(ws_manager.broadcast(json.dumps(msg), exclude=None))


# ── Endpoints: gateway ──────────────────────────────────────────────────────

@router.post("/events", dependencies=[Depends(require_radio_gateway)])
async def radio_events_ingest(request: Request):
    """
    Nhận sự kiện từ gateway điều phối bộ đàm. Body là MỘT object, một mảng,
    hoặc {"events": [...]}. Tên trường linh hoạt (xem radio_events.py), tối
    thiểu cần radio_id + event_type.
    """
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(400, "Body phải là JSON.")
    raw_events = body.get("events") if isinstance(body, dict) and "events" in body else body
    if isinstance(raw_events, dict):
        raw_events = [raw_events]
    if not isinstance(raw_events, list) or not raw_events:
        raise HTTPException(400, "Không có sự kiện nào.")
    if len(raw_events) > MAX_BATCH:
        raise HTTPException(413, f"Tối đa {MAX_BATCH} sự kiện mỗi request.")

    items, rejected = [], []
    for idx, raw in enumerate(raw_events):
        try:
            items.append((re_.normalize_event(raw), raw))
        except re_.RadioEventError as e:
            rejected.append({"index": idx, "error": str(e)})

    results = await run_in_threadpool(_ingest_batch, items) if items else []
    await _broadcast(request, results, actor="radio-gateway")
    return {
        "status": "success" if not rejected else "partial_success",
        "accepted": len(results),
        "alarms_created": sum(1 for r in results if r["result"] == "created"),
        "results": [
            {"result": r["result"], "alarm_id": (r.get("alarm") or {}).get("id"),
             "job_id": (r.get("alarm") or {}).get("job_id")}
            for r in results
        ],
        "rejected": rejected,
    }


# ── Endpoints: app (trực ban / quản lý) ─────────────────────────────────────

@router.get("/alarms")
def radio_alarms_list(
    status: str = "active",
    limit: int = 100,
    actor: str = Depends(require_operator),
):
    limit = max(1, min(limit, 500))
    with open_connection() as conn:
        if status == "active":
            rows = _all(
                conn,
                "SELECT * FROM radio_events WHERE is_alarm = 1 AND status IN (?, ?) "
                "ORDER BY received_at DESC LIMIT ?",
                (*ACTIVE_STATUSES, limit),
            )
        else:
            rows = _all(conn, "SELECT * FROM radio_events ORDER BY received_at DESC LIMIT ?", (limit,))
    return {"alarms": [_alarm_view(r) for r in rows], "count": len(rows)}


class AckPayload(BaseModel):
    note: Optional[str] = None


@router.post("/alarms/{alarm_id}/ack")
async def radio_alarm_ack(
    alarm_id: str, body: AckPayload, request: Request, actor: str = Depends(require_operator),
):
    """
    Giám sát xác nhận ĐÃ TIẾP NHẬN cảnh báo (đang liên lạc / đang tới hiện
    trường). Không tự tắt báo động của job — việc đó vẫn đi qua luồng
    check-in / dismiss Alone Worker trên app sau khi đã gặp được công nhân.
    """
    def _do() -> Dict[str, Any]:
        now = _now()
        with open_connection() as conn:
            row = _one(conn, "SELECT * FROM radio_events WHERE id = ?", (alarm_id,))
            if row is None:
                raise HTTPException(404, "Không tìm thấy cảnh báo.")
            if row["status"] not in ACTIVE_STATUSES:
                return {"result": "unchanged", "alarm": _alarm_view(row), "pushed_tables": []}
            conn.execute(
                sql("UPDATE radio_events SET status = 'acknowledged', acked_at = ?, acked_by = ?, ack_note = ? WHERE id = ?"),
                (now, actor, body.note, alarm_id),
            )
            conn.commit()
            pushed: List[str] = []
            if row.get("job_id"):
                repo = make_sync_repo(conn)
                repo.push_mutations(
                    [{
                        "id": f"radio-{uuid.uuid4().hex}",
                        "table": "mushroom_safety_checkin_logs",
                        "operation": "insert",
                        "data": {
                            "id": f"radio_ack_{alarm_id}",
                            "job_id": row["job_id"],
                            "worker_id": str(row.get("employee_name") or row.get("employee_id") or row["radio_id"]),
                            "event_type": "radio_alarm_ack",
                            "notes": f"Radio alarm acknowledged by {actor}" + (f": {body.note}" if body.note else ""),
                            "timestamp": now,
                        },
                    }],
                    now, default_origin_server_id=CONFIG.server_id, actor_user_id=actor,
                )
                pushed = ["mushroom_safety_checkin_logs"]
            updated = _one(conn, "SELECT * FROM radio_events WHERE id = ?", (alarm_id,)) or row
            return {"result": "acknowledged", "alarm": _alarm_view(updated), "pushed_tables": pushed}

    result = await run_in_threadpool(_do)
    await _broadcast(request, [result], actor=actor)
    return {"status": "success", "result": result["result"], "alarm": result["alarm"]}


@router.get("/devices")
def radio_devices_list(actor: str = Depends(require_operator)):
    with open_connection() as conn:
        rows = _all(conn, "SELECT * FROM radio_devices ORDER BY radio_id")
    for r in rows:
        r["active"] = bool(r.get("active"))
    return {"devices": rows, "count": len(rows)}


class RadioDevicePayload(BaseModel):
    employee_id: Optional[str] = None
    employee_name: Optional[str] = None
    label: Optional[str] = None
    model: Optional[str] = None
    system: Optional[str] = None  # 'dmr' | 'tetra'
    active: Optional[bool] = True


@router.put("/devices/{radio_id}")
def radio_device_upsert(radio_id: str, body: RadioDevicePayload, actor: str = Depends(require_admin_token)):
    """Gán / đổi người giữ bộ đàm. Gửi employee_id & employee_name rỗng để thu hồi."""
    radio_id = radio_id.strip()
    if not radio_id:
        raise HTTPException(400, "radio_id rỗng.")
    system = (body.system or "dmr").strip().lower()
    if system not in ("dmr", "tetra"):
        raise HTTPException(400, "system phải là 'dmr' hoặc 'tetra'.")
    now = _now()
    emp_id = (body.employee_id or "").strip() or None
    emp_name = (body.employee_name or "").strip() or None
    with open_connection() as conn:
        exists = _one(conn, "SELECT radio_id FROM radio_devices WHERE radio_id = ?", (radio_id,))
        if exists:
            conn.execute(
                sql(
                    "UPDATE radio_devices SET employee_id = ?, employee_name = ?, label = ?, "
                    "model = COALESCE(?, model), system = ?, active = ?, updated_at = ?, updated_by = ? "
                    "WHERE radio_id = ?"
                ),
                (emp_id, emp_name, body.label, body.model, system, 1 if body.active else 0, now, actor, radio_id),
            )
        else:
            conn.execute(
                sql(
                    "INSERT INTO radio_devices (radio_id, system, model, label, employee_id, employee_name, "
                    "active, created_at, updated_at, updated_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                ),
                (radio_id, system, body.model, body.label, emp_id, emp_name,
                 1 if body.active else 0, now, now, actor),
            )
        conn.commit()
        row = _one(conn, "SELECT * FROM radio_devices WHERE radio_id = ?", (radio_id,)) or {}
    row["active"] = bool(row.get("active"))
    return {"status": "success", "device": row}


@router.delete("/devices/{radio_id}")
def radio_device_delete(radio_id: str, actor: str = Depends(require_admin_token)):
    with open_connection() as conn:
        conn.execute(sql("DELETE FROM radio_devices WHERE radio_id = ?"), (radio_id,))
        conn.commit()
    return {"status": "success"}


class SimulatePayload(BaseModel):
    radio_id: str
    event_type: str = "SOS"
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@router.post("/simulate")
async def radio_simulate(body: SimulatePayload, request: Request, actor: str = Depends(require_admin_token)):
    """
    Nghiệm thu phía app khi chưa có gateway: bơm một sự kiện giả qua ĐÚNG
    đường xử lý thật. Báo động giả vẫn bật cảnh báo job thật — chỉ dùng khi
    đã báo trước cho ca trực.
    """
    raw = {**body.model_dump(), "simulated": True, "simulated_by": actor}
    try:
        ev = re_.normalize_event(raw)
    except re_.RadioEventError as e:
        raise HTTPException(400, str(e))
    results = await run_in_threadpool(_ingest_batch, [(ev, raw)])
    await _broadcast(request, results, actor=actor)
    return {"status": "success", **results[0]}


# ── Lệnh iZii → bộ đàm (qua radio_bridge) ───────────────────────────────────
#
# Server KHÔNG nói chuyện trực tiếp với bộ đàm: nó xếp lệnh vào radio_commands,
# bridge (gần repeater) lấy lệnh, gửi xuống bộ đàm rồi báo kết quả. Hai lý do:
# bridge là nơi duy nhất có kết nối HSTRP tới repeater, và hàng đợi trên DB giữ
# được lệnh khi bridge tạm mất kết nối.
#
# Vòng đời: pending → sent (bridge đã nhận, có hạn thuê) → done | failed;
# pending quá COMMAND_TTL → expired (tin "time out" cũ cả giờ thì gửi cũng vô ích).

COMMANDS = ("lone_worker_status", "lone_worker_enable", "lone_worker_disable", "text_message")
COMMAND_LEASE = timedelta(seconds=30)
COMMAND_MAX_ATTEMPTS = 3
COMMAND_TTL = timedelta(minutes=10)
MAX_TEXT_LEN = 140


def _command_view(row: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(row)
    for k in ("params", "result"):
        try:
            out[k] = json.loads(out[k]) if out.get(k) else None
        except (TypeError, ValueError):
            pass
    return out


def create_command(
    conn, radio_id: str, command: str, params: Optional[Dict[str, Any]] = None, *,
    created_by: str, reason: Optional[str] = None, job_id: Optional[str] = None,
    dedup_key: Optional[str] = None,
) -> tuple:
    """Xếp một lệnh. Trả (lệnh, có_tạo_mới). Cùng dedup_key → trả lệnh cũ."""
    if dedup_key:
        old = _one(conn, "SELECT * FROM radio_commands WHERE dedup_key = ?", (dedup_key,))
        if old:
            return _command_view(old), False
    row = {
        "id": f"rcmd_{uuid.uuid4().hex[:16]}",
        "radio_id": str(radio_id),
        "command": command,
        "params": json.dumps(params or {}, ensure_ascii=False),
        "status": "pending",
        "dedup_key": dedup_key,
        "reason": reason,
        "job_id": job_id,
        "attempts": 0,
        "created_at": _now(),
        "created_by": created_by,
    }
    cols = list(row.keys())
    conn.execute(
        sql(f"INSERT INTO radio_commands ({', '.join(cols)}) VALUES ({', '.join('?' for _ in cols)})"),
        tuple(row[c] for c in cols),
    )
    conn.commit()
    return _command_view(row), True


def _is_alarm_mutation(m: Dict[str, Any]) -> bool:
    data = m.get("data") or {}
    return m.get("table") in ("mushroom_jobs", "jobs") and bool(data.get("id")) and re_._truthy(data.get("alarm_triggered"))


def enqueue_timeout_alerts(conn, repo, mutations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Job Alone Worker vừa bị bật alarm_triggered (đồng hồ trong app hết giờ) →
    nhắn tin xuống bộ đàm của người đang làm job đó. Gọi SAU khi mutation đã
    được lưu. Báo động do chính bộ đàm gửi lên không đi qua đây (ingest_event
    đẩy mutation thẳng vào repo), nên không có vòng lặp radio → iZii → radio.
    """
    hits = [m for m in mutations if _is_alarm_mutation(m)]
    if not hits:
        return []
    jobs = re_.fold_records(repo.get_mutations_by_table("mushroom_jobs"))
    radios = _all(conn, "SELECT * FROM radio_devices WHERE active = 1")
    rooms: Optional[Dict[str, Dict[str, Any]]] = None
    created: List[Dict[str, Any]] = []
    for m in hits:
        job = {**(m.get("data") or {}), **jobs.get(m["data"]["id"], {})}
        if not (re_._truthy(job.get("is_solo_job")) or str(job.get("job_type", "")).lower() == "alone_worker"):
            continue
        assignee = re_._job_assignee(job)
        targets = [r for r in radios if re_.assignee_matches(assignee, r.get("employee_id"), r.get("employee_name"))]
        if not targets:
            print(f"ℹ️  [RADIO] Job {job['id']} time out nhưng '{assignee}' không giữ bộ đàm nào — không nhắn được.")
            continue
        if rooms is None:
            rooms = re_.fold_records(repo.get_mutations_by_table("grow_rooms"))
        room = (rooms.get(job.get("room_id") or "") or {}).get("name") or job.get("room_id") or "?"
        text = f"ALONE WORKER TIMEOUT - {room}. Check in now or contact supervisor."[:MAX_TEXT_LEN]
        for r in targets:
            cmd, is_new = create_command(
                conn, r["radio_id"], "text_message", {"text": text},
                created_by="alone-worker-timeout", reason="alone_worker_timeout", job_id=job["id"],
                # Mỗi lần đồng hồ chạy lại (check-in đặt lại started_at) là một lần time out mới.
                dedup_key=f"timeout:{job['id']}:{job.get('started_at') or ''}:{r['radio_id']}",
            )
            if is_new:
                print(f"📟 [RADIO] Xếp tin time out cho bộ đàm {r['radio_id']} ({assignee}), job {job['id']}")
                created.append(cmd)
    return created


def enqueue_timeout_alerts_for_push(mutations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Điểm gọi từ /sync/push. Lọc rẻ trước khi mở connection."""
    if not any(_is_alarm_mutation(m) for m in mutations):
        return []
    with open_connection() as conn:
        return enqueue_timeout_alerts(conn, make_sync_repo(conn), mutations)


class CommandPayload(BaseModel):
    command: str
    params: Optional[Dict[str, Any]] = None


@router.post("/devices/{radio_id}/commands")
def radio_command_create(radio_id: str, body: CommandPayload, actor: str = Depends(require_operator)):
    if body.command not in COMMANDS:
        raise HTTPException(400, f"command phải là một trong: {', '.join(COMMANDS)}")
    params = body.params or {}
    if body.command == "text_message":
        text = str(params.get("text") or "").strip()
        if not text:
            raise HTTPException(400, "text_message cần params.text")
        params = {"text": text[:MAX_TEXT_LEN]}
    with open_connection() as conn:
        if not _one(conn, "SELECT radio_id FROM radio_devices WHERE radio_id = ?", (radio_id,)):
            raise HTTPException(404, f"Bộ đàm {radio_id} chưa đăng ký.")
        cmd, _ = create_command(conn, radio_id, body.command, params, created_by=actor, reason="manual")
    return {"status": "success", "command": cmd}


@router.get("/commands")
def radio_commands_list(radio_id: Optional[str] = None, limit: int = 50, actor: str = Depends(require_operator)):
    limit = max(1, min(limit, 200))
    with open_connection() as conn:
        if radio_id:
            rows = _all(conn, "SELECT * FROM radio_commands WHERE radio_id = ? ORDER BY created_at DESC LIMIT ?",
                        (radio_id, limit))
        else:
            rows = _all(conn, "SELECT * FROM radio_commands ORDER BY created_at DESC LIMIT ?", (limit,))
    return {"commands": [_command_view(r) for r in rows], "count": len(rows)}


@router.get("/bridge/commands", dependencies=[Depends(require_radio_gateway)])
def bridge_commands_claim(limit: int = 20):
    """Bridge lấy lệnh cần gửi. Lệnh được 'thuê' COMMAND_LEASE; không báo kết quả thì cấp lại."""
    limit = max(1, min(limit, 100))
    now_dt = datetime.now(timezone.utc)
    now = now_dt.isoformat()
    ttl_cutoff = (now_dt - COMMAND_TTL).isoformat()
    lease_cutoff = (now_dt - COMMAND_LEASE).isoformat()
    with open_connection() as conn:
        conn.execute(
            sql("UPDATE radio_commands SET status = 'expired', done_at = ?, error = ? "
                "WHERE status = 'pending' AND created_at < ?"),
            (now, "Hết hạn trước khi bridge lấy lệnh (bridge không chạy?)", ttl_cutoff),
        )
        conn.execute(
            sql("UPDATE radio_commands SET status = 'failed', done_at = ?, error = ? "
                "WHERE status = 'sent' AND sent_at < ? AND attempts >= ?"),
            (now, "Bridge không báo kết quả sau nhiều lần thử", lease_cutoff, COMMAND_MAX_ATTEMPTS),
        )
        rows = _all(
            conn,
            "SELECT * FROM radio_commands WHERE status = 'pending' OR (status = 'sent' AND sent_at < ?) "
            "ORDER BY created_at ASC LIMIT ?",
            (lease_cutoff, limit),
        )
        for r in rows:
            conn.execute(
                sql("UPDATE radio_commands SET status = 'sent', sent_at = ?, attempts = attempts + 1 WHERE id = ?"),
                (now, r["id"]),
            )
        conn.commit()
    return {"commands": [_command_view(r) for r in rows]}


class CommandResultPayload(BaseModel):
    ok: bool
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


@router.post("/bridge/commands/{command_id}/result", dependencies=[Depends(require_radio_gateway)])
def bridge_command_result(command_id: str, body: CommandResultPayload):
    now = _now()
    with open_connection() as conn:
        cmd = _one(conn, "SELECT * FROM radio_commands WHERE id = ?", (command_id,))
        if cmd is None:
            raise HTTPException(404, "Không tìm thấy lệnh.")
        conn.execute(
            sql("UPDATE radio_commands SET status = ?, done_at = ?, result = ?, error = ? WHERE id = ?"),
            ("done" if body.ok else "failed", now,
             json.dumps(body.result, ensure_ascii=False) if body.result is not None else None,
             None if body.ok else (body.error or "failed"), command_id),
        )
        if body.ok and cmd["command"].startswith("lone_worker_"):
            state = (body.result or {}).get("lone_worker")
            if state not in ("on", "off"):
                state = {"lone_worker_enable": "on", "lone_worker_disable": "off"}.get(cmd["command"])
            if state:
                conn.execute(
                    sql("UPDATE radio_devices SET lone_worker_state = ?, lone_worker_checked_at = ? WHERE radio_id = ?"),
                    (state, now, cmd["radio_id"]),
                )
        conn.commit()
        row = _one(conn, "SELECT * FROM radio_commands WHERE id = ?", (command_id,)) or cmd
    return {"status": "success", "command": _command_view(row)}
