"""地理位置建议生成器和账单提醒生成器"""
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta

from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class LocationBasedAdviceGenerator:
    """地理位置建议生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_location_insight(
        self,
        location_name: str,
        spending_data: Dict[str, Any],
        nearby_alternatives: Optional[List[Dict[str, Any]]] = None,
    ) -> str:
        """生成地理位置消费洞察"""

        total_spent = spending_data.get('total', 0)
        visit_count = spending_data.get('visits', 0)
        avg_per_visit = total_spent / visit_count if visit_count > 0 else 0
        categories = spending_data.get('categories', {})

        alternatives_text = ""
        if nearby_alternatives:
            alternatives_text = "\n\n附近替代选择：\n" + "\n".join(
                [f"- {alt['name']}: {alt.get('description', '')} (距离{alt.get('distance', 0)}米)"
                 for alt in nearby_alternatives[:3]]
            )

        prompt = f"""你是一个专业的消费顾问。请分析用户在特定地点的消费模式并提供建议。

地点信息：
- 地点名称：{location_name}
- 总消费：¥{total_spent:.0f}
- 访问次数：{visit_count}次
- 单次平均：¥{avg_per_visit:.0f}
- 消费分类：{', '.join([f'{k}¥{v:.0f}' for k, v in categories.items()])}{alternatives_text}

要求：
1. 分析消费特点
2. 如果消费较高，提供节省建议
3. 如果有替代选择，适当推荐
4. 40-80字
5. 语气友好、实用

请直接输出建议，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=250,
                temperature=0.7,
            )
            return response.strip()

        except Exception as e:
            logger.error(f"Failed to generate location insight: {e}")
            # 降级方案
            if nearby_alternatives:
                alt = nearby_alternatives[0]
                return f"在{location_name}已消费¥{total_spent:.0f}（{visit_count}次）。附近{alt['name']}可能更实惠，距离{alt.get('distance', 0)}米～"
            else:
                return f"在{location_name}已消费¥{total_spent:.0f}（{visit_count}次），单次平均¥{avg_per_visit:.0f}。"

    async def generate_high_spending_area_alert(
        self,
        area_name: str,
        spending_amount: float,
        time_period: str,
        impact_on_budget: Dict[str, Any],
    ) -> str:
        """生成高消费区域提醒"""

        budget_impact = impact_on_budget.get('percentage', 0)
        affected_categories = impact_on_budget.get('categories', [])

        prompt = f"""你是一个温暖的理财助手。用户在某个区域消费较多，请生成友好的提醒。

消费情况：
- 区域：{area_name}
- 消费金额：¥{spending_amount:.0f}
- 时间段：{time_period}
- 占预算比例：{budget_impact:.1f}%
- 影响分类：{', '.join(affected_categories)}

要求：
1. 语气友好、不指责
2. 指出消费特点
3. 提供1-2个实用建议
4. 30-50字
5. 可以使用emoji

请直接输出提醒文案，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=200,
                temperature=0.7,
            )
            return response.strip()

        except Exception as e:
            logger.error(f"Failed to generate high spending area alert: {e}")
            return f"{time_period}在{area_name}消费¥{spending_amount:.0f}，占预算{budget_impact:.1f}%。建议适当控制～"


class BillReminderGenerator:
    """账单提醒生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def generate_reminder(
        self,
        bill_type: str,
        bill_name: str,
        amount: float,
        due_date: datetime,
        account_balance: Optional[float] = None,
    ) -> Dict[str, Any]:
        """生成账单提醒"""

        days_until_due = (due_date - datetime.now()).days
        urgency = "紧急" if days_until_due <= 3 else "重要" if days_until_due <= 7 else "提醒"

        balance_text = ""
        if account_balance is not None:
            balance_text = f"\n当前余额：¥{account_balance:.0f}"
            if account_balance < amount:
                balance_text += "（余额不足）"

        prompt = f"""你是一个贴心的账单管家。请生成账单提醒文案。

账单信息：
- 类型：{bill_type}
- 名称：{bill_name}
- 金额：¥{amount:.0f}
- 到期日：{due_date.strftime('%Y-%m-%d')}
- 剩余天数：{days_until_due}天
- 紧急程度：{urgency}{balance_text}

要求：
1. 根据紧急程度调整语气
2. 如果余额不足，提醒充值
3. 提供还款建议
4. 返回JSON格式：
{{
  "title": "提醒标题",
  "message": "提醒内容(30-50字)",
  "urgency_level": "high/medium/low",
  "action_text": "操作按钮文案",
  "tips": "小贴士(可选)"
}}

请直接输出JSON，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=300,
                temperature=0.6,
            )

            import json
            return json.loads(response.strip())

        except Exception as e:
            logger.error(f"Failed to generate bill reminder: {e}")
            # 降级方案
            urgency_level = "high" if days_until_due <= 3 else "medium" if days_until_due <= 7 else "low"

            if account_balance is not None and account_balance < amount:
                message = f"{bill_name}将在{days_until_due}天后到期，需支付¥{amount:.0f}。当前余额不足，请及时充值～"
            else:
                message = f"{bill_name}将在{days_until_due}天后到期，需支付¥{amount:.0f}。记得按时还款哦～"

            return {
                'title': f'{bill_type}账单提醒',
                'message': message,
                'urgency_level': urgency_level,
                'action_text': '立即还款' if urgency_level == 'high' else '查看详情',
                'tips': '按时还款可避免逾期费用' if urgency_level != 'low' else '',
            }

    async def generate_repayment_strategy(
        self,
        bills: List[Dict[str, Any]],
        available_amount: float,
    ) -> Dict[str, Any]:
        """生成还款策略"""

        total_due = sum(bill['amount'] for bill in bills)
        shortage = max(0, total_due - available_amount)

        bills_text = "\n".join([
            f"- {bill['name']}: ¥{bill['amount']:.0f} (到期{bill['days_until_due']}天)"
            for bill in bills
        ])

        prompt = f"""你是一个专业的债务管理顾问。请为用户制定还款策略。

账单情况：
{bills_text}
- 总计：¥{total_due:.0f}
- 可用金额：¥{available_amount:.0f}
- 缺口：¥{shortage:.0f}

要求：
1. 如果资金充足，建议全部还款
2. 如果资金不足，按紧急程度排序
3. 提供具体的还款顺序和金额
4. 返回JSON格式：
{{
  "strategy": "全额还款/优先还款/分期还款",
  "repayment_order": [
    {{"bill": "账单名", "amount": 1000, "reason": "原因"}},
    ...
  ],
  "shortage_solution": "资金不足的解决方案",
  "tips": ["建议1", "建议2"]
}}

请直接输出JSON，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=600,
                temperature=0.5,
            )

            import json
            return json.loads(response.strip())

        except Exception as e:
            logger.error(f"Failed to generate repayment strategy: {e}")
            # 降级方案
            if shortage == 0:
                return {
                    'strategy': '全额还款',
                    'repayment_order': [
                        {'bill': bill['name'], 'amount': bill['amount'], 'reason': '按时还款'}
                        for bill in bills
                    ],
                    'shortage_solution': '',
                    'tips': ['建议设置自动还款', '保持良好信用记录'],
                }
            else:
                # 按到期时间排序
                sorted_bills = sorted(bills, key=lambda x: x['days_until_due'])
                return {
                    'strategy': '优先还款',
                    'repayment_order': [
                        {'bill': bill['name'], 'amount': min(bill['amount'], available_amount), 'reason': f'{bill["days_until_due"]}天后到期'}
                        for bill in sorted_bills
                    ],
                    'shortage_solution': f'还需¥{shortage:.0f}，建议临时调拨或申请延期',
                    'tips': ['优先还最紧急的账单', '避免逾期产生额外费用'],
                }
