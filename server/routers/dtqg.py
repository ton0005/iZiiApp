# server/routers/dtqg.py
"""
API nội bộ của iZii cho Đơn thuốc quốc gia (QĐ 808/QĐ-BYT).

Thiết bị KHÔNG gọi thẳng donthuocquocgia.vn và không giữ mật khẩu/token/app-key:
  - HIS (phòng khám): app chỉ đặt prescriptions.dtqg_status = 'queued'; server tự gửi
    (vòng nền + endpoint gửi ngay).
  - POS (nhà thuốc): app gọi /pos/lookup và /pos/sell; server giữ app-name/app-key.

Phân quyền:
  quản trị (X-iZii-Admin-Token) : đặt mật khẩu, thêm/xóa bác sĩ, chạy hàng đợi
  người thao tác (device token hoặc admin) : xem trạng thái, gửi ngay một đơn, tra/bán theo đơn
Mọi endpoint (trừ /status) từ chối khi IZIIAPP_DTQG_ENABLED chưa bật, để môi trường
dev không lỡ gọi hệ thống thật.
"""
from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

from database import sql
from dependencies import make_sync_repo, open_connection
from dtqg_client import DtqgClient
from dtqg_crypto import CredentialKeyError
from dtqg_pos import DtqgPos
from dtqg_service import DtqgGateway
from radio_events import fold_records
from routers.radio_gateway import require_admin_token, require_operator
from server_config import CONFIG

router = APIRouter(prefix="/api/v1/dtqg", tags=["Đơn thuốc quốc gia (QĐ 808)"])


def _make_client() -> DtqgClient:
    return DtqgClient(CONFIG.dtqg_api_base, CONFIG.dtqg_web_base, timeout=CONFIG.dtqg_http_timeout_seconds)


def _require_enabled() -> None:
    if not CONFIG.dtqg_enabled:
        raise HTTPException(503, "Liên thông Đơn thuốc quốc gia đang tắt (IZIIAPP_DTQG_ENABLED).")


def _with_gateway(fn):
    with open_connection() as conn:
        client = _make_client()
        try:
            return fn(DtqgGateway(conn, make_sync_repo(conn), client), conn)
        finally:
            client.close()


def _with_pos(fn):
    with open_connection() as conn:
        client = _make_client()
        try:
            repo = make_sync_repo(conn)
            pos = DtqgPos(conn, client, CONFIG.dtqg_pos_app_name, CONFIG.dtqg_pos_app_key)
            return fn(pos, conn, repo)
        finally:
            client.close()


# ── Trạng thái ──────────────────────────────────────────────────────────────

@router.get("/status")
async def dtqg_status(_: str = Depends(require_operator)) -> Dict[str, Any]:
    def run(gw: DtqgGateway, conn) -> Dict[str, Any]:
        rxs = fold_records(gw.repo.get_mutations_by_table("prescriptions")).values()
        counts: Dict[str, int] = {}
        for r in rxs:
            k = r.get("dtqg_status") or "draft"
            counts[k] = counts.get(k, 0) + 1
        pos_pending = conn.execute(
            sql("SELECT COUNT(*) AS n FROM dtqg_pos_sales WHERE sync_status = 'pending'")
        ).fetchone()
        return {
            "enabled": CONFIG.dtqg_enabled,
            "api_base": CONFIG.dtqg_api_base,
            "credential_key_configured": bool(CONFIG.dtqg_cred_key),
            "pos_configured": bool(CONFIG.dtqg_pos_app_name and CONFIG.dtqg_pos_app_key),
            "facility_code": gw.facility_code(),
            "prescriptions": counts,
            "pos_pending": int(pos_pending["n"]) if pos_pending else 0,
            "credentials": gw.credential_status(),   # không bao giờ kèm mật khẩu
        }

    return await run_in_threadpool(_with_gateway, run)


# ── Quản trị ────────────────────────────────────────────────────────────────

class CredentialIn(BaseModel):
    subject_type: str = Field(pattern="^(facility|doctor)$")
    subject_code: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1, max_length=200)


@router.put("/credentials")
async def set_credential(body: CredentialIn, who: str = Depends(require_admin_token)) -> Dict[str, Any]:
    def run(gw: DtqgGateway, conn):
        gw.set_password(body.subject_type, body.subject_code.strip(), body.password, by=who)
        return {"ok": True}

    try:
        return await run_in_threadpool(_with_gateway, run)
    except CredentialKeyError as e:
        raise HTTPException(503, str(e))


class DoctorIn(BaseModel):
    ma_lien_thong_bac_si: str = Field(min_length=1, max_length=100)


@router.post("/doctors/add")
async def add_doctor(body: DoctorIn, _: str = Depends(require_admin_token)) -> Dict[str, Any]:
    _require_enabled()
    return await run_in_threadpool(_with_gateway, lambda gw, c: gw.add_doctor(body.ma_lien_thong_bac_si.strip()))


@router.post("/doctors/remove")
async def remove_doctor(body: DoctorIn, _: str = Depends(require_admin_token)) -> Dict[str, Any]:
    _require_enabled()
    return await run_in_threadpool(_with_gateway, lambda gw, c: gw.remove_doctor(body.ma_lien_thong_bac_si.strip()))


@router.post("/queue/process")
async def process_queue(limit: int = Query(20, ge=1, le=200), _: str = Depends(require_admin_token)) -> Dict[str, Any]:
    _require_enabled()
    results = await run_in_threadpool(_with_gateway, lambda gw, c: gw.process_queue(limit))
    return {"results": results}


# ── HIS ─────────────────────────────────────────────────────────────────────

@router.post("/prescriptions/{prescription_id}/send")
async def send_prescription(prescription_id: str, _: str = Depends(require_operator)) -> Dict[str, Any]:
    _require_enabled()
    return await run_in_threadpool(_with_gateway, lambda gw, c: gw.send(prescription_id))


@router.get("/prescriptions")
async def list_prescriptions(
    status: Optional[str] = Query(None, pattern="^(draft|queued|sent|rejected)$"),
    limit: int = Query(100, ge=1, le=500),
    _: str = Depends(require_operator),
) -> Dict[str, Any]:
    """Danh sách đơn kèm trạng thái liên thông (nguồn sự thật là server, vì trạng thái 'sent'/'rejected' do server ghi)."""
    def run(gw: DtqgGateway, conn):
        rxs = fold_records(gw.repo.get_mutations_by_table("prescriptions"))
        patients = fold_records(gw.repo.get_mutations_by_table("patients"))
        doctors = fold_records(gw.repo.get_mutations_by_table("doctors"))
        items = fold_records(gw.repo.get_mutations_by_table("prescription_items"))
        counts: Dict[str, int] = {}
        for it in items.values():
            counts[it.get("prescription_id")] = counts.get(it.get("prescription_id"), 0) + 1
        rows = []
        for r in rxs.values():
            st = r.get("dtqg_status") or "draft"
            if status and st != status:
                continue
            rows.append({
                "id": r["id"],
                "ma_don_thuoc": r.get("ma_don_thuoc"),
                "dtqg_status": st,
                "dtqg_last_error": r.get("dtqg_last_error"),
                "dtqg_sent_at": r.get("dtqg_sent_at"),
                "prescription_date": r.get("prescription_date"),
                "patient_name": (patients.get(r.get("patient_id")) or {}).get("full_name", ""),
                "doctor_name": (doctors.get(r.get("doctor_id")) or {}).get("name", ""),
                "item_count": counts.get(r["id"], 0),
            })
        rows.sort(key=lambda x: str(x["prescription_date"] or ""), reverse=True)
        return {"prescriptions": rows[:limit]}

    return await run_in_threadpool(_with_gateway, run)


@router.get("/submissions")
async def submissions(
    prescription_id: Optional[str] = None,
    limit: int = Query(50, ge=1, le=500),
    _: str = Depends(require_operator),
) -> Dict[str, Any]:
    def run(gw: DtqgGateway, conn):
        q = "SELECT * FROM dtqg_submissions"
        params: tuple = ()
        if prescription_id:
            q += " WHERE prescription_id = ?"
            params = (prescription_id,)
        q += " ORDER BY created_at DESC LIMIT ?"
        rows = conn.execute(sql(q), params + (limit,)).fetchall()
        out: List[Dict[str, Any]] = []
        for r in rows:
            d = dict(r)
            d["errors"] = json.loads(d.get("errors") or "[]")
            out.append(d)
        return {"submissions": out}

    return await run_in_threadpool(_with_gateway, run)


# ── POS ─────────────────────────────────────────────────────────────────────

class PosLookupIn(BaseModel):
    ma_don_thuoc: str = Field(min_length=1, max_length=40)


@router.post("/pos/lookup")
async def pos_lookup(body: PosLookupIn, _: str = Depends(require_operator)) -> Dict[str, Any]:
    _require_enabled()
    return await run_in_threadpool(_with_pos, lambda pos, c, r: pos.lookup(body.ma_don_thuoc))


class PosLineIn(BaseModel):
    ma_thuoc_da_ke_don: str
    so_luong_ban: float
    ma_thuoc: Optional[str] = None
    biet_duoc: Optional[str] = None
    ten_thuoc: Optional[str] = None
    don_vi_tinh: Optional[str] = None
    cach_dung: Optional[str] = None


class PosSellIn(BaseModel):
    ma_don_thuoc: str
    ma_hoa_don: str
    lines: List[PosLineIn]
    supplier: Optional[Dict[str, Any]] = None   # bỏ trống → lấy từ thông tin cơ sở


def _default_supplier(repo) -> Dict[str, Any]:
    fac = fold_records(repo.get_mutations_by_table("clinic_facility")).get("default", {})
    return {
        "ma_dinh_danh_co_so_cung_ung_thuoc": fac.get("ma_dinh_danh_cung_ung"),
        "ten_co_so_cung_ung_thuoc": fac.get("name"),
        "so_dien_thoai_co_so_cung_ung_thuoc": "".join(ch for ch in str(fac.get("phone") or "") if ch.isdigit()),
        "dia_chi_co_so_cung_ung_thuoc": fac.get("address"),
    }


@router.post("/pos/sell")
async def pos_sell(body: PosSellIn, who: str = Depends(require_operator)) -> Dict[str, Any]:
    _require_enabled()

    def run(pos: DtqgPos, conn, repo):
        supplier = {**_default_supplier(repo), **{k: v for k, v in (body.supplier or {}).items() if v}}
        return pos.sell(
            body.ma_don_thuoc,
            [l.model_dump(exclude_none=True) for l in body.lines],
            supplier, body.ma_hoa_don, by=who,
        )

    return await run_in_threadpool(_with_pos, run)


@router.post("/pos/retry")
async def pos_retry(_: str = Depends(require_admin_token)) -> Dict[str, Any]:
    _require_enabled()
    return {"results": await run_in_threadpool(_with_pos, lambda pos, c, r: pos.retry_pending())}
