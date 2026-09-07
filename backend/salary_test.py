"""验证薪资自动记账：创建今天发薪的规则 -> 手动触发 job -> 检查是否生成收入记录"""
import sys

sys.path.insert(0, ".")

from app.database import SessionLocal
from app.models import SalaryRule, Transaction
from app.scheduler import run_salary_job
from datetime import date

db = SessionLocal()
ledger_id = 1
user_id = 1

# 清理可能的旧规则/记录
db.query(SalaryRule).filter(SalaryRule.ledger_id == ledger_id).delete()
db.query(Transaction).filter(Transaction.source == "salary").delete()
db.commit()

today = date.today()
rule = SalaryRule(
    user_id=user_id,
    ledger_id=ledger_id,
    name="工资",
    amount=12000,
    pay_day=today.day,  # 今天发薪
)
db.add(rule)
db.commit()
rule_id = rule.id

print(f"规则已创建: pay_day={rule.pay_day} (今天{today.day}号)")

# 触发 job
run_salary_job()

db.expire_all()
rule = db.get(SalaryRule, rule_id)
txs = db.query(Transaction).filter(Transaction.source == "salary").all()

print(f"rule.last_run = {rule.last_run} (期望 {today.strftime('%Y-%m')})")
print(f"生成的薪资记录数 = {len(txs)} (期望 1)")
for t in txs:
    print(f"  -> {t.date} {t.type} {t.amount} {t.note}")

ok = rule.last_run == today.strftime("%Y-%m") and len(txs) == 1
print("RESULT:", "PASS" if ok else "FAIL")

# 再跑一次验证幂等（不重复生成）
run_salary_job()
db.expire_all()
txs = db.query(Transaction).filter(Transaction.source == "salary").all()
print(f"二次触发后记录数 = {len(txs)} (期望仍为 1)")
print("IDEMPOTENT:", "PASS" if len(txs) == 1 else "FAIL")

db.close()
