#!/usr/bin/env bash
# 停止后端
cd "$(dirname "$0")"

if [ -f app.pid ]; then
    kill "$(cat app.pid)" 2>/dev/null && echo "已停止" || echo "进程已不在运行"
    rm -f app.pid
else
    pkill -f "uvicorn app.main:app" 2>/dev/null && echo "已停止" || echo "本来就没在运行"
fi
