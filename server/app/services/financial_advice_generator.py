"""财务建议AI生成服务"""
import asyncio
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class FinancialAdviceGenerator:
    """财务建议AI生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_budget_warning_advice(
        self,
        category: str,
        remaining: float,
        days_left: int,
        daily_average: float,
        user_context: Optional[Dict[str, Any]] = None,
    ) -> str:
        """生成预算预警建议"""
        prompt = f"""你是一个温暖、专业的理财助手。用户的{category}预算即将用完，请生成一条简短的建议。

当前情况：
- 分类：{category}
- 剩余预算：¥{remaining:.0f}
- 剩余天数：{days_left}天
- 日均可用：¥{daily_average:.0f}

要求：
1. 语气友好、不指责
2. 提供1-2个具体可行的建议
3. 30-50字
4. 可以适当使用emoji

请直接输出建议文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=150,
                temperature=0.8,
            )
            return response.strip()
        except Exception as e:
            logger.error(f"Failed to generate budget warning advice: {e}")
            # 降级方案
            return f"{category}还剩 ¥{remaining:.0f}/{days_left}天，平均每天¥{daily_average:.0f}。建议适当控制消费～"

    async def generate_overspending_advice(
        self,
        category: str,
        overspent_amount: float,
        reason: Optional[str] = None,
        available_sources: Optional[List[Dict[str, Any]]] = None,
    ) -> str:
        """生成超支处理建议"""
        reason_text = f"，主要是{reason}" if reason else ""
        sources_text = ""
        if available_sources:
            sources_text = "\n可调拨来源：\n" + "\n".join(
                [f"- {s['name']}：还剩¥{s['remaining']:.0f}" for s in available_sources]
            )

        prompt = f"""你是一个温暖、专业的理财助手。用户的{category}预算超支了，请生成一条处理建议。

当前情况：
- 超支分类：{category}
- 超支金额：¥{overspent_amount:.0f}{reason_text}{sources_text}

要求：
1. 语气理解、支持，不指责
2. 如果有可调拨来源，建议调拨方案
3. 如果没有，建议下月补上或调整预算
4. 30-60字
5. 可以适当使用emoji

请直接输出建议文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=200,
                temperature=0.8,
            )
            return response.strip()
        except Exception as e:
            logger.error(f"Failed to generate overspending advice: {e}")
            # 降级方案
            if available_sources and len(available_sources) > 0:
                source = available_sources[0]
                return f"{category}超支 ¥{overspent_amount:.0f}{reason_text}。可以从{source['name']}（还剩¥{source['remaining']:.0f}）调拨，要帮你设置吗？"
            else:
                return f"{category}超支 ¥{overspent_amount:.0f}{reason_text}。别担心，下个月我们一起调整预算～"

    async def generate_money_age_advice(
        self,
        current_age: float,
        target_age: float,
        improvement_opportunities: Optional[List[Dict[str, Any]]] = None,
    ) -> str:
        """生成钱龄提升建议"""
        gap = target_age - current_age
        opportunities_text = ""
        if improvement_opportunities:
            opportunities_text = "\n改善机会：\n" + "\n".join(
                [f"- {o['description']}" for o in improvement_opportunities[:2]]
            )

        prompt = f"""你是一个温暖、专业的理财助手。用户想提升钱龄，请生成一条建议。

当前情况：
- 当前钱龄：{current_age:.0f}天
- 目标钱龄：{target_age:.0f}天
- 差距：{gap:.0f}天{opportunities_text}

要求：
1. 语气鼓励、积极
2. 提供1-2个具体可行的改善方法
3. 如果有改善机会，重点说明
4. 40-60字
5. 可以适当使用emoji

请直接输出建议文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=200,
                temperature=0.8,
            )
            return response.strip()
        except Exception as e:
            logger.error(f"Failed to generate money age advice: {e}")
            # 降级方案
            return f"钱龄目前 {current_age:.0f}天，离目标差{gap:.0f}天。推迟大额消费到发工资后，可以有效提升钱龄～"

    async def generate_savings_advice(
        self,
        monthly_income: float,
        monthly_expense: float,
        current_savings_rate: float,
        target_savings_rate: float = 0.2,
    ) -> str:
        """生成储蓄建议"""
        current_savings = monthly_income * current_savings_rate
        target_savings = monthly_income * target_savings_rate
        gap = target_savings - current_savings

        prompt = f"""你是一个温暖、专业的理财助手。用户想提高储蓄率，请生成一条建议。

当前情况：
- 月收入：¥{monthly_income:.0f}
- 月支出：¥{monthly_expense:.0f}
- 当前储蓄率：{current_savings_rate*100:.0f}%（¥{current_savings:.0f}）
- 目标储蓄率：{target_savings_rate*100:.0f}%（¥{target_savings:.0f}）
- 需要增加：¥{gap:.0f}

要求：
1. 语气鼓励、实用
2. 提供1-2个具体可行的储蓄方法
3. 不要说教，要有同理心
4. 40-60字
5. 可以适当使用emoji

请直接输出建议文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=200,
                temperature=0.8,
            )
            return response.strip()
        except Exception as e:
            logger.error(f"Failed to generate savings advice: {e}")
            # 降级方案
            return f"当前储蓄率{current_savings_rate*100:.0f}%，建议提升到{target_savings_rate*100:.0f}%。每月多存¥{gap:.0f}，可以从减少非必要支出开始～"

    async def generate_category_insight(
        self,
        category: str,
        current_amount: float,
        average_amount: float,
        trend: str,  # 'increasing', 'decreasing', 'stable'
        percentage_change: float,
    ) -> str:
        """生成分类消费洞察"""
        trend_text = {
            'increasing': '增长',
            'decreasing': '下降',
            'stable': '保持稳定',
        }.get(trend, '变化')

        prompt = f"""你是一个温暖、专业的理财助手。用户的{category}消费有变化，请生成一条洞察。

当前情况：
- 分类：{category}
- 本月消费：¥{current_amount:.0f}
- 平均消费：¥{average_amount:.0f}
- 趋势：{trend_text}
- 变化幅度：{abs(percentage_change):.0f}%

要求：
1. 语气客观、友好
2. 指出变化趋势和可能原因
3. 如果增长明显，提供控制建议
4. 如果下降，给予肯定
5. 30-50字
6. 可以适当使用emoji

请直接输出洞察文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=150,
                temperature=0.8,
            )
            return response.strip()
        except Exception as e:
            logger.error(f"Failed to generate category insight: {e}")
            # 降级方案
            if trend == 'increasing':
                return f"本月{category}支出¥{current_amount:.0f}，比平均水平高{abs(percentage_change):.0f}%。建议关注一下消费频率～"
            elif trend == 'decreasing':
                return f"本月{category}支出¥{current_amount:.0f}，比平均水平低{abs(percentage_change):.0f}%。做得很好，继续保持！"
            else:
                return f"本月{category}支出¥{current_amount:.0f}，保持稳定。财务管理得不错～"

    async def generate_achievement_description(
        self,
        achievement_type: str,
        achievement_data: Dict[str, Any],
    ) -> str:
        """生成成就描述"""
        prompt = f"""你是一个温暖、热情的理财助手。用户达成了一个成就，请生成一条庆祝文案。

成就类型：{achievement_type}
成就数据：{achievement_data}

要求：
1. 语气热情、庆祝
2. 包含具体数字
3. 给予肯定和鼓励
4. 20-40字
5. 使用庆祝emoji

请直接输出庆祝文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=150,
                temperature=0.9,
            )
            return response.strip()
        except Exception as e:
            logger.error(f"Failed to generate achievement description: {e}")
            # 降级方案
            return f"恭喜达成{achievement_type}成就！继续加油！🎉"

    async def generate_batch_advice(
        self,
        advice_requests: List[Dict[str, Any]],
    ) -> List[str]:
        """批量生成建议（提高效率）"""
        tasks = []
        for request in advice_requests:
            advice_type = request.get('type')
            if advice_type == 'budget_warning':
                task = self.generate_budget_warning_advice(**request.get('params', {}))
            elif advice_type == 'overspending':
                task = self.generate_overspending_advice(**request.get('params', {}))
            elif advice_type == 'money_age':
                task = self.generate_money_age_advice(**request.get('params', {}))
            elif advice_type == 'savings':
                task = self.generate_savings_advice(**request.get('params', {}))
            elif advice_type == 'category_insight':
                task = self.generate_category_insight(**request.get('params', {}))
            elif advice_type == 'achievement':
                task = self.generate_achievement_description(**request.get('params', {}))
            else:
                task = asyncio.sleep(0)  # 占位
            tasks.append(task)

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # 处理异常
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"Failed to generate advice {i}: {result}")
                processed_results.append("建议生成失败，请稍后重试")
            else:
                processed_results.append(result)

        return processed_results
