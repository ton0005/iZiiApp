# server/services/timesheet_service.py
# Timesheet Calculation Service (Phase 5 - P5.2)
from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List

from server_config import CONFIG


def _parse_iso(dt_str: Optional[str]) -> Optional[datetime]:
    if not dt_str:
        return None
    try:
        clean = dt_str.replace("Z", "+00:00")
        dt = datetime.fromisoformat(clean)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def calculate_timesheet_for_events(
    employee_id: str,
    plan_date: str,
    events: List[Dict[str, Any]],
    policy: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Pure business logic to compute daily timesheet metrics from attendance events.
    """
    if policy is None:
        policy = {
            "standard_break_minutes": 30,
            "grace_minutes": 5,
            "extra_break_rule": "unpaid",
        }

    standard_break_minutes = int(policy.get("standard_break_minutes", 30))
    grace_minutes = int(policy.get("grace_minutes", 5))
    extra_break_rule = policy.get("extra_break_rule", "unpaid")

    # Sort events by timestamp ascending
    sorted_events = sorted(
        events, key=lambda e: _parse_iso(e.get("timestamp")) or datetime.min.replace(tzinfo=timezone.utc)
    )

    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    total_break_seconds = 0.0
    current_break_start: Optional[datetime] = None

    for ev in sorted_events:
        etype = ev.get("event_type", "").upper()
        ts = _parse_iso(ev.get("timestamp"))
        if not ts:
            continue

        if etype == "CHECK_IN":
            if check_in_time is None or ts < check_in_time:
                check_in_time = ts
        elif etype == "CHECK_OUT":
            if check_out_time is None or ts > check_out_time:
                check_out_time = ts
        elif etype == "BREAK_START":
            current_break_start = ts
        elif etype == "BREAK_END":
            if current_break_start is not None and ts > current_break_start:
                total_break_seconds += (ts - current_break_start).total_seconds()
                current_break_start = None

    total_break_taken_minutes = int(round(total_break_seconds / 60.0))

    gross_worked_minutes = 0
    if check_in_time and check_out_time and check_out_time > check_in_time:
        gross_worked_minutes = int(round((check_out_time - check_in_time).total_seconds() / 60.0))

    allowed_threshold = standard_break_minutes + grace_minutes
    extra_break_minutes = max(0, total_break_taken_minutes - allowed_threshold)

    # Standard lunch break is unpaid
    if extra_break_rule == "deduct_double":
        break_deduction = total_break_taken_minutes + extra_break_minutes
    else:
        break_deduction = total_break_taken_minutes

    paid_minutes = max(0, gross_worked_minutes - break_deduction)
    overtime_minutes = max(0, paid_minutes - 480)  # 8 hours = 480 working minutes

    status = "normal"
    if extra_break_minutes > 0 or check_in_time is None or check_out_time is None:
        status = "needs_review"

    return {
        "employee_id": employee_id,
        "plan_date": plan_date,
        "check_in_time": check_in_time.isoformat() if check_in_time else None,
        "check_out_time": check_out_time.isoformat() if check_out_time else None,
        "total_break_taken_minutes": total_break_taken_minutes,
        "standard_break_allowed_minutes": standard_break_minutes,
        "extra_break_minutes": extra_break_minutes,
        "gross_worked_minutes": gross_worked_minutes,
        "paid_minutes": paid_minutes,
        "overtime_minutes": overtime_minutes,
        "status": status,
    }


def compute_and_save_daily_timesheets(date_str: Optional[str] = None) -> int:
    now_utc = datetime.now(timezone.utc)
    if not date_str:
        date_str = now_utc.strftime("%Y-%m-%d")

    backend = CONFIG.db_backend

    if backend == "postgres":
        from db_postgres import pg_connection

        with pg_connection() as conn:
            # 1. Fetch policy
            cur = conn.execute(
                "SELECT standard_break_minutes, grace_minutes, extra_break_rule "
                "FROM mushroom_break_policies LIMIT 1"
            )
            p_row = cur.fetchone()
            policy = {
                "standard_break_minutes": p_row[0] if p_row else 30,
                "grace_minutes": p_row[1] if p_row else 5,
                "extra_break_rule": p_row[2] if p_row else "unpaid",
            }

            # 2. Fetch events matching date
            cur = conn.execute(
                "SELECT id, employee_id, plan_id, event_type, timestamp, source, location "
                "FROM mushroom_attendance_events "
                "WHERE timestamp LIKE %s OR timestamp LIKE %s",
                (f"{date_str}%", f"{date_str.replace('-', '/')}%"),
            )
            rows = cur.fetchall()

            events_by_emp: Dict[str, List[Dict[str, Any]]] = {}
            for r in rows:
                emp_id = r[1]
                events_by_emp.setdefault(emp_id, []).append({
                    "id": r[0],
                    "employee_id": r[1],
                    "plan_id": r[2],
                    "event_type": r[3],
                    "timestamp": r[4],
                    "source": r[5],
                    "location": r[6],
                })

            count = 0
            for emp_id, ev_list in events_by_emp.items():
                calc = calculate_timesheet_for_events(emp_id, date_str, ev_list, policy)
                ts_id = str(uuid.uuid4())
                calc_time = now_utc.isoformat()

                cur = conn.execute(
                    "SELECT id FROM mushroom_daily_timesheets WHERE employee_id = %s AND plan_date = %s",
                    (emp_id, date_str),
                )
                existing = cur.fetchone()
                if existing:
                    ts_id = existing[0]
                    conn.execute(
                        """
                        UPDATE mushroom_daily_timesheets SET
                            check_in_time = %s,
                            check_out_time = %s,
                            total_break_taken_minutes = %s,
                            standard_break_allowed_minutes = %s,
                            extra_break_minutes = %s,
                            gross_worked_minutes = %s,
                            paid_minutes = %s,
                            overtime_minutes = %s,
                            status = %s,
                            updated_at = %s
                        WHERE id = %s
                        """,
                        (
                            calc["check_in_time"],
                            calc["check_out_time"],
                            calc["total_break_taken_minutes"],
                            calc["standard_break_allowed_minutes"],
                            calc["extra_break_minutes"],
                            calc["gross_worked_minutes"],
                            calc["paid_minutes"],
                            calc["overtime_minutes"],
                            calc["status"],
                            calc_time,
                            ts_id,
                        ),
                    )
                else:
                    conn.execute(
                        """
                        INSERT INTO mushroom_daily_timesheets (
                            id, employee_id, plan_date, check_in_time, check_out_time,
                            total_break_taken_minutes, standard_break_allowed_minutes,
                            extra_break_minutes, gross_worked_minutes, paid_minutes,
                            overtime_minutes, status, created_at, updated_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            ts_id,
                            emp_id,
                            date_str,
                            calc["check_in_time"],
                            calc["check_out_time"],
                            calc["total_break_taken_minutes"],
                            calc["standard_break_allowed_minutes"],
                            calc["extra_break_minutes"],
                            calc["gross_worked_minutes"],
                            calc["paid_minutes"],
                            calc["overtime_minutes"],
                            calc["status"],
                            calc_time,
                            calc_time,
                        ),
                    )

                # postgres sync_mutation
                calc["id"] = ts_id
                calc["created_ats"] = calc_time
                calc["updated_ats"] = calc_time
                conn.execute(
                    """
                    INSERT INTO sync_mutations (
                        id, client_id, "table", operation, data, server_received_at,
                        origin_server_id, actor_user_id, schema_version
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, server_received_at = EXCLUDED.server_received_at
                    """,
                    (
                        f'ts_{ts_id}',
                        "timesheet_service",
                        "mushroom_daily_timesheets",
                        "upsert",
                        json.dumps(calc),
                        calc_time,
                        CONFIG.server_id,
                        "system",
                        1,
                    ),
                )
                count += 1
            conn.commit()
            return count

    else:
        from database import get_db_connection
        conn = get_db_connection()
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT standard_break_minutes, grace_minutes, extra_break_rule "
                "FROM mushroom_break_policies LIMIT 1"
            )
            p_row = cur.fetchone()
            policy = {
                "standard_break_minutes": p_row[0] if p_row else 30,
                "grace_minutes": p_row[1] if p_row else 5,
                "extra_break_rule": p_row[2] if p_row else "unpaid",
            }

            cur.execute(
                "SELECT id, employee_id, plan_id, event_type, timestamp, source, location "
                "FROM mushroom_attendance_events "
                "WHERE timestamp LIKE ? OR timestamp LIKE ?",
                (f"{date_str}%", f"{date_str.replace('-', '/')}%"),
            )
            rows = cur.fetchall()

            events_by_emp = {}
            for r in rows:
                emp_id = r[1]
                events_by_emp.setdefault(emp_id, []).append({
                    "id": r[0],
                    "employee_id": r[1],
                    "plan_id": r[2],
                    "event_type": r[3],
                    "timestamp": r[4],
                    "source": r[5],
                    "location": r[6],
                })

            count = 0
            for emp_id, ev_list in events_by_emp.items():
                calc = calculate_timesheet_for_events(emp_id, date_str, ev_list, policy)
                ts_id = str(uuid.uuid4())
                calc_time = now_utc.isoformat()

                cur.execute(
                    "SELECT id FROM mushroom_daily_timesheets WHERE employee_id = ? AND plan_date = ?",
                    (emp_id, date_str),
                )
                existing = cur.fetchone()
                if existing:
                    ts_id = existing[0]
                    cur.execute(
                        """
                        UPDATE mushroom_daily_timesheets SET
                            check_in_time = ?,
                            check_out_time = ?,
                            total_break_taken_minutes = ?,
                            standard_break_allowed_minutes = ?,
                            extra_break_minutes = ?,
                            gross_worked_minutes = ?,
                            paid_minutes = ?,
                            overtime_minutes = ?,
                            status = ?,
                            updated_at = ?
                        WHERE id = ?
                        """,
                        (
                            calc["check_in_time"],
                            calc["check_out_time"],
                            calc["total_break_taken_minutes"],
                            calc["standard_break_allowed_minutes"],
                            calc["extra_break_minutes"],
                            calc["gross_worked_minutes"],
                            calc["paid_minutes"],
                            calc["overtime_minutes"],
                            calc["status"],
                            calc_time,
                            ts_id,
                        ),
                    )
                else:
                    cur.execute(
                        """
                        INSERT INTO mushroom_daily_timesheets (
                            id, employee_id, plan_date, check_in_time, check_out_time,
                            total_break_taken_minutes, standard_break_allowed_minutes,
                            extra_break_minutes, gross_worked_minutes, paid_minutes,
                            overtime_minutes, status, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            ts_id,
                            emp_id,
                            date_str,
                            calc["check_in_time"],
                            calc["check_out_time"],
                            calc["total_break_taken_minutes"],
                            calc["standard_break_allowed_minutes"],
                            calc["extra_break_minutes"],
                            calc["gross_worked_minutes"],
                            calc["paid_minutes"],
                            calc["overtime_minutes"],
                            calc["status"],
                            calc_time,
                            calc_time,
                        ),
                    )

                calc["id"] = ts_id
                calc["created_at"] = calc_time
                calc["updated_at"] = calc_time
                cur.execute(
                    """
                    INSERT OR REPLACE INTO sync_mutations (
                        id, client_id, "table", operation, data, server_received_at,
                        origin_server_id, actor_user_id, schema_version
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        f"ts_{ts_id}",
                        "timesheet_service",
                        "mushroom_daily_timesheets",
                        "upsert",
                        json.dumps(calc),
                        calc_time,
                        CONFIG.server_id,
                        "system",
                        1,
                    ),
                )
                count += 1
            conn.commit()
            return count
        finally:
            conn.close()
