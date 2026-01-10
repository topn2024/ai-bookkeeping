"""语音服务Token代理API

提供阿里云语音服务的临时Token获取功能，避免在客户端暴露密钥。
"""
import hashlib
import hmac
import base64
import time
import uuid
from datetime import datetime, timedelta
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.core.config import settings
from app.models.user import User

router = APIRouter(prefix="/voice", tags=["voice"])


class VoiceTokenResponse(BaseModel):
    """语音服务Token响应"""
    token: str
    expires_at: datetime
    app_key: str
    # ASR 配置
    asr_url: str = "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1"
    asr_rest_url: str = "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr"
    # TTS 配置
    tts_url: str = "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/tts"
    # Picovoice 配置（唤醒词检测）
    picovoice_access_key: Optional[str] = None


class TokenCache:
    """Token缓存管理"""
    _token: Optional[str] = None
    _expires_at: Optional[datetime] = None
    _lock_time: Optional[datetime] = None

    @classmethod
    def get_cached_token(cls) -> Optional[tuple[str, datetime]]:
        """获取缓存的Token（如果未过期）"""
        if cls._token and cls._expires_at:
            # 预留5分钟的刷新窗口
            if datetime.utcnow() < cls._expires_at - timedelta(minutes=5):
                return cls._token, cls._expires_at
        return None

    @classmethod
    def set_token(cls, token: str, expires_at: datetime):
        """设置Token缓存"""
        cls._token = token
        cls._expires_at = expires_at

    @classmethod
    def is_rate_limited(cls) -> bool:
        """检查是否处于限流状态"""
        if cls._lock_time:
            if datetime.utcnow() < cls._lock_time:
                return True
            cls._lock_time = None
        return False

    @classmethod
    def set_rate_limit(cls, seconds: int = 60):
        """设置限流"""
        cls._lock_time = datetime.utcnow() + timedelta(seconds=seconds)


def _create_signature(access_key_secret: str, string_to_sign: str) -> str:
    """创建阿里云API签名"""
    h = hmac.new(
        (access_key_secret + "&").encode("utf-8"),
        string_to_sign.encode("utf-8"),
        hashlib.sha1
    )
    return base64.b64encode(h.digest()).decode("utf-8")


async def _get_alibaba_token() -> tuple[str, datetime]:
    """从阿里云获取临时Token

    Returns:
        tuple: (token, expires_at)
    """
    # 检查缓存
    cached = TokenCache.get_cached_token()
    if cached:
        return cached

    # 检查限流
    if TokenCache.is_rate_limited():
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="请求过于频繁，请稍后重试"
        )

    # 从配置获取密钥
    access_key_id = getattr(settings, "ALIBABA_ACCESS_KEY_ID", None)
    access_key_secret = getattr(settings, "ALIBABA_ACCESS_KEY_SECRET", None)

    if not access_key_id or not access_key_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="语音服务未配置"
        )

    # 构建Token请求参数
    # 阿里云NLS Token获取API: https://help.aliyun.com/document_detail/72153.html
    timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    nonce = str(uuid.uuid4())

    params = {
        "AccessKeyId": access_key_id,
        "Action": "CreateToken",
        "Format": "JSON",
        "RegionId": "cn-shanghai",
        "SignatureMethod": "HMAC-SHA1",
        "SignatureNonce": nonce,
        "SignatureVersion": "1.0",
        "Timestamp": timestamp,
        "Version": "2019-02-28",
    }

    # 按字母排序参数
    sorted_params = sorted(params.items(), key=lambda x: x[0])

    # 构建待签名字符串
    from urllib.parse import quote

    def percent_encode(s: str) -> str:
        return quote(s, safe="~")

    query_string = "&".join(
        f"{percent_encode(k)}={percent_encode(v)}"
        for k, v in sorted_params
    )

    string_to_sign = f"GET&%2F&{percent_encode(query_string)}"
    signature = _create_signature(access_key_secret, string_to_sign)

    # 发送请求
    params["Signature"] = signature

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://nls-meta.cn-shanghai.aliyuncs.com/",
                params=params
            )
            response.raise_for_status()
            data = response.json()

            if "Token" in data:
                token = data["Token"]["Id"]
                # Token有效期通常为24小时，这里设置为1小时供客户端使用
                expires_at = datetime.utcnow() + timedelta(hours=1)

                # 缓存Token
                TokenCache.set_token(token, expires_at)

                return token, expires_at
            else:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"获取Token失败: {data.get('Message', 'Unknown error')}"
                )

    except httpx.HTTPStatusError as e:
        TokenCache.set_rate_limit(60)  # 错误后限流60秒
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"阿里云服务请求失败: {str(e)}"
        )
    except httpx.TimeoutException:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="阿里云服务请求超时"
        )


@router.get("/token", response_model=VoiceTokenResponse)
async def get_voice_token(
    current_user: User = Depends(get_current_user)
) -> VoiceTokenResponse:
    """获取语音服务临时Token

    返回阿里云语音服务的临时访问Token，客户端使用此Token调用ASR/TTS服务。
    Token有效期为1小时，建议客户端在Token过期前5分钟刷新。

    需要认证：是
    限流：每分钟最多10次请求
    """
    token, expires_at = await _get_alibaba_token()

    app_key = getattr(settings, "ALIBABA_NLS_APP_KEY", "")
    picovoice_key = getattr(settings, "PICOVOICE_ACCESS_KEY", None)

    return VoiceTokenResponse(
        token=token,
        expires_at=expires_at,
        app_key=app_key,
        picovoice_access_key=picovoice_key,
    )


@router.get("/token/status")
async def get_token_status(
    current_user: User = Depends(get_current_user)
) -> dict:
    """检查语音服务状态

    返回语音服务的配置状态，用于客户端判断是否可以使用在线语音服务。
    """
    has_config = all([
        getattr(settings, "ALIBABA_ACCESS_KEY_ID", None),
        getattr(settings, "ALIBABA_ACCESS_KEY_SECRET", None),
        getattr(settings, "ALIBABA_NLS_APP_KEY", None),
    ])

    return {
        "available": has_config,
        "message": "语音服务已配置" if has_config else "语音服务未配置，请使用离线模式",
    }
