"""Notification email service for sending transactional emails."""
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header
from email.utils import formataddr
from typing import Optional

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class NotificationEmailService:
    """Service for sending notification emails (password reset, etc.)."""

    def __init__(self):
        self.settings = get_settings()

    @property
    def is_configured(self) -> bool:
        """Check if SMTP is configured."""
        return bool(
            self.settings.SMTP_HOST
            and self.settings.SMTP_USER
            and self.settings.SMTP_PASSWORD
        )

    async def send_password_reset_code(
        self,
        to_email: str,
        reset_code: str,
        expires_minutes: int = 10,
    ) -> bool:
        """Send password reset code via email.

        Args:
            to_email: Recipient email address
            reset_code: The 6-digit reset code
            expires_minutes: Code validity in minutes

        Returns:
            True if email sent successfully
        """
        subject = f"【{self.settings.SMTP_FROM_NAME}】密码重置验证码"
        html_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center;">
                <h1 style="color: white; margin: 0;">密码重置</h1>
            </div>
            <div style="padding: 30px; background: #f9f9f9;">
                <p>您好，</p>
                <p>您正在重置 {self.settings.SMTP_FROM_NAME} 账户密码。请使用以下验证码完成重置：</p>
                <div style="background: white; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #667eea;">{reset_code}</span>
                </div>
                <p style="color: #666;">此验证码将在 <strong>{expires_minutes} 分钟</strong>后失效。</p>
                <p style="color: #999; font-size: 12px;">如果您没有请求重置密码，请忽略此邮件。</p>
            </div>
            <div style="padding: 20px; text-align: center; color: #999; font-size: 12px;">
                <p>此邮件由系统自动发送，请勿回复。</p>
            </div>
        </body>
        </html>
        """
        text_body = f"""
密码重置验证码

您好，

您正在重置 {self.settings.SMTP_FROM_NAME} 账户密码。
您的验证码是：{reset_code}

此验证码将在 {expires_minutes} 分钟后失效。

如果您没有请求重置密码，请忽略此邮件。
"""
        return await self._send_email(to_email, subject, html_body, text_body)

    async def _send_email(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
    ) -> bool:
        """Send an email.

        Args:
            to_email: Recipient email
            subject: Email subject
            html_body: HTML content
            text_body: Plain text content (fallback)

        Returns:
            True if sent successfully
        """
        if not self.is_configured:
            logger.warning("SMTP not configured, cannot send email")
            return False

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = Header(subject, "utf-8")
            from_email = self.settings.SMTP_FROM_EMAIL or self.settings.SMTP_USER
            msg["From"] = formataddr((str(Header(self.settings.SMTP_FROM_NAME, "utf-8")), from_email))
            msg["To"] = to_email

            if text_body:
                msg.attach(MIMEText(text_body, "plain", "utf-8"))
            msg.attach(MIMEText(html_body, "html", "utf-8"))

            if self.settings.SMTP_USE_TLS:
                server = smtplib.SMTP(self.settings.SMTP_HOST, self.settings.SMTP_PORT)
                server.starttls()
            else:
                server = smtplib.SMTP_SSL(self.settings.SMTP_HOST, self.settings.SMTP_PORT)

            server.login(self.settings.SMTP_USER, self.settings.SMTP_PASSWORD)
            server.sendmail(
                self.settings.SMTP_FROM_EMAIL or self.settings.SMTP_USER,
                to_email,
                msg.as_string(),
            )
            server.quit()

            logger.info(f"Email sent successfully to {to_email}")
            return True

        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"SMTP authentication failed: {e}")
            return False
        except smtplib.SMTPException as e:
            logger.error(f"SMTP error: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            return False


# Singleton instance
notification_email_service = NotificationEmailService()
