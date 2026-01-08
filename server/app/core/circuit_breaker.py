"""Circuit breaker pattern implementation based on Chapter 32 design.

Circuit breaker states:
- CLOSED: Normal operation, requests flow through
- OPEN: Circuit tripped, requests fail fast
- HALF_OPEN: Testing if service recovered

Configuration:
- failure_threshold: Number of failures before opening circuit
- success_threshold: Number of successes in half-open to close circuit
- timeout: Time in seconds before transitioning from OPEN to HALF_OPEN
"""
import asyncio
import logging
import time
from enum import Enum
from typing import Callable, Optional, Any, TypeVar, Generic
from dataclasses import dataclass, field
from functools import wraps

logger = logging.getLogger(__name__)

T = TypeVar("T")


class CircuitState(Enum):
    """Circuit breaker states."""
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"


@dataclass
class CircuitBreakerConfig:
    """Circuit breaker configuration."""
    failure_threshold: int = 5           # Failures before opening
    success_threshold: int = 3           # Successes in half-open to close
    timeout: float = 30.0                # Seconds before half-open
    half_open_max_calls: int = 3         # Max concurrent calls in half-open
    excluded_exceptions: tuple = ()      # Exceptions that don't count as failures


@dataclass
class CircuitStats:
    """Circuit breaker statistics."""
    total_calls: int = 0
    total_failures: int = 0
    total_successes: int = 0
    consecutive_failures: int = 0
    consecutive_successes: int = 0
    last_failure_time: Optional[float] = None
    last_success_time: Optional[float] = None
    state_changes: int = 0


class CircuitBreakerError(Exception):
    """Exception raised when circuit is open."""

    def __init__(self, circuit_name: str, remaining_timeout: float):
        self.circuit_name = circuit_name
        self.remaining_timeout = remaining_timeout
        super().__init__(
            f"Circuit '{circuit_name}' is open. "
            f"Retry after {remaining_timeout:.1f} seconds."
        )


class CircuitBreaker:
    """Circuit breaker implementation with async support."""

    def __init__(
        self,
        name: str,
        config: Optional[CircuitBreakerConfig] = None,
        fallback: Optional[Callable] = None,
    ):
        self.name = name
        self.config = config or CircuitBreakerConfig()
        self.fallback = fallback

        self._state = CircuitState.CLOSED
        self._stats = CircuitStats()
        self._opened_at: Optional[float] = None
        self._half_open_calls: int = 0
        self._lock = asyncio.Lock()

    @property
    def state(self) -> CircuitState:
        """Get current circuit state."""
        return self._state

    @property
    def stats(self) -> CircuitStats:
        """Get circuit statistics."""
        return self._stats

    @property
    def is_closed(self) -> bool:
        return self._state == CircuitState.CLOSED

    @property
    def is_open(self) -> bool:
        return self._state == CircuitState.OPEN

    @property
    def is_half_open(self) -> bool:
        return self._state == CircuitState.HALF_OPEN

    async def _transition_to(self, new_state: CircuitState):
        """Transition to a new state."""
        old_state = self._state
        self._state = new_state
        self._stats.state_changes += 1

        if new_state == CircuitState.OPEN:
            self._opened_at = time.time()
            self._half_open_calls = 0
            logger.warning(
                f"Circuit '{self.name}' OPENED after {self._stats.consecutive_failures} failures"
            )
        elif new_state == CircuitState.HALF_OPEN:
            self._half_open_calls = 0
            logger.info(f"Circuit '{self.name}' transitioning to HALF_OPEN")
        elif new_state == CircuitState.CLOSED:
            self._stats.consecutive_failures = 0
            logger.info(f"Circuit '{self.name}' CLOSED after recovery")

    async def _should_allow_request(self) -> bool:
        """Check if a request should be allowed."""
        if self._state == CircuitState.CLOSED:
            return True

        if self._state == CircuitState.OPEN:
            # Check if timeout has passed
            if self._opened_at and time.time() - self._opened_at >= self.config.timeout:
                await self._transition_to(CircuitState.HALF_OPEN)
                return True
            return False

        if self._state == CircuitState.HALF_OPEN:
            # Allow limited requests in half-open state
            return self._half_open_calls < self.config.half_open_max_calls

        return False

    def _get_remaining_timeout(self) -> float:
        """Get remaining timeout before half-open."""
        if self._opened_at:
            elapsed = time.time() - self._opened_at
            return max(0, self.config.timeout - elapsed)
        return self.config.timeout

    async def _record_success(self):
        """Record a successful call."""
        self._stats.total_calls += 1
        self._stats.total_successes += 1
        self._stats.consecutive_successes += 1
        self._stats.consecutive_failures = 0
        self._stats.last_success_time = time.time()

        if self._state == CircuitState.HALF_OPEN:
            if self._stats.consecutive_successes >= self.config.success_threshold:
                await self._transition_to(CircuitState.CLOSED)

    async def _record_failure(self, error: Exception):
        """Record a failed call."""
        # Check if exception should be excluded
        if isinstance(error, self.config.excluded_exceptions):
            return

        self._stats.total_calls += 1
        self._stats.total_failures += 1
        self._stats.consecutive_failures += 1
        self._stats.consecutive_successes = 0
        self._stats.last_failure_time = time.time()

        if self._state == CircuitState.HALF_OPEN:
            # Any failure in half-open reopens the circuit
            await self._transition_to(CircuitState.OPEN)
        elif self._state == CircuitState.CLOSED:
            if self._stats.consecutive_failures >= self.config.failure_threshold:
                await self._transition_to(CircuitState.OPEN)

    async def call(self, func: Callable[..., Any], *args, **kwargs) -> Any:
        """Execute a function through the circuit breaker."""
        async with self._lock:
            allowed = await self._should_allow_request()

        if not allowed:
            remaining = self._get_remaining_timeout()
            logger.warning(
                f"Circuit '{self.name}' is OPEN, rejecting request. "
                f"Retry in {remaining:.1f}s"
            )
            if self.fallback:
                return await self.fallback(*args, **kwargs) if asyncio.iscoroutinefunction(self.fallback) else self.fallback(*args, **kwargs)
            raise CircuitBreakerError(self.name, remaining)

        if self._state == CircuitState.HALF_OPEN:
            self._half_open_calls += 1

        try:
            # Execute the function
            if asyncio.iscoroutinefunction(func):
                result = await func(*args, **kwargs)
            else:
                result = func(*args, **kwargs)

            async with self._lock:
                await self._record_success()

            return result

        except Exception as e:
            async with self._lock:
                await self._record_failure(e)

            if self.fallback:
                logger.info(f"Circuit '{self.name}' using fallback after error: {e}")
                return await self.fallback(*args, **kwargs) if asyncio.iscoroutinefunction(self.fallback) else self.fallback(*args, **kwargs)
            raise

    def reset(self):
        """Reset the circuit breaker to closed state."""
        self._state = CircuitState.CLOSED
        self._stats = CircuitStats()
        self._opened_at = None
        self._half_open_calls = 0
        logger.info(f"Circuit '{self.name}' manually reset")

    def get_status(self) -> dict:
        """Get current circuit breaker status."""
        return {
            "name": self.name,
            "state": self._state.value,
            "stats": {
                "total_calls": self._stats.total_calls,
                "total_failures": self._stats.total_failures,
                "total_successes": self._stats.total_successes,
                "consecutive_failures": self._stats.consecutive_failures,
                "consecutive_successes": self._stats.consecutive_successes,
                "state_changes": self._stats.state_changes,
            },
            "config": {
                "failure_threshold": self.config.failure_threshold,
                "success_threshold": self.config.success_threshold,
                "timeout": self.config.timeout,
            },
            "remaining_timeout": self._get_remaining_timeout() if self.is_open else None,
        }


# Global circuit breaker registry
_circuit_breakers: dict[str, CircuitBreaker] = {}


def get_circuit_breaker(
    name: str,
    config: Optional[CircuitBreakerConfig] = None,
    fallback: Optional[Callable] = None,
) -> CircuitBreaker:
    """Get or create a circuit breaker by name."""
    if name not in _circuit_breakers:
        _circuit_breakers[name] = CircuitBreaker(name, config, fallback)
    return _circuit_breakers[name]


def get_all_circuit_breakers() -> dict[str, CircuitBreaker]:
    """Get all registered circuit breakers."""
    return _circuit_breakers.copy()


def circuit_breaker(
    name: str,
    failure_threshold: int = 5,
    success_threshold: int = 3,
    timeout: float = 30.0,
    fallback: Optional[Callable] = None,
    excluded_exceptions: tuple = (),
):
    """Decorator to apply circuit breaker to a function."""
    config = CircuitBreakerConfig(
        failure_threshold=failure_threshold,
        success_threshold=success_threshold,
        timeout=timeout,
        excluded_exceptions=excluded_exceptions,
    )

    def decorator(func: Callable) -> Callable:
        cb = get_circuit_breaker(name, config, fallback)

        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            return await cb.call(func, *args, **kwargs)

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            return asyncio.get_event_loop().run_until_complete(
                cb.call(func, *args, **kwargs)
            )

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper

    return decorator


# Pre-configured circuit breakers for common services
AI_SERVICE_CB = CircuitBreakerConfig(
    failure_threshold=3,
    success_threshold=2,
    timeout=60.0,
)

DATABASE_CB = CircuitBreakerConfig(
    failure_threshold=5,
    success_threshold=3,
    timeout=30.0,
)

EXTERNAL_API_CB = CircuitBreakerConfig(
    failure_threshold=5,
    success_threshold=3,
    timeout=45.0,
)
