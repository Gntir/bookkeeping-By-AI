# -*- coding: utf-8 -*-
# glm-5.2-fast-preview 换模型前的质量专项：拒闲聊 / 日期换算 / 缺信息追问 / 速度
import asyncio
import os
import sys

import httpx

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

from app.ai_parser import TOOL_SCHEMA, build_system_prompt  # noqa: E402
from datetime import date, timedelta  # noqa: E402

def load_env():
    cfg = {}
    with open(os.path.join(HERE, "..", ".env"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg


MODEL = None  # 运行时取 .env 的 AI_MODEL


async def run(client, cfg, user_text, expect):
    messages = [
        {"role": "system", "content": build_system_prompt(date.today(),
         ["餐饮", "交通", "购物", "娱乐", "医疗", "居住", "其他"], ["工资", "兼职", "理财", "红包", "其他"])},
        {"role": "user", "content": user_text},
    ]
    payload = {
        "model": cfg["AI_MODEL"], "messages": messages, "tools": [TOOL_SCHEMA],
        "tool_choice": "auto", "temperature": 0.1,
        "enable_thinking": False, "reasoning_effort": "none", "max_tokens": 500,
    }
    import time
    t0 = time.perf_counter()
    r = await client.post(f"{cfg['AI_BASE_URL']}/chat/completions",
                          headers={"Authorization": f"Bearer {cfg['AIHUBMIX_API_KEY']}"}, json=payload)
    dt = time.perf_counter() - t0
    r.raise_for_status()
    msg = r.json()["choices"][0]["message"]
    calls = [c["function"]["arguments"] for c in (msg.get("tool_calls") or [])]
    reply = (msg.get("content") or "")[:60]
    print(f"[{expect}] {dt:4.1f}s")
    print(f"  用户: {user_text}")
    print(f"  回复: {reply}")
    for c in calls:
        print(f"  账单: {c}")


async def main():
    cfg = load_env()
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    async with httpx.AsyncClient(timeout=60) as client:
        await run(client, cfg, "我不舒服，给我讲个笑话", "拒绝闲聊")
        await run(client, cfg, "昨天打车回家28.5", f"日期={yesterday}")
        await run(client, cfg, "中午吃饭花了", "追问金额")
        await run(client, cfg, "这个月发了工资12000，交房租3000", "两笔+收支混合")


if __name__ == "__main__":
    asyncio.run(main())
