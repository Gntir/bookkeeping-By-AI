@echo off
REM One-click release: build APK then upload APK + release.json to the server.
REM 1) Edit release_note.txt (update description) at project root first.
REM 2) Run this script; input the server password when scp asks.
REM 3) Users get the update popup on next app launch. No server restart needed.
call "%~dp0build_apk.cmd"
if errorlevel 1 (echo Build FAILED, abort release. & exit /b 1)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_release.ps1"
scp mobile\build\app\outputs\flutter-apk\app-release.apk root@154.8.178.27:/root/intresting_project/bookkeeping/backend/release/app-release.apk
scp release.json root@154.8.178.27:/root/intresting_project/bookkeeping/backend/release/release.json
if errorlevel 1 (echo Upload FAILED. & exit /b 1)
echo Release uploaded. Users will see the update prompt on next app launch.