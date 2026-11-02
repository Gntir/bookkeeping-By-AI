@echo off
REM LOCAL-ONLY release target config (gitignored, never commit real values).
REM Used by release_apk.cmd. Copy this file to deploy_target.cmd and fill in.
set "JZ_SERVER=root@YOUR_SERVER_IP"
set "JZ_REMOTE_DIR=/root/YOUR_PROJECT_DIR"
