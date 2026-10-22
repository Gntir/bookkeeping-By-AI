# -*- coding: utf-8 -*-
# 实测：aihubmix 的 gpt-4o-audio 模型能否转写中文记账语音（含数字难点）
import base64
import time
import json

import httpx

cfg = {}
with open(".env", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            cfg[k] = v

audio_b64 = base64.b64encode(open("tool/voice_test.wav", "rb").read()).decode()
print(f"音频大小: {len(audio_b64) // 1024} KB (base64)")

import sys

MODEL = sys.argv[1] if len(sys.argv) > 1 else "gpt-4o-audio-preview"
payload = {
    "model": MODEL,
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "把这段语音逐字转写成文字，只输出转写结果，不要解释。",
                },
                {
                    "type": "input_audio",
                    "input_audio": {"data": audio_b64, "format": "wav"},
                },
            ],
        }
    ],
    "max_tokens": 200,
    "reasoning_effort": "none",  # 关闭 gemini 思考，纯转写不需要
}
t0 = time.perf_counter()
r = httpx.post(
    cfg["AI_BASE_URL"] + "/chat/completions",
    headers={"Authorization": f"Bearer {cfg['AIHUBMIX_API_KEY']}"},
    json=payload,
    timeout=90,
)
dt = time.perf_counter() - t0
print(f"HTTP {r.status_code} | {dt:.1f}s")
if r.status_code == 200:
    data = r.json()
    print("转写结果:", data["choices"][0]["message"]["content"])
    print("usage:", json.dumps(data.get("usage", {})))
else:
    print(r.text[:300])
