@echo off
cd /d "%~dp0"
title iZiiApp Standalone Multi-Server Engine v2.0

echo ===================================================
echo   iZiiApp Server v2.0 - Multi-Server Mesh Engine
echo ===================================================
echo.

if exist "%~dp0dist\izii_server\izii_server.exe" (
    echo [1/1] Starting compiled izii_server.exe on port 8080...
    "%~dp0dist\izii_server\izii_server.exe"
) else (
    echo [1/2] Checking and initializing database...
    python db_init.py
    echo [2/2] Starting Uvicorn ASGI Server on port 8080...
    python -m uvicorn app:app --host 0.0.0.0 --port 8080 --reload
)

pause
