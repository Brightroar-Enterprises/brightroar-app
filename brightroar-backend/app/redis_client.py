import redis.asyncio as aioredis
from app.config import get_settings
import json
from typing import Any

settings = get_settings()

redis_client: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    global redis_client
    if redis_client is None:
        redis_client = await aioredis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
    return redis_client


async def close_redis():
    global redis_client
    if redis_client:
        await redis_client.close()
        redis_client = None


# ── Helper functions ──────────────────────────────────────────────────────────

async def cache_set(key: str, value: Any, ttl: int = 300):
    """Store a value in Redis with optional TTL (seconds)."""
    r = await get_redis()
    await r.set(key, json.dumps(value), ex=ttl)


async def cache_get(key: str) -> Any | None:
    """Retrieve a cached value from Redis."""
    r = await get_redis()
    data = await r.get(key)
    return json.loads(data) if data else None


async def cache_delete(key: str):
    r = await get_redis()
    await r.delete(key)


async def cache_delete_pattern(pattern: str):
    """Delete all keys matching a pattern (e.g. 'user:123:*')."""
    r = await get_redis()
    keys = await r.keys(pattern)
    if keys:
        await r.delete(*keys)


async def blacklist_token(jti: str, ttl: int):
    """Add a JWT ID to the blacklist (used on logout)."""
    r = await get_redis()
    await r.set(f"blacklist:{jti}", "1", ex=ttl)


async def is_token_blacklisted(jti: str) -> bool:
    r = await get_redis()
    return bool(await r.exists(f"blacklist:{jti}"))


async def set_refresh_token(user_id: str, token: str, ttl: int):
    r = await get_redis()
    await r.set(f"refresh:{user_id}", token, ex=ttl)


async def get_refresh_token(user_id: str) -> str | None:
    r = await get_redis()
    return await r.get(f"refresh:{user_id}")


async def delete_refresh_token(user_id: str):
    r = await get_redis()
    await r.delete(f"refresh:{user_id}")
