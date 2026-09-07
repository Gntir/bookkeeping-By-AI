from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Ledger, LedgerMember, User
from ..schemas import LoginIn, RegisterIn, TokenOut, UserOut
from ..security import create_token, hash_password, verify_password

router = APIRouter(prefix="/api/auth", tags=["auth"])


def create_default_ledger(db: Session, user: User) -> None:
    """注册时自动创建默认个人账本"""
    import random
    import string

    code = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
    ledger = Ledger(name=f"{user.nickname}的账本", invite_code=code)
    db.add(ledger)
    db.flush()
    db.add(LedgerMember(ledger_id=ledger.id, user_id=user.id, role="owner"))
    db.commit()


@router.post("/register", response_model=TokenOut)
def register(data: RegisterIn, db: Session = Depends(get_db)):
    if db.query(User).filter_by(phone=data.phone).first():
        raise HTTPException(400, "该手机号已注册")
    user = User(
        phone=data.phone,
        password_hash=hash_password(data.password),
        nickname=data.nickname,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    create_default_ledger(db, user)
    return TokenOut(token=create_token(user.id), user=UserOut.model_validate(user))


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    user = db.query(User).filter_by(phone=data.phone).first()
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(400, "手机号或密码错误")
    return TokenOut(token=create_token(user.id), user=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user
