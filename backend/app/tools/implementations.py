"""
Tool implementations.

Add new tools here and register them with the @tools.register decorator.
"""

import json
import re
from datetime import datetime
from app.tools.registry import ToolRegistry
from app.logger import get_logger

logger = get_logger(__name__)

# Global registry instance
tools = ToolRegistry()


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


@tools.register
def search_database(query: str, filters: str = "{}") -> str:
    """Search a database with filters."""
    logger.info(f"search_database called: query='{query}', filters='{filters}'")
    return json.dumps({
        "query": query,
        "filters": json.loads(filters) if filters else {},
        "results": [
            {"id": 1, "title": "Result 1", "relevance": 0.95},
            {"id": 2, "title": "Result 2", "relevance": 0.87}
        ]
    })


@tools.register
def get_price_range(item: str, similarity_threshold: float = 0.5, registry: ToolRegistry = None) -> str:
    """
    Search for similar items in the vector DB and calculate price range.
    Returns min/max/avg price from top 5 items with similarity > threshold (default 0.5).
    """
    logger.info(f"get_price_range called: item='{item}', threshold={similarity_threshold}")

    if not registry or not registry.rag_pipeline:
        logger.error("RAG pipeline not initialized")
        return json.dumps({
            "success": False,
            "error": "RAG pipeline not initialized"
        })

    try:
        # Search for similar items (get more results to ensure we have enough above threshold)
        results = registry.rag_pipeline.search(item, n_results=20)
        logger.info(f"Found {len(results)} results from vector DB")

        # Filter by similarity threshold
        similar_items = [r for r in results if r.get("score", 0) > similarity_threshold]
        logger.info(f"Filtered to {len(similar_items)} items above threshold {similarity_threshold}")

        if not similar_items:
            return json.dumps({
                "success": False,
                "error": f"No items found with similarity > {similarity_threshold}",
                "searched_for": item,
                "total_results": len(results),
                "best_match_score": results[0].get("score", 0) if results else 0
            })

        # Take only top 5 most similar items
        top_items = similar_items[:5]
        logger.info(f"Using top {len(top_items)} most similar items for price calculation")

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
                    logger.debug(f"Extracted price: {price} (score: {result['score']:.3f})")
                except ValueError:
                    logger.warning(f"Could not parse price: {price_match.group(1)}")

        if not prices:
            return json.dumps({
                "success": False,
                "error": "No valid prices found in similar items",
                "searched_for": item,
                "similar_items_count": len(similar_items)
            })

        # Calculate price range
        min_price = min(prices)
        max_price = max(prices)
        avg_price = sum(prices) / len(prices)

        logger.info(f"Price range calculated: {min_price} - {max_price} (avg: {avg_price:.2f})")

        return json.dumps({
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
        }, indent=2)

    except Exception as e:
        logger.error(f"get_price_range failed: {e}", exc_info=True)
        return json.dumps({
            "success": False,
            "error": str(e)
        })