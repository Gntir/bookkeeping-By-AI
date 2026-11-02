@echo off
REM One-click release: build APK then upload APK + release.json to the server.
REM 1) Edit release_note.txt (update description) at project root first.
REM 2) Copy deploy_target.template.cmd to deploy_target.cmd and fill in your server.
REM 3) Run this script; input the server password when scp asks.
REM 4) Users get the update popup on next app launch. No server restart needed.
if not exist "%~dp0deploy_target.cmd" (
    echo Missing deploy_target.cmd. Copy deploy_target.template.cmd to deploy_target.cmd and fill it in.
    exit /b 1
)
call "%~dp0deploy_target.cmd"
call "%~dp0build_apk.cmd"
if errorlevel 1 (echo Build FAILED, abort release. & exit /b 1)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_release.ps1"
scp mobile\build\app\outputs\flutter-apk\app-release.apk %JZ_SERVER%:%JZ_REMOTE_DIR%/backend/release/app-release.apk
scp release.json %JZ_SERVER%:%JZ_REMOTE_DIR%/backend/release/release.json
if errorlevel 1 (echo Upload FAILED. & exit /b 1)
echo Release uploaded. Users will see the update prompt on next app launch.