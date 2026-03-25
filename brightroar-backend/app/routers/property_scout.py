from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import json

from app.database import get_db
from app.models.user import User
from app.core.dependencies import get_current_active_user
from app.redis_client import cache_get, cache_set
from app.services.property_service import PropertyService, PropertyAPIError
from app.config import get_settings

router = APIRouter(prefix="/property", tags=["Property Scout"])


def _get_service() -> PropertyService:
    settings = get_settings()
    return PropertyService(rapidapi_key=getattr(settings, "rapidapi_key", ""))


@router.get("/search")
async def search_properties(
    location: str = Query(..., description="City, state e.g. 'Austin, TX'"),
    crime_rates: str = Query("", description="Comma-separated: Low,Medium-Low,Medium,Medium-High"),
    roi_ranges: str = Query("", description="Comma-separated: 5-7%,7-9%,9-11%,>11%"),
    market_status: str = Query("", description="Comma-separated: Emerging,Stable,Declining,Gentrifying"),
    property_types: str = Query("", description="Comma-separated: Single-Family,Condo,Townhouse,Multi-Family"),
    timelines: str = Query("", description="Comma-separated: <3 Years,3-5 Years,5-7 Years,>7 Years"),
    current_user: User = Depends(get_current_active_user),
):
    """
    Search properties by investment criteria.
    Returns ranked list with ROI estimates, crime levels, school ratings and investment scores.
    Uses Zillow via RapidAPI if key configured, otherwise returns demo data.
    """
    cache_key = f"property:search:{location}:{crime_rates}:{roi_ranges}:{property_types}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    svc = _get_service()
    result = await svc.search_by_criteria(
        location=location,
        crime_rates=[x.strip() for x in crime_rates.split(",") if x.strip()],
        roi_ranges=[x.strip() for x in roi_ranges.split(",") if x.strip()],
        market_status=[x.strip() for x in market_status.split(",") if x.strip()],
        property_types=[x.strip() for x in property_types.split(",") if x.strip()],
        timelines=[x.strip() for x in timelines.split(",") if x.strip()],
    )

    await cache_set(cache_key, result, ttl=300)  # cache 5 minutes
    return result


@router.get("/detail/{zpid}")
async def get_property_detail(
    zpid: str,
    current_user: User = Depends(get_current_active_user),
):
    """Get detailed info for a specific property by Zillow ID."""
    cache_key = f"property:detail:{zpid}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    svc = _get_service()
    result = await svc.get_property_detail(zpid)
    if not result:
        raise HTTPException(status_code=404, detail="Property not found")

    await cache_set(cache_key, result, ttl=600)
    return result


@router.get("/neighborhood")
async def get_neighborhood_stats(
    location: str = Query(..., description="City, state e.g. 'Austin, TX'"),
    current_user: User = Depends(get_current_active_user),
):
    """Get neighborhood stats: crime, schools, walk score, market trend."""
    cache_key = f"property:neighborhood:{location}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    svc = _get_service()
    result = await svc.get_neighborhood_stats(location)
    await cache_set(cache_key, result, ttl=3600)  # cache 1 hour
    return result


@router.get("/trends")
async def get_market_trends(
    location: str = Query(..., description="City, state e.g. 'Austin, TX'"),
    current_user: User = Depends(get_current_active_user),
):
    """Get rent growth and price appreciation trends for a location."""
    cache_key = f"property:trends:{location}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    svc = _get_service()
    result = await svc.get_market_trends(location)
    await cache_set(cache_key, result, ttl=3600)
    return result


@router.get("/portfolio")
async def get_portfolio(
    current_user: User = Depends(get_current_active_user),
):
    """
    Get real estate portfolio summary — total value, ROI, cash flow,
    property list, ROI trend and cash flow by market.
    Uses demo data if no RapidAPI key configured.
    """
    cache_key = f"property:portfolio:{current_user.id}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    svc = _get_service()
    result = svc.get_portfolio_summary()
    await cache_set(cache_key, result, ttl=300)
    return result


@router.get("/portfolio/analysis")
async def get_portfolio_analysis(
    current_user: User = Depends(get_current_active_user),
):
    """AI-generated portfolio analysis text."""
    svc = _get_service()
    return {"analysis": svc.get_portfolio_analysis()}


@router.post("/portfolio/property")
async def add_portfolio_property(
    address: str = Query(...),
    city: str = Query(...),
    property_type: str = Query(...),
    purchase_price: float = Query(...),
    monthly_cashflow: float = Query(...),
    current_user: User = Depends(get_current_active_user),
):
    """Add a property to the portfolio (stored in-memory/demo for now)."""
    return {
        "status": "added",
        "property": {
            "address": address,
            "city": city,
            "type": property_type,
            "purchase_price": purchase_price,
            "monthly_cashflow": monthly_cashflow,
        }
    }
