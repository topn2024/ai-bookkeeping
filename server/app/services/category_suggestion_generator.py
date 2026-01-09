"""分类建议AI生成服务"""
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime

from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class CategorySuggestionGenerator:
    """分类建议AI生成器"""

    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service

    async def suggest_category(
        self,
        description: str,
        amount: float,
        merchant: Optional[str] = None,
        time: Optional[datetime] = None,
        location: Optional[str] = None,
        user_history: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        """基于多维度信息建议分类"""

        # 构建上下文
        context_parts = [f"交易描述：{description}", f"金额：¥{amount:.2f}"]

        if merchant:
            context_parts.append(f"商户：{merchant}")

        if time:
            hour = time.hour
            time_period = "早餐" if 6 <= hour < 9 else "午餐" if 11 <= hour < 14 else "晚餐" if 17 <= hour < 21 else "其他"
            context_parts.append(f"时间：{time.strftime('%H:%M')} ({time_period})")

        if location:
            context_parts.append(f"地点：{location}")

        # 用户历史模式
        history_text = ""
        if user_history:
            history_text = "\n\n用户历史分类习惯：\n" + "\n".join(
                [f"- {h['description']} → {h['category']}" for h in user_history[:5]]
            )

        prompt = f"""你是一个专业的记账分类助手。请根据交易信息推荐最合适的分类。

交易信息：
{chr(10).join(context_parts)}{history_text}

常见分类：
- 餐饮：外卖、餐厅、食堂、零食、饮料
- 交通：打车、公交、地铁、加油、停车
- 购物：服装、日用品、电子产品、家居
- 娱乐：电影、游戏、旅游、健身
- 医疗：看病、买药、体检
- 教育：培训、书籍、课程
- 住房：房租、物业、水电
- 通讯：话费、宽带、流量
- 其他：不确定的分类

要求：
1. 返回JSON格式：{{"category": "分类名", "confidence": 0.95, "reason": "推荐理由"}}
2. confidence是置信度(0-1)
3. reason简短说明推荐理由(10-20字)

请直接输出JSON，不需要其他内容。"""

        try:
            response = await self.llm_service.generate(
                prompt=prompt,
                max_tokens=150,
                temperature=0.3,  # 低温度保证稳定性
            )

            # 解析JSON
            import json
            result = json.loads(response.strip())

            return {
                'category': result.get('category', '其他'),
                'confidence': result.get('confidence', 0.5),
                'reason': result.get('reason', '基于交易信息推荐'),
            }

        except Exception as e:
            logger.error(f"Failed to suggest category: {e}")
            # 降级方案：基于规则
            return self._rule_based_suggestion(description, amount, merchant)

    def _rule_based_suggestion(
        self,
        description: str,
        amount: float,
        merchant: Optional[str] = None,
    ) -> Dict[str, Any]:
        """基于规则的降级方案"""
        desc_lower = description.lower()
        merchant_lower = (merchant or "").lower()

        # 餐饮关键词
        if any(kw in desc_lower or kw in merchant_lower for kw in
               ['餐', '饭', '外卖', '美团', '饿了么', '食', '咖啡', '奶茶', '麦当劳', '肯德基']):
            return {'category': '餐饮', 'confidence': 0.8, 'reason': '包含餐饮关键词'}

        # 交通关键词
        if any(kw in desc_lower or kw in merchant_lower for kw in
               ['打车', '滴滴', '出租', '公交', '地铁', '加油', '停车', '高速']):
            return {'category': '交通', 'confidence': 0.8, 'reason': '包含交通关键词'}

        # 购物关键词
        if any(kw in desc_lower or kw in merchant_lower for kw in
               ['淘宝', '京东', '拼多多', '超市', '商场', '购物', '衣服', '鞋']):
            return {'category': '购物', 'confidence': 0.8, 'reason': '包含购物关键词'}

        # 娱乐关键词
        if any(kw in desc_lower or kw in merchant_lower for kw in
               ['电影', '游戏', 'steam', '健身', '旅游', 'ktv']):
            return {'category': '娱乐', 'confidence': 0.8, 'reason': '包含娱乐关键词'}

        # 医疗关键词
        if any(kw in desc_lower or kw in merchant_lower for kw in
               ['医院', '药店', '体检', '看病', '挂号']):
            return {'category': '医疗', 'confidence': 0.8, 'reason': '包含医疗关键词'}

        # 默认
        return {'category': '其他', 'confidence': 0.3, 'reason': '无法确定分类'}

    async def suggest_batch(
        self,
        transactions: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        """批量建议分类"""
        import asyncio

        tasks = [
            self.suggest_category(
                description=t.get('description', ''),
                amount=t.get('amount', 0),
                merchant=t.get('merchant'),
                time=t.get('time'),
                location=t.get('location'),
                user_history=t.get('user_history'),
            )
            for t in transactions
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # 处理异常
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"Failed to suggest category for transaction {i}: {result}")
                processed_results.append({
                    'category': '其他',
                    'confidence': 0.0,
                    'reason': '分类失败',
                })
            else:
                processed_results.append(result)

        return processed_results

    async def learn_from_correction(
        self,
        transaction_id: str,
        suggested_category: str,
        actual_category: str,
        description: str,
        amount: float,
    ) -> None:
        """从用户纠正中学习（用于未来优化）"""
        # 这里可以记录到数据库，用于后续模型微调
        logger.info(
            f"Category correction: {suggested_category} -> {actual_category} "
            f"for '{description}' (¥{amount})"
        )
        # TODO: 存储到学习数据库
