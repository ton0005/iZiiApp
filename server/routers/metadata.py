# server/routers/metadata.py
"""
Metadata, UI Descriptors, Settings & Record Rules Router (Phase 3 - P3.1, P3.2, P3.4, P3.5)
Cung cấp API định nghĩa schema động, màu sắc, enum, bố cục form (Q3), và cấu hình phân cấp.
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field

from fastapi import APIRouter, Depends, HTTPException, Query
from dependencies import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["Metadata & Settings"])


class SaveSettingRequest(BaseModel):
    scope: str = Field("global", description="global | tenant | site | device")
    scope_id: str = Field("", description="Mã tenant/site/device hoặc rỗng nếu là global")
    key: str = Field(..., description="Khóa cấu hình, ví dụ: safety.checkin_interval")
    value: Any = Field(..., description="Giá trị cấu hình (dict, list, int, string, bool)")
    data_type: str = Field("json", description="json | text | int | bool")


@router.get("/meta/models")
def list_models(conn=Depends(get_db)):
    """
    P3.1: Lấy danh sách các models đã đăng ký trong model_registry.
    """
    try:
        cur = conn.execute(
            "SELECT tenant_id, model_name, module_name, table_name, label, is_syncable FROM model_registry"
        )
        rows = [dict(r) for r in cur.fetchall()]
        return {"count": len(rows), "models": rows}
    except Exception as e:
        logger.error(f"⚠️ [META] Lỗi đọc model_registry: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/meta/fields/{model_name}")
def get_model_fields(model_name: str, conn=Depends(get_db)):
    """
    P3.1: Lấy danh sách các trường (fields) và ràng buộc của một model.
    """
    try:
        cur = conn.execute(
            """
            SELECT tenant_id, model_name, field_name, data_type, is_required, is_custom, label, enum_values, ui
            FROM field_registry
            WHERE model_name = %s
            ORDER BY field_name ASC
            """,
            (model_name,),
        )
        rows = [dict(r) for r in cur.fetchall()]
        return {"model": model_name, "count": len(rows), "fields": rows}
    except Exception as e:
        logger.error(f"⚠️ [META] Lỗi đọc field_registry cho model {model_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/meta/ui/{model_name}")
def get_ui_descriptor(model_name: str, conn=Depends(get_db)):
    """
    P3.2 & Q3: Lấy UI descriptor hoàn chỉnh cho model:
    - Danh sách fields với nhãn đa ngôn ngữ, widget, thứ tự nhóm.
    - Danh sách enum_values kèm mã màu hex và icon.
    - Đặc biệt cho 'job' / 'mushroom_jobs': tự động hợp nhất các dynamic job types từ mushroom_job_types.
    Client dựa vào descriptor này để hiển thị màu và form mà không cần build lại app!
    """
    try:
        normalized_model = "job" if model_name in ("job", "jobs", "mushroom_jobs") else model_name

        # 1. Tra cứu fields từ field_registry
        cur = conn.execute(
            """
            SELECT field_name, data_type, is_required, is_custom, label, enum_values, ui
            FROM field_registry
            WHERE model_name = %s
            """,
            (normalized_model,),
        )
        fields_map: Dict[str, Any] = {}
        for r in cur.fetchall():
            row_dict = dict(r)
            fields_map[row_dict["field_name"]] = row_dict

        # 2. Xử lý đặc thù cho job type (giải F1 & dynamic job types)
        if normalized_model == "job":
            cur_jt = conn.execute(
                """
                SELECT id, name, plan_minutes, is_solo_job, is_custom, is_active, color, label, icon, sort_order
                FROM mushroom_job_types
                WHERE is_active = 1
                ORDER BY sort_order ASC, name ASC
                """
            )
            job_types = []
            for jt in cur_jt.fetchall():
                jt_dict = dict(jt)
                job_types.append({
                    "value": jt_dict["id"],
                    "name": jt_dict["name"],
                    "color": jt_dict.get("color") or "#4A90E2",
                    "icon": jt_dict.get("icon") or "assignment",
                    "plan_minutes": jt_dict.get("plan_minutes") or 30,
                    "is_solo_job": bool(jt_dict.get("is_solo_job")),
                    "is_custom": bool(jt_dict.get("is_custom")),
                    "label": jt_dict.get("label") or {"vi": jt_dict["name"], "en": jt_dict["name"]},
                })

            if "job_type" not in fields_map:
                fields_map["job_type"] = {
                    "field_name": "job_type",
                    "data_type": "enum",
                    "is_required": True,
                    "is_custom": False,
                    "label": {"vi": "Loại công việc", "en": "Job Type"},
                    "enum_values": job_types,
                    "ui": {"widget": "select", "order": 10, "group": "general"},
                }
            else:
                fields_map["job_type"]["enum_values"] = job_types

        return {
            "model": normalized_model,
            "display_name": {"vi": "Công việc", "en": "Job"} if normalized_model == "job" else {"vi": normalized_model, "en": normalized_model},
            "fields": list(fields_map.values()),
        }
    except Exception as e:
        logger.error(f"⚠️ [META] Lỗi sinh UI descriptor cho model {model_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/settings")
def get_settings(
    scope: str = Query("global", description="global | tenant | site | device"),
    scope_id: str = Query("", description="scope_id tương ứng"),
    key: Optional[str] = Query(None),
    conn=Depends(get_db),
):
    """
    P3.4: Tra cứu cấu hình typed có scope.
    """
    try:
        where_clauses = ["scope = %s", "scope_id = %s"]
        params = [scope, scope_id]
        if key:
            where_clauses.append("key = %s")
            params.append(key)

        cur = conn.execute(
            f"""
            SELECT scope, scope_id, key, value, data_type, updated_by, updated_at
            FROM settings
            WHERE {' AND '.join(where_clauses)}
            """,
            tuple(params),
        )
        rows = [dict(r) for r in cur.fetchall()]
        return {"count": len(rows), "settings": rows}
    except Exception as e:
        logger.error(f"⚠️ [SETTINGS] Lỗi tra cứu settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/settings")
def save_setting(req: SaveSettingRequest, conn=Depends(get_db)):
    """
    P3.4: Lưu hoặc cập nhật cấu hình theo scope.
    """
    try:
        val_json = req.value
        if not isinstance(val_json, (dict, list)):
            val_json = {"val": req.value}

        conn.execute(
            """
            INSERT INTO settings (scope, scope_id, key, value, data_type, updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, now())
            ON CONFLICT (scope, scope_id, key) DO UPDATE SET
                value = EXCLUDED.value,
                data_type = EXCLUDED.data_type,
                updated_at = now()
            """,
            (req.scope, req.scope_id, req.key, json.dumps(val_json), req.data_type, "admin"),
        )
        return {"status": "success", "message": f"Cấu hình '{req.key}' cho scope '{req.scope}' đã được cập nhật."}
    except Exception as e:
        logger.error(f"⚠️ [SETTINGS] Lỗi lưu settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def domain_to_sql(domain: List[Any]) -> tuple[str, list]:
    """
    Chuyển đổi Odoo-style domain expression (P3.5) sang SQL WHERE clause và params.
    Hỗ trợ các toán tử: '=', '!=', 'in', 'not in', '>', '>=', '<', '<=', 'like', 'ilike'.
    Ví dụ: [("status", "=", "in_progress"), ("priority", "in", ["high", "urgent"])]
    """
    if not domain or not isinstance(domain, list):
        return "TRUE", []

    clauses = []
    params = []

    for item in domain:
        if not isinstance(item, (list, tuple)) or len(item) != 3:
            continue
        field, op, val = item
        op = str(op).lower().strip()
        safe_field = f'"{field}"' if not field.startswith('"') else field

        if op in ("=", "=="):
            clauses.append(f"{safe_field} = %s")
            params.append(val)
        elif op in ("!=", "<>"):
            clauses.append(f"{safe_field} <> %s")
            params.append(val)
        elif op == "in":
            val_list = list(val) if isinstance(val, (list, tuple, set)) else [val]
            placeholders = ", ".join(["%s"] * len(val_list))
            clauses.append(f"{safe_field} IN ({placeholders})")
            params.extend(val_list)
        elif op in ("not in", "not_in"):
            val_list = list(val) if isinstance(val, (list, tuple, set)) else [val]
            placeholders = ", ".join(["%s"] * len(val_list))
            clauses.append(f"{safe_field} NOT IN ({placeholders})")
            params.extend(val_list)
        elif op in (">", ">=", "<", "<="):
            clauses.append(f"{safe_field} {op} %s")
            params.append(val)
        elif op == "like":
            clauses.append(f"{safe_field} LIKE %s")
            params.append(val)
        elif op == "ilike":
            clauses.append(f"{safe_field} ILIKE %s")
            params.append(val)

    where_sql = " AND ".join(clauses) if clauses else "TRUE"
    return where_sql, params


@router.get("/rules/{model_name}")
def get_record_rules(model_name: str, conn=Depends(get_db)):
    """
    P3.5: Lấy danh sách record rules áp dụng cho model.
    """
    try:
        cur = conn.execute(
            """
            SELECT tenant_id, rule_name, model_name, role_key, domain, perm_read, perm_write, enabled
            FROM record_rules
            WHERE model_name = %s AND enabled = TRUE
            """,
            (model_name,),
        )
        rows = [dict(r) for r in cur.fetchall()]
        return {"model": model_name, "count": len(rows), "rules": rows}
    except Exception as e:
        logger.error(f"⚠️ [RULES] Lỗi tra cứu record_rules: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/rules/{model_name}/filter")
def evaluate_model_rules(
    model_name: str,
    role: str = Query("picker", description="Role của user hiện tại, ví dụ: picker, supervisor, manager"),
    perm: str = Query("read", description="Quyền cần kiểm tra: read | write"),
    conn=Depends(get_db),
):
    """
    P3.5 & B3: Thực thi domain expressions của record_rules trên model.
    Dịch các rule thỏa mãn role/perm thành SQL WHERE clause an toàn.
    """
    try:
        perm_col = "perm_read" if perm == "read" else "perm_write"
        cur = conn.execute(
            f"""
            SELECT domain
            FROM record_rules
            WHERE model_name = %s 
              AND (role_key = %s OR role_key = '*')
              AND {perm_col} = TRUE
              AND enabled = TRUE
            """,
            (model_name, role),
        )
        rows = cur.fetchall()
        
        all_clauses = []
        all_params = []
        for r in rows:
            d = r["domain"] if isinstance(r, dict) else r[0]
            if isinstance(d, str):
                try:
                    d = json.loads(d)
                except Exception:
                    d = []
            where_sql, params = domain_to_sql(d)
            if where_sql != "TRUE":
                all_clauses.append(f"({where_sql})")
                all_params.extend(params)

        combined_sql = " AND ".join(all_clauses) if all_clauses else "TRUE"
        return {
            "model": model_name,
            "role": role,
            "perm": perm,
            "rule_count": len(rows),
            "where_sql": combined_sql,
            "params": all_params,
        }
    except Exception as e:
        logger.error(f"⚠️ [RULES] Lỗi thực thi filter domain: {e}")
        raise HTTPException(status_code=500, detail=str(e))

