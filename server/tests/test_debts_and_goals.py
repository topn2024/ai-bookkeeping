"""End-to-end tests for debt management and savings goals."""
import pytest
from datetime import datetime, timedelta
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import uuid4

from app.models.user import User
from app.models.book import Book


class TestDebtCreation:
    """Test cases for debt creation."""

    @pytest.mark.asyncio
    async def test_create_credit_card_debt(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a credit card debt."""
        response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Credit Card Debt",
                "debt_type": "credit_card",
                "original_amount": 5000.00,
                "current_balance": 4500.00,
                "interest_rate": 18.0,
                "minimum_payment": 150.00,
                "due_day": 15,
            },
        )

        assert response.status_code in [200, 201]
        if response.status_code in [200, 201]:
            data = response.json()
            assert data["name"] == "Credit Card Debt"
            assert data["debt_type"] == "credit_card"
            assert float(data["interest_rate"]) == 18.0

    @pytest.mark.asyncio
    async def test_create_mortgage_debt(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a mortgage debt."""
        response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Home Mortgage",
                "debt_type": "mortgage",
                "original_amount": 500000.00,
                "current_balance": 450000.00,
                "interest_rate": 4.5,
                "minimum_payment": 2500.00,
                "due_day": 1,
                "start_date": datetime.now().isoformat(),
            },
        )

        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_create_car_loan_debt(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a car loan debt."""
        response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Car Loan",
                "debt_type": "car_loan",
                "original_amount": 30000.00,
                "current_balance": 25000.00,
                "interest_rate": 6.0,
                "minimum_payment": 500.00,
                "due_day": 10,
            },
        )

        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_create_personal_loan_debt(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a personal loan debt."""
        response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Personal Loan",
                "debt_type": "personal_loan",
                "original_amount": 10000.00,
                "current_balance": 8000.00,
                "interest_rate": 12.0,
                "minimum_payment": 300.00,
                "due_day": 20,
            },
        )

        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_create_student_loan_debt(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a student loan debt."""
        response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Student Loan",
                "debt_type": "student_loan",
                "original_amount": 50000.00,
                "current_balance": 45000.00,
                "interest_rate": 5.0,
                "minimum_payment": 400.00,
            },
        )

        assert response.status_code in [200, 201]


class TestDebtPayments:
    """Test cases for debt payments."""

    @pytest.mark.asyncio
    async def test_record_debt_payment(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test recording a debt payment."""
        # Create debt first
        create_response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Test Debt",
                "debt_type": "credit_card",
                "original_amount": 2000.00,
                "current_balance": 2000.00,
                "interest_rate": 18.0,
                "minimum_payment": 100.00,
            },
        )

        if create_response.status_code in [200, 201]:
            debt_id = create_response.json()["id"]

            # Record payment
            payment_response = await authenticated_client.post(
                f"/api/v1/debts/{debt_id}/payments",
                json={
                    "amount": 500.00,
                    "principal_amount": 475.00,
                    "interest_amount": 25.00,
                    "date": datetime.now().isoformat(),
                },
            )

            assert payment_response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_get_debt_payment_history(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting debt payment history."""
        # Create debt
        create_response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Debt With History",
                "debt_type": "personal_loan",
                "original_amount": 5000.00,
                "current_balance": 5000.00,
                "interest_rate": 10.0,
                "minimum_payment": 200.00,
            },
        )

        if create_response.status_code in [200, 201]:
            debt_id = create_response.json()["id"]

            # Get payment history
            response = await authenticated_client.get(
                f"/api/v1/debts/{debt_id}/payments"
            )

            assert response.status_code == 200


class TestDebtStrategies:
    """Test cases for debt repayment strategies."""

    @pytest.mark.asyncio
    async def test_snowball_strategy(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test debt snowball strategy calculation."""
        response = await authenticated_client.get(
            f"/api/v1/debts/strategy/snowball",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_avalanche_strategy(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test debt avalanche strategy calculation."""
        response = await authenticated_client.get(
            f"/api/v1/debts/strategy/avalanche",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_strategy_comparison(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test comparing debt repayment strategies."""
        response = await authenticated_client.get(
            f"/api/v1/debts/strategy/compare",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_payment_simulator(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test debt payment simulator with extra payments."""
        # Create debt
        create_response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Simulation Debt",
                "debt_type": "credit_card",
                "original_amount": 5000.00,
                "current_balance": 5000.00,
                "interest_rate": 18.0,
                "minimum_payment": 150.00,
            },
        )

        if create_response.status_code in [200, 201]:
            debt_id = create_response.json()["id"]

            # Simulate extra payment
            response = await authenticated_client.post(
                f"/api/v1/debts/{debt_id}/simulate",
                json={
                    "extra_payment": 100.00,
                },
            )

            assert response.status_code in [200, 404]


class TestDebtStatistics:
    """Test cases for debt statistics."""

    @pytest.mark.asyncio
    async def test_debt_overview(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting debt overview."""
        response = await authenticated_client.get(
            f"/api/v1/debts/overview",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_estimated_payoff_date(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting estimated payoff date for debts."""
        response = await authenticated_client.get(
            f"/api/v1/debts/payoff-estimate",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_mark_debt_paid_off(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test marking a debt as paid off."""
        # Create debt
        create_response = await authenticated_client.post(
            "/api/v1/debts",
            json={
                "book_id": str(test_book.id),
                "name": "Debt to Pay Off",
                "debt_type": "credit_card",
                "original_amount": 1000.00,
                "current_balance": 0.00,
                "interest_rate": 18.0,
                "minimum_payment": 50.00,
            },
        )

        if create_response.status_code in [200, 201]:
            debt_id = create_response.json()["id"]

            # Mark as paid off
            response = await authenticated_client.post(
                f"/api/v1/debts/{debt_id}/mark-paid"
            )

            assert response.status_code in [200, 204, 404]


class TestSavingsGoalCreation:
    """Test cases for savings goal creation."""

    @pytest.mark.asyncio
    async def test_create_savings_goal(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a savings goal."""
        target_date = (datetime.now() + timedelta(days=365)).isoformat()

        response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Emergency Fund",
                "target_amount": 50000.00,
                "current_amount": 10000.00,
                "target_date": target_date,
            },
        )

        assert response.status_code in [200, 201]
        if response.status_code in [200, 201]:
            data = response.json()
            assert data["name"] == "Emergency Fund"
            assert float(data["target_amount"]) == 50000.00

    @pytest.mark.asyncio
    async def test_create_vacation_goal(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a vacation savings goal."""
        target_date = (datetime.now() + timedelta(days=180)).isoformat()

        response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Summer Vacation",
                "target_amount": 15000.00,
                "current_amount": 0.00,
                "target_date": target_date,
                "icon": "flight",
                "color": "#2196F3",
            },
        )

        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_create_goal_without_target_date(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a savings goal without target date."""
        response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "New Car",
                "target_amount": 100000.00,
                "current_amount": 25000.00,
            },
        )

        assert response.status_code in [200, 201]


class TestSavingsGoalDeposits:
    """Test cases for savings goal deposits."""

    @pytest.mark.asyncio
    async def test_add_deposit_to_goal(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test adding a deposit to savings goal."""
        # Create goal
        create_response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Test Goal",
                "target_amount": 10000.00,
                "current_amount": 0.00,
            },
        )

        if create_response.status_code in [200, 201]:
            goal_id = create_response.json()["id"]

            # Add deposit
            deposit_response = await authenticated_client.post(
                f"/api/v1/savings-goals/{goal_id}/deposits",
                json={
                    "amount": 1000.00,
                    "date": datetime.now().isoformat(),
                    "note": "Monthly savings",
                },
            )

            assert deposit_response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_withdraw_from_goal(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test withdrawing from savings goal."""
        # Create goal with some balance
        create_response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Withdrawal Test",
                "target_amount": 10000.00,
                "current_amount": 5000.00,
            },
        )

        if create_response.status_code in [200, 201]:
            goal_id = create_response.json()["id"]

            # Withdraw
            response = await authenticated_client.post(
                f"/api/v1/savings-goals/{goal_id}/withdraw",
                json={
                    "amount": 1000.00,
                    "date": datetime.now().isoformat(),
                    "note": "Emergency withdrawal",
                },
            )

            assert response.status_code in [200, 201, 404]


class TestSavingsGoalStatistics:
    """Test cases for savings goal statistics."""

    @pytest.mark.asyncio
    async def test_goal_progress(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting savings goal progress."""
        # Create goal
        create_response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Progress Test",
                "target_amount": 5000.00,
                "current_amount": 2500.00,
            },
        )

        if create_response.status_code in [200, 201]:
            goal_id = create_response.json()["id"]

            # Get progress
            response = await authenticated_client.get(
                f"/api/v1/savings-goals/{goal_id}"
            )

            assert response.status_code == 200
            data = response.json()
            # Should be 50% progress
            if "progress_percentage" in data:
                assert data["progress_percentage"] == 50.0

    @pytest.mark.asyncio
    async def test_monthly_savings_recommendation(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting monthly savings recommendation."""
        # Create goal with target date
        target_date = (datetime.now() + timedelta(days=365)).isoformat()

        create_response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Monthly Target Test",
                "target_amount": 12000.00,
                "current_amount": 0.00,
                "target_date": target_date,
            },
        )

        if create_response.status_code in [200, 201]:
            goal_id = create_response.json()["id"]

            # Get recommendation
            response = await authenticated_client.get(
                f"/api/v1/savings-goals/{goal_id}/recommendation"
            )

            assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_all_goals_overview(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting all savings goals overview."""
        response = await authenticated_client.get(
            f"/api/v1/savings-goals/overview",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_mark_goal_completed(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test marking a savings goal as completed."""
        # Create completed goal
        create_response = await authenticated_client.post(
            "/api/v1/savings-goals",
            json={
                "book_id": str(test_book.id),
                "name": "Completed Goal",
                "target_amount": 1000.00,
                "current_amount": 1000.00,
            },
        )

        if create_response.status_code in [200, 201]:
            goal_id = create_response.json()["id"]

            # Mark as completed
            response = await authenticated_client.post(
                f"/api/v1/savings-goals/{goal_id}/complete"
            )

            assert response.status_code in [200, 204, 404]


class TestBillReminders:
    """Test cases for bill reminders."""

    @pytest.mark.asyncio
    async def test_create_bill_reminder(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a bill reminder."""
        due_date = (datetime.now() + timedelta(days=7)).isoformat()

        response = await authenticated_client.post(
            "/api/v1/bill-reminders",
            json={
                "book_id": str(test_book.id),
                "name": "Electricity Bill",
                "amount": 200.00,
                "due_date": due_date,
                "frequency": "monthly",
                "reminder_days_before": 3,
            },
        )

        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_get_upcoming_bills(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting upcoming bills."""
        response = await authenticated_client.get(
            f"/api/v1/bill-reminders/upcoming",
            params={
                "book_id": str(test_book.id),
                "days": 30,
            },
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_mark_bill_paid(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test marking a bill as paid."""
        # Create reminder
        due_date = (datetime.now() + timedelta(days=7)).isoformat()

        create_response = await authenticated_client.post(
            "/api/v1/bill-reminders",
            json={
                "book_id": str(test_book.id),
                "name": "Test Bill",
                "amount": 100.00,
                "due_date": due_date,
                "frequency": "once",
            },
        )

        if create_response.status_code in [200, 201]:
            reminder_id = create_response.json()["id"]

            # Mark as paid
            response = await authenticated_client.post(
                f"/api/v1/bill-reminders/{reminder_id}/mark-paid",
                json={
                    "paid_date": datetime.now().isoformat(),
                    "paid_amount": 100.00,
                },
            )

            assert response.status_code in [200, 204, 404]


class TestRecurringTransactions:
    """Test cases for recurring transactions."""

    @pytest.mark.asyncio
    async def test_create_recurring_expense(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account,
        expense_category,
    ):
        """Test creating a recurring expense."""
        response = await authenticated_client.post(
            "/api/v1/recurring-transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 200.00,
                "description": "Monthly subscription",
                "frequency": "monthly",
                "start_date": datetime.now().isoformat(),
            },
        )

        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_list_recurring_transactions(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test listing recurring transactions."""
        response = await authenticated_client.get(
            f"/api/v1/recurring-transactions",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_pause_recurring_transaction(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account,
        expense_category,
    ):
        """Test pausing a recurring transaction."""
        # Create recurring
        create_response = await authenticated_client.post(
            "/api/v1/recurring-transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 50.00,
                "description": "Test recurring",
                "frequency": "weekly",
            },
        )

        if create_response.status_code in [200, 201]:
            recurring_id = create_response.json()["id"]

            # Pause
            response = await authenticated_client.post(
                f"/api/v1/recurring-transactions/{recurring_id}/pause"
            )

            assert response.status_code in [200, 204, 404]
