@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
title iZiiApp - Adjust Completed Jobs Time

echo ================================================================================
echo       IZIIAPP - CHINH LAI GIO HOAN THANH JOB (KHONG VUOT STANDARD)
echo ================================================================================
echo.

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Khong tim thay Python trong he thong!
    echo Vui long cai dat Python hoac them vao PATH.
    echo.
    pause
    exit /b 1
)

python fix_over_standard_jobs.py %*

echo.
echo ================================================================================
pause
