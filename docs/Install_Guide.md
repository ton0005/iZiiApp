Cách tạo file cài đặt iZiiApp_Setup.exe (1-Click):
Cài đặt Inno Setup Compiler (nếu máy chưa có):

powershell


winget install JRSoftware.InnoSetup -e
(hoặc tải file cài tại jrsoftware.org/isdl.php)

Chạy script đóng gói:

powershell


cd windows\installer
.\build_installer.ps1
Kết quả: File cài đặt thành phẩm sẽ nằm tại:
👉 windows\installer\Output\iZiiApp_Setup_v1.0.4.exe