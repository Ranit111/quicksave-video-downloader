@echo off
title QuickSave Web Launcher
color 0B
echo ==========================================================
echo        STARTING QUICKSAVE VIDEO DOWNLOADER (WEB)
echo ==========================================================
echo.
echo [1/2] Launching Backend API (Port 8000)...
start "QuickSave Backend - Port 8000" cmd /k "cd /d %~dp0backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

timeout /t 2 /nobreak >nul

echo [2/2] Launching Flutter Web App (Port 3000)...
start "QuickSave Web App - Port 3000" cmd /k "cd /d %~dp0mobile_app && flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0"

echo.
echo ==========================================================
echo  Servers are starting in their own windows:
echo    - Web App:     http://localhost:3000
echo    - Backend API: http://localhost:8000/docs
echo ==========================================================
echo.
echo You can close this window now.
pause
