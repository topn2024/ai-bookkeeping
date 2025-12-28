"""Account schemas."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class AccountCreate(BaseModel):
    """Schema for creating an account."""
    name: str = Field(..., max_length=100)
    account_type: int = Field(..., ge=1, le=5)  # 1: cash, 2: debit, 3: credit, 4: alipay, 5: wechat
    icon: Optional[str] = Field(None, max_length=50)
    balance: Decimal = Field(default=Decimal("0"))
    credit_limit: Optional[Decimal] = None
    bill_day: Optional[int] = Field(None, ge=1, le=31)
    repay_day: Optional[int] = Field(None, ge=1, le=31)
    is_default: bool = False


class AccountUpdate(BaseModel):
    """Schema for updating an account."""
    name: Optional[str] = Field(None, max_length=100)
    icon: Optional[str] = Field(None, max_length=50)
    balance: Optional[Decimal] = None
    credit_limit: Optional[Decimal] = None
    bill_day: Optional[int] = Field(None, ge=1, le=31)
    repay_day: Optional[int] = Field(None, ge=1, le=31)
    is_default: Optional[bool] = None


class AccountResponse(BaseModel):
    """Schema for account response."""
    id: UUID
    user_id: UUID
    name: str
    account_type: int
    icon: Optional[str] = None
    balance: Decimal
    credit_limit: Optional[Decimal] = None
    bill_day: Optional[int] = None
    repay_day: Optional[int] = None
    is_default: bool
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
