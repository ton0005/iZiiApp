### **Phương án Extend khi cần scale**

| Giai đoạn | Thay đổi | Lợi ích |
| ----- | ----- | ----- |
| **Bước 1 — Fix nền tảng** | Thay `BaseHTTPRequestHandler` bằng framework production thật (vd: FastAPI \+ Uvicorn, chạy async) | Tăng thông lượng đáng kể trên cùng phần cứng, không cần đổi máy |
| **Bước 2 — Persistence thật** | Thay in-memory Dict/List bằng DB thật (SQLite có WAL hoặc PostgreSQL), có thể thêm Redis làm cache cho dữ liệu nóng | Hết rủi ro mất dữ liệu, chịu tải ghi tốt hơn |
| **Bước 3 — Nâng phần cứng dọc (vertical)** | Tăng RAM/CPU cho máy chủ hiện tại hoặc chuyển sang VM cloud cấu hình cao hơn, đổi HDD → SSD | Giải quyết nút thắt I/O khi có DB ghi đĩa |
| **Bước 4 — Scale ngang (horizontal)** | Khi 1 máy chủ vertical scale không đủ: thêm load balancer \+ nhiều instance app, tách WebSocket ra service riêng | Chịu được hàng nghìn User đồng thời |
| **Notification queue** | Thay "Mock Queue" bằng Redis Queue hoặc managed queue (vd SQS) thật | Đảm bảo không mất notification khi server bận/restart |

