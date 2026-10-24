# server/dtqg_service.py
"""
DtqgGateway — gửi đơn thuốc đã kê lên Hệ thống Đơn thuốc quốc gia (QĐ 808).

Nguồn dữ liệu là mutation log (fold_records), vì backend SQLite không có read
model; trên Postgres cũng dùng được. Thiết bị chỉ đặt `dtqg_status = 'queued'`;
mật khẩu/token liên thông chỉ nằm ở bảng dtqg_* của server.

Chuỗi gọi (mục III–VII):
  đăng nhập cơ sở → thêm bác sĩ (một lần) → đăng nhập bác sĩ → gửi đơn
Token hiệu lực 7 ngày, cache trong dtqg_sessions; gặp 401 thì đăng nhập lại
đúng một lần rồi gửi lại.

Kết quả mỗi lần gọi (`result`):
  sent       200 — đơn bị khóa, ghi dtqg_status='sent'
  rejected   422 hoặc không qua kiểm tra nội bộ — ghi lỗi NGUYÊN VĂN cho bác sĩ
  retry      lỗi mạng/timeout — giữ 'queued', lần sau thử lại
  blocked    thiếu cấu hình (mật khẩu, mã liên thông, khóa mã hóa) — giữ 'queued'
  skipped    đã gửi trước đó (kể cả khi lần trước gửi xong nhưng chưa kịp ghi trạng thái)
"""
from __future__ import annotations

import hashlib
import json
import threading
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, List, Optional, Tuple

import dtqg_payload as payload
from database import sql
from dtqg_client import DtqgClient, DtqgResult
from dtqg_crypto import CredentialKeyError, decrypt_password, encrypt_password
from radio_events import fold_records
from server_config import CONFIG

TOKEN_TTL = timedelta(days=7)
TOKEN_REFRESH_MARGIN = timedelta(hours=1)

_inflight: set = set()
_inflight_lock = threading.Lock()


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()


def _parse(v: Any) -> Optional[datetime]:
    try:
        d = datetime.fromisoformat(str(v))
    except (TypeError, ValueError):
        return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


class DtqgGateway:
    def __init__(
        self,
        conn,
        repo,
        client: DtqgClient,
        now_fn: Callable[[], datetime] = lambda: datetime.now(timezone.utc),
        cred_key: Optional[str] = None,
    ):
        self.conn = conn
        self.repo = repo
        self.client = client
        self._now = now_fn
        self._key = cred_key

    # ── DB helpers ──────────────────────────────────────────────────────────

    def _one(self, q: str, params: tuple = ()) -> Optional[Dict[str, Any]]:
        row = self.conn.execute(sql(q), params).fetchone()
        return dict(row) if row is not None else None

    # credentials
    def set_password(self, subject_type: str, code: str, password: str, by: str = "admin") -> None:
        enc = encrypt_password(password, self._key)  # fail-closed nếu chưa có khóa
        now = _iso(self._now())
        self.conn.execute(
            sql("DELETE FROM dtqg_credentials WHERE subject_type = ? AND subject_code = ?"),
            (subject_type, code),
        )
        self.conn.execute(
            sql("INSERT INTO dtqg_credentials (subject_type, subject_code, password_enc, updated_at, updated_by) "
                "VALUES (?, ?, ?, ?, ?)"),
            (subject_type, code, enc, now, by),
        )
        self.drop_session(subject_type, code)  # đổi mật khẩu → token cũ không còn đáng tin
        self.conn.commit()

    def _get_password(self, subject_type: str, code: str) -> Optional[str]:
        row = self._one(
            "SELECT password_enc FROM dtqg_credentials WHERE subject_type = ? AND subject_code = ?",
            (subject_type, code),
        )
        return decrypt_password(row["password_enc"], self._key) if row else None

    def credential_status(self) -> List[Dict[str, Any]]:
        rows = self.conn.execute(
            sql("SELECT subject_type, subject_code, updated_at, updated_by FROM dtqg_credentials "
                "ORDER BY subject_type, subject_code")
        ).fetchall()
        return [dict(r) for r in rows]  # KHÔNG trả password_enc

    # sessions
    def _get_session(self, subject_type: str, code: str) -> Optional[str]:
        row = self._one(
            "SELECT token, expires_at FROM dtqg_sessions WHERE subject_type = ? AND subject_code = ?",
            (subject_type, code),
        )
        if not row:
            return None
        exp = _parse(row["expires_at"])
        if exp is None or exp - TOKEN_REFRESH_MARGIN <= self._now():
            return None
        return row["token"]

    def _save_session(self, subject_type: str, code: str, token: str) -> None:
        now = self._now()
        self.drop_session(subject_type, code)
        self.conn.execute(
            sql("INSERT INTO dtqg_sessions (subject_type, subject_code, token, expires_at, created_at) "
                "VALUES (?, ?, ?, ?, ?)"),
            (subject_type, code, token, _iso(now + TOKEN_TTL), _iso(now)),
        )
        self.conn.commit()

    def drop_session(self, subject_type: str, code: str) -> None:
        self.conn.execute(
            sql("DELETE FROM dtqg_sessions WHERE subject_type = ? AND subject_code = ?"),
            (subject_type, code),
        )

    # doctor links
    def _is_linked(self, facility: str, doctor: str) -> bool:
        return self._one(
            "SELECT 1 AS x FROM dtqg_doctor_links WHERE facility_code = ? AND doctor_code = ?",
            (facility, doctor),
        ) is not None

    def _mark_linked(self, facility: str, doctor: str) -> None:
        if not self._is_linked(facility, doctor):
            self.conn.execute(
                sql("INSERT INTO dtqg_doctor_links (facility_code, doctor_code, added_at) VALUES (?, ?, ?)"),
                (facility, doctor, _iso(self._now())),
            )
            self.conn.commit()

    def _unlink(self, facility: str, doctor: str) -> None:
        self.conn.execute(
            sql("DELETE FROM dtqg_doctor_links WHERE facility_code = ? AND doctor_code = ?"),
            (facility, doctor),
        )
        self.conn.commit()

    # submissions
    def _attempts(self, prescription_id: str) -> int:
        row = self._one(
            "SELECT COUNT(*) AS n FROM dtqg_submissions WHERE prescription_id = ? AND kind = 'gui_don'",
            (prescription_id,),
        )
        return int(row["n"]) if row else 0

    def _already_sent(self, ma_don: str) -> bool:
        return self._one(
            "SELECT 1 AS x FROM dtqg_submissions WHERE ma_don_thuoc = ? AND kind = 'gui_don' AND ok = 1",
            (ma_don,),
        ) is not None

    def _record(self, rx_id: str, ma_don: Optional[str], http_status: Optional[int], ok: bool,
                errors: List[str], body: Optional[Dict[str, Any]]) -> None:
        h = hashlib.sha256(json.dumps(body, sort_keys=True, ensure_ascii=False).encode()).hexdigest() if body else None
        self.conn.execute(
            sql("INSERT INTO dtqg_submissions (id, prescription_id, ma_don_thuoc, kind, attempt, http_status, "
                "ok, errors, payload_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"),
            (f"dsub_{uuid.uuid4().hex[:16]}", rx_id, ma_don, "gui_don", self._attempts(rx_id) + 1,
             http_status, 1 if ok else 0, json.dumps(errors, ensure_ascii=False), h, _iso(self._now())),
        )
        self.conn.commit()

    # ── dữ liệu nghiệp vụ (mutation log) ────────────────────────────────────

    def _table(self, name: str) -> Dict[str, Dict[str, Any]]:
        return fold_records(self.repo.get_mutations_by_table(name))

    def load_context(self, prescription_id: str) -> Optional[Dict[str, Any]]:
        rx = self._table("prescriptions").get(prescription_id)
        if rx is None:
            return None
        items = [i for i in self._table("prescription_items").values()
                 if i.get("prescription_id") == prescription_id]
        patient = self._table("patients").get(rx.get("patient_id"), {})
        doctor = self._table("doctors").get(rx.get("doctor_id"), {})
        fac = self._table("clinic_facility").get("default", {})
        facility_code = fac.get("ma_lien_thong_dtqg") or (
            "01" + str(fac["ma_cskcb"]).strip().lower() if str(fac.get("ma_cskcb") or "").strip() else None
        )
        return {"rx": rx, "items": items, "patient": patient, "doctor": doctor,
                "facility": fac, "facility_code": facility_code}

    def _push_status(self, rx_id: str, status: str, error: Optional[str], sent: bool = False) -> None:
        data: Dict[str, Any] = {"id": rx_id, "dtqg_status": status, "dtqg_last_error": error}
        if sent:
            data["dtqg_sent_at"] = _iso(self._now())
        self.repo.push_mutations(
            [{"id": f"dtqg-{uuid.uuid4().hex}", "table": "prescriptions", "operation": "update", "data": data}],
            _iso(self._now()),
            default_origin_server_id=CONFIG.server_id,
            actor_user_id="dtqg-gateway",
            actor_device_id="dtqg-gateway",
        )

    # ── đăng nhập ───────────────────────────────────────────────────────────

    def _facility_token(self, facility: str, force: bool = False) -> Tuple[Optional[str], Optional[DtqgResult]]:
        if not force:
            tok = self._get_session("facility", facility)
            if tok:
                return tok, None
        pw = self._get_password("facility", facility)
        if pw is None:
            raise _Blocked(f"Chưa nhập mật khẩu liên thông của cơ sở {facility}")
        res = self.client.login_facility(facility, pw)
        if not res.ok:
            return None, res
        token = (res.data or {}).get("token") if isinstance(res.data, dict) else None
        if not token:
            return None, DtqgResult(False, res.status, res.data, ["Phản hồi đăng nhập cơ sở không có token"])
        self._save_session("facility", facility, token)
        return token, None

    def _ensure_linked(self, facility: str, doctor: str) -> Optional[DtqgResult]:
        """Trả về DtqgResult lỗi nếu không thêm được bác sĩ; None nếu đã liên kết."""
        if self._is_linked(facility, doctor):
            return None
        tok, err = self._facility_token(facility)
        if err:
            return err
        res = self.client.add_doctor(tok, doctor)
        if res.unauthorized:
            tok, err = self._facility_token(facility, force=True)
            if err:
                return err
            res = self.client.add_doctor(tok, doctor)
        if res.ok or (res.status == 422 and any("tồn tại" in e or "đã có" in e or "đã được thêm" in e
                                                   for e in res.errors)):
            self._mark_linked(facility, doctor)
            return None
        return res

    def _doctor_token(self, facility: str, doctor: str, force: bool = False) -> Tuple[Optional[str], Optional[DtqgResult]]:
        if not force:
            tok = self._get_session("doctor", doctor)
            if tok:
                return tok, None
        link_err = self._ensure_linked(facility, doctor)
        if link_err:
            return None, link_err
        pw = self._get_password("doctor", doctor)
        if pw is None:
            raise _Blocked(f"Chưa nhập mật khẩu liên thông của bác sĩ {doctor}")
        res = self.client.login_doctor(doctor, facility, pw)
        if not res.ok and res.status == 422 and any("chưa được thêm" in e for e in res.errors):
            # Hệ thống nói bác sĩ chưa thuộc cơ sở dù ta tưởng đã thêm → thêm lại một lần.
            self._unlink(facility, doctor)
            link_err = self._ensure_linked(facility, doctor)
            if link_err:
                return None, link_err
            res = self.client.login_doctor(doctor, facility, pw)
        if not res.ok:
            return None, res
        data = res.data if isinstance(res.data, dict) else {}
        token = data.get("token")
        if not token:
            return None, DtqgResult(False, res.status, res.data, ["Phản hồi đăng nhập bác sĩ không có token"])
        self._save_session("doctor", doctor, token)
        return token, None

    # ── gửi đơn ─────────────────────────────────────────────────────────────

    def send(self, prescription_id: str) -> Dict[str, Any]:
        with _inflight_lock:
            if prescription_id in _inflight:
                return {"result": "skipped", "errors": ["Đơn đang được gửi bởi tiến trình khác"]}
            _inflight.add(prescription_id)
        try:
            return self._send(prescription_id)
        finally:
            with _inflight_lock:
                _inflight.discard(prescription_id)

    def _send(self, prescription_id: str) -> Dict[str, Any]:
        ctx = self.load_context(prescription_id)
        if ctx is None:
            return {"result": "not_found", "errors": ["Không tìm thấy đơn thuốc"]}
        rx = ctx["rx"]
        ma_don = rx.get("ma_don_thuoc")

        if rx.get("dtqg_status") == "sent":
            return {"result": "skipped", "ma_don_thuoc": ma_don, "errors": []}
        if ma_don and self._already_sent(ma_don):
            # Lần trước gửi 200 nhưng chưa kịp ghi trạng thái → ghi bù, KHÔNG gửi lại.
            self._push_status(prescription_id, "sent", None, sent=True)
            return {"result": "skipped", "ma_don_thuoc": ma_don, "errors": []}
        if rx.get("status") == "cancelled":
            return {"result": "skipped", "ma_don_thuoc": ma_don, "errors": ["Đơn đã bị hủy"]}

        body = payload.build_body(rx, ctx["items"], ctx["patient"])
        errors = payload.validate_body(body, self._now().astimezone(payload.VN_TZ))
        doctor = ctx["doctor"]
        doctor_code = doctor.get("ma_lien_thong_dtqg")
        if not doctor_code:
            errors.append("Bác sĩ chưa có mã liên thông")
        if doctor and doctor.get("dtqg_status") != "active":
            errors.append(f"Bác sĩ chưa được duyệt mã liên thông (trạng thái: {doctor.get('dtqg_status')})")
        if doctor and doctor.get("duoc_ke_don") in (False, 0, "0", "false"):
            errors.append("Bác sĩ không được phân công kê đơn")
        facility = ctx["facility_code"]
        if not facility:
            errors.append("Chưa khai báo mã cơ sở KCB")
        elif ma_don and not str(ma_don).startswith(facility[2:]):
            errors.append("5 ký tự đầu của mã đơn không khớp mã cơ sở")
        if errors:
            self._record(prescription_id, ma_don, None, False, errors, None)
            self._push_status(prescription_id, "rejected", "; ".join(errors))
            return {"result": "rejected", "ma_don_thuoc": ma_don, "errors": errors, "local": True}

        try:
            res = self._deliver(facility, doctor_code, body)
        except (_Blocked, CredentialKeyError) as e:
            return {"result": "blocked", "ma_don_thuoc": ma_don, "errors": [str(e)]}

        self._record(prescription_id, ma_don, res.status or None, res.ok, res.errors, body)
        if res.ok:
            self._push_status(prescription_id, "sent", None, sent=True)
            return {"result": "sent", "ma_don_thuoc": ma_don, "errors": []}
        if res.network_error or res.status >= 500:
            msg = "; ".join(res.errors)
            if rx.get("dtqg_last_error") != msg:
                self._push_status(prescription_id, "queued", msg)
            return {"result": "retry", "ma_don_thuoc": ma_don, "errors": res.errors, "http_status": res.status}
        # 4xx: hệ thống từ chối nội dung/đăng nhập → bác sĩ phải đọc lỗi
        self._push_status(prescription_id, "rejected", "; ".join(res.errors))
        return {"result": "rejected", "ma_don_thuoc": ma_don, "errors": res.errors, "http_status": res.status}

    def _deliver(self, facility: str, doctor_code: str, body: Dict[str, Any]) -> DtqgResult:
        tok, err = self._doctor_token(facility, doctor_code)
        if err:
            return err
        res = self.client.send_prescription(tok, body)
        if res.unauthorized:
            self.drop_session("doctor", doctor_code)
            self.conn.commit()
            tok, err = self._doctor_token(facility, doctor_code, force=True)
            if err:
                return err
            res = self.client.send_prescription(tok, body)
        return res

    def facility_code(self) -> Optional[str]:
        fac = self._table("clinic_facility").get("default", {})
        if fac.get("ma_lien_thong_dtqg"):
            return fac["ma_lien_thong_dtqg"]
        cs = str(fac.get("ma_cskcb") or "").strip().lower()
        return "01" + cs if cs else None

    def add_doctor(self, doctor_code: str) -> Dict[str, Any]:
        """Quản trị: thêm bác sĩ vào cơ sở (mục IV)."""
        facility = self.facility_code()
        if not facility:
            return {"result": "rejected", "errors": ["Chưa khai báo mã cơ sở KCB"]}
        try:
            err = self._ensure_linked(facility, doctor_code)
        except (_Blocked, CredentialKeyError) as e:
            return {"result": "blocked", "errors": [str(e)]}
        if err is None:
            return {"result": "ok", "errors": []}
        return {"result": "retry" if err.network_error or err.status >= 500 else "rejected",
                "errors": err.errors, "http_status": err.status}

    def remove_doctor(self, doctor_code: str) -> Dict[str, Any]:
        """Quản trị: xóa bác sĩ khỏi cơ sở (mục V) — khi nghỉ việc/đình chỉ."""
        facility = self.facility_code()
        if not facility:
            return {"result": "rejected", "errors": ["Chưa khai báo mã cơ sở KCB"]}
        try:
            tok, err = self._facility_token(facility)
            if err is None:
                res = self.client.remove_doctor(tok, doctor_code)
                if res.unauthorized:
                    tok, err = self._facility_token(facility, force=True)
                    if err is None:
                        res = self.client.remove_doctor(tok, doctor_code)
            if err is not None:
                res = err
        except (_Blocked, CredentialKeyError) as e:
            return {"result": "blocked", "errors": [str(e)]}
        if res.ok:
            self._unlink(facility, doctor_code)
            self.drop_session("doctor", doctor_code)
            self.conn.commit()
            return {"result": "ok", "errors": []}
        return {"result": "retry" if res.network_error or res.status >= 500 else "rejected",
                "errors": res.errors, "http_status": res.status}

    def process_queue(self, limit: int = 20) -> List[Dict[str, Any]]:
        rxs = [r for r in self._table("prescriptions").values() if r.get("dtqg_status") == "queued"]
        rxs.sort(key=lambda r: str(r.get("prescription_date") or r.get("created_at") or ""))
        out = []
        for r in rxs[:limit]:
            res = self.send(r["id"])
            res["prescription_id"] = r["id"]
            out.append(res)
        return out


class _Blocked(Exception):
    """Thiếu cấu hình để gửi (mật khẩu...) — không phải lỗi của đơn."""
