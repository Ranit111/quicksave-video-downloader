@echo off
title QuickSave All-in-One Launcher
color 0B

:MENU
cls
echo ==========================================================
echo               QUICK SAVE CONTROLLER MENU
echo ==========================================================
echo.
echo   [1] Start Web Browser Mode (Port 3000 + Backend Port 8000)
echo   [2] Start Web in Chrome (Direct Window + Backend)
echo   [3] Start Mobile App (Android Phone / Emulator + Backend)
echo   [4] Start Backend API Server Only (Port 8000)
echo   [5] Exit
echo.
echo ==========================================================
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto WEB
if "%choice%"=="2" goto CHROME
if "%choice%"=="3" goto MOBILE
if "%choice%"=="4" goto BACKEND
if "%choice%"=="5" exit
goto MENU

:WEB
echo.
echo Starting Backend and Web Server...
call "%~dp0run_web.bat"
exit

:CHROME
echo.
echo [1/2] Starting Backend...
start "QuickSave Backend - Port 8000" cmd /k "cd /d %~dp0backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
timeout /t 2 /nobreak >nul
echo [2/2] Launching Chrome...
cd /d "%~dp0mobile_app"
flutter run -d chrome
exit

:MOBILE
echo.
echo Starting Backend and Mobile App...
call "%~dp0run_mobile.bat"
exit

:BACKEND
echo.
echo Starting Backend Only...
cd /d "%~dp0backend"
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
exit
