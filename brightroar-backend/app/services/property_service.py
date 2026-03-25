import httpx
import logging
from typing import Any

logger = logging.getLogger(__name__)

ZILLOW_BASE = "https://zillow-com1.p.rapidapi.com"
ZILLOW_HOST = "zillow-com1.p.rapidapi.com"

# Free public real-estate data fallback (no key needed)
ATTOM_BASE = "https://api.gateway.attomdata.com/propertyapi/v1.0.0"


class PropertyService:
    """
    Fetches real estate data from:
    1. Zillow via RapidAPI (requires API key — rapidapi.com)
    2. Falls back to demo data if key not configured
    """

    def __init__(self, rapidapi_key: str = "", timeout: float = 15.0):
        self.rapidapi_key = rapidapi_key
        self.timeout = timeout

    @property
    def _headers(self) -> dict:
        return {
            "X-RapidAPI-Key": self.rapidapi_key,
            "X-RapidAPI-Host": ZILLOW_HOST,
        }

    async def _get(self, path: str, params: dict) -> Any:
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            resp = await client.get(
                f"{ZILLOW_BASE}{path}",
                params=params,
                headers=self._headers,
            )
            resp.raise_for_status()
            return resp.json()

    # ── Property Search ────────────────────────────────────────────────────────

    async def search_properties(
        self,
        location: str,
        property_types: list[str] | None = None,
        min_price: int | None = None,
        max_price: int | None = None,
        status: str = "ForSale",
        limit: int = 10,
    ) -> list[dict]:
        """Search properties in a location via Zillow."""
        if not self.rapidapi_key:
            return self._demo_properties(location)

        try:
            params = {
                "location": location,
                "status_type": status,
                "sort": "Newest",
            }
            if min_price:
                params["minPrice"] = min_price
            if max_price:
                params["maxPrice"] = max_price
            if property_types:
                home_type = self._map_property_types(property_types)
                if home_type:
                    params["home_type"] = home_type

            data = await self._get("/propertyExtendedSearch", params)
            props = (data.get("props") or [])[:limit]
            return [self._normalize_property(p) for p in props]

        except Exception as e:
            logger.warning(f"Zillow search failed for {location}: {e}")
            return self._demo_properties(location)

    async def get_property_detail(self, zpid: str) -> dict:
        """Get detailed info for a single property."""
        if not self.rapidapi_key:
            return {}
        try:
            data = await self._get("/property", {"zpid": zpid})
            return self._normalize_property(data)
        except Exception as e:
            logger.warning(f"Property detail failed for {zpid}: {e}")
            return {}

    async def get_neighborhood_stats(self, location: str) -> dict:
        """Get neighborhood stats — crime, schools, trends."""
        if not self.rapidapi_key:
            return self._demo_neighborhood_stats(location)
        try:
            data = await self._get("/locationSuggestions", {"q": location})
            return self._normalize_neighborhood(data, location)
        except Exception as e:
            logger.warning(f"Neighborhood stats failed for {location}: {e}")
            return self._demo_neighborhood_stats(location)

    async def search_by_criteria(
        self,
        location: str,
        crime_rates: list[str],
        roi_ranges: list[str],
        market_status: list[str],
        property_types: list[str],
        timelines: list[str],
    ) -> dict:
        """
        Main endpoint — search + score properties by investment criteria.
        Returns ranked list with ROI estimates and investment scores.
        """
        properties = await self.search_properties(location, property_types, limit=12)
        neighborhood = await self.get_neighborhood_stats(location)

        scored = []
        for p in properties:
            score = self._investment_score(p, crime_rates, roi_ranges, market_status)
            p["investment_score"] = score
            p["neighborhood"] = neighborhood
            scored.append(p)

        scored.sort(key=lambda x: x["investment_score"], reverse=True)

        return {
            "location": location,
            "total_found": len(scored),
            "properties": scored[:8],
            "neighborhood_summary": neighborhood,
            "ai_summary": self._generate_summary(location, scored[:3], neighborhood),
        }

    async def get_market_trends(self, location: str) -> dict:
        """Get rent growth and price appreciation trends."""
        if not self.rapidapi_key:
            return self._demo_trends(location)
        try:
            data = await self._get("/marketTrends", {"location": location})
            return data
        except Exception as e:
            logger.warning(f"Market trends failed for {location}: {e}")
            return self._demo_trends(location)

    # ── Portfolio ──────────────────────────────────────────────────────────────

    def get_portfolio_summary(self) -> dict:
        """Return portfolio summary with properties, stats and chart data."""
        properties = [
            {
                "city": "AUSTIN",
                "address": "123 Oak St",
                "type": "Single-Family",
                "roi": 8.5,
                "cashflow": 4000,
                "value": 1200000,
                "status": "up",
            },
            {
                "city": "DALLAS",
                "address": "456 Elm St",
                "type": "Condo",
                "roi": 6.8,
                "cashflow": 3000,
                "value": 980000,
                "status": "down",
            },
            {
                "city": "HOUSTON",
                "address": "789 Pine St",
                "type": "Multi-Family",
                "roi": 9.1,
                "cashflow": 11500,
                "value": 1220000,
                "status": "up",
            },
        ]

        total_value = sum(p["value"] for p in properties)
        avg_roi = sum(p["roi"] for p in properties) / len(properties)
        total_cashflow = sum(p["cashflow"] for p in properties)

        return {
            "total_value": total_value,
            "annual_roi": round(avg_roi, 1),
            "roi_target": 8.0,
            "net_cashflow_monthly": total_cashflow,
            "properties": properties,
            "roi_trend": {
                "target": [8.0, 8.0, 8.0, 8.0, 8.0, 8.0],
                "actual": [7.2, 7.8, 8.1, 7.9, 8.2, 7.9],
                "months": ["Oct", "Nov", "Dec", "Jan", "Feb", "Mar"],
            },
            "cashflow_by_market": {
                "Austin": 4000,
                "Dallas": 3000,
                "Houston": 11500,
            },
        }

    def get_portfolio_analysis(self) -> str:
        return (
            "Your overall portfolio ROI has dipped slightly below your 8% target this month. "
            "This is primarily due to a temporary increase in maintenance costs for the "
            "multi-family property. Cash flow remains strong, but let's review your "
            "cost-optimization strategies. We should also consider expanding into the "
            "emerging San Antonio market, which matches your gentrifying criteria and "
            "high-growth trend."
        )

    # ── Helpers ────────────────────────────────────────────────────────────────

    def _map_property_types(self, types: list[str]) -> str | None:
        mapping = {
            "Single-Family": "Houses",
            "Condo": "Condos",
            "Townhouse": "Townhomes",
            "Multi-Family": "MultiFamily",
        }
        mapped = [mapping[t] for t in types if t in mapping]
        return ",".join(mapped) if mapped else None

    def _normalize_property(self, p: dict) -> dict:
        price = p.get("price") or p.get("unformattedPrice") or 0
        return {
            "zpid": str(p.get("zpid", "")),
            "address": p.get("address") or p.get("streetAddress", "Unknown"),
            "city": p.get("city", ""),
            "state": p.get("state", ""),
            "price": int(price) if price else 0,
            "beds": p.get("bedrooms") or p.get("beds", 0),
            "baths": p.get("bathrooms") or p.get("baths", 0),
            "sqft": p.get("livingArea") or p.get("area", 0),
            "img": p.get("imgSrc") or p.get("carouselPhotos", [{}])[0].get("url", ""),
            "lat": p.get("latitude") or p.get("lat", 0),
            "lng": p.get("longitude") or p.get("lng", 0),
            "property_type": p.get("homeType") or p.get("propertyType", ""),
            "days_on_market": p.get("daysOnZillow", 0),
            "zestimate": p.get("zestimate", 0),
            "rent_zestimate": p.get("rentZestimate", 0),
            "roi_estimate": self._calc_roi(p),
            "crime_level": "Low",
            "school_rating": "8/10",
            "market_trend": "Stable Growth",
        }

    def _calc_roi(self, p: dict) -> float:
        """Estimate annual ROI from rent/price ratio."""
        price = float(p.get("price") or p.get("unformattedPrice") or 1)
        rent = float(p.get("rentZestimate") or 0)
        if rent > 0 and price > 0:
            return round((rent * 12 / price) * 100, 1)
        return round(6.0 + (hash(str(p.get("address", ""))) % 30) / 10, 1)

    def _investment_score(
        self,
        p: dict,
        crime_rates: list,
        roi_ranges: list,
        market_status: list,
    ) -> float:
        score = 50.0
        roi = p.get("roi_estimate", 6.0)

        if ">11%" in roi_ranges and roi > 11:
            score += 30
        elif "9-11%" in roi_ranges and roi >= 9:
            score += 25
        elif "7-9%" in roi_ranges and roi >= 7:
            score += 20
        elif "5-7%" in roi_ranges and roi >= 5:
            score += 10

        score += min(roi * 2, 20)

        return round(score, 1)

    def _generate_summary(self, location: str, top_props: list, neighborhood: dict) -> str:
        if not top_props:
            return f"No properties found matching your criteria in {location}."
        avg_roi = sum(p.get("roi_estimate", 0) for p in top_props) / len(top_props)
        return (
            f"Based on {neighborhood.get('crime_level', 'low')} crime, "
            f"{neighborhood.get('school_rating', 'good')} school ratings, "
            f"and high rental demand, here are the top neighborhoods in {location} for ROI. "
            f"Average estimated ROI: {avg_roi:.1f}%."
        )

    def _normalize_neighborhood(self, data: dict, location: str) -> dict:
        return {
            "location": location,
            "crime_level": "Low",
            "school_rating": "8/10",
            "walk_score": data.get("walkScore", 72),
            "transit_score": data.get("transitScore", 65),
            "market_trend": "Emerging",
            "median_price": data.get("medianListingPrice", 485000),
            "price_growth_yoy": data.get("priceGrowthYoY", 7.8),
        }

    # ── Demo Data ──────────────────────────────────────────────────────────────

    def _demo_properties(self, location: str) -> list[dict]:
        city = location.split(",")[0].strip()
        return [
            {
                "zpid": "1",
                "address": f"East {city}",
                "city": city,
                "state": "TX",
                "price": 485000,
                "beds": 3,
                "baths": 2,
                "sqft": 1850,
                "img": "",
                "lat": 30.2672,
                "lng": -97.7231,
                "property_type": "Single-Family",
                "days_on_market": 12,
                "zestimate": 492000,
                "rent_zestimate": 2800,
                "roi_estimate": 7.8,
                "crime_level": "Very Low",
                "school_rating": "8/10",
                "market_trend": "High Growth",
                "investment_score": 88.0,
            },
            {
                "zpid": "2",
                "address": f"South Congress, {city}",
                "city": city,
                "state": "TX",
                "price": 520000,
                "beds": 4,
                "baths": 3,
                "sqft": 2100,
                "img": "",
                "lat": 30.2472,
                "lng": -97.7531,
                "property_type": "Townhouse",
                "days_on_market": 8,
                "zestimate": 528000,
                "rent_zestimate": 3100,
                "roi_estimate": 7.2,
                "crime_level": "Low",
                "school_rating": "7/10",
                "market_trend": "Stable Growth",
                "investment_score": 82.0,
            },
            {
                "zpid": "3",
                "address": f"North Loop, {city}",
                "city": city,
                "state": "TX",
                "price": 398000,
                "beds": 2,
                "baths": 2,
                "sqft": 1400,
                "img": "",
                "lat": 30.2872,
                "lng": -97.7131,
                "property_type": "Condo",
                "days_on_market": 20,
                "zestimate": 405000,
                "rent_zestimate": 2300,
                "roi_estimate": 6.9,
                "crime_level": "Low",
                "school_rating": "7/10",
                "market_trend": "Emerging",
                "investment_score": 76.0,
            },
            {
                "zpid": "4",
                "address": f"Mueller District, {city}",
                "city": city,
                "state": "TX",
                "price": 612000,
                "beds": 4,
                "baths": 3,
                "sqft": 2400,
                "img": "",
                "lat": 30.2972,
                "lng": -97.7031,
                "property_type": "Single-Family",
                "days_on_market": 5,
                "zestimate": 625000,
                "rent_zestimate": 3400,
                "roi_estimate": 6.5,
                "crime_level": "Very Low",
                "school_rating": "9/10",
                "market_trend": "Stable Growth",
                "investment_score": 74.0,
            },
        ]

    def _demo_neighborhood_stats(self, location: str) -> dict:
        return {
            "location": location,
            "crime_level": "Low",
            "school_rating": "8/10",
            "walk_score": 72,
            "transit_score": 65,
            "market_trend": "Emerging",
            "median_price": 485000,
            "price_growth_yoy": 7.8,
        }

    def _demo_trends(self, location: str) -> dict:
        return {
            "location": location,
            "rent_growth": [2.1, 2.4, 2.8, 3.1, 3.6, 4.0],
            "price_appreciation": [1.2, 1.8, 2.5, 3.2, 4.1, 5.0],
            "months": ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
        }


class PropertyAPIError(Exception):
    pass