from datetime import date as DateVal
from typing import Literal, Optional

from pydantic import BaseModel, Field


# ---------- Auth ----------
class RegisterIn(BaseModel):
    phone: str = Field(min_length=5, max_length=20)
    password: str = Field(min_length=6, max_length=64)
    nickname: str = Field(min_length=1, max_length=50)


class LoginIn(BaseModel):
    phone: str
    password: str


class UserOut(BaseModel):
    id: int
    phone: str
    nickname: str

    class Config:
        from_attributes = True


class TokenOut(BaseModel):
    token: str
    user: UserOut


# ---------- Ledger ----------
class LedgerCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class LedgerOut(BaseModel):
    id: int
    name: str
    invite_code: str
    role: str
    member_count: int

    class Config:
        from_attributes = True


class JoinIn(BaseModel):
    invite_code: str


# ---------- Category ----------
class CategoryOut(BaseModel):
    id: int
    name: str
    type: str
    icon: str


# ---------- Transaction ----------
class TransactionIn(BaseModel):
    ledger_id: int
    type: str  # expense / income
    amount: float = Field(gt=0)
    category_id: Optional[int] = None
    category_name: str
    date: DateVal
    note: str = ""
    source: str = "manual"


class TransactionUpdate(BaseModel):
    type: Optional[str] = None
    amount: Optional[float] = Field(default=None, gt=0)
    category_id: Optional[int] = None
    category_name: Optional[str] = None
    date: Optional[DateVal] = None
    note: Optional[str] = None


class TransactionOut(BaseModel):
    id: int
    ledger_id: int
    created_by: int
    creator_name: str = ""
    category_id: Optional[int]
    category_name: str
    type: str
    amount: float
    date: DateVal
    note: str
    source: str

    class Config:
        from_attributes = True


# ---------- AI ----------
class ChatHistoryItem(BaseModel):
    """多轮对话历史（仅允许 user/assistant，防 system 注入）"""

    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=1000)


class AIParseIn(BaseModel):
    ledger_id: int
    text: str = Field(min_length=1, max_length=500)
    history: list[ChatHistoryItem] = Field(default_factory=list, max_length=20)


class DraftItem(BaseModel):
    """AI 解析出的待确认记录草稿"""

    type: str
    amount: float
    category_name: str
    date: DateVal
    note: str


class AIParseOut(BaseModel):
    reply: str  # AI 给用户的一句话回复
    drafts: list[DraftItem] = []


# ---------- Salary ----------
class SalaryRuleIn(BaseModel):
    ledger_id: int
    name: str = "工资"
    amount: float = Field(gt=0)
    pay_day: int = Field(ge=1, le=31)


class SalaryRuleOut(BaseModel):
    id: int
    ledger_id: int
    name: str
    amount: float
    pay_day: int
    active: bool
    last_run: Optional[str]

    class Config:
        from_attributes = True


# ---------- Stats ----------
class SummaryOut(BaseModel):
    month: str
    income: float
    expense: float
    balance: float


class CategoryStat(BaseModel):
    category_name: str
    icon: str
    amount: float
    count: int


class DailyStat(BaseModel):
    date: str
    expense: float
    income: float


class MemberStat(BaseModel):
    user_id: int
    nickname: str
    expense: float
    income: float


class MonthlyStat(BaseModel):
    month: str
    income: float
    expense: float


class ReportOut(BaseModel):
    month: str
    income: float
    expense: float
    balance: float
    top_expense: list[CategoryStat]
    top_income: list[CategoryStat]
    daily: list[DailyStat]
    members: list[MemberStat]
    max_expense: Optional[TransactionOut]
