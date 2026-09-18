#!/usr/bin/env bash
# Script điều chỉnh giờ hoàn thành Job (không vượt quá Standard) trên Linux/Ubuntu/WSL

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================================"
echo "      IZIIAPP - CHINH LAI GIO HOAN THANH JOB (KHONG VUOT STANDARD) - LINUX/WSL"
echo "================================================================================"
echo ""

# Kiểm tra python3 hoặc python
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ Lỗi: Không tìm thấy Python! Vui lòng cài đặt: sudo apt install python3 python3-pip"
    exit 1
fi

# Chạy script
$PYTHON_CMD server/fix_over_standard_jobs.py "$@"
