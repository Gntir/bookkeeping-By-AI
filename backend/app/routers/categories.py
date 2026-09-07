from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Category, User
from ..schemas import CategoryOut

router = APIRouter(prefix="/api/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
def list_categories(
    type: str = Query(..., pattern="^(expense|income)$"),
    ledger_id: Optional[int] = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """预置分类 + 该账本的自定义分类"""
    q = db.query(Category).filter(Category.type == type)
    if ledger_id:
        q = q.filter((Category.ledger_id.is_(None)) | (Category.ledger_id == ledger_id))
    else:
        q = q.filter(Category.ledger_id.is_(None))
    return q.order_by(Category.sort).all()
