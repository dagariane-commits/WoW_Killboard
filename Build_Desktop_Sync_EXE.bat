@echo off
title Build WoWKillboardSync.exe
cd /d "%~dp0"
echo ===================================================
echo   Compiling WoWKillboardSync.exe with PyInstaller
echo ===================================================
echo.
pyinstaller --onefile --name WoWKillboardSync --clean sync/watcher.py
echo.
echo [DONE] Standalone binary compiled: dist\WoWKillboardSync.exe
pause
