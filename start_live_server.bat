@echo off
title AURA Live Backend Server - SIH Demo Runner
color 0A
cls
echo ===============================================================================
echo            A U R A   L I V E   B A C K E N D   S E R V E R
echo              Smart India Hackathon (SIH) Presentation Mode
echo ===============================================================================
echo.

cd /d "%~dp0backend"

if not exist "venv\Scripts\python.exe" (
    echo [ERROR] Python virtual environment not found in backend\venv!
    echo Please ensure backend\venv exists.
    pause
    exit /b 1
)

echo [1/3] Starting FastAPI Uvicorn Server on http://0.0.0.0:8000...
start "Aura Uvicorn Backend" cmd /k "color 0B && title Aura Backend Service && echo Starting Uvicorn... && venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

echo [2/3] Waiting 4 seconds for server initialization...
timeout /t 4 /nobreak >nul

echo [3/3] Starting Ngrok Public Cloud Tunnel on port 8000...
start "Aura Ngrok Tunnel" cmd /k "color 0D && title Aura Cloud Tunnel && echo Starting Ngrok Tunnel... && npx ngrok http 8000"

echo.
echo ===============================================================================
echo  [SUCCESS] Both Backend Server & Cloud Tunnel have been launched!
echo.
echo  Local API URL  : http://localhost:8000
echo  Public Tunnel  : https://staining-slashing-tinfoil.ngrok-free.dev
echo.
echo  Keep the opened command windows running during your presentation!
echo ===============================================================================
echo.
pause
