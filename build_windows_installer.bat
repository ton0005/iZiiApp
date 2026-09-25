@echo off
chcp 65001 >nul
echo =====================================================
echo    Dang khoi dong Inno Setup Builder cho iZiiApp...
echo =====================================================
echo.

cd /d "%~dp0windows\installer"
call build_installer.bat %*
