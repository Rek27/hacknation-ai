"""
Output models for structured streaming responses.
"""

from __future__ import annotations

from typing import Literal, Optional, Union
from pydantic import BaseModel, Field, ConfigDict


_model_config = ConfigDict(
    json_schema_extra={"additionalProperties": False},
    populate_by_name=True,
)


class TreeNode(BaseModel):
    """A single node in an event-planning tree."""

    emoji: str = Field(..., description="Single emoji symbol rendered in UI")
    label: str = Field(..., description="Display label for this node")
    selected: bool = Field(
        default=False,
        description="Whether the user has confirmed this node",
    )
    children: list[TreeNode] = Field(
        default_factory=list,
        description="Child nodes (max 6 per level)",
    )

    model_config = _model_config


TreeNode.model_rebuild()


class TextFieldChunk(BaseModel):
    """A single form field with a label and optional prefilled content."""

    label: str = Field(..., description="Field label")
    content: str = Field(
        default="",
        description="Prefilled value (empty string if not yet provided)",
    )

    model_config = _model_config


class TextChunk(BaseModel):
    """A short text message from the model."""

    type: Literal["text"] = "text"
    content: str = Field(..., description="Text content chunk")

    model_config = _model_config


class PeopleTreeTrunk(BaseModel):
    """Tree of people-related event needs."""

    type: Literal["people_tree"] = "people_tree"
    nodes: list[TreeNode] = Field(
        ...,
        description="Top-level nodes (Food, Drinks, Entertainment, Accommodation)",
    )

    model_config = _model_config


class PlaceTreeTrunk(BaseModel):
    """Tree of place/venue-related event needs."""

    type: Literal["place_tree"] = "place_tree"
    nodes: list[TreeNode] = Field(..., description="Top-level nodes (dynamic)")

    model_config = _model_config


class TextFormChunk(BaseModel):
    """Structured form with required fields."""

    type: Literal["text_form"] = "text_form"
    address: TextFieldChunk
    budget: TextFieldChunk
    date: TextFieldChunk
    duration: TextFieldChunk
    number_of_attendees: TextFieldChunk = Field(
        ...,
        alias="numberOfAttendees",
    )

    model_config = _model_config


class ItemsChunk(BaseModel):
    """Final list of detailed item names to be purchased."""

    type: Literal["items"] = "items"
    items: list[str] = Field(
        ...,
        description="Detailed names of each item to purchase",
    )

    model_config = _model_config


class ErrorOutput(BaseModel):
    """Error during processing."""

    type: Literal["error"] = "error"
    message: str = Field(..., description="Error message")
    code: Optional[str] = Field(None, description="Error code")

    model_config = _model_config


OutputItem = Union[
    TextChunk,
    PeopleTreeTrunk,
    PlaceTreeTrunk,
    TextFormChunk,
    ItemsChunk,
    ErrorOutput,
]