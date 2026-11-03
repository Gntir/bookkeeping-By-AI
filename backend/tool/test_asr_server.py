# -*- coding: utf-8 -*-
# 服务器端验证：gemini-2.5-pro 语音转写（用完即删）
import base64
import os
import sys
import time

os.chdir("/root/intresting_project/bookkeeping/backend")
sys.path.insert(0, "/root/intresting_project/bookkeeping/backend")

import httpx

from app.config import get_settings

s = get_settings()
print("ASR_MODEL =", s.ASR_MODEL)
wav = open("tool/voice_test.wav", "rb").read()
payload = {
    "model": s.ASR_MODEL,
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "把这段语音逐字转写成文字，只输出转写结果，不要解释。"},
                {"type": "input_audio", "input_audio": {"data": base64.b64encode(wav).decode(), "format": "wav"}},
            ],
        }
    ],
    "max_tokens": 300,
    "reasoning_effort": "none",
}
ok = 0
for i in range(2):
    t0 = time.perf_counter()
    r = httpx.post(
        f"{s.AI_BASE_URL}/chat/completions",
        headers={"Authorization": f"Bearer {s.AIHUBMIX_API_KEY}"},
        json=payload,
        timeout=45,
    )
    dt = time.perf_counter() - t0
    if r.status_code == 200:
        text = (r.json()["choices"][0]["message"].get("content") or "").strip()
        ok += 1
        print(f"run{i+1}: 200 {dt:.1f}s | {text}")
    else:
        print(f"run{i+1}: {r.status_code} {dt:.1f}s | {r.text[:150]}")
print("RESULT:", "PASS" if ok == 2 else "FAIL")
