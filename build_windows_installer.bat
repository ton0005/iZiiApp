@echo off
chcp 65001 >nul
echo =====================================================
echo    Đang khởi động Inno Setup Builder cho iZiiApp...
echo =====================================================
echo.

cd /d "%~dp0windows\installer"
call build_installer.bat
