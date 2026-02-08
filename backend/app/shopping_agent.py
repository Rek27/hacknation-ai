"""
ShoppingAgent — builds a ChunkShoppingCart from ShoppingList items.
"""

from __future__ import annotations

import json
import math
import re
from dataclasses import dataclass
from typing import Any

from app.logger import get_logger
from app.models import CartItem, CartItemDetail, ChunkShoppingCart

logger = get_logger(__name__)


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

    def build_cart(
        self,
        items: list[str],
        price_ranges: list[dict],
        quantities: dict[str, int],
        form_data: dict[str, str] | None,
    ) -> tuple[ChunkShoppingCart, list[dict], list[str]]:
        price_fallbacks = _price_range_map(price_ranges)
        attendees = _parse_attendees(form_data or {})
        duration_hours = _parse_duration_hours(form_data or {})

        cart_items: list[CartItem] = []
        total_price = 0.0
        tool_events: list[dict] = []
        missing_items: list[str] = []

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
            results = self.rag_pipeline.search(item, n_results=5)
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
            total_price += (
                cart_item.recommended_item.price
                * cart_item.recommended_item.amount
            )

        return (
            ChunkShoppingCart(items=cart_items, price=round(total_price, 2)),
            tool_events,
            missing_items,
        )

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
            delivery_time_ms=_delivery_ms(int(delivery_days)),
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
