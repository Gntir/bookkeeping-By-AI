"""薪资定时任务：每月发薪日自动生成收入记录
- 每天 09:00 检查一次
- 应用启动时补跑一次（防停机漏记）
- pay_day > 当月天数时，取当月最后一天（如31号规则在2月缩到28/29号）
- last_run 记录已生成的月份，保证每月只生成一次
"""
import calendar
import logging
from datetime import date, datetime, timedelta

from sqlalchemy import select

from .database import SessionLocal
from .models import Category, SalaryRule, Transaction

logger = logging.getLogger("salary")


def run_salary_job() -> None:
    today = date.today()
    current_month = today.strftime("%Y-%m")
    last_day = calendar.monthrange(today.year, today.month)[1]
    effective_pay_day = min(last_day, 31)  # 当月实际存在的最大"发薪日"

    db = SessionLocal()
    try:
        rules = db.execute(select(SalaryRule).where(SalaryRule.active.is_(True))).scalars().all()
        for rule in rules:
            if rule.last_run == current_month:
                continue  # 本月已生成
            if today.day < min(rule.pay_day, effective_pay_day):
                continue  # 还没到发薪日

            cat = db.execute(
                select(Category).where(Category.name == "工资", Category.type == "income")
            ).scalar_one_or_none()
            tx = Transaction(
                ledger_id=rule.ledger_id,
                created_by=rule.user_id,
                category_id=cat.id if cat else None,
                category_name=cat.name if cat else "工资",
                type="income",
                amount=rule.amount,
                date=today,
                note=f"{rule.name}（{current_month}）",
                source="salary",
            )
            db.add(tx)
            rule.last_run = current_month
            logger.info("薪资已记账: rule=%s amount=%s", rule.id, rule.amount)
        db.commit()
    finally:
        db.close()


def start_scheduler():
    from apscheduler.schedulers.background import BackgroundScheduler

    scheduler = BackgroundScheduler()
    scheduler.add_job(run_salary_job, "cron", hour=9, minute=0, id="salary_daily")
    # 启动后延迟几秒补跑一次，防止停机期间漏记
    scheduler.add_job(
        run_salary_job,
        "date",
        run_date=datetime.now() + timedelta(seconds=5),
        id="salary_boot",
    )
    scheduler.start()
    return scheduler
