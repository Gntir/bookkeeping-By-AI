# -*- coding: utf-8 -*-
# 最终验证：完整记账场景下 enable_thinking=false 的速度与 tool_calls 正确性
import asyncio
import time
import os
import sys

import httpx

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
ENV_PATH = os.path.join(HERE, "..", ".env")

from app.ai_parser import TOOL_SCHEMA, build_system_prompt  # noqa: E402
from datetime import date  # noqa: E402


def load_env():
    cfg = {}
    with open(ENV_PATH, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg


async def call(client, cfg, label, model=None):
    model = model or cfg["AI_MODEL"]
    messages = [
        {"role": "system", "content": build_system_prompt(date.today(),
         ["餐饮", "交通", "购物", "娱乐", "医疗", "居住", "其他"], ["工资", "兼职", "理财", "红包", "其他"])},
        {"role": "user", "content": "今天午饭花了35"},
        {"role": "assistant", "content": "记好啦：餐饮支出35元"},
        {"role": "user", "content": "再来一笔打车20，还有闲鱼卖旧书收到45"},
    ]
    payload = {
        "model": model,
        "messages": messages,
        "tools": [TOOL_SCHEMA],
        "tool_choice": "auto",
        "temperature": 0.1,
        "enable_thinking": False,     # Qwen/vLLM 风格关思考
        "reasoning_effort": "none",   # OpenAI 风格关思考，双参数覆盖更多渠道
        "max_tokens": 500,
    }
    t0 = time.perf_counter()
    r = await client.post(
        f"{cfg['AI_BASE_URL']}/chat/completions",
        headers={"Authorization": f"Bearer {cfg['AIHUBMIX_API_KEY']}"},
        json=payload,
    )
    dt = time.perf_counter() - t0
    r.raise_for_status()
    if os.environ.get("RAW"):
        print(r.text[:800])
        return
    data = r.json()
    msg = data["choices"][0]["message"]
    calls = [c["function"]["arguments"] for c in (msg.get("tool_calls") or [])]
    rc = msg.get("reasoning_content") or ""
    rd = msg.get("reasoning_details") or []
    think = len(rc) + (len(str(rd)) if rd else 0)
    print(f"  [{label}] {dt:5.2f}s | 思考量={think} | tool_calls={len(calls)} | reply={(msg.get('content') or '')[:40]}")
    for a in calls:
        print(f"      -> {a}")


async def main():
    cfg = load_env()
    models = [cfg["AI_MODEL"], "glm-5-turbo", "glm-5.2-fast-preview"]
    async with httpx.AsyncClient(timeout=90) as client:
        for m in models:
            print(f"== {m} ==")
            for i in range(3):
                try:
                    await call(client, cfg, f"{m[:16]}#{i + 1}", model=m)
                except Exception as e:
                    print("  失败:", str(e)[:150])


if __name__ == "__main__":
    asyncio.run(main())
