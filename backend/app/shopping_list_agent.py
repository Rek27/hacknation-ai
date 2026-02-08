"""
ShoppingListAgent — builds an internal shopping list and streams reasoning.

Streams TextChunk reasoning; returns ShoppingList internally (not to user).
"""

from __future__ import annotations

import json
import re
from typing import AsyncGenerator
from openai import AsyncOpenAI

from app.logger import get_logger
from app.models import TreeNode, TextChunk, ErrorOutput
from app.models.context import Context
from app.tools import tools
from app.tools.implementations import get_price_range
logger = get_logger(__name__)


_TEXT_TOOL: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "emit_text",
            "description": (
                "Send a short reasoning chunk to the user. "
                "Keep it concise and practical."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "content": {
                        "type": "string",
                        "description": "Short text to display to the user",
                    },
                },
                "required": ["content"],
                "additionalProperties": False,
            },
            "strict": True,
        },
    }
]


_ITEMS_TOOL: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "emit_items",
            "description": (
                "Emit a list of detailed item strings to purchase. "
                "Items must be specific and actionable."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "items": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Detailed item list",
                    }
                },
                "required": ["items"],
                "additionalProperties": False,
            },
            "strict": True,
        },
    }
]

_QUANTITY_TOOL: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "emit_quantities",
            "description": (
                "Emit quantities for each shopping list item. "
                "Quantities must be positive integers."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "quantities": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "item": {"type": "string"},
                                "quantity": {"type": "integer"},
                            },
                            "required": ["item", "quantity"],
                            "additionalProperties": False,
                        },
                        "description": "Quantity suggestions for each item",
                    }
                },
                "required": ["quantities"],
                "additionalProperties": False,
            },
            "strict": True,
        },
    }
]


_SYSTEM_PROMPT_LIST = """\
You are ShoppingListAgent. Build a concise, detailed shopping list for the event.
Use the selected tree nodes and form fields (budget, date, duration, attendees, address).
Each item should be specific (brand/type/size when possible), but keep the list practical.
When the user requests items that are not available, choose the most similar items from the \
provided inventory list. Only select items that are explicitly available in the inventory list.
Do not include quantities in the item names.
Return only by calling emit_items once.
"""


_SYSTEM_PROMPT_QUANTITIES = """\
You are ShoppingListAgent. Given the shopping list items, form fields (duration in hours), \
and selected tree nodes, propose quantities for each item.
Return only via emit_quantities with a quantity for every listed item.
"""


_SYSTEM_PROMPT_REASONING = """\
You are ShoppingListAgent. Stream short reasoning to the user about how the shopping list \
fits their budget and selections. Reference price range data and quantities when available.
Do not output the shopping list itself. Only call emit_text.
Provide 2-4 short, practical messages.
"""

_QUANTITY_SUFFIX_RE = re.compile(
    r"\((\d+)\s*(bottles?|cans?|packs?|pcs?|pieces?|units?)\)",
    re.IGNORECASE,
)


def _strip_quantity_from_item(item: str) -> tuple[str, int | None]:
    match = _QUANTITY_SUFFIX_RE.search(item)
    if not match:
        return item.strip(), None
    qty = int(match.group(1))
    cleaned = _QUANTITY_SUFFIX_RE.sub("", item).strip()
    # Remove dangling separators like "-" or ":" at end
    cleaned = cleaned.rstrip("-:").strip()
    return cleaned, qty

def get_unique_item_names(rag_pipeline=None) -> list[str]:
    """
    Retrieve all unique article names from the vector database.
    
    Returns:
        List of unique article names (e.g., ["Banana Smoothie", "Water 0.5L", ...])
    """
    logger.info("Retrieving unique item names from vector database")
    
    rag = rag_pipeline or tools.rag_pipeline
    if rag is None:
        logger.warning("RAG pipeline not available; returning empty inventory")
        return []
    
    # Get all documents from the collection
    results = rag.collection.get()
    
    # Extract unique article names from document texts
    unique_names = set()
    
    if results['documents']:
        for doc_text in results['documents']:
            # Parse the document text to extract the Article field
            # Format: "ID: 1, Article: Banana Smoothie, Price: 1.49, ..."
            parts = doc_text.split(", ")
            for part in parts:
                if part.strip().startswith("Article:"):
                    # Extract the article name after "Article: "
                    article_name = part.split("Article:", 1)[1].strip()
                    unique_names.add(article_name)
                    break
    
    result_list = sorted(list(unique_names))
    logger.info(f"Found {len(result_list)} unique item names")
    
    return result_list


def _prune_selected(nodes: list[TreeNode] | None) -> list[TreeNode]:
    """Return only selected nodes (and their selected descendants)."""
    if not nodes:
        return []
    pruned: list[TreeNode] = []
    for node in nodes:
        children = _prune_selected(node.children)
        if node.selected or children:
            pruned.append(
                TreeNode(
                    emoji=node.emoji,
                    label=node.label,
                    selected=True if (node.selected or children) else False,
                    children=children,
                )
            )
    return pruned


def _trees_to_text(people_tree: list[TreeNode], place_tree: list[TreeNode]) -> str:
    def _fmt(nodes: list[TreeNode], depth: int = 0) -> list[str]:
        lines: list[str] = []
        for n in nodes:
            prefix = "  " * depth
            check = "[x]" if n.selected else "[ ]"
            lines.append(f"{prefix}{check} {n.emoji} {n.label}")
            lines.extend(_fmt(n.children, depth + 1))
        return lines

    parts: list[str] = []
    if people_tree:
        parts.append("### People Tree (selected)\n" + "\n".join(_fmt(people_tree)))
    if place_tree:
        parts.append("### Place Tree (selected)\n" + "\n".join(_fmt(place_tree)))
    return "\n\n".join(parts) if parts else "(no selected tree data)"


def _format_form_data(form_data: dict[str, str]) -> str:
    if not form_data:
        return "(no form data)"
    lines = [f"- {k}: {v}" for k, v in form_data.items() if v]
    return "\n".join(lines) if lines else "(no form data)"


def _parse_price_range(raw: str) -> list[dict]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, dict):
        return []
    results = data.get("results")
    return results if isinstance(results, list) else []

def _parse_quantities(raw: str) -> dict[str, int]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    entries = data.get("quantities")
    if not isinstance(entries, list):
        return {}
    quantities: dict[str, int] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        item = str(entry.get("item", "")).strip()
        qty = entry.get("quantity")
        if not item or not isinstance(qty, int):
            continue
        if qty > 0:
            quantities[item] = qty
    return quantities


class ShoppingListAgent:
    """Generates a shopping list and streams reasoning text."""

    def __init__(self, api_key: str, model: str = "gpt-4.1"):
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model
        logger.info(f"ShoppingListAgent initialized with model: {model}")

    async def generate_shopping_list(
        self,
        context: Context,
        people_tree: list[TreeNode] | None,
        place_tree: list[TreeNode] | None,
        form_data: dict[str, str] | None,
    ) -> tuple[list[str], list[dict], dict[str, int]]:
        """Create a shopping list, fetch price ranges, and propose quantities."""
        pruned_people = _prune_selected(people_tree)
        pruned_place = _prune_selected(place_tree)
        tree_text = _trees_to_text(pruned_people, pruned_place)
        form_text = _format_form_data(form_data or {})
        available_items = get_unique_item_names()

        messages = [
            {"role": "system", "content": _SYSTEM_PROMPT_LIST},
            *context.get_conversation_history(),
            {
                "role": "user",
                "content": (
                    "Selected tree nodes:\n"
                    f"{tree_text}\n\n"
                    "Form data:\n"
                    f"{form_text}\n\n"
                    "Available inventory items (choose only from this list):\n"
                    f"{json.dumps(available_items, indent=2)}\n\n"
                    "Generate the shopping list now."
                ),
            },
        ]

        items: list[str] = []
        extracted_quantities: dict[str, int] = {}
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                tools=_ITEMS_TOOL,
                tool_choice="required",
                temperature=0.4,
            )
            tool_calls = response.choices[0].message.tool_calls or []
            for call in tool_calls:
                if call.function.name != "emit_items":
                    continue
                args = json.loads(call.function.arguments or "{}")
                raw_items = args.get("items", [])
                if isinstance(raw_items, list):
                    cleaned_items: list[str] = []
                    for raw in raw_items:
                        raw_item = str(raw).strip()
                        if not raw_item:
                            continue
                        cleaned, qty = _strip_quantity_from_item(raw_item)
                        cleaned_items.append(cleaned)
                        if qty and qty > 0:
                            extracted_quantities[cleaned] = qty
                    items = cleaned_items
        except Exception as e:
            logger.error(f"ShoppingListAgent list generation error: {e}", exc_info=True)

        price_ranges: list[dict] = []
        if items:
            try:
                raw = get_price_range(
                    json.dumps(items),
                    registry=tools,
                )
                price_ranges = _parse_price_range(raw)
            except Exception as e:
                logger.warning(
                    f"Price range tool failed: {e}",
                    exc_info=True,
                )

        quantities: dict[str, int] = {}
        if items:
            try:
                response = await self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": _SYSTEM_PROMPT_QUANTITIES},
                        *context.get_conversation_history(),
                        {
                            "role": "user",
                            "content": (
                                "Selected tree nodes:\n"
                                f"{tree_text}\n\n"
                                "Form data:\n"
                                f"{form_text}\n\n"
                                "Shopping list items:\n"
                                f"{json.dumps(items, indent=2)}\n\n"
                                "Provide quantities."
                            ),
                        },
                    ],
                    tools=_QUANTITY_TOOL,
                    tool_choice="required",
                    temperature=0.4,
                )
                tool_calls = response.choices[0].message.tool_calls or []
                for call in tool_calls:
                    if call.function.name != "emit_quantities":
                        continue
                    quantities = _parse_quantities(call.function.arguments or "")
            except Exception as e:
                logger.warning(
                    f"Quantity suggestion failed: {e}",
                    exc_info=True,
                )

        if extracted_quantities:
            quantities.update(extracted_quantities)

        return items, price_ranges, quantities

    async def stream_reasoning(
        self,
        context: Context,
        items: list[str],
        price_ranges: list[dict],
        quantities: dict[str, int],
        people_tree: list[TreeNode] | None,
        place_tree: list[TreeNode] | None,
        form_data: dict[str, str] | None,
    ) -> AsyncGenerator[str, None]:
        """Stream TextChunk reasoning about the shopping list."""
        pruned_people = _prune_selected(people_tree)
        pruned_place = _prune_selected(place_tree)
        tree_text = _trees_to_text(pruned_people, pruned_place)
        form_text = _format_form_data(form_data or {})
        price_text = json.dumps(price_ranges, indent=2) if price_ranges else "None"
        quantity_text = json.dumps(quantities, indent=2) if quantities else "None"

        messages = [
            {"role": "system", "content": _SYSTEM_PROMPT_REASONING},
            *context.get_conversation_history(),
            {
                "role": "user",
                "content": (
                    "Selected tree nodes:\n"
                    f"{tree_text}\n\n"
                    "Form data:\n"
                    f"{form_text}\n\n"
                    "Shopping list items:\n"
                    f"{json.dumps(items, indent=2)}\n\n"
                    "Price range data:\n"
                    f"{price_text}\n\n"
                    "Quantity suggestions:\n"
                    f"{quantity_text}\n\n"
                    "Stream concise reasoning now."
                ),
            },
        ]

        try:
            stream = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                tools=_TEXT_TOOL,
                tool_choice="required",
                stream=True,
                temperature=0.4,
            )
        except Exception as e:
            logger.error(f"ShoppingListAgent stream error: {e}", exc_info=True)
            yield ErrorOutput(message=str(e), code="SHOPPING_LIST_ERROR").model_dump_json()
            return

        tool_calls: dict[int, dict] = {}

        async for chunk in stream:
            delta = chunk.choices[0].delta
            if delta.tool_calls:
                for tc_delta in delta.tool_calls:
                    idx = tc_delta.index
                    if idx not in tool_calls:
                        tool_calls[idx] = {
                            "id": "",
                            "name": "",
                            "arguments": "",
                        }
                    if tc_delta.id:
                        tool_calls[idx]["id"] = tc_delta.id
                    if tc_delta.function:
                        if tc_delta.function.name:
                            tool_calls[idx]["name"] = tc_delta.function.name
                        if tc_delta.function.arguments:
                            tool_calls[idx]["arguments"] += (
                                tc_delta.function.arguments
                            )

            finish = chunk.choices[0].finish_reason
            if finish in ("tool_calls", "stop"):
                for idx in sorted(tool_calls):
                    tc = tool_calls[idx]
                    if tc["name"] != "emit_text":
                        continue
                    try:
                        args = json.loads(tc["arguments"])
                        content = str(args.get("content", "")).strip()
                        if content:
                            yield TextChunk(content=content).model_dump_json()
                    except json.JSONDecodeError:
                        yield ErrorOutput(
                            message="Failed to parse reasoning",
                            code="SHOPPING_LIST_PARSE_ERROR",
                        ).model_dump_json()
                return
