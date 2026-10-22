# -*- coding: utf-8 -*-
# AI 记账质量专项测试：单轮 + 多轮（追问补全/防重复/拒闲聊），换模型或改提示词后跑
import asyncio
import os
import sys
import time

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


async def run(client, cfg, user_text, expect, history=None):
    messages = [
        {"role": "system", "content": build_system_prompt(date.today(),
         ["餐饮", "交通", "购物", "娱乐", "医疗", "居住", "其他"], ["工资", "兼职", "理财", "红包", "其他"])},
        *(history or []),
        {"role": "user", "content": user_text},
    ]
    payload = {
        "model": cfg["AI_MODEL"], "messages": messages, "tools": [TOOL_SCHEMA],
        "tool_choice": "auto", "temperature": 0.1,
        "enable_thinking": False, "reasoning_effort": "none", "max_tokens": 500,
    }
    t0 = time.perf_counter()
    r = await client.post(f"{cfg['AI_BASE_URL']}/chat/completions",
                          headers={"Authorization": f"Bearer {cfg['AIHUBMIX_API_KEY']}"}, json=payload)
    dt = time.perf_counter() - t0
    r.raise_for_status()
    msg = r.json()["choices"][0]["message"]
    calls = [c["function"]["arguments"] for c in (msg.get("tool_calls") or [])]
    reply = (msg.get("content") or "")[:60]
    print(f"[{expect}] {dt:4.1f}s | tool_calls={len(calls)}")
    if history:
        print(f"  (多轮) 历史{len(history)}条 + 当前: {user_text}")
    else:
        print(f"  用户: {user_text}")
    print(f"  回复: {reply}")
    for c in calls:
        print(f"  账单: {c}")


async def main():
    cfg = load_env()
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    async with httpx.AsyncClient(timeout=60) as client:
        # --- 本次 bug 复现：追问后用户补充回答，必须真正入账 ---
        await run(client, cfg, "一共", "追问后补全→记1笔3.33", history=[
            {"role": "user", "content": "午饭支出米饭3.33"},
            {"role": "assistant", "content": "请问是午饭和米饭两笔，还是一共一笔3.33呢？"},
        ])
        # --- 单句模糊表述：多物品+单金额，默认一笔不追问 ---
        await run(client, cfg, "午饭支出米饭3.33", "单句模糊→直接记1笔")
        # --- 回归：多轮不重复 ---
        await run(client, cfg, "再来一笔打车20", "多轮追加→只记打车1笔", history=[
            {"role": "user", "content": "今天午饭花了35"},
            {"role": "assistant", "content": "记好啦：餐饮支出35元"},
        ])
        # --- 回归：缺金额追问 ---
        await run(client, cfg, "中午吃饭花了", "缺金额→追问0笔")
        # --- 回归：闲聊拒绝 ---
        await run(client, cfg, "给我讲个笑话", "闲聊→拒绝0笔")
        # --- 回归：日期换算 ---
        await run(client, cfg, "昨天打车回家28.5", f"日期={yesterday} 1笔")


if __name__ == "__main__":
    asyncio.run(main())
