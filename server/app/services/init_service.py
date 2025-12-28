"""Service for initializing new user data."""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category


# Default expense categories
DEFAULT_EXPENSE_CATEGORIES = [
    ("餐饮", "🍽️"),
    ("交通", "🚌"),
    ("购物", "🛒"),
    ("娱乐", "🎮"),
    ("住房", "🏠"),
    ("医疗", "🏥"),
    ("教育", "📚"),
    ("人情", "👥"),
    ("通讯", "📱"),
    ("其他", "📦"),
]

# Default income categories
DEFAULT_INCOME_CATEGORIES = [
    ("工资", "💰"),
    ("奖金", "🏆"),
    ("兼职", "💼"),
    ("理财", "📈"),
    ("红包", "🧧"),
    ("其他", "💝"),
]


async def init_system_categories(db: AsyncSession):
    """Initialize system default categories if not exist."""
    # Check if system categories exist
    result = await db.execute(
        select(Category).where(Category.is_system == True).limit(1)
    )
    if result.scalar_one_or_none():
        return  # Already initialized

    # Create expense categories
    for i, (name, icon) in enumerate(DEFAULT_EXPENSE_CATEGORIES):
        category = Category(
            name=name,
            icon=icon,
            category_type=1,  # expense
            sort_order=i,
            is_system=True,
        )
        db.add(category)

    # Create income categories
    for i, (name, icon) in enumerate(DEFAULT_INCOME_CATEGORIES):
        category = Category(
            name=name,
            icon=icon,
            category_type=2,  # income
            sort_order=i,
            is_system=True,
        )
        db.add(category)

    await db.flush()


async def init_user_data(db: AsyncSession, user: User):
    """Initialize default data for a new user."""
    # Ensure system categories exist
    await init_system_categories(db)

    # Create default book
    book = Book(
        user_id=user.id,
        name="日常账本",
        icon="📒",
        book_type=0,
        is_default=True,
    )
    db.add(book)

    # Create default accounts
    accounts = [
        Account(
            user_id=user.id,
            name="现金",
            account_type=1,
            icon="💵",
            is_default=True,
        ),
        Account(
            user_id=user.id,
            name="支付宝",
            account_type=4,
            icon="📱",
        ),
        Account(
            user_id=user.id,
            name="微信",
            account_type=5,
            icon="💬",
        ),
    ]
    for account in accounts:
        db.add(account)

    await db.flush()
