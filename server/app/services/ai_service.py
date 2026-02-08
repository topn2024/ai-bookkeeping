"""AI service for image/text recognition.

Uses Qwen (通义千问) as primary AI provider for all parsing tasks.
Zhipu (智谱) serves as fallback when Qwen is unavailable.
"""
import re
import json
import base64
import logging
from decimal import Decimal
from typing import Optional
import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class AIService:
    """AI service for recognizing transactions from images and text.

    Primary: Qwen (通义千问) - for image recognition, text parsing, and bill parsing
    Fallback: Zhipu (智谱 GLM) - when Qwen API fails
    """

    def __init__(self):
        self.qwen_api_key = settings.QWEN_API_KEY
        self.zhipu_api_key = settings.ZHIPU_API_KEY

        # Qwen API endpoints
        self.qwen_vl_url = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        self.qwen_text_url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

        # Zhipu API endpoint (fallback)
        self.zhipu_url = "https://open.bigmodel.cn/api/paas/v4/chat/completions"

        # Shared httpx client for connection reuse
        self._client = httpx.AsyncClient(
            timeout=30.0,
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )

    async def close(self):
        """Close the shared httpx client."""
        await self._client.aclose()

    async def recognize_image(self, image_content: bytes) -> dict:
        """Recognize transaction from receipt/bill image using Qwen VL."""
        # Encode image to base64
        image_base64 = base64.b64encode(image_content).decode("utf-8")

        # Use Qwen VL for image understanding
        prompt = """请分析这张图片（小票/收据/账单），提取以下信息：
1. 消费金额（数字）
2. 商户名称
3. 消费类型（餐饮/交通/购物/娱乐/住房/医疗/教育/其他）
4. 消费日期
5. 商品明细摘要

请以JSON格式返回，格式如下：
{
    "amount": 金额数字,
    "merchant": "商户名称",
    "category": "消费类型",
    "date": "日期",
    "note": "商品明细摘要"
}

如果无法识别某项，请设为null。"""

        try:
            response = await self._client.post(
                "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
                headers={
                    "Authorization": f"Bearer {self.qwen_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "qwen-vl-plus",
                    "input": {
                        "messages": [
                            {
                                "role": "user",
                                "content": [
                                    {"image": f"data:image/jpeg;base64,{image_base64}"},
                                    {"text": prompt}
                                ]
                            }
                        ]
                    }
                },
                timeout=30.0,
            )

            if response.status_code == 200:
                result = response.json()
                text = result.get("output", {}).get("choices", [{}])[0].get("message", {}).get("content", "")
                return self._parse_ai_response(text)
            else:
                return self._empty_result()

        except Exception as e:
            logger.error(f"AI recognition error: {e}", exc_info=True)
            return self._empty_result()

    async def recognize_image_batch(self, image_content: bytes) -> list[dict]:
        """Recognize multiple transactions from a long image (e.g., bill screenshot).

        This method is designed for long images that may contain multiple transaction records,
        such as bank statements, credit card bills, or payment history screenshots.

        Args:
            image_content: Image bytes

        Returns:
            List of transaction dictionaries
        """
        # Encode image to base64
        image_base64 = base64.b64encode(image_content).decode("utf-8")

        # Enhanced prompt for multiple transactions
        prompt = """请分析这张图片，这可能是一张包含多条交易记录的长图（如账单截图、银行流水、支付记录等）。

请识别图片中的所有交易记录，对每条交易提取：
1. 消费金额（数字）
2. 商户名称或交易描述
3. 消费类型（餐饮/交通/购物/娱乐/住房/医疗/教育/转账/其他）
4. 交易日期和时间
5. 交易类型（支出/收入）

请以JSON数组格式返回所有交易，格式如下：
{
    "transactions": [
        {
            "amount": 金额数字,
            "merchant": "商户名称或描述",
            "category": "消费类型",
            "date": "日期时间",
            "type": "expense或income",
            "note": "备注说明"
        },
        ...
    ],
    "total_count": 交易总数
}

注意：
- 如果只有一条交易，也返回数组格式
- 按时间顺序排列（最新的在前）
- 如果某项无法识别，设为null
- 忽略余额、总计等非交易信息"""

        try:
            response = await self._client.post(
                "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
                headers={
                    "Authorization": f"Bearer {self.qwen_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "qwen-vl-plus",
                    "input": {
                        "messages": [
                            {
                                "role": "user",
                                "content": [
                                    {"image": f"data:image/jpeg;base64,{image_base64}"},
                                    {"text": prompt}
                                ]
                            }
                        ]
                    }
                },
                timeout=60.0,  # Longer timeout for long images
            )

            if response.status_code == 200:
                result = response.json()
                text = result.get("output", {}).get("choices", [{}])[0].get("message", {}).get("content", "")
                return self._parse_batch_response(text)
            else:
                logger.error(f"Batch recognition failed: {response.status_code}")
                return []

        except Exception as e:
            logger.error(f"Batch AI recognition error: {e}", exc_info=True)
            return []

    async def parse_voice_text(self, text: str) -> dict:
        """Parse transaction from voice/text input.

        Primary: Qwen (通义千问)
        Fallback: Zhipu (智谱) -> Simple regex parsing
        """
        prompt = f"""请分析以下记账语音/文字，提取交易信息：

"{text}"

请提取：
1. 金额（数字）
2. 消费类型（餐饮/交通/购物/娱乐/住房/医疗/教育/工资/奖金/兼职/理财/其他）
3. 是支出还是收入（expense/income）
4. 备注描述

请以JSON格式返回：
{{
    "amount": 金额数字,
    "category": "消费类型",
    "type": "expense或income",
    "note": "备注"
}}"""

        # Try Qwen first (primary)
        try:
            result = await self._call_qwen_text(prompt)
            if result:
                return self._parse_ai_response(result, is_voice=True)
        except Exception as e:
            logger.warning(f"Qwen text parsing failed: {e}")

        # Fallback to Zhipu
        try:
            result = await self._call_zhipu_text(prompt)
            if result:
                return self._parse_ai_response(result, is_voice=True)
        except Exception as e:
            logger.warning(f"Zhipu text parsing failed: {e}")

        # Final fallback to simple parsing
        return self._simple_parse(text)

    async def recognize_voice_audio(self, audio_content: bytes, audio_format: str = "mp3") -> dict:
        """Recognize transaction from audio using Qwen-Omni-Turbo.

        This method directly processes audio without pre-transcription,
        using Qwen's multimodal understanding capability for better accuracy.

        Note: qwen-audio-turbo is a preview version with limited free quota.
        qwen-omni-turbo is recommended for production use.

        Args:
            audio_content: Raw audio bytes
            audio_format: Audio format (mp3, wav, aac, m4a, etc.)

        Returns:
            Parsed transaction information
        """
        # Encode audio to base64
        audio_base64 = base64.b64encode(audio_content).decode("utf-8")

        prompt = """请分析这段语音，提取记账信息。

请识别语音内容，并提取：
1. 金额（数字）
2. 消费类型（餐饮/交通/购物/娱乐/住房/医疗/教育/工资/奖金/兼职/理财/其他）
3. 是支出还是收入（expense/income）
4. 备注描述

请以JSON格式返回：
{
    "transcription": "语音转写文本",
    "amount": 金额数字,
    "category": "消费类型",
    "type": "expense或income",
    "note": "备注"
}"""

        try:
            response = await self._client.post(
                self.qwen_vl_url,  # 使用多模态端点
                headers={
                    "Authorization": f"Bearer {self.qwen_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "qwen-omni-turbo",  # 全模态模型，支持音频理解
                    "input": {
                        "messages": [
                            {
                                "role": "user",
                                "content": [
                                    {"audio": f"data:audio/{audio_format};base64,{audio_base64}"},
                                    {"text": prompt}
                                ]
                            }
                        ]
                    }
                },
                timeout=60.0,
            )

            if response.status_code == 200:
                result = response.json()
                text = result.get("output", {}).get("choices", [{}])[0].get("message", {}).get("content", "")
                return self._parse_audio_response(text)
            else:
                logger.error(f"Qwen Audio API error: {response.status_code} - {response.text}")
                return self._empty_audio_result(error=f"API error: {response.status_code}")

        except Exception as e:
            logger.error(f"Qwen Audio recognition error: {e}", exc_info=True)
            return self._empty_audio_result(error=str(e))

    def _parse_audio_response(self, text: str) -> dict:
        """Parse Qwen Audio response."""
        try:
            json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group())

                result = {
                    "transcription": data.get("transcription", ""),
                    "amount": Decimal(str(data.get("amount"))) if data.get("amount") else None,
                    "category_name": data.get("category"),
                    "category_type": 2 if data.get("type") == "income" else 1,
                    "note": data.get("note"),
                    "confidence": 0.9,
                    "raw_text": text,
                    "success": True,
                }
                return result
        except Exception as e:
            logger.warning(f"Audio parse error: {e}")

        return self._empty_audio_result()

    def _empty_audio_result(self, error: str = None) -> dict:
        """Return empty audio result."""
        return {
            "transcription": None,
            "amount": None,
            "category_name": None,
            "category_type": 1,
            "note": None,
            "confidence": None,
            "raw_text": None,
            "success": False,
            "error": error,
        }

    def _parse_ai_response(self, text: str, is_voice: bool = False) -> dict:
        """Parse AI response JSON."""
        try:
            # Extract JSON from response
            json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group())

                result = {
                    "amount": Decimal(str(data.get("amount"))) if data.get("amount") else None,
                    "category_name": data.get("category"),
                    "category_type": 2 if data.get("type") == "income" else 1,
                    "note": data.get("note") or data.get("merchant"),
                    "merchant": data.get("merchant"),
                    "date": data.get("date"),
                    "confidence": 0.85,
                    "raw_text": text,
                }
                return result
        except Exception as e:
            logger.warning(f"Parse error: {e}")

        return self._empty_result()

    def _parse_batch_response(self, text: str) -> list[dict]:
        """Parse batch AI response containing multiple transactions."""
        try:
            # Extract JSON from response
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group())
                transactions = data.get("transactions", [])

                results = []
                for trans in transactions:
                    try:
                        result = {
                            "amount": Decimal(str(trans.get("amount"))) if trans.get("amount") else None,
                            "category_name": trans.get("category"),
                            "category_type": 2 if trans.get("type") == "income" else 1,
                            "note": trans.get("note") or trans.get("merchant"),
                            "merchant": trans.get("merchant"),
                            "date": trans.get("date"),
                            "confidence": 0.85,
                        }
                        # Only add if has amount
                        if result["amount"]:
                            results.append(result)
                    except Exception as e:
                        logger.warning(f"Failed to parse transaction: {e}")
                        continue

                logger.info(f"Parsed {len(results)} transactions from batch image")
                return results

        except Exception as e:
            logger.error(f"Batch parse error: {e}")

        return []

    def _simple_parse(self, text: str) -> dict:
        """Simple regex-based parsing as fallback."""
        result = self._empty_result()

        # Extract amount
        amount_match = re.search(r'(\d+(?:\.\d{1,2})?)\s*(?:元|块|￥)?', text)
        if amount_match:
            result["amount"] = Decimal(amount_match.group(1))

        # Detect income keywords
        income_keywords = ["工资", "收入", "到账", "进账", "收到", "赚"]
        is_income = any(kw in text for kw in income_keywords)
        result["category_type"] = 2 if is_income else 1

        # Simple category detection
        category_map = {
            "餐": "餐饮", "饭": "餐饮", "吃": "餐饮", "外卖": "餐饮", "咖啡": "餐饮",
            "车": "交通", "地铁": "交通", "公交": "交通", "打车": "交通", "滴滴": "交通",
            "买": "购物", "购": "购物", "淘宝": "购物", "京东": "购物",
            "电影": "娱乐", "游戏": "娱乐", "ktv": "娱乐",
            "房租": "住房", "水电": "住房",
            "医": "医疗", "药": "医疗",
            "书": "教育", "课": "教育",
            "工资": "工资", "奖金": "奖金",
        }

        for keyword, category in category_map.items():
            if keyword in text.lower():
                result["category_name"] = category
                break

        if not result["category_name"]:
            result["category_name"] = "工资" if is_income else "其他"

        result["note"] = text
        result["confidence"] = 0.6

        return result

    def _empty_result(self) -> dict:
        """Return empty result."""
        return {
            "amount": None,
            "category_name": None,
            "category_type": 1,
            "note": None,
            "merchant": None,
            "date": None,
            "confidence": None,
            "raw_text": None,
        }

    async def parse_bill_email(self, email_content: str, email_subject: str = "", sender: str = "") -> dict:
        """Parse credit card bill from email content.

        Primary: Qwen (通义千问)
        Fallback: Zhipu (智谱)

        Args:
            email_content: The email body content (HTML or plain text)
            email_subject: Email subject line
            sender: Email sender address

        Returns:
            Parsed bill information including transactions
        """
        prompt = f"""请分析这封信用卡账单邮件，提取账单信息。

邮件主题: {email_subject}
发件人: {sender}
邮件内容:
{email_content[:8000]}

请提取以下信息并以JSON格式返回：
{{
    "bank_name": "银行名称",
    "card_number_last4": "卡号后四位",
    "bill_date": "账单日期 (YYYY-MM-DD)",
    "due_date": "还款日期 (YYYY-MM-DD)",
    "total_amount": 账单总金额(数字),
    "min_payment": 最低还款额(数字),
    "previous_balance": 上期余额(数字),
    "current_balance": 本期余额(数字),
    "transactions": [
        {{
            "date": "交易日期 (YYYY-MM-DD)",
            "description": "交易描述/商户名称",
            "amount": 交易金额(数字),
            "category": "消费类型(餐饮/交通/购物/娱乐/住房/医疗/教育/其他)"
        }}
    ],
    "is_bill": true/false表示是否为有效账单邮件,
    "confidence": 0.0-1.0之间的置信度
}}

如果这不是账单邮件或无法解析，请返回 {{"is_bill": false, "confidence": 0}}"""

        # Try Qwen first (primary)
        try:
            result = await self._call_qwen_text(prompt, timeout=60.0)
            if result:
                return self._parse_bill_response(result)
        except Exception as e:
            logger.warning(f"Qwen bill parsing failed: {e}")

        # Fallback to Zhipu
        try:
            result = await self._call_zhipu_text(prompt, timeout=60.0)
            if result:
                return self._parse_bill_response(result)
        except Exception as e:
            logger.error(f"Zhipu bill parsing failed: {e}")

        return self._empty_bill_result()

    def _parse_bill_response(self, text: str) -> dict:
        """Parse AI response for bill parsing."""
        try:
            # Extract JSON from response
            json_match = re.search(r'\{[\s\S]*\}', text)
            if json_match:
                data = json.loads(json_match.group())

                # Validate and normalize the response
                result = {
                    "bank_name": data.get("bank_name"),
                    "card_number_last4": data.get("card_number_last4"),
                    "bill_date": data.get("bill_date"),
                    "due_date": data.get("due_date"),
                    "total_amount": Decimal(str(data.get("total_amount", 0))) if data.get("total_amount") else None,
                    "min_payment": Decimal(str(data.get("min_payment", 0))) if data.get("min_payment") else None,
                    "previous_balance": Decimal(str(data.get("previous_balance", 0))) if data.get("previous_balance") else None,
                    "current_balance": Decimal(str(data.get("current_balance", 0))) if data.get("current_balance") else None,
                    "transactions": [],
                    "is_bill": data.get("is_bill", False),
                    "confidence": float(data.get("confidence", 0)),
                    "raw_text": text,
                }

                # Parse transactions
                for tx in data.get("transactions", []):
                    if tx.get("amount"):
                        result["transactions"].append({
                            "date": tx.get("date"),
                            "description": tx.get("description"),
                            "amount": Decimal(str(tx.get("amount"))),
                            "category": tx.get("category", "其他"),
                        })

                return result

        except Exception as e:
            logger.warning(f"Bill parse error: {e}")

        return self._empty_bill_result()

    def _empty_bill_result(self) -> dict:
        """Return empty bill result."""
        return {
            "bank_name": None,
            "card_number_last4": None,
            "bill_date": None,
            "due_date": None,
            "total_amount": None,
            "min_payment": None,
            "previous_balance": None,
            "current_balance": None,
            "transactions": [],
            "is_bill": False,
            "confidence": 0,
            "raw_text": None,
        }

    async def _call_qwen_text(self, prompt: str, timeout: float = 30.0) -> Optional[str]:
        """Call Qwen text API (通义千问).

        Args:
            prompt: The prompt to send
            timeout: Request timeout in seconds

        Returns:
            AI response text or None if failed
        """
        if not self.qwen_api_key:
            return None

        response = await self._client.post(
            self.qwen_text_url,
            headers={
                "Authorization": f"Bearer {self.qwen_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "qwen-plus",
                "messages": [
                    {"role": "user", "content": prompt}
                ]
            },
            timeout=timeout,
        )

        if response.status_code == 200:
            result = response.json()
            return result.get("choices", [{}])[0].get("message", {}).get("content", "")
        else:
            logger.error(f"Qwen API error: {response.status_code} - {response.text}")
            return None

    async def _call_zhipu_text(self, prompt: str, timeout: float = 30.0) -> Optional[str]:
        """Call Zhipu text API (智谱 GLM) as fallback.

        Args:
            prompt: The prompt to send
            timeout: Request timeout in seconds

        Returns:
            AI response text or None if failed
        """
        if not self.zhipu_api_key:
            return None

        response = await self._client.post(
            self.zhipu_url,
            headers={
                "Authorization": f"Bearer {self.zhipu_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "glm-4-flash",
                "messages": [
                    {"role": "user", "content": prompt}
                ]
            },
            timeout=timeout,
        )

        if response.status_code == 200:
            result = response.json()
            return result.get("choices", [{}])[0].get("message", {}).get("content", "")
        else:
            logger.error(f"Zhipu API error: {response.status_code} - {response.text}")
            return None


# Singleton instance
ai_service = AIService()
