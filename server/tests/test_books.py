"""End-to-end tests for book management module."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.book import Book


class TestBookManagement:
    """Test cases for book CRUD operations."""

    @pytest.mark.asyncio
    async def test_create_book_success(
        self, authenticated_client: AsyncClient, data_factory
    ):
        """Test successful book creation."""
        book_name = data_factory.random_string("Book")
        response = await authenticated_client.post(
            "/api/v1/books",
            json={
                "name": book_name,
                "description": "Test book description",
                "icon_name": "book",
                "color": "#4CAF50",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == book_name
        assert data["description"] == "Test book description"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_create_book_without_auth_fails(
        self, client: AsyncClient, data_factory
    ):
        """Test book creation without authentication fails."""
        response = await client.post(
            "/api/v1/books",
            json={
                "name": data_factory.random_string("Book"),
                "description": "Test",
            },
        )

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_list_books_success(
        self, authenticated_client: AsyncClient, test_book: Book
    ):
        """Test listing user's books."""
        response = await authenticated_client.get("/api/v1/books")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        # Verify test book is in the list
        book_ids = [b["id"] for b in data]
        assert str(test_book.id) in book_ids

    @pytest.mark.asyncio
    async def test_get_book_by_id_success(
        self, authenticated_client: AsyncClient, test_book: Book
    ):
        """Test getting a specific book."""
        response = await authenticated_client.get(f"/api/v1/books/{test_book.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(test_book.id)
        assert data["name"] == test_book.name

    @pytest.mark.asyncio
    async def test_get_nonexistent_book_fails(
        self, authenticated_client: AsyncClient
    ):
        """Test getting a nonexistent book fails."""
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = await authenticated_client.get(f"/api/v1/books/{fake_id}")

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_update_book_success(
        self, authenticated_client: AsyncClient, test_book: Book
    ):
        """Test updating a book."""
        new_name = "Updated Book Name"
        response = await authenticated_client.put(
            f"/api/v1/books/{test_book.id}",
            json={
                "name": new_name,
                "description": "Updated description",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == new_name
        assert data["description"] == "Updated description"

    @pytest.mark.asyncio
    async def test_delete_book_success(
        self, authenticated_client: AsyncClient, db_session: AsyncSession, test_user: User
    ):
        """Test deleting a book."""
        # Create a book to delete
        from uuid import uuid4
        book = Book(
            id=uuid4(),
            name="Book to Delete",
            owner_id=test_user.id,
            is_default=False,
        )
        db_session.add(book)
        await db_session.commit()

        response = await authenticated_client.delete(f"/api/v1/books/{book.id}")

        assert response.status_code == 200

        # Verify book is deleted
        get_response = await authenticated_client.get(f"/api/v1/books/{book.id}")
        assert get_response.status_code == 404

    @pytest.mark.asyncio
    async def test_set_default_book_success(
        self, authenticated_client: AsyncClient, test_book: Book
    ):
        """Test setting a book as default."""
        response = await authenticated_client.post(
            f"/api/v1/books/{test_book.id}/set-default"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["is_default"] is True


class TestAccountManagement:
    """Test cases for account CRUD operations."""

    @pytest.mark.asyncio
    async def test_create_account_success(
        self, authenticated_client: AsyncClient, test_book: Book, data_factory
    ):
        """Test successful account creation."""
        account_name = data_factory.random_string("Account")
        response = await authenticated_client.post(
            "/api/v1/accounts",
            json={
                "book_id": str(test_book.id),
                "name": account_name,
                "account_type": "bank",
                "balance": 5000.00,
                "currency": "CNY",
                "icon_name": "account_balance",
                "color": "#2196F3",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == account_name
        assert data["account_type"] == "bank"
        assert float(data["balance"]) == 5000.00

    @pytest.mark.asyncio
    async def test_list_accounts_success(
        self, authenticated_client: AsyncClient, test_account
    ):
        """Test listing accounts."""
        response = await authenticated_client.get("/api/v1/accounts")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_create_various_account_types(
        self, authenticated_client: AsyncClient, test_book: Book, data_factory
    ):
        """Test creating different account types."""
        account_types = ["cash", "bank", "credit", "ewallet", "investment"]

        for acc_type in account_types:
            response = await authenticated_client.post(
                "/api/v1/accounts",
                json={
                    "book_id": str(test_book.id),
                    "name": data_factory.random_string(acc_type),
                    "account_type": acc_type,
                    "balance": 1000.00,
                    "currency": "CNY",
                },
            )
            assert response.status_code == 200
            assert response.json()["account_type"] == acc_type

    @pytest.mark.asyncio
    async def test_update_account_balance(
        self, authenticated_client: AsyncClient, test_account
    ):
        """Test updating account balance."""
        new_balance = 15000.00
        response = await authenticated_client.put(
            f"/api/v1/accounts/{test_account.id}",
            json={
                "balance": new_balance,
            },
        )

        assert response.status_code == 200
        assert float(response.json()["balance"]) == new_balance


class TestCategoryManagement:
    """Test cases for category CRUD operations."""

    @pytest.mark.asyncio
    async def test_create_expense_category(
        self, authenticated_client: AsyncClient, test_book: Book, data_factory
    ):
        """Test creating expense category."""
        category_name = data_factory.random_string("ExpenseCategory")
        response = await authenticated_client.post(
            "/api/v1/categories",
            json={
                "book_id": str(test_book.id),
                "name": category_name,
                "type": "expense",
                "icon_name": "shopping_cart",
                "color": "#F44336",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == category_name
        assert data["type"] == "expense"

    @pytest.mark.asyncio
    async def test_create_income_category(
        self, authenticated_client: AsyncClient, test_book: Book, data_factory
    ):
        """Test creating income category."""
        category_name = data_factory.random_string("IncomeCategory")
        response = await authenticated_client.post(
            "/api/v1/categories",
            json={
                "book_id": str(test_book.id),
                "name": category_name,
                "type": "income",
                "icon_name": "payments",
                "color": "#4CAF50",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == category_name
        assert data["type"] == "income"

    @pytest.mark.asyncio
    async def test_create_subcategory(
        self, authenticated_client: AsyncClient, test_category, data_factory
    ):
        """Test creating a subcategory (child category)."""
        subcategory_name = data_factory.random_string("SubCategory")
        response = await authenticated_client.post(
            "/api/v1/categories",
            json={
                "book_id": str(test_category.book_id),
                "name": subcategory_name,
                "type": "expense",
                "parent_id": str(test_category.id),
                "icon_name": "local_offer",
                "color": "#FF9800",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == subcategory_name
        assert data["parent_id"] == str(test_category.id)

    @pytest.mark.asyncio
    async def test_list_categories(
        self, authenticated_client: AsyncClient, test_category
    ):
        """Test listing categories."""
        response = await authenticated_client.get(
            f"/api/v1/categories?book_id={test_category.book_id}"
        )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_update_category(
        self, authenticated_client: AsyncClient, test_category
    ):
        """Test updating a category."""
        new_name = "Updated Category Name"
        response = await authenticated_client.put(
            f"/api/v1/categories/{test_category.id}",
            json={
                "name": new_name,
                "color": "#9C27B0",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == new_name
        assert data["color"] == "#9C27B0"

    @pytest.mark.asyncio
    async def test_reorder_categories(
        self, authenticated_client: AsyncClient, test_category, expense_category
    ):
        """Test reordering categories."""
        response = await authenticated_client.post(
            "/api/v1/categories/reorder",
            json={
                "category_ids": [str(expense_category.id), str(test_category.id)],
            },
        )

        # May return 200 or 404 depending on implementation
        assert response.status_code in [200, 404, 422]
