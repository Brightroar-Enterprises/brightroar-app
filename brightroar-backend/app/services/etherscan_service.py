import httpx
import logging
from decimal import Decimal

logger = logging.getLogger(__name__)

# Public Ethereum RPC endpoints — no API key needed
# We try multiple in order until one works
PUBLIC_RPCS = [
    "https://cloudflare-eth.com",
    "https://eth.llamarpc.com",
    "https://ethereum.publicnode.com",
    "https://1rpc.io/eth",
]

ERC20_CONTRACTS = {
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
}

ERC20_DECIMALS = {
    "USDT": 6,
    "USDC": 6,
    "ETH":  18,
}


class EtherscanService:
    """
    Fetches on-chain Ethereum balances using free public RPC endpoints.
    No API key required. Tries multiple endpoints as fallback.
    """

    def __init__(self, api_key: str = "", timeout: float = 10.0):
        self.api_key = api_key  # kept for compatibility, not used
        self.timeout = timeout

    async def _rpc(self, method: str, params: list) -> dict:
        """Try each public RPC endpoint until one succeeds."""
        last_error = None
        payload = {"jsonrpc": "2.0", "method": method, "params": params, "id": 1}
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            for rpc in PUBLIC_RPCS:
                try:
                    resp = await client.post(rpc, json=payload)
                    resp.raise_for_status()
                    data = resp.json()
                    if "error" in data:
                        last_error = data["error"].get("message", "RPC error")
                        continue
                    return data
                except Exception as e:
                    last_error = str(e)
                    logger.warning(f"RPC {rpc} failed: {e}, trying next...")
                    continue
        raise EtherscanError(f"All RPC endpoints failed. Last error: {last_error}")

    async def get_eth_balance(self, address: str) -> Decimal:
        """Get native ETH balance."""
        try:
            data = await self._rpc("eth_getBalance", [address, "latest"])
            hex_val = data.get("result", "0x0")
            return Decimal(int(hex_val, 16)) / Decimal("1e18")
        except Exception as e:
            logger.warning(f"ETH balance failed: {e}")
            return Decimal("0")

    async def get_erc20_balance(self, address: str, token_symbol: str) -> Decimal:
        """Get ERC-20 token balance using balanceOf() eth_call."""
        contract = ERC20_CONTRACTS.get(token_symbol.upper())
        if not contract:
            raise EtherscanError(f"Unknown token: {token_symbol}")

        decimals = ERC20_DECIMALS.get(token_symbol.upper(), 18)
        # balanceOf(address) selector = 0x70a08231
        padded = address.lower().replace("0x", "").zfill(64)
        call_data = f"0x70a08231{padded}"

        try:
            result = await self._rpc("eth_call", [{"to": contract, "data": call_data}, "latest"])
            hex_result = result.get("result", "0x0")
            if not hex_result or hex_result == "0x":
                return Decimal("0")
            return Decimal(int(hex_result, 16)) / Decimal(10 ** decimals)
        except Exception as e:
            logger.warning(f"ERC-20 balance failed for {token_symbol}: {e}")
            return Decimal("0")

    async def get_balance_for_asset(self, address: str, asset_symbol: str) -> Decimal:
        """Fetch balance for ETH, USDT, or USDC."""
        sym = asset_symbol.upper()
        if sym == "ETH":
            return await self.get_eth_balance(address)
        elif sym in ERC20_CONTRACTS:
            return await self.get_erc20_balance(address, sym)
        else:
            logger.warning(f"Asset {sym} not supported for on-chain sync")
            return Decimal("0")

    async def get_all_balances(self, address: str) -> dict:
        """Fetch ETH + USDT + USDC balances in parallel."""
        import asyncio
        results = await asyncio.gather(
            self.get_eth_balance(address),
            self.get_erc20_balance(address, "USDT"),
            self.get_erc20_balance(address, "USDC"),
            return_exceptions=True,
        )
        tokens = ["ETH", "USDT", "USDC"]
        return {t: Decimal("0") if isinstance(r, Exception) else r
                for t, r in zip(tokens, results)}


class EtherscanError(Exception):
    pass


class EtherscanConnectionError(Exception):
    pass