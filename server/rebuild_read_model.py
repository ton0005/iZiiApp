# server/rebuild_read_model.py
"""
P4.8: Rebuild Relational Read Model from Sync Mutations.
Xóa toàn bộ read model tables, reset projection_checkpoint,
và replay tuần tự toàn bộ mutations từ sync_mutations theo thứ tự seq ASC.
Đảm bảo tính idempotent và tính toàn vẹn (DoD P4.8).
"""
from __future__ import annotations

import os
import sys
import json
import logging
from typing import List, Optional

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from dependencies import open_connection
from projector import ReadModelProjector, TABLE_ALIASES

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

READ_MODEL_TABLES = [
    "mushroom_jobs",
    "grow_rooms",
    "mushroom_job_types",
    "mushroom_attendance_events",
    "mushroom_break_policies",
    "mushroom_daily_timesheets",
    "mushroom_job_safety_configs",
    "mushroom_safety_checkin_logs",
    "tasks",
    "work_sessions",
]


def rebuild_read_model(target_tables: Optional[List[str]] = None, dry_run: bool = False) -> int:
    """
    Xóa sạch dữ liệu read model và replay toàn bộ sync_mutations theo seq ASC.
    """
    tables_to_clear = target_tables or READ_MODEL_TABLES
    projector = ReadModelProjector()
    projector.clear_columns_cache()

    with open_connection() as conn:
        if dry_run:
            cur = conn.execute("SELECT count(*) as total FROM sync_mutations WHERE seq IS NOT NULL")
            row = cur.fetchone()
            total = row["total"] if isinstance(row, dict) else row[0]
            logger.info(f"[DRY-RUN] Sẽ replay {total} mutations cho các bảng {tables_to_clear}")
            return total

        logger.info(f"🧹 Đang xóa sạch dữ liệu read model ({len(tables_to_clear)} bảng)...")
        for tbl in reversed(tables_to_clear):
            try:
                conn.execute(f"TRUNCATE TABLE {tbl} CASCADE")
            except Exception as e:
                try:
                    conn.execute(f"DELETE FROM {tbl}")
                except Exception as de:
                    logger.warning(f"Không thể xóa bảng {tbl}: {de}")
        conn.commit()

        conn.execute("DELETE FROM projection_checkpoint WHERE projection_name = 'relational_read_model'")
        conn.commit()
        logger.info("✅ Đã reset checkpoint. Bắt đầu replay sync_mutations theo seq ASC...")

        cur_muts = conn.execute(
            """
            SELECT id, "table", operation, data, seq, actor_user_id, schema_version
            FROM sync_mutations
            WHERE seq IS NOT NULL
            ORDER BY seq ASC
            """
        )
        mutations = cur_muts.fetchall()
        logger.info(f"📦 Tìm thấy {len(mutations)} mutations cần replay.")

        replayed_count = 0
        last_seq = 0

        for row in mutations:
            m = dict(row)
            m_data = m.get("data")
            if isinstance(m_data, str):
                try:
                    m_data = json.loads(m_data)
                except Exception:
                    m_data = {}
            if not isinstance(m_data, dict):
                m_data = {}

            seq = m["seq"]
            table = m["table"]
            op = m["operation"]
            mut_id = m["id"]
            actor = m.get("actor_user_id") or "rebuild_system"
            tenant_id = m_data.get("tenant_id") or "default"

            try:
                with conn.transaction():
                    projector.project_mutation(
                        conn=conn,
                        table=table,
                        operation=op,
                        data=m_data,
                        seq=seq,
                        mutation_id=mut_id,
                        tenant_id=tenant_id,
                        actor=actor,
                    )
                replayed_count += 1
                if seq > last_seq:
                    last_seq = seq
            except Exception as pe:
                logger.warning(f"⚠️ Bỏ qua mutation lỗi trong quá trình replay seq={seq} ({table}): {pe}")

        if last_seq > 0:
            projector.update_checkpoint(conn, last_seq)

        conn.commit()
        logger.info(f"🎉 Hoàn tất replay: {replayed_count}/{len(mutations)} mutations đã được chiếu lại thành công. Checkpoint={last_seq}.")
        return replayed_count


if __name__ == "__main__":
    rebuild_read_model()
