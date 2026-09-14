@echo off
title QuickSave Mobile Launcher
color 0A

echo ==========================================================
echo       STARTING QUICKSAVE VIDEO DOWNLOADER (MOBILE)
echo ==========================================================
echo.

:: 1. Start Backend API Server in a separate window
echo [1/3] Launching Backend API (Port 8000)...
start "QuickSave Backend - Port 8000" cmd /k "cd /d %~dp0backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

timeout /t 2 /nobreak >nul

:: 2. Set up ADB Port Forwarding (so the phone can access http://localhost:8000)
echo [2/3] Setting up USB port forwarding (adb reverse tcp:8000 tcp:8000)...
set "ADB_PATH=C:\Users\ranit\AppData\Local\Android\Sdk\platform-tools\adb.exe"

if exist "%ADB_PATH%" (
    "%ADB_PATH%" reverse tcp:8000 tcp:8000 >nul 2>&1
) else (
    adb reverse tcp:8000 tcp:8000 >nul 2>&1
)

:: 3. Detect connected Android device ID
set "DEVICE_ID="
if exist "%ADB_PATH%" (
    for /f "skip=1 tokens=1" %%d in ('"%ADB_PATH%" devices') do (
        if not "%%d"=="" if not "%%d"=="List" if not defined DEVICE_ID set "DEVICE_ID=%%d"
    )
)

echo.
cd /d "%~dp0mobile_app"

if defined DEVICE_ID (
    echo [3/3] Target Android device detected: %DEVICE_ID%
    echo Building and installing QuickSave onto your phone...
    echo.
    flutter run -d %DEVICE_ID%
) else (
    echo [3/3] No specific device detected via ADB, scanning Flutter devices...
    echo.
    flutter run -d 2201117PI
)

echo.
echo ==========================================================
echo App process finished.
echo ==========================================================
pause
