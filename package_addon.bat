@echo off
title Package WoW Killboard Addon
cd /d "%~dp0"
echo ===================================================
echo   Packaging WoWKillboard Addon for Distribution
echo ===================================================
echo.
powershell -Command "Compress-Archive -Path 'Addon\WoWKillboard' -DestinationPath 'WoWKillboard-v1.0.5.zip' -Force; Copy-Item 'WoWKillboard-v1.0.5.zip' 'WoWKillboard-v1.0.4.zip' -Force; Copy-Item 'WoWKillboard-v1.0.5.zip' 'WoWKillboard-v1.0.3.zip' -Force; Copy-Item 'WoWKillboard-v1.0.5.zip' 'WoWKillboard-v1.0.2.zip' -Force; Copy-Item 'WoWKillboard-v1.0.5.zip' 'WoWKillboard-v1.0.1.zip' -Force; Copy-Item 'WoWKillboard-v1.0.5.zip' 'WoWKillboard-v1.0.0.zip' -Force; Copy-Item 'WoWKillboard-v1.0.5.zip' 'web\static\WoWKillboard-v1.0.5.zip' -Force"
echo.
echo [DONE] Addon packaged to: WoWKillboard-v1.0.5.zip (and mirrored to web\static\ and legacy aliases)
echo You can upload this .zip to CurseForge, Wago.io, or share it on Discord!
pause
