# server/dtqg_pos.py
"""
Vai trò POS nhà thuốc của Đơn thuốc quốc gia (QĐ 808, mục VIII–IX):
  tra đơn theo mã → bán (có thể bán nhiều lần, có thể thay thuốc) → cập nhật số lượng bán.

app-name / app-key là bí mật của ĐƠN VỊ LÀM PHẦN MỀM (IZIIAPP_DTQG_POS_APP_NAME/KEY),
chỉ nằm ở server; thiết bị nhà thuốc gọi qua router của iZii, không cầm khóa này.

Quy tắc áp dụng (Hướng dẫn 8.3, 26):
  - Đơn hiệu lực 5 ngày kể từ ngày giờ kê đơn; hết hạn thì không bán.
  - Đơn đã bán hết toàn phần thì không bán nữa.
  - Dược sĩ ĐH được thay thuốc cùng hoạt chất/đường dùng/liều khi người mua đồng ý;
    dòng thay thế gửi mã/tên thuốc MỚI nhưng `ma_thuoc_da_ke_don` vẫn là mã thuốc GỐC.
Số bán được cộng dồn theo `ma_thuoc_da_ke_don` từ nhật ký dtqg_pos_sales của iZii.
Hệ thống quốc gia không cho biết đã bán bao nhiêu — nếu nhà thuốc khác cùng bán đơn này
thì iZii không thấy; để hệ thống quốc gia là bên chặn cuối (422).
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, List, Optional

import dtqg_payload as payload
from database import sql
from dtqg_client import DtqgClient, DtqgResult

VALIDITY = timedelta(days=5)


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()


class DtqgPos:
    def __init__(
        self,
        conn,
        client: DtqgClient,
        app_name: str,
        app_key: str,
        now_fn: Callable[[], datetime] = lambda: datetime.now(timezone.utc),
    ):
        self.conn = conn
        self.client = client
        self.app_name = app_name
        self.app_key = app_key
        self._now = now_fn

    def _configured(self) -> Optional[str]:
        if not (self.app_name and self.app_key):
            return "Server chưa cấu hình IZIIAPP_DTQG_POS_APP_NAME / IZIIAPP_DTQG_POS_APP_KEY"
        return None

    # ── số đã bán ───────────────────────────────────────────────────────────
    def sold_quantities(self, ma_don: str) -> Dict[str, float]:
        """Cộng dồn theo ma_thuoc_da_ke_don, tính cả lần bán còn 'pending' (đã giao thuốc rồi)."""
        rows = self.conn.execute(
            sql("SELECT lines FROM dtqg_pos_sales WHERE ma_don_thuoc = ? AND sync_status <> 'rejected'"),
            (ma_don,),
        ).fetchall()
        out: Dict[str, float] = {}
        for r in rows:
            for ln in json.loads(r["lines"]):
                k = ln["ma_thuoc_da_ke_don"]
                out[k] = out.get(k, 0.0) + float(ln["so_luong_ban"])
        return out

    # ── tra đơn ─────────────────────────────────────────────────────────────
    def lookup(self, ma_don: str) -> Dict[str, Any]:
        err = self._configured()
        if err:
            return {"ok": False, "status": 503, "errors": [err]}
        ma = (ma_don or "").strip().lower()
        if not payload.is_valid_ma_don(ma):
            return {"ok": False, "status": 400, "errors": ["Mã đơn thuốc không đúng định dạng xxxxxyyyyyyy-z"]}
        res = self.client.pos_get_prescription(self.app_name, self.app_key, ma)
        if not res.ok:
            return {"ok": False, "status": res.status, "errors": res.errors,
                    "retryable": res.network_error or res.status >= 500}
        rx = res.data if isinstance(res.data, dict) else {}
        sold = self.sold_quantities(ma)
        lines = []
        for ln in rx.get("thong_tin_don_thuoc") or []:
            prescribed = float(ln.get("so_luong") or 0)
            done = sold.get(ln.get("ma_thuoc"), 0.0)
            lines.append({**ln, "da_ban": done, "con_lai": max(prescribed - done, 0.0)})
        issued = payload._parse_dt(rx.get("ngay_gio_ke_don"))
        # Giờ kê đơn là giờ VN không kèm múi giờ.
        expires = (issued + VALIDITY) if issued else None
        expired = bool(expires and self._now() > expires)
        fully_sold = bool(lines) and all(l["con_lai"] <= 0 for l in lines)
        return {
            "ok": True, "status": 200,
            "prescription": {**rx, "thong_tin_don_thuoc": lines},
            "het_han": expired,
            "het_han_luc": expires.isoformat() if expires else None,
            "da_ban_het": fully_sold,
            "co_the_ban": not expired and not fully_sold,
            "errors": [],
        }

    # ── bán / cập nhật ──────────────────────────────────────────────────────
    def sell(
        self,
        ma_don: str,
        lines: List[Dict[str, Any]],
        supplier: Dict[str, Any],
        ma_hoa_don: str,
        by: str = "pos",
    ) -> Dict[str, Any]:
        info = self.lookup(ma_don)
        if not info["ok"]:
            return {"result": "lookup_failed", **info}
        if info["het_han"]:
            return {"result": "rejected", "errors": ["Đơn thuốc đã hết hạn (5 ngày kể từ ngày kê đơn)"], "local": True}
        if info["da_ban_het"]:
            return {"result": "rejected", "errors": ["Đơn thuốc đã bán hết"], "local": True}

        ma = ma_don.strip().lower()
        prescribed = {l["ma_thuoc"]: l for l in info["prescription"]["thong_tin_don_thuoc"]}
        errors: List[str] = []
        out_lines: List[Dict[str, Any]] = []
        add: Dict[str, float] = {}
        for i, ln in enumerate(lines or [], 1):
            orig_code = ln.get("ma_thuoc_da_ke_don")
            orig = prescribed.get(orig_code)
            label = f"Dòng #{i}"
            if orig is None:
                errors.append(f"{label}: ma_thuoc_da_ke_don không có trong đơn")
                continue
            qty = ln.get("so_luong_ban")
            if not isinstance(qty, (int, float)) or qty <= 0:
                errors.append(f"{label}: so_luong_ban phải lớn hơn 0")
                continue
            add[orig_code] = add.get(orig_code, 0.0) + float(qty)
            if add[orig_code] > orig["con_lai"] + 1e-9:
                errors.append(f"{label} ({orig.get('ten_thuoc')}): bán {add[orig_code]:g} vượt số còn lại {orig['con_lai']:g}")
                continue
            # Không thay thuốc thì lấy nguyên thông tin thuốc đã kê.
            out_lines.append({
                "ma_thuoc_da_ke_don": orig_code,
                "ma_thuoc": ln.get("ma_thuoc") or orig["ma_thuoc"],
                "biet_duoc": ln.get("biet_duoc") or orig["biet_duoc"],
                "ten_thuoc": ln.get("ten_thuoc") or orig["ten_thuoc"],
                "don_vi_tinh": ln.get("don_vi_tinh") or orig["don_vi_tinh"],
                "so_luong": orig["so_luong"],
                "so_luong_ban": float(qty),
                "cach_dung": ln.get("cach_dung") or orig["cach_dung"],
            })
        if not out_lines and not errors:
            errors.append("Chưa chọn thuốc nào để bán")
        phone = str(supplier.get("so_dien_thoai_co_so_cung_ung_thuoc") or "").strip()
        for key, limit in (("ma_dinh_danh_co_so_cung_ung_thuoc", 200), ("ten_co_so_cung_ung_thuoc", 2000),
                           ("dia_chi_co_so_cung_ung_thuoc", 2000)):
            v = str(supplier.get(key) or "").strip()
            if not v:
                errors.append(f"Thiếu {key}")
            elif len(v) > limit:
                errors.append(f"{key} tối đa {limit} ký tự")
        if not phone.isdigit() or len(phone) > 12:
            errors.append("so_dien_thoai_co_so_cung_ung_thuoc phải là chuỗi số tối đa 12")
        hd = (ma_hoa_don or "").strip()
        if not hd:
            errors.append("Thiếu ma_hoa_don")
        elif len(hd) > 20:
            errors.append("ma_hoa_don tối đa 20 ký tự")
        if errors:
            return {"result": "rejected", "errors": errors, "local": True}

        body = {
            "ma_don_thuoc": ma,
            "thong_tin_thuoc": out_lines,
            "ma_dinh_danh_co_so_cung_ung_thuoc": str(supplier["ma_dinh_danh_co_so_cung_ung_thuoc"]).strip(),
            "ten_co_so_cung_ung_thuoc": str(supplier["ten_co_so_cung_ung_thuoc"]).strip(),
            "so_dien_thoai_co_so_cung_ung_thuoc": phone,
            "dia_chi_co_so_cung_ung_thuoc": str(supplier["dia_chi_co_so_cung_ung_thuoc"]).strip(),
            "ma_hoa_don": hd,
        }
        sale_id = f"dsale_{uuid.uuid4().hex[:16]}"
        # Lưu TRƯỚC khi gọi mạng: thuốc đã giao cho khách thì số đã bán phải được tính
        # dù hệ thống quốc gia đang không với tới được.
        meta = {k: v for k, v in body.items() if k != "thong_tin_thuoc"}
        self.conn.execute(
            sql("INSERT INTO dtqg_pos_sales (id, ma_don_thuoc, ma_hoa_don, lines, meta, sync_status, created_by, created_at) "
                "VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)"),
            (sale_id, ma, hd, json.dumps(out_lines, ensure_ascii=False), json.dumps(meta, ensure_ascii=False),
             by, _iso(self._now())),
        )
        self.conn.commit()
        return {**self._push(sale_id, body), "sale_id": sale_id}

    def _push(self, sale_id: str, body: Dict[str, Any]) -> Dict[str, Any]:
        err = self._configured()
        if err:
            return {"result": "blocked", "errors": [err]}
        res: DtqgResult = self.client.pos_update_sold(self.app_name, self.app_key, body)
        now = _iso(self._now())
        if res.ok:
            self.conn.execute(
                sql("UPDATE dtqg_pos_sales SET sync_status = 'sent', sent_at = ?, last_error = NULL WHERE id = ?"),
                (now, sale_id),
            )
            self.conn.commit()
            return {"result": "sent", "errors": []}
        self._log_failure(sale_id, res)
        if res.network_error or res.status >= 500:
            return {"result": "retry", "errors": res.errors, "http_status": res.status}
        # 404/422: hệ thống từ chối → không tính vào số đã bán nữa
        self.conn.execute(
            sql("UPDATE dtqg_pos_sales SET sync_status = 'rejected', last_error = ? WHERE id = ?"),
            ("; ".join(res.errors), sale_id),
        )
        self.conn.commit()
        return {"result": "rejected", "errors": res.errors, "http_status": res.status}

    def _log_failure(self, sale_id: str, res: DtqgResult) -> None:
        self.conn.execute(
            sql("INSERT INTO dtqg_submissions (id, prescription_id, ma_don_thuoc, kind, attempt, http_status, ok, "
                "errors, created_at) VALUES (?, ?, ?, 'pos_cap_nhat', 1, ?, 0, ?, ?)"),
            (f"dsub_{uuid.uuid4().hex[:16]}", sale_id, None, res.status or None,
             json.dumps(res.errors, ensure_ascii=False), _iso(self._now())),
        )
        self.conn.commit()

    def retry_pending(self, limit: int = 20) -> List[Dict[str, Any]]:
        rows = self.conn.execute(
            sql("SELECT * FROM dtqg_pos_sales WHERE sync_status = 'pending' ORDER BY created_at LIMIT ?"),
            (limit,),
        ).fetchall()
        out = []
        for r in rows:
            body = {**json.loads(r["meta"]), "thong_tin_thuoc": json.loads(r["lines"])}
            out.append({"sale_id": r["id"], **self._push(r["id"], body)})
        return out
