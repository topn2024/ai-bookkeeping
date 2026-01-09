"""储蓄建议生成器、成就描述生成器、年度报告生成器"""
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime

from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class SavingsAdviceGenerator:
    """储蓄建议生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_savings_plan(
        self,
        goal_name: str,
        target_amount: float,
        current_amount: float,
        deadline: datetime,
        monthly_income: float,
        monthly_expense: float,
    ) -> Dict[str, Any]:
        """生成储蓄计划"""

        remaining = target_amount - current_amount
        months_left = max(1, (deadline - datetime.now()).days // 30)
        monthly_needed = remaining / months_left
        disposable_income = monthly_income - monthly_expense

        prompt = f"""你是一个专业的理财规划师。请为用户制定储蓄计划。

储蓄目标：
- 目标名称：{goal_name}
- 目标金额：¥{target_amount:.0f}
- 已存金额：¥{current_amount:.0f}
- 还需存入：¥{remaining:.0f}
- 剩余时间：{months_left}个月
- 每月需存：¥{monthly_needed:.0f}

用户财务状况：
- 月收入：¥{monthly_income:.0f}
- 月支出：¥{monthly_expense:.0f}
- 可支配收入：¥{disposable_income:.0f}

要求：
1. 评估目标可行性
2. 提供具体的储蓄方案
3. 如果目标过高，建议调整
4. 返回JSON格式：
{{
  "feasibility": "可行/困难/不可行",
  "monthly_savings": 1000,
  "savings_rate": 0.2,
  "strategies": ["策略1", "策略2"],
  "timeline_adjustment": "如需调整期限的建议",
  "motivation": "鼓励的话"
}}

请直接输出JSON，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=500,
                temperature=0.6,
            )

            import json
            return json.loads(response.strip())

        except Exception as e:
            logger.error(f"Failed to generate savings plan: {e}")
            # 降级方案
            feasibility = "可行" if monthly_needed <= disposable_income * 0.5 else "困难" if monthly_needed <= disposable_income else "不可行"

            return {
                'feasibility': feasibility,
                'monthly_savings': min(monthly_needed, disposable_income * 0.5),
                'savings_rate': min(monthly_needed / monthly_income, 0.5),
                'strategies': [
                    f'每月固定存入¥{monthly_needed:.0f}',
                    '减少非必要支出',
                    '寻找额外收入来源',
                ],
                'timeline_adjustment': f'建议延长{int(monthly_needed / (disposable_income * 0.3))}个月' if feasibility == '不可行' else '',
                'motivation': f'坚持{months_left}个月，{goal_name}就能实现！',
            }


class AchievementDescriptionGenerator:
    """成就描述生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_description(
        self,
        achievement_type: str,
        achievement_data: Dict[str, Any],
        user_name: Optional[str] = None,
    ) -> str:
        """生成成就描述"""

        user_prefix = f"{user_name}，" if user_name else ""

        prompt = f"""你是一个热情的理财助手。用户达成了一个成就，请生成庆祝文案。

成就类型：{achievement_type}
成就数据：{achievement_data}

要求：
1. 语气热情、庆祝
2. 包含具体数字和成就内容
3. 给予真诚的肯定和鼓励
4. 20-40字
5. 使用1-2个庆祝emoji
6. 可以称呼用户为"{user_prefix}"

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
            return f"{user_prefix}恭喜达成{achievement_type}成就！继续加油！🎉"


class AnnualReportGenerator:
    """年度报告生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_summary(
        self,
        year: int,
        total_income: float,
        total_expense: float,
        category_breakdown: Dict[str, float],
        highlights: List[str],
        user_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """生成年度总结"""

        savings = total_income - total_expense
        savings_rate = savings / total_income if total_income > 0 else 0

        # 找出最大支出分类
        top_category = max(category_breakdown.items(), key=lambda x: x[1]) if category_breakdown else ('其他', 0)

        user_prefix = f"{user_name}的" if user_name else "您的"

        prompt = f"""你是一个温暖、专业的理财顾问。请为用户生成{year}年度财务总结。

年度数据：
- 总收入：¥{total_income:.0f}
- 总支出：¥{total_expense:.0f}
- 总储蓄：¥{savings:.0f}
- 储蓄率：{savings_rate*100:.1f}%
- 最大支出：{top_category[0]} ¥{top_category[1]:.0f}

支出分布：
{chr(10).join([f"- {cat}: ¥{amt:.0f} ({amt/total_expense*100:.1f}%)" for cat, amt in sorted(category_breakdown.items(), key=lambda x: x[1], reverse=True)[:5]])}

年度亮点：
{chr(10).join([f"- {h}" for h in highlights])}

要求：
1. 生成温暖、个性化的年度总结
2. 指出亮点和改进空间
3. 提供下一年的建议
4. 返回JSON格式：
{{
  "title": "年度总结标题",
  "summary": "总体评价(50-80字)",
  "highlights_text": "亮点总结(30-50字)",
  "improvements": ["改进建议1", "改进建议2"],
  "next_year_goals": ["目标1", "目标2"],
  "closing": "结束语(20-30字)"
}}

请直接输出JSON，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=800,
                temperature=0.7,
            )

            import json
            return json.loads(response.strip())

        except Exception as e:
            logger.error(f"Failed to generate annual summary: {e}")
            # 降级方案
            return {
                'title': f'{user_prefix}{year}年财务回顾',
                'summary': f'{year}年{user_prefix}总收入¥{total_income:.0f}，总支出¥{total_expense:.0f}，储蓄率{savings_rate*100:.1f}%。',
                'highlights_text': f'全年坚持记账，{top_category[0]}是最大支出项。',
                'improvements': [
                    f'建议控制{top_category[0]}支出' if savings_rate < 0.1 else '继续保持良好的储蓄习惯',
                    '定期回顾预算执行情况',
                ],
                'next_year_goals': [
                    f'储蓄率提升到{min(savings_rate + 0.05, 0.3)*100:.0f}%',
                    '养成每日记账习惯',
                ],
                'closing': f'{year+1}年，让我们一起实现更好的财务目标！',
            }

    async def generate_category_insight(
        self,
        category: str,
        year: int,
        monthly_data: List[float],
        year_total: float,
        comparison_data: Optional[Dict[str, Any]] = None,
    ) -> str:
        """生成分类洞察"""

        avg_monthly = year_total / 12
        max_month = max(enumerate(monthly_data), key=lambda x: x[1])
        min_month = min(enumerate(monthly_data), key=lambda x: x[1])

        comparison_text = ""
        if comparison_data:
            comparison_text = f"\n与去年对比：{comparison_data.get('trend', '持平')}"

        prompt = f"""你是一个专业的数据分析师。请为用户的{category}支出生成洞察。

{year}年{category}支出：
- 全年总计：¥{year_total:.0f}
- 月均支出：¥{avg_monthly:.0f}
- 最高月份：{max_month[0]+1}月 ¥{max_month[1]:.0f}
- 最低月份：{min_month[0]+1}月 ¥{min_month[1]:.0f}{comparison_text}

要求：
1. 分析消费趋势和特点
2. 指出异常月份的可能原因
3. 提供优化建议
4. 30-60字
5. 语气客观、友好

请直接输出洞察文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=200,
                temperature=0.7,
            )
            return response.strip()

        except Exception as e:
            logger.error(f"Failed to generate category insight: {e}")
            return f'{year}年{category}支出¥{year_total:.0f}，月均¥{avg_monthly:.0f}。{max_month[0]+1}月支出最高，建议关注消费频率。'
