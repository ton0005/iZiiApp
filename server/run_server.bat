@echo off
cd /d "%~dp0"
if "%IZIIAPP_SERVER_DB_PATH%"=="" set "IZIIAPP_SERVER_DB_PATH=%~dp0data\iziiapp.db"

echo ============================================
echo   iZiiApp Server v2.0 - Repository Pattern
echo ============================================
echo.

echo [1/2] Checking and initializing the database...
python db_init.py

echo [2/2] Starting Uvicorn ASGI Server on port 8080...
:: Use uvicorn to run both API and WebSocket simultaneously on port 8080
:: Exclude build directories to prevent FileNotFoundError scan race conditions
python -m uvicorn app:app --host 0.0.0.0 --port 8080 --reload --reload-exclude "build" --reload-exclude ".dart_tool" --reload-exclude ".git" --reload-exclude "data" --reload-exclude "__pycache__"
pause
