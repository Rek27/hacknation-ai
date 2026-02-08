"""
FormAgent — one-shot agent that generates a prefilled form from submitted trees.

Streams TextChunk (conversational intro) then a TextFormChunk via SSE.
Uses OpenAI tool calling with `emit_text` + `emit_form`.
"""

import json
from typing import AsyncGenerator
from openai import AsyncOpenAI
from app.models import (
    TreeNode,
    TextChunk,
    TextFieldChunk,
    TextFormChunk,
    ErrorOutput,
)
from app.models.context import Context
from app.logger import get_logger

logger = get_logger(__name__)


# ── emit_form tool schema ───────────────────────────────────────────────────

_TEXT_FIELD_SCHEMA = {
    "type": "object",
    "properties": {
        "label": {"type": "string", "description": "Field label"},
        "content": {
            "type": "string",
            "description": "Prefilled value or empty string",
        },
    },
    "required": ["label", "content"],
    "additionalProperties": False,
}

EMIT_FORM_TOOL: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "emit_text",
            "description": (
                "Send a short text message to the user. "
                "Use for a brief intro before the form."
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
    },
    {
        "type": "function",
        "function": {
            "name": "emit_form",
            "description": (
                "Emit a form for the user to review. "
                "Prefill fields with information already known from the tree selections."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "address": _TEXT_FIELD_SCHEMA,
                    "budget": _TEXT_FIELD_SCHEMA,
                    "date": _TEXT_FIELD_SCHEMA,
                    "duration": _TEXT_FIELD_SCHEMA,
                    "numberOfAttendees": _TEXT_FIELD_SCHEMA,
                },
                "required": [
                    "address",
                    "budget",
                    "date",
                    "duration",
                    "numberOfAttendees",
                ],
                "additionalProperties": False,
            },
            "strict": True,
        },
    },
]


# ── System prompt ───────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are **FormAgent**, a concise assistant that creates a purchase-planning form.

You have just received the user's confirmed event trees (what they need for people \
and for the venue). Your job:

1. Call `emit_text` with a **short** friendly message (1-2 sentences) acknowledging \
their selections and explaining you are preparing a form.
   - Do NOT include JSON, code blocks, lists, or markup in `emit_text`.
2. Then call `emit_form` with fields that must ALWAYS include:
   - Address
   - Budget
   - Date
   - Duration (days)
   - Number of attendees

Prefill `content` when the user previously provided it; otherwise use empty string.
Do not omit any required field.
"""


_FIELD_SPECS: list[tuple[str, list[str]]] = [
    ("Address", ["address", "location", "venue"]),
    ("Budget", ["budget", "price", "cost"]),
    ("Date", ["date", "event date"]),
    ("Duration (days)", ["duration", "duration (days)", "days"]),
    ("Number of attendees", ["number of attendees", "attendees", "guests", "guest count"]),
]


def _trees_to_text(
    people_tree: list[TreeNode] | None,
    place_tree: list[TreeNode] | None,
) -> str:
    """Serialize selected tree nodes into readable text for the prompt."""

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
        parts.append("### People Tree\n" + "\n".join(_fmt(people_tree)))
    if place_tree:
        parts.append("### Place Tree\n" + "\n".join(_fmt(place_tree)))
    return "\n\n".join(parts) if parts else "(no tree data)"


def _normalize_fields(
    ai_data: dict,
    prior_data: dict[str, str] | None,
) -> dict[str, TextFieldChunk]:
    """Ensure required fields exist and are prefilled when available."""
    ai_map: dict[str, str] = {}
    for key, field in ai_data.items():
        if isinstance(field, dict):
            label = str(field.get("label", "")).strip() or key
            content = str(field.get("content", "")).strip()
            ai_map[label.lower()] = content

    prior_map: dict[str, str] = prior_data or {}

    normalized: dict[str, TextFieldChunk] = {}
    for canonical_label, aliases in _FIELD_SPECS:
        content = ""
        for alias in [canonical_label.lower()] + aliases:
            if alias in ai_map and ai_map[alias]:
                content = ai_map[alias]
                break
        if not content:
            for alias in [canonical_label.lower()] + aliases:
                if alias in prior_map and prior_map[alias]:
                    content = prior_map[alias]
                    break
        normalized[canonical_label] = TextFieldChunk(
            label=canonical_label,
            content=content,
        )
    return normalized


def _sanitize_text(content: str) -> str:
    """Keep text short and strip any code/JSON artifacts."""
    cleaned = content.replace("```", " ").strip()
    if "{" in cleaned or "}" in cleaned:
        cleaned = cleaned.split("{", 1)[0].strip()
    # Keep only first 1-2 sentences
    parts = cleaned.split(".")
    short = ".".join(parts[:2]).strip()
    if short and not short.endswith("."):
        short += "."
    return short or "Preparing your form now."


# ── FormAgent ───────────────────────────────────────────────────────────────


class FormAgent:
    """One-shot streaming agent: TextChunk intro + TextFormChunk."""

    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model
        logger.info(f"FormAgent initialized with model: {model}")

    async def stream_form(
        self,
        context: Context,
        people_tree: list[TreeNode] | None,
        place_tree: list[TreeNode] | None,
        prior_fields: dict[str, str] | None = None,
    ) -> AsyncGenerator[str, None]:
        """Generate a streaming response: TextChunks then TextFormChunk.

        Yields JSON strings for SSE `data:` lines.
        """
        tree_text = _trees_to_text(people_tree, place_tree)
        logger.info(f"FormAgent generating form from trees:\n{tree_text[:200]}")

        messages: list[dict] = [{"role": "system", "content": _SYSTEM_PROMPT}]
        messages.extend(context.get_conversation_history())
        messages.append(
            {
                "role": "user",
                "content": (
                    "Here are my confirmed event selections:\n\n"
                    f"{tree_text}\n\n"
                    "Please prepare a form for me."
                ),
            }
        )

        max_iterations = 5
        for iteration in range(max_iterations):
            stream = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                tools=EMIT_FORM_TOOL,
                tool_choice="required",
                stream=True,
                temperature=0.5,
            )

            tool_calls: dict[int, dict] = {}

            async for chunk in stream:
                delta = chunk.choices[0].delta

                # Accumulate tool call deltas
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
                        try:
                            args = json.loads(tc["arguments"])
                        except json.JSONDecodeError as e:
                            logger.error(f"FormAgent parse error: {e}")
                            yield ErrorOutput(
                                message="Failed to parse tool data",
                                code="FORM_PARSE_ERROR",
                            ).model_dump_json()
                            continue

                        if tc["name"] == "emit_text":
                            safe_text = _sanitize_text(args["content"])
                            yield TextChunk(content=safe_text).model_dump_json()
                            continue

                        if tc["name"] == "emit_form":
                            try:
                                fields = _normalize_fields(
                                    args,
                                    prior_fields,
                                )
                                form = TextFormChunk(
                                    address=fields["Address"],
                                    budget=fields["Budget"],
                                    date=fields["Date"],
                                    duration=fields["Duration (days)"],
                                    number_of_attendees=fields["Number of attendees"],
                                )
                                yield form.model_dump_json(by_alias=True)
                                logger.info("FormAgent emitted structured form")
                            except KeyError as e:
                                logger.error(f"FormAgent field error: {e}")
                                yield ErrorOutput(
                                    message="Missing required form field",
                                    code="FORM_MISSING_FIELD",
                                ).model_dump_json()
                    return

        logger.warning("FormAgent hit max iterations")
