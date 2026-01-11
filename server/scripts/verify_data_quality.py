#!/usr/bin/env python3
"""
数据质量监控功能验证脚本

用于验证数据质量监控功能是否正确部署和运行。

Usage:
    python scripts/verify_data_quality.py
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from admin.models.data_quality_check import DataQualityCheck
from app.services.data_quality_checker import DataQualityChecker


async def verify_database_connection():
    """验证数据库连接"""
    print("=" * 60)
    print("1. 验证数据库连接")
    print("=" * 60)

    try:
        engine = create_async_engine(settings.DATABASE_URL, echo=False)
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT 1"))
            assert result.scalar() == 1
            print("✓ 数据库连接成功")
        await engine.dispose()
        return True
    except Exception as e:
        print(f"✗ 数据库连接失败: {e}")
        return False


async def verify_table_exists():
    """验证 data_quality_checks 表是否存在"""
    print("\n" + "=" * 60)
    print("2. 验证数据表")
    print("=" * 60)

    try:
        engine = create_async_engine(settings.DATABASE_URL, echo=False)
        async with engine.connect() as conn:
            # 检查表是否存在
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables
                    WHERE table_schema = 'public'
                    AND table_name = 'data_quality_checks'
                )
            """))
            exists = result.scalar()

            if exists:
                print("✓ data_quality_checks 表存在")

                # 检查表结构
                result = await conn.execute(text("""
                    SELECT column_name, data_type, is_nullable
                    FROM information_schema.columns
                    WHERE table_name = 'data_quality_checks'
                    ORDER BY ordinal_position
                """))
                columns = result.fetchall()

                print(f"\n表结构 ({len(columns)} 列):")
                for col_name, data_type, is_nullable in columns:
                    nullable = "NULL" if is_nullable == "YES" else "NOT NULL"
                    print(f"  - {col_name:20} {data_type:20} {nullable}")

                # 检查索引
                result = await conn.execute(text("""
                    SELECT indexname, indexdef
                    FROM pg_indexes
                    WHERE tablename = 'data_quality_checks'
                """))
                indexes = result.fetchall()

                if indexes:
                    print(f"\n索引 ({len(indexes)} 个):")
                    for idx_name, idx_def in indexes:
                        print(f"  - {idx_name}")

                await engine.dispose()
                return True
            else:
                print("✗ data_quality_checks 表不存在")
                print("\n请运行数据库迁移:")
                print("  alembic upgrade head")
                await engine.dispose()
                return False

    except Exception as e:
        print(f"✗ 验证表失败: {e}")
        return False


async def verify_model():
    """验证 ORM 模型"""
    print("\n" + "=" * 60)
    print("3. 验证 ORM 模型")
    print("=" * 60)

    try:
        # 测试创建和查询
        engine = create_async_engine(settings.DATABASE_URL, echo=False)
        async_session = sessionmaker(
            engine, class_=AsyncSession, expire_on_commit=False
        )

        from datetime import datetime

        async with async_session() as session:
            # 创建测试记录
            test_check = DataQualityCheck(
                check_time=datetime.utcnow(),
                check_type="null_check",
                target_table="test_table",
                target_column="test_column",
                severity="low",
                total_records=100,
                affected_records=1,
                issue_details={"test": "verification"},
                status="detected",
            )

            session.add(test_check)
            await session.commit()
            await session.refresh(test_check)

            test_id = test_check.id
            print(f"✓ 成功创建测试记录 (ID: {test_id})")

            # 查询测试记录
            result = await session.execute(
                text("SELECT * FROM data_quality_checks WHERE id = :id"),
                {"id": test_id}
            )
            record = result.fetchone()

            if record:
                print("✓ 成功查询测试记录")

                # 删除测试记录
                await session.execute(
                    text("DELETE FROM data_quality_checks WHERE id = :id"),
                    {"id": test_id}
                )
                await session.commit()
                print("✓ 成功删除测试记录")
            else:
                print("✗ 查询测试记录失败")
                return False

        await engine.dispose()
        return True

    except Exception as e:
        print(f"✗ 验证模型失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def verify_checker_service():
    """验证数据质量检查服务"""
    print("\n" + "=" * 60)
    print("4. 验证数据质量检查服务")
    print("=" * 60)

    try:
        engine = create_async_engine(settings.DATABASE_URL, echo=False)
        async_session = sessionmaker(
            engine, class_=AsyncSession, expire_on_commit=False
        )

        async with async_session() as session:
            checker = DataQualityChecker(session)
            print("✓ 成功实例化 DataQualityChecker")

            # 检查是否有表可以测试
            from app.models.user import User

            print(f"\n尝试对 users 表进行空值检查...")
            result = await checker.check_null_values(
                table_name="users",
                column_name="phone",
                model_class=User,
            )

            if result:
                print(f"✓ 空值检查完成")
                print(f"  - 检查类型: {result.check_type}")
                print(f"  - 目标表: {result.target_table}")
                print(f"  - 目标列: {result.target_column}")
                print(f"  - 严重程度: {result.severity}")
                print(f"  - 总记录数: {result.total_records}")
                print(f"  - 受影响记录数: {result.affected_records}")

                # 删除测试结果
                await session.delete(result)
                await session.commit()
                print("  - 已清理测试数据")
            else:
                print("  - 未发现问题（符合预期）")

        await engine.dispose()
        return True

    except Exception as e:
        print(f"✗ 验证检查服务失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def verify_api_routes():
    """验证 API 路由是否正确注册"""
    print("\n" + "=" * 60)
    print("5. 验证 API 路由")
    print("=" * 60)

    try:
        from admin.api import admin_router

        routes = []
        for route in admin_router.routes:
            if hasattr(route, 'path'):
                if 'data-quality' in route.path:
                    routes.append(f"{','.join(route.methods)} {route.path}")

        if routes:
            print(f"✓ 找到 {len(routes)} 个数据质量相关路由:")
            for route in sorted(routes):
                print(f"  - {route}")
            return True
        else:
            print("✗ 未找到数据质量相关路由")
            return False

    except Exception as e:
        print(f"✗ 验证路由失败: {e}")
        return False


async def verify_celery_tasks():
    """验证 Celery 任务配置"""
    print("\n" + "=" * 60)
    print("6. 验证 Celery 任务")
    print("=" * 60)

    try:
        from app.tasks.celery_app import celery_app

        # 检查任务是否注册
        tasks = []
        for task_name in celery_app.tasks.keys():
            if 'data_quality' in task_name:
                tasks.append(task_name)

        if tasks:
            print(f"✓ 找到 {len(tasks)} 个数据质量相关任务:")
            for task in sorted(tasks):
                print(f"  - {task}")
        else:
            print("⚠ 未找到数据质量相关任务")
            print("  这可能是正常的，取决于任务是否已导入")

        # 检查定时任务配置
        schedule = celery_app.conf.beat_schedule
        dq_schedules = []
        for name, config in schedule.items():
            if 'data_quality' in config.get('task', ''):
                dq_schedules.append(name)
                print(f"\n✓ 定时任务配置: {name}")
                print(f"  - 任务: {config['task']}")
                print(f"  - 调度: {config['schedule']}")

        if not dq_schedules:
            print("✗ 未找到数据质量定时任务配置")
            return False

        return True

    except Exception as e:
        print(f"✗ 验证 Celery 任务失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def main():
    """主验证流程"""
    print("\n")
    print("╔" + "=" * 58 + "╗")
    print("║" + " " * 10 + "数据质量监控功能验证" + " " * 26 + "║")
    print("╚" + "=" * 58 + "╝")
    print()

    results = {
        "数据库连接": await verify_database_connection(),
        "数据表": await verify_table_exists(),
        "ORM模型": await verify_model(),
        "检查服务": await verify_checker_service(),
        "API路由": await verify_api_routes(),
        "Celery任务": await verify_celery_tasks(),
    }

    # 总结
    print("\n" + "=" * 60)
    print("验证总结")
    print("=" * 60)

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for name, result in results.items():
        status = "✓ 通过" if result else "✗ 失败"
        print(f"{name:15} {status}")

    print()
    print(f"总计: {passed}/{total} 项通过")

    if passed == total:
        print("\n🎉 所有验证通过！数据质量监控功能已正确部署。")
        print("\n后续步骤:")
        print("1. 启动 Celery Worker:")
        print("   celery -A app.tasks.celery_app worker --beat --loglevel=info")
        print("\n2. 启动 FastAPI 服务:")
        print("   uvicorn app.main:app --reload")
        print("\n3. 访问管理后台:")
        print("   系统监控 -> 数据质量")
        return 0
    else:
        print("\n⚠️  部分验证失败，请检查错误信息并修复。")
        print("\n参考文档:")
        print("  - server/DEPLOYMENT.md")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
