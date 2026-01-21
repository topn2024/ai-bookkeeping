"""定期刷新伙伴化消息库的后台任务"""
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.models.companion_message import CompanionMessageLibrary
from app.services.companion_message_generator import CompanionMessageGenerator
from app.services.llm_service import LLMService
from app.core.database import get_db

logger = logging.getLogger(__name__)


class CompanionMessageRefreshTask:
    """伙伴化消息库定期刷新任务"""

    def __init__(
        self,
        llm_service: LLMService,
        refresh_interval_hours: int = 24,  # 默认每24小时刷新一次
        messages_per_scene: int = 10,  # 每个场景生成10条消息
    ):
        self.generator = CompanionMessageGenerator(llm_service)
        self.refresh_interval_hours = refresh_interval_hours
        self.messages_per_scene = messages_per_scene
        self._task: Optional[asyncio.Task] = None
        self._running = False

    async def start(self):
        """启动定期刷新任务"""
        if self._running:
            logger.warning("Refresh task is already running")
            return

        self._running = True
        self._task = asyncio.create_task(self._run_refresh_loop())
        logger.info(f"Started companion message refresh task (interval: {self.refresh_interval_hours}h)")

    async def stop(self):
        """停止定期刷新任务"""
        if not self._running:
            return

        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

        logger.info("Stopped companion message refresh task")

    async def _run_refresh_loop(self):
        """运行刷新循环"""
        while self._running:
            try:
                # 执行刷新
                await self._refresh_messages()

                # 等待下一次刷新
                await asyncio.sleep(self.refresh_interval_hours * 3600)

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in refresh loop: {e}", exc_info=True)
                # 出错后等待一段时间再重试
                await asyncio.sleep(300)  # 5分钟后重试

    async def _refresh_messages(self):
        """执行消息刷新"""
        logger.info("Starting companion message refresh...")
        start_time = datetime.now()

        try:
            async for db in get_db():
                # 检查是否需要刷新
                should_refresh = await self._should_refresh(db)

                if not should_refresh:
                    logger.info("Message library is fresh, skipping refresh")
                    return

                # 执行刷新
                results = await self.generator.refresh_all_scenes(
                    db=db,
                    messages_per_scene=self.messages_per_scene,
                )

                duration = (datetime.now() - start_time).total_seconds()
                logger.info(
                    f"Refresh completed: {results['success']}/{results['total_scenes']} scenes, "
                    f"{results['total_messages']} messages generated in {duration:.2f}s"
                )

                # 清理旧消息（保留最近的消息）
                await self._cleanup_old_messages(db)

        except Exception as e:
            logger.error(f"Failed to refresh messages: {e}", exc_info=True)

    async def _should_refresh(self, db: AsyncSession) -> bool:
        """检查是否需要刷新"""
        # 检查最新消息的创建时间
        stmt = select(func.max(CompanionMessageLibrary.created_at))
        result = await db.execute(stmt)
        latest_created_at = result.scalar()

        if latest_created_at is None:
            # 没有消息，需要刷新
            return True

        # 如果最新消息超过刷新间隔，需要刷新
        time_since_last_refresh = datetime.utcnow() - latest_created_at
        return time_since_last_refresh > timedelta(hours=self.refresh_interval_hours)

    async def _cleanup_old_messages(self, db: AsyncSession, keep_recent_days: int = 30):
        """清理旧消息，保留最近的消息"""
        cutoff_date = datetime.utcnow() - timedelta(days=keep_recent_days)

        # 对于每个场景/情感组合，保留最近的消息，删除旧的
        # 这里简化处理：只删除超过30天且使用次数为0的消息
        stmt = select(CompanionMessageLibrary).where(
            and_(
                CompanionMessageLibrary.created_at < cutoff_date,
                CompanionMessageLibrary.usage_count == 0,
            )
        )
        result = await db.execute(stmt)
        old_messages = result.scalars().all()

        if old_messages:
            for msg in old_messages:
                await db.delete(msg)
            await db.commit()
            logger.info(f"Cleaned up {len(old_messages)} old unused messages")

    async def trigger_manual_refresh(self):
        """手动触发刷新"""
        logger.info("Manual refresh triggered")
        await self._refresh_messages()


# 全局任务实例
_refresh_task: Optional[CompanionMessageRefreshTask] = None


async def start_refresh_task(
    llm_service: LLMService,
    refresh_interval_hours: int = 24,
    messages_per_scene: int = 10,
):
    """启动刷新任务"""
    global _refresh_task

    if _refresh_task is not None:
        logger.warning("Refresh task already started")
        return

    _refresh_task = CompanionMessageRefreshTask(
        llm_service=llm_service,
        refresh_interval_hours=refresh_interval_hours,
        messages_per_scene=messages_per_scene,
    )
    await _refresh_task.start()


async def stop_refresh_task():
    """停止刷新任务"""
    global _refresh_task

    if _refresh_task is None:
        return

    await _refresh_task.stop()
    _refresh_task = None


async def trigger_manual_refresh():
    """手动触发刷新"""
    global _refresh_task

    if _refresh_task is None:
        raise RuntimeError("Refresh task not started")

    await _refresh_task.trigger_manual_refresh()
