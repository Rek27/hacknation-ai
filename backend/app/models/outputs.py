"""
Output models for streaming responses.

All streaming objects inherit from OutputItem for type safety and easy extensibility.
"""

from typing import Literal, Optional, Union, Any
from pydantic import BaseModel, Field, ConfigDict


_model_config = ConfigDict(
    json_schema_extra={"additionalProperties": False},
    populate_by_name=True
)


class ToolOutput(BaseModel):
    """Signals that the agent decided to call a tool.

    The actual tool call including arguments is delivered via separate
    mechanisms. The frontend only needs to know which tool was invoked
    to display loading indicators or special UI affordances.
    """

    type: Literal["tool"] = "tool"
    name: str = Field(..., description="Name of the invoked tool")
    reason: Optional[str] = Field(None, description="Reason for the tool call")
    arguments: Optional[dict[str, Any]] = Field(None, description="Tool call arguments")

    model_config = _model_config

class ToolResultOutput(BaseModel):
    """Result from a tool execution."""

    type: Literal["tool_result"] = "tool_result"
    name: str = Field(..., description="Name of the tool that was executed")
    result: str = Field(..., description="Tool execution result")
    success: bool = Field(default=True, description="Whether the tool execution succeeded")

    model_config = _model_config


class TextChunk(BaseModel):
    """A chunk of streaming text from the model."""

    type: Literal["text"] = "text"
    content: str = Field(..., description="Text content chunk")

    model_config = _model_config


class ThinkingChunk(BaseModel):
    """Model's internal reasoning (for models that support thinking)."""

    type: Literal["thinking"] = "thinking"
    content: str = Field(..., description="Thinking content")

    model_config = _model_config


class ApiAnswerOutput(BaseModel):
    """The agent's final complete response to the user.

    Only generate after all necessary tool calls have been made.
    """

    type: Literal["answer"] = "answer"
    content: str = Field(..., description="Complete answer text")
    metadata: Optional[dict[str, Any]] = Field(
        default=None,
        description="Additional metadata (citations, sources, etc.)"
    )

    model_config = _model_config


class ErrorOutput(BaseModel):
    """Error during processing."""

    type: Literal["error"] = "error"
    message: str = Field(..., description="Error message")
    code: Optional[str] = Field(None, description="Error code")

    model_config = _model_config


# Union type for all possible output items
OutputItem = Union[
    ToolOutput,
    ToolResultOutput,
    TextChunk,
    ThinkingChunk,
    ApiAnswerOutput,
    ErrorOutput,
]


class StreamResponse(BaseModel):
    """Container for streaming response with multiple items."""

    items: list[OutputItem] = Field(default_factory=list)

    model_config = _model_config

    def add_item(self, item: OutputItem) -> None:
        """Add an item to the stream."""
        self.items.append(item)