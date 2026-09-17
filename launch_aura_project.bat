@echo off
title AURA - Complete Project Runner (Backend + Tunnel + App)
color 0A
cls
echo ===============================================================================
echo                A U R A   P R O J E C T   A U T O - L A U N C H E R
echo                      Smart India Hackathon (SIH) Demo
echo ===============================================================================
echo.

cd /d "%~dp0"

:: 1. Check if backend is already listening on port 8000
netstat -ano | findstr :8000 >nul 2>&1
if %errorlevel% neq 0 (
    echo [1/3] Launching FastAPI Backend Server on port 8000...
    start "Aura Uvicorn Backend" cmd /k "cd /d "%~dp0backend" && color 0B && title Aura Backend Service && venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload"
    timeout /t 3 /nobreak >nul
) else (
    echo [1/3] FastAPI Backend is already running on port 8000.
)

:: 2. Check if ngrok is running
tasklist | findstr /i "ngrok" >nul 2>&1
if %errorlevel% neq 0 (
    echo [2/3] Launching Ngrok Cloud Tunnel...
    start "Aura Ngrok Tunnel" cmd /k "cd /d "%~dp0backend" && color 0D && title Aura Cloud Tunnel && npx ngrok http 8000"
    timeout /t 3 /nobreak >nul
) else (
    echo [2/3] Ngrok Cloud Tunnel is already active.
)

:: 3. Launch the Flutter app
echo.
echo [3/3] Launching Flutter Mobile App on your connected device...
echo ===============================================================================
echo Public Ngrok URL: https://staining-slashing-tinfoil.ngrok-free.dev
echo ===============================================================================
echo.

cd /d "%~dp0mobile_app"
flutter run
