#!/usr/bin/env python3
"""数据库初始化脚本 - 直接从模型创建所有表

使用方法：
    python scripts/init_database.py

功能：
    - 检查数据库连接
    - 删除所有现有表（危险操作，仅用于开发环境）
    - 根据模型定义创建所有表
    - 创建所有索引和约束
    - 验证表结构

注意：
    ⚠️ 此脚本会删除所有现有数据！
    ⚠️ 仅适用于开发和测试环境！
    ⚠️ 生产环境请谨慎使用！
"""
import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from sqlalchemy import text, inspect
from app.core.database import engine, Base
from app.core.config import settings

# 导入所有模型以注册到 Base.metadata
from app.models.user import User
from app.models.account import Account
from app.models.book import (
    Book, BookMember, BookInvitation, FamilyBudget, MemberBudget,
    FamilySavingGoal, GoalContribution, TransactionSplit, SplitParticipant
)
from app.models.transaction import Transaction
from app.models.category import Category
from app.models.budget import Budget
from app.models.expense_target import ExpenseTarget
from app.models.email_binding import EmailBinding
from app.models.oauth_provider import OAuthProvider
from app.models.backup import Backup
from app.models.app_version import AppVersion
from app.models.upgrade_analytics import UpgradeAnalytics
from app.models.location import GeoFence, FrequentLocation, UserHomeLocation
from app.models.money_age import ResourcePool, ConsumptionRecord, MoneyAgeSnapshot, MoneyAgeConfig
from app.models.companion_message import (
    CompanionMessageLibrary, CompanionMessageGenerationLog, CompanionMessageFeedback
)
from app.models.data_quality_check import DataQualityCheck
from app.models.admin import AdminUser, AdminLog


def print_banner():
    """打印横幅"""
    print("=" * 80)
    print("🗄️  AI记账应用 - 数据库初始化脚本")
    print("=" * 80)
    print()


def check_database_connection():
    """检查数据库连接"""
    print("📡 检查数据库连接...")
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()
        print(f"✅ 数据库连接成功: {settings.DATABASE_URL.split('@')[1] if '@' in settings.DATABASE_URL else 'localhost'}")
        return True
    except Exception as e:
        print(f"❌ 数据库连接失败: {e}")
        return False


def confirm_drop_all():
    """确认删除所有表"""
    print()
    print("⚠️  警告: 此操作将删除数据库中的所有表和数据！")
    print()

    # 检查是否是生产环境
    if not settings.DEBUG:
        print("❌ 错误: 检测到非DEBUG模式（可能是生产环境）")
        print("   为了安全，此脚本只能在 DEBUG=true 时运行")
        return False

    response = input("请输入 'YES' 确认删除所有数据: ")
    return response.strip() == 'YES'


def drop_all_tables():
    """删除所有表"""
    print()
    print("🗑️  删除所有现有表...")
    try:
        # 获取当前所有表
        inspector = inspect(engine)
        existing_tables = inspector.get_table_names()

        if existing_tables:
            print(f"   发现 {len(existing_tables)} 个表: {', '.join(existing_tables)}")
            Base.metadata.drop_all(bind=engine)
            print("✅ 所有表已删除")
        else:
            print("   没有发现现有表")
        return True
    except Exception as e:
        print(f"❌ 删除表失败: {e}")
        return False


def create_all_tables():
    """创建所有表"""
    print()
    print("📋 创建所有表...")
    try:
        Base.metadata.create_all(bind=engine)
        print("✅ 所有表创建成功")
        return True
    except Exception as e:
        print(f"❌ 创建表失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def verify_tables():
    """验证表结构"""
    print()
    print("🔍 验证表结构...")

    try:
        inspector = inspect(engine)
        created_tables = inspector.get_table_names()

        # 期望的表列表（按字母顺序）
        expected_tables = sorted([
            'accounts',
            'admin_logs',
            'admin_users',
            'app_versions',
            'backups',
            'book_invitations',
            'book_members',
            'books',
            'budgets',
            'categories',
            'companion_message_feedback',
            'companion_message_generation_log',
            'companion_message_library',
            'consumption_records',
            'data_quality_checks',
            'email_bindings',
            'expense_targets',
            'family_budgets',
            'family_saving_goals',
            'frequent_locations',
            'geo_fences',
            'goal_contributions',
            'member_budgets',
            'money_age_configs',
            'money_age_snapshots',
            'oauth_providers',
            'resource_pools',
            'split_participants',
            'transaction_splits',
            'transactions',
            'upgrade_analytics',
            'user_home_locations',
            'users',
        ])

        created_tables_sorted = sorted(created_tables)

        # 检查缺失的表
        missing_tables = set(expected_tables) - set(created_tables)
        extra_tables = set(created_tables) - set(expected_tables)

        print(f"   创建了 {len(created_tables)} 个表")

        if missing_tables:
            print(f"⚠️  缺少表: {', '.join(sorted(missing_tables))}")

        if extra_tables:
            print(f"ℹ️  额外的表: {', '.join(sorted(extra_tables))}")

        if not missing_tables and not extra_tables:
            print("✅ 所有预期的表都已创建")

        # 显示一些关键表的详细信息
        print()
        print("📊 关键表字段验证:")

        key_tables = {
            'users': ['id', 'phone', 'email', 'nickname', 'member_level'],
            'books': ['id', 'user_id', 'name', 'book_type'],
            'transactions': ['id', 'user_id', 'book_id', 'account_id', 'amount', 'transaction_date'],
            'book_invitations': ['id', 'book_id', 'code', 'voice_code', 'status'],
            'family_budgets': ['id', 'book_id', 'period', 'total_budget'],
        }

        for table_name, expected_columns in key_tables.items():
            if table_name in created_tables:
                columns = inspector.get_columns(table_name)
                column_names = [col['name'] for col in columns]
                missing_cols = set(expected_columns) - set(column_names)

                if missing_cols:
                    print(f"   ⚠️  {table_name}: 缺少字段 {missing_cols}")
                else:
                    print(f"   ✅ {table_name}: {len(column_names)} 个字段 OK")

        return len(missing_tables) == 0

    except Exception as e:
        print(f"❌ 验证失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def print_summary():
    """打印总结"""
    print()
    print("=" * 80)
    print("✨ 数据库初始化完成！")
    print("=" * 80)
    print()
    print("后续步骤:")
    print("  1. 启动应用服务器")
    print("  2. 创建管理员账户（如需要）")
    print("  3. 开始开发和测试")
    print()


def main():
    """主函数"""
    print_banner()

    # 检查数据库连接
    if not check_database_connection():
        print()
        print("请检查数据库配置:")
        print(f"  DATABASE_URL: {settings.DATABASE_URL[:50]}...")
        sys.exit(1)

    # 确认删除操作
    if not confirm_drop_all():
        print()
        print("❌ 操作已取消")
        sys.exit(0)

    # 删除所有表
    if not drop_all_tables():
        sys.exit(1)

    # 创建所有表
    if not create_all_tables():
        sys.exit(1)

    # 验证表结构
    if not verify_tables():
        print()
        print("⚠️  警告: 表结构验证发现问题，请检查上述输出")

    # 打印总结
    print_summary()


if __name__ == "__main__":
    main()
