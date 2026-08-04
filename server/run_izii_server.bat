@echo off
cd /d "%~dp0"
if "%IZIIAPP_SERVER_DB_PATH%"=="" set "IZIIAPP_SERVER_DB_PATH=%~dp0data\iziiapp.db"

echo ===================================================
echo   iZiiApp Server v2.0 - Multi-Server Mesh Engine
echo ===================================================
echo.

set "EXE_DIR=%~dp0dist\izii_server"
set "EXE_PATH=%EXE_DIR%\izii_server.exe"

if exist "%EXE_PATH%" (
    rem .env KHONG duoc dong goi vao ban build (secret khong nen nam trong
    rem artifact). Khi chay dang frozen, server_config._load_env_file() doc
    rem file .env nam CANH file .exe -> copy sang neu chua co hoac da cu.
    if exist "%~dp0.env" (
        if not exist "%EXE_DIR%\.env" (
            copy /Y "%~dp0.env" "%EXE_DIR%\.env" >nul
            echo [ENV] Da copy .env sang canh izii_server.exe
        ) else (
            xcopy /Y /D /Q "%~dp0.env" "%EXE_DIR%\" >nul
        )
    ) else (
        echo [!] Canh bao: khong tim thay server\.env
        echo     Server se chay o che do standalone va TU CHOI moi ket noi WebSocket.
    )

    echo [1/1] Starting compiled izii_server.exe on port 8080...
    "%EXE_PATH%"
) else (
    echo [1/2] Checking and initializing database...
    python db_init.py
    echo [2/2] Starting Uvicorn ASGI Server on port 8080...
    python -m uvicorn app:app --host 0.0.0.0 --port 8080 --reload
)

pause
