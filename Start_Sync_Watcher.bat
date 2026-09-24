@echo off
title WoW Killboard - SavedVariables Sync Watcher
cd /d "%~dp0"
echo ===================================================
echo   WoW Killboard - SavedVariables Sync Watcher
echo ===================================================
echo.
echo This watcher monitors your WoW SavedVariables file and automatically
echo syncs your PvP kills, bounties, and debt records to the web server.
echo.
set /p WOWPATH="Enter path to WoWKillboard.lua (or press Enter for local test file): "
if "%WOWPATH%"=="" set WOWPATH=WoWKillboard.lua

python sync/watcher.py --file "%WOWPATH%" --api "http://127.0.0.1:8080"
pause
