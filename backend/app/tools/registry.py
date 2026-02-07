"""
Central registry for all tools with OpenAI schema generation.
"""

import json
import inspect
from typing import Callable, Any, Optional
from datetime import datetime

from app.logger import get_logger

logger = get_logger(__name__)


class ToolRegistry:
    """Central registry for all tools."""

    def __init__(self, rag_pipeline=None):
        self._tools: dict[str, dict[str, Any]] = {}
        self.rag_pipeline = rag_pipeline
        logger.info("ToolRegistry initialized")

    def set_rag_pipeline(self, pipeline) -> None:
        """Set the RAG pipeline after initialization."""
        self.rag_pipeline = pipeline
        logger.info("RAG pipeline connected to ToolRegistry")

    def register(self, func: Callable) -> Callable:
        """Decorator to register a tool."""
        sig = inspect.signature(func)
        params = {}
        required = []

        for param_name, param in sig.parameters.items():
            if param_name == 'registry':
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

    def get_openai_schema(self) -> list[dict]:
        """Generate OpenAI tools schema from registered tools."""
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

    async def execute(self, tool_name: str, arguments: dict) -> str:
        """Execute a tool by name."""
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

    def get_tool_names(self) -> list[str]:
        """Get list of registered tool names."""
        return list(self._tools.keys())