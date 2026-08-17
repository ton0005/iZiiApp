#!/usr/bin/env python3
"""
Dọn mutation trùng lặp trong sync_mutations.

BỐI CẢNH: `checkSoloJobsAlarms()` phía Flutter chạy mỗi 30 giây và ghi một
mutation `grow_rooms` MỖI LẦN CHẠY cho công việc Alone Worker quá giờ, không
kiểm phòng đã ở trạng thái đó chưa. Mỗi bản ghi mang một UUID mới nên
`INSERT OR REPLACE` không gộp được. Kết quả: `/sync/status` báo 15.272 bản ghi
`grow_rooms` trên tổng 15.333 — 99,6% là rác.

Lỗi gốc đã vá trong `repository.dart` (kiểm trạng thái trước khi ghi) và có
thêm lưới chặn ở `sync_service.queueMutation`. Script này dọn phần đã lỡ sinh.

CÁCH DÙNG:
    python don_mutation_trung.py            # chỉ xem, KHÔNG xoá
    python don_mutation_trung.py --apply    # xoá thật (tự sao lưu trước)

NGUYÊN TẮC: với mỗi (table, record_id, operation) có payload giống hệt nhau
(bỏ qua dấu thời gian), GIỮ LẠI BẢN MỚI NHẤT theo seq và xoá phần còn lại.
Máy khách chỉ cần trạng thái cuối cùng, không cần 15.000 lần lặp lại nó.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
from collections import defaultdict
from datetime import datetime

# Bỏ các trường chỉ mang dấu thời gian khi so sánh — chúng đổi mỗi lần ghi
# nên nếu tính vào thì không bao giờ phát hiện được trùng.
_IGNORED_FIELDS = {"updated_at", "updatedAt", "created_at", "createdAt", "timestamp"}


def fingerprint(raw_data: str) -> str:
    """Vân tay nội dung, không phụ thuộc thứ tự khoá và dấu thời gian."""
    try:
        obj = json.loads(raw_data)
    except Exception:
        return raw_data
    if not isinstance(obj, dict):
        return raw_data
    significant = {k: v for k, v in obj.items() if k not in _IGNORED_FIELDS}
    return json.dumps(significant, sort_keys=True, ensure_ascii=False)


def record_id_of(raw_data: str) -> str:
    try:
        obj = json.loads(raw_data)
        if isinstance(obj, dict):
            return str(obj.get("id", ""))
    except Exception:
        pass
    return ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", help="Đường dẫn iziiapp.db (mặc định: lấy từ cấu hình)")
    ap.add_argument("--apply", action="store_true", help="Xoá thật thay vì chỉ xem")
    args = ap.parse_args()

    db_path = args.db
    if not db_path:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        try:
            from database import DB_PATH
            db_path = DB_PATH
        except Exception as e:
            print(f"Không xác định được đường dẫn database: {e}")
            return 1

    if not os.path.exists(db_path):
        print(f"Không tìm thấy database: {db_path}")
        return 1

    print(f"Database: {db_path}")
    print(f"Chế độ  : {'XOÁ THẬT' if args.apply else 'chỉ xem (thêm --apply để xoá)'}\n")

    if args.apply:
        backup = f"{db_path}.backup-{datetime.now():%Y%m%d-%H%M%S}"
        shutil.copy2(db_path, backup)
        print(f"Đã sao lưu → {backup}\n")

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    total = conn.execute("SELECT COUNT(*) c FROM sync_mutations").fetchone()["c"]
    print(f"Tổng mutation hiện có: {total:,}\n")

    print("Phân bố theo bảng:")
    rows = conn.execute(
        'SELECT "table" t, COUNT(*) n FROM sync_mutations '
        'GROUP BY "table" ORDER BY n DESC'
    ).fetchall()
    for r in rows:
        print(f"   {r['t']:<36} {r['n']:>8,}")

    # Gom nhóm theo (bảng, id bản ghi, thao tác, vân tay nội dung)
    groups: dict[tuple, list[int]] = defaultdict(list)
    cur = conn.execute(
        'SELECT seq, "table" AS t, operation, data FROM sync_mutations ORDER BY seq'
    )
    for row in cur:
        rid = record_id_of(row["data"])
        if not rid:
            continue
        key = (row["t"], rid, row["operation"], fingerprint(row["data"]))
        groups[key].append(row["seq"])

    doomed: list[int] = []
    per_table: dict[str, int] = defaultdict(int)
    for (table, _rid, _op, _fp), seqs in groups.items():
        if len(seqs) > 1:
            # Giữ bản mới nhất, xoá phần còn lại.
            doomed.extend(seqs[:-1])
            per_table[table] += len(seqs) - 1

    if not doomed:
        print("\n✅ Không có mutation trùng lặp nào.")
        conn.close()
        return 0

    print(f"\nTìm thấy {len(doomed):,} mutation trùng (giữ bản mới nhất mỗi nhóm):")
    for t, n in sorted(per_table.items(), key=lambda kv: -kv[1]):
        print(f"   {t:<36} {n:>8,}")
    print(f"\nSau khi dọn còn: {total - len(doomed):,} bản ghi "
          f"({100 * len(doomed) / total:.1f}% là rác)")

    if not args.apply:
        print("\nChạy lại với --apply để xoá thật.")
        conn.close()
        return 0

    for i in range(0, len(doomed), 500):
        batch = doomed[i:i + 500]
        conn.execute(
            f"DELETE FROM sync_mutations WHERE seq IN ({','.join('?' * len(batch))})",
            batch,
        )
    conn.commit()
    conn.execute("VACUUM")
    conn.close()

    print(f"\n✅ Đã xoá {len(doomed):,} bản ghi và nén lại database.")
    print("⚠️  Máy khách nào đang giữ con trỏ seq cũ sẽ tự động đồng bộ lại — "
          "cơ chế cursor_reset đã xử lý việc này.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
