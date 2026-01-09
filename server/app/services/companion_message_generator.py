"""AI文案生成服务 - 调用LLM生成伙伴化消息"""
import asyncio
import logging
from datetime import datetime
from typing import List, Optional
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.companion_message import (
    CompanionMessageLibrary,
    CompanionMessageGenerationLog,
)
from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class CompanionMessageGenerator:
    """AI伙伴化消息生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_messages_for_scene(
        self,
        db: AsyncSession,
        scene_type: str,
        emotion_type: str,
        time_of_day: Optional[str] = None,
        language: str = 'zh_CN',
        count: int = 10,
    ) -> List[CompanionMessageLibrary]:
        """为特定场景生成多条消息"""
        batch_id = f"gen_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid4().hex[:8]}"
        start_time = datetime.now()

        generated_messages = []
        success_count = 0
        failed_count = 0
        error_message = None

        try:
            # 构建生成提示词
            prompt = self._build_generation_prompt(
                scene_type=scene_type,
                emotion_type=emotion_type,
                time_of_day=time_of_day,
                language=language,
                count=count,
            )

            # 调用LLM生成
            logger.info(f"Generating {count} messages for {scene_type}/{emotion_type}")
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=1000,
                temperature=0.9,  # 高温度以增加多样性
            )

            # 解析生成的消息
            messages = self._parse_generated_messages(response)

            # 保存到数据库
            for msg_content in messages[:count]:
                try:
                    message = CompanionMessageLibrary(
                        id=uuid4(),
                        scene_type=scene_type,
                        emotion_type=emotion_type,
                        time_of_day=time_of_day,
                        content=msg_content,
                        language=language,
                        generation_method='ai',
                        quality_score=None,  # 后续可以添加质量评估
                        is_active=True,
                        created_at=datetime.utcnow(),
                        updated_at=datetime.utcnow(),
                    )
                    db.add(message)
                    generated_messages.append(message)
                    success_count += 1
                except Exception as e:
                    logger.error(f"Failed to save message: {e}")
                    failed_count += 1

            await db.commit()

        except Exception as e:
            logger.error(f"Failed to generate messages: {e}")
            error_message = str(e)
            failed_count = count

        # 记录生成日志
        generation_time_ms = int((datetime.now() - start_time).total_seconds() * 1000)
        log = CompanionMessageGenerationLog(
            id=uuid4(),
            batch_id=batch_id,
            scene_type=scene_type,
            emotion_type=emotion_type,
            generated_count=count,
            success_count=success_count,
            failed_count=failed_count,
            generation_time_ms=generation_time_ms,
            model_name=self.llm_service.model_name,
            error_message=error_message,
            created_at=datetime.utcnow(),
        )
        db.add(log)
        await db.commit()

        logger.info(
            f"Generated {success_count}/{count} messages for {scene_type}/{emotion_type} "
            f"in {generation_time_ms}ms"
        )

        return generated_messages

    async def refresh_all_scenes(
        self,
        db: AsyncSession,
        messages_per_scene: int = 10,
    ) -> dict:
        """刷新所有场景的消息库"""
        # 定义需要生成的场景和情感组合
        scene_configs = [
            # 问候场景
            ('dailyGreeting', 'energetic', 'morning'),
            ('dailyGreeting', 'friendly', 'afternoon'),
            ('dailyGreeting', 'relaxed', 'evening'),
            ('dailyGreeting', 'caring', 'lateNight'),

            # 记账完成
            ('recordCompletion', 'encouraging', None),
            ('recordCompletion', 'celebrating', None),

            # 连续记账
            ('streakContinued', 'encouraging', None),
            ('streakContinued', 'celebrating', None),

            # 里程碑
            ('milestone', 'celebrating', None),

            # 成就解锁
            ('achievementUnlocked', 'celebrating', None),

            # 预算场景
            ('budgetReminder', 'caring', None),
            ('budgetWarning', 'caring', None),
            ('budgetWarning', 'supportive', None),
            ('budgetCritical', 'supportive', None),
            ('budgetExceeded', 'supportive', None),
            ('budgetAchieved', 'celebrating', None),
            ('budgetAchieved', 'encouraging', None),

            # 钱龄场景
            ('moneyAgeImproved', 'encouraging', None),
            ('moneyAgeImproved', 'celebrating', None),
            ('moneyAgeStable', 'friendly', None),
            ('moneyAgeDeclined', 'supportive', None),

            # 回归场景
            ('returnAfterBreak', 'welcoming', None),
            ('longTimeNoSee', 'welcoming', None),

            # 洞察发现
            ('insightDiscovery', 'encouraging', None),
            ('insightDiscovery', 'curious', None),

            # 晚间总结
            ('eveningSummary', 'relaxed', 'evening'),
            ('eveningSummary', 'caring', 'evening'),

            # 储蓄目标
            ('savingsGoalProgress', 'encouraging', None),
            ('savingsGoalHalfway', 'celebrating', None),
            ('savingsGoalHalfway', 'encouraging', None),
            ('savingsGoalAchieved', 'celebrating', None),
            ('savingsGoalAchieved', 'grateful', None),

            # 特殊日期
            ('specialDate', 'celebrating', None),
            ('specialDate', 'grateful', None),
        ]

        results = {
            'total_scenes': len(scene_configs),
            'success': 0,
            'failed': 0,
            'total_messages': 0,
        }

        for scene_type, emotion_type, time_of_day in scene_configs:
            try:
                messages = await self.generate_messages_for_scene(
                    db=db,
                    scene_type=scene_type,
                    emotion_type=emotion_type,
                    time_of_day=time_of_day,
                    count=messages_per_scene,
                )
                results['success'] += 1
                results['total_messages'] += len(messages)
            except Exception as e:
                logger.error(f"Failed to generate for {scene_type}/{emotion_type}: {e}")
                results['failed'] += 1

            # 避免过快请求LLM
            await asyncio.sleep(1)

        return results

    def _build_generation_prompt(
        self,
        scene_type: str,
        emotion_type: str,
        time_of_day: Optional[str],
        language: str,
        count: int,
    ) -> str:
        """构建生成提示词"""
        scene_descriptions = {
            'dailyGreeting': '每日问候',
            'recordCompletion': '记账完成后的鼓励',
            'streakContinued': '连续记账的激励',
            'milestone': '里程碑达成庆祝',
            'achievementUnlocked': '成就解锁庆祝',
            'budgetReminder': '预算提醒',
            'budgetWarning': '预算预警',
            'budgetCritical': '预算紧急',
            'budgetExceeded': '预算超支安慰',
            'budgetAchieved': '预算达成庆祝',
            'moneyAgeImproved': '钱龄提升鼓励',
            'moneyAgeStable': '钱龄稳定',
            'moneyAgeDeclined': '钱龄下降支持',
            'returnAfterBreak': '短暂离开后回归欢迎',
            'longTimeNoSee': '长时间未见欢迎',
            'insightDiscovery': 'AI洞察发现',
            'eveningSummary': '晚间总结',
            'savingsGoalProgress': '储蓄进度更新',
            'savingsGoalHalfway': '储蓄目标50%',
            'savingsGoalAchieved': '储蓄目标达成',
            'specialDate': '特殊日期祝福',
        }

        emotion_descriptions = {
            'celebrating': '庆祝、兴奋',
            'encouraging': '鼓励、激励',
            'friendly': '友好、亲切',
            'caring': '关心、温暖',
            'supportive': '支持、理解',
            'welcoming': '欢迎、热情',
            'energetic': '有活力、积极',
            'relaxed': '放松、舒缓',
            'neutral': '中性、平和',
            'grateful': '感恩、感谢',
            'curious': '好奇、探索',
        }

        time_context = ''
        if time_of_day:
            time_map = {
                'morning': '早上',
                'afternoon': '下午',
                'evening': '晚上',
                'lateNight': '深夜',
            }
            time_context = f"\n时间段：{time_map.get(time_of_day, time_of_day)}"

        scene_desc = scene_descriptions.get(scene_type, scene_type)
        emotion_desc = emotion_descriptions.get(emotion_type, emotion_type)

        prompt = f"""你是一个温暖、友善的AI理财助手。请为以下场景生成{count}条不同的问候语或提示语。

场景：{scene_desc}
情感基调：{emotion_desc}{time_context}
语言：{'简体中文' if language == 'zh_CN' else language}

要求：
1. 语气温暖友善，像朋友一样，不要生硬或说教
2. 每条消息简短有力，15-30个字
3. 可以适当使用emoji增加亲和力（但不要过度）
4. 避免指责用户，展现理解和支持
5. 每条消息要有所不同，提供多样性
6. 可以使用变量占位符：{{timeGreeting}}（时间问候）、{{nickname}}（昵称）、{{days}}（天数）、{{amount}}（金额）、{{vaultName}}（小金库名称）、{{remaining}}（剩余）、{{daysLeft}}（剩余天数）、{{goalName}}（目标名称）、{{progress}}（进度）、{{achievementName}}（成就名称）、{{consecutiveDays}}（连续天数）、{{previousAge}}（之前钱龄）、{{currentAge}}（当前钱龄）、{{daysSinceLastActive}}（离开天数）

请直接输出{count}条消息，每条一行，不需要编号或其他格式。"""

        return prompt

    def _parse_generated_messages(self, response: str) -> List[str]:
        """解析LLM生成的消息"""
        # 按行分割
        lines = response.strip().split('\n')

        messages = []
        for line in lines:
            # 清理行
            line = line.strip()

            # 跳过空行
            if not line:
                continue

            # 移除可能的编号（如 "1. "、"1) "、"- "等）
            import re
            line = re.sub(r'^[\d\-\*\•]+[\.\)]\s*', '', line)

            # 跳过太短或太长的消息
            if len(line) < 5 or len(line) > 100:
                continue

            messages.append(line)

        return messages
