import json
import inspect
from typing import Callable, Dict, Any, List
from datetime import datetime
from app.logger import get_logger

logger = get_logger(__name__)


class ToolRegistry:
    """Central registry for all tools"""
    
    def __init__(self, rag_pipeline=None):
        self._tools: Dict[str, Dict[str, Any]] = {}
        self.rag_pipeline = rag_pipeline
        logger.info("ToolRegistry initialized")
    
    def set_rag_pipeline(self, pipeline):
        """Set the RAG pipeline after initialization"""
        self.rag_pipeline = pipeline
        logger.info("RAG pipeline connected to ToolRegistry")
    
    def register(self, func: Callable):
        """Decorator to register a tool"""
        sig = inspect.signature(func)
        params = {}
        required = []
        
        for param_name, param in sig.parameters.items():
            if param_name == 'registry':  # Skip internal parameter
                continue
                
            param_type = "string"
            
            if param.annotation != inspect.Parameter.empty:
                if param.annotation == int:
                    param_type = "integer"
                elif param.annotation == float:
                    param_type = "number"
                elif param.annotation == bool:
                    param_type = "boolean"
            
            if param.default == inspect.Parameter.empty:
                required.append(param_name)
            
            params[param_name] = {
                "type": param_type,
                "description": f"Parameter {param_name}"
            }
        
        self._tools[func.__name__] = {
            "function": func,
            "description": func.__doc__ or "",
            "parameters": params,
            "required": required
        }
        
        logger.info(f"Tool registered: {func.__name__}")
        return func
    
    def get_openai_schema(self) -> List[Dict]:
        """Generate OpenAI tools schema from registered tools"""
        schema = []
        
        for name, tool in self._tools.items():
            schema.append({
                "type": "function",
                "function": {
                    "name": name,
                    "description": tool["description"].strip(),
                    "parameters": {
                        "type": "object",
                        "properties": tool["parameters"],
                        "required": tool["required"]
                    }
                }
            })
        
        return schema
    
    async def execute(self, tool_name: str, arguments: Dict) -> str:
        """Execute a tool by name"""
        if tool_name not in self._tools:
            logger.error(f"Unknown tool requested: {tool_name}")
            return json.dumps({"error": f"Unknown tool: {tool_name}"})
        
        tool = self._tools[tool_name]
        try:
            func = tool["function"]
            sig = inspect.signature(func)
            
            if 'registry' in sig.parameters:
                arguments['registry'] = self
            
            result = func(**arguments)
            
            if inspect.iscoroutine(result):
                result = await result
            
            return result
        except Exception as e:
            logger.error(
                f"Tool execution error: {tool_name} - {e}",
                exc_info=True,
                extra={"tool_name": tool_name}
            )
            return json.dumps({"error": str(e), "tool": tool_name})
    
    def get_tool_names(self) -> List[str]:
        """Get list of registered tool names"""
        return list(self._tools.keys())


# Create global registry
tools = ToolRegistry()


@tools.register
def get_rag_chunks(query: str, n_results: int = 3, registry: ToolRegistry = None) -> str:
    """Retrieve relevant document chunks based on a query using RAG"""
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
    """Get current weather for a location"""
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
    """Evaluate a mathematical expression"""
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
    """Search a database with filters"""
    logger.info(f"search_database called: query='{query}', filters='{filters}'")
    return json.dumps({
        "query": query,
        "filters": json.loads(filters) if filters else {},
        "results": [
            {"id": 1, "title": "Result 1", "relevance": 0.95},
            {"id": 2, "title": "Result 2", "relevance": 0.87}
        ]
    })
