"""
Tool implementations.

Add new tools here and register them with the @tools.register decorator.
"""

import json
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