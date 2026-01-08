"""Distributed lock service implementing RedLock algorithm.

Implements distributed locking from Chapter 33.3:
- RedLock algorithm for distributed lock acquisition
- Auto-renewal mechanism
- Deadlock prevention via TTL
- Fair lock support (optional)

Lock scenarios from design doc 33.3.1:
- Budget deduction: lock:budget:{userId}, TTL=10s, retry=3
- Money age recalculation: lock:moneyage:{userId}, TTL=60s, no retry
- Monthly settlement: lock:settlement:{userId}:{yearMonth}, TTL=300s, no retry
- Family ledger: lock:family:{familyId}, TTL=30s, retry=5

Reference: Design Document Chapter 33.3 - Distributed Lock Design
Code Block: 435
"""
import asyncio
import logging
import random
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Dict, Optional, TypeVar

from redis.asyncio import Redis

from app.core.redis import get_redis

logger = logging.getLogger(__name__)

T = TypeVar("T")


class LockStatus(Enum):
    """Lock acquisition status."""
    NOT_ACQUIRED = "not_acquired"
    ACQUIRED = "acquired"
    RELEASED = "released"
    EXPIRED = "expired"
    FAILED = "failed"


@dataclass
class LockOptions:
    """Lock acquisition options."""
    ttl: float = 30.0              # Lock TTL in seconds
    wait_timeout: float = 10.0     # Max wait time for acquisition
    auto_renew: bool = True        # Auto-renew before expiration
    renew_interval: float = 10.0   # Renewal interval in seconds
    max_renew_count: int = 10      # Maximum renewal attempts
    retry_count: int = 3           # Retry attempts for acquisition
    retry_delay: float = 0.1       # Base retry delay in seconds
    clock_drift_factor: float = 0.01  # Clock drift compensation


@dataclass
class DistributedLock:
    """Distributed lock instance."""
    resource: str
    owner_id: str
    acquired_at: float
    expires_at: float
    status: LockStatus = LockStatus.ACQUIRED
    renew_count: int = 0

    @property
    def is_expired(self) -> bool:
        return time.time() > self.expires_at

    @property
    def is_valid(self) -> bool:
        return self.status == LockStatus.ACQUIRED and not self.is_expired

    @property
    def time_to_live(self) -> float:
        return max(0, self.expires_at - time.time())


@dataclass
class LockResult:
    """Result of lock acquisition."""
    success: bool
    lock: Optional[DistributedLock] = None
    error: Optional[str] = None
    wait_time: Optional[float] = None


@dataclass
class LockStats:
    """Lock service statistics."""
    total_acquires: int = 0
    successful_acquires: int = 0
    failed_acquires: int = 0
    releases: int = 0
    renewals: int = 0
    timeouts: int = 0

    @property
    def success_rate(self) -> float:
        return self.successful_acquires / self.total_acquires if self.total_acquires > 0 else 0.0


# Pre-configured lock scenarios from design doc 33.3.1
LOCK_CONFIGS: Dict[str, LockOptions] = {
    "budget": LockOptions(
        ttl=10.0,
        retry_count=3,
        retry_delay=0.1,
    ),
    "money_age": LockOptions(
        ttl=60.0,
        retry_count=0,  # No retry, return cached value
    ),
    "settlement": LockOptions(
        ttl=300.0,
        retry_count=0,  # No retry, return "settlement in progress"
    ),
    "family": LockOptions(
        ttl=30.0,
        retry_count=5,
        retry_delay=0.2,
    ),
}


class DistributedLockService:
    """Distributed lock service implementing RedLock-like algorithm.

    Usage:
        # Direct lock management
        result = await lock_service.acquire("lock:budget:user123")
        if result.success:
            try:
                # Do work
            finally:
                await lock_service.release("lock:budget:user123", result.lock.owner_id)

        # Context manager style
        async with lock_service.lock("lock:budget:user123"):
            # Do work (auto-release)

        # Function wrapper
        result = await lock_service.with_lock(
            "lock:budget:user123",
            do_budget_update,
            options=LOCK_CONFIGS["budget"]
        )
    """

    _instance: Optional["DistributedLockService"] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._held_locks: Dict[str, DistributedLock] = {}
        self._renew_tasks: Dict[str, asyncio.Task] = {}
        self._stats = LockStats()
        self._initialized = True

    @property
    def stats(self) -> LockStats:
        """Get lock statistics."""
        return self._stats

    # ==================== Lock Acquisition ====================

    async def acquire(
        self,
        resource: str,
        options: Optional[LockOptions] = None,
        owner_id: Optional[str] = None,
    ) -> LockResult:
        """Acquire a distributed lock.

        Args:
            resource: Resource identifier to lock
            options: Lock options
            owner_id: Custom owner ID (auto-generated if not provided)

        Returns:
            LockResult with success status and lock info
        """
        options = options or LockOptions()
        owner_id = owner_id or str(uuid.uuid4())
        start_time = time.time()

        self._stats.total_acquires += 1

        # Retry loop
        for attempt in range(options.retry_count + 1):
            result = await self._try_acquire(resource, owner_id, options)

            if result.success:
                self._stats.successful_acquires += 1

                # Setup auto-renewal
                if options.auto_renew and result.lock:
                    self._setup_auto_renew(result.lock, options)

                result.wait_time = time.time() - start_time
                return result

            # Check wait timeout
            elapsed = time.time() - start_time
            if elapsed >= options.wait_timeout:
                self._stats.failed_acquires += 1
                self._stats.timeouts += 1
                return LockResult(
                    success=False,
                    error="Wait timeout exceeded",
                    wait_time=elapsed,
                )

            # Retry delay with jitter
            if attempt < options.retry_count:
                jitter = random.uniform(0, 0.05)
                await asyncio.sleep(options.retry_delay * (attempt + 1) + jitter)

        self._stats.failed_acquires += 1
        return LockResult(
            success=False,
            error=f"Max retry count ({options.retry_count}) exceeded",
            wait_time=time.time() - start_time,
        )

    async def _try_acquire(
        self,
        resource: str,
        owner_id: str,
        options: LockOptions,
    ) -> LockResult:
        """Single attempt to acquire lock."""
        redis = await get_redis()
        if not redis:
            return LockResult(success=False, error="Redis not available")

        try:
            # Use SET NX with expiration for atomic lock
            lock_key = resource
            ttl_ms = int(options.ttl * 1000)

            acquired = await redis.set(
                lock_key,
                owner_id,
                nx=True,  # Only set if not exists
                px=ttl_ms,  # Expiration in milliseconds
            )

            if acquired:
                now = time.time()
                # Account for clock drift
                drift = options.ttl * options.clock_drift_factor + 0.002
                validity = options.ttl - drift

                lock = DistributedLock(
                    resource=resource,
                    owner_id=owner_id,
                    acquired_at=now,
                    expires_at=now + validity,
                )

                self._held_locks[resource] = lock

                logger.debug(f"Lock acquired: {resource} by {owner_id[:8]}")
                return LockResult(success=True, lock=lock)

            return LockResult(success=False, error="Lock already held")

        except Exception as e:
            logger.error(f"Lock acquisition error for '{resource}': {e}")
            return LockResult(success=False, error=str(e))

    # ==================== Lock Release ====================

    async def release(
        self,
        resource: str,
        owner_id: Optional[str] = None,
    ) -> bool:
        """Release a distributed lock.

        Args:
            resource: Resource identifier
            owner_id: Owner ID to verify (optional but recommended)

        Returns:
            True if successfully released
        """
        lock = self._held_locks.get(resource)
        if not lock:
            return False

        if owner_id and lock.owner_id != owner_id:
            logger.warning(f"Lock release denied: owner mismatch for {resource}")
            return False

        # Cancel auto-renewal
        self._cancel_auto_renew(resource)

        redis = await get_redis()
        if not redis:
            # Can't release in Redis, but clean up locally
            del self._held_locks[resource]
            return False

        try:
            # Use Lua script for atomic check-and-delete
            lua_script = """
            if redis.call("get", KEYS[1]) == ARGV[1] then
                return redis.call("del", KEYS[1])
            else
                return 0
            end
            """

            result = await redis.eval(lua_script, 1, resource, lock.owner_id)

            if result:
                lock.status = LockStatus.RELEASED
                del self._held_locks[resource]
                self._stats.releases += 1
                logger.debug(f"Lock released: {resource}")
                return True

            return False

        except Exception as e:
            logger.error(f"Lock release error for '{resource}': {e}")
            return False

    # ==================== Auto-Renewal ====================

    def _setup_auto_renew(self, lock: DistributedLock, options: LockOptions) -> None:
        """Setup automatic lock renewal."""
        # Cancel existing renewal task
        self._cancel_auto_renew(lock.resource)

        async def renew_loop():
            while lock.resource in self._held_locks:
                try:
                    await asyncio.sleep(options.renew_interval)

                    if lock.resource not in self._held_locks:
                        break

                    if lock.renew_count >= options.max_renew_count:
                        logger.warning(f"Max renew count reached for lock: {lock.resource}")
                        break

                    success = await self._renew_lock(lock, options)
                    if not success:
                        logger.warning(f"Lock renewal failed for: {lock.resource}")
                        break

                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.error(f"Lock renewal error for '{lock.resource}': {e}")
                    break

        self._renew_tasks[lock.resource] = asyncio.create_task(renew_loop())

    def _cancel_auto_renew(self, resource: str) -> None:
        """Cancel auto-renewal for a resource."""
        task = self._renew_tasks.pop(resource, None)
        if task:
            task.cancel()

    async def _renew_lock(self, lock: DistributedLock, options: LockOptions) -> bool:
        """Renew a lock's TTL."""
        redis = await get_redis()
        if not redis:
            return False

        try:
            # Use Lua script to atomically check owner and extend
            lua_script = """
            if redis.call("get", KEYS[1]) == ARGV[1] then
                return redis.call("pexpire", KEYS[1], ARGV[2])
            else
                return 0
            end
            """

            ttl_ms = int(options.ttl * 1000)
            result = await redis.eval(lua_script, 1, lock.resource, lock.owner_id, ttl_ms)

            if result:
                lock.renew_count += 1
                lock.expires_at = time.time() + options.ttl
                self._stats.renewals += 1
                logger.debug(f"Lock renewed: {lock.resource} ({lock.renew_count}/{options.max_renew_count})")
                return True

            # Lock was lost
            lock.status = LockStatus.EXPIRED
            if lock.resource in self._held_locks:
                del self._held_locks[lock.resource]
            return False

        except Exception as e:
            logger.error(f"Lock renewal error for '{lock.resource}': {e}")
            return False

    # ==================== Convenience Methods ====================

    async def with_lock(
        self,
        resource: str,
        operation: Callable[[], T],
        options: Optional[LockOptions] = None,
    ) -> T:
        """Execute operation with lock protection.

        Args:
            resource: Resource to lock
            operation: Async function to execute
            options: Lock options

        Returns:
            Result from operation

        Raises:
            LockAcquisitionError: If lock cannot be acquired
        """
        result = await self.acquire(resource, options)

        if not result.success:
            raise LockAcquisitionError(resource, result.error or "Unknown error")

        try:
            if asyncio.iscoroutinefunction(operation):
                return await operation()
            return operation()
        finally:
            await self.release(resource, result.lock.owner_id)

    async def try_with_lock(
        self,
        resource: str,
        operation: Callable[[], T],
        default: T = None,
        options: Optional[LockOptions] = None,
    ) -> T:
        """Try to execute operation with lock, return default if lock unavailable.

        Args:
            resource: Resource to lock
            operation: Async function to execute
            default: Default value if lock cannot be acquired
            options: Lock options (wait_timeout=0 for no wait)

        Returns:
            Result from operation or default
        """
        no_wait_options = options or LockOptions()
        no_wait_options.wait_timeout = 0
        no_wait_options.retry_count = 0

        result = await self.acquire(resource, no_wait_options)

        if not result.success:
            return default

        try:
            if asyncio.iscoroutinefunction(operation):
                return await operation()
            return operation()
        finally:
            await self.release(resource, result.lock.owner_id)

    # ==================== Lock Helpers for Common Scenarios ====================

    async def acquire_budget_lock(self, user_id: str) -> LockResult:
        """Acquire lock for budget operations.

        Scenario: Prevent budget over-deduction
        Key: lock:budget:{userId}
        TTL: 10s, Retry: 3 times @ 100ms
        """
        return await self.acquire(
            f"lock:budget:{user_id}",
            LOCK_CONFIGS["budget"],
        )

    async def acquire_money_age_lock(self, user_id: str) -> LockResult:
        """Acquire lock for money age recalculation.

        Scenario: Prevent concurrent recalculation
        Key: lock:moneyage:{userId}
        TTL: 60s, No retry (return cached value if locked)
        """
        return await self.acquire(
            f"lock:moneyage:{user_id}",
            LOCK_CONFIGS["money_age"],
        )

    async def acquire_settlement_lock(self, user_id: str, year_month: str) -> LockResult:
        """Acquire lock for monthly settlement.

        Scenario: Prevent duplicate settlement
        Key: lock:settlement:{userId}:{yearMonth}
        TTL: 300s, No retry (return "settlement in progress")
        """
        return await self.acquire(
            f"lock:settlement:{user_id}:{year_month}",
            LOCK_CONFIGS["settlement"],
        )

    async def acquire_family_lock(self, family_id: str) -> LockResult:
        """Acquire lock for family ledger operations.

        Scenario: Multi-member mutual exclusion
        Key: lock:family:{familyId}
        TTL: 30s, Retry: 5 times @ 200ms
        """
        return await self.acquire(
            f"lock:family:{family_id}",
            LOCK_CONFIGS["family"],
        )

    # ==================== Status Methods ====================

    def is_locked(self, resource: str) -> bool:
        """Check if a resource is currently locked by this service."""
        lock = self._held_locks.get(resource)
        return lock is not None and lock.is_valid

    def get_lock_info(self, resource: str) -> Optional[DistributedLock]:
        """Get info about a held lock."""
        return self._held_locks.get(resource)

    def get_stats_summary(self) -> Dict[str, Any]:
        """Get statistics summary."""
        return {
            "total_acquires": self._stats.total_acquires,
            "successful_acquires": self._stats.successful_acquires,
            "failed_acquires": self._stats.failed_acquires,
            "releases": self._stats.releases,
            "renewals": self._stats.renewals,
            "timeouts": self._stats.timeouts,
            "success_rate": round(self._stats.success_rate, 4),
            "currently_held": len(self._held_locks),
        }

    async def close(self) -> None:
        """Cleanup: release all locks and cancel tasks."""
        # Cancel all renewal tasks
        for task in self._renew_tasks.values():
            task.cancel()
        self._renew_tasks.clear()

        # Release all locks
        for resource in list(self._held_locks.keys()):
            await self.release(resource)


class LockAcquisitionError(Exception):
    """Exception raised when lock acquisition fails."""

    def __init__(self, resource: str, message: str):
        self.resource = resource
        self.message = message
        super().__init__(f"Failed to acquire lock on '{resource}': {message}")


# Global singleton instance
distributed_lock = DistributedLockService()


# ==================== Convenience Functions ====================

async def with_budget_lock(user_id: str, operation: Callable[[], T]) -> T:
    """Execute operation with budget lock."""
    return await distributed_lock.with_lock(
        f"lock:budget:{user_id}",
        operation,
        LOCK_CONFIGS["budget"],
    )


async def with_family_lock(family_id: str, operation: Callable[[], T]) -> T:
    """Execute operation with family lock."""
    return await distributed_lock.with_lock(
        f"lock:family:{family_id}",
        operation,
        LOCK_CONFIGS["family"],
    )
