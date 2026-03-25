from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import get_settings
from app.database import init_db
from app.redis_client import get_redis, close_redis
from app.routers import auth, wallets, transactions, analytics, market
from app.routers import binance as binance_router
from app.routers import property_scout as property_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    await get_redis()
    print(f"✅ {settings.app_name} v{settings.app_version} started")
    yield
    # Shutdown
    await close_redis()
    print("👋 Shutdown complete")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Institutional Crypto Asset Management API",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router,         prefix="/api/v1")
app.include_router(wallets.router,      prefix="/api/v1")
app.include_router(transactions.router, prefix="/api/v1")
app.include_router(analytics.router,    prefix="/api/v1")
app.include_router(market.router,       prefix="/api/v1")
app.include_router(binance_router.router, prefix="/api/v1")
app.include_router(property_router.router, prefix="/api/v1")  # ← add this


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health():
    return {"status": "ok", "version": settings.app_version}


@app.get("/", tags=["Health"])
async def root():
    return {"message": f"Welcome to {settings.app_name}", "docs": "/docs"}
