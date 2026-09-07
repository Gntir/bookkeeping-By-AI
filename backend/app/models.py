from datetime import date as DateVal, datetime
from typing import Optional

from sqlalchemy import Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(128))
    nickname: Mapped[str] = mapped_column(String(50))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)

    memberships: Mapped[list["LedgerMember"]] = relationship(back_populates="user")


class Ledger(Base):
    """账本：单人记账 or 多人共享"""

    __tablename__ = "ledgers"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50))
    invite_code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)

    members: Mapped[list["LedgerMember"]] = relationship(back_populates="ledger")
    transactions: Mapped[list["Transaction"]] = relationship(back_populates="ledger")


class LedgerMember(Base):
    __tablename__ = "ledger_members"
    __table_args__ = (UniqueConstraint("ledger_id", "user_id", name="uq_member"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    ledger_id: Mapped[int] = mapped_column(ForeignKey("ledgers.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    role: Mapped[str] = mapped_column(String(10), default="member")  # owner / member
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)

    ledger: Mapped["Ledger"] = relationship(back_populates="members")
    user: Mapped["User"] = relationship(back_populates="memberships")


class Category(Base):
    """分类：预置分类 ledger_id 为空（全局），自定义分类绑定账本"""

    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    ledger_id: Mapped[Optional[int]] = mapped_column(ForeignKey("ledgers.id"), nullable=True)
    name: Mapped[str] = mapped_column(String(20))
    type: Mapped[str] = mapped_column(String(10))  # expense / income
    icon: Mapped[str] = mapped_column(String(10), default="🏷️")
    sort: Mapped[int] = mapped_column(Integer, default=0)


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(primary_key=True)
    ledger_id: Mapped[int] = mapped_column(ForeignKey("ledgers.id"), index=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    category_id: Mapped[Optional[int]] = mapped_column(ForeignKey("categories.id"), nullable=True)
    category_name: Mapped[str] = mapped_column(String(20))  # 冗余存名，防止分类被删
    type: Mapped[str] = mapped_column(String(10))  # expense / income
    amount: Mapped[float] = mapped_column(Float)
    date: Mapped[DateVal] = mapped_column(Date, index=True)
    note: Mapped[str] = mapped_column(String(200), default="")
    source: Mapped[str] = mapped_column(String(10), default="manual")  # manual / ai / salary
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)

    ledger: Mapped["Ledger"] = relationship(back_populates="transactions")


class SalaryRule(Base):
    """固定薪资规则：每月 pay_day 自动生成一条收入"""

    __tablename__ = "salary_rules"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    ledger_id: Mapped[int] = mapped_column(ForeignKey("ledgers.id"))
    name: Mapped[str] = mapped_column(String(50), default="工资")
    amount: Mapped[float] = mapped_column(Float)
    pay_day: Mapped[int] = mapped_column(Integer)  # 1-31
    active: Mapped[bool] = mapped_column(default=True)
    last_run: Mapped[Optional[str]] = mapped_column(String(7), nullable=True)  # 已生成的月份 YYYY-MM
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
