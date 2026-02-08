"""
Tool implementations.

Add new tools here and register them with the @tools.register decorator.
"""

import json
import re
import hashlib
import random
from datetime import datetime
from typing import Optional, Union
from dataclasses import dataclass
from app.tools.registry import ToolRegistry
from app.logger import get_logger

logger = get_logger(__name__)

# Global registry instance
tools = ToolRegistry()


@dataclass
class FilterRange:
    """Represents a range filter with optional min and max values."""
    min: Optional[Union[int, float]] = None
    max: Optional[Union[int, float]] = None
    
    def __post_init__(self):
        """Validate that at least one of min or max is provided."""
        if self.min is None and self.max is None:
            raise ValueError("At least one of 'min' or 'max' must be provided")


@dataclass
class Filters:
    """
    Filters for search_database queries.
    
    Filters are applied to the vector database BEFORE querying, reducing search space.
    Multiple filters are combined with AND logic - all conditions must be satisfied.
    
    Attributes:
        delivery_time: Filter by delivery estimate in days
            - int: Exact match (e.g., 0 for same-day)
            - FilterRange: Range with min/max (e.g., FilterRange(max=1) for ≤1 day)
        
        price: Filter by item price
            - float: Exact match (e.g., 1.50)
            - FilterRange: Range with min/max (e.g., FilterRange(min=1.0, max=3.0))
    
    Examples:
        # Same-day delivery only
        Filters(delivery_time=0)
        
        # Max 1-day delivery
        Filters(delivery_time=FilterRange(max=1))
        
        # Delivery range 1-2 days
        Filters(delivery_time=FilterRange(min=1, max=2))
        
        # Price range with max delivery
        Filters(
            delivery_time=FilterRange(max=1),
            price=FilterRange(max=2.0)
        )
    """
    delivery_time: Optional[Union[int, FilterRange]] = None
    price: Optional[Union[float, FilterRange]] = None
    
    def __post_init__(self):
        """Validate that at least one filter is provided."""
        if self.delivery_time is None and self.price is None:
            raise ValueError("At least one filter must be provided")
    
    def to_dict(self) -> dict:
        """
        Convert Filters object to dict format for compatibility.
        
        Returns:
            Dict representation with structure:
            {
                "delivery_time": int or {"min": int, "max": int},
                "price": float or {"min": float, "max": float}
            }
        """
        result = {}
        
        if self.delivery_time is not None:
            if isinstance(self.delivery_time, FilterRange):
                range_dict = {}
                if self.delivery_time.min is not None:
                    range_dict["min"] = self.delivery_time.min
                if self.delivery_time.max is not None:
                    range_dict["max"] = self.delivery_time.max
                result["delivery_time"] = range_dict
            else:
                result["delivery_time"] = self.delivery_time
        
        if self.price is not None:
            if isinstance(self.price, FilterRange):
                range_dict = {}
                if self.price.min is not None:
                    range_dict["min"] = self.price.min
                if self.price.max is not None:
                    range_dict["max"] = self.price.max
                result["price"] = range_dict
            else:
                result["price"] = self.price
        
        return result


@tools.register
def get_rag_chunks(query: str, n_results: int = 3, registry: ToolRegistry = None) -> str:
    """Retrieve relevant document chunks based on a query using RAG."""
    logger.info(f"get_rag_chunks called: query='{query}', n_results={n_results}")

    if not registry or not registry.rag_pipeline:
        logger.error("RAG pipeline not initialized")
        return json.dumps({
            "success": False,
            "error": "RAG pipeline not initialized"
        })

    try:
        results = registry.rag_pipeline.search(query, n_results)
        logger.info(f"RAG search successful: {len(results)} chunks found")
        return json.dumps({
            "success": True,
            "chunks": results,
            "count": len(results)
        }, indent=2)
    except Exception as e:
        logger.error(f"RAG search failed: {e}", exc_info=True)
        return json.dumps({
            "success": False,
            "error": str(e)
        })


@tools.register
def get_current_weather(location: str) -> str:
    """Get current weather for a location."""
    logger.info(f"get_current_weather called: location='{location}'")
    return json.dumps({
        "location": location,
        "temperature": 22,
        "condition": "Sunny",
        "humidity": 65,
        "timestamp": datetime.now().isoformat()
    })


@tools.register
def calculate(expression: str) -> str:
    """Evaluate a mathematical expression."""
    logger.info(f"calculate called: expression='{expression}'")
    try:
        allowed_names = {"abs": abs, "round": round, "min": min, "max": max}
        result = eval(expression, {"__builtins__": {}}, allowed_names)
        logger.info(f"Calculation result: {result}")
        return json.dumps({
            "expression": expression,
            "result": result
        })
    except Exception as e:
        logger.error(f"Calculation error: {e}")
        return json.dumps({
            "error": f"Invalid expression: {str(e)}"
        })


def _stable_rng(seed_text: str) -> random.Random:
    digest = hashlib.sha256(seed_text.encode("utf-8")).hexdigest()
    seed_int = int(digest[:16], 16)
    return random.Random(seed_int)


def _extract_event_type(event_context: str) -> str:
    lower = event_context.lower()
    keywords = {
        "wedding": "wedding",
        "birthday": "birthday party",
        "conference": "conference",
        "meetup": "meetup",
        "office": "office event",
        "corporate": "corporate event",
        "festival": "festival",
        "sports": "sports event",
        "kids": "kids event",
        "school": "school event",
        "outdoor": "outdoor event",
    }
    for key, label in keywords.items():
        if key in lower:
            return label
    return "community event"


def _extract_location(event_context: str) -> str:
    match = re.search(r"address:\s*([^.\n]+)", event_context, re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return "the venue"


@tools.register
def check_retailer_sponsorship(
    retailer: str,
    items: str,
    event_context: str
) -> str:
    """
    Mock retailer sponsorship check with deterministic, realistic reasoning.
    """
    try:
        parsed_items = json.loads(items)
        if not isinstance(parsed_items, list):
            parsed_items = [parsed_items]
    except (json.JSONDecodeError, TypeError):
        parsed_items = [items]

    normalized_items: list[dict] = []
    for entry in parsed_items:
        if isinstance(entry, dict):
            name = str(entry.get("item", "")).strip()
            if name:
                normalized_items.append(
                    {
                        "item": name,
                        "id": entry.get("id"),
                    }
                )
        else:
            name = str(entry).strip()
            if name:
                normalized_items.append({"item": name, "id": None})

    seed_text = f"{retailer}|{json.dumps(normalized_items)}|{event_context}"
    rng = _stable_rng(seed_text)

    event_type = _extract_event_type(event_context)
    location = _extract_location(event_context)

    approved = rng.random() > 0.35

    approve_reasons = [
        f"We can support the {event_type} in {location} with a targeted promo.",
        f"This {event_type} in {location} aligns with our local outreach goals.",
        f"Seasonal demand in {location} makes this {event_type} a good fit.",
        f"Our regional marketing plan includes events like this {event_type} in {location}.",
        f"Partnering on this {event_type} in {location} fits our community engagement focus.",
        f"Projected attendance in {location} makes this {event_type} a strong match.",
        f"This {event_type} helps us showcase new inventory in {location}.",
    ]
    reject_reasons = [
        f"Our local budget for {location} is already allocated this month.",
        f"Inventory constraints in {location} limit support for this {event_type}.",
        f"We cannot sponsor this {event_type} due to delivery capacity in {location}.",
        f"Compliance limits prevent sponsorships for this {event_type} in {location}.",
        f"Current vendor commitments in {location} restrict additional sponsorships.",
        f"The event timing in {location} overlaps with an internal campaign freeze.",
        f"We are prioritizing different categories for {event_type} in {location}.",
    ]

    if not approved:
        return json.dumps({
            "retailer": retailer,
            "status": "rejected",
            "reason": rng.choice(reject_reasons),
            "discountedItems": []
        })

    if not normalized_items:
        normalized_items = [{"item": "general supplies", "id": None}]

    percent_steps = list(range(5, 55, 5))
    target_count = max(1, int(round(len(normalized_items) * 0.2)))
    target_count = min(target_count, len(normalized_items))
    discounted_selection = rng.sample(normalized_items, k=target_count)
    discounted_names = {entry["item"] for entry in discounted_selection}

    discounted_items = []
    for entry in normalized_items:
        if entry["item"] in discounted_names:
            percent = rng.choice(percent_steps)
        else:
            percent = 0
        discounted_items.append({
            "item": entry["item"],
            "id": entry.get("id"),
            "percent": percent
        })

    overall_discount = int(sum(i["percent"] for i in discounted_items) / len(discounted_items))

    return json.dumps({
        "retailer": retailer,
        "status": "approved",
        "reason": rng.choice(approve_reasons),
        "discountPercent": overall_discount,
        "discountedItems": discounted_items
    })


def _build_where_clause(filters: Optional[Union[Filters, dict]]) -> Optional[dict]:
    """
    Build a ChromaDB where clause from Filters object or dict.
    
    Supports expandable filter types with AND relationship between filters.
    
    Args:
        filters: Filters object or dict of filters
    
    Returns:
        ChromaDB where clause dict using $and operator for multiple conditions
    """
    if not filters:
        return None
    
    # Convert Filters object to dict for processing
    if isinstance(filters, Filters):
        filters_dict = filters.to_dict()
    else:
        filters_dict = filters
    
    conditions = []
    
    # Handle delivery_time filter
    if "delivery_time" in filters_dict:
        delivery_filter = filters_dict["delivery_time"]
        
        if isinstance(delivery_filter, (int, float)):
            # Exact match: delivery_time=0
            conditions.append({"delivery_estimate": {"$eq": int(delivery_filter)}})
        elif isinstance(delivery_filter, dict):
            # Range filter: {"max": 1} or {"min": 1, "max": 2}
            if "max" in delivery_filter:
                conditions.append({"delivery_estimate": {"$lte": int(delivery_filter["max"])}})
            if "min" in delivery_filter:
                conditions.append({"delivery_estimate": {"$gte": int(delivery_filter["min"])}})
        else:
            logger.warning(f"Invalid delivery_time filter format: {delivery_filter}")
    
    # Handle price filter
    if "price" in filters_dict:
        price_filter = filters_dict["price"]
        
        if isinstance(price_filter, (int, float)):
            # Exact match: price=1.5
            conditions.append({"price": {"$eq": float(price_filter)}})
        elif isinstance(price_filter, dict):
            # Range filter: {"max": 2.0} or {"min": 1.0, "max": 3.0}
            if "max" in price_filter:
                conditions.append({"price": {"$lte": float(price_filter["max"])}})
            if "min" in price_filter:
                conditions.append({"price": {"$gte": float(price_filter["min"])}})
        else:
            logger.warning(f"Invalid price filter format: {price_filter}")
    
    # Return None if no valid conditions
    if not conditions:
        return None
    
    # Single condition: return as-is
    if len(conditions) == 1:
        return conditions[0]
    
    # Multiple conditions: combine with $and
    return {"$and": conditions}


def search_database(
    query, 
    similarity_threshold: float = 0.5, 
    top_results: int = 5,
    n_results: int = 20,
    filters: Optional[Union[Filters, dict]] = None,
    rag_pipeline = None
):
    """
    Search the vector database for similar items using semantic similarity with optional filtering.
    
    Supports both single and multiple query searches. When searching multiple items,
    top_results is applied per item (e.g., 2 items with top_results=5 returns up to 10 total).
    
    Filters are applied to the vector database BEFORE querying, reducing the search space.
    Multiple filters are combined with AND logic.
    
    Args:
        query: Single item name (str), JSON array string, or list of item names
        similarity_threshold: Minimum similarity score to filter results (default: 0.5)
        top_results: Maximum number of top results per query item (default: 5)
        n_results: Number of results to retrieve from vector DB before filtering (default: 20)
        filters: Optional Filters object or dict to apply before search.
            Filters object (recommended):
                Filters(delivery_time=0)  # Same-day delivery
                Filters(delivery_time=FilterRange(max=1))  # Max 1 day
                Filters(
                    delivery_time=FilterRange(min=1, max=2),
                    price=FilterRange(max=2.0)
                )
            Dict format (backward compatible):
                {"delivery_time": 0}
                {"delivery_time": {"max": 1}}
                {"delivery_time": {"min": 1, "max": 2}, "price": {"max": 2.0}}
        rag_pipeline: RAG pipeline instance for searching
    
    Returns:
        - If single query (str): List of top N filtered results
        - If multiple queries (list/JSON): List of dicts with 'query' and 'results' keys
          Example: [{"query": "item1", "results": [...]}, {"query": "item2", "results": [...]}]
    
    Examples:
        # Single query with no filters
        results = search_database("Banana Smoothie", top_results=5, rag_pipeline=rag)
        
        # Single query with same-day delivery filter
        results = search_database(
            "Banana Smoothie", 
            filters=Filters(delivery_time=0),
            rag_pipeline=rag
        )
        
        # Multiple queries with max 1-day delivery
        results = search_database(
            ["Banana", "Coffee"],
            filters=Filters(delivery_time=FilterRange(max=1)),
            top_results=3,
            rag_pipeline=rag
        )
        
        # Combined filters
        results = search_database(
            "Water",
            filters=Filters(
                delivery_time=0,
                price=FilterRange(max=1.0)
            ),
            rag_pipeline=rag
        )
    """
    if not rag_pipeline:
        logger.error("RAG pipeline not provided to search_database")
        return []
    
    # Parse query - could be single string, JSON array, or list
    queries = []
    is_single_query = False
    
    if isinstance(query, str):
        # Try to parse as JSON array first
        try:
            parsed = json.loads(query)
            if isinstance(parsed, list):
                queries = parsed
            else:
                # Single string that's valid JSON but not a list
                queries = [query]
                is_single_query = True
        except (json.JSONDecodeError, TypeError):
            # Plain string
            queries = [query]
            is_single_query = True
    elif isinstance(query, list):
        queries = query
    else:
        logger.error(f"Invalid query type: {type(query)}")
        return []
    
    # Build ChromaDB where clause from filters
    where_clause = _build_where_clause(filters)
    if where_clause:
        logger.debug(f"Applying filters: {filters} -> where clause: {where_clause}")
    
    logger.debug(f"Processing {len(queries)} queries")
    
    # Search for each query
    all_results = []
    for q in queries:
        # Search for similar items in vector DB with optional filtering
        results = rag_pipeline.search(q, n_results=n_results, where=where_clause)
        logger.debug(f"Found {len(results)} results from vector DB for '{q}'")
        
        # Filter by similarity threshold
        similar_items = [r for r in results if r.get("score", 0) > similarity_threshold]
        logger.debug(f"Filtered to {len(similar_items)} items with similarity > {similarity_threshold}")
        
        # Return only top N results per query
        top_items = similar_items[:top_results]
        logger.debug(f"Returning top {len(top_items)} results for '{q}'")
        
        all_results.append({
            "query": q,
            "results": top_items
        })
    
    # For backward compatibility: if single query, return flat list
    if is_single_query and len(all_results) == 1:
        return all_results[0]["results"]
    
    # For multiple queries, return structured response
    return all_results


def _calculate_price_range_for_item(
    item: str, 
    similarity_threshold: float, 
    top_results: int,
    rag_pipeline
) -> dict:
    """
    Helper function to calculate price range for a single item.
    
    Args:
        item: Item name to search for
        similarity_threshold: Minimum similarity score
        top_results: Number of top results to use for price calculation
        rag_pipeline: RAG pipeline instance
    """
    # Use search_database to get top similar items
    top_items = search_database(
        query=item,
        similarity_threshold=similarity_threshold,
        top_results=top_results,
        n_results=20,
        rag_pipeline=rag_pipeline
    )
    
    if not top_items:
        return {
            "success": False,
            "item": item,
            "error": f"No items found with similarity > {similarity_threshold}",
            "total_results": 0,
            "best_match_score": 0
        }

    # Extract prices from content
    prices = []
    for result in top_items:
        content = result.get("content", "")
        # Parse "Price: X.XX" from the formatted text
        price_match = re.search(r"Price:\s*([0-9]+\.?[0-9]*)", content)
        if price_match:
            try:
                price = float(price_match.group(1))
                prices.append(price)
            except ValueError:
                logger.warning(f"Could not parse price: {price_match.group(1)}")

    if not prices:
        return {
            "success": False,
            "item": item,
            "error": "No valid prices found in similar items",
            "similar_items_count": len(top_items)
        }

    # Calculate price range
    min_price = min(prices)
    max_price = max(prices)
    avg_price = sum(prices) / len(prices)

    return {
        "success": True,
        "item": item,
        "price_range": {
            "min": min_price,
            "max": max_price,
            "average": round(avg_price, 2)
        },
        "similar_items_count": len(top_items),
        "prices_found": len(prices),
        "similarity_threshold": similarity_threshold
    }


@tools.register
def get_price_range(
    items: str, 
    similarity_threshold: float = 0.5, 
    top_results: int = 5,
    registry: ToolRegistry = None
) -> str:
    """
    Search for similar items in the vector DB and calculate price ranges.
    
    Args:
        items: JSON array of item names, e.g. '["Banana Smoothie", "Water"]' or single item string
        similarity_threshold: Minimum similarity score (default: 0.5)
        top_results: Number of top similar items to use for price calculation (default: 5)
    
    Returns min/max/avg price from top N similar items for each queried item.
    """
    if not registry or not registry.rag_pipeline:
        logger.error("RAG pipeline not initialized")
        return json.dumps({
            "success": False,
            "error": "RAG pipeline not initialized"
        })

    try:
        # Parse items - could be JSON array or single string
        try:
            items_list = json.loads(items)
            if not isinstance(items_list, list):
                items_list = [items]
        except (json.JSONDecodeError, TypeError):
            # If not valid JSON, treat as single item
            items_list = [items]
        
        logger.info(f"get_price_range called for {len(items_list)} items, threshold={similarity_threshold}, top_results={top_results}")
        
        # Calculate price range for each item
        results = []
        for item in items_list:
            item_result = _calculate_price_range_for_item(
                item, 
                similarity_threshold,
                top_results,
                registry.rag_pipeline
            )
            results.append(item_result)
            
            if item_result["success"]:
                pr = item_result["price_range"]
                logger.info(f"✓ {item}: €{pr['min']:.2f} - €{pr['max']:.2f} (avg: €{pr['average']:.2f})")
            else:
                logger.warning(f"✗ {item}: {item_result.get('error', 'Unknown error')}")
        
        # Return results
        successful = sum(1 for r in results if r["success"])
        return json.dumps({
            "success": successful > 0,
            "items_processed": len(results),
            "items_successful": successful,
            "results": results
        }, indent=2)

    except Exception as e:
        logger.error(f"get_price_range failed: {e}", exc_info=True)
        return json.dumps({
            "success": False,
            "error": str(e)
        })