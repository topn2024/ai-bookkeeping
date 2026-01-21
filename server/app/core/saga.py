"""Saga transaction pattern implementation based on Chapter 32 design.

Saga pattern for distributed transactions with compensation:
- Each step has an execute action and a compensate action
- If any step fails, previous steps are compensated in reverse order
- Supports both sync and async operations

Use cases:
- Multi-account transfers (debit source, credit target)
- Order processing (reserve inventory, charge payment, fulfill order)
- User registration (create user, send email, create default book)
"""
import asyncio
import logging
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Callable, Dict, List, Optional, TypeVar, Generic

logger = logging.getLogger(__name__)

T = TypeVar("T")


class SagaState(Enum):
    """Saga execution states."""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    COMPENSATING = "compensating"
    COMPENSATED = "compensated"
    FAILED = "failed"


# 别名，保持向后兼容
SagaStatus = SagaState


class StepState(Enum):
    """Individual step states."""
    PENDING = "pending"
    EXECUTING = "executing"
    COMPLETED = "completed"
    FAILED = "failed"
    COMPENSATING = "compensating"
    COMPENSATED = "compensated"


@dataclass
class StepResult:
    """Result of a saga step execution."""
    success: bool
    data: Any = None
    error: Optional[Exception] = None


@dataclass
class SagaStep:
    """A single step in a saga transaction."""
    name: str
    execute: Callable[..., Any]
    compensate: Optional[Callable[..., Any]] = None
    state: StepState = StepState.PENDING
    result: Optional[StepResult] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    compensated_at: Optional[datetime] = None


@dataclass
class SagaContext:
    """Shared context for saga execution."""
    saga_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    data: Dict[str, Any] = field(default_factory=dict)
    step_results: Dict[str, Any] = field(default_factory=dict)

    def set(self, key: str, value: Any):
        """Set a value in the context."""
        self.data[key] = value

    def get(self, key: str, default: Any = None) -> Any:
        """Get a value from the context."""
        return self.data.get(key, default)

    def set_step_result(self, step_name: str, result: Any):
        """Store result from a step for use by later steps."""
        self.step_results[step_name] = result

    def get_step_result(self, step_name: str) -> Any:
        """Get result from a previous step."""
        return self.step_results.get(step_name)


class SagaExecutionError(Exception):
    """Exception raised when saga execution fails."""

    def __init__(
        self,
        message: str,
        saga_id: str,
        failed_step: str,
        original_error: Exception,
        compensated: bool = False,
    ):
        super().__init__(message)
        self.saga_id = saga_id
        self.failed_step = failed_step
        self.original_error = original_error
        self.compensated = compensated


class Saga:
    """Saga transaction orchestrator."""

    def __init__(self, name: str):
        self.name = name
        self.steps: List[SagaStep] = []
        self.state = SagaState.PENDING
        self.context = SagaContext()
        self.started_at: Optional[datetime] = None
        self.completed_at: Optional[datetime] = None

    def add_step(
        self,
        name: str,
        execute: Callable[..., Any],
        compensate: Optional[Callable[..., Any]] = None,
    ) -> "Saga":
        """Add a step to the saga."""
        step = SagaStep(name=name, execute=execute, compensate=compensate)
        self.steps.append(step)
        return self

    async def execute(self, initial_data: Optional[Dict[str, Any]] = None) -> SagaContext:
        """Execute the saga transaction."""
        if initial_data:
            self.context.data.update(initial_data)

        self.state = SagaState.RUNNING
        self.started_at = datetime.utcnow()
        completed_steps: List[SagaStep] = []

        logger.info(f"Saga '{self.name}' [{self.context.saga_id}] starting with {len(self.steps)} steps")

        try:
            for step in self.steps:
                step.state = StepState.EXECUTING
                step.started_at = datetime.utcnow()

                logger.debug(f"Saga '{self.name}' executing step: {step.name}")

                try:
                    # Execute the step
                    if asyncio.iscoroutinefunction(step.execute):
                        result = await step.execute(self.context)
                    else:
                        result = step.execute(self.context)

                    step.result = StepResult(success=True, data=result)
                    step.state = StepState.COMPLETED
                    step.completed_at = datetime.utcnow()
                    completed_steps.append(step)

                    # Store result for later steps
                    if result is not None:
                        self.context.set_step_result(step.name, result)

                    logger.debug(f"Saga '{self.name}' step '{step.name}' completed")

                except Exception as e:
                    step.result = StepResult(success=False, error=e)
                    step.state = StepState.FAILED
                    step.completed_at = datetime.utcnow()

                    logger.error(f"Saga '{self.name}' step '{step.name}' failed: {e}")

                    # Trigger compensation
                    await self._compensate(completed_steps, step.name, e)

                    raise SagaExecutionError(
                        message=f"Saga '{self.name}' failed at step '{step.name}'",
                        saga_id=self.context.saga_id,
                        failed_step=step.name,
                        original_error=e,
                        compensated=True,
                    )

            # All steps completed successfully
            self.state = SagaState.COMPLETED
            self.completed_at = datetime.utcnow()

            logger.info(
                f"Saga '{self.name}' [{self.context.saga_id}] completed successfully "
                f"in {(self.completed_at - self.started_at).total_seconds():.2f}s"
            )

            return self.context

        except SagaExecutionError:
            raise
        except Exception as e:
            self.state = SagaState.FAILED
            logger.error(f"Saga '{self.name}' failed unexpectedly: {e}")
            raise

    async def _compensate(
        self,
        completed_steps: List[SagaStep],
        failed_step_name: str,
        original_error: Exception,
    ):
        """Compensate completed steps in reverse order."""
        self.state = SagaState.COMPENSATING

        logger.warning(
            f"Saga '{self.name}' compensating {len(completed_steps)} steps "
            f"due to failure in '{failed_step_name}'"
        )

        compensation_errors = []

        # Compensate in reverse order
        for step in reversed(completed_steps):
            if step.compensate is None:
                logger.debug(f"Step '{step.name}' has no compensation action, skipping")
                continue

            step.state = StepState.COMPENSATING

            try:
                logger.debug(f"Compensating step: {step.name}")

                if asyncio.iscoroutinefunction(step.compensate):
                    await step.compensate(self.context)
                else:
                    step.compensate(self.context)

                step.state = StepState.COMPENSATED
                step.compensated_at = datetime.utcnow()

                logger.debug(f"Step '{step.name}' compensated successfully")

            except Exception as e:
                logger.error(f"Compensation failed for step '{step.name}': {e}")
                compensation_errors.append((step.name, e))

        if compensation_errors:
            self.state = SagaState.FAILED
            logger.error(
                f"Saga '{self.name}' compensation partially failed: "
                f"{len(compensation_errors)} compensation errors"
            )
        else:
            self.state = SagaState.COMPENSATED
            logger.info(f"Saga '{self.name}' compensation completed successfully")

    def get_status(self) -> Dict[str, Any]:
        """Get saga execution status."""
        return {
            "saga_id": self.context.saga_id,
            "name": self.name,
            "state": self.state.value,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "steps": [
                {
                    "name": step.name,
                    "state": step.state.value,
                    "has_compensation": step.compensate is not None,
                    "started_at": step.started_at.isoformat() if step.started_at else None,
                    "completed_at": step.completed_at.isoformat() if step.completed_at else None,
                }
                for step in self.steps
            ],
        }


class SagaBuilder:
    """Fluent builder for creating sagas."""

    def __init__(self, name: str):
        self.saga = Saga(name)

    def step(
        self,
        name: str,
        execute: Callable[..., Any],
        compensate: Optional[Callable[..., Any]] = None,
    ) -> "SagaBuilder":
        """Add a step to the saga."""
        self.saga.add_step(name, execute, compensate)
        return self

    def build(self) -> Saga:
        """Build and return the saga."""
        return self.saga


def saga(name: str) -> SagaBuilder:
    """Create a new saga builder."""
    return SagaBuilder(name)


# ============== Pre-built Saga Templates ==============

class TransferSaga:
    """Saga for account-to-account transfers."""

    @staticmethod
    async def create(
        source_account_id: str,
        target_account_id: str,
        amount: float,
        fee: float = 0,
        db_session = None,
    ) -> Saga:
        """Create a transfer saga."""

        async def debit_source(ctx: SagaContext):
            """Debit the source account."""
            # In real implementation, this would update the database
            ctx.set("debited_amount", amount + fee)
            logger.info(f"Debited {amount + fee} from account {source_account_id}")
            return {"debited": amount + fee}

        async def compensate_debit(ctx: SagaContext):
            """Reverse the debit on the source account."""
            debited = ctx.get("debited_amount", 0)
            logger.info(f"Reversing debit of {debited} to account {source_account_id}")

        async def credit_target(ctx: SagaContext):
            """Credit the target account."""
            ctx.set("credited_amount", amount)
            logger.info(f"Credited {amount} to account {target_account_id}")
            return {"credited": amount}

        async def compensate_credit(ctx: SagaContext):
            """Reverse the credit on the target account."""
            credited = ctx.get("credited_amount", 0)
            logger.info(f"Reversing credit of {credited} from account {target_account_id}")

        async def record_transaction(ctx: SagaContext):
            """Record the transfer transaction."""
            logger.info(f"Recording transfer: {source_account_id} -> {target_account_id}")
            return {"transaction_id": str(uuid.uuid4())}

        async def compensate_transaction(ctx: SagaContext):
            """Mark the transaction as reversed."""
            tx_result = ctx.get_step_result("record_transaction")
            if tx_result:
                logger.info(f"Marking transaction {tx_result['transaction_id']} as reversed")

        return (
            saga("account_transfer")
            .step("debit_source", debit_source, compensate_debit)
            .step("credit_target", credit_target, compensate_credit)
            .step("record_transaction", record_transaction, compensate_transaction)
            .build()
        )


class UserRegistrationSaga:
    """Saga for user registration with default resources."""

    @staticmethod
    async def create(
        user_data: Dict[str, Any],
        db_session = None,
    ) -> Saga:
        """Create a user registration saga."""

        async def create_user(ctx: SagaContext):
            """Create the user account."""
            user_id = str(uuid.uuid4())
            ctx.set("user_id", user_id)
            logger.info(f"Created user {user_id}")
            return {"user_id": user_id}

        async def compensate_user(ctx: SagaContext):
            """Delete the created user."""
            user_id = ctx.get("user_id")
            logger.info(f"Deleting user {user_id}")

        async def create_default_book(ctx: SagaContext):
            """Create default book for the user."""
            user_id = ctx.get("user_id")
            book_id = str(uuid.uuid4())
            ctx.set("book_id", book_id)
            logger.info(f"Created default book {book_id} for user {user_id}")
            return {"book_id": book_id}

        async def compensate_book(ctx: SagaContext):
            """Delete the default book."""
            book_id = ctx.get("book_id")
            logger.info(f"Deleting book {book_id}")

        async def create_default_account(ctx: SagaContext):
            """Create default account for the user."""
            user_id = ctx.get("user_id")
            account_id = str(uuid.uuid4())
            ctx.set("account_id", account_id)
            logger.info(f"Created default account {account_id} for user {user_id}")
            return {"account_id": account_id}

        async def compensate_account(ctx: SagaContext):
            """Delete the default account."""
            account_id = ctx.get("account_id")
            logger.info(f"Deleting account {account_id}")

        async def send_welcome_email(ctx: SagaContext):
            """Send welcome email (no compensation needed - idempotent)."""
            user_id = ctx.get("user_id")
            logger.info(f"Sending welcome email to user {user_id}")
            return {"email_sent": True}

        return (
            saga("user_registration")
            .step("create_user", create_user, compensate_user)
            .step("create_default_book", create_default_book, compensate_book)
            .step("create_default_account", create_default_account, compensate_account)
            .step("send_welcome_email", send_welcome_email, None)  # No compensation for email
            .build()
        )


# ============== Transaction Sagas (Chapter 33.1) ==============

class TransactionCreateSaga:
    """Saga for creating transactions with balance updates.

    Steps:
    1. Validate input
    2. Create transaction record
    3. Update source account balance
    4. Update target account balance (if transfer)

    Reference: Design Document Chapter 33.1.2 - 创建支出
    """

    @staticmethod
    async def create(
        db_session,
        user_id: str,
        transaction_data: dict,
    ) -> Saga:
        """Create a transaction creation saga."""

        async def validate_input(ctx: SagaContext):
            """Validate transaction data."""
            data = ctx.get("transaction_data")
            # Basic validation
            if not data.get("amount") or data["amount"] <= 0:
                raise ValueError("Invalid amount")
            if not data.get("account_id"):
                raise ValueError("Account required")
            logger.info(f"Transaction validated: amount={data.get('amount')}")
            return {"validated": True}

        async def create_transaction_record(ctx: SagaContext):
            """Create the transaction record in database."""
            data = ctx.get("transaction_data")
            # In real implementation, this creates the transaction
            transaction_id = str(uuid.uuid4())
            ctx.set("transaction_id", transaction_id)
            logger.info(f"Transaction created: {transaction_id}")
            return {"transaction_id": transaction_id}

        async def compensate_transaction(ctx: SagaContext):
            """Delete the transaction record."""
            transaction_id = ctx.get("transaction_id")
            if transaction_id:
                logger.info(f"Deleting transaction: {transaction_id}")
                # In real implementation, delete from database

        async def update_source_balance(ctx: SagaContext):
            """Update source account balance."""
            data = ctx.get("transaction_data")
            account_id = data.get("account_id")
            amount = data.get("amount", 0)
            fee = data.get("fee", 0)
            tx_type = data.get("transaction_type", 1)

            if tx_type == 1:  # Expense
                change = -(amount + fee)
            elif tx_type == 2:  # Income
                change = amount
            else:  # Transfer
                change = -(amount + fee)

            ctx.set("source_balance_change", change)
            ctx.set("source_account_id", account_id)
            logger.info(f"Updated source balance: account={account_id}, change={change}")
            return {"balance_updated": True, "change": change}

        async def compensate_source_balance(ctx: SagaContext):
            """Reverse source account balance change."""
            change = ctx.get("source_balance_change", 0)
            account_id = ctx.get("source_account_id")
            if change != 0:
                logger.info(f"Reversing source balance: account={account_id}, change={-change}")
                # In real implementation, reverse the balance

        async def update_target_balance(ctx: SagaContext):
            """Update target account balance (for transfers)."""
            data = ctx.get("transaction_data")
            tx_type = data.get("transaction_type", 1)

            if tx_type != 3:  # Not a transfer
                return {"skipped": True}

            target_account_id = data.get("target_account_id")
            amount = data.get("amount", 0)

            ctx.set("target_balance_change", amount)
            ctx.set("target_account_id", target_account_id)
            logger.info(f"Updated target balance: account={target_account_id}, change={amount}")
            return {"balance_updated": True, "change": amount}

        async def compensate_target_balance(ctx: SagaContext):
            """Reverse target account balance change."""
            change = ctx.get("target_balance_change", 0)
            account_id = ctx.get("target_account_id")
            if change != 0:
                logger.info(f"Reversing target balance: account={account_id}, change={-change}")
                # In real implementation, reverse the balance

        s = (
            saga("transaction_create")
            .step("validate_input", validate_input, None)
            .step("create_transaction", create_transaction_record, compensate_transaction)
            .step("update_source_balance", update_source_balance, compensate_source_balance)
            .step("update_target_balance", update_target_balance, compensate_target_balance)
            .build()
        )

        s.context.set("user_id", user_id)
        s.context.set("transaction_data", transaction_data)
        s.context.set("db_session", db_session)

        return s


class TransactionDeleteSaga:
    """Saga for deleting transactions with balance restoration.

    Steps:
    1. Restore source account balance
    2. Restore target account balance (if transfer)
    3. Delete transaction record

    Reference: Design Document Chapter 33.1.2 - 删除交易
    """

    @staticmethod
    async def create(
        db_session,
        transaction_id: str,
        transaction_data: dict,
    ) -> Saga:
        """Create a transaction deletion saga."""

        async def restore_source_balance(ctx: SagaContext):
            """Restore source account balance."""
            data = ctx.get("transaction_data")
            account_id = data.get("account_id")
            amount = data.get("amount", 0)
            fee = data.get("fee", 0)
            tx_type = data.get("transaction_type", 1)

            if tx_type == 1:  # Expense - add back
                change = amount + fee
            elif tx_type == 2:  # Income - subtract
                change = -amount
            else:  # Transfer - add back to source
                change = amount + fee

            ctx.set("source_restore_change", change)
            ctx.set("source_account_id", account_id)
            logger.info(f"Restored source balance: account={account_id}, change={change}")
            return {"restored": True}

        async def compensate_source_restore(ctx: SagaContext):
            """Undo source balance restoration."""
            change = ctx.get("source_restore_change", 0)
            account_id = ctx.get("source_account_id")
            if change != 0:
                logger.info(f"Undoing source restore: account={account_id}, change={-change}")

        async def restore_target_balance(ctx: SagaContext):
            """Restore target account balance (for transfers)."""
            data = ctx.get("transaction_data")
            tx_type = data.get("transaction_type", 1)

            if tx_type != 3:  # Not a transfer
                return {"skipped": True}

            target_account_id = data.get("target_account_id")
            amount = data.get("amount", 0)

            ctx.set("target_restore_change", -amount)
            ctx.set("target_account_id", target_account_id)
            logger.info(f"Restored target balance: account={target_account_id}, change={-amount}")
            return {"restored": True}

        async def compensate_target_restore(ctx: SagaContext):
            """Undo target balance restoration."""
            change = ctx.get("target_restore_change", 0)
            account_id = ctx.get("target_account_id")
            if change != 0:
                logger.info(f"Undoing target restore: account={account_id}, change={-change}")

        async def delete_transaction(ctx: SagaContext):
            """Delete the transaction record."""
            transaction_id = ctx.get("transaction_id")
            logger.info(f"Deleted transaction: {transaction_id}")
            return {"deleted": True}

        async def compensate_delete(ctx: SagaContext):
            """Restore the deleted transaction (re-create)."""
            data = ctx.get("transaction_data")
            logger.info(f"Restoring deleted transaction with data: {data}")
            # In real implementation, re-create the transaction

        s = (
            saga("transaction_delete")
            .step("restore_source_balance", restore_source_balance, compensate_source_restore)
            .step("restore_target_balance", restore_target_balance, compensate_target_restore)
            .step("delete_transaction", delete_transaction, compensate_delete)
            .build()
        )

        s.context.set("transaction_id", transaction_id)
        s.context.set("transaction_data", transaction_data)
        s.context.set("db_session", db_session)

        return s


class MonthlySettlementSaga:
    """Saga for monthly budget settlement.

    Steps:
    1. Calculate remaining budget
    2. Transfer to savings (小金库)
    3. Reset budget for next month

    Reference: Design Document Chapter 33.1.2 - 月度结算
    """

    @staticmethod
    async def create(
        db_session,
        user_id: str,
        year_month: str,
    ) -> Saga:
        """Create a monthly settlement saga."""

        async def calculate_remaining(ctx: SagaContext):
            """Calculate remaining budget."""
            year_month = ctx.get("year_month")
            # In real implementation, calculate from database
            remaining = 1000.0  # Example
            ctx.set("remaining_budget", remaining)
            logger.info(f"Calculated remaining budget: {remaining} for {year_month}")
            return {"remaining": remaining}

        async def transfer_to_savings(ctx: SagaContext):
            """Transfer remaining to savings."""
            remaining = ctx.get("remaining_budget", 0)
            if remaining > 0:
                logger.info(f"Transferred {remaining} to savings")
                ctx.set("transferred_amount", remaining)
            return {"transferred": remaining}

        async def compensate_transfer(ctx: SagaContext):
            """Reverse savings transfer."""
            amount = ctx.get("transferred_amount", 0)
            if amount > 0:
                logger.info(f"Reversing savings transfer: {amount}")

        async def reset_budget(ctx: SagaContext):
            """Reset budget for next period."""
            year_month = ctx.get("year_month")
            logger.info(f"Reset budget counters for {year_month}")
            return {"reset": True}

        async def compensate_reset(ctx: SagaContext):
            """Restore budget state."""
            logger.info("Restoring budget state")

        s = (
            saga("monthly_settlement")
            .step("calculate_remaining", calculate_remaining, None)
            .step("transfer_to_savings", transfer_to_savings, compensate_transfer)
            .step("reset_budget", reset_budget, compensate_reset)
            .build()
        )

        s.context.set("user_id", user_id)
        s.context.set("year_month", year_month)
        s.context.set("db_session", db_session)

        return s
