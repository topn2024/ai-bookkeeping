"""LLM service for text generation."""
import logging
from typing import Optional
import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class LLMService:
    """LLM service for generating text content using Qwen."""

    def __init__(self):
        self.api_key = settings.QWEN_API_KEY
        self.api_url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        self.model = "qwen-plus"

    async def generate(
        self,
        prompt: str,
        max_tokens: int = 500,
        temperature: float = 0.7,
        model: Optional[str] = None,
    ) -> str:
        """Generate text using Qwen LLM.

        Args:
            prompt: The prompt to send to the LLM
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (0-1)
            model: Optional model override

        Returns:
            Generated text content
        """
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.api_url,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": model or self.model,
                        "messages": [
                            {"role": "user", "content": prompt}
                        ],
                        "max_tokens": max_tokens,
                        "temperature": temperature,
                    },
                    timeout=30.0,
                )

                if response.status_code == 200:
                    result = response.json()
                    content = result.get("choices", [{}])[0].get("message", {}).get("content", "")
                    return content
                else:
                    logger.error(f"LLM API error: {response.status_code} - {response.text}")
                    raise Exception(f"LLM API returned status {response.status_code}")

        except Exception as e:
            logger.error(f"LLM generation error: {e}", exc_info=True)
            raise
