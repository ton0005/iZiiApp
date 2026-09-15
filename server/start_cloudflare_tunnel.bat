@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo =======================================================
echo    iZiiServer - Cloudflare Quick Tunnel Launcher
echo =======================================================
echo.

:: 1. Kiem tra xem cloudflared da duoc cai dat chua
where cloudflared >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [OK] Da tim thay cloudflared trong he thong.
    goto :START_TUNNEL
)

:: Kiem tra trong thu muc hien tai
if exist "%~dp0cloudflared.exe" (
    echo [OK] Da tim thay cloudflared.exe trong thu muc server.
    set "CLOUDFLARED_CMD=%~dp0cloudflared.exe"
    goto :START_LOCAL_TUNNEL
)

echo [!] Chua tim thay cloudflared tren may.
echo [*] Dang tu dong cai dat cloudflared qua winget...
winget install --id Cloudflare.cloudflared -e --source winget --accept-source-agreements --accept-package-agreements

where cloudflared >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [OK] Cai dat cloudflared thanh cong!
    goto :START_TUNNEL
)

echo.
echo [!] Khong the cai tu dong qua winget.
echo [*] Ban co the tai cloudflared.exe thu cong tu:
echo     https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
echo     va doi ten thanh cloudflared.exe roi dat vao thu muc server nay.
echo.
pause
exit /b 1

:START_TUNNEL
set "CLOUDFLARED_CMD=cloudflared"

:START_LOCAL_TUNNEL
echo.
echo =======================================================
echo  Dang khoi tao Cloudflare Tunnel tro toi http://127.0.0.1:8080 ...
echo.
echo  LUU Y:
echo  1. Hay dam bao iZiiServer (run_server.bat) DANG CHAY tren cong 8080!
echo  2. Copy duong link https://*.trycloudflare.com hien thi ben duoi
echo     va dan vao muc: iZiiApp -> Settings -> Sync Server URL tren dien thoai.
echo =======================================================
echo.

"%CLOUDFLARED_CMD%" tunnel --url http://127.0.0.1:8080
pause
