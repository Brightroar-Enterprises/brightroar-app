from fastapi import APIRouter, Depends, Query, HTTPException
from app.services.binance_service import BinanceService
from app.core.dependencies import get_current_active_user
from app.models.user import User
from app.redis_client import cache_get, cache_set

router = APIRouter(prefix="/market", tags=["Market Data (Binance)"])

SUPPORTED_SYMBOLS = {
    "BTCUSDT", "ETHUSDT", "SOLUSDT", "DOTUSDT",
    "BNBUSDT", "ADAUSDT", "XRPUSDT", "LTCUSDT",
}


def _validate_symbol(symbol: str) -> str:
    sym = symbol.upper()
    if sym not in SUPPORTED_SYMBOLS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported symbol '{sym}'. Supported: {sorted(SUPPORTED_SYMBOLS)}",
        )
    return sym


@router.get("/prices")
async def get_prices(
    symbols: str = Query(
        "BTCUSDT,ETHUSDT,SOLUSDT,DOTUSDT",
        description="Comma-separated Binance symbols",
    ),
    _: User = Depends(get_current_active_user),
):
    """Latest price for one or more symbols."""
    symbol_list = [s.strip().upper() for s in symbols.split(",")]
    cache_key = f"market:prices:{','.join(sorted(symbol_list))}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    binance = BinanceService()
    prices = await binance.get_prices(symbol_list)
    result = {k: str(v) for k, v in prices.items()}
    await cache_set(cache_key, result, ttl=10)
    return result


@router.get("/ticker/{symbol}")
async def get_ticker(
    symbol: str,
    _: User = Depends(get_current_active_user),
):
    """24h rolling stats for a single symbol."""
    sym = _validate_symbol(symbol)
    cache_key = f"market:ticker:{sym}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    binance = BinanceService()
    tickers = await binance.get_24h_tickers([sym])
    result = tickers[0] if tickers else {}
    await cache_set(cache_key, result, ttl=15)
    return result


@router.get("/klines/{symbol}")
async def get_klines(
    symbol: str,
    interval: str = Query("1d", pattern="^(1m|5m|15m|1h|4h|1d|1w)$"),
    limit: int = Query(30, ge=1, le=500),
    _: User = Depends(get_current_active_user),
):
    """Candlestick data for charting."""
    sym = _validate_symbol(symbol)
    cache_key = f"market:klines:{sym}:{interval}:{limit}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    binance = BinanceService()
    klines = await binance.get_klines(sym, interval=interval, limit=limit)

    ttl = 60 if interval in ("1d", "1w") else 30
    await cache_set(cache_key, klines, ttl=ttl)
    return klines


@router.get("/orderbook/{symbol}")
async def get_order_book(
    symbol: str,
    limit: int = Query(10, ge=5, le=100),
    _: User = Depends(get_current_active_user),
):
    """Order book depth."""
    sym = _validate_symbol(symbol)
    binance = BinanceService()
    return await binance.get_order_book(sym, limit=limit)
