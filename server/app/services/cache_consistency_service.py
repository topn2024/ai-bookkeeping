"""Cache consistency service with Cache-Aside and Delayed Double-Delete patterns.

Implements cache consistency strategies from Chapter 33.2:
- Cache-Aside pattern for read operations
- Delayed Double-Delete for write operations
- Version control for conflict detection
- Data hash verification

Cache TTL configurations (from design doc 33.2.2):
- Transaction list: 5 minutes (最终一致)
- Single transaction: 30 minutes (最终一致)
- Budget balance: Not cached (强一致 - real-time DB query)
- Money age data: 1 hour (最终一致)
- Statistics reports: 24 hours (弱一致)
- User config: 1 hour (最终一致)

Reference: Design Document Chapter 33.2 - Cache Consistency Design
Code Block: 434
"""
import asyncio
import hashlib
import json
import logging
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from typing import Any, Callable, Dict, List, Optional, TypeVar

from redis.asyncio import Redis

from app.core.redis import get_redis

logger = logging.getLogger(__name__)

T = TypeVar("T")


class CacheStrategy(Enum):
    """Cache consistency strategy types."""
    CACHE_ASIDE = "cache_aside"       # Application manages cache
    WRITE_THROUGH = "write_through"   # Sync write to both
    WRITE_BEHIND = "write_behind"     # Async write to DB
    READ_THROUGH = "read_through"     # Cache handles DB reads


@dataclass
class CacheConfig:
    """Cache configuration for different data types."""
    prefix: str
    ttl: int  # seconds
    consistency: str  # "strong", "eventual", "weak"
    delayed_delete_delay: float = 0.5  # seconds


# Cache configurations based on design doc 33.2.2
CACHE_CONFIGS: Dict[str, CacheConfig] = {
    "transaction_list": CacheConfig(
        prefix="txn:list:",
        ttl=300,  # 5 minutes
        consistency="eventual",
    ),
    "transaction_single": CacheConfig(
        prefix="txn:",
        ttl=1800,  # 30 minutes
        consistency="eventual",
    ),
    "money_age": CacheConfig(
        prefix="moneyage:",
        ttl=3600,  # 1 hour
        consistency="eventual",
    ),
    "stats_report": CacheConfig(
        prefix="stats:",
        ttl=86400,  # 24 hours
        consistency="weak",
    ),
    "user_config": CacheConfig(
        prefix="config:",
        ttl=3600,  # 1 hour
        consistency="eventual",
    ),
    # Budget balance is NOT cached (strong consistency required)
}


@dataclass
class CacheEntry:
    """Cache entry with metadata."""
    key: str
    value: Any
    version: int
    data_hash: str
    created_at: float
    expires_at: float
    access_count: int = 0
    last_accessed_at: float = field(default_factory=time.time)


@dataclass
class CacheStats:
    """Cache operation statistics."""
    hits: int = 0
    misses: int = 0
    writes: int = 0
    deletes: int = 0
    delayed_deletes: int = 0
    consistency_errors: int = 0

    @property
    def hit_rate(self) -> float:
        total = self.hits + self.misses
        return self.hits / total if total > 0 else 0.0


class CacheConsistencyService:
    """Cache consistency service implementing Cache-Aside and Delayed Double-Delete.

    Usage:
        # Read with cache
        value = await cache_service.get("user:123", loader=load_user_from_db)

        # Update with consistency guarantee
        await cache_service.update_with_consistency(
            key="user:123",
            db_operation=update_user_in_db,
            delay=0.5
        )
    """

    _instance: Optional["CacheConsistencyService"] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._versions: Dict[str, int] = {}
        self._delayed_tasks: Dict[str, asyncio.Task] = {}
        self._stats = CacheStats()
        self._strategy = CacheStrategy.CACHE_ASIDE
        self._initialized = True

    @property
    def stats(self) -> CacheStats:
        """Get cache statistics."""
        return self._stats

    # ==================== Cache-Aside Read ====================

    async def get(
        self,
        key: str,
        loader: Optional[Callable[[], Any]] = None,
        ttl: Optional[int] = None,
        config_type: Optional[str] = None,
    ) -> Optional[Any]:
        """Get value from cache with Cache-Aside pattern.

        1. Try to get from cache
        2. If miss and loader provided, load from source
        3. Store loaded value in cache

        Args:
            key: Cache key
            loader: Async function to load data if cache miss
            ttl: Cache TTL in seconds (overrides config)
            config_type: Config type key from CACHE_CONFIGS

        Returns:
            Cached or loaded value, None if not found
        """
        redis = await get_redis()
        if not redis:
            # Redis unavailable, fall back to loader
            if loader:
                return await self._call_loader(loader)
            return None

        # Determine TTL from config
        effective_ttl = ttl
        if config_type and config_type in CACHE_CONFIGS:
            effective_ttl = effective_ttl or CACHE_CONFIGS[config_type].ttl

        try:
            # Try cache first
            cached = await redis.get(key)
            if cached:
                self._stats.hits += 1
                return self._deserialize(cached)

            self._stats.misses += 1

            # Cache miss - load from source
            if loader:
                value = await self._call_loader(loader)
                if value is not None:
                    await self.set(key, value, ttl=effective_ttl)
                return value

            return None

        except Exception as e:
            logger.error(f"Cache GET error for key '{key}': {e}")
            # Fall back to loader on error
            if loader:
                return await self._call_loader(loader)
            return None

    async def set(
        self,
        key: str,
        value: Any,
        ttl: int = 1800,
    ) -> bool:
        """Set value in cache.

        Args:
            key: Cache key
            value: Value to cache
            ttl: TTL in seconds (default 30 minutes)

        Returns:
            True if successful
        """
        redis = await get_redis()
        if not redis:
            return False

        try:
            serialized = self._serialize(value)
            await redis.set(key, serialized, ex=ttl)
            self._stats.writes += 1

            # Update version
            self._versions[key] = self._versions.get(key, 0) + 1

            return True
        except Exception as e:
            logger.error(f"Cache SET error for key '{key}': {e}")
            return False

    async def delete(self, key: str) -> bool:
        """Delete key from cache.

        Args:
            key: Cache key

        Returns:
            True if successful
        """
        redis = await get_redis()
        if not redis:
            return False

        try:
            await redis.delete(key)
            self._stats.deletes += 1

            # Cancel pending delayed delete
            if key in self._delayed_tasks:
                self._delayed_tasks[key].cancel()
                del self._delayed_tasks[key]

            return True
        except Exception as e:
            logger.error(f"Cache DELETE error for key '{key}': {e}")
            return False

    # ==================== Delayed Double-Delete ====================

    async def update_with_consistency(
        self,
        key: str,
        db_operation: Callable[[], Any],
        delay: float = 0.5,
        ttl: Optional[int] = None,
        update_cache: bool = True,
    ) -> Any:
        """Update data with delayed double-delete consistency pattern.

        Pattern:
        1. Delete cache (clear stale data)
        2. Execute DB operation
        3. Schedule delayed delete (prevent concurrent read rebuilding stale cache)
        4. Optionally update cache with new value

        Args:
            key: Cache key
            db_operation: Async function to update database
            delay: Delay before second delete (default 500ms)
            ttl: Cache TTL for new value
            update_cache: Whether to update cache with result

        Returns:
            Result from db_operation
        """
        # Step 1: Delete cache first
        await self.delete(key)

        # Step 2: Execute database operation
        try:
            result = await self._call_loader(db_operation)
        except Exception as e:
            logger.error(f"DB operation failed for key '{key}': {e}")
            raise

        # Step 3: Schedule delayed delete
        self._schedule_delayed_delete(key, delay)

        # Step 4: Update cache with new value
        if update_cache and result is not None:
            await self.set(key, result, ttl=ttl or 1800)

        return result

    def _schedule_delayed_delete(self, key: str, delay: float) -> None:
        """Schedule a delayed cache deletion.

        Args:
            key: Cache key
            delay: Delay in seconds
        """
        # Cancel existing task if any
        if key in self._delayed_tasks:
            self._delayed_tasks[key].cancel()

        async def delayed_delete():
            try:
                await asyncio.sleep(delay)
                await self.delete(key)
                self._stats.delayed_deletes += 1
                logger.debug(f"Delayed delete executed for key: {key}")
            except asyncio.CancelledError:
                pass
            except Exception as e:
                logger.error(f"Delayed delete failed for key '{key}': {e}")
            finally:
                if key in self._delayed_tasks:
                    del self._delayed_tasks[key]

        self._delayed_tasks[key] = asyncio.create_task(delayed_delete())

    # ==================== Batch Operations ====================

    async def invalidate_pattern(self, pattern: str) -> int:
        """Invalidate all keys matching pattern.

        Args:
            pattern: Redis key pattern (e.g., "txn:list:user123:*")

        Returns:
            Number of keys deleted
        """
        redis = await get_redis()
        if not redis:
            return 0

        try:
            # Scan for matching keys
            keys = []
            async for key in redis.scan_iter(match=pattern, count=100):
                keys.append(key)

            if keys:
                await redis.delete(*keys)
                self._stats.deletes += len(keys)
                logger.info(f"Invalidated {len(keys)} keys matching '{pattern}'")

            return len(keys)
        except Exception as e:
            logger.error(f"Pattern invalidation error for '{pattern}': {e}")
            return 0

    async def invalidate_user_cache(self, user_id: str) -> int:
        """Invalidate all cache entries for a user.

        Args:
            user_id: User ID

        Returns:
            Total keys deleted
        """
        count = 0
        patterns = [
            f"txn:list:{user_id}:*",
            f"txn:{user_id}:*",
            f"moneyage:{user_id}:*",
            f"stats:{user_id}:*",
            f"config:{user_id}:*",
        ]

        for pattern in patterns:
            count += await self.invalidate_pattern(pattern)

        return count

    # ==================== Consistency Validation ====================

    async def validate_consistency(
        self,
        key: str,
        db_loader: Callable[[], Any],
    ) -> bool:
        """Validate cache consistency against database.

        Args:
            key: Cache key
            db_loader: Function to load current DB value

        Returns:
            True if consistent, False if mismatch (cache will be invalidated)
        """
        redis = await get_redis()
        if not redis:
            return True  # Can't validate without Redis

        try:
            cached = await redis.get(key)
            if not cached:
                return True  # No cache entry, nothing to validate

            db_value = await self._call_loader(db_loader)
            if db_value is None:
                # DB has no value, cache should be deleted
                await self.delete(key)
                self._stats.consistency_errors += 1
                return False

            # Compare hashes
            cached_hash = self._compute_hash(self._deserialize(cached))
            db_hash = self._compute_hash(db_value)

            if cached_hash != db_hash:
                logger.warning(f"Cache consistency mismatch for key: {key}")
                await self.delete(key)
                self._stats.consistency_errors += 1
                return False

            return True

        except Exception as e:
            logger.error(f"Consistency validation error for key '{key}': {e}")
            return False

    # ==================== Helper Methods ====================

    async def _call_loader(self, loader: Callable) -> Any:
        """Call loader function (sync or async)."""
        if asyncio.iscoroutinefunction(loader):
            return await loader()
        return loader()

    def _serialize(self, value: Any) -> str:
        """Serialize value for storage."""
        return json.dumps(value, default=str, ensure_ascii=False)

    def _deserialize(self, data: str) -> Any:
        """Deserialize stored value."""
        return json.loads(data)

    def _compute_hash(self, value: Any) -> str:
        """Compute MD5 hash of value for consistency check."""
        json_str = json.dumps(value, sort_keys=True, default=str)
        return hashlib.md5(json_str.encode()).hexdigest()

    def get_version(self, key: str) -> int:
        """Get current version number for a key."""
        return self._versions.get(key, 0)

    def get_stats_summary(self) -> Dict[str, Any]:
        """Get statistics summary."""
        return {
            "hits": self._stats.hits,
            "misses": self._stats.misses,
            "writes": self._stats.writes,
            "deletes": self._stats.deletes,
            "delayed_deletes": self._stats.delayed_deletes,
            "consistency_errors": self._stats.consistency_errors,
            "hit_rate": round(self._stats.hit_rate, 4),
            "pending_delayed_deletes": len(self._delayed_tasks),
        }

    async def close(self) -> None:
        """Cleanup resources."""
        # Cancel all delayed tasks
        for task in self._delayed_tasks.values():
            task.cancel()
        self._delayed_tasks.clear()


# Global singleton instance
cache_service = CacheConsistencyService()


# ==================== Convenience Functions ====================

async def cached(
    key: str,
    loader: Callable[[], Any],
    ttl: int = 1800,
    config_type: Optional[str] = None,
) -> Any:
    """Convenience function for cache-aside pattern.

    Usage:
        user = await cached(f"user:{user_id}", lambda: get_user(user_id))
    """
    return await cache_service.get(key, loader=loader, ttl=ttl, config_type=config_type)


async def invalidate(key: str) -> bool:
    """Convenience function to invalidate cache."""
    return await cache_service.delete(key)


async def update_cached(
    key: str,
    db_operation: Callable[[], Any],
    delay: float = 0.5,
) -> Any:
    """Convenience function for update with consistency."""
    return await cache_service.update_with_consistency(key, db_operation, delay)
