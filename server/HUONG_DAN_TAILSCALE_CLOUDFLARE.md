# Hướng Dẫn Thiết Lập & Thử Nghiệm: Cloudflare Tunnel & Tailscale cho iZiiServer

Tài liệu này cung cấp 2 phương án thay thế cho **VS Code DevTunnels** nhằm giải quyết triệt để vấn đề đồng bộ chập chờn ("lúc nhanh lúc chậm") khi tạo Job, nhắn tin hoặc gọi thoại giữa Laptop và Điện thoại (Samsung, iPad,...).

---

## 1. Phân Tích: Vì Sao VS Code DevTunnels Bị "Lúc Nhanh Lúc Chậm"?

Dựa trên phân tích log thực tế tại `C:\Users\CHANH\AppData\Local\iZiiApp\server\logs\server.log`:

1. **Khi đồng bộ SIÊU NHANH (< 1 - 2 giây)**:
   - WebSocket `/chat` đang kết nối ổn định (`[WS] Client connected. Active clients: 3`).
   - Khi Laptop tạo New Job, `EventEngine` lập tức broadcast event `mushroom.job_added` qua WebSocket.
   - Điện thoại nhận được event tức thì và gọi `GET /sync/pull` ngay lập tức.
2. **Khi đồng bộ BỊ CHẬM (15 - 40 giây hoặc đứng)**:
   - Trong log xuất hiện liên tục các sự kiện ngắt kết nối WebSocket:
     `🔌 [WS] Client disconnected. Active clients: 2`
   - **Nguyên nhân**: VS Code DevTunnels đặt máy chủ trung chuyển (Relay Proxy) tại **Australia East** (`*.aue.devtunnels.ms`). 
   - Trên mạng di động (4G hoặc Wi-Fi gia đình), các kết nối TCP nhàn rỗi (idle keepalive) thường xuyên bị timeout hoặc proxy ngắt. Điện thoại cũng gặp lỗi phân giải DNS: `Failed host lookup: '*.aue.devtunnels.ms'`.
   - Khi mất WebSocket, điện thoại **không nhận được tín hiệu tức thì**. Nó phải chờ đến khi timer chạy nền (5s - 30s) hoặc khi người dùng vuốt/chuyển màn hình mới kích hoạt kéo dữ liệu (`/sync/pull`).

---

## 2. Phương Án 1: Cloudflare Tunnel (Khuyên Dùng Cho Mọi Nơi - Không Cần Cài App Trên ĐT)

Cloudflare Tunnel (`cloudflared`) tạo đường hầm mã hoá từ Laptop ra mạng lưới Edge toàn cầu của Cloudflare (có PoP tại Việt Nam: Hà Nội, TP.HCM), hỗ trợ WebSocket cực kỳ ổn định.

### Cách A. Quick Tunnel (Thử nghiệm nhanh trong 1 phút, không cần tài khoản hay tên miền)
1. Trong thư mục `server\`, nhấp đúp chạy file:
   ```cmd
   start_cloudflare_tunnel.bat
   ```
   *(File sẽ tự động tải `cloudflared` nếu máy chưa có)*.
2. Cửa sổ terminal sẽ hiển thị đường link dạng:
   ```text
   Your quick Tunnel has been created! Visit it at:
   https://random-words-1234.trycloudflare.com
   ```
3. Mở **iZiiApp** trên điện thoại Samsung:
   - Vào **Cài đặt (Settings)** -> **Sync Server URL**.
   - Dán URL: `https://random-words-1234.trycloudflare.com` (chọn Lưu).
4. **Kết quả**: 
   - Ping cực thấp (< 25ms).
   - WebSocket giữ kết nối liên tục, không bị ngắt bất ngờ như DevTunnels.
   - Khi tạo Job bên này, bên kia nhảy lên ngay lập tức!

### Cách B. Named Tunnel (Tên miền cố định riêng, chạy vĩnh viễn)
Nếu bạn có một tên miền riêng (ví dụ `izii.mycompany.vn` trên Cloudflare):
1. Đăng nhập Cloudflare Zero Trust Dashboard -> **Networks** -> **Tunnels**.
2. Tạo tunnel mới và copy lệnh cài đặt cho Windows (dạng service chạy ngầm vĩnh viễn cùng Windows).
3. Trỏ Public Hostname: `server.mycompany.vn` -> `http://localhost:8080`.
4. URL trên điện thoại sẽ cố định mãi mãi: `https://server.mycompany.vn`.

---

## 3. Phương Án 2: Tailscale (Mạng Nội Bộ VPN Mesh WireGuard - Ổn Định Tuyệt Đối)

Tailscale kết nối Laptop và Điện thoại thành một mạng nội bộ riêng (Virtual Private Network) dùng giao thức WireGuard P2P.

### Ưu điểm vượt trội:
- **Cùng mạng Wi-Fi**: Dữ liệu đi **thẳng trong mạng nội bộ LAN** (độ trễ ~ 1ms - 2ms, không qua Internet!).
- **Khác mạng (4G / Ngoài đường)**: Kết nối P2P mã hoá trực tiếp giữa 2 máy.
- **Không bao giờ đứt kết nối**: WireGuard là giao thức UDP không trạng thái (stateless), dù điện thoại tắt màn hình hay chuyển từ Wi-Fi sang 4G thì địa chỉ IP vẫn giữ nguyên, WebSocket tự động khôi phục ngay lập tức!
- **IP cố định không bao giờ đổi**: Mỗi máy có 1 IP tĩnh dạng `100.x.y.z`.

### Các bước cài đặt Tailscale:

#### Bước 1: Cài đặt trên Laptop
1. Chạy lệnh cài đặt qua Terminal (hoặc tải từ [tailscale.com](https://tailscale.com/download)):
   ```powershell
   winget install --id Tailscale.Tailscale -e
   ```
2. Mở ứng dụng **Tailscale** ở khay hệ thống (System Tray), chọn **Log in...** và đăng nhập bằng tài khoản Google / Microsoft / GitHub.
3. Sau khi đăng nhập, nhấp chuột phải vào biểu tượng Tailscale để xem địa chỉ IP của Laptop (ví dụ: `100.85.120.45`).

#### Bước 2: Cài đặt trên Điện Thoại (Samsung / iPhone / iPad)
1. Lên **Google Play Store** (hoặc Apple App Store), tìm và cài đặt app **Tailscale**.
2. Mở app Tailscale trên điện thoại và **đăng nhập cùng tài khoản** với Laptop.
3. Bật công tắc **Connect** trên Tailscale điện thoại.

#### Bước 3: Cấu hình iZiiApp trên Điện thoại
1. Mở **iZiiApp** trên điện thoại Samsung.
2. Vào **Settings** -> **Sync Server URL**.
3. Nhập địa chỉ:
   ```text
   http://100.85.120.45:8080
   ```
   *(Thay `100.85.120.45` bằng IP Tailscale thực tế của Laptop)*.
4. Bấm **Lưu**.

---

## 4. Bảng So Sánh Chi Tiết

| Tiêu chí | VS Code DevTunnels | Cloudflare Tunnel | Tailscale |
| :--- | :--- | :--- | :--- |
| **Vị trí Server Proxy** | Australia East (`aue`) | Việt Nam Edge (Hà Nội, HCM) | P2P trực tiếp giữa 2 máy |
| **Độ trễ trung bình (Ping)** | 150ms - 400ms (hay spike) | 15ms - 35ms | **1ms - 5ms** (Wi-Fi) / 20ms (4G) |
| **Độ ổn định WebSocket** | Kém (hay rớt kết nối) | Rất tốt | **Hoàn hảo (WireGuard)** |
| **Cài đặt trên Điện thoại** | Không cần (dùng link HTTPS) | Không cần (dùng link HTTPS) | Cần cài app Tailscale (1 lần) |
| **Địa chỉ URL** | Thay đổi theo phiên VS Code | Cố định (hoặc link Quick) | **Cố định vĩnh viễn (`100.x.y.z`)** |
| **Khuyên dùng cho** | Debug nhanh tính năng web | Demo diện rộng bên ngoài | **Sản xuất nội bộ & thử nghiệm thực tế** |

---

## 5. Kết Luận & Khuyến Nghị

- **Để test nhanh ngay lập tức mà không cần cài thêm app gì lên điện thoại**: Chạy `start_cloudflare_tunnel.bat` và dán link `https://*.trycloudflare.com` vào app.
- **Để vận hành ổn định lâu dài nhất cho nông trại / xưởng sản xuất (nhiều thiết bị di động)**: Cài **Tailscale** cho Laptop và các điện thoại. Đây là giải pháp tiêu chuẩn công nghiệp cho hệ thống phân tán offline-first vì mạng nội bộ WireGuard siêu nhanh và không phụ thuộc vào chất lượng đường truyền quốc tế.
