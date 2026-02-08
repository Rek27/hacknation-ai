"""
ShoppingAgent — builds a ChunkShoppingCart from ShoppingList items.
"""

from __future__ import annotations

import asyncio
import json
import math
import os
import random
import re
from dataclasses import dataclass
from typing import Any, AsyncGenerator

from app.logger import get_logger
from app.models import CartItem, CartItemDetail, ChunkShoppingCart
from app.tools.implementations import check_retailer_sponsorship

logger = get_logger(__name__)
IMAGE_BASE_URL = os.getenv("IMAGE_BASE_URL", "http://localhost:8000/images")


def _parse_fields_from_content(content: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for part in content.split(","):
        if ":" not in part:
            continue
        key, value = part.split(":", 1)
        key = key.strip().lower()
        value = value.strip()
        if key and value:
            fields[key] = value
    return fields


def _parse_price(value: str) -> float | None:
    match = re.search(r"([0-9]+(?:\.[0-9]+)?)", value)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def _parse_delivery_days(value: str) -> int | None:
    match = re.search(r"([0-9]+)", value)
    if not match:
        return None
    try:
        return int(match.group(1))
    except ValueError:
        return None


def _parse_review_rating(value: str) -> float | None:
    match = re.search(r"([0-9]+(?:\.[0-9]+)?)", value)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def _parse_review_count(value: str) -> int | None:
    match = re.search(r"([0-9]+)", value)
    if not match:
        return None
    try:
        return int(match.group(1))
    except ValueError:
        return None


def _image_url(image_id: str | None) -> str | None:
    if not image_id:
        return None
    clean = str(image_id).strip()
    if not clean:
        return None
    return f"{IMAGE_BASE_URL}/{clean}.jpg"


def _extract_retailer(result: dict[str, Any]) -> str:
    content = str(result.get("content", "")).strip()
    fields = _parse_fields_from_content(content)
    return (
        fields.get("retailer")
        or fields.get("store")
        or fields.get("vendor")
        or "Unknown retailer"
    )


def _extract_item_id(result: dict[str, Any]) -> str | None:
    metadata = result.get("metadata")
    if isinstance(metadata, dict):
        source = metadata.get("source")
        row = metadata.get("row")
        if source is not None and row is not None:
            return f"{source}:{row}"
    return None


def _format_event_context(form_data: dict[str, str] | None) -> str:
    if not form_data:
        return ""
    parts = []
    address = form_data.get("address")
    if address:
        parts.append(f"Address: {address}")
    date = form_data.get("date")
    if date:
        parts.append(f"Date: {date}")
    duration = form_data.get("duration")
    if duration:
        parts.append(f"Duration: {duration}")
    attendees = form_data.get("number of attendees")
    if attendees:
        parts.append(f"Attendees: {attendees}")
    return ". ".join(parts)


def _delivery_ms(days: int) -> int:
    return max(days, 0) * 24 * 60 * 60 * 1000


def _infer_amount(
    item: str,
    attendees: int | None,
    duration_hours: float | None,
) -> int:
    if not attendees:
        return 1
    lower = item.lower()
    consumable = _is_consumable(lower)
    per_person = any(
        phrase in lower
        for phrase in [
            "per person",
            "per attendee",
            "per guest",
            "each attendee",
            "each person",
        ]
    )
    base = attendees if (per_person or consumable) else 1
    if consumable and duration_hours:
        multiplier = max(1, math.ceil(duration_hours / 4))
        return base * multiplier
    return base


def _price_range_map(price_ranges: list[dict]) -> dict[str, float]:
    mapping: dict[str, float] = {}
    for entry in price_ranges:
        item = entry.get("item")
        price_range = entry.get("price_range", {})
        if not item or not isinstance(price_range, dict):
            continue
        avg = price_range.get("average")
        if isinstance(avg, (int, float)):
            mapping[str(item)] = float(avg)
    return mapping


class ShoppingAgent:
    """Build cart items from vector DB search results."""

    def __init__(self, rag_pipeline):
        self.rag_pipeline = rag_pipeline
        logger.info("ShoppingAgent initialized")

    async def build_cart(
        self,
        items: list[str],
        price_ranges: list[dict],
        quantities: dict[str, int],
        form_data: dict[str, str] | None,
        event_context: str | None = None,
    ) -> tuple[
        ChunkShoppingCart,
        list[dict],
        list[str],
        dict[str, list[dict[str, str | None]]],
        str,
    ]:
        """Build cart. Returns (cart, tool_events, missing, retailer_items, context_text).

        Sponsorship is handled separately via ``stream_sponsorship_offers``.
        """
        price_fallbacks = _price_range_map(price_ranges)
        attendees = _parse_attendees(form_data or {})
        duration_hours = _parse_duration_hours(form_data or {})
        context_text = event_context or _format_event_context(form_data)

        cart_items: list[CartItem] = []
        total_price = 0.0
        tool_events: list[dict] = []
        missing_items: list[str] = []
        retailer_items: dict[str, list[dict[str, str | None]]] = {}

        search_entries: list[tuple[str, asyncio.Future]] = []
        for item in items:
            if not item.strip():
                continue
            tool_events.append(
                {
                    "type": "tool",
                    "name": "vector_search",
                    "reason": "Retrieve similar items from vector DB",
                    "arguments": {"query": item, "n_results": 5},
                }
            )
            search_entries.append(
                (item, asyncio.to_thread(self.rag_pipeline.search, item, n_results=5))
            )

        results_list = []
        if search_entries:
            results_list = await asyncio.gather(
                *(entry[1] for entry in search_entries),
                return_exceptions=True,
            )

        for (item, _), results in zip(search_entries, results_list):
            if isinstance(results, Exception):
                logger.warning(f"Vector search failed for {item}: {results}")
                tool_events.append(
                    {
                        "type": "tool_result",
                        "name": "vector_search",
                        "result": json.dumps({"query": item, "count": 0}),
                        "success": False,
                    }
                )
                missing_items.append(item)
                continue

            tool_events.append(
                {
                    "type": "tool_result",
                    "name": "vector_search",
                    "result": json.dumps(
                        {
                            "query": item,
                            "count": len(results),
                        }
                    ),
                    "success": len(results) > 0,
                }
            )
            if not results:
                missing_items.append(item)
                continue

            candidates: list[_Candidate] = []
            for index, result in enumerate(results):
                candidate = self._result_to_candidate(
                    item,
                    result,
                    attendees,
                    duration_hours,
                    quantities.get(item),
                    price_fallbacks.get(item),
                    index,
                )
                if candidate:
                    candidates.append(candidate)
            if not candidates:
                missing_items.append(item)
                continue
            cart_item = _select_cart_item(candidates)
            cart_items.append(cart_item)
            recommended = cart_item.recommended_item
            retailer_items.setdefault(recommended.retailer, []).append(
                {"item": recommended.name, "id": recommended.id}
            )
            total_price += (
                cart_item.recommended_item.price
                * cart_item.recommended_item.amount
            )

        return (
            ChunkShoppingCart(items=cart_items, price=round(total_price, 2)),
            tool_events,
            missing_items,
            retailer_items,
            context_text,
        )

    # ------------------------------------------------------------------
    # Streaming sponsorship: yields {"phase":"start",...} and
    # {"phase":"end",...} events sequentially with a simulated delay.
    # ------------------------------------------------------------------

    async def stream_sponsorship_offers(
        self,
        retailer_items: dict[str, list[dict[str, str | None]]],
        event_context: str,
    ) -> AsyncGenerator[dict, None]:
        """Yield start/end events for each retailer sponsorship call.

        Each retailer produces two yields:
        1. ``{"phase": "start", "retailer": ..., "item_count": ...}``
        2. ``{"phase": "end", ...offer_data...}``

        The mock calls are resolved upfront (parallel) so the
        forced-rejection logic can be applied, then results are drip-fed
        sequentially with a 2-4 s delay per call.
        """
        if not retailer_items:
            return

        # ── run all mock calls in parallel ────────────────────────────
        entries: list[tuple[str, list, asyncio.Future]] = []
        for retailer, item_list in retailer_items.items():
            entries.append((
                retailer,
                item_list,
                asyncio.to_thread(
                    check_retailer_sponsorship,
                    retailer=retailer,
                    items=json.dumps(item_list),
                    event_context=event_context,
                ),
            ))

        raw_results = await asyncio.gather(
            *(e[2] for e in entries),
            return_exceptions=True,
        )

        # ── collect & normalise ───────────────────────────────────────
        resolved: list[tuple[str, list, dict]] = []
        for (retailer, item_list, _), raw in zip(entries, raw_results):
            if isinstance(raw, Exception):
                logger.warning(f"Sponsorship tool failed for {retailer}: {raw}")
                resolved.append((retailer, item_list, {
                    "retailer": retailer,
                    "status": "rejected",
                    "reason": "Tool error",
                    "discountedItems": [],
                }))
                continue
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, dict):
                    resolved.append((retailer, item_list, parsed))
                else:
                    resolved.append((retailer, item_list, {
                        "retailer": retailer,
                        "status": "rejected",
                        "reason": "Invalid tool response",
                        "discountedItems": [],
                    }))
            except json.JSONDecodeError:
                resolved.append((retailer, item_list, {
                    "retailer": retailer,
                    "status": "rejected",
                    "reason": "Invalid tool response",
                    "discountedItems": [],
                }))

        # ── force at least one rejection when all approved ────────────
        all_offers = [r[2] for r in resolved]
        if all_offers and all(o.get("status") == "approved" for o in all_offers):
            forced = all_offers[0]
            forced["status"] = "rejected"
            forced["reason"] = "Sponsorship budget already committed for this event."
            forced["discountPercent"] = None
            forced["discountedItems"] = []

        # ── yield start → delay → end for each retailer ──────────────
        for retailer, item_list, offer in resolved:
            yield {
                "phase": "start",
                "retailer": retailer,
                "item_count": len(item_list),
            }
            delay = random.uniform(2.0, 4.0)
            logger.info(
                f"Sponsorship call to {retailer} — sleeping {delay:.1f}s"
            )
            await asyncio.sleep(delay)
            yield {
                "phase": "end",
                **offer,
            }

    def _result_to_candidate(
        self,
        query_item: str,
        result: dict[str, Any],
        attendees: int | None,
        duration_hours: float | None,
        quantity_override: int | None,
        price_fallback: float | None,
        index: int,
    ) -> _Candidate | None:
        content = str(result.get("content", "")).strip()
        fields = _parse_fields_from_content(content)

        name = (
            fields.get("name")
            or fields.get("item")
            or fields.get("product")
            or fields.get("title")
            or query_item
        )
        price = None
        for key in ("price", "unit price", "cost"):
            if key in fields:
                price = _parse_price(fields[key])
                if price is not None:
                    break
        if price is None and price_fallback is not None:
            price = float(price_fallback)
        if price is None:
            price = 0.0

        retailer = (
            fields.get("retailer")
            or fields.get("store")
            or fields.get("vendor")
            or "Unknown retailer"
        )

        delivery_days = None
        for key in ("delivery estimate", "delivery", "delivery days"):
            if key in fields:
                delivery_days = _parse_delivery_days(fields[key])
                if delivery_days is not None:
                    break
        if delivery_days is None:
            delivery_days = 3

        review_rating = None
        for key in ("review rating", "rating", "review score"):
            if key in fields:
                review_rating = _parse_review_rating(fields[key])
                if review_rating is not None:
                    break
        if review_rating is None:
            review_rating = 0.0

        review_count = None
        for key in ("reviews count", "review count", "reviews"):
            if key in fields:
                review_count = _parse_review_count(fields[key])
                if review_count is not None:
                    break
        if review_count is None:
            review_count = 0

        image_id = None
        for key in ("image", "image id", "image_id"):
            if key in fields and fields[key]:
                image_id = fields[key]
                break

        if isinstance(quantity_override, int) and quantity_override > 0:
            amount = quantity_override
        else:
            amount = _infer_amount(query_item, attendees, duration_hours)

        item_id = None
        metadata = result.get("metadata")
        if isinstance(metadata, dict):
            source = metadata.get("source")
            row = metadata.get("row")
            if source is not None and row is not None:
                item_id = f"{source}:{row}"

        detail = CartItemDetail(
            id=item_id,
            name=str(name),
            price=float(price),
            amount=int(amount),
            retailer=str(retailer),
            review_rating=float(review_rating),
            reviews_count=int(review_count),
            delivery_time_ms=_delivery_ms(int(delivery_days)),
            image_url=_image_url(image_id),
        )
        return _Candidate(
            detail=detail,
            price=float(price),
            delivery_days=int(delivery_days),
            rating=float(review_rating),
            index=index,
        )


def _parse_attendees(form_data: dict[str, str]) -> int | None:
    for key in ("number of attendees", "attendees", "guest count", "guests"):
        value = form_data.get(key)
        if not value:
            continue
        match = re.search(r"([0-9]+)", value)
        if match:
            try:
                return int(match.group(1))
            except ValueError:
                continue
    return None


def _parse_duration_hours(form_data: dict[str, str]) -> float | None:
    for key in ("duration", "duration (hours)", "event duration", "hours"):
        value = form_data.get(key)
        if not value:
            continue
        match = re.search(r"([0-9]+(?:\.[0-9]+)?)", value)
        if match:
            try:
                return float(match.group(1))
            except ValueError:
                continue
    return None


def _is_consumable(item_lower: str) -> bool:
    keywords = [
        "water",
        "coffee",
        "tea",
        "soda",
        "juice",
        "drink",
        "snack",
        "chips",
        "cookies",
        "meal",
        "lunch",
        "dinner",
        "breakfast",
        "fruit",
        "sandwich",
    ]
    return any(keyword in item_lower for keyword in keywords)


@dataclass(frozen=True)
class _Candidate:
    detail: CartItemDetail
    price: float
    delivery_days: int
    rating: float
    index: int


def _select_cart_item(candidates: list[_Candidate]) -> CartItem:
    cheapest = min(candidates, key=lambda c: (c.price, c.index))
    fastest = min(
        candidates,
        key=lambda c: (c.delivery_days, c.price, c.index),
    )
    best_rating = min(
        candidates,
        key=lambda c: (-c.rating, c.price, c.index),
    )

    counts: dict[int, int] = {}
    for picked in (cheapest, fastest, best_rating):
        counts[picked.index] = counts.get(picked.index, 0) + 1
    recommended = min(
        candidates,
        key=lambda c: (-counts.get(c.index, 0), c.price, c.index),
    )

    return CartItem(
        recommended_item=recommended.detail,
        cheapest_item=cheapest.detail,
        best_rating_item=best_rating.detail,
        fastest_delivery_item=fastest.detail,
    )
