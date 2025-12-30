"""Pytest configuration and fixtures for E2E testing."""
import asyncio
import os
from typing import AsyncGenerator, Generator
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

from app.core.database import Base, get_db
from app.core.config import settings
from app.core.security import create_access_token, get_password_hash
from app.main import app
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category


# Test database URL - use a separate test database
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://ai_bookkeeping:AiBookkeeping@2024@localhost:5432/ai_bookkeeping_test"
)


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def test_engine():
    """Create test database engine."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        poolclass=NullPool,
        echo=False,
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create database session for each test."""
    async_session_factory = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with async_session_factory() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture(scope="function")
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create test HTTP client."""
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    """Create a test user."""
    user = User(
        id=uuid4(),
        email=f"test_{uuid4().hex[:8]}@example.com",
        phone=f"138{uuid4().hex[:8][:8].ljust(8, '0')}",
        password_hash=get_password_hash("testpassword123"),
        nickname="Test User",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def test_user_token(test_user: User) -> str:
    """Create access token for test user."""
    return create_access_token(str(test_user.id))


@pytest_asyncio.fixture
async def authenticated_client(
    client: AsyncClient,
    test_user_token: str
) -> AsyncClient:
    """Create authenticated test client."""
    client.headers["Authorization"] = f"Bearer {test_user_token}"
    return client


@pytest_asyncio.fixture
async def test_book(db_session: AsyncSession, test_user: User) -> Book:
    """Create a test book."""
    book = Book(
        id=uuid4(),
        name="Test Book",
        user_id=test_user.id,
        is_default=True,
    )
    db_session.add(book)
    await db_session.commit()
    await db_session.refresh(book)
    return book


@pytest_asyncio.fixture
async def test_account(db_session: AsyncSession, test_user: User, test_book: Book) -> Account:
    """Create a test account."""
    account = Account(
        id=uuid4(),
        user_id=test_user.id,
        book_id=test_book.id,
        name="Test Cash Account",
        account_type="cash",
        balance=10000.00,
        currency="CNY",
        is_active=True,
    )
    db_session.add(account)
    await db_session.commit()
    await db_session.refresh(account)
    return account


@pytest_asyncio.fixture
async def test_category(db_session: AsyncSession, test_user: User, test_book: Book) -> Category:
    """Create a test category."""
    category = Category(
        id=uuid4(),
        user_id=test_user.id,
        book_id=test_book.id,
        name="Test Category",
        type="expense",
        icon_name="shopping_cart",
        color="#FF5722",
        sort_order=0,
    )
    db_session.add(category)
    await db_session.commit()
    await db_session.refresh(category)
    return category


@pytest_asyncio.fixture
async def expense_category(db_session: AsyncSession, test_user: User, test_book: Book) -> Category:
    """Create an expense category."""
    category = Category(
        id=uuid4(),
        user_id=test_user.id,
        book_id=test_book.id,
        name="Food & Dining",
        type="expense",
        icon_name="restaurant",
        color="#E91E63",
        sort_order=1,
    )
    db_session.add(category)
    await db_session.commit()
    await db_session.refresh(category)
    return category


@pytest_asyncio.fixture
async def income_category(db_session: AsyncSession, test_user: User, test_book: Book) -> Category:
    """Create an income category."""
    category = Category(
        id=uuid4(),
        user_id=test_user.id,
        book_id=test_book.id,
        name="Salary",
        type="income",
        icon_name="payments",
        color="#4CAF50",
        sort_order=0,
    )
    db_session.add(category)
    await db_session.commit()
    await db_session.refresh(category)
    return category


# Helper class for test data generation
class TestDataFactory:
    """Factory for generating test data."""

    @staticmethod
    def random_email() -> str:
        return f"user_{uuid4().hex[:8]}@test.com"

    @staticmethod
    def random_phone() -> str:
        return f"138{uuid4().hex[:8][:8].ljust(8, '0')}"

    @staticmethod
    def random_string(prefix: str = "") -> str:
        return f"{prefix}_{uuid4().hex[:8]}"


@pytest.fixture
def data_factory() -> TestDataFactory:
    """Provide test data factory."""
    return TestDataFactory()
