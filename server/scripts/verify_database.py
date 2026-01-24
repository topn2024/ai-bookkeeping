#!/usr/bin/env python3
"""
数据库初始化验证脚本

用于验证数据库重置后的数据是否正确初始化
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text, select
from app.core.database import AsyncSessionLocal
from app.models import Category, User, Book, Account, Transaction, Budget
from admin.models import AdminUser, AdminRole, AdminPermission


async def verify_system_categories():
    """验证系统分类"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT COUNT(*) FROM categories WHERE is_system = true")
        )
        count = result.scalar()
        print(f"✓ 系统分类: {count} 个")
        return count > 0


async def verify_admin_roles():
    """验证管理员角色"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT COUNT(*) FROM admin_roles WHERE is_system = true")
        )
        count = result.scalar()
        print(f"✓ 管理员角色: {count} 个")
        return count > 0


async def verify_admin_permissions():
    """验证管理员权限"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT COUNT(*) FROM admin_permissions")
        )
        count = result.scalar()
        print(f"✓ 管理员权限: {count} 个")
        return count > 0


async def verify_default_admin():
    """验证默认管理员"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT username FROM admin_users WHERE username = 'admin'")
        )
        admin = result.scalar()
        if admin:
            print(f"✓ 默认管理员: {admin}")
            return True
        else:
            print("✗ 默认管理员不存在")
            return False


async def verify_test_user():
    """验证测试用户"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT phone FROM users WHERE phone = '13800138000'")
        )
        user = result.scalar()
        if user:
            print(f"✓ 测试用户: {user}")
            return True
        else:
            print("ℹ 测试用户不存在（可能未使用 full 模式）")
            return None


async def verify_test_data():
    """验证测试数据"""
    async with AsyncSessionLocal() as session:
        # 检查账本
        result = await session.execute(text("SELECT COUNT(*) FROM books"))
        books_count = result.scalar()

        # 检查账户
        result = await session.execute(text("SELECT COUNT(*) FROM accounts"))
        accounts_count = result.scalar()

        # 检查交易
        result = await session.execute(text("SELECT COUNT(*) FROM transactions"))
        transactions_count = result.scalar()

        # 检查预算
        result = await session.execute(text("SELECT COUNT(*) FROM budgets"))
        budgets_count = result.scalar()

        if books_count > 0:
            print(f"✓ 测试账本: {books_count} 个")
            print(f"✓ 测试账户: {accounts_count} 个")
            print(f"✓ 测试交易: {transactions_count} 笔")
            print(f"✓ 测试预算: {budgets_count} 个")
            return True
        else:
            print("ℹ 测试数据不存在（可能未使用 full 模式）")
            return None


async def main():
    """主函数"""
    print("\n" + "=" * 60)
    print("🔍 数据库初始化验证")
    print("=" * 60 + "\n")

    try:
        results = []

        print("📋 验证系统数据...")
        results.append(await verify_system_categories())
        results.append(await verify_admin_roles())
        results.append(await verify_admin_permissions())
        results.append(await verify_default_admin())

        print("\n📋 验证测试数据...")
        test_user_result = await verify_test_user()
        if test_user_result:
            results.append(await verify_test_data())

        print("\n" + "=" * 60)
        if all(r for r in results if r is not None):
            print("✅ 验证通过！数据库初始化成功")
        else:
            print("⚠️  部分验证失败，请检查初始化过程")
        print("=" * 60 + "\n")

    except Exception as e:
        print(f"\n❌ 验证失败: {str(e)}\n")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
