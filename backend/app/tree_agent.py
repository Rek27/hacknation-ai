"""
TreeAgent — streaming agent that builds interactive event-planning trees.

All output goes through tools (tool_choice="required"):
  - emit_text          → TextChunk
  - emit_people_tree   → PeopleTreeTrunk
  - emit_place_tree    → PlaceTreeTrunk

This guarantees the LLM never dumps raw markdown trees as plain text.
"""

import json
import os
from typing import AsyncGenerator
from openai import AsyncOpenAI
from app.models import ErrorOutput
from app.models.context import Context
from app.logger import get_logger

logger = get_logger(__name__)

# ── Recursive TreeNode JSON Schema for OpenAI strict mode ───────────────────

_TREE_NODE_SCHEMA = {
    "type": "object",
    "properties": {
        "emoji": {"type": "string", "description": "Single emoji symbol"},
        "label": {"type": "string", "description": "Node label"},
        "selected": {
            "type": "boolean",
            "description": "Whether the user confirmed this node",
        },
        "children": {
            "type": "array",
            "description": "Child nodes",
            "items": {"$ref": "#/$defs/TreeNode"},
        },
    },
    "required": ["emoji", "label", "selected", "children"],
    "additionalProperties": False,
}

_DEFS = {"TreeNode": _TREE_NODE_SCHEMA}


def _nodes_param(description: str) -> dict:
    """Build the `nodes` parameter schema with recursive TreeNode $defs."""
    return {
        "type": "object",
        "properties": {
            "nodes": {
                "type": "array",
                "description": description,
                "items": {"$ref": "#/$defs/TreeNode"},
            },
        },
        "required": ["nodes"],
        "additionalProperties": False,
        "$defs": _DEFS,
    }


# ── Emit tools (text + trees) ──────────────────────────────────────────────

EMIT_TOOLS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "emit_text",
            "description": (
                "Send a short text message to the user. "
                "Use for greetings, questions, confirmations — keep it brief."
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
            "name": "emit_people_tree",
            "description": (
                "Emit the full People Tree (what attendees need). "
                "First-level nodes MUST be exactly: Food, Drinks, Entertainment, Accommodation."
            ),
            "parameters": _nodes_param(
                "Top-level people-tree nodes "
                "(exactly: Food, Drinks, Entertainment, Accommodation)"
            ),
            "strict": True,
        },
    },
    {
        "type": "function",
        "function": {
            "name": "emit_place_tree",
            "description": (
                "Emit the full Place Tree (what the venue/location needs). "
                "First-level nodes are fully dynamic based on event type."
            ),
            "parameters": _nodes_param(
                "Top-level place-tree nodes (dynamic)"
            ),
            "strict": True,
        },
    },
]


# ── System prompt loader ────────────────────────────────────────────────────

_INSTRUCTIONS_PATH = os.path.join(os.path.dirname(__file__), "instructions.md")


def _load_system_prompt(context: Context) -> str:
    with open(_INSTRUCTIONS_PATH, "r", encoding="utf-8") as f:
        template = f.read()
    return template


# ── TreeAgent ───────────────────────────────────────────────────────────────


class TreeAgent:
    """Streaming agent that builds event-planning trees via OpenAI tool calling."""

    def __init__(self, api_key: str, model: str = "gpt-4.1"):
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model
        logger.info(f"TreeAgent initialized with model: {model}")

    async def stream_response(
        self,
        context: Context,
        user_message: str,
    ) -> AsyncGenerator[str, None]:
        """Stream structured responses via tool calls only.

        Yields JSON strings suitable for SSE `data:` lines.
        """
        logger.info(f"TreeAgent stream for: {user_message[:80]!r}")

        context.add_message("user", user_message)
        messages = self._prepare_messages(context)

        max_iterations = 10
        for iteration in range(max_iterations):
            logger.debug(f"TreeAgent iteration {iteration + 1}")

            stream = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                tools=EMIT_TOOLS,
                tool_choice="required",
                parallel_tool_calls=True,
                stream=True,
                temperature=0.7,
            )

            # tool_calls indexed by delta.tool_calls[].index
            tool_calls: dict[int, dict] = {}
            collected_text_for_context: list[str] = []
            emitted_people = False
            emitted_place = False
            emitted_text = False
            inserted_preface = False

            async for chunk in stream:
                delta = chunk.choices[0].delta

                # ── Accumulate tool-call deltas ─────────────────────────
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

                # ── Finish ──────────────────────────────────────────────
                finish = chunk.choices[0].finish_reason
                if finish in ("tool_calls", "stop"):
                    # Process all completed tool calls
                    assistant_tool_calls = []
                    has_only_text = True

                    for idx in sorted(tool_calls):
                        tc = tool_calls[idx]
                        assistant_tool_calls.append(
                            {
                                "id": tc["id"],
                                "type": "function",
                                "function": {
                                    "name": tc["name"],
                                    "arguments": tc["arguments"],
                                },
                            }
                        )

                        try:
                            args = json.loads(tc["arguments"])
                            output_json = self._build_output_json(
                                tc["name"], args
                            )
                            if output_json:
                                if tc["name"] == "emit_people_tree":
                                    if emitted_people:
                                        logger.info(
                                            "Skipping duplicate people_tree"
                                        )
                                        continue
                                    emitted_people = True
                                    if not emitted_text and not inserted_preface:
                                        preface = {
                                            "type": "text",
                                            "content": "Got it — here are the current trees.",
                                        }
                                        yield json.dumps(preface)
                                        collected_text_for_context.append(
                                            preface["content"]
                                        )
                                        emitted_text = True
                                        inserted_preface = True
                                if tc["name"] == "emit_place_tree":
                                    if emitted_place:
                                        logger.info(
                                            "Skipping duplicate place_tree"
                                        )
                                        continue
                                    emitted_place = True
                                    if not emitted_text and not inserted_preface:
                                        preface = {
                                            "type": "text",
                                            "content": "Got it — here are the current trees.",
                                        }
                                        yield json.dumps(preface)
                                        collected_text_for_context.append(
                                            preface["content"]
                                        )
                                        emitted_text = True
                                        inserted_preface = True

                                # Bridge text between the two trees
                                if (
                                    tc["name"] == "emit_place_tree"
                                    and emitted_people
                                ):
                                    bridge = {
                                        "type": "text",
                                        "content": (
                                            "Now let's look at what the venue "
                                            "itself will need:"
                                        ),
                                    }
                                    yield json.dumps(bridge)
                                    collected_text_for_context.append(
                                        bridge["content"]
                                    )

                                yield output_json
                                logger.info(f"Emitted {tc['name']}")

                                # Track text for conversation context
                                if tc["name"] == "emit_text":
                                    collected_text_for_context.append(
                                        args["content"]
                                    )
                                    emitted_text = True
                                else:
                                    has_only_text = False
                        except json.JSONDecodeError as e:
                            logger.error(f"Bad tool args: {e}")
                            yield ErrorOutput(
                                message=f"Invalid tool arguments for {tc['name']}",
                                code="TOOL_PARSE_ERROR",
                            ).model_dump_json()

                    # Save text to conversation history
                    if collected_text_for_context:
                        context.add_message(
                            "assistant",
                            "\n".join(collected_text_for_context),
                        )

                    # Done for this turn — all tool calls processed.
                    return

        logger.warning("TreeAgent hit max iterations")

    # ── Helpers ──────────────────────────────────────────────────────────────

    @staticmethod
    def _propagate_selection(nodes: list[dict]) -> None:
        """Ensure parent nodes are selected when any child is selected."""
        for node in nodes:
            children = node.get("children", []) or []
            if children:
                TreeAgent._propagate_selection(children)
                if any(child.get("selected") for child in children):
                    node["selected"] = True

    @staticmethod
    def _build_output_json(name: str, args: dict) -> str | None:
        """Build JSON string for the frontend.

        Tree data is passed through as-is (already validated by OpenAI
        strict mode) to avoid Pydantic re-validation issues with
        recursive models.
        """
        if name == "emit_text":
            return json.dumps({"type": "text", "content": args["content"]})
        if name == "emit_people_tree":
            nodes = args.get("nodes", [])
            TreeAgent._propagate_selection(nodes)
            return json.dumps({"type": "people_tree", "nodes": nodes})
        if name == "emit_place_tree":
            nodes = args.get("nodes", [])
            if len(nodes) > 6:
                logger.info(
                    "Trimming place_tree top-level nodes from %d to 6",
                    len(nodes),
                )
                nodes = nodes[:6]
            TreeAgent._propagate_selection(nodes)
            return json.dumps({"type": "place_tree", "nodes": nodes})
        logger.warning(f"Unknown tool: {name}")
        return None

    def _prepare_messages(self, context: Context) -> list[dict]:
        """Build the messages list with system prompt + conversation history."""
        system_prompt = _load_system_prompt(context)
        messages: list[dict] = [{"role": "system", "content": system_prompt}]
        messages.extend(context.get_conversation_history())
        return messages
