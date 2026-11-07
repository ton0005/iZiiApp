"""
iZii Radio Bridge — nhận gói dữ liệu Hytera (HDAP/HSTRP qua UDP) từ repeater HR1062 hoặc
bộ đàm, đổi thành sự kiện báo động và đẩy sang iZiiServer (/api/v1/radio/events).

Tách khỏi server/ có chủ đích: tiến trình riêng, KHÔNG đóng gói vào izii_server.exe, vì lớp giải
mã dùng ok-dmrlib (AGPL-3.0) và tài liệu ADK của Hytera nằm dưới NDA. Xem README.md.
"""
