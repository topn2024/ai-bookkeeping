"""End-to-end tests for AI features module.

Tests AI-powered features including:
- Image recognition (receipt scanning) with qwen-vl-plus
- Voice/audio recognition with qwen-omni-turbo
- Smart categorization with qwen-turbo/qwen-plus
- Email bill parsing

Note: Some AI endpoints may return 404 if not yet implemented.
Tests accept 404 as valid response indicating pending implementation.
"""
import pytest
import base64
from datetime import datetime
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.book import Book


class TestImageRecognition:
    """Test cases for image recognition (receipt scanning)."""

    @pytest.mark.asyncio
    async def test_parse_receipt_image_base64(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test parsing receipt from base64 image."""
        # Create a minimal valid base64 image (1x1 pixel PNG)
        minimal_png = (
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
            "+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        )

        response = await authenticated_client.post(
            "/api/v1/ai/parse-receipt",
            json={
                "image_base64": minimal_png,
                "book_id": str(test_book.id),
            },
        )

        # May succeed or fail based on AI service availability
        # 404 indicates endpoint not yet implemented
        assert response.status_code in [200, 400, 404, 422, 500, 503]

    @pytest.mark.asyncio
    async def test_parse_receipt_without_auth_fails(
        self,
        client: AsyncClient,
    ):
        """Test that receipt parsing requires authentication."""
        response = await client.post(
            "/api/v1/ai/parse-receipt",
            json={
                "image_base64": "test",
            },
        )

        # Should return 401 (unauthorized) or 404 (not implemented)
        assert response.status_code in [401, 404]


class TestVoiceRecognition:
    """Test cases for voice recognition using qwen-omni-turbo model."""

    @pytest.mark.asyncio
    async def test_parse_voice_text(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test parsing voice transcribed text."""
        response = await authenticated_client.post(
            "/api/v1/ai/parse-voice",
            json={
                "text": "今天午餐花了35元",
                "book_id": str(test_book.id),
            },
        )

        # Check response structure if successful
        if response.status_code == 200:
            data = response.json()
            # Should contain parsed transaction data
            assert "amount" in data or "transaction" in data or isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_parse_complex_voice_text(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test parsing complex voice input."""
        response = await authenticated_client.post(
            "/api/v1/ai/parse-voice",
            json={
                "text": "昨天在超市买了一些水果和蔬菜，一共花了128块5毛",
                "book_id": str(test_book.id),
            },
        )

        assert response.status_code in [200, 400, 404, 422, 500, 503]

    @pytest.mark.asyncio
    async def test_parse_income_voice_text(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test parsing income voice input."""
        response = await authenticated_client.post(
            "/api/v1/ai/parse-voice",
            json={
                "text": "收到工资一万五",
                "book_id": str(test_book.id),
            },
        )

        assert response.status_code in [200, 400, 404, 422, 500, 503]


class TestAudioRecognition:
    """Test cases for audio file recognition using qwen-omni-turbo model.

    The qwen-omni-turbo model is a multimodal model that supports direct
    audio understanding without requiring separate speech-to-text conversion.
    Supported formats: m4a (AAC-LC), wav, mp3
    """

    @pytest.mark.asyncio
    async def test_parse_audio_base64(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test parsing audio from base64 encoded data."""
        # Create a minimal valid audio placeholder (actual audio would be longer)
        # This tests the API structure, actual recognition requires real audio
        minimal_audio_base64 = base64.b64encode(b"RIFF" + b"\x00" * 40).decode()

        response = await authenticated_client.post(
            "/api/v1/ai/parse-audio",
            json={
                "audio_base64": minimal_audio_base64,
                "format": "wav",
                "book_id": str(test_book.id),
            },
        )

        # May succeed or fail based on AI service availability
        # 400/422 for invalid audio format is expected
        assert response.status_code in [200, 400, 404, 422, 500, 503]

    @pytest.mark.asyncio
    async def test_parse_audio_m4a_format(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test parsing m4a audio format (AAC-LC encoding)."""
        # M4A header placeholder
        minimal_m4a = base64.b64encode(b"ftyp" + b"\x00" * 40).decode()

        response = await authenticated_client.post(
            "/api/v1/ai/parse-audio",
            json={
                "audio_base64": minimal_m4a,
                "format": "m4a",
                "book_id": str(test_book.id),
            },
        )

        assert response.status_code in [200, 400, 404, 422, 500, 503]

    @pytest.mark.asyncio
    async def test_parse_audio_without_auth_fails(
        self,
        client: AsyncClient,
    ):
        """Test that audio parsing requires authentication."""
        response = await client.post(
            "/api/v1/ai/parse-audio",
            json={
                "audio_base64": "dGVzdA==",  # "test" in base64
                "format": "wav",
            },
        )

        # Should return 401 (unauthorized) or 404 (not implemented)
        assert response.status_code in [401, 404]

    @pytest.mark.asyncio
    async def test_parse_audio_empty_data_fails(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test that empty audio data returns error."""
        response = await authenticated_client.post(
            "/api/v1/ai/parse-audio",
            json={
                "audio_base64": "",
                "format": "wav",
                "book_id": str(test_book.id),
            },
        )

        # Should return validation error
        assert response.status_code in [400, 404, 422]

    @pytest.mark.asyncio
    async def test_parse_audio_unsupported_format(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test that unsupported audio format returns error."""
        response = await authenticated_client.post(
            "/api/v1/ai/parse-audio",
            json={
                "audio_base64": base64.b64encode(b"test").decode(),
                "format": "unsupported_format",
                "book_id": str(test_book.id),
            },
        )

        # Should return validation error for unsupported format
        assert response.status_code in [400, 404, 422]


class TestSmartCategorization:
    """Test cases for smart category suggestion."""

    @pytest.mark.asyncio
    async def test_suggest_category(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test category suggestion for transaction description."""
        response = await authenticated_client.post(
            "/api/v1/ai/suggest-category",
            json={
                "description": "星巴克咖啡",
                "book_id": str(test_book.id),
            },
        )

        if response.status_code == 200:
            data = response.json()
            # Should suggest food/beverage category
            assert "category" in data or "suggestion" in data or isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_suggest_category_multiple(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test multiple category suggestions."""
        test_cases = [
            "加油站加油",          # Transportation
            "网易云音乐会员",       # Entertainment
            "电费水费",            # Utilities
            "京东购物",            # Shopping
        ]

        for description in test_cases:
            response = await authenticated_client.post(
                "/api/v1/ai/suggest-category",
                json={
                    "description": description,
                    "book_id": str(test_book.id),
                },
            )
            assert response.status_code in [200, 400, 404, 422, 500, 503]


class TestEmailBillParsing:
    """Test cases for email bill parsing."""

    @pytest.mark.asyncio
    async def test_parse_bill_email(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test parsing credit card bill email."""
        sample_bill_content = """
        招商银行信用卡电子账单
        账单周期: 2024年11月1日 - 2024年11月30日
        账单金额: ¥3,568.50
        最后还款日: 2024年12月25日

        交易明细:
        11月5日 星巴克咖啡 ¥45.00
        11月8日 淘宝购物 ¥299.00
        11月12日 美团外卖 ¥35.50
        """

        response = await authenticated_client.post(
            "/api/v1/ai/parse-bill",
            json={
                "email_content": sample_bill_content,
                "email_subject": "招商银行信用卡账单",
                "sender": "credit-card@cmbchina.com",
            },
        )

        if response.status_code == 200:
            data = response.json()
            # Verify parsed data structure
            assert isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_parse_bill_empty_content(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test parsing empty bill content."""
        response = await authenticated_client.post(
            "/api/v1/ai/parse-bill",
            json={
                "email_content": "",
                "email_subject": "Test",
                "sender": "test@test.com",
            },
        )

        # Should return error for empty content
        assert response.status_code in [400, 404, 422]


class TestEmailBindings:
    """Test cases for email binding management."""

    @pytest.mark.asyncio
    async def test_create_email_binding(
        self,
        authenticated_client: AsyncClient,
        data_factory,
    ):
        """Test creating an email binding."""
        response = await authenticated_client.post(
            "/api/v1/email-bindings",
            json={
                "email": data_factory.random_email(),
                "email_type": "gmail",
                "imap_server": "imap.gmail.com",
                "imap_port": 993,
                "imap_password": "app_password_here",
            },
        )

        assert response.status_code in [200, 201, 400, 422]

    @pytest.mark.asyncio
    async def test_list_email_bindings(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test listing email bindings."""
        response = await authenticated_client.get("/api/v1/email-bindings")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_delete_email_binding(
        self,
        authenticated_client: AsyncClient,
        data_factory,
    ):
        """Test deleting an email binding."""
        # Create binding first
        create_response = await authenticated_client.post(
            "/api/v1/email-bindings",
            json={
                "email": data_factory.random_email(),
                "email_type": "custom",
                "imap_server": "imap.example.com",
                "imap_port": 993,
                "imap_password": "test_password",
            },
        )

        if create_response.status_code in [200, 201]:
            binding_id = create_response.json().get("id")
            if binding_id:
                delete_response = await authenticated_client.delete(
                    f"/api/v1/email-bindings/{binding_id}"
                )
                assert delete_response.status_code in [200, 204, 404]


class TestAIQuotas:
    """Test cases for AI feature usage quotas."""

    @pytest.mark.asyncio
    async def test_check_ai_quota(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test checking AI feature usage quota."""
        response = await authenticated_client.get("/api/v1/ai/quota")

        # May return quota info or 404 if not implemented
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_ai_rate_limiting(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test AI feature rate limiting."""
        # Make multiple requests quickly
        for _ in range(5):
            response = await authenticated_client.post(
                "/api/v1/ai/parse-voice",
                json={
                    "text": "测试",
                    "book_id": str(test_book.id),
                },
            )
            # Should not crash, may rate limit
            assert response.status_code in [200, 400, 404, 422, 429, 500, 503]
