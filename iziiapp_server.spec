# -*- mode: python ; coding: utf-8 -*-
"""
⛔ SPEC NÀY ĐÃ BỊ VÔ HIỆU HOÁ — ĐỪNG DÙNG.

Bản cũ của file này build ra `iziiapp_server.exe` (one-file) và có một lỗi
nghiêm trọng: hiddenimports KHÔNG có `zeroconf`.

Hậu quả: zeroconf có các submodule biên dịch bằng Cython được nạp động, nên
bản build thiếu chúng sẽ ném ImportError khi khởi động mDNS. Mà app.py lại
bọc phần này trong try/except:

    except Exception as e:
        print(f"⚠️  [mDNS] Không khởi động được advertise/discovery: {e}...")

→ Server VẪN CHẠY nhưng mất hoàn toàn khả năng tự phát hiện peer. Nếu
IZIIAPP_PEERS trong .env cũng để trống thì mesh đứng im mà không có lỗi rõ
ràng nào — cực kỳ khó chẩn đoán.

Ngoài ra file này còn tạo ra bản build thứ hai ở server/webhook_server/, kéo
theo một file iziiapp.db riêng — đúng nguồn gốc của tình trạng "3 database
song song" từng gây nhầm lẫn khi debug. Và run_izii_server.bat cũng chỉ tìm
dist\izii_server\izii_server.exe, tức bản build này chưa từng được dùng thật.

════════════════════════════════════════════════════════════════════════════
DÙNG SPEC HỢP NHẤT THAY THẾ:

    cd server
    pyinstaller --noconfirm izii_server.spec

Spec đó đã gộp đủ cả hai nhóm phụ thuộc: zeroconf (mDNS) và
websockets + httpx (webhook & realtime event).
════════════════════════════════════════════════════════════════════════════
"""

raise SystemExit(
    "\n"
    "=========================================================================\n"
    " iziiapp_server.spec da bi vo hieu hoa (thieu zeroconf -> hong mDNS).\n"
    "\n"
    " Dung spec hop nhat:\n"
    "     cd server\n"
    "     pyinstaller --noconfirm izii_server.spec\n"
    "\n"
    " Ket qua: server/dist/izii_server/izii_server.exe\n"
    "=========================================================================\n"
)
