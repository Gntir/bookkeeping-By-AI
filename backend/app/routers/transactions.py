from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, require_ledger_member
from ..models import Transaction, User
from ..schemas import TransactionIn, TransactionOut, TransactionUpdate

router = APIRouter(prefix="/api/transactions", tags=["transactions"])


def to_out(db: Session, t: Transaction) -> TransactionOut:
    creator = db.get(User, t.created_by)
    out = TransactionOut.model_validate(t)
    out.creator_name = creator.nickname if creator else "未知"
    return out


def parse_month(month: str) -> tuple[date, date]:
    """'2026-09' -> (月初, 月末)"""
    try:
        year, mon = int(month[:4]), int(month[5:7])
        start = date(year, mon, 1)
        if mon == 12:
            end = date(year, 12, 31)
        else:
            end = date(year, mon + 1, 1) - timedelta(days=1)
        return start, end
    except (ValueError, IndexError):
        raise HTTPException(400, "月份格式错误，应为 YYYY-MM")


@router.get("", response_model=dict)
def list_transactions(
    ledger_id: int,
    month: Optional[str] = None,
    type: Optional[str] = Query(None, pattern="^(expense|income)$"),
    page: int = 1,
    size: int = 50,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, ledger_id, db)
    q = db.query(Transaction).filter(Transaction.ledger_id == ledger_id)
    if month:
        start, end = parse_month(month)
        q = q.filter(Transaction.date >= start, Transaction.date <= end)
    if type:
        q = q.filter(Transaction.type == type)
    total = q.count()
    rows = (
        q.order_by(Transaction.date.desc(), Transaction.id.desc())
        .offset((page - 1) * size)
        .limit(size)
        .all()
    )
    return {"total": total, "items": [to_out(db, t) for t in rows]}


@router.post("", response_model=TransactionOut)
def create_transaction(
    data: TransactionIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, data.ledger_id, db)
    if data.type not in ("expense", "income"):
        raise HTTPException(400, "type 必须是 expense 或 income")
    t = Transaction(
        ledger_id=data.ledger_id,
        created_by=user.id,
        category_id=data.category_id,
        category_name=data.category_name,
        type=data.type,
        amount=round(data.amount, 2),
        date=data.date,
        note=data.note or "",
        source=data.source if data.source in ("manual", "ai", "salary") else "manual",
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    return to_out(db, t)


@router.put("/{tx_id}", response_model=TransactionOut)
def update_transaction(
    tx_id: int,
    data: TransactionUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    t = db.get(Transaction, tx_id)
    if t is None:
        raise HTTPException(404, "记录不存在")
    member = require_ledger_member(user, t.ledger_id, db)
    # 普通成员只能改自己记的，owner 可以改所有
    if member.role != "owner" and t.created_by != user.id:
        raise HTTPException(403, "只能修改自己记的账")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(t, field, value)
    if t.amount is not None:
        t.amount = round(t.amount, 2)
    db.commit()
    db.refresh(t)
    return to_out(db, t)


@router.delete("/{tx_id}")
def delete_transaction(
    tx_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    t = db.get(Transaction, tx_id)
    if t is None:
        raise HTTPException(404, "记录不存在")
    member = require_ledger_member(user, t.ledger_id, db)
    if member.role != "owner" and t.created_by != user.id:
        raise HTTPException(403, "只能删除自己记的账")
    db.delete(t)
    db.commit()
    return {"ok": True}
