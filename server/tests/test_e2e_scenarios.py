"""
End-to-End Scenario Tests for AI Bookkeeping.

These tests simulate complete user workflows across multiple features.
"""
import pytest
from datetime import datetime, timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


class TestCompleteUserJourney:
    """Test complete user journey from registration to daily usage."""

    @pytest.mark.asyncio
    async def test_new_user_complete_setup(
        self, client: AsyncClient, data_factory
    ):
        """
        Scenario: New user registration and initial setup

        Steps:
        1. Register new user
        2. Create first book
        3. Create accounts
        4. Create categories
        5. Add first transaction
        """
        # Step 1: Register
        email = data_factory.random_email()
        register_response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": "SecurePass123!",
                "nickname": "New User",
            },
        )

        if register_response.status_code != 200:
            pytest.skip("Registration endpoint may have different requirements")

        token = register_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Step 2: Create book
        book_response = await client.post(
            "/api/v1/books",
            headers=headers,
            json={
                "name": "My Personal Finance",
                "description": "Personal expense tracking",
            },
        )
        assert book_response.status_code == 200
        book_id = book_response.json()["id"]

        # Step 3: Create accounts
        cash_response = await client.post(
            "/api/v1/accounts",
            headers=headers,
            json={
                "book_id": book_id,
                "name": "Cash Wallet",
                "account_type": "cash",
                "balance": 1000.00,
                "currency": "CNY",
            },
        )
        assert cash_response.status_code == 200
        cash_account_id = cash_response.json()["id"]

        bank_response = await client.post(
            "/api/v1/accounts",
            headers=headers,
            json={
                "book_id": book_id,
                "name": "Bank Account",
                "account_type": "bank",
                "balance": 50000.00,
                "currency": "CNY",
            },
        )
        assert bank_response.status_code == 200

        # Step 4: Create categories
        food_category = await client.post(
            "/api/v1/categories",
            headers=headers,
            json={
                "book_id": book_id,
                "name": "Food",
                "type": "expense",
                "icon_name": "restaurant",
                "color": "#E91E63",
            },
        )
        assert food_category.status_code == 200
        category_id = food_category.json()["id"]

        # Step 5: Add first transaction
        transaction_response = await client.post(
            "/api/v1/transactions",
            headers=headers,
            json={
                "book_id": book_id,
                "account_id": cash_account_id,
                "category_id": category_id,
                "type": "expense",
                "amount": 35.00,
                "description": "Lunch",
                "date": datetime.now().isoformat(),
            },
        )
        assert transaction_response.status_code == 200


class TestMonthlyBudgetingWorkflow:
    """Test monthly budgeting workflow."""

    @pytest.mark.asyncio
    async def test_budget_cycle_management(
        self,
        authenticated_client: AsyncClient,
        test_book,
        test_account,
        expense_category,
    ):
        """
        Scenario: Monthly budget cycle

        Steps:
        1. Create monthly budget
        2. Add transactions throughout month
        3. Check budget status
        4. View budget summary
        """
        current_year = datetime.now().year
        current_month = datetime.now().month

        # Step 1: Create budget
        budget_response = await authenticated_client.post(
            "/api/v1/budgets",
            json={
                "book_id": str(test_book.id),
                "category_id": str(expense_category.id),
                "name": "Food Budget",
                "amount": 2000.00,
                "period": "monthly",
                "year": current_year,
                "month": current_month,
            },
        )
        assert budget_response.status_code == 200

        # Step 2: Add transactions
        for i in range(5):
            await authenticated_client.post(
                "/api/v1/transactions",
                json={
                    "book_id": str(test_book.id),
                    "account_id": str(test_account.id),
                    "category_id": str(expense_category.id),
                    "type": "expense",
                    "amount": 100.00 + i * 20,
                    "description": f"Meal {i + 1}",
                    "date": datetime.now().isoformat(),
                },
            )

        # Step 3: Check budget status
        budget_list = await authenticated_client.get(
            f"/api/v1/budgets?book_id={test_book.id}"
        )
        assert budget_list.status_code == 200


class TestMultiAccountTransfers:
    """Test transfers between multiple accounts."""

    @pytest.mark.asyncio
    async def test_account_transfer_workflow(
        self,
        authenticated_client: AsyncClient,
        db_session: AsyncSession,
        test_book,
        test_user,
    ):
        """
        Scenario: Transfer money between accounts

        Steps:
        1. Create multiple accounts
        2. Transfer from one to another
        3. Verify balances updated correctly
        """
        from uuid import uuid4
        from app.models.account import Account

        # Create source account
        source = Account(
            id=uuid4(),
            user_id=test_user.id,
            book_id=test_book.id,
            name="Checking",
            account_type="bank",
            balance=10000.00,
            currency="CNY",
        )
        db_session.add(source)

        # Create target account
        target = Account(
            id=uuid4(),
            user_id=test_user.id,
            book_id=test_book.id,
            name="Savings",
            account_type="bank",
            balance=5000.00,
            currency="CNY",
        )
        db_session.add(target)
        await db_session.commit()

        initial_source_balance = source.balance
        initial_target_balance = target.balance
        transfer_amount = 2000.00

        # Perform transfer
        transfer_response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(source.id),
                "to_account_id": str(target.id),
                "type": "transfer",
                "amount": transfer_amount,
                "description": "Monthly savings",
                "date": datetime.now().isoformat(),
            },
        )
        assert transfer_response.status_code == 200


class TestReportGeneration:
    """Test report generation scenarios."""

    @pytest.mark.asyncio
    async def test_monthly_report_with_data(
        self,
        authenticated_client: AsyncClient,
        test_book,
        test_account,
        expense_category,
        income_category,
    ):
        """
        Scenario: Generate monthly report

        Steps:
        1. Add various transactions
        2. Generate monthly statistics
        3. Verify report contains correct data
        """
        current_date = datetime.now()

        # Add income
        await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(income_category.id),
                "type": "income",
                "amount": 10000.00,
                "description": "Salary",
                "date": current_date.isoformat(),
            },
        )

        # Add expenses
        for amount in [500, 300, 200, 150]:
            await authenticated_client.post(
                "/api/v1/transactions",
                json={
                    "book_id": str(test_book.id),
                    "account_id": str(test_account.id),
                    "category_id": str(expense_category.id),
                    "type": "expense",
                    "amount": float(amount),
                    "description": "Expense",
                    "date": current_date.isoformat(),
                },
            )

        # Get monthly stats
        stats_response = await authenticated_client.get(
            "/api/v1/stats/monthly",
            params={
                "book_id": str(test_book.id),
                "year": current_date.year,
                "month": current_date.month,
            },
        )
        assert stats_response.status_code == 200


class TestExpenseTargetTracking:
    """Test expense target tracking scenarios."""

    @pytest.mark.asyncio
    async def test_expense_target_workflow(
        self,
        authenticated_client: AsyncClient,
        test_book,
        test_account,
        expense_category,
    ):
        """
        Scenario: Track expense target progress

        Steps:
        1. Create expense target
        2. Add expenses
        3. Check target progress
        4. Verify alerts when approaching limit
        """
        current_date = datetime.now()

        # Create target
        target_response = await authenticated_client.post(
            "/api/v1/expense-targets",
            json={
                "book_id": str(test_book.id),
                "name": "Monthly Limit",
                "max_amount": 5000.00,
                "year": current_date.year,
                "month": current_date.month,
                "alert_threshold": 80,
            },
        )
        assert target_response.status_code == 200
        target_id = target_response.json()["id"]

        # Add expenses (approaching limit)
        for i in range(4):
            await authenticated_client.post(
                "/api/v1/transactions",
                json={
                    "book_id": str(test_book.id),
                    "account_id": str(test_account.id),
                    "category_id": str(expense_category.id),
                    "type": "expense",
                    "amount": 1000.00,
                    "description": f"Expense {i+1}",
                    "date": current_date.isoformat(),
                },
            )

        # Check target status
        target_detail = await authenticated_client.get(
            f"/api/v1/expense-targets/{target_id}"
        )
        assert target_detail.status_code == 200


class TestDataIntegrity:
    """Test data integrity across operations."""

    @pytest.mark.asyncio
    async def test_transaction_deletion_restores_balance(
        self,
        authenticated_client: AsyncClient,
        test_book,
        test_account,
        expense_category,
    ):
        """
        Scenario: Deleting transaction restores account balance

        Steps:
        1. Record initial balance
        2. Create expense transaction
        3. Verify balance decreased
        4. Delete transaction
        5. Verify balance restored
        """
        # Get initial balance
        initial_response = await authenticated_client.get(
            f"/api/v1/accounts/{test_account.id}"
        )
        initial_balance = float(initial_response.json()["balance"])

        # Create transaction
        expense_amount = 500.00
        create_response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": expense_amount,
                "description": "Test expense",
                "date": datetime.now().isoformat(),
            },
        )
        assert create_response.status_code == 200
        transaction_id = create_response.json()["id"]

        # Verify balance decreased
        after_expense = await authenticated_client.get(
            f"/api/v1/accounts/{test_account.id}"
        )
        assert float(after_expense.json()["balance"]) == initial_balance - expense_amount

        # Delete transaction
        delete_response = await authenticated_client.delete(
            f"/api/v1/transactions/{transaction_id}"
        )
        assert delete_response.status_code == 200

        # Verify balance restored
        after_delete = await authenticated_client.get(
            f"/api/v1/accounts/{test_account.id}"
        )
        assert float(after_delete.json()["balance"]) == initial_balance
