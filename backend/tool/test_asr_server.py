# -*- coding: utf-8 -*-
# 服务器端验证：Whisper 语音转写（与 voice.py 相同代码路径）；部署后跑一次确认 ASR 可用
import asyncio
import os
import sys
import time

os.chdir("/root/intresting_project/bookkeeping/backend")
sys.path.insert(0, "/root/intresting_project/bookkeeping/backend")

from app.ai_parser import _get_client
from app.config import get_settings

import importlib

importlib.import_module("app.routers.voice")
print("voice.py import OK")


async def main():
    s = get_settings()
    print("ASR_MODEL =", s.ASR_MODEL)
    data = open("tool/voice_test.wav", "rb").read()
    client = _get_client()
    ok = 0
    for i in range(2):
        t0 = time.perf_counter()
        resp = await client.post(
            f"{s.AI_BASE_URL}/audio/transcriptions",
            headers={"Authorization": f"Bearer {s.AIHUBMIX_API_KEY}"},
            files={"file": ("audio.wav", data, "audio/wav")},
            data={"model": s.ASR_MODEL, "language": "zh"},
        )
        dt = time.perf_counter() - t0
        resp.raise_for_status()
        text = (resp.json().get("text") or "").strip()
        ok += 1
        print(f"run{i+1}: {resp.status_code} {dt:.1f}s | {text}")
    print("RESULT:", "PASS" if ok == 2 else "FAIL")


asyncio.run(main())
