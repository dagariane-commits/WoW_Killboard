@echo off
title WoW Killboard - Universal Sync Client
cd /d "%~dp0"
echo ===================================================
echo   WoW Killboard - Universal Sync Client
echo ===================================================
echo.
if exist "WoWKillboardSync.exe" (
    echo [*] Launching standalone binary WoWKillboardSync.exe...
    WoWKillboardSync.exe
) else (
    echo [*] Launching python sync/watcher.py...
    python sync/watcher.py
)
pause
