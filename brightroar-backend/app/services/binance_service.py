import httpx
import hmac
import hashlib
import time
from decimal import Decimal
from typing import Any
import logging
import asyncio

logger = logging.getLogger(__name__)

BINANCE_BASE_URL = "https://api.binance.com"
BINANCE_FUTURES_URL = "https://fapi.binance.com"
BINANCE_DAPI_URL = "https://dapi.binance.com"   # coin-m futures

STABLECOINS = {"USDT", "BUSD", "USDC", "TUSD", "DAI", "FDUSD", "USDP"}


class BinanceService:
    """
    Binance REST API client covering:
      - Spot wallet         (/api/v3/account)
      - Funding wallet      (/sapi/v1/asset/get-funding-asset)
      - USD-M Futures       (fapi /v2/account)
      - COIN-M Futures      (dapi /v1/account)
      - Margin (cross)      (/sapi/v1/margin/account)
      - Isolated Margin     (/sapi/v1/margin/isolated/account)
    """

    def __init__(self, timeout: float = 15.0):
        self.timeout = timeout

    # ── Signing ────────────────────────────────────────────────────────────

    @staticmethod
    def _sign(params: dict, api_secret: str) -> str:
        query_string = "&".join(f"{k}={v}" for k, v in params.items())
        return hmac.new(
            api_secret.encode("utf-8"),
            query_string.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    @staticmethod
    def _now_ms() -> int:
        return int(time.time() * 1000)

    # ── HTTP ───────────────────────────────────────────────────────────────

    async def _get(
        self,
        path: str,
        params: dict | None = None,
        api_key: str | None = None,
        api_secret: str | None = None,
        base_url: str = BINANCE_BASE_URL,
    ) -> Any:
        url = f"{base_url}{path}"
        headers: dict[str, str] = {}
        p = dict(params or {})

        if api_key:
            headers["X-MBX-APIKEY"] = api_key

        if api_secret:
            p["timestamp"] = self._now_ms()
            p["recvWindow"] = 5000
            p["signature"] = self._sign(p, api_secret)

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                resp = await client.get(url, params=p, headers=headers)
                resp.raise_for_status()
                return resp.json()
            except httpx.HTTPStatusError as e:
                body = {}
                try:
                    body = e.response.json()
                except Exception:
                    pass
                logger.warning(f"Binance {e.response.status_code} on {path}: {body}")
                raise BinanceAPIError(
                    status_code=e.response.status_code,
                    message=body.get("msg", "Binance API error"),
                    code=body.get("code"),
                )
            except httpx.RequestError as e:
                logger.error(f"Binance connection error on {path}: {e}")
                raise BinanceConnectionError(str(e))

    async def _post(
        self,
        path: str,
        params: dict | None = None,
        api_key: str | None = None,
        api_secret: str | None = None,
        base_url: str = BINANCE_BASE_URL,
    ) -> Any:
        url = f"{base_url}{path}"
        headers: dict[str, str] = {}
        p = dict(params or {})

        if api_key:
            headers["X-MBX-APIKEY"] = api_key

        if api_secret:
            p["timestamp"] = self._now_ms()
            p["recvWindow"] = 5000
            p["signature"] = self._sign(p, api_secret)

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                resp = await client.post(url, params=p, headers=headers)
                resp.raise_for_status()
                return resp.json()
            except httpx.HTTPStatusError as e:
                body = {}
                try:
                    body = e.response.json()
                except Exception:
                    pass
                logger.warning(f"Binance POST {e.response.status_code} on {path}: {body}")
                raise BinanceAPIError(
                    status_code=e.response.status_code,
                    message=body.get("msg", "Binance API error"),
                    code=body.get("code"),
                )

    # ==========================================================================
    # PRICE HELPERS
    # ==========================================================================

    async def get_prices(self, symbols: list[str]) -> dict[str, Decimal]:
        data = await self._get("/api/v3/ticker/price")
        price_map = {item["symbol"]: Decimal(item["price"]) for item in data}
        return {s: price_map.get(s, Decimal("0")) for s in symbols}

    async def get_single_price(self, symbol: str) -> Decimal:
        data = await self._get("/api/v3/ticker/price", params={"symbol": symbol})
        return Decimal(data["price"])

    async def _build_price_map(self) -> dict[str, Decimal]:
        """Fetch all USDT prices in one call."""
        data = await self._get("/api/v3/ticker/price")
        price_map: dict[str, Decimal] = {}
        for item in data:
            sym = item["symbol"]
            if sym.endswith("USDT"):
                asset = sym[:-4]
                price_map[asset] = Decimal(item["price"])
        # Stablecoins = $1
        for sc in STABLECOINS:
            price_map[sc] = Decimal("1")
        return price_map

    def _usd_value(self, asset: str, qty: Decimal, price_map: dict[str, Decimal]) -> Decimal:
        price = price_map.get(asset, Decimal("0"))
        return qty * price

    # ==========================================================================
    # SPOT WALLET
    # ==========================================================================

    async def get_spot_balances(self, api_key: str, api_secret: str) -> list[dict]:
        data = await self._get("/api/v3/account", params={}, api_key=api_key, api_secret=api_secret)
        result = []
        for b in data.get("balances", []):
            free = Decimal(b["free"])
            locked = Decimal(b["locked"])
            total = free + locked
            if total > Decimal("0"):
                result.append({"asset": b["asset"], "free": str(free), "locked": str(locked), "total": str(total)})
        return result

    # ==========================================================================
    # FUNDING WALLET
    # ==========================================================================

    async def get_funding_balances(self, api_key: str, api_secret: str) -> list[dict]:
        """POST /sapi/v1/asset/get-funding-asset"""
        try:
            data = await self._post(
                "/sapi/v1/asset/get-funding-asset",
                params={"needBtcValuation": "false"},
                api_key=api_key, api_secret=api_secret,
            )
            result = []
            for b in (data or []):
                free = Decimal(str(b.get("free", "0")))
                locked = Decimal(str(b.get("locked", "0")))
                freeze = Decimal(str(b.get("freeze", "0")))
                withdrawing = Decimal(str(b.get("withdrawing", "0")))
                total = free + locked + freeze + withdrawing
                if total > Decimal("0"):
                    result.append({"asset": b["asset"], "free": str(free), "locked": str(locked), "total": str(total)})
            return result
        except BinanceAPIError as e:
            logger.warning(f"Funding wallet not accessible: {e.message}")
            return []

    # ==========================================================================
    # USD-M FUTURES WALLET
    # ==========================================================================

    async def get_futures_usdm_balances(self, api_key: str, api_secret: str) -> list[dict]:
        """GET /fapi/v2/account — USD-M perpetual futures"""
        try:
            data = await self._get(
                "/fapi/v2/account",
                params={},
                api_key=api_key, api_secret=api_secret,
                base_url=BINANCE_FUTURES_URL,
            )
            result = []
            for b in data.get("assets", []):
                wallet_balance = Decimal(str(b.get("walletBalance", "0")))
                unrealized_pnl = Decimal(str(b.get("unrealizedProfit", "0")))
                total = wallet_balance + unrealized_pnl
                if wallet_balance > Decimal("0"):
                    result.append({
                        "asset": b["asset"],
                        "wallet_balance": str(wallet_balance),
                        "unrealized_pnl": str(unrealized_pnl),
                        "total": str(total),
                        "free": str(b.get("availableBalance", "0")),
                        "locked": "0",
                    })
            return result
        except BinanceAPIError as e:
            logger.warning(f"USD-M Futures not accessible: {e.message}")
            return []

    # ==========================================================================
    # COIN-M FUTURES WALLET
    # ==========================================================================

    async def get_futures_coinm_balances(self, api_key: str, api_secret: str) -> list[dict]:
        """GET /dapi/v1/account — COIN-M perpetual futures"""
        try:
            data = await self._get(
                "/dapi/v1/account",
                params={},
                api_key=api_key, api_secret=api_secret,
                base_url=BINANCE_DAPI_URL,
            )
            result = []
            for b in data.get("assets", []):
                wallet_balance = Decimal(str(b.get("walletBalance", "0")))
                unrealized_pnl = Decimal(str(b.get("unrealizedProfit", "0")))
                if wallet_balance > Decimal("0"):
                    result.append({
                        "asset": b["asset"],
                        "wallet_balance": str(wallet_balance),
                        "unrealized_pnl": str(unrealized_pnl),
                        "total": str(wallet_balance + unrealized_pnl),
                        "free": str(b.get("availableBalance", "0")),
                        "locked": "0",
                    })
            return result
        except BinanceAPIError as e:
            logger.warning(f"COIN-M Futures not accessible: {e.message}")
            return []

    # ==========================================================================
    # CROSS MARGIN WALLET
    # ==========================================================================

    async def get_cross_margin_balances(self, api_key: str, api_secret: str) -> list[dict]:
        """GET /sapi/v1/margin/account — cross margin"""
        try:
            data = await self._get(
                "/sapi/v1/margin/account",
                params={},
                api_key=api_key, api_secret=api_secret,
            )
            result = []
            for b in data.get("userAssets", []):
                free = Decimal(str(b.get("free", "0")))
                locked = Decimal(str(b.get("locked", "0")))
                borrowed = Decimal(str(b.get("borrowed", "0")))
                net = Decimal(str(b.get("netAsset", "0")))
                total = free + locked
                if total > Decimal("0"):
                    result.append({
                        "asset": b["asset"],
                        "free": str(free),
                        "locked": str(locked),
                        "borrowed": str(borrowed),
                        "net_asset": str(net),
                        "total": str(total),
                    })
            return result
        except BinanceAPIError as e:
            logger.warning(f"Cross margin not accessible: {e.message}")
            return []

    # ==========================================================================
    # ISOLATED MARGIN WALLET
    # ==========================================================================

    async def get_isolated_margin_balances(self, api_key: str, api_secret: str) -> list[dict]:
        """GET /sapi/v1/margin/isolated/account — isolated margin pairs"""
        try:
            data = await self._get(
                "/sapi/v1/margin/isolated/account",
                params={},
                api_key=api_key, api_secret=api_secret,
            )
            result = []
            for pair in data.get("assets", []):
                for side in ["baseAsset", "quoteAsset"]:
                    b = pair.get(side, {})
                    asset = b.get("asset", "")
                    free = Decimal(str(b.get("free", "0")))
                    locked = Decimal(str(b.get("locked", "0")))
                    borrowed = Decimal(str(b.get("borrowed", "0")))
                    net = Decimal(str(b.get("netAsset", "0")))
                    total = free + locked
                    if total > Decimal("0") and asset:
                        result.append({
                            "asset": asset,
                            "pair": pair.get("symbol", ""),
                            "free": str(free),
                            "locked": str(locked),
                            "borrowed": str(borrowed),
                            "net_asset": str(net),
                            "total": str(total),
                        })
            return result
        except BinanceAPIError as e:
            logger.warning(f"Isolated margin not accessible: {e.message}")
            return []

    # ==========================================================================
    # FULL ACCOUNT SNAPSHOT — all wallets combined
    # ==========================================================================

    async def get_full_account_snapshot(
        self,
        api_key: str,
        api_secret: str,
    ) -> dict:
        """
        Fetches balances from ALL wallet types in parallel:
          spot, funding, USD-M futures, COIN-M futures, cross margin, isolated margin
        Returns total USD value + per-wallet-type breakdown.
        """
        # Fetch all wallet types in parallel
        results = await asyncio.gather(
            self.get_spot_balances(api_key, api_secret),
            self.get_funding_balances(api_key, api_secret),
            self.get_futures_usdm_balances(api_key, api_secret),
            self.get_futures_coinm_balances(api_key, api_secret),
            self.get_cross_margin_balances(api_key, api_secret),
            self.get_isolated_margin_balances(api_key, api_secret),
            return_exceptions=True,
        )

        spot_balances      = results[0] if not isinstance(results[0], Exception) else []
        funding_balances   = results[1] if not isinstance(results[1], Exception) else []
        futures_usdm       = results[2] if not isinstance(results[2], Exception) else []
        futures_coinm      = results[3] if not isinstance(results[3], Exception) else []
        cross_margin       = results[4] if not isinstance(results[4], Exception) else []
        isolated_margin    = results[5] if not isinstance(results[5], Exception) else []

        # Fetch all prices once
        price_map = await self._build_price_map()

        def enrich(balances: list[dict], wallet_type: str) -> tuple[Decimal, list[dict]]:
            total = Decimal("0")
            enriched = []
            for b in balances:
                asset = b["asset"]
                qty = Decimal(b.get("total", b.get("wallet_balance", "0")))
                usd = self._usd_value(asset, qty, price_map)
                total += usd
                enriched.append({**b, "value_usd": str(round(usd, 2)), "wallet_type": wallet_type})
            return total, enriched

        spot_total,     spot_rich     = enrich(spot_balances,    "spot")
        funding_total,  funding_rich  = enrich(funding_balances, "funding")
        futusdm_total,  futusdm_rich  = enrich(futures_usdm,     "futures_usdm")
        futcoinm_total, futcoinm_rich = enrich(futures_coinm,    "futures_coinm")
        cross_total,    cross_rich    = enrich(cross_margin,     "cross_margin")
        iso_total,      iso_rich      = enrich(isolated_margin,  "isolated_margin")

        grand_total = spot_total + funding_total + futusdm_total + futcoinm_total + cross_total + iso_total

        # Combine all assets for allocation %
        all_assets: dict[str, Decimal] = {}
        for items in [spot_rich, funding_rich, futusdm_rich, futcoinm_rich, cross_rich, iso_rich]:
            for b in items:
                asset = b["asset"]
                usd = Decimal(b["value_usd"])
                all_assets[asset] = all_assets.get(asset, Decimal("0")) + usd

        # Top assets sorted by value
        top_assets = sorted(
            [{"asset": k, "value_usd": str(v), "allocation_pct": float(round(v / grand_total * 100, 2)) if grand_total > 0 else 0.0}
             for k, v in all_assets.items() if v > Decimal("0.01")],
            key=lambda x: Decimal(x["value_usd"]),
            reverse=True,
        )

        return {
            "total_usd": str(round(grand_total, 2)),
            "wallets": {
                "spot":            {"total_usd": str(round(spot_total, 2)),     "assets": spot_rich},
                "funding":         {"total_usd": str(round(funding_total, 2)),  "assets": funding_rich},
                "futures_usdm":    {"total_usd": str(round(futusdm_total, 2)),  "assets": futusdm_rich},
                "futures_coinm":   {"total_usd": str(round(futcoinm_total, 2)), "assets": futcoinm_rich},
                "cross_margin":    {"total_usd": str(round(cross_total, 2)),    "assets": cross_rich},
                "isolated_margin": {"total_usd": str(round(iso_total, 2)),      "assets": iso_rich},
            },
            "top_assets": top_assets,
            "account_type": "FULL",
        }

    # ==========================================================================
    # LEGACY — kept for compatibility
    # ==========================================================================

    async def get_account_snapshot(self, api_key: str, api_secret: str) -> dict:
        """Alias for get_full_account_snapshot."""
        return await self.get_full_account_snapshot(api_key, api_secret)

    async def get_account_balances(self, api_key: str, api_secret: str) -> list[dict]:
        """Spot balances only — used for credential validation."""
        return await self.get_spot_balances(api_key, api_secret)

    async def get_single_asset_balance(self, asset: str, api_key: str, api_secret: str) -> dict:
        balances = await self.get_spot_balances(api_key, api_secret)
        for b in balances:
            if b["asset"].upper() == asset.upper():
                return b
        return {"asset": asset, "free": "0", "locked": "0", "total": "0"}

    # ==========================================================================
    # PUBLIC market data
    # ==========================================================================

    async def get_24h_tickers(self, symbols: list[str]) -> list[dict]:
        results = []
        for symbol in symbols:
            try:
                data = await self._get("/api/v3/ticker/24hr", params={"symbol": symbol})
                results.append({
                    "symbol": data["symbol"],
                    "price": data["lastPrice"],
                    "price_change": data["priceChange"],
                    "price_change_pct": data["priceChangePercent"],
                    "high_24h": data["highPrice"],
                    "low_24h": data["lowPrice"],
                    "volume_24h": data["volume"],
                    "quote_volume_24h": data["quoteVolume"],
                })
            except Exception as e:
                logger.warning(f"Ticker fetch failed for {symbol}: {e}")
        return results

    async def get_klines(self, symbol: str, interval: str = "1d", limit: int = 30) -> list[dict]:
        data = await self._get("/api/v3/klines", params={"symbol": symbol, "interval": interval, "limit": limit})
        return [{"open_time": item[0], "open": item[1], "high": item[2], "low": item[3], "close": item[4], "volume": item[5], "close_time": item[6]} for item in data]

    async def get_order_book(self, symbol: str, limit: int = 10) -> dict:
        return await self._get("/api/v3/depth", params={"symbol": symbol, "limit": limit})

    async def get_trade_history(self, symbol: str, api_key: str, api_secret: str, limit: int = 50) -> list[dict]:
        data = await self._get("/api/v3/myTrades", params={"symbol": symbol, "limit": limit}, api_key=api_key, api_secret=api_secret)
        return [{"id": t["id"], "symbol": t["symbol"], "side": "BUY" if t["isBuyer"] else "SELL", "qty": t["qty"], "price": t["price"], "commission": t["commission"], "commission_asset": t["commissionAsset"], "time": t["time"]} for t in data]

    async def get_open_orders(self, api_key: str, api_secret: str, symbol: str | None = None) -> list[dict]:
        params: dict = {}
        if symbol:
            params["symbol"] = symbol
        return await self._get("/api/v3/openOrders", params=params, api_key=api_key, api_secret=api_secret)

    async def get_deposit_history(self, api_key: str, api_secret: str, asset: str | None = None, limit: int = 20) -> list[dict]:
        params: dict = {"limit": limit}
        if asset:
            params["coin"] = asset
        data = await self._get("/sapi/v1/capital/deposit/hisrec", params=params, api_key=api_key, api_secret=api_secret)
        return data if isinstance(data, list) else []

    async def get_withdrawal_history(self, api_key: str, api_secret: str, asset: str | None = None, limit: int = 20) -> list[dict]:
        params: dict = {"limit": limit}
        if asset:
            params["coin"] = asset
        data = await self._get("/sapi/v1/capital/withdraw/history", params=params, api_key=api_key, api_secret=api_secret)
        return data if isinstance(data, list) else []


    # ==========================================================================
    # PNL ENDPOINTS
    # ==========================================================================

    @staticmethod
    def _period_to_start_ms(period: str) -> int | None:
        """Convert period string to Unix millisecond start time. None = all-time."""
        import time as _time
        from datetime import datetime, timezone, timedelta
        now = datetime.now(timezone.utc)
        period_map = {
            "1d":  now - timedelta(days=1),
            "1w":  now - timedelta(weeks=1),
            "1m":  now - timedelta(days=30),
            "3m":  now - timedelta(days=90),
            "ytd": datetime(now.year, 1, 1, tzinfo=timezone.utc),
            "all": None,
        }
        dt = period_map.get(period)
        return int(dt.timestamp() * 1000) if dt else None

    async def get_futures_income_history(
        self, api_key: str, api_secret: str, limit: int = 100,
        start_time_ms: int | None = None,
    ) -> dict:
        """GET /fapi/v1/income — realized PnL from futures trades, optionally filtered by period."""
        try:
            params: dict = {"limit": limit, "incomeType": "REALIZED_PNL"}
            if start_time_ms:
                params["startTime"] = start_time_ms
            data = await self._get(
                "/fapi/v1/income",
                params=params,
                api_key=api_key, api_secret=api_secret,
                base_url=BINANCE_FUTURES_URL,
            )
            total = sum(Decimal(str(d.get("income", "0"))) for d in (data or []))
            return {
                "realized_pnl": str(round(total, 4)),
                "entries": [
                    {
                        "symbol": d.get("symbol", ""),
                        "income": str(d.get("income", "0")),
                        "asset": d.get("asset", "USDT"),
                        "time": d.get("time", 0),
                        "info": d.get("info", ""),
                    }
                    for d in (data or [])
                ],
            }
        except BinanceAPIError as e:
            logger.warning(f"Futures income history not accessible: {e.message}")
            return {"realized_pnl": "0", "entries": []}

    async def get_futures_unrealized_pnl(
        self, api_key: str, api_secret: str
    ) -> dict:
        """Unrealized PnL from open futures positions (always current — not period-filtered)."""
        try:
            data = await self._get(
                "/fapi/v2/account",
                params={},
                api_key=api_key, api_secret=api_secret,
                base_url=BINANCE_FUTURES_URL,
            )
            positions = [
                p for p in data.get("positions", [])
                if Decimal(str(p.get("unrealizedProfit", "0"))) != 0
            ]
            total_unrealized = sum(
                Decimal(str(p.get("unrealizedProfit", "0"))) for p in positions
            )
            return {
                "unrealized_pnl": str(round(total_unrealized, 4)),
                "positions": [
                    {
                        "symbol": p.get("symbol", ""),
                        "side": "LONG" if Decimal(str(p.get("positionAmt", "0"))) > 0 else "SHORT",
                        "size": str(p.get("positionAmt", "0")),
                        "entry_price": str(p.get("entryPrice", "0")),
                        "mark_price": str(p.get("markPrice", "0")),
                        "unrealized_pnl": str(p.get("unrealizedProfit", "0")),
                        "leverage": str(p.get("leverage", "1")),
                        "margin_type": p.get("marginType", "cross"),
                    }
                    for p in positions
                ],
            }
        except BinanceAPIError as e:
            logger.warning(f"Futures positions not accessible: {e.message}")
            return {"unrealized_pnl": "0", "positions": []}

    async def get_spot_pnl(
        self, api_key: str, api_secret: str,
        price_map: dict | None = None,
        start_time_ms: int | None = None,
    ) -> dict:
        """
        Spot PnL = current portfolio value vs estimated cost basis.
        When start_time_ms is set, only trades after that time count toward cost basis.
        """
        try:
            balances = await self.get_spot_balances(api_key, api_secret)
            if not balances:
                return {"spot_pnl": "0", "assets": []}

            if price_map is None:
                price_map = await self._build_price_map()

            assets_pnl = []
            total_current = Decimal("0")
            total_cost = Decimal("0")

            for b in balances:
                asset = b["asset"]
                qty = Decimal(b["total"])
                current_price = price_map.get(asset, Decimal("0"))
                current_value = qty * current_price

                if current_value < Decimal("0.01"):
                    continue

                cost_basis = Decimal("0")
                try:
                    symbol = f"{asset}USDT"
                    trade_params: dict = {"symbol": symbol, "limit": 500}
                    if start_time_ms:
                        trade_params["startTime"] = start_time_ms
                    trades = await self._get(
                        "/api/v3/myTrades",
                        params=trade_params,
                        api_key=api_key, api_secret=api_secret,
                    )
                    buy_qty = Decimal("0")
                    buy_cost = Decimal("0")
                    for t in trades:
                        if t.get("isBuyer"):
                            q = Decimal(str(t.get("qty", "0")))
                            p = Decimal(str(t.get("price", "0")))
                            buy_qty += q
                            buy_cost += q * p
                    if buy_qty > 0:
                        avg_price = buy_cost / buy_qty
                        cost_basis = min(qty, buy_qty) * avg_price
                except Exception:
                    cost_basis = current_value

                pnl = current_value - cost_basis
                total_current += current_value
                total_cost += cost_basis

                assets_pnl.append({
                    "asset": asset,
                    "qty": str(qty),
                    "current_price": str(current_price),
                    "current_value": str(round(current_value, 2)),
                    "cost_basis": str(round(cost_basis, 2)),
                    "pnl": str(round(pnl, 2)),
                    "pnl_pct": str(round((pnl / cost_basis * 100) if cost_basis > 0 else Decimal("0"), 2)),
                })

            total_pnl = total_current - total_cost
            return {
                "spot_pnl": str(round(total_pnl, 2)),
                "total_current_value": str(round(total_current, 2)),
                "total_cost_basis": str(round(total_cost, 2)),
                "pnl_pct": str(round((total_pnl / total_cost * 100) if total_cost > 0 else Decimal("0"), 2)),
                "assets": sorted(assets_pnl, key=lambda x: float(x["current_value"]), reverse=True),
            }
        except Exception as e:
            logger.warning(f"Spot PnL calculation failed: {e}")
            return {"spot_pnl": "0", "total_current_value": "0", "total_cost_basis": "0", "pnl_pct": "0", "assets": []}

    async def get_full_pnl_summary(
        self, api_key: str, api_secret: str, period: str = "all"
    ) -> dict:
        """
        Overall PnL across: spot + futures unrealized + futures realized.
        period: '1d' | '1w' | '1m' | '3m' | 'ytd' | 'all'
        - Spot & realized futures are filtered by period start time
        - Unrealized is always current (open positions have no time concept)
        """
        start_ms = self._period_to_start_ms(period)
        price_map = await self._build_price_map()

        results = await asyncio.gather(
            self.get_spot_pnl(api_key, api_secret, price_map, start_time_ms=start_ms),
            self.get_futures_unrealized_pnl(api_key, api_secret),
            self.get_futures_income_history(api_key, api_secret, start_time_ms=start_ms),
            return_exceptions=True,
        )

        spot     = results[0] if not isinstance(results[0], Exception) else {"spot_pnl": "0", "assets": [], "pnl_pct": "0"}
        unreal   = results[1] if not isinstance(results[1], Exception) else {"unrealized_pnl": "0", "positions": []}
        realized = results[2] if not isinstance(results[2], Exception) else {"realized_pnl": "0", "entries": []}

        spot_pnl     = Decimal(str(spot.get("spot_pnl", "0")))
        unreal_pnl   = Decimal(str(unreal.get("unrealized_pnl", "0")))
        realized_pnl = Decimal(str(realized.get("realized_pnl", "0")))
        total_pnl    = spot_pnl + unreal_pnl + realized_pnl

        return {
            "total_pnl": str(round(total_pnl, 2)),
            "period": period,
            "spot": {
                "pnl": str(round(spot_pnl, 2)),
                "pnl_pct": spot.get("pnl_pct", "0"),
                "current_value": spot.get("total_current_value", "0"),
                "cost_basis": spot.get("total_cost_basis", "0"),
                "assets": spot.get("assets", []),
            },
            "futures_unrealized": {
                "pnl": str(round(unreal_pnl, 2)),
                "positions": unreal.get("positions", []),
            },
            "futures_realized": {
                "pnl": str(round(realized_pnl, 2)),
                "entries": realized.get("entries", [])[:10],
            },
        }


# ── Exceptions ────────────────────────────────────────────────────────────────

class BinanceAPIError(Exception):
    def __init__(self, status_code: int, message: str, code: int | None = None):
        self.status_code = status_code
        self.message = message
        self.code = code
        super().__init__(f"Binance {status_code} (code={code}): {message}")


class BinanceConnectionError(Exception):
    pass