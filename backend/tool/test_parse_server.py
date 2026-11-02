# -*- coding: utf-8 -*-
# 服务器端验证：AI 文字报账 bug 修复效果（用完即删）
import asyncio
import os
import sys

os.chdir("/root/intresting_project/bookkeeping/backend")  # 读 .env 需要
sys.path.insert(0, "/root/intresting_project/bookkeeping/backend")

from app.ai_parser import parse_text

HIST = [
    {"role": "user", "content": "昨天打车回家28.5"},
    {"role": "assistant", "content": "记好啦：交通支出28.5元\n（已调用 save_transaction：支出28.5元 交通（打车）2026-11-01）"},
]
EXP = ["餐饮", "交通", "购物", "娱乐", "医疗", "居住", "其他"]
INC = ["工资", "兼职", "理财", "红包", "其他"]


async def main():
    ok = 0
    for i in range(2):
        r = await parse_text("10月16号充电，21.69元", EXP, INC, history=HIST)
        has_draft = len(r["drafts"]) == 1 and r["drafts"][0]["amount"] == 21.69
        ok += 1 if has_draft else 0
        print(f"run{i+1}: drafts={r['drafts']} reply={r['reply'][:40]}")
    print("RESULT:", "PASS" if ok == 2 else "FAIL")


asyncio.run(main())
