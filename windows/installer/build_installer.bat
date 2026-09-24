@echo off
chcp 65001 >nul
echo =====================================================
echo    iZiiApp Windows Installer Builder (Inno Setup)
echo =====================================================
echo.

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_installer.ps1"

if %ERRORLEVEL% equ 0 (
    echo.
    echo [OK] Tạo bộ cài đặt thành công!
) else (
    echo.
    echo [ERROR] Quá trình đóng gói thất bại.
)

pause
