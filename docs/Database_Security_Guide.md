# Hướng Dẫn Quản Lý & Bảo Mật Cơ Sở Dữ Liệu iZiiApp

Tài liệu hướng dẫn chi tiết vị trí lưu trữ, cách kiểm tra dữ liệu, quản lý file log và phương án bảo mật nâng cao cho **iZiiApp (Flutter Client)** và **iZiiServer (FastAPI Backend)**.

---

## 📁 1. Vị Trí Lưu Trữ File Cơ Sở Dữ Liệu (Database Locations)

### 1.1 Ứng dụng Flutter Client (`iZiiApp`)
File SQLite chính: `izii_app_db.sqlite`

- **Vị trí bảo mật mới (Đã cập nhật)**:
  ```text
  C:\Users\CHANH\AppData\Local\izii_app\data\izii_app_db.sqlite
  ```
- **Thao tác tự động**: Hệ thống tự động di chuyển (migrate) dữ liệu từ vị trí cũ (`OneDrive\Documents`) sang thư mục `AppData\Local` riêng biệt của ứng dụng để tránh bị Cloud auto-sync hoặc người dùng thông thường truy cập công khai.
- **Trên thiết bị di động (Android / iOS)**:
  ```text
  <Thư_mục_ứng_dụng>/izii_app_db.sqlite
  ```

### 1.2 Máy chủ Backend Server (`iZiiServer`)
File SQLite chính: `iziiapp.db`

- **Khi chạy code Python (`run_server.bat` / `app.py`)**:
  ```text
  c:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server\data\iziiapp.db
  ```
- **Khi chạy bản build file thực thi (`izii_server.exe`)**:
  ```text
  c:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server\dist\izii_server\data\iziiapp.db
  ```
- **Tùy chỉnh linh hoạt**: Có thể đặt biến môi trường `IZIIAPP_SERVER_DB_PATH` để thay đổi đường dẫn lưu trữ trên server thật.

---

## 📑 2. File Nhật Ký & Giao Dịch (Logs & WAL Files)

1. **File Log máy chủ Backend (`server.log`)**:
   - Vị trí: `server/data/logs/server.log`
   - Tính năng: Tự động xoay vòng log (Log Rotation). Khi dung lượng vượt quá **10MB**, file cũ được đổi tên thành `server.log.old`.

2. **File Nhật ký giao dịch đệm SQLite (WAL Mode)**:
   - File log giao dịch tạm thời: `iziiapp.db-wal`
   - File chỉ mục bộ nhớ dùng chung: `iziiapp.db-shm`
   - Vị trí: Nằm ngay trong thư mục chứa file `iziiapp.db`.

---

## 🛠️ 3. Cách Mở & Xem Dữ Liệu Bằng Ứng Dụng Bên Ngoài

Cả 2 file database đều là định dạng chuẩn **SQLite 3**. Bạn có thể dùng các phần mềm sau để xem dữ liệu:

### 3.1 Dùng DB Browser for SQLite (Khuyên dùng)
- **Tải ứng dụng**: [sqlitebrowser.org](https://sqlitebrowser.org/)
- **Cách xem**: Mở ứng dụng ➔ Bấm **Open Database** ➔ Tìm đến đường dẫn file `.sqlite` hoặc `.db`.
- **Tính năng**:
  - Xem danh sách bảng (`mushroom_employees`, `grow_rooms`, `chat_messages`...).
  - Duyệt dữ liệu dạng bảng (`Browse Data`).
  - Chạy truy vấn SQL tự do (`Execute SQL`).
  - Xuất dữ liệu ra file Excel/CSV.

### 3.2 Dùng Extension trực tiếp trong VS Code
- Cài đặt extension: **SQLite Viewer** hoặc **vscode-sqlite**.
- Click đúp trực tiếp vào file `.sqlite` hoặc `.db` trong cửa sổ làm việc của VS Code để xem dữ liệu.

---

## 🛡️ 4. Hướng Dẫn Nâng Cấp Bảo Mật Chống Đánh Cắp Dữ Liệu

### 4.1 Mã hóa toàn bộ File Database bằng SQLCipher (AES-256)
- **Cơ chế**: Mã hóa cứng tập tin SQLite bằng thuật toán **AES-256 bit**.
- **Hiệu quả**: Khi ai đó lấy được file `.sqlite` / `.db` và mở bằng DB Browser, phần mềm sẽ thông báo `File is encrypted or is not a database` và **không thể đọc được dữ liệu**.
- **Cách tích hợp**:
  - **Flutter**: Sử dụng package `sqflite_sqlcipher` / `drift` với kho khóa bảo mật `flutter_secure_storage` (Windows Credential Manager / Android Keystore).
  - **Python Server**: Sử dụng thư viện `sqlcipher3` bọc ngoài SQLite và truyền khóa giải mã qua biến môi trường.

### 4.2 Phân quyền tập tin ở cấp Hệ điều hành (Windows Security / File Permissions)
- Click chuột phải vào file `.sqlite` / `.db` ➔ Chọn **Properties** ➔ Thẻ **Security**.
- Bấm **Edit...** ➔ Xóa quyền truy cập của nhóm `Everyone`, `Users`, `Guests`.
- Chỉ cấp quyền **Full control** cho duy nhất **Tài khoản Windows cá nhân của bạn**.

### 4.3 Mã hóa từng trường dữ liệu nhạy cảm (Field-Level Encryption)
- Mật khẩu nhân viên được mã hóa một chiều SHA-256 (`passwordHash`).
- Nội dung chat và thông tin cá nhân cần mã hóa AES-256-GCM trước khi ghi vào Database.

---

## ⚠️ 5. Các Lưu Ý Quan Trọng
1. **Không mở file ở chế độ chỉnh sửa khi ứng dụng/server đang chạy**: Hãy đóng app/server trước khi sửa dữ liệu thủ công bằng DB Browser để tránh lỗi `database is locked`.
2. **Nếu chỉ xem dữ liệu khi app đang chạy**: Hãy chọn chế độ **Read-Only** trong phần mềm đọc SQLite.
