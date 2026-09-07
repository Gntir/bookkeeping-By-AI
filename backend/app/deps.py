from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from .database import get_db
from .models import Ledger, LedgerMember, User
from .security import decode_token


def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "未登录")
    user_id = decode_token(auth.removeprefix("Bearer ").strip())
    if user_id is None:
        raise HTTPException(401, "登录已过期")
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(401, "用户不存在")
    return user


def require_ledger_member(
    user: User, ledger_id: int, db: Session
) -> LedgerMember:
    """校验用户是否是账本成员，返回成员关系"""
    member = (
        db.query(LedgerMember)
        .filter_by(ledger_id=ledger_id, user_id=user.id)
        .first()
    )
    if member is None:
        raise HTTPException(403, "你不是该账本成员")
    return member


def get_ledger_or_404(ledger_id: int, db: Session) -> Ledger:
    ledger = db.get(Ledger, ledger_id)
    if ledger is None:
        raise HTTPException(404, "账本不存在")
    return ledger
