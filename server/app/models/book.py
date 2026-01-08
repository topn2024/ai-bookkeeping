"""Book model."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey, Text, Numeric
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class Book(Base):
    """Book (ledger) model.

    Book types:
    - 0: personal (个人账本)
    - 1: family (家庭账本)
    - 2: business (商业账本)
    - 3: couple (情侣账本)
    - 4: group (群组账本/AA制)
    - 5: project (专项账本)
    """

    __tablename__ = "books"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    icon: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    cover_image: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    book_type: Mapped[int] = mapped_column(Integer, default=0)  # 0-5 as defined above
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    currency: Mapped[str] = mapped_column(String(10), default='CNY')
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, onupdate=beijing_now_naive)

    # Settings as JSON
    settings: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True, default=dict)
    # settings schema: {
    #   "auto_sync_enabled": bool,
    #   "notify_on_new_transaction": bool,
    #   "notify_on_budget_alert": bool,
    #   "default_visibility": str,  # "private", "all_members", "admins_only"
    #   "allow_member_invite": bool,
    #   "monthly_budget_limit": float,
    #   "require_approval_for_large": bool,
    #   "large_expense_threshold": float
    # }

    # Relationships
    user = relationship("User", back_populates="books")
    transactions = relationship("Transaction", back_populates="book", lazy="dynamic")
    members = relationship("BookMember", back_populates="book", lazy="dynamic", cascade="all, delete-orphan")
    invitations = relationship("BookInvitation", back_populates="book", lazy="dynamic", cascade="all, delete-orphan")
    family_budgets = relationship("FamilyBudget", back_populates="book", lazy="dynamic", cascade="all, delete-orphan")
    saving_goals = relationship("FamilySavingGoal", back_populates="book", lazy="dynamic", cascade="all, delete-orphan")

    @property
    def is_shared(self) -> bool:
        """Check if this is a shared book."""
        return self.book_type != 0


class BookMember(Base):
    """Book member model for collaboration.

    Member roles:
    - 0: viewer (查看者 - 仅查看)
    - 1: member (成员 - 记账、查看、编辑自己的)
    - 2: admin (管理员 - 管理成员、编辑设置)
    - 3: owner (所有者 - 全部权限)
    """

    __tablename__ = "book_members"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    role: Mapped[int] = mapped_column(Integer, default=1)  # 0: viewer, 1: member, 2: admin, 3: owner
    nickname: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)  # Nickname in this book
    invited_by: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)

    # Member settings as JSON
    settings: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True, default=dict)
    # settings schema: {
    #   "receive_notifications": bool,
    #   "show_in_ranking": bool,
    #   "default_visibility": str
    # }

    # Relationships
    book = relationship("Book", back_populates="members")
    user = relationship("User", foreign_keys=[user_id])
    inviter = relationship("User", foreign_keys=[invited_by])


class BookInvitation(Base):
    """Book invitation model for inviting members.

    Invitation status:
    - 0: active
    - 1: expired
    - 2: revoked
    - 3: accepted
    """

    __tablename__ = "book_invitations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    inviter_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    role: Mapped[int] = mapped_column(Integer, default=1)  # Role to assign when joining
    code: Mapped[str] = mapped_column(String(20), nullable=False, unique=True, index=True)  # Invite code
    voice_code: Mapped[Optional[str]] = mapped_column(String(6), nullable=True, index=True)  # 6-digit voice code
    status: Mapped[int] = mapped_column(Integer, default=0)  # 0: active, 1: expired, 2: revoked, 3: accepted
    max_uses: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # NULL for unlimited
    used_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    # Relationships
    book = relationship("Book", back_populates="invitations")
    inviter = relationship("User")


class FamilyBudget(Base):
    """Family budget model for shared budget management.

    Budget strategies:
    - 0: unified (统一预算 - 共享总额)
    - 1: per_member (成员配额 - 各自独立)
    - 2: per_category (分类负责)
    - 3: hybrid (混合模式)
    """

    __tablename__ = "family_budgets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    period: Mapped[str] = mapped_column(String(7), nullable=False)  # "YYYY-MM" format
    strategy: Mapped[int] = mapped_column(Integer, default=0)  # 0: unified, 1: per_member, etc.
    total_budget: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, onupdate=beijing_now_naive)

    # Budget rules as JSON
    rules: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True, default=dict)
    # rules schema: {
    #   "allow_overspend": bool,
    #   "overspend_limit": float,
    #   "require_approval_for_large": bool,
    #   "large_expense_threshold": float,
    #   "notify_on_threshold": bool,
    #   "threshold_percentages": [50, 80, 100]
    # }

    # Relationships
    book = relationship("Book", back_populates="family_budgets")
    member_budgets = relationship("MemberBudget", back_populates="family_budget", lazy="dynamic", cascade="all, delete-orphan")


class MemberBudget(Base):
    """Member budget allocation within a family budget."""

    __tablename__ = "member_budgets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    family_budget_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("family_budgets.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    allocated: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False, default=0)  # Allocated amount
    spent: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False, default=0)  # Spent amount
    category_spent: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True, default=dict)  # {category_id: amount}
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, onupdate=beijing_now_naive)

    # Relationships
    family_budget = relationship("FamilyBudget", back_populates="member_budgets")
    user = relationship("User")


class FamilySavingGoal(Base):
    """Family saving goal for shared financial goals.

    Goal status:
    - 0: active
    - 1: completed
    - 2: cancelled
    """

    __tablename__ = "family_saving_goals"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    icon: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    target_amount: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False)
    current_amount: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False, default=0)
    deadline: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    status: Mapped[int] = mapped_column(Integer, default=0)  # 0: active, 1: completed, 2: cancelled
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Relationships
    book = relationship("Book", back_populates="saving_goals")
    creator = relationship("User")
    contributions = relationship("GoalContribution", back_populates="goal", lazy="dynamic", cascade="all, delete-orphan")


class GoalContribution(Base):
    """Contribution to a family saving goal."""

    __tablename__ = "goal_contributions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    goal_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("family_saving_goals.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False)
    note: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)

    # Relationships
    goal = relationship("FamilySavingGoal", back_populates="contributions")
    user = relationship("User")


class TransactionSplit(Base):
    """Transaction split for AA sharing.

    Split types:
    - 0: equal (平均分摊)
    - 1: percentage (按比例)
    - 2: exact (精确金额)
    - 3: shares (按份数)

    Split status:
    - 0: pending (待确认)
    - 1: confirmed (已确认)
    - 2: settling (结算中)
    - 3: settled (已结算)
    """

    __tablename__ = "transaction_splits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transaction_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("transactions.id", ondelete="CASCADE"), nullable=False)
    split_type: Mapped[int] = mapped_column(Integer, default=0)  # 0: equal, 1: percentage, 2: exact, 3: shares
    status: Mapped[int] = mapped_column(Integer, default=0)  # 0: pending, 1: confirmed, 2: settling, 3: settled
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    settled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Relationships
    transaction = relationship("Transaction", back_populates="split_info")
    participants = relationship("SplitParticipant", back_populates="split", lazy="dynamic", cascade="all, delete-orphan")


class SplitParticipant(Base):
    """Participant in a transaction split."""

    __tablename__ = "split_participants"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    split_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("transaction_splits.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(15, 2), nullable=False)  # Amount to pay
    percentage: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)  # Percentage if applicable
    shares: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # Shares if applicable
    is_payer: Mapped[bool] = mapped_column(Boolean, default=False)  # Is this the original payer
    is_settled: Mapped[bool] = mapped_column(Boolean, default=False)
    settled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Relationships
    split = relationship("TransactionSplit", back_populates="participants")
    user = relationship("User")
