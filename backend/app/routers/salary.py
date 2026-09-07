from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, require_ledger_member
from ..models import SalaryRule, User
from ..schemas import SalaryRuleIn, SalaryRuleOut

router = APIRouter(prefix="/api/salary-rules", tags=["salary"])


@router.get("", response_model=list[SalaryRuleOut])
def my_rules(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(SalaryRule).filter(SalaryRule.user_id == user.id).all()


@router.post("", response_model=SalaryRuleOut)
def create_rule(
    data: SalaryRuleIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_ledger_member(user, data.ledger_id, db)
    # demo：每人每账本一条薪资规则
    exists = (
        db.query(SalaryRule)
        .filter_by(user_id=user.id, ledger_id=data.ledger_id)
        .first()
    )
    if exists:
        raise HTTPException(400, "该账本已有薪资规则，请直接修改")
    rule = SalaryRule(
        user_id=user.id,
        ledger_id=data.ledger_id,
        name=data.name,
        amount=data.amount,
        pay_day=data.pay_day,
    )
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


@router.put("/{rule_id}", response_model=SalaryRuleOut)
def update_rule(
    rule_id: int,
    data: SalaryRuleIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rule = db.get(SalaryRule, rule_id)
    if rule is None or rule.user_id != user.id:
        raise HTTPException(404, "规则不存在")
    require_ledger_member(user, data.ledger_id, db)
    rule.ledger_id = data.ledger_id
    rule.name = data.name
    rule.amount = data.amount
    rule.pay_day = data.pay_day
    db.commit()
    db.refresh(rule)
    return rule


@router.delete("/{rule_id}")
def delete_rule(
    rule_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rule = db.get(SalaryRule, rule_id)
    if rule is None or rule.user_id != user.id:
        raise HTTPException(404, "规则不存在")
    db.delete(rule)
    db.commit()
    return {"ok": True}
