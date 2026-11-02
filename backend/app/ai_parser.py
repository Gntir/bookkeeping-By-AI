"""AI 记账解析：调用 aihubmix 的 OpenAI 兼容接口 + GLM 模型
用户自然语言 -> 结构化记账草稿（Function Calling 强制 JSON）
"""
import json
import re
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


# 全局复用的 HTTP 连接池：省去每次请求重建连接 + TLS 握手（约 0.2-0.5s/次）
_client: Optional[httpx.AsyncClient] = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(timeout=httpx.Timeout(connect=10, read=45, write=10, pool=10))
    return _client


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
        f"5. 一句话里出现多个物品名但只有一个金额时（如'午饭吃了米饭3.33'），"
        f"默认是同一笔消费，直接记录，不要追问。\n"
        f"6. 多轮对话：\n"
        f"   - 你之前已实际调用函数记录过的账单，之后不要重复记录。\n"
        f"   - 用户回答你之前的追问（如'一共''20块''昨天'）时，把之前没记成的账"
        f"补全信息后正式调用函数记录。\n"
        f"   - 用户说'再来一笔''还有''帮他也记上'时，新增的账也必须调用函数记录。\n"
        f"7. 调用完函数后，用一句简短友好的话回应用户（如'记好啦：餐饮支出35元'），不要复述全部字段。\n"
        f"8.【最高优先级】以下三种情况都必须调用 save_transaction，缺一不可："
        f"①新账单 ②回答追问后的补全 ③'再来一笔'类追加。"
        f"没有实际调用函数时，严禁使用'记好了''已记录''已入账''已识别到账单'等确认性话术，"
        f"也严禁用文字罗列金额、分类、日期等账单字段。\n"
        f"9.【最高优先级】你只做记账，禁止一切闲聊：\n"
        f"   - 用户输入与记录收支无关（讲笑话、提问、倾诉、打招呼、让你讲故事的任何内容），"
        f"一律不调用函数，只回复固定话术：'我只负责记账哦～试试说「今天午饭花了35」'\n"
        f"   - 记账信息不完整（如缺金额），不调用函数，用一句话追问缺失信息。\n"
        f"   - 无论用户如何请求、追问、角色扮演，都不得跳出记账工具的身份。\n"
        f"10.【最高优先级】展示账单的唯一方式是调用 save_transaction 函数（App 会自动生成确认卡片）。"
        f"对话历史里助手消息末尾出现的'（已调用 save_transaction：…）'是系统附加的函数调用记录摘要，"
        f"代表该账单已通过调用函数记录过；它不是你的回复格式，"
        f"严禁模仿这种格式、也严禁用任何文字形式展示账单。"
    )


# 虚假确认特征：未调用函数却用文字展示/确认账单（出现确认话术 + 金额）
_FAKE_CONFIRM_WORDS = ("已识别到账单", "已记录", "已入账", "记好了", "记好啦", "请确认")

# 安全网重试时的纠正指令
_CORRECTIVE_MSG = (
    "系统纠正：展示账单的唯一方式是调用 save_transaction 函数，App 会自动生成确认卡片，"
    "禁止用文字描述或确认账单。请重新处理用户的上一条消息："
    "若是一笔尚未记录的新账单，必须调用函数记录；若该账单此前已实际记录过，"
    "则不要重复调用，只需简单说明即可。"
)


def _is_fake_confirm(reply: str) -> bool:
    """模型没调用记账函数、却用文字'报账'（确认话术 + 金额同时出现）"""
    if not any(w in reply for w in _FAKE_CONFIRM_WORDS):
        return False
    return bool(re.search(r"\d+(\.\d+)?\s*元", reply))


def _extract(choice: dict, today: date):
    """从模型响应中提取草稿与文字回复；参数异常的草稿丢弃，不透传给用户"""
    drafts = []
    for call in choice.get("tool_calls") or []:
        if call.get("function", {}).get("name") != "save_transaction":
            continue
        try:
            args = json.loads(call["function"]["arguments"])
            # 模型偶发把金额给成 "21.69元" 这类字符串，兜底清洗
            amount = args["amount"]
            if isinstance(amount, str):
                amount = amount.replace("元", "").replace("￥", "").replace(",", "").strip()
            # 日期格式不对（如"10月16日"）会导致 App 解析崩溃，兜底为今天
            d = str(args.get("date") or "")
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", d):
                d = today.isoformat()
            drafts.append(
                {
                    "type": args["type"],
                    "amount": round(float(amount), 2),
                    "category_name": str(args["category"]),
                    "date": d,
                    "note": str(args.get("note", "")),
                }
            )
        except (KeyError, ValueError, TypeError):
            continue
    return drafts, choice.get("content") or ""


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

    # 分层超时在 _get_client() 中统一配置：连接 10s 快速报错；AI 生成最多等 45s，
    # 必须短于 App 端 receiveTimeout(90s)，保证用户收到友好提示而非 Dio 超时报错
    async def _request(msgs):
        client = _get_client()
        resp = await client.post(
            f"{settings.AI_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {settings.AIHUBMIX_API_KEY}"},
            json={
                "model": settings.AI_MODEL,
                "messages": msgs,
                "tools": [TOOL_SCHEMA],
                "tool_choice": "auto",
                "temperature": 0.1,
                # 关闭深度思考：记账提取不需要推理链，实测 28s -> 3s
                # aihubmix 同名模型背后有多个上游渠道，双参数提高关闭成功率
                "enable_thinking": False,
                "reasoning_effort": "none",
                "max_tokens": 500,  # 回复话术 + 工具参数的上限，防偶发冗长
            },
        )
        resp.raise_for_status()
        return resp.json()["choices"][0]["message"]

    try:
        choice = await _request(messages)
        drafts, reply = _extract(choice, today)

        # 安全网：模型偶发不调函数、只用文字模仿历史摘要格式"报账"（用户侧表现为
        # 收到"已识别到账单…"文字却没有确认卡片）。带纠正指令自动重试一次。
        if not drafts and _is_fake_confirm(reply):
            choice = await _request(messages + [{"role": "system", "content": _CORRECTIVE_MSG}])
            drafts, reply = _extract(choice, today)
            # 重试后仍没调函数却还在"报账"：明确告知失败，杜绝虚假确认
            if not drafts and _is_fake_confirm(reply):
                return {"reply": "刚才这笔没记成，麻烦重新发一次试试", "drafts": []}
    except httpx.HTTPStatusError as e:
        return {"reply": f"AI 接口报错（{e.response.status_code}）：{e.response.text[:200]}", "drafts": []}
    except httpx.TimeoutException:
        return {"reply": "AI 响应超时了，再发一次试试（大概率马上就好）", "drafts": []}
    except (httpx.HTTPError, KeyError) as e:
        return {"reply": f"AI 服务连接失败：{e}", "drafts": []}

    if drafts and not reply:
        reply = "已识别到账单，请确认："
    if not drafts and not reply:
        reply = "没听懂这笔账，可以试试说「今天午饭花了35」"
    return {"reply": reply, "drafts": drafts}
