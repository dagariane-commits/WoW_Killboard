@echo off
title Stop WoW Killboard Sync
echo [*] Terminating WoWKillboardSync background process...
taskkill /f /im WoWKillboardSync.exe >nul 2>&1
echo [OK] WoWKillboardSync has been stopped.
timeout /t 2 >nul
