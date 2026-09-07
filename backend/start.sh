#!/usr/bin/env bash
# 启动后端（后台常驻，日志写入 app.log）
cd "$(dirname "$0")"

# 端口：优先读 .env 里的 PORT，没有就用 7012
PORT=$(grep -E '^PORT=' .env 2>/dev/null | cut -d= -f2 | tr -d '\r')
PORT=${PORT:-7012}

if [ ! -d .venv ]; then
    echo "还没初始化，先运行：bash setup.sh"
    exit 1
fi

# 已在跑就先停掉
bash stop.sh 2>/dev/null || true

nohup .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT" > app.log 2>&1 &
echo $! > app.pid
sleep 2

# 用 python 做健康检查（不依赖 curl）
if .venv/bin/python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:$PORT/docs', timeout=3).status==200 else 1)" 2>/dev/null; then
    echo "启动成功"
    echo "  本机自检：   http://127.0.0.1:$PORT/docs"
    echo "  外网访问：   http://你的服务器IP:$PORT/docs"
    echo "  看运行日志： tail -f app.log   （Ctrl+C 退出查看）"
else
    echo "启动可能失败，最近日志："
    tail -30 app.log
fi
