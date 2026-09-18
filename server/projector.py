# server/projector.py
"""
Relational Read-Model Projector (Phase 4 - P4.1, P4.2, P4.3)
Chiếu (project) các thay đổi từ sync_mutations vào các bảng quan hệ chuẩn hóa trên PostgreSQL.
Tuân thủ nghiêm ngặt nguyên tắc NT-3 và Q1 (Dirty-Field merge theo cột).
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional, Set

from hooks import HookEngine, HookContext

logger = logging.getLogger(__name__)

# Bảng bí danh (Logical model -> Physical table)
TABLE_ALIASES = {
    "jobs": "mushroom_jobs",
    "rooms": "grow_rooms",
    "job_types": "mushroom_job_types",
    "attendance_events": "mushroom_attendance_events",
    "break_policies": "mushroom_break_policies",
    "daily_timesheets": "mushroom_daily_timesheets",
    "safety_configs": "mushroom_job_safety_configs",
    "safety_logs": "mushroom_safety_checkin_logs",
}


class ReadModelProjector:
    """
    Projector thực hiện bóc tách mutations và đồng bộ vào Read Models của PostgreSQL.
    """
    _table_columns_cache: Dict[str, Set[str]] = {}

    def __init__(self, hook_engine: Optional[HookEngine] = None):
        self.hook_engine = hook_engine or HookEngine.get_instance()

    @classmethod
    def clear_columns_cache(cls):
        """Xóa cache schema cột để nhận diện ngay các thay đổi sau migration (A6)."""
        cls._table_columns_cache.clear()
        logger.info("🧹 [PROJECTOR] Đã xóa cache schema cột bảng.")

    def get_table_columns(self, conn, table_name: str) -> Set[str]:
        """Tra cứu và cache danh sách các cột thực tế của bảng trong Postgres."""
        if table_name in self._table_columns_cache:
            return self._table_columns_cache[table_name]

        cur = conn.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = %s
            """,
            (table_name,),
        )
        cols = {(row["column_name"] if isinstance(row, dict) else row[0]) for row in cur.fetchall()}
        if cols:
            self._table_columns_cache[table_name] = cols
        return cols

    def project_mutation(
        self,
        conn,
        table: str,
        operation: str,
        data: Dict[str, Any],
        seq: int,
        mutation_id: Optional[str] = None,
        tenant_id: str = "default",
        actor: Optional[str] = None,
    ) -> bool:
        """
        Chiếu một mutation đơn lẻ vào bảng quan hệ tương ứng.
        Tuân thủ quy tắc Dirty-field merge:
        - insert: Thêm mới bản ghi đầy đủ.
        - update: Merge các cột có mặt trong data; giữ nguyên các cột vắng mặt; đặt NULL cho null tường minh.
        - delete: Đánh dấu tombstone deleted_at hoặc xoá.
        - Chống out-of-order/replay: chỉ áp dụng khi seq > last_seq (hoặc last_seq IS NULL).
        """
        target_table = TABLE_ALIASES.get(table.lower(), table.lower())
        cols = self.get_table_columns(conn, target_table)
        if not cols:
            # Bảng không tồn tại trong DB read model
            return False

        record_id = data.get("id")
        if not record_id:
            logger.warning(f"⚠️ [PROJECTOR] Bỏ qua mutation bảng {target_table} vì thiếu 'id'")
            return False

        now_utc = datetime.now(timezone.utc).isoformat()
        actor_name = actor or "system"
        op = str(operation).lower()

        # Tạo HookContext
        ctx = HookContext(conn=conn, tenant_id=tenant_id, actor=actor_name)

        # Trigger before_save hook
        data = self.hook_engine.execute_hooks("before_save", target_table, data, ctx)

        if op in ("insert", "create"):
            # Chuẩn bị dữ liệu insert
            insert_payload: Dict[str, Any] = {}
            for col in cols:
                if col in data:
                    insert_payload[col] = data[col]

            # Bổ sung audit columns nếu bảng hỗ trợ
            if "tenant_id" in cols and "tenant_id" not in insert_payload:
                insert_payload["tenant_id"] = tenant_id
            if "created_at" in cols and "created_at" not in insert_payload:
                insert_payload["created_at"] = now_utc
            if "updated_at" in cols:
                insert_payload["updated_at"] = now_utc
            if "created_by" in cols and "created_by" not in insert_payload:
                insert_payload["created_by"] = actor_name
            if "updated_by" in cols:
                insert_payload["updated_by"] = actor_name
            if "last_seq" in cols:
                insert_payload["last_seq"] = seq
            if "last_mutation_id" in cols and mutation_id:
                insert_payload["last_mutation_id"] = mutation_id

            col_names = list(insert_payload.keys())
            placeholders = ["%s"] * len(col_names)
            values = [insert_payload[c] for c in col_names]

            # Kiểm tra xem bản ghi đã tồn tại chưa
            cur = conn.execute(f"SELECT last_seq FROM {target_table} WHERE id = %s", (record_id,))
            row = cur.fetchone()
            if row:
                # Đã tồn tại -> Chuyển sang merge update theo quy tắc Q1
                self._apply_column_merge_update(
                    conn, target_table, cols, data, record_id, seq, mutation_id, actor_name, now_utc, ctx
                )
            else:
                sql = f"INSERT INTO {target_table} ({', '.join(col_names)}) VALUES ({', '.join(placeholders)})"
                conn.execute(sql, tuple(values))

                # Đọc lại dòng đầy đủ sau khi insert để truyền vào hook after_save (A2)
                cur_row = conn.execute(f"SELECT * FROM {target_table} WHERE id = %s", (record_id,))
                inserted_row = cur_row.fetchone()
                if inserted_row:
                    self.hook_engine.execute_hooks("after_save", target_table, dict(inserted_row), ctx)

        elif op in ("update", "patch", "upsert"):
            # Kiểm tra bản ghi có tồn tại trong read model không (P4.2 / A5)
            cur_exist = conn.execute(f"SELECT 1 FROM {target_table} WHERE id = %s", (record_id,))
            if not cur_exist.fetchone():
                # Chưa có trong read model: kiểm tra xem CÓ LỊCH SỬ TRƯỚC ĐÓ trong sync_mutations không
                # Loại trừ chính mutation hiện tại (seq < seq hoặc id != mutation_id)
                cur_mut = conn.execute(
                    """
                    SELECT 1 FROM sync_mutations
                    WHERE "table" = %s 
                      AND ((data::jsonb->>'id') = %s OR id = %s)
                      AND (seq < %s OR seq IS NULL)
                      AND id <> %s
                    LIMIT 1
                    """,
                    (table, record_id, record_id, seq, mutation_id or ""),
                )
                if not cur_mut.fetchone():
                    raise ValueError(
                        f"Record '{record_id}' in table '{target_table}' does not exist on server. "
                        f"Cannot apply partial update to unknown entity (P4.2)."
                    )

            self._apply_column_merge_update(
                conn, target_table, cols, data, record_id, seq, mutation_id, actor_name, now_utc, ctx
            )

        elif op in ("delete", "remove"):
            if "deleted_at" in cols:
                # Tombstone soft delete
                cur = conn.execute(
                    f"""
                    UPDATE {target_table}
                    SET deleted_at = %s,
                        updated_at = %s,
                        last_seq = %s,
                        last_mutation_id = %s,
                        updated_by = %s
                    WHERE id = %s AND (last_seq IS NULL OR %s > last_seq)
                    """,
                    (now_utc, now_utc, seq, mutation_id, actor_name, record_id, seq),
                )
            else:
                cur = conn.execute(f"DELETE FROM {target_table} WHERE id = %s", (record_id,))

        return True

    def _apply_column_merge_update(
        self,
        conn,
        target_table: str,
        cols: Set[str],
        data: Dict[str, Any],
        record_id: str,
        seq: int,
        mutation_id: Optional[str],
        actor_name: str,
        now_utc: str,
        ctx: HookContext,
    ):
        """
        Merge từng cột theo Dirty-Field (NT-3 & Q1):
        Chỉ cập nhật các cột có mặt trong data.
        Bảo lưu nguyên vẹn các cột vắng mặt.
        Sau khi merge, đọc lại merged_row từ DB để chạy hook after_save (A2).
        """
        set_clauses = []
        values = []

        # Các cột được hệ thống gán tường minh bên dưới, không nạp lại từ payload để tránh trùng lặp trong mệnh đề SET
        EXPLICIT_COLS = {"id", "updated_at", "updated_by", "last_seq", "last_mutation_id"}

        # Các cột cập nhật từ payload
        for key, val in data.items():
            if key in EXPLICIT_COLS or key not in cols:
                continue
            # Format JSON/Dict if column is jsonb/text
            if isinstance(val, (dict, list)):
                val = json.dumps(val)
            set_clauses.append(f'"{key}" = %s')
            values.append(val)

        if "updated_at" in cols:
            # Ưu tiên lấy timestamp từ payload nếu client gửi, ngược lại dùng now_utc
            client_updated_at = data.get("updated_at")
            set_clauses.append('"updated_at" = %s')
            values.append(client_updated_at or now_utc)
        if "updated_by" in cols:
            set_clauses.append('"updated_by" = %s')
            values.append(actor_name)
        if "last_seq" in cols:
            set_clauses.append('"last_seq" = %s')
            values.append(seq)
        if "last_mutation_id" in cols and mutation_id:
            set_clauses.append('"last_mutation_id" = %s')
            values.append(mutation_id)

        if not set_clauses:
            return

        # Điều kiện WHERE có kiểm tra seq chống out-of-order/replay
        sql = f"""
            UPDATE {target_table}
            SET {', '.join(set_clauses)}
            WHERE id = %s
              AND (last_seq IS NULL OR %s > last_seq)
        """
        values.append(record_id)
        values.append(seq)

        cur = conn.execute(sql, tuple(values))
        rows_affected = cur.rowcount if hasattr(cur, "rowcount") else 1

        # A2: Chỉ kích hoạt hook after_save khi thực sự có dòng được cập nhật thành công (seq > last_seq)
        if rows_affected > 0:
            cur_merged = conn.execute(f"SELECT * FROM {target_table} WHERE id = %s", (record_id,))
            merged_row = cur_merged.fetchone()
            if merged_row:
                self.hook_engine.execute_hooks("after_save", target_table, dict(merged_row), ctx)

    def update_checkpoint(self, conn, seq: int, projection_name: str = "relational_read_model"):
        """Ghi nhận seq đã project thành công vào projection_checkpoint (P4.3). Không nuốt lỗi (A6)."""
        conn.execute(
            """
            INSERT INTO projection_checkpoint (projection_name, last_projected_seq, updated_at)
            VALUES (%s, %s, now())
            ON CONFLICT (projection_name) DO UPDATE SET
                last_projected_seq = GREATEST(projection_checkpoint.last_projected_seq, EXCLUDED.last_projected_seq),
                updated_at = now()
            """,
            (projection_name, seq),
        )
