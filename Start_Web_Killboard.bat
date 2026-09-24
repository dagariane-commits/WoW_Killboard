@echo off
title WoW Killboard - Web Server
cd /d "%~dp0"
echo ===================================================
echo   WoW Killboard (zKillboard Platform)
echo   Starting Web Server at http://localhost:8080 ...
echo ===================================================
echo.
start http://localhost:8080
python web/server.py
pause
