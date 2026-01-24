#!/usr/bin/env python3
"""
数据库重置和初始化脚本

用途：
1. 删除所有表并重新创建（支持表结构变更）
2. 初始化系统预设数据（分类、管理员角色等）
3. 可选：创建测试用户和示例数据

使用方法：
    python scripts/reset_database.py --mode [clean|init|full]

    --mode clean: 删除并重建所有表（不初始化数据）
    --mode init: 重建表并初始化系统预设
    --mode full: 重建表、初始化系统预设并创建测试数据
    --confirm: 跳过确认提示（危险！）

警告：此脚本会删除所有数据和表结构，请仅在测试环境使用！
"""
import asyncio
import sys
import os
from pathlib import Path
from datetime import datetime, timedelta
from decimal import Decimal
import argparse

# 添加项目根目录到 Python 路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal, engine, Base
from app.core.security import get_password_hash
from app.core.timezone import beijing_now_naive

# 导入所有模型以确保表结构正确注册到 Base.metadata
from app.models import *
from admin.models import *


async def confirm_action(mode: str) -> bool:
    """确认操作"""
    print("\n" + "=" * 60)
    print("⚠️  警告：数据库重置操作")
    print("=" * 60)
    print(f"模式: {mode}")
    print(f"数据库: {os.getenv('DATABASE_URL', 'Not set')}")
    print("\n此操作将：")

    print("  ❌ 删除所有数据库表")
    print("  ❌ 删除所有用户数据")
    print("  ❌ 删除所有交易记录")
    print("  ✅ 重新创建所有表结构")

    if mode in ['init', 'full']:
        print("  ✅ 初始化系统分类")
        print("  ✅ 初始化管理员角色和权限")
        print("  ✅ 创建默认管理员账号")

    if mode == 'full':
        print("  ✅ 创建测试用户和示例数据")

    print("\n" + "=" * 60)
    response = input("确认执行此操作？(输入 'YES' 继续): ")
    return response == "YES"


async def drop_and_create_tables():
    """删除所有表并重新创建"""
    print("\n🔨 重建数据库表结构...")

    try:
        # 删除所有表 - 使用 CASCADE 处理循环依赖
        print("  🗑️  删除所有表...")
        async with engine.begin() as conn:
            # 对于 PostgreSQL，使用 CASCADE 删除所有表
            # 这会自动处理外键依赖关系
            await conn.execute(text("DROP SCHEMA public CASCADE"))
            await conn.execute(text("CREATE SCHEMA public"))
            # 恢复默认权限
            await conn.execute(text("GRANT ALL ON SCHEMA public TO PUBLIC"))
        print("  ✓ 所有表已删除")

        # 重新创建所有表
        print("  🏗️  创建所有表...")
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("  ✓ 所有表已创建")

        print("✅ 表结构重建完成\n")

    except Exception as e:
        print(f"❌ 表结构重建失败: {str(e)}")
        raise


async def init_system_categories(session: AsyncSession):
    """初始化系统预设分类"""
    print("📁 初始化系统分类...")

    # 支出分类
    expense_categories = [
        {"name": "餐饮", "icon": "🍜", "sort_order": 1},
        {"name": "购物", "icon": "🛍️", "sort_order": 2},
        {"name": "交通", "icon": "🚗", "sort_order": 3},
        {"name": "娱乐", "icon": "🎮", "sort_order": 4},
        {"name": "医疗", "icon": "💊", "sort_order": 5},
        {"name": "住房", "icon": "🏠", "sort_order": 6},
        {"name": "教育", "icon": "📚", "sort_order": 7},
        {"name": "通讯", "icon": "📱", "sort_order": 8},
        {"name": "服饰", "icon": "👔", "sort_order": 9},
        {"name": "美容", "icon": "💄", "sort_order": 10},
        {"name": "运动", "icon": "⚽", "sort_order": 11},
        {"name": "旅游", "icon": "✈️", "sort_order": 12},
        {"name": "数码", "icon": "💻", "sort_order": 13},
        {"name": "宠物", "icon": "🐕", "sort_order": 14},
        {"name": "礼物", "icon": "🎁", "sort_order": 15},
        {"name": "其他", "icon": "📦", "sort_order": 99},
    ]

    # 收入分类
    income_categories = [
        {"name": "工资", "icon": "💰", "sort_order": 1},
        {"name": "奖金", "icon": "🎉", "sort_order": 2},
        {"name": "投资", "icon": "📈", "sort_order": 3},
        {"name": "兼职", "icon": "💼", "sort_order": 4},
        {"name": "红包", "icon": "🧧", "sort_order": 5},
        {"name": "退款", "icon": "↩️", "sort_order": 6},
        {"name": "其他", "icon": "💵", "sort_order": 99},
    ]

    # 创建支出分类
    for cat_data in expense_categories:
        category = Category(
            user_id=None,  # 系统分类
            parent_id=None,
            name=cat_data["name"],
            icon=cat_data["icon"],
            category_type=1,  # 支出
            sort_order=cat_data["sort_order"],
            is_system=True,
        )
        session.add(category)
        print(f"  ✓ 创建支出分类: {cat_data['name']}")

    # 创建收入分类
    for cat_data in income_categories:
        category = Category(
            user_id=None,  # 系统分类
            parent_id=None,
            name=cat_data["name"],
            icon=cat_data["icon"],
            category_type=2,  # 收入
            sort_order=cat_data["sort_order"],
            is_system=True,
        )
        session.add(category)
        print(f"  ✓ 创建收入分类: {cat_data['name']}")

    await session.commit()
    print("✅ 系统分类初始化完成\n")


async def init_admin_roles_and_permissions(session: AsyncSession):
    """初始化管理员角色和权限"""
    print("👥 初始化管理员角色和权限...")

    from admin.models.admin_role import PREDEFINED_PERMISSIONS, PREDEFINED_ROLES

    # 创建权限
    permissions_map = {}
    for perm_data in PREDEFINED_PERMISSIONS:
        permission = AdminPermission(
            code=perm_data["code"],
            name=perm_data["name"],
            description=perm_data.get("description"),
            module=perm_data["module"],
        )
        session.add(permission)
        permissions_map[perm_data["code"]] = permission
        print(f"  ✓ 创建权限: {perm_data['code']} - {perm_data['name']}")

    await session.flush()

    # 创建角色
    for role_name, role_data in PREDEFINED_ROLES.items():
        role = AdminRole(
            name=role_name,
            display_name=role_data["display_name"],
            description=role_data["description"],
            is_system=role_data["is_system"],
        )

        # 分配权限
        if "*" in role_data["permissions"]:
            # 超级管理员拥有所有权限
            role.permissions = list(permissions_map.values())
        else:
            role.permissions = [
                permissions_map[perm_code]
                for perm_code in role_data["permissions"]
                if perm_code in permissions_map
            ]

        session.add(role)
        print(f"  ✓ 创建角色: {role_name} - {role_data['display_name']}")

    await session.commit()
    print("✅ 管理员角色和权限初始化完成\n")


async def create_default_admin(session: AsyncSession):
    """创建默认超级管理员"""
    print("👤 创建默认超级管理员...")

    # 查找超级管理员角色
    result = await session.execute(
        text("SELECT id FROM admin_roles WHERE name = 'super_admin'")
    )
    role_id = result.scalar_one()

    # 创建默认管理员
    admin = AdminUser(
        username="admin",
        email="admin@example.com",
        password_hash=get_password_hash("admin123"),
        display_name="系统管理员",
        role_id=role_id,
        is_active=True,
        is_superadmin=True,
    )
    session.add(admin)
    await session.commit()

    print("  ✓ 用户名: admin")
    print("  ✓ 密码: admin123")
    print("  ✓ 邮箱: admin@example.com")
    print("✅ 默认管理员创建完成\n")


async def create_test_data(session: AsyncSession):
    """创建测试用户和示例数据"""
    print("🧪 创建测试数据...")

    # 创建测试用户
    test_user = User(
        phone="13800138000",
        email="test@example.com",
        email_verified=True,
        email_verified_at=beijing_now_naive(),
        password_hash=get_password_hash("test123"),
        nickname="测试用户",
        member_level=0,
        is_active=True,
    )
    session.add(test_user)
    await session.flush()
    print(f"  ✓ 创建测试用户: {test_user.nickname}")

    # 创建个人账本
    personal_book = Book(
        user_id=test_user.id,
        name="我的账本",
        description="个人日常记账",
        book_type=0,  # 个人账本
        is_default=True,
        currency="CNY",
    )
    session.add(personal_book)
    await session.flush()
    print(f"  ✓ 创建账本: {personal_book.name}")

    # 创建账户
    accounts_data = [
        {"name": "现金", "account_type": 1, "balance": Decimal("1000.00"), "is_default": True},
        {"name": "工商银行", "account_type": 2, "balance": Decimal("5000.00")},
        {"name": "支付宝", "account_type": 4, "balance": Decimal("2000.00")},
        {"name": "微信", "account_type": 5, "balance": Decimal("500.00")},
    ]

    accounts = []
    for acc_data in accounts_data:
        account = Account(
            user_id=test_user.id,
            name=acc_data["name"],
            account_type=acc_data["account_type"],
            balance=acc_data["balance"],
            is_default=acc_data.get("is_default", False),
            currency="CNY",
        )
        session.add(account)
        accounts.append(account)
        print(f"  ✓ 创建账户: {account.name} (余额: ¥{account.balance})")

    await session.flush()

    # 获取系统分类
    result = await session.execute(
        text("SELECT id, name, category_type FROM categories WHERE is_system = true ORDER BY category_type, sort_order")
    )
    categories = result.fetchall()
    expense_categories = [c for c in categories if c[2] == 1]
    income_categories = [c for c in categories if c[2] == 2]

    # 创建示例交易
    print("  📝 创建示例交易...")

    # 收入交易
    income_txn = Transaction(
        user_id=test_user.id,
        book_id=personal_book.id,
        account_id=accounts[1].id,  # 工商银行
        category_id=income_categories[0][0],  # 工资
        transaction_type=2,  # 收入
        amount=Decimal("8000.00"),
        transaction_date=(beijing_now_naive() - timedelta(days=5)).date(),
        note="月度工资",
    )
    session.add(income_txn)

    # 支出交易
    expense_transactions = [
        {
            "account": accounts[0],  # 现金
            "category": expense_categories[0][0],  # 餐饮
            "amount": Decimal("45.50"),
            "note": "午餐",
            "days_ago": 1,
        },
        {
            "account": accounts[2],  # 支付宝
            "category": expense_categories[1][0],  # 购物
            "amount": Decimal("299.00"),
            "note": "买衣服",
            "days_ago": 2,
        },
        {
            "account": accounts[3],  # 微信
            "category": expense_categories[2][0],  # 交通
            "amount": Decimal("15.00"),
            "note": "打车",
            "days_ago": 1,
        },
        {
            "account": accounts[2],  # 支付宝
            "category": expense_categories[0][0],  # 餐饮
            "amount": Decimal("68.00"),
            "note": "晚餐",
            "days_ago": 0,
        },
    ]

    for txn_data in expense_transactions:
        transaction = Transaction(
            user_id=test_user.id,
            book_id=personal_book.id,
            account_id=txn_data["account"].id,
            category_id=txn_data["category"],
            transaction_type=1,  # 支出
            amount=txn_data["amount"],
            transaction_date=(beijing_now_naive() - timedelta(days=txn_data["days_ago"])).date(),
            note=txn_data["note"],
        )
        session.add(transaction)

    print(f"  ✓ 创建 {len(expense_transactions) + 1} 笔交易记录")

    # 创建预算
    current_date = beijing_now_naive()
    budget = Budget(
        user_id=test_user.id,
        book_id=personal_book.id,
        category_id=None,  # 总预算
        name="月度预算",
        budget_type=1,  # 月度
        amount=Decimal("3000.00"),
        year=current_date.year,
        month=current_date.month,
        is_active=True,
    )
    session.add(budget)
    print(f"  ✓ 创建月度预算: ¥{budget.amount}")

    await session.commit()
    print("\n✅ 测试数据创建完成")
    print(f"\n📋 测试账号信息：")
    print(f"  手机号: 13800138000")
    print(f"  邮箱: test@example.com")
    print(f"  密码: test123")
    print()


async def main(mode: str, skip_confirm: bool = False):
    """主函数"""
    print("\n" + "=" * 60)
    print("🔧 AI记账 - 数据库重置工具")
    print("=" * 60)

    # 确认操作
    if not skip_confirm:
        if not await confirm_action(mode):
            print("\n❌ 操作已取消")
            return

    try:
        # 重建表结构（所有模式都需要）
        await drop_and_create_tables()

        # 初始化系统数据
        if mode in ['init', 'full']:
            async with AsyncSessionLocal() as session:
                await init_system_categories(session)
                await init_admin_roles_and_permissions(session)
                await create_default_admin(session)

        # 创建测试数据
        if mode == 'full':
            async with AsyncSessionLocal() as session:
                await create_test_data(session)

        print("\n" + "=" * 60)
        print("✅ 数据库重置完成！")
        print("=" * 60 + "\n")

    except Exception as e:
        print(f"\n❌ 操作失败: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="AI记账数据库重置工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python scripts/reset_database.py --mode clean     # 仅重建表结构
  python scripts/reset_database.py --mode init      # 重建表并初始化系统数据
  python scripts/reset_database.py --mode full      # 完整重置（含测试数据）
  python scripts/reset_database.py --mode full --confirm  # 跳过确认
        """
    )
    parser.add_argument(
        "--mode",
        choices=["clean", "init", "full"],
        default="init",
        help="重置模式: clean(仅重建表), init(初始化系统数据), full(含测试数据)"
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="跳过确认提示（危险！）"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    asyncio.run(main(args.mode, args.confirm))
