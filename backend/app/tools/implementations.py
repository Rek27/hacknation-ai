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


def _calculate_price_range_for_item(item: str, similarity_threshold: float, rag_pipeline) -> dict:
    """Helper function to calculate price range for a single item."""
    # Search for similar items (get more results to ensure we have enough above threshold)
    results = rag_pipeline.search(item, n_results=20)
    logger.debug(f"Found {len(results)} results from vector DB for '{item}'")

    # Filter by similarity threshold
    similar_items = [r for r in results if r.get("score", 0) > similarity_threshold]
    
    if not similar_items:
        return {
            "success": False,
            "item": item,
            "error": f"No items found with similarity > {similarity_threshold}",
            "total_results": len(results),
            "best_match_score": results[0].get("score", 0) if results else 0
        }

    # Take only top 5 most similar items
    top_items = similar_items[:5]
    logger.debug(f"Using top {len(top_items)} most similar items for '{item}'")

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
            "similar_items_count": len(similar_items)
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
def get_price_range(items: str, similarity_threshold: float = 0.5, registry: ToolRegistry = None) -> str:
    """
    Search for similar items in the vector DB and calculate price ranges.
    
    Args:
        items: JSON array of item names, e.g. '["Banana Smoothie", "Water"]' or single item string
        similarity_threshold: Minimum similarity score (default 0.5)
    
    Returns min/max/avg price from top 5 similar items for each queried item.
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
        
        logger.info(f"get_price_range called for {len(items_list)} items, threshold={similarity_threshold}")
        
        # Calculate price range for each item
        results = []
        for item in items_list:
            item_result = _calculate_price_range_for_item(
                item, 
                similarity_threshold, 
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