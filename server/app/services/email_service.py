"""Email service for fetching and parsing bill emails."""
import imaplib
import email
from email.header import decode_header
from email.utils import parsedate_to_datetime
import logging
import re
from datetime import datetime, timedelta
from typing import List, Optional, Tuple
from html import unescape
from bs4 import BeautifulSoup

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decrypt_sensitive_data
from app.models.email_binding import EmailBinding, EmailType
from app.services.ai_service import AIService

logger = logging.getLogger(__name__)


# Known bank email sender patterns
BANK_SENDER_PATTERNS = [
    # 招商银行
    (r"cmbchina\.com", "招商银行"),
    (r"creditcard\.cmbchina\.com", "招商银行信用卡"),
    # 工商银行
    (r"icbc\.com\.cn", "工商银行"),
    # 建设银行
    (r"ccb\.com", "建设银行"),
    # 中国银行
    (r"boc\.cn", "中国银行"),
    # 农业银行
    (r"abchina\.com", "农业银行"),
    # 交通银行
    (r"bankcomm\.com", "交通银行"),
    # 浦发银行
    (r"spdb\.com\.cn", "浦发银行"),
    # 中信银行
    (r"citicbank\.com", "中信银行"),
    # 广发银行
    (r"cgbchina\.com\.cn", "广发银行"),
    # 民生银行
    (r"cmbc\.com\.cn", "民生银行"),
    # 兴业银行
    (r"cib\.com\.cn", "兴业银行"),
    # 光大银行
    (r"cebbank\.com", "光大银行"),
    # 平安银行
    (r"pingan\.com", "平安银行"),
    # 支付宝
    (r"alipay\.com", "支付宝"),
    # 微信支付
    (r"wechat\.com|tenpay\.com", "微信支付"),
]

# Keywords in subject that indicate a bill email
BILL_SUBJECT_KEYWORDS = [
    "账单", "对账单", "月结单", "电子账单",
    "信用卡账单", "还款提醒", "账户月结",
    "statement", "bill", "credit card",
]


class EmailService:
    """Service for fetching and parsing bill emails."""

    def __init__(self):
        self.ai_service = AIService()

    async def sync_and_parse_bills(self, binding: EmailBinding, db: AsyncSession) -> dict:
        """Sync emails and parse bills for a binding.

        Args:
            binding: The email binding to sync
            db: Database session

        Returns:
            Sync result with statistics
        """
        try:
            # Connect to email server
            emails = await self._fetch_bill_emails(binding)

            if not emails:
                return {
                    "success": True,
                    "emails_found": 0,
                    "bills_parsed": 0,
                    "message": "No new bill emails found",
                }

            # Parse each email
            bills_parsed = 0
            for email_data in emails:
                try:
                    result = await self.ai_service.parse_bill_email(
                        email_content=email_data["content"],
                        email_subject=email_data["subject"],
                        sender=email_data["sender"],
                    )

                    if result.get("is_bill") and result.get("confidence", 0) > 0.5:
                        bills_parsed += 1
                        # Store parsed bill data for user confirmation
                        # This would be stored in a pending_bills table or similar
                        logger.info(f"Parsed bill from {email_data['sender']}: {result.get('bank_name')}")

                except Exception as e:
                    logger.warning(f"Failed to parse email: {e}")
                    continue

            return {
                "success": True,
                "emails_found": len(emails),
                "bills_parsed": bills_parsed,
                "message": f"Found {len(emails)} emails, parsed {bills_parsed} bills",
            }

        except imaplib.IMAP4.error as e:
            logger.error(f"IMAP error: {e}")
            raise Exception(f"Failed to connect to email server: {e}")
        except Exception as e:
            logger.error(f"Email sync error: {e}", exc_info=True)
            raise

    async def _fetch_bill_emails(
        self,
        binding: EmailBinding,
        days_back: int = 30,
    ) -> List[dict]:
        """Fetch potential bill emails from the mail server.

        Args:
            binding: The email binding with credentials
            days_back: Number of days to look back

        Returns:
            List of email data dicts
        """
        # Connect to IMAP server
        imap_server = binding.imap_server
        imap_port = binding.imap_port or 993

        if not imap_server or not binding.imap_password:
            raise Exception("IMAP server or password not configured")

        mail = imaplib.IMAP4_SSL(imap_server, imap_port, timeout=30)

        try:
            # Login with decrypted password
            decrypted_password = decrypt_sensitive_data(binding.imap_password)
            mail.login(binding.email, decrypted_password)

            # Select inbox
            mail.select("INBOX")

            # Search for emails from the past N days
            since_date = (datetime.now() - timedelta(days=days_back)).strftime("%d-%b-%Y")
            search_criteria = f'(SINCE "{since_date}")'

            status, message_numbers = mail.search(None, search_criteria)
            if status != "OK":
                return []

            email_ids = message_numbers[0].split()

            # Limit to most recent 100 emails
            email_ids = email_ids[-100:]

            emails = []
            for email_id in email_ids:
                try:
                    email_data = self._fetch_and_parse_email(mail, email_id)
                    if email_data and self._is_potential_bill_email(email_data):
                        emails.append(email_data)
                except Exception as e:
                    logger.warning(f"Failed to fetch email {email_id}: {e}")
                    continue

            return emails

        finally:
            try:
                mail.close()
                mail.logout()
            except Exception as e:
                logger.debug(f"Error closing IMAP connection: {e}")

    def _fetch_and_parse_email(self, mail: imaplib.IMAP4_SSL, email_id: bytes) -> Optional[dict]:
        """Fetch and parse a single email.

        Args:
            mail: IMAP connection
            email_id: Email ID to fetch

        Returns:
            Parsed email data or None
        """
        status, msg_data = mail.fetch(email_id, "(RFC822)")
        if status != "OK":
            return None

        raw_email = msg_data[0][1]
        msg = email.message_from_bytes(raw_email)

        # Parse headers
        subject = self._decode_header(msg.get("Subject", ""))
        sender = self._decode_header(msg.get("From", ""))
        date_str = msg.get("Date", "")

        try:
            email_date = parsedate_to_datetime(date_str) if date_str else None
        except (ValueError, TypeError) as e:
            logger.debug(f"Failed to parse email date '{date_str}': {e}")
            email_date = None

        # Extract body content
        content = self._extract_email_content(msg)

        return {
            "id": email_id.decode() if isinstance(email_id, bytes) else str(email_id),
            "subject": subject,
            "sender": sender,
            "date": email_date,
            "content": content,
        }

    def _decode_header(self, header_value: str) -> str:
        """Decode email header value."""
        if not header_value:
            return ""

        decoded_parts = []
        for part, encoding in decode_header(header_value):
            if isinstance(part, bytes):
                try:
                    decoded_parts.append(part.decode(encoding or "utf-8", errors="replace"))
                except (UnicodeDecodeError, LookupError):
                    decoded_parts.append(part.decode("utf-8", errors="replace"))
            else:
                decoded_parts.append(str(part))

        return " ".join(decoded_parts)

    def _extract_email_content(self, msg: email.message.Message) -> str:
        """Extract text content from email message."""
        content_parts = []

        if msg.is_multipart():
            for part in msg.walk():
                content_type = part.get_content_type()
                content_disposition = str(part.get("Content-Disposition", ""))

                # Skip attachments
                if "attachment" in content_disposition:
                    continue

                if content_type == "text/plain":
                    try:
                        charset = part.get_content_charset() or "utf-8"
                        payload = part.get_payload(decode=True)
                        if payload:
                            content_parts.append(payload.decode(charset, errors="replace"))
                    except (UnicodeDecodeError, LookupError, AttributeError):
                        pass
                elif content_type == "text/html":
                    try:
                        charset = part.get_content_charset() or "utf-8"
                        payload = part.get_payload(decode=True)
                        if payload:
                            html_content = payload.decode(charset, errors="replace")
                            text_content = self._html_to_text(html_content)
                            content_parts.append(text_content)
                    except (UnicodeDecodeError, LookupError, AttributeError):
                        pass
        else:
            content_type = msg.get_content_type()
            try:
                charset = msg.get_content_charset() or "utf-8"
                payload = msg.get_payload(decode=True)
                if payload:
                    if content_type == "text/html":
                        content_parts.append(self._html_to_text(payload.decode(charset, errors="replace")))
                    else:
                        content_parts.append(payload.decode(charset, errors="replace"))
            except (UnicodeDecodeError, LookupError, AttributeError):
                pass

        return "\n".join(content_parts)

    def _html_to_text(self, html_content: str) -> str:
        """Convert HTML to plain text."""
        try:
            soup = BeautifulSoup(html_content, "html.parser")

            # Remove script and style elements
            for script in soup(["script", "style"]):
                script.decompose()

            # Get text
            text = soup.get_text(separator="\n")

            # Clean up whitespace
            lines = (line.strip() for line in text.splitlines())
            chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
            text = "\n".join(chunk for chunk in chunks if chunk)

            return unescape(text)
        except Exception:
            # Fallback: simple regex removal of tags
            clean = re.sub(r'<[^>]+>', ' ', html_content)
            return unescape(clean)

    def _is_potential_bill_email(self, email_data: dict) -> bool:
        """Check if email is potentially a bill email.

        Args:
            email_data: Parsed email data

        Returns:
            True if email might be a bill
        """
        subject = email_data.get("subject", "").lower()
        sender = email_data.get("sender", "").lower()

        # Check sender against known bank patterns
        for pattern, _ in BANK_SENDER_PATTERNS:
            if re.search(pattern, sender, re.IGNORECASE):
                return True

        # Check subject for bill keywords
        for keyword in BILL_SUBJECT_KEYWORDS:
            if keyword.lower() in subject:
                return True

        return False

    async def test_connection(self, binding: EmailBinding) -> Tuple[bool, str]:
        """Test email connection.

        Args:
            binding: The email binding to test

        Returns:
            Tuple of (success, message)
        """
        try:
            imap_server = binding.imap_server
            imap_port = binding.imap_port or 993

            if not imap_server or not binding.imap_password:
                return False, "IMAP server or password not configured"

            mail = imaplib.IMAP4_SSL(imap_server, imap_port, timeout=30)
            # Login with decrypted password
            decrypted_password = decrypt_sensitive_data(binding.imap_password)
            mail.login(binding.email, decrypted_password)
            mail.select("INBOX")
            mail.close()
            mail.logout()

            return True, "Connection successful"

        except imaplib.IMAP4.error as e:
            return False, f"Authentication failed: {e}"
        except Exception as e:
            return False, f"Connection failed: {e}"
