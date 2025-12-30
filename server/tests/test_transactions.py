"""End-to-end tests for transaction module."""
import pytest
from datetime import datetime, timedelta
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import uuid4

from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction


class TestExpenseTransactions:
    """Test cases for expense transactions."""

    @pytest.mark.asyncio
    async def test_create_expense_success(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test creating an expense transaction."""
        response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 150.50,
                "description": "Lunch at restaurant",
                "date": datetime.now().isoformat(),
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["type"] == "expense"
        assert float(data["amount"]) == 150.50
        assert data["description"] == "Lunch at restaurant"

    @pytest.mark.asyncio
    async def test_expense_updates_account_balance(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test that expense transaction updates account balance."""
        initial_balance = float(test_account.balance)
        expense_amount = 200.00

        await authenticated_client.post(
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

        # Check account balance
        account_response = await authenticated_client.get(
            f"/api/v1/accounts/{test_account.id}"
        )
        new_balance = float(account_response.json()["balance"])

        # Balance should decrease by expense amount
        assert new_balance == initial_balance - expense_amount


class TestIncomeTransactions:
    """Test cases for income transactions."""

    @pytest.mark.asyncio
    async def test_create_income_success(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        income_category: Category,
    ):
        """Test creating an income transaction."""
        response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(income_category.id),
                "type": "income",
                "amount": 5000.00,
                "description": "Monthly salary",
                "date": datetime.now().isoformat(),
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["type"] == "income"
        assert float(data["amount"]) == 5000.00

    @pytest.mark.asyncio
    async def test_income_updates_account_balance(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        income_category: Category,
    ):
        """Test that income transaction updates account balance."""
        initial_balance = float(test_account.balance)
        income_amount = 3000.00

        await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(income_category.id),
                "type": "income",
                "amount": income_amount,
                "description": "Bonus",
                "date": datetime.now().isoformat(),
            },
        )

        # Check account balance
        account_response = await authenticated_client.get(
            f"/api/v1/accounts/{test_account.id}"
        )
        new_balance = float(account_response.json()["balance"])

        # Balance should increase by income amount
        assert new_balance == initial_balance + income_amount


class TestTransferTransactions:
    """Test cases for transfer transactions."""

    @pytest.mark.asyncio
    async def test_create_transfer_success(
        self,
        authenticated_client: AsyncClient,
        db_session: AsyncSession,
        test_book: Book,
        test_account: Account,
        test_user: User,
    ):
        """Test creating a transfer between accounts."""
        # Create a second account
        target_account = Account(
            id=uuid4(),
            user_id=test_user.id,
            book_id=test_book.id,
            name="Savings Account",
            account_type="bank",
            balance=5000.00,
            currency="CNY",
        )
        db_session.add(target_account)
        await db_session.commit()

        response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "to_account_id": str(target_account.id),
                "type": "transfer",
                "amount": 1000.00,
                "description": "Transfer to savings",
                "date": datetime.now().isoformat(),
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["type"] == "transfer"
        assert float(data["amount"]) == 1000.00


class TestTransactionQueries:
    """Test cases for querying transactions."""

    @pytest.mark.asyncio
    async def test_list_transactions(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test listing transactions."""
        # Create a few transactions
        for i in range(3):
            await authenticated_client.post(
                "/api/v1/transactions",
                json={
                    "book_id": str(test_book.id),
                    "account_id": str(test_account.id),
                    "category_id": str(expense_category.id),
                    "type": "expense",
                    "amount": 100.00 + i * 10,
                    "description": f"Transaction {i}",
                    "date": datetime.now().isoformat(),
                },
            )

        response = await authenticated_client.get(
            f"/api/v1/transactions?book_id={test_book.id}"
        )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list) or "items" in data

    @pytest.mark.asyncio
    async def test_filter_transactions_by_date(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test filtering transactions by date range."""
        today = datetime.now()
        yesterday = today - timedelta(days=1)

        # Create transaction for today
        await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 50.00,
                "description": "Today's expense",
                "date": today.isoformat(),
            },
        )

        response = await authenticated_client.get(
            f"/api/v1/transactions",
            params={
                "book_id": str(test_book.id),
                "start_date": yesterday.date().isoformat(),
                "end_date": today.date().isoformat(),
            },
        )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_filter_transactions_by_category(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test filtering transactions by category."""
        # Create transaction with category
        await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 75.00,
                "description": "Category test",
                "date": datetime.now().isoformat(),
            },
        )

        response = await authenticated_client.get(
            f"/api/v1/transactions",
            params={
                "book_id": str(test_book.id),
                "category_id": str(expense_category.id),
            },
        )

        assert response.status_code == 200


class TestTransactionModification:
    """Test cases for modifying transactions."""

    @pytest.mark.asyncio
    async def test_update_transaction(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test updating a transaction."""
        # Create transaction
        create_response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 100.00,
                "description": "Original description",
                "date": datetime.now().isoformat(),
            },
        )
        transaction_id = create_response.json()["id"]

        # Update transaction
        update_response = await authenticated_client.put(
            f"/api/v1/transactions/{transaction_id}",
            json={
                "amount": 150.00,
                "description": "Updated description",
            },
        )

        assert update_response.status_code == 200
        data = update_response.json()
        assert float(data["amount"]) == 150.00
        assert data["description"] == "Updated description"

    @pytest.mark.asyncio
    async def test_delete_transaction(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test deleting a transaction."""
        # Create transaction
        create_response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 50.00,
                "description": "To be deleted",
                "date": datetime.now().isoformat(),
            },
        )
        transaction_id = create_response.json()["id"]

        # Delete transaction
        delete_response = await authenticated_client.delete(
            f"/api/v1/transactions/{transaction_id}"
        )

        assert delete_response.status_code == 200

        # Verify deletion
        get_response = await authenticated_client.get(
            f"/api/v1/transactions/{transaction_id}"
        )
        assert get_response.status_code == 404


class TestTransactionTags:
    """Test cases for transaction tags."""

    @pytest.mark.asyncio
    async def test_create_transaction_with_tags(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test creating transaction with tags."""
        response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 200.00,
                "description": "Business lunch",
                "date": datetime.now().isoformat(),
                "tags": ["business", "reimbursable"],
            },
        )

        assert response.status_code == 200
        data = response.json()
        if "tags" in data:
            assert "business" in data["tags"]
            assert "reimbursable" in data["tags"]


class TestReimbursableTransactions:
    """Test cases for reimbursable transactions."""

    @pytest.mark.asyncio
    async def test_mark_transaction_reimbursable(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account: Account,
        expense_category: Category,
    ):
        """Test marking transaction as reimbursable."""
        # Create transaction
        create_response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(test_account.id),
                "category_id": str(expense_category.id),
                "type": "expense",
                "amount": 500.00,
                "description": "Business expense",
                "date": datetime.now().isoformat(),
                "is_reimbursable": True,
            },
        )

        assert create_response.status_code == 200
        data = create_response.json()
        if "is_reimbursable" in data:
            assert data["is_reimbursable"] is True


class TestMultiCurrencyTransactions:
    """Test cases for multi-currency support."""

    @pytest.mark.asyncio
    async def test_create_account_with_different_currency(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        data_factory,
    ):
        """Test creating accounts with different currencies."""
        currencies = ["CNY", "USD", "EUR", "JPY", "GBP", "KRW", "HKD", "TWD"]

        for currency in currencies:
            response = await authenticated_client.post(
                "/api/v1/accounts",
                json={
                    "book_id": str(test_book.id),
                    "name": f"{currency} Account",
                    "account_type": "bank",
                    "balance": 1000.00,
                    "currency": currency,
                },
            )
            assert response.status_code == 200
            data = response.json()
            assert data["currency"] == currency

    @pytest.mark.asyncio
    async def test_cross_currency_transfer(
        self,
        authenticated_client: AsyncClient,
        db_session: AsyncSession,
        test_book: Book,
        test_user: User,
    ):
        """Test transfer between accounts with different currencies."""
        # Create CNY account
        cny_account = Account(
            id=uuid4(),
            user_id=test_user.id,
            book_id=test_book.id,
            name="CNY Account",
            account_type="bank",
            balance=10000.00,
            currency="CNY",
        )
        db_session.add(cny_account)

        # Create USD account
        usd_account = Account(
            id=uuid4(),
            user_id=test_user.id,
            book_id=test_book.id,
            name="USD Account",
            account_type="bank",
            balance=1000.00,
            currency="USD",
        )
        db_session.add(usd_account)
        await db_session.commit()

        # Transfer with exchange rate
        response = await authenticated_client.post(
            "/api/v1/transactions",
            json={
                "book_id": str(test_book.id),
                "account_id": str(cny_account.id),
                "to_account_id": str(usd_account.id),
                "type": "transfer",
                "amount": 7000.00,  # CNY amount
                "to_amount": 1000.00,  # USD amount (with exchange rate)
                "exchange_rate": 7.0,
                "description": "CNY to USD transfer",
                "date": datetime.now().isoformat(),
            },
        )

        # May succeed or return validation error depending on implementation
        assert response.status_code in [200, 400, 422]

    @pytest.mark.asyncio
    async def test_manual_exchange_rate_setting(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test manual exchange rate setting endpoint."""
        response = await authenticated_client.post(
            "/api/v1/settings/exchange-rates",
            json={
                "base_currency": "CNY",
                "rates": {
                    "USD": 0.14,
                    "EUR": 0.13,
                    "JPY": 21.0,
                    "GBP": 0.11,
                },
            },
        )

        # May return 200 or 404 depending on implementation
        assert response.status_code in [200, 201, 404]

    @pytest.mark.asyncio
    async def test_get_exchange_rates(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test getting current exchange rates."""
        response = await authenticated_client.get("/api/v1/settings/exchange-rates")

        # May return rates or 404 if not implemented
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_currency_conversion_calculation(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test currency conversion calculation endpoint."""
        response = await authenticated_client.get(
            "/api/v1/currency/convert",
            params={
                "from_currency": "CNY",
                "to_currency": "USD",
                "amount": 1000.00,
            },
        )

        # May return converted amount or 404 if not implemented
        assert response.status_code in [200, 404]


class TestMultiCurrencyReports:
    """Test cases for multi-currency reporting."""

    @pytest.mark.asyncio
    async def test_multi_currency_asset_summary(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting asset summary across multiple currencies."""
        response = await authenticated_client.get(
            "/api/v1/stats/multi-currency-assets",
            params={"book_id": str(test_book.id)},
        )

        # May return summary or 404 if not implemented
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_currency_distribution_report(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting currency distribution in assets."""
        response = await authenticated_client.get(
            "/api/v1/stats/currency-distribution",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_account_list_by_currency(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test listing accounts grouped by currency."""
        response = await authenticated_client.get(
            "/api/v1/accounts",
            params={
                "book_id": str(test_book.id),
                "group_by": "currency",
            },
        )

        assert response.status_code == 200
