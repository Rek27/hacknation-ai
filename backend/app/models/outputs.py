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


class RetailerOfferItem(BaseModel):
    """Discount detail for a single item from a retailer."""

    id: Optional[str] = Field(default=None, description="Optional item id")
    item: str = Field(..., description="Item name eligible for discount")
    percent: int = Field(..., description="Discount percent for this item")

    model_config = _model_config


class RetailerOffer(BaseModel):
    """Retailer sponsorship decision with item discounts."""

    retailer: str = Field(..., description="Retailer or store name")
    status: Literal["approved", "rejected"] = Field(
        ...,
        description="Sponsorship decision",
    )
    reason: Optional[str] = Field(
        default=None,
        description="Short rationale for approval or rejection",
    )
    discount_percent: Optional[int] = Field(
        default=None,
        alias="discountPercent",
        description="Overall discount percent when approved",
    )
    discounted_items: list[RetailerOfferItem] = Field(
        default_factory=list,
        alias="discountedItems",
        description="Per-item discount details",
    )

    model_config = _model_config


class RetailerOffersChunk(BaseModel):
    """Sponsorship decisions and discounts by retailer."""

    type: Literal["retailer_offers"] = "retailer_offers"
    offers: list[RetailerOffer] = Field(default_factory=list)

    model_config = _model_config


class RetailerCallStartChunk(BaseModel):
    """Signals that a sponsorship call to a retailer has started."""

    type: Literal["retailer_call_start"] = "retailer_call_start"
    retailer: str = Field(..., description="Retailer being contacted")
    item_count: int = Field(
        default=0,
        alias="itemCount",
        description="Number of items included in the sponsorship request",
    )

    model_config = _model_config


class ShoppingList(BaseModel):
    """Internal shopping list generated after form submission."""

    items: list[str] = Field(
        default_factory=list,
        description="Detailed names of each item to purchase",
    )

    model_config = _model_config


class CartItemDetail(BaseModel):
    """Single item option derived from vector DB results."""

    id: Optional[str] = Field(default=None, description="Optional item id")
    name: str = Field(..., description="Current item name")
    price: float = Field(..., description="Price per item")
    amount: int = Field(..., description="Quantity for this item")
    retailer: str = Field(..., description="Retailer or store name")
    review_rating: float = Field(
        default=0.0,
        alias="reviewRating",
        description="Average review rating (0 if unavailable)",
    )
    reviews_count: int = Field(
        default=0,
        alias="reviewsCount",
        description="Number of reviews (0 if unavailable)",
    )
    delivery_time_ms: int = Field(
        ...,
        alias="deliveryTimeMs",
        description="Delivery time in milliseconds",
    )
    image_url: Optional[str] = Field(
        default=None,
        alias="imageUrl",
        description="Public image URL for the item",
    )

    model_config = _model_config


class CartItem(BaseModel):
    """Cart entry containing recommended and alternative options."""

    recommended_item: CartItemDetail = Field(
        ...,
        alias="recommendedItem",
        description="Recommended item derived from top results",
    )
    cheapest_item: CartItemDetail = Field(
        ...,
        alias="cheapestItem",
        description="Cheapest item in the top results",
    )
    best_rating_item: CartItemDetail = Field(
        ...,
        alias="bestRatingItem",
        description="Highest rated item in the top results",
    )
    fastest_delivery_item: CartItemDetail = Field(
        ...,
        alias="fastestDeliveryItem",
        description="Fastest delivery item in the top results",
    )

    model_config = _model_config


class ChunkShoppingCart(BaseModel):
    """Cart chunk containing items and total price."""

    type: Literal["cart"] = "cart"
    items: list[CartItem] = Field(default_factory=list)
    price: float = Field(
        default=0.0,
        description="Total price across cart items",
    )

    model_config = _model_config


class ErrorOutput(BaseModel):
    """Error during processing."""

    type: Literal["error"] = "error"
    message: str = Field(..., description="Error message")
    code: Optional[str] = Field(None, description="Error code")

    model_config = _model_config


class VoicePromptChunk(BaseModel):
    """TTS prompt to be spoken to user."""

    type: Literal["voice_prompt"] = "voice_prompt"
    text: str = Field(..., description="Text to speak to user")
    audio_url: str = Field(..., description="URL to TTS audio file")
    phase: str = Field(..., description="Current phase of interaction")

    model_config = _model_config


class VoiceConfirmationChunk(BaseModel):
    """Request user confirmation via voice."""

    type: Literal["voice_confirmation"] = "voice_confirmation"
    question: str = Field(..., description="Confirmation question")
    matched_item: str = Field(..., description="What was matched")
    audio_url: str = Field(..., description="URL to TTS audio")

    model_config = _model_config


class VoiceStatusChunk(BaseModel):
    """Voice interaction status update."""

    type: Literal["voice_status"] = "voice_status"
    status: str = Field(..., description="listening, speaking, processing, done")
    message: Optional[str] = Field(None, description="Optional status message")

    model_config = _model_config


OutputItem = Union[
    TextChunk,
    PeopleTreeTrunk,
    PlaceTreeTrunk,
    TextFormChunk,
    ItemsChunk,
    RetailerCallStartChunk,
    RetailerOffersChunk,
    ChunkShoppingCart,
    ErrorOutput,
    VoicePromptChunk,
    VoiceConfirmationChunk,
    VoiceStatusChunk,
]