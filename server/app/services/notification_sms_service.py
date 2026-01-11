"""Notification SMS service for sending SMS verification codes via Aliyun."""
import logging
from typing import Optional
from alibabacloud_dysmsapi20170525.client import Client as DysmsapiClient
from alibabacloud_tea_openapi import models as open_api_models
from alibabacloud_dysmsapi20170525 import models as dysmsapi_models
from alibabacloud_tea_util import models as util_models

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class NotificationSmsService:
    """Service for sending SMS notifications via Aliyun (阿里云短信服务)."""

    def __init__(self):
        self.settings = get_settings()
        self._client: Optional[DysmsapiClient] = None

    @property
    def is_configured(self) -> bool:
        """Check if Aliyun SMS is configured."""
        return bool(
            self.settings.ALIYUN_ACCESS_KEY_ID
            and self.settings.ALIYUN_ACCESS_KEY_SECRET
            and self.settings.ALIYUN_SMS_SIGN_NAME
            and self.settings.ALIYUN_SMS_TEMPLATE_CODE
        )

    def _get_client(self) -> DysmsapiClient:
        """Get or create Aliyun SMS client."""
        if self._client is None:
            config = open_api_models.Config(
                access_key_id=self.settings.ALIYUN_ACCESS_KEY_ID,
                access_key_secret=self.settings.ALIYUN_ACCESS_KEY_SECRET,
            )
            # 设置endpoint
            config.endpoint = f"dysmsapi.aliyuncs.com"
            self._client = DysmsapiClient(config)
        return self._client

    async def send_verification_code(
        self,
        phone_number: str,
        code: str,
    ) -> bool:
        """Send SMS verification code.

        Args:
            phone_number: Recipient phone number (with country code, e.g., +8613800138000)
            code: The 6-digit verification code

        Returns:
            True if SMS sent successfully
        """
        if not self.is_configured:
            logger.warning("Aliyun SMS not configured, cannot send SMS")
            return False

        # Remove '+' and spaces from phone number
        phone_number = phone_number.replace('+', '').replace(' ', '')

        try:
            client = self._get_client()

            # 创建发送请求
            send_sms_request = dysmsapi_models.SendSmsRequest(
                phone_numbers=phone_number,
                sign_name=self.settings.ALIYUN_SMS_SIGN_NAME,
                template_code=self.settings.ALIYUN_SMS_TEMPLATE_CODE,
                template_param=f'{{"code":"{code}"}}',  # 模板参数，格式为JSON字符串
            )

            # 发送短信
            runtime = util_models.RuntimeOptions()
            response = client.send_sms_with_options(send_sms_request, runtime)

            # 检查响应
            if response.body.code == 'OK':
                logger.info(f"SMS sent successfully to {phone_number}")
                return True
            else:
                logger.error(f"Failed to send SMS: {response.body.code} - {response.body.message}")
                return False

        except Exception as e:
            logger.error(f"Failed to send SMS to {phone_number}: {e}")
            return False


# Singleton instance
notification_sms_service = NotificationSmsService()
