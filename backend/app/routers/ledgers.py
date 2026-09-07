import random
import string

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, get_ledger_or_404, require_ledger_member
from ..models import Ledger, LedgerMember, User
from ..schemas import JoinIn, LedgerCreate, LedgerOut, UserOut

router = APIRouter(prefix="/api/ledgers", tags=["ledgers"])


def gen_invite_code(db: Session) -> str:
    while True:
        code = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if not db.query(Ledger).filter_by(invite_code=code).first():
            return code


@router.get("", response_model=list[LedgerOut])
def my_ledgers(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = (
        db.query(Ledger, LedgerMember.role)
        .join(LedgerMember, LedgerMember.ledger_id == Ledger.id)
        .filter(LedgerMember.user_id == user.id)
        .all()
    )
    result = []
    for ledger, role in rows:
        count = (
            db.query(LedgerMember).filter_by(ledger_id=ledger.id).count()
        )
        result.append(
            LedgerOut(
                id=ledger.id,
                name=ledger.name,
                invite_code=ledger.invite_code,
                role=role,
                member_count=count,
            )
        )
    return result


@router.post("", response_model=LedgerOut)
def create_ledger(
    data: LedgerCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ledger = Ledger(name=data.name, invite_code=gen_invite_code(db))
    db.add(ledger)
    db.flush()
    db.add(LedgerMember(ledger_id=ledger.id, user_id=user.id, role="owner"))
    db.commit()
    db.refresh(ledger)
    return LedgerOut(
        id=ledger.id,
        name=ledger.name,
        invite_code=ledger.invite_code,
        role="owner",
        member_count=1,
    )


@router.post("/join", response_model=LedgerOut)
def join_ledger(
    data: JoinIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    ledger = db.query(Ledger).filter_by(invite_code=data.invite_code.strip().upper()).first()
    if ledger is None:
        raise HTTPException(404, "邀请码无效")
    exists = (
        db.query(LedgerMember).filter_by(ledger_id=ledger.id, user_id=user.id).first()
    )
    if exists:
        raise HTTPException(400, "你已在该账本中")
    db.add(LedgerMember(ledger_id=ledger.id, user_id=user.id, role="member"))
    db.commit()
    count = db.query(LedgerMember).filter_by(ledger_id=ledger.id).count()
    return LedgerOut(
        id=ledger.id,
        name=ledger.name,
        invite_code=ledger.invite_code,
        role="member",
        member_count=count,
    )


@router.get("/{ledger_id}/members", response_model=list[UserOut])
def members(
    ledger_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    get_ledger_or_404(ledger_id, db)
    require_ledger_member(user, ledger_id, db)
    rows = (
        db.query(User)
        .join(LedgerMember, LedgerMember.user_id == User.id)
        .filter(LedgerMember.ledger_id == ledger_id)
        .all()
    )
    return rows
