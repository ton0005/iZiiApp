import os
import sys

# Cho phép `import radio_bridge` khi chạy pytest từ thư mục gốc repo.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
