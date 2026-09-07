from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, require_ledger_member
from ..models import Category, LedgerMember, Transaction, User
from ..routers.transactions import parse_month, to_out
from ..schemas import (
    CategoryStat,
    DailyStat,
    MemberStat,
    MonthlyStat,
    ReportOut,
    SummaryOut,
)

router = APIRouter(prefix="/api/stats", tags=["stats"])


def _month_query(db: Session, ledger_id: int, month: str):
    start, end = parse_month(month)
    return (
        db.query(Transaction)
        .filter(
            Transaction.ledger_id == ledger_id,
            Transaction.date >= start,
            Transaction.date <= end,
        )
    )


@router.get("/summary", response_model=SummaryOut)
def summary(
    ledger_id: int,
    month: str = Query(default_factory=lambda: date.today().strftime("%Y-%m")),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, ledger_id, db)
    q = _month_query(db, ledger_id, month)
    income = q.filter(Transaction.type == "income").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0.0)
    ).scalar()
    expense = q.filter(Transaction.type == "expense").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0.0)
    ).scalar()
    return SummaryOut(
        month=month,
        income=round(income, 2),
        expense=round(expense, 2),
        balance=round(income - expense, 2),
    )


@router.get("/categories", response_model=list[CategoryStat])
def by_category(
    ledger_id: int,
    month: str = Query(default_factory=lambda: date.today().strftime("%Y-%m")),
    type: str = Query("expense", pattern="^(expense|income)$"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, ledger_id, db)
    rows = (
        _month_query(db, ledger_id, month)
        .filter(Transaction.type == type)
        .with_entities(
            Transaction.category_name,
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("cnt"),
        )
        .group_by(Transaction.category_name)
        .order_by(func.sum(Transaction.amount).desc())
        .all()
    )
    icon_map = {
        c.name: c.icon
        for c in db.query(Category).filter(Category.type == type).all()
    }
    return [
        CategoryStat(
            category_name=r.category_name,
            icon=icon_map.get(r.category_name, "🏷️"),
            amount=round(r.total, 2),
            count=r.cnt,
        )
        for r in rows
    ]


@router.get("/daily", response_model=list[DailyStat])
def daily(
    ledger_id: int,
    month: str = Query(default_factory=lambda: date.today().strftime("%Y-%m")),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, ledger_id, db)
    start, end = parse_month(month)
    rows = (
        _month_query(db, ledger_id, month)
        .with_entities(
            Transaction.date,
            Transaction.type,
            func.sum(Transaction.amount).label("total"),
        )
        .group_by(Transaction.date, Transaction.type)
        .all()
    )
    by_date: dict[str, DailyStat] = {}
    for r in rows:
        key = r.date.isoformat()
        item = by_date.setdefault(key, DailyStat(date=key, expense=0.0, income=0.0))
        if r.type == "expense":
            item.expense = round(r.total, 2)
        else:
            item.income = round(r.total, 2)
    return sorted(by_date.values(), key=lambda x: x.date)


@router.get("/members", response_model=list[MemberStat])
def by_member(
    ledger_id: int,
    month: str = Query(default_factory=lambda: date.today().strftime("%Y-%m")),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, ledger_id, db)
    rows = (
        _month_query(db, ledger_id, month)
        .with_entities(
            Transaction.created_by,
            Transaction.type,
            func.sum(Transaction.amount).label("total"),
        )
        .group_by(Transaction.created_by, Transaction.type)
        .all()
    )
    name_map = {
        u.id: u.nickname
        for u in db.query(User)
        .join(LedgerMember, LedgerMember.user_id == User.id)
        .filter(LedgerMember.ledger_id == ledger_id)
        .all()
    }
    members: dict[int, MemberStat] = {}
    for r in rows:
        item = members.setdefault(
            r.created_by,
            MemberStat(
                user_id=r.created_by,
                nickname=name_map.get(r.created_by, f"用户{r.created_by}"),
                expense=0.0,
                income=0.0,
            ),
        )
        if r.type == "expense":
            item.expense = round(r.total, 2)
        else:
            item.income = round(r.total, 2)
    return list(members.values())


@router.get("/monthly", response_model=list[MonthlyStat])
def monthly(
    ledger_id: int,
    year: int = Query(default_factory=lambda: date.today().year),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, ledger_id, db)
    rows = (
        db.query(Transaction)
        .filter(
            Transaction.ledger_id == ledger_id,
            Transaction.date >= date(year, 1, 1),
            Transaction.date <= date(year, 12, 31),
        )
        .with_entities(
            func.strftime("%Y-%m", Transaction.date).label("m"),
            Transaction.type,
            func.sum(Transaction.amount).label("total"),
        )
        .group_by("m", Transaction.type)
        .all()
    )
    by_month = {f"{m:02d}": MonthlyStat(month=f"{m:02d}", income=0.0, expense=0.0) for m in range(1, 13)}
    for r in rows:
        mon = r.m[5:7]  # '2026-09' -> '09'
        if r.type == "income":
            by_month[mon].income = round(r.total, 2)
        else:
            by_month[mon].expense = round(r.total, 2)
    return list(by_month.values())


@router.get("/report", response_model=ReportOut)
def report(
    ledger_id: int,
    month: str = Query(default_factory=lambda: date.today().strftime("%Y-%m")),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """月报：一次拉全所有聚合数据"""
    require_ledger_member(user, ledger_id, db)
    s = summary(ledger_id=ledger_id, month=month, user=user, db=db)
    top_expense = by_category(ledger_id=ledger_id, month=month, type="expense", user=user, db=db)
    top_income = by_category(ledger_id=ledger_id, month=month, type="income", user=user, db=db)
    daily_data = daily(ledger_id=ledger_id, month=month, user=user, db=db)
    member_data = by_member(ledger_id=ledger_id, month=month, user=user, db=db)

    max_tx = (
        _month_query(db, ledger_id, month)
        .filter(Transaction.type == "expense")
        .order_by(Transaction.amount.desc())
        .first()
    )
    return ReportOut(
        month=month,
        income=s.income,
        expense=s.expense,
        balance=s.balance,
        top_expense=top_expense,
        top_income=top_income,
        daily=daily_data,
        members=member_data,
        max_expense=to_out(db, max_tx) if max_tx else None,
    )
