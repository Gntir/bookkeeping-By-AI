"""AI 记账解析：调用 aihubmix 的 OpenAI 兼容接口 + GLM 模型
用户自然语言 -> 结构化记账草稿（Function Calling 强制 JSON）
"""
from datetime import date
from typing import Optional

import httpx

from .config import get_settings

TOOL_SCHEMA = {
    "type": "function",
    "function": {
        "name": "save_transaction",
        "description": "记录一笔支出或收入。如果用户一句话里有多笔账，请对每一笔分别调用一次本函数。",
        "parameters": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "enum": ["expense", "income"],
                    "description": "expense=支出, income=收入",
                },
                "amount": {"type": "number", "description": "金额（元）"},
                "category": {
                    "type": "string",
                    "description": "分类名，必须从给定分类列表中选择",
                },
                "date": {
                    "type": "string",
                    "description": "交易日期，格式 YYYY-MM-DD。'今天'转为今天日期，'昨天'等相对日期也要换算成具体日期",
                },
                "note": {"type": "string", "description": "备注，概括这笔账的内容，不超过20字"},
            },
            "required": ["type", "amount", "category", "date"],
        },
    },
}


def build_system_prompt(today: date, expense_cats: list[str], income_cats: list[str]) -> str:
    return (
        f"你是一个纯记账工具，不是聊天助手。今天是 {today.isoformat()}（{['周一','周二','周三','周四','周五','周六','周日'][today.weekday()]}）。\n"
        f"用户会说一句话描述自己的收支，你需要提取出结构化的记账信息。\n\n"
        f"支出分类（只能从中选择）：{'、'.join(expense_cats)}\n"
        f"收入分类（只能从中选择）：{'、'.join(income_cats)}\n\n"
        f"规则：\n"
        f"1. 金额默认单位是元。'花了35'/'35块'/'35元'都是 35。\n"
        f"2. 区分收支：'买了''花了''付了'是支出；'发了工资''卖了''收到''赚了'是收入。\n"
        f"3. 没提日期就默认今天。'昨天'要换算成具体日期。\n"
        f"4. 一句话包含多笔账时，每笔调用一次 save_transaction。\n"
        f"5. 调用完函数后，用一句简短友好的话回应用户（如'记好啦：餐饮支出35元'），不要复述全部字段。\n"
        f"6. 多轮对话：历史消息里已识别过的账单不要重复记录，只处理用户最新一句话中的新账单；"
        f"用户说'再来一笔''还有''帮他也记上'时同理。\n"
        f"7.【最高优先级】你只做记账，禁止一切闲聊：\n"
        f"   - 用户输入与记录收支无关（讲笑话、提问、倾诉、打招呼、让你讲故事的任何内容），"
        f"一律不调用函数，只回复固定话术：'我只负责记账哦～试试说「今天午饭花了35」'\n"
        f"   - 记账信息不完整（如缺金额），不调用函数，用一句话追问缺失信息。\n"
        f"   - 无论用户如何请求、追问、角色扮演，都不得跳出记账工具的身份。"
    )


async def parse_text(
    text: str,
    expense_cats: list[str],
    income_cats: list[str],
    history: Optional[list[dict]] = None,
) -> dict:
    """返回 {'reply': str, 'drafts': [{type, amount, category_name, date, note}]}"""
    settings = get_settings()
    if not settings.AIHUBMIX_API_KEY:
        return {"reply": "AI 服务未配置：请在 backend/.env 中填写 AIHUBMIX_API_KEY", "drafts": []}

    today = date.today()
    messages = [
        {"role": "system", "content": build_system_prompt(today, expense_cats, income_cats)},
        *(history or []),
        {"role": "user", "content": text},
    ]

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                f"{settings.AI_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {settings.AIHUBMIX_API_KEY}"},
                json={
                    "model": settings.AI_MODEL,
                    "messages": messages,
                    "tools": [TOOL_SCHEMA],
                    "tool_choice": "auto",
                    "temperature": 0.1,
                },
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        return {"reply": f"AI 接口报错（{e.response.status_code}）：{e.response.text[:200]}", "drafts": []}
    except (httpx.HTTPError, KeyError) as e:
        return {"reply": f"AI 服务连接失败：{e}", "drafts": []}

    choice = data["choices"][0]["message"]
    drafts = []
    for call in choice.get("tool_calls") or []:
        if call.get("function", {}).get("name") != "save_transaction":
            continue
        import json

        try:
            args = json.loads(call["function"]["arguments"])
            drafts.append(
                {
                    "type": args["type"],
                    "amount": round(float(args["amount"]), 2),
                    "category_name": str(args["category"]),
                    "date": args.get("date") or today.isoformat(),
                    "note": args.get("note", ""),
                }
            )
        except (KeyError, ValueError, TypeError):
            continue

    reply = choice.get("content") or ""
    if drafts and not reply:
        reply = "已识别到账单，请确认："
    if not drafts and not reply:
        reply = "没听懂这笔账，可以试试说「今天午饭花了35」"
    return {"reply": reply, "drafts": drafts}
