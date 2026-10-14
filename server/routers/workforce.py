# server/routers/workforce.py
"""
Workforce & Timesheet Management Router (Phase 5 - P5.2, P5.3)
Kết nối dịch vụ chấm công (timesheet_service) với API phục vụ app Flutter và Dashboard quản lý.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from pydantic import BaseModel

from fastapi import APIRouter, Depends, HTTPException, Query
from dependencies import get_db
from services.timesheet_service import compute_and_save_daily_timesheets

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/workforce", tags=["Workforce & Timesheets"])


class CalculateTimesheetRequest(BaseModel):
    plan_date: Optional[str] = None


@router.post("/timesheets/calculate")
def calculate_timesheets(req: CalculateTimesheetRequest = CalculateTimesheetRequest()):
    """
    P5.2: Tổng hợp sự kiện điểm danh (attendance_events) thành bảng chấm công (daily_timesheets).
    Tính toán giờ làm gross, thời gian nghỉ chuẩn/vượt, phạt nghỉ vượt, và giờ làm được trả/OT.
    """
    date_str = req.plan_date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        count = compute_and_save_daily_timesheets(date_str)
        return {
            "status": "success",
            "plan_date": date_str,
            "processed_count": count,
            "message": f"Đã tính toán và cập nhật {count} bản ghi chấm công cho ngày {date_str}.",
        }
    except Exception as e:
        logger.error(f"⚠️ [WORKFORCE] Lỗi tính toán bảng chấm công: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/timesheets/daily")
def get_daily_timesheets(
    plan_date: Optional[str] = Query(None, description="Ngày làm việc YYYY-MM-DD"),
    employee_id: Optional[str] = Query(None, description="Mã nhân viên"),
    conn=Depends(get_db),
):
    """
    Tra cứu danh sách bảng chấm công hàng ngày.
    """
    try:
        where_clauses = ["1=1"]
        params = []
        if plan_date:
            where_clauses.append("plan_date = %s")
            params.append(plan_date)
        if employee_id:
            where_clauses.append("employee_id = %s")
            params.append(employee_id)

        sql = f"""
            SELECT id, employee_id, plan_date, check_in_time, check_out_time,
                   total_break_taken_minutes, standard_break_allowed_minutes,
                   extra_break_minutes, gross_worked_minutes, paid_minutes,
                   overtime_minutes, assigned_team_color, status, created_at, updated_at
            FROM mushroom_daily_timesheets
            WHERE {' AND '.join(where_clauses)}
            ORDER BY plan_date DESC, employee_id ASC
        """
        cur = conn.execute(sql, tuple(params))
        rows = [dict(r) for r in cur.fetchall()]
        return {
            "count": len(rows),
            "timesheets": rows,
        }
    except Exception as e:
        logger.error(f"⚠️ [WORKFORCE] Lỗi tra cứu bảng chấm công: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/attendance/events")
def get_attendance_events(
    date: Optional[str] = Query(None, description="Ngày điểm danh YYYY-MM-DD"),
    employee_id: Optional[str] = Query(None, description="Mã nhân viên"),
    conn=Depends(get_db),
):
    """
    Tra cứu danh sách sự kiện điểm danh (check-in, check-out, break-start, break-end).
    """
    try:
        where_clauses = ["1=1"]
        params = []
        if date:
            where_clauses.append("(timestamp LIKE %s OR timestamp LIKE %s)")
            params.append(f"{date}%")
            params.append(f"{date.replace('-', '/')}%")
        if employee_id:
            where_clauses.append("employee_id = %s")
            params.append(employee_id)

        sql = f"""
            SELECT id, employee_id, plan_id, event_type, timestamp, source, location, created_at
            FROM mushroom_attendance_events
            WHERE {' AND '.join(where_clauses)}
            ORDER BY timestamp ASC
        """
        cur = conn.execute(sql, tuple(params))
        rows = [dict(r) for r in cur.fetchall()]
        return {
            "count": len(rows),
            "events": rows,
        }
    except Exception as e:
        logger.error(f"⚠️ [WORKFORCE] Lỗi tra cứu sự kiện điểm danh: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/break-policies")
def get_break_policies(conn=Depends(get_db)):
    """
    P5.3: Lấy danh sách chính sách giải lao áp dụng.
    """
    try:
        cur = conn.execute(
            "SELECT id, standard_break_minutes, grace_minutes, extra_break_rule FROM mushroom_break_policies"
        )
        rows = [dict(r) for r in cur.fetchall()]
        return {
            "count": len(rows),
            "policies": rows,
        }
    except Exception as e:
        logger.error(f"⚠️ [WORKFORCE] Lỗi tra cứu chính sách giải lao: {e}")
        raise HTTPException(status_code=500, detail=str(e))
