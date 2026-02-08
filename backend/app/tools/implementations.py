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


def search_database(
    query, 
    similarity_threshold: float = 0.5, 
    top_results: int = 5,
    n_results: int = 20, 
    rag_pipeline = None
):
    """
    Search the vector database for similar items using semantic similarity.
    
    Supports both single and multiple query searches. When searching multiple items,
    top_results is applied per item (e.g., 2 items with top_results=5 returns up to 10 total).
    
    Args:
        query: Single item name (str), JSON array string, or list of item names
        similarity_threshold: Minimum similarity score to filter results (default: 0.5)
        top_results: Maximum number of top results per query item (default: 5)
        n_results: Number of results to retrieve from vector DB before filtering (default: 20)
        rag_pipeline: RAG pipeline instance for searching
    
    Returns:
        - If single query (str): List of top N filtered results
        - If multiple queries (list/JSON): List of dicts with 'query' and 'results' keys
          Example: [{"query": "item1", "results": [...]}, {"query": "item2", "results": [...]}]
    
    Examples:
        # Single query
        results = search_database("Banana Smoothie", top_results=5, rag_pipeline=rag)
        # Returns: [result1, result2, ...] (up to 5 results)
        
        # Multiple queries
        results = search_database(["Banana", "Coffee"], top_results=3, rag_pipeline=rag)
        # Returns: [
        #   {"query": "Banana", "results": [r1, r2, r3]},
        #   {"query": "Coffee", "results": [r1, r2, r3]}
        # ] (up to 3 results per item = 6 total)
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
    
    logger.debug(f"Processing {len(queries)} queries")
    
    # Search for each query
    all_results = []
    for q in queries:
        # Search for similar items in vector DB
        results = rag_pipeline.search(q, n_results=n_results)
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