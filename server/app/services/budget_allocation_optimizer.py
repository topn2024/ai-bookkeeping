"""预算分配优化器"""
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime

from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class BudgetAllocationOptimizer:
    """预算分配智能优化器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def optimize_allocation(
        self,
        monthly_income: float,
        historical_expenses: Dict[str, float],
        financial_goals: Optional[List[Dict[str, Any]]] = None,
        user_preferences: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """优化预算分配方案"""

        # 计算历史平均支出
        total_historical = sum(historical_expenses.values())
        expense_ratios = {
            cat: amount / total_historical if total_historical > 0 else 0
            for cat, amount in historical_expenses.items()
        }

        # 构建目标描述
        goals_text = ""
        if financial_goals:
            goals_text = "\n\n财务目标：\n" + "\n".join(
                [f"- {g['name']}: {g.get('description', '')}" for g in financial_goals]
            )

        # 构建偏好描述
        prefs_text = ""
        if user_preferences:
            prefs_text = "\n\n用户偏好：\n" + "\n".join(
                [f"- {k}: {v}" for k, v in user_preferences.items()]
            )

        prompt = f"""你是一个专业的理财规划师。请为用户优化月度预算分配方案。

用户情况：
- 月收入：¥{monthly_income:.0f}
- 历史月均支出：¥{total_historical:.0f}

历史支出分布：
{chr(10).join([f"- {cat}: ¥{amt:.0f} ({expense_ratios[cat]*100:.1f}%)" for cat, amt in historical_expenses.items()])}{goals_text}{prefs_text}

要求：
1. 参考50/30/20法则（50%必需、30%想要、20%储蓄），但根据实际情况调整
2. 考虑用户历史消费习惯
3. 如果有财务目标，优先保证储蓄
4. 返回JSON格式：
{{
  "allocations": {{
    "必需支出": {{"amount": 5000, "categories": ["餐饮", "交通", "住房"]}},
    "弹性支出": {{"amount": 3000, "categories": ["购物", "娱乐"]}},
    "储蓄": {{"amount": 2000, "categories": ["应急基金", "目标储蓄"]}}
  }},
  "category_budgets": {{
    "餐饮": 1500,
    "交通": 800,
    ...
  }},
  "reasoning": "分配理由说明",
  "tips": ["建议1", "建议2"]
}}

请直接输出JSON，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=800,
                temperature=0.5,
            )

            import json
            result = json.loads(response.strip())

            return result

        except Exception as e:
            logger.error(f"Failed to optimize allocation: {e}")
            # 降级方案：基于50/30/20法则
            return self._rule_based_allocation(monthly_income, historical_expenses)

    def _rule_based_allocation(
        self,
        monthly_income: float,
        historical_expenses: Dict[str, float],
    ) -> Dict[str, Any]:
        """基于规则的降级方案"""

        # 50/30/20法则
        needs_budget = monthly_income * 0.5
        wants_budget = monthly_income * 0.3
        savings_budget = monthly_income * 0.2

        # 分类映射
        needs_categories = ['餐饮', '交通', '住房', '医疗', '通讯']
        wants_categories = ['购物', '娱乐', '教育']

        # 计算各分类预算
        category_budgets = {}

        # 必需支出按历史比例分配
        needs_total = sum(historical_expenses.get(cat, 0) for cat in needs_categories)
        for cat in needs_categories:
            if needs_total > 0:
                ratio = historical_expenses.get(cat, 0) / needs_total
                category_budgets[cat] = needs_budget * ratio
            else:
                category_budgets[cat] = needs_budget / len(needs_categories)

        # 弹性支出按历史比例分配
        wants_total = sum(historical_expenses.get(cat, 0) for cat in wants_categories)
        for cat in wants_categories:
            if wants_total > 0:
                ratio = historical_expenses.get(cat, 0) / wants_total
                category_budgets[cat] = wants_budget * ratio
            else:
                category_budgets[cat] = wants_budget / len(wants_categories)

        return {
            'allocations': {
                '必需支出': {
                    'amount': needs_budget,
                    'categories': needs_categories,
                },
                '弹性支出': {
                    'amount': wants_budget,
                    'categories': wants_categories,
                },
                '储蓄': {
                    'amount': savings_budget,
                    'categories': ['应急基金', '目标储蓄'],
                },
            },
            'category_budgets': category_budgets,
            'reasoning': '基于50/30/20法则和历史消费习惯分配',
            'tips': [
                f'建议储蓄{savings_budget:.0f}元（20%收入）',
                '必需支出控制在50%以内',
                '弹性支出适度控制',
            ],
        }

    async def suggest_adjustment(
        self,
        current_allocation: Dict[str, float],
        actual_spending: Dict[str, float],
        days_remaining: int,
    ) -> str:
        """建议预算调整"""

        # 计算超支和结余
        overspent = {}
        surplus = {}
        for category, budget in current_allocation.items():
            spent = actual_spending.get(category, 0)
            diff = budget - spent
            if diff < 0:
                overspent[category] = abs(diff)
            elif diff > budget * 0.3:  # 结余超过30%
                surplus[category] = diff

        if not overspent and not surplus:
            return "预算执行良好，继续保持！"

        # 构建调整建议
        overspent_text = ""
        if overspent:
            overspent_text = "\n超支分类：\n" + "\n".join(
                [f"- {cat}: 超支¥{amt:.0f}" for cat, amt in overspent.items()]
            )

        surplus_text = ""
        if surplus:
            surplus_text = "\n结余分类：\n" + "\n".join(
                [f"- {cat}: 结余¥{amt:.0f}" for cat, amt in surplus.items()]
            )

        prompt = f"""你是一个专业的理财顾问。用户的预算执行有偏差，请提供调整建议。

当前情况：
- 剩余天数：{days_remaining}天{overspent_text}{surplus_text}

要求：
1. 如果有超支，建议从结余分类调拨
2. 如果没有结余，建议下月调整预算
3. 语气友好、实用
4. 30-60字

请直接输出建议，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=200,
                temperature=0.7,
            )
            return response.strip()

        except Exception as e:
            logger.error(f"Failed to suggest adjustment: {e}")
            # 降级方案
            if overspent and surplus:
                surplus_cat = list(surplus.keys())[0]
                overspent_cat = list(overspent.keys())[0]
                return f"建议从{surplus_cat}（结余¥{surplus[surplus_cat]:.0f}）调拨到{overspent_cat}，平衡预算～"
            elif overspent:
                return "部分分类超支，建议下月适当增加预算或控制消费～"
            else:
                return "预算执行良好，部分分类有结余，可以考虑增加储蓄～"
