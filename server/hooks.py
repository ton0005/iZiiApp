# server/hooks.py
"""
Hook Engine (Phase 4 - P4.6)
Đăng ký và kích hoạt logic nghiệp vụ tự động khi dữ liệu thay đổi (before_save, after_save, on_event).
Mượn kiến trúc DbSaveHook từ Smartstore.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Callable, Dict, List, Any, Optional

logger = logging.getLogger(__name__)


class HookContext:
    def __init__(self, conn, tenant_id: str, actor: Optional[str] = None):
        self.conn = conn
        self.tenant_id = tenant_id
        self.actor = actor

    def query_one(self, sql: str, params: tuple = ()) -> Optional[tuple]:
        cur = self.conn.execute(sql, params)
        return cur.fetchone()

    def execute(self, sql: str, params: tuple = ()):
        return self.conn.execute(sql, params)


class HookEngine:
    _instance: Optional[HookEngine] = None

    def __init__(self):
        # hooks structure: { (model, event): [callable] }
        self._hooks: Dict[tuple[str, str], List[Callable]] = {}
        self._register_default_hooks()

    @classmethod
    def get_instance(cls) -> HookEngine:
        if cls._instance is None:
            cls._instance = HookEngine()
        return cls._instance

    def register(self, model: str, event: str, handler: Callable):
        key = (model.lower(), event.lower())
        self._hooks.setdefault(key, []).append(handler)
        logger.debug(f"Registered hook for ({model}, {event}): {handler.__name__}")

    def execute_hooks(
        self,
        event: str,
        model: str,
        record: Dict[str, Any],
        ctx: HookContext,
    ) -> Dict[str, Any]:
        """
        Kích hoạt các hooks đã đăng ký cho (model, event).
        Có thể sửa đổi record (cho before_save) hoặc thực hiện side effects (sau after_save).
        """
        key = (model.lower(), event.lower())
        handlers = self._hooks.get(key, [])
        for handler in handlers:
            try:
                res = handler(ctx, record)
                if isinstance(res, dict) and event.startswith("before"):
                    record = res
            except Exception as e:
                logger.error(f"❌ [HOOK-ENGINE] Lỗi nghiêm trọng khi chạy hook {handler.__name__} cho ({model}, {event}): {e}")
                if event.startswith("after"):
                    raise
        return record

    def _register_default_hooks(self):
        """
        Đăng ký các hook nghiệp vụ cốt lõi của hệ thống.
        """
        # 1. Alone Worker safety config hook (Giải quyết M1)
        self.register("mushroom_jobs", "after_save", _hook_ensure_alone_worker_safety_config)
        self.register("jobs", "after_save", _hook_ensure_alone_worker_safety_config)

        # 2. Completed job hook (P5.8: reset current_stage)
        self.register("mushroom_jobs", "after_save", _hook_job_completed)
        self.register("jobs", "after_save", _hook_job_completed)


def _hook_ensure_alone_worker_safety_config(ctx: HookContext, record: Dict[str, Any]):
    """
    Hook P4.6 & M1: Khi công việc là Alone Worker (hoặc is_solo_job=1),
    tự động đảm bảo bản ghi an toàn mushroom_job_safety_configs tồn tại cho job_id.
    Nhận record là dòng đã merge từ database nên hoạt động 100% chính xác kể cả khi client gửi delta update.
    """
    job_id = record.get("id")
    if not job_id:
        return

    is_solo = record.get("is_solo_job") in (1, "1", True)
    job_type = str(record.get("job_type", "")).lower()

    if is_solo or job_type == "alone_worker":
        # Tra cứu xem đã có config chưa
        cur = ctx.query_one(
            "SELECT id FROM mushroom_job_safety_configs WHERE job_id = %s",
            (job_id,)
        )
        if not cur:
            cfg_id = f"cfg_{job_id}"
            now_str = datetime.now(timezone.utc).isoformat()
            ctx.execute(
                """
                INSERT INTO mushroom_job_safety_configs (
                    id, job_id, check_in_interval_minutes, grace_period_minutes,
                    escalation_target, auto_start_on_job_begin, alarm_type, created_at,
                    tenant_id
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
                """,
                (cfg_id, job_id, 30, 5, "supervisor", True, "push_inapp", now_str, ctx.tenant_id),
            )
            logger.info(f"🛡️ [HOOK] Tự động tạo safety config {cfg_id} cho Alone Worker job {job_id}")


def _hook_job_completed(ctx: HookContext, record: Dict[str, Any]):
    """
    Hook P4.6 & P5.8: Khi job kết thúc (status == 'completed'),
    tự động reset current_stage của phòng grow_rooms thành NULL và cập nhật updated_at.
    """
    status = str(record.get("status", "")).lower()
    if status == "completed":
        room_id = record.get("room_id")
        if room_id:
            now_iso = datetime.now(timezone.utc).isoformat()
            ctx.execute(
                """
                UPDATE grow_rooms 
                SET current_stage = NULL, updated_at = %s 
                WHERE id = %s AND (tenant_id = %s OR tenant_id = 'default')
                """,
                (now_iso, room_id, ctx.tenant_id),
            )
            logger.info(f"🔄 [HOOK] Đã reset current_stage phòng {room_id} về NULL sau khi hoàn thành job {record.get('id')}")

