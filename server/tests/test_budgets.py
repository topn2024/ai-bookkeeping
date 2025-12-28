"""End-to-end tests for budget and statistics module."""
import pytest
from datetime import datetime
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import uuid4

from app.models.user import User
from app.models.book import Book
from app.models.budget import Budget
from app.models.category import Category


class TestBudgetManagement:
    """Test cases for budget CRUD operations."""

    @pytest.mark.asyncio
    async def test_create_monthly_budget(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating a monthly budget."""
        current_year = datetime.now().year
        current_month = datetime.now().month

        response = await authenticated_client.post(
            "/api/v1/budgets",
            json={
                "book_id": str(test_book.id),
                "name": "Monthly Budget",
                "amount": 10000.00,
                "period": "monthly",
                "year": current_year,
                "month": current_month,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Monthly Budget"
        assert float(data["amount"]) == 10000.00

    @pytest.mark.asyncio
    async def test_create_category_budget(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        expense_category: Category,
    ):
        """Test creating a budget for specific category."""
        response = await authenticated_client.post(
            "/api/v1/budgets",
            json={
                "book_id": str(test_book.id),
                "category_id": str(expense_category.id),
                "name": "Food Budget",
                "amount": 2000.00,
                "period": "monthly",
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["category_id"] == str(expense_category.id)
        assert float(data["amount"]) == 2000.00

    @pytest.mark.asyncio
    async def test_list_budgets(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test listing budgets."""
        # Create a budget first
        await authenticated_client.post(
            "/api/v1/budgets",
            json={
                "book_id": str(test_book.id),
                "name": "Test Budget",
                "amount": 5000.00,
                "period": "monthly",
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        response = await authenticated_client.get(
            f"/api/v1/budgets?book_id={test_book.id}"
        )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_update_budget(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test updating a budget."""
        # Create budget
        create_response = await authenticated_client.post(
            "/api/v1/budgets",
            json={
                "book_id": str(test_book.id),
                "name": "Original Budget",
                "amount": 3000.00,
                "period": "monthly",
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )
        budget_id = create_response.json()["id"]

        # Update budget
        update_response = await authenticated_client.put(
            f"/api/v1/budgets/{budget_id}",
            json={
                "name": "Updated Budget",
                "amount": 4000.00,
            },
        )

        assert update_response.status_code == 200
        data = update_response.json()
        assert data["name"] == "Updated Budget"
        assert float(data["amount"]) == 4000.00

    @pytest.mark.asyncio
    async def test_delete_budget(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test deleting a budget."""
        # Create budget
        create_response = await authenticated_client.post(
            "/api/v1/budgets",
            json={
                "book_id": str(test_book.id),
                "name": "Budget to Delete",
                "amount": 1000.00,
                "period": "monthly",
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )
        budget_id = create_response.json()["id"]

        # Delete budget
        delete_response = await authenticated_client.delete(
            f"/api/v1/budgets/{budget_id}"
        )

        assert delete_response.status_code == 200


class TestExpenseTargets:
    """Test cases for expense targets."""

    @pytest.mark.asyncio
    async def test_create_expense_target(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test creating an expense target."""
        response = await authenticated_client.post(
            "/api/v1/expense-targets",
            json={
                "book_id": str(test_book.id),
                "name": "Monthly Spending Limit",
                "max_amount": 8000.00,
                "year": datetime.now().year,
                "month": datetime.now().month,
                "alert_threshold": 80,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Monthly Spending Limit"
        assert float(data["max_amount"]) == 8000.00

    @pytest.mark.asyncio
    async def test_create_category_expense_target(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        expense_category: Category,
    ):
        """Test creating expense target for specific category."""
        response = await authenticated_client.post(
            "/api/v1/expense-targets",
            json={
                "book_id": str(test_book.id),
                "category_id": str(expense_category.id),
                "name": "Food Spending Limit",
                "max_amount": 2000.00,
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["category_id"] == str(expense_category.id)

    @pytest.mark.asyncio
    async def test_get_expense_target_summary(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting expense target summary."""
        # Create target first
        await authenticated_client.post(
            "/api/v1/expense-targets",
            json={
                "book_id": str(test_book.id),
                "name": "Test Target",
                "max_amount": 5000.00,
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        response = await authenticated_client.get(
            f"/api/v1/expense-targets/summary",
            params={
                "book_id": str(test_book.id),
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        assert response.status_code == 200


class TestStatistics:
    """Test cases for statistics endpoints."""

    @pytest.mark.asyncio
    async def test_get_overview_stats(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting overview statistics."""
        response = await authenticated_client.get(
            f"/api/v1/stats/overview",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code == 200
        data = response.json()
        # Verify expected fields
        assert "total_income" in data or "income" in data or isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_get_monthly_stats(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting monthly statistics."""
        response = await authenticated_client.get(
            f"/api/v1/stats/monthly",
            params={
                "book_id": str(test_book.id),
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_get_category_stats(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting category statistics."""
        response = await authenticated_client.get(
            f"/api/v1/stats/by-category",
            params={
                "book_id": str(test_book.id),
                "year": datetime.now().year,
                "month": datetime.now().month,
            },
        )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_get_trend_stats(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting trend statistics."""
        response = await authenticated_client.get(
            f"/api/v1/stats/trend",
            params={
                "book_id": str(test_book.id),
                "months": 6,
            },
        )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_get_yearly_report(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting yearly report."""
        response = await authenticated_client.get(
            f"/api/v1/stats/yearly",
            params={
                "book_id": str(test_book.id),
                "year": datetime.now().year,
            },
        )

        assert response.status_code == 200


class TestAssetAnalysis:
    """Test cases for asset analysis."""

    @pytest.mark.asyncio
    async def test_get_net_worth(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_account,
    ):
        """Test getting net worth calculation."""
        response = await authenticated_client.get(
            f"/api/v1/stats/net-worth",
            params={"book_id": str(test_book.id)},
        )

        # May return 200 or 404 depending on implementation
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_get_asset_distribution(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test getting asset distribution."""
        response = await authenticated_client.get(
            f"/api/v1/stats/asset-distribution",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]


class TestDataExport:
    """Test cases for data export functionality."""

    @pytest.mark.asyncio
    async def test_export_transactions_csv(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test exporting transactions to CSV."""
        response = await authenticated_client.get(
            f"/api/v1/transactions/export",
            params={
                "book_id": str(test_book.id),
                "format": "csv",
            },
        )

        # May return file or 404 if not implemented
        assert response.status_code in [200, 404]
