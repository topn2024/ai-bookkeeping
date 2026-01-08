"""Redis client for caching, rate limiting, and distributed consistency.

This module provides async Redis connection management for:
- Cache consistency service (Chapter 33.2)
- Distributed lock service (Chapter 33.3)
- Rate limiting
- General caching

Reference: Design Document Chapter 33 - Distributed Consistency Design
"""
import logging
import time
from typing import Optional
from contextlib import asynccontextmanager

import redis.asyncio as redis
from redis.asyncio import Redis, ConnectionPool

from app.core.config import settings

logger = logging.getLogger(__name__)

# Global Redis client and pool
_redis_client: Optional[Redis] = None
_redis_pool: Optional[ConnectionPool] = None


class RedisManager:
    """Enhanced Redis connection manager with health checks."""

    _instance: Optional["RedisManager"] = None
    _redis: Optional[Redis] = None
    _pool: Optional[ConnectionPool] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def connect(self, url: str = None) -> None:
        """Initialize Redis connection pool."""
        if self._redis is not None:
            return

        url = url or settings.REDIS_URL
        if not url:
            logger.warning("REDIS_URL not configured, Redis features disabled")
            return

        try:
            self._pool = ConnectionPool.from_url(
                url,
                max_connections=20,
                decode_responses=True,
                socket_timeout=5.0,
                socket_connect_timeout=5.0,
            )
            self._redis = Redis(connection_pool=self._pool)
            await self._redis.ping()
            logger.info(f"Redis connected: {self._mask_url(url)}")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self._redis = None
            self._pool = None

    async def disconnect(self) -> None:
        """Close Redis connection and cleanup."""
        if self._redis:
            await self._redis.close()
            if self._pool:
                await self._pool.disconnect()
            self._redis = None
            self._pool = None
            logger.info("Redis disconnected")

    def get_client(self) -> Optional[Redis]:
        """Get Redis client instance."""
        return self._redis

    def is_connected(self) -> bool:
        """Check if Redis is connected."""
        return self._redis is not None

    async def health_check(self) -> dict:
        """Perform Redis health check."""
        if not self._redis:
            return {"connected": False, "error": "Not connected"}
        try:
            start = time.time()
            await self._redis.ping()
            latency = (time.time() - start) * 1000
            info = await self._redis.info("server")
            return {
                "connected": True,
                "latency_ms": round(latency, 2),
                "redis_version": info.get("redis_version", "unknown"),
            }
        except Exception as e:
            return {"connected": False, "error": str(e)}

    @staticmethod
    def _mask_url(url: str) -> str:
        """Mask password in Redis URL for logging."""
        if "@" in url and ":" in url:
            parts = url.split("@")
            if len(parts) == 2:
                prefix = parts[0]
                if ":" in prefix:
                    proto_pass = prefix.rsplit(":", 1)
                    return f"{proto_pass[0]}:***@{parts[1]}"
        return url


# Singleton instance
redis_manager = RedisManager()


async def get_redis() -> Optional[Redis]:
    """Get Redis client instance."""
    global _redis_client

    if _redis_client is None:
        if not settings.REDIS_URL:
            logger.warning("REDIS_URL not configured, Redis features disabled")
            return None

        try:
            _redis_client = redis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
            )
            # Test connection
            await _redis_client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            _redis_client = None
            return None

    return _redis_client


async def close_redis():
    """Close Redis connection."""
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
        logger.info("Redis connection closed")
    # Also close manager
    await redis_manager.disconnect()


@asynccontextmanager
async def redis_connection():
    """Context manager for Redis connection."""
    client = await get_redis()
    try:
        yield client
    finally:
        pass  # Don't close shared connection


class RedisCache:
    """Redis cache operations."""

    @staticmethod
    async def get(key: str) -> Optional[str]:
        """Get value from cache."""
        client = await get_redis()
        if client:
            try:
                return await client.get(key)
            except Exception as e:
                logger.error(f"Redis GET error: {e}")
        return None

    @staticmethod
    async def set(key: str, value: str, expire: int = 3600) -> bool:
        """Set value in cache with expiration."""
        client = await get_redis()
        if client:
            try:
                await client.set(key, value, ex=expire)
                return True
            except Exception as e:
                logger.error(f"Redis SET error: {e}")
        return False

    @staticmethod
    async def delete(key: str) -> bool:
        """Delete key from cache."""
        client = await get_redis()
        if client:
            try:
                await client.delete(key)
                return True
            except Exception as e:
                logger.error(f"Redis DELETE error: {e}")
        return False

    @staticmethod
    async def incr(key: str, expire: int = None) -> Optional[int]:
        """Increment counter and optionally set expiration."""
        client = await get_redis()
        if client:
            try:
                count = await client.incr(key)
                if expire and count == 1:
                    await client.expire(key, expire)
                return count
            except Exception as e:
                logger.error(f"Redis INCR error: {e}")
        return None

    @staticmethod
    async def exists(key: str) -> bool:
        """Check if key exists."""
        client = await get_redis()
        if client:
            try:
                return await client.exists(key) > 0
            except Exception as e:
                logger.error(f"Redis EXISTS error: {e}")
        return False

    @staticmethod
    async def ttl(key: str) -> Optional[int]:
        """Get remaining TTL of a key."""
        client = await get_redis()
        if client:
            try:
                return await client.ttl(key)
            except Exception as e:
                logger.error(f"Redis TTL error: {e}")
        return None
