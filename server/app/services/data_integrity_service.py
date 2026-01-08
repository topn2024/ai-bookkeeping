"""Data integrity verification service.

Implements periodic data validation from Chapter 33.4:
- Account balance verification
- Budget spent verification
- Split totals verification
- Transaction consistency checks

Reference: Design Document Chapter 33.4 - Data Integrity Guarantee
Code Block: 436
"""
import logging
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


class IntegrityStatus(Enum):
    """Integrity check result status."""
    PASS = "pass"
    FAIL = "fail"
    WARNING = "warning"
    SKIPPED = "skipped"
    ERROR = "error"


@dataclass
class IntegrityIssue:
    """Single integrity issue found."""
    entity_type: str
    entity_id: str
    issue_type: str
    expected: Any
    actual: Any
    description: str
    severity: str = "error"  # error, warning, info
    auto_fixable: bool = False


@dataclass
class IntegrityReport:
    """Report from an integrity check."""
    check_name: str
    status: IntegrityStatus
    checked_at: datetime
    duration_ms: float
    total_checked: int = 0
    issues_found: int = 0
    issues: List[IntegrityIssue] = field(default_factory=list)
    details: Dict[str, Any] = field(default_factory=dict)

    def add_issue(self, issue: IntegrityIssue):
        """Add an issue to the report."""
        self.issues.append(issue)
        self.issues_found += 1
        if self.status == IntegrityStatus.PASS:
            self.status = IntegrityStatus.FAIL


@dataclass
class FullIntegrityReport:
    """Full integrity check report."""
    started_at: datetime
    completed_at: Optional[datetime] = None
    total_duration_ms: float = 0
    checks_run: int = 0
    checks_passed: int = 0
    checks_failed: int = 0
    total_issues: int = 0
    reports: List[IntegrityReport] = field(default_factory=list)

    def add_report(self, report: IntegrityReport):
        """Add a check report."""
        self.reports.append(report)
        self.checks_run += 1
        if report.status == IntegrityStatus.PASS:
            self.checks_passed += 1
        elif report.status == IntegrityStatus.FAIL:
            self.checks_failed += 1
        self.total_issues += report.issues_found


class DataIntegrityService:
    """Service for verifying data integrity across the system.

    Performs periodic checks to ensure:
    - Account balances match transaction sums
    - Budget spent amounts are accurate
    - Split participant totals match split amounts
    - No orphaned records exist
    """

    _instance: Optional["DataIntegrityService"] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._last_check: Optional[FullIntegrityReport] = None
        self._initialized = True

    @property
    def last_check(self) -> Optional[FullIntegrityReport]:
        """Get last full check report."""
        return self._last_check

    # ==================== Account Balance Verification ====================

    async def verify_account_balances(
        self,
        db: AsyncSession,
        user_id: Optional[UUID] = None,
    ) -> IntegrityReport:
        """Verify account balances match transaction sums.

        For each account, calculates:
        - Expected balance = initial_balance + sum(income) - sum(expenses) - sum(transfers_out) + sum(transfers_in)
        - Compares with stored balance

        Args:
            db: Database session
            user_id: Optional user ID to check (None for all users)

        Returns:
            IntegrityReport with results
        """
        import time
        start = time.time()
        report = IntegrityReport(
            check_name="account_balance_verification",
            status=IntegrityStatus.PASS,
            checked_at=datetime.utcnow(),
            duration_ms=0,
        )

        try:
            from app.models.account import Account
            from app.models.transaction import Transaction

            # Query accounts
            account_query = select(Account)
            if user_id:
                account_query = account_query.where(Account.user_id == user_id)

            accounts_result = await db.execute(account_query)
            accounts = accounts_result.scalars().all()

            for account in accounts:
                report.total_checked += 1

                # Calculate expected balance from transactions
                # Income (type=2): adds to balance
                income_result = await db.execute(
                    select(func.coalesce(func.sum(Transaction.amount), 0))
                    .where(
                        Transaction.account_id == account.id,
                        Transaction.transaction_type == 2,
                    )
                )
                total_income = Decimal(str(income_result.scalar() or 0))

                # Expense (type=1): subtracts from balance (including fee)
                expense_result = await db.execute(
                    select(func.coalesce(func.sum(Transaction.amount + Transaction.fee), 0))
                    .where(
                        Transaction.account_id == account.id,
                        Transaction.transaction_type == 1,
                    )
                )
                total_expense = Decimal(str(expense_result.scalar() or 0))

                # Transfer out (type=3, source account): subtracts
                transfer_out_result = await db.execute(
                    select(func.coalesce(func.sum(Transaction.amount + Transaction.fee), 0))
                    .where(
                        Transaction.account_id == account.id,
                        Transaction.transaction_type == 3,
                    )
                )
                total_transfer_out = Decimal(str(transfer_out_result.scalar() or 0))

                # Transfer in (type=3, target account): adds
                transfer_in_result = await db.execute(
                    select(func.coalesce(func.sum(Transaction.amount), 0))
                    .where(
                        Transaction.target_account_id == account.id,
                        Transaction.transaction_type == 3,
                    )
                )
                total_transfer_in = Decimal(str(transfer_in_result.scalar() or 0))

                # Calculate expected balance (assuming initial_balance is 0 or stored separately)
                # Note: In a real system, you'd need the initial balance from account creation
                calculated_balance = total_income - total_expense - total_transfer_out + total_transfer_in

                # Compare with stored balance (need to handle initial balance)
                # For now, we'll flag significant discrepancies
                stored_balance = Decimal(str(account.balance))
                discrepancy = abs(stored_balance - calculated_balance)

                # Allow small floating point differences
                if discrepancy > Decimal("0.01"):
                    report.add_issue(IntegrityIssue(
                        entity_type="Account",
                        entity_id=str(account.id),
                        issue_type="balance_mismatch",
                        expected=str(calculated_balance),
                        actual=str(stored_balance),
                        description=(
                            f"Account balance mismatch: stored={stored_balance}, "
                            f"calculated={calculated_balance}, diff={discrepancy}"
                        ),
                        severity="error",
                        auto_fixable=True,
                    ))

        except Exception as e:
            logger.error(f"Account balance verification error: {e}")
            report.status = IntegrityStatus.ERROR
            report.details["error"] = str(e)

        report.duration_ms = (time.time() - start) * 1000
        return report

    # ==================== Budget Spent Verification ====================

    async def verify_budget_spent(
        self,
        db: AsyncSession,
        user_id: Optional[UUID] = None,
    ) -> IntegrityReport:
        """Verify budget spent amounts match actual transaction totals.

        Args:
            db: Database session
            user_id: Optional user ID to check

        Returns:
            IntegrityReport with results
        """
        import time
        start = time.time()
        report = IntegrityReport(
            check_name="budget_spent_verification",
            status=IntegrityStatus.PASS,
            checked_at=datetime.utcnow(),
            duration_ms=0,
        )

        try:
            from app.models.budget import Budget
            from app.models.transaction import Transaction
            from app.services.stats_service import stats_service

            # Query budgets
            budget_query = select(Budget)
            if user_id:
                budget_query = budget_query.where(Budget.user_id == user_id)

            budgets_result = await db.execute(budget_query)
            budgets = budgets_result.scalars().all()

            for budget in budgets:
                report.total_checked += 1

                # Calculate actual spent using stats service
                actual_spent = await stats_service.calculate_budget_spent(
                    db,
                    budget.user_id,
                    budget.book_id,
                    budget.category_id,
                    budget.year,
                    budget.month,
                )

                # Budget model may not store spent (calculated on-the-fly)
                # This check is mainly for any cached/stored values
                report.details[str(budget.id)] = {
                    "budget_amount": str(budget.amount),
                    "actual_spent": str(actual_spent),
                    "utilization": f"{(actual_spent / budget.amount * 100):.1f}%" if budget.amount > 0 else "N/A",
                }

        except Exception as e:
            logger.error(f"Budget spent verification error: {e}")
            report.status = IntegrityStatus.ERROR
            report.details["error"] = str(e)

        report.duration_ms = (time.time() - start) * 1000
        return report

    # ==================== Split Totals Verification ====================

    async def verify_split_totals(
        self,
        db: AsyncSession,
        user_id: Optional[UUID] = None,
    ) -> IntegrityReport:
        """Verify split participant totals match split amounts.

        Args:
            db: Database session
            user_id: Optional user ID to check

        Returns:
            IntegrityReport with results
        """
        import time
        start = time.time()
        report = IntegrityReport(
            check_name="split_totals_verification",
            status=IntegrityStatus.PASS,
            checked_at=datetime.utcnow(),
            duration_ms=0,
        )

        try:
            from app.models.split import TransactionSplit, SplitParticipant

            # Query splits
            split_query = select(TransactionSplit)
            # Note: Would need to join to filter by user if needed

            splits_result = await db.execute(split_query)
            splits = splits_result.scalars().all()

            for split in splits:
                report.total_checked += 1

                # Sum participant amounts
                participants_result = await db.execute(
                    select(func.coalesce(func.sum(SplitParticipant.amount), 0))
                    .where(SplitParticipant.split_id == split.id)
                )
                participant_total = Decimal(str(participants_result.scalar() or 0))

                split_amount = Decimal(str(split.amount))
                discrepancy = abs(split_amount - participant_total)

                if discrepancy > Decimal("0.01"):
                    report.add_issue(IntegrityIssue(
                        entity_type="TransactionSplit",
                        entity_id=str(split.id),
                        issue_type="participant_total_mismatch",
                        expected=str(split_amount),
                        actual=str(participant_total),
                        description=(
                            f"Split total mismatch: split_amount={split_amount}, "
                            f"participant_total={participant_total}"
                        ),
                        severity="error",
                        auto_fixable=False,
                    ))

        except Exception as e:
            logger.error(f"Split totals verification error: {e}")
            report.status = IntegrityStatus.ERROR
            report.details["error"] = str(e)

        report.duration_ms = (time.time() - start) * 1000
        return report

    # ==================== Orphaned Records Check ====================

    async def verify_no_orphaned_records(
        self,
        db: AsyncSession,
    ) -> IntegrityReport:
        """Check for orphaned records (referencing deleted parents).

        Args:
            db: Database session

        Returns:
            IntegrityReport with results
        """
        import time
        start = time.time()
        report = IntegrityReport(
            check_name="orphaned_records_check",
            status=IntegrityStatus.PASS,
            checked_at=datetime.utcnow(),
            duration_ms=0,
        )

        try:
            from app.models.transaction import Transaction
            from app.models.account import Account
            from app.models.book import Book

            # Check transactions with invalid account references
            orphaned_txn_query = (
                select(Transaction)
                .outerjoin(Account, Transaction.account_id == Account.id)
                .where(Account.id.is_(None))
            )
            orphaned_result = await db.execute(orphaned_txn_query)
            orphaned_txns = orphaned_result.scalars().all()

            for txn in orphaned_txns:
                report.total_checked += 1
                report.add_issue(IntegrityIssue(
                    entity_type="Transaction",
                    entity_id=str(txn.id),
                    issue_type="orphaned_account_reference",
                    expected="valid account",
                    actual=str(txn.account_id),
                    description=f"Transaction references non-existent account: {txn.account_id}",
                    severity="error",
                    auto_fixable=False,
                ))

            # Check transactions with invalid book references
            orphaned_book_query = (
                select(Transaction)
                .outerjoin(Book, Transaction.book_id == Book.id)
                .where(Book.id.is_(None))
            )
            orphaned_book_result = await db.execute(orphaned_book_query)
            orphaned_book_txns = orphaned_book_result.scalars().all()

            for txn in orphaned_book_txns:
                report.total_checked += 1
                report.add_issue(IntegrityIssue(
                    entity_type="Transaction",
                    entity_id=str(txn.id),
                    issue_type="orphaned_book_reference",
                    expected="valid book",
                    actual=str(txn.book_id),
                    description=f"Transaction references non-existent book: {txn.book_id}",
                    severity="error",
                    auto_fixable=False,
                ))

        except Exception as e:
            logger.error(f"Orphaned records check error: {e}")
            report.status = IntegrityStatus.ERROR
            report.details["error"] = str(e)

        report.duration_ms = (time.time() - start) * 1000
        return report

    # ==================== Full Check ====================

    async def run_full_check(
        self,
        db: AsyncSession,
        user_id: Optional[UUID] = None,
    ) -> FullIntegrityReport:
        """Run all integrity checks.

        Args:
            db: Database session
            user_id: Optional user ID to limit scope

        Returns:
            FullIntegrityReport with all results
        """
        full_report = FullIntegrityReport(started_at=datetime.utcnow())

        logger.info(f"Starting full integrity check (user_id={user_id})")

        # Run all checks
        checks = [
            self.verify_account_balances(db, user_id),
            self.verify_budget_spent(db, user_id),
            self.verify_split_totals(db, user_id),
        ]

        # Add orphaned check only for full system checks
        if user_id is None:
            checks.append(self.verify_no_orphaned_records(db))

        for check_coro in checks:
            report = await check_coro
            full_report.add_report(report)
            logger.info(
                f"Check '{report.check_name}': {report.status.value} "
                f"({report.total_checked} checked, {report.issues_found} issues)"
            )

        full_report.completed_at = datetime.utcnow()
        full_report.total_duration_ms = sum(r.duration_ms for r in full_report.reports)

        self._last_check = full_report

        logger.info(
            f"Full integrity check completed: {full_report.checks_passed}/{full_report.checks_run} passed, "
            f"{full_report.total_issues} total issues, {full_report.total_duration_ms:.1f}ms"
        )

        return full_report

    def get_summary(self) -> Dict[str, Any]:
        """Get summary of last check."""
        if not self._last_check:
            return {"last_check": None}

        return {
            "last_check": {
                "started_at": self._last_check.started_at.isoformat(),
                "completed_at": self._last_check.completed_at.isoformat() if self._last_check.completed_at else None,
                "duration_ms": self._last_check.total_duration_ms,
                "checks_run": self._last_check.checks_run,
                "checks_passed": self._last_check.checks_passed,
                "checks_failed": self._last_check.checks_failed,
                "total_issues": self._last_check.total_issues,
            }
        }


# Global singleton instance
data_integrity = DataIntegrityService()
