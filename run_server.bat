@echo off
cd /d "%~dp0"
title iZiiApp Standalone Sync Server
echo [1/2] Checking and initializing the database...
python server/db_init.py

echo [2/2] Starting Uvicorn ASGI Server on port 8080...
python server/app.py
pause
