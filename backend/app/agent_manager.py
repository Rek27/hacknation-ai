"""
Agent manager with structured streaming outputs.
"""

import json
from typing import AsyncGenerator
from openai import AsyncOpenAI
from app.models import (
    ToolOutput,
    ToolResultOutput,
    TextChunk,
    ApiAnswerOutput,
    ErrorOutput
)
from app.tools import tools
from app.models.context import Context
from app.logger import get_logger

logger = get_logger(__name__)


class AgentManager:
    """Manages agent interactions with structured streaming."""

    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model
        logger.info(f"AgentManager initialized with model: {model}")

    async def stream_response(
        self, 
        context: Context, 
        user_message: str
    ) -> AsyncGenerator[str, None]:
        """
        Stream structured responses from the agent.

        Yields JSON strings of OutputItem objects.
        """
        logger.info(f"Starting stream for message: {user_message[:50]}...")

        # Add user message to context
        context.add_message("user", user_message)

        # Prepare messages for API
        messages = self._prepare_messages(context)

        # Get tools schema
        tools_schema = tools.get_openai_schema()

        try:
            # Stream from OpenAI
            stream = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                tools=tools_schema if tools_schema else None,
                stream=True,
                temperature=0.7,
            )

            current_tool_call = None
            collected_content = []
            tool_calls_made = []

            async for chunk in stream:
                delta = chunk.choices[0].delta

                # Handle tool calls
                if delta.tool_calls:
                    for tool_call in delta.tool_calls:
                        if tool_call.function:
                            # Start of a new tool call
                            if tool_call.function.name:
                                current_tool_call = {
                                    "id": f"call_{len(tool_calls_made)}",
                                    "name": tool_call.function.name,
                                    "arguments": ""
                                }
                                tool_calls_made.append(current_tool_call)

                                # Yield tool output signal
                                output = ToolOutput(
                                    name=tool_call.function.name,
                                    reason=f"Using {tool_call.function.name} to process request"
                                )
                                yield output.model_dump_json()
                                logger.info(f"Tool called: {tool_call.function.name}")

                            # Accumulate arguments
                            if tool_call.function.arguments and current_tool_call:
                                current_tool_call["arguments"] += tool_call.function.arguments

                # Handle text content
                if delta.content:
                    collected_content.append(delta.content)

                    # Yield text chunk
                    output = TextChunk(content=delta.content)
                    yield output.model_dump_json()

                # Check if streaming is done
                if chunk.choices[0].finish_reason:
                    finish_reason = chunk.choices[0].finish_reason
                    logger.info(f"Stream finished: {finish_reason}")

                    # Execute tools if needed
                    if finish_reason == "tool_calls" and tool_calls_made:
                        # Execute all tool calls
                        for tc in tool_calls_made:
                            tool_name = tc["name"]
                            arguments = json.loads(tc["arguments"])

                            logger.info(f"Executing tool: {tool_name} with args: {arguments}")
                            tool_result = await tools.execute(tool_name, arguments)

                            # Yield tool result
                            result_output = ToolResultOutput(
                                name=tool_name,
                                result=tool_result,
                                success=True
                            )
                            yield result_output.model_dump_json()

                        # Add to messages and continue
                        messages.append({
                            "role": "assistant",
                            "tool_calls": [{
                                "id": tc["id"],
                                "type": "function",
                                "function": {
                                    "name": tc["name"],
                                    "arguments": tc["arguments"]
                                }
                            } for tc in tool_calls_made]
                        })

                        for tc in tool_calls_made:
                            tool_result = await tools.execute(
                                tc["name"], 
                                json.loads(tc["arguments"])
                            )
                            messages.append({
                                "role": "tool",
                                "tool_call_id": tc["id"],
                                "content": tool_result
                            })

                        # Continue streaming
                        async for follow_up_chunk in self._continue_stream(messages, tools_schema):
                            yield follow_up_chunk

                    # Normal completion
                    elif finish_reason == "stop":
                        full_content = "".join(collected_content)
                        if full_content:
                            context.add_message("assistant", full_content)

                            # Yield final answer
                            answer = ApiAnswerOutput(
                                content=full_content,
                                metadata={"finish_reason": finish_reason}
                            )
                            yield answer.model_dump_json()

        except Exception as e:
            logger.error(f"Error in stream_response: {e}", exc_info=True)
            error = ErrorOutput(
                message=str(e),
                code="STREAM_ERROR"
            )
            yield error.model_dump_json()

    async def _continue_stream(
        self, 
        messages: list, 
        tools_schema: list
    ) -> AsyncGenerator[str, None]:
        """Continue streaming after tool execution."""
        stream = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            tools=tools_schema if tools_schema else None,
            stream=True,
            temperature=0.7,
        )

        collected_content = []

        async for chunk in stream:
            delta = chunk.choices[0].delta

            if delta.content:
                collected_content.append(delta.content)
                output = TextChunk(content=delta.content)
                yield output.model_dump_json()

            if chunk.choices[0].finish_reason == "stop":
                full_content = "".join(collected_content)
                if full_content:
                    answer = ApiAnswerOutput(
                        content=full_content,
                        metadata={"finish_reason": "stop"}
                    )
                    yield answer.model_dump_json()

    def _prepare_messages(self, context: Context) -> list:
        """Prepare messages for OpenAI API."""
        messages = []

        # System message
        system_parts = [
            f"You are a helpful AI assistant for {context.user_name}.",
            f"Current date: {context.current_date.strftime('%Y-%m-%d %H:%M:%S')}"
        ]

        # Add RAG context if available
        rag_context = context.get_rag_context()
        if rag_context:
            system_parts.append(f"\n\nRelevant context:\n{rag_context}")

        # Add page context if available
        if context.current_page_context:
            system_parts.append(f"\n\nCurrent page context: {context.current_page_context}")

        messages.append({
            "role": "system",
            "content": "\n".join(system_parts)
        })

        # Add conversation history
        messages.extend(context.get_conversation_history())

        return messages