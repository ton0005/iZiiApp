# Hướng Dẫn Đóng Gói Bộ Cài Đặt Tự Động Cho iZiiApp (Windows)
## iZiiApp Windows Installer Packaging Guide

**Mục đích:** Tạo file cài đặt Setup (`.exe`) tự động cho iZiiApp, giải quyết triệt để lỗi thiếu DLL (`MSVCP140.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`) trên các máy tính mới.

---

## 🚀 Cách 1: Tạo bộ cài đặt tự động 1-Click (Inno Setup - Khuyến nghị)

Script [build_installer.ps1](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/windows/installer/build_installer.ps1) sẽ tự động:
1. Kiểm tra bản build Flutter Windows Release.
2. Tự động tải `vc_redist.x64.exe` chính thức từ Microsoft vào thư mục `redist/`.
3. Tự động biên dịch ra file cài đặt `Output/iZiiApp_Setup_v1.0.4.exe`.

### Các bước thực hiện:
1. Mở **PowerShell** tại thư mục `windows/installer`:
   ```powershell
   cd windows\installer
   .\build_installer.ps1
   ```
2. Nếu máy chưa có phần mềm **Inno Setup**, bạn có thể cài đặt nhanh qua lệnh:
   ```powershell
   winget install JRSoftware.InnoSetup -e
   ```
   *(hoặc tải file cài tại [jrsoftware.org/isdl.php](https://jrsoftware.org/isdl.php))*
3. File cài đặt Setup hoàn chỉnh sẽ được tạo tại thư mục:  
   `windows\installer\Output\iZiiApp_Setup_v1.0.4.exe`

---

## 📦 Cách hoạt động của Bộ cài đặt trên máy người dùng

Khi mang file `iZiiApp_Setup_v1.0.4.exe` sang bất kỳ máy tính Windows mới nào:
1. Trình cài đặt tự động kiểm tra xem máy đã có **Microsoft Visual C++ 2015-2022 Redistributable (x64)** hay chưa.
2. **Nếu chưa có:** Trình cài đặt tự động kích hoạt `vc_redist.x64.exe /install /passive /norestart /quiet` ngầm để cài đủ các file DLL hệ thống (`MSVCP140.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`).
3. Giải nén toàn bộ ứng dụng iZiiApp vào thư mục `C:\Program Files\iZiiApp`.
4. Tạo biểu tượng Shortcut ngoài màn hình **Desktop** và trong menu **Start**.
5. Cung cấp chức năng gỡ cài đặt (Uninstaller) trong Control Panel.

---

## 🛠️ Danh sách các tệp liên quan

| Tệp tin | Vai trò |
|---|---|
| [izii_app_setup.iss](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/windows/installer/izii_app_setup.iss) | Script cấu hình Inno Setup (kiểm tra Registry & cài ngầm VC++). |
| [izii_app_setup.nsi](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/windows/installer/izii_app_setup.nsi) | Script cấu hình NSIS (tuỳ chọn nếu dùng Nullsoft Installer). |
| [build_installer.ps1](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/windows/installer/build_installer.ps1) | Script PowerShell tự động tải redist và đóng gói thành phẩm 1-Click. |
