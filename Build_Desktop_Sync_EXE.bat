@echo off
title Build WoWKillboardSync.exe
cd /d "%~dp0"
echo ===================================================
echo   Compiling WoWKillboardSync.exe with PyInstaller
echo ===================================================
echo.
pyinstaller --onefile --noconsole --name WoWKillboardSync --clean sync/watcher.py
echo.
echo [*] Copying compiled binary to root and web/static...
copy /y dist\WoWKillboardSync.exe WoWKillboardSync.exe >nul
copy /y dist\WoWKillboardSync.exe web\static\WoWKillboardSync.exe >nul
echo [DONE] Standalone Desktop Companion compiled and deployed:
echo        - dist\WoWKillboardSync.exe
echo        - WoWKillboardSync.exe
echo        - web\static\WoWKillboardSync.exe
pause
