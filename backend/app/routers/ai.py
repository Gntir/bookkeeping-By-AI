from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..ai_parser import parse_text
from ..database import get_db
from ..deps import get_current_user, require_ledger_member
from ..models import Category, User
from ..schemas import AIParseIn, AIParseOut

router = APIRouter(prefix="/api/ai", tags=["ai"])


@router.post("/parse", response_model=AIParseOut)
async def ai_parse(
    data: AIParseIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """自然语言 -> 记账草稿（不入库，前端确认后调 /api/transactions 落库）"""
    require_ledger_member(user, data.ledger_id, db)

    expense_cats = [
        c.name
        for c in db.query(Category)
        .filter(
            Category.type == "expense",
            (Category.ledger_id.is_(None)) | (Category.ledger_id == data.ledger_id),
        )
        .all()
    ]
    income_cats = [
        c.name
        for c in db.query(Category)
        .filter(
            Category.type == "income",
            (Category.ledger_id.is_(None)) | (Category.ledger_id == data.ledger_id),
        )
        .all()
    ]

    result = await parse_text(
        data.text,
        expense_cats,
        income_cats,
        history=[h.model_dump() for h in data.history],
    )
    return AIParseOut(**result)
