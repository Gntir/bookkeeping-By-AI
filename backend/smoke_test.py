"""后端 API 冒烟测试：注册->登录->账本->记账->统计 全链路"""
import json
import urllib.request

BASE = "http://127.0.0.1:8000"


def call(method: str, path: str, body=None, token: str | None = None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body else None,
        headers={
            "Content-Type": "application/json",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw.decode(errors="replace")[:200]}


results = []


def check(name: str, cond: bool, detail=""):
    results.append((name, "PASS" if cond else "FAIL", detail))


import time

time.sleep(3)

# 1. health
s, d = call("GET", "/api/health")
check("health", s == 200 and d.get("ok"))

# 2. 注册
s, d = call("POST", "/api/auth/register", {"phone": "13800000001", "password": "test123456", "nickname": "小明"})
check("register", s == 200 and d.get("token"), str(d)[:120])
token = d.get("token", "")

# 3. 重复注册应失败
s, d = call("POST", "/api/auth/register", {"phone": "13800000001", "password": "test123456", "nickname": "小明"})
check("register-dup-blocked", s == 400)

# 4. 登录
s, d = call("POST", "/api/auth/login", {"phone": "13800000001", "password": "test123456"})
check("login", s == 200 and d.get("token"))
token = d.get("token", token)

# 5. me
s, d = call("GET", "/api/auth/me", token=token)
check("me", s == 200 and d.get("nickname") == "小明")

# 6. 我的账本（注册自带1个）
s, d = call("GET", "/api/ledgers", token=token)
check("ledgers-list", s == 200 and len(d) == 1 and d[0]["member_count"] == 1)
ledger_id = d[0]["id"] if s == 200 and d else 0
invite_code = d[0]["invite_code"] if s == 200 and d else ""

# 7. 分类
s, d = call("GET", "/api/categories?type=expense&ledger_id=%d" % ledger_id, token=token)
check("categories-expense", s == 200 and len(d) >= 10, f"got {len(d)}")
s, d = call("GET", "/api/categories?type=income&ledger_id=%d" % ledger_id, token=token)
check("categories-income", s == 200 and len(d) >= 5)

# 8. 手动记一笔支出
s, d = call(
    "POST",
    "/api/transactions",
    {
        "ledger_id": ledger_id,
        "type": "expense",
        "amount": 35.5,
        "category_name": "餐饮",
        "date": "2026-09-04",
        "note": "午饭",
        "source": "manual",
    },
    token=token,
)
check("tx-create-expense", s == 200 and d.get("id"), str(d)[:120])
tx_id = d.get("id")

# 9. 记一笔收入
s, d = call(
    "POST",
    "/api/transactions",
    {
        "ledger_id": ledger_id,
        "type": "income",
        "amount": 800,
        "category_name": "二手闲置",
        "date": "2026-09-04",
        "note": "卖旧手机",
        "source": "manual",
    },
    token=token,
)
check("tx-create-income", s == 200 and d.get("id"))

# 10. 列表
s, d = call("GET", f"/api/transactions?ledger_id={ledger_id}&month=2026-09", token=token)
check("tx-list", s == 200 and d.get("total") == 2)

# 11. 修改
s, d = call("PUT", f"/api/transactions/{tx_id}", {"amount": 36}, token=token)
check("tx-update", s == 200 and d.get("amount") == 36)

# 12. 统计-汇总
s, d = call("GET", f"/api/stats/summary?ledger_id={ledger_id}&month=2026-09", token=token)
check("stats-summary", s == 200 and d["expense"] == 36 and d["income"] == 800, str(d)[:120])

# 13. 统计-分类
s, d = call("GET", f"/api/stats/categories?ledger_id={ledger_id}&month=2026-09&type=expense", token=token)
check("stats-categories", s == 200 and len(d) == 1 and d[0]["category_name"] == "餐饮")

# 14. 统计-每日
s, d = call("GET", f"/api/stats/daily?ledger_id={ledger_id}&month=2026-09", token=token)
check("stats-daily", s == 200 and len(d) == 1)

# 15. 统计-月报
s, d = call("GET", f"/api/stats/report?ledger_id={ledger_id}&month=2026-09", token=token)
check("stats-report", s == 200 and d["income"] == 800 and d["max_expense"]["amount"] == 36, str(d)[:150])

# 16. 薪资规则
s, d = call("POST", "/api/salary-rules", {"ledger_id": ledger_id, "name": "工资", "amount": 12000, "pay_day": 10}, token=token)
check("salary-create", s == 200 and d.get("id"), str(d)[:120])

# 17. 第二个用户注册+通过邀请码加入账本
s, d = call("POST", "/api/auth/register", {"phone": "13800000002", "password": "test123456", "nickname": "小红"})
token2 = d.get("token", "")
s, d = call("POST", "/api/ledgers/join", {"invite_code": invite_code}, token=token2)
check("join-ledger", s == 200 and d.get("id") == ledger_id, str(d)[:120])

# 18. 成员列表
s, d = call("GET", f"/api/ledgers/{ledger_id}/members", token=token)
check("members", s == 200 and len(d) == 2)

# 19. 成员记账 + 成员统计
s, d = call(
    "POST",
    "/api/transactions",
    {"ledger_id": ledger_id, "type": "expense", "amount": 50, "category_name": "交通", "date": "2026-09-04", "note": "打车"},
    token=token2,
)
check("member-tx", s == 200)
s, d = call("GET", f"/api/stats/members?ledger_id={ledger_id}&month=2026-09", token=token)
check("stats-members", s == 200 and len(d) == 2)

# 20. 非成员访问应被拒
s, d = call("POST", "/api/auth/register", {"phone": "13800000003", "password": "test123456", "nickname": "路人"})
token3 = d.get("token", "")
s, d = call("GET", f"/api/transactions?ledger_id={ledger_id}", token=token3)
check("non-member-blocked", s == 403)

# 21. 未登录应被拒
s, d = call("GET", f"/api/transactions?ledger_id={ledger_id}")
check("no-auth-blocked", s == 401)

# 22. AI 解析（无 key 时应有友好提示而非崩溃；本机连不上 aihubmix 时跳过）
try:
    s, d = call("POST", "/api/ai/parse", {"ledger_id": ledger_id, "text": "今天午饭花了35"}, token=token)
    check("ai-parse-graceful", s == 200 and "reply" in d, str(d)[:150])
except Exception:
    results.append(("ai-parse-graceful", "SKIP", "本机无法连接 aihubmix，跳过（部署到服务器后再验）"))

# 23. 删除记录
s, d = call("DELETE", f"/api/transactions/{tx_id}", token=token)
check("tx-delete", s == 200)
s, d = call("GET", f"/api/transactions?ledger_id={ledger_id}&month=2026-09", token=token)
check("tx-deleted", s == 200 and d["total"] == 2)

print()
fails = 0
skips = 0
for name, status, detail in results:
    mark = "OK " if status == "PASS" else ("---" if status == "SKIP" else "!!!")
    print(f"[{mark}] {name} {('- ' + detail) if (status != 'PASS' and detail) else ''}")
    if status == "FAIL":
        fails += 1
    if status == "SKIP":
        skips += 1
print()
print(f"TOTAL: {len(results) - fails - skips}/{len(results) - skips} passed" + (f"（{skips} 项因网络跳过）" if skips else ""))
