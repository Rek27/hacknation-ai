from openai import OpenAI
from typing import AsyncGenerator
import json
from datetime import datetime
import time
from app.context import Context
from pathlib import Path
from app.tools import tools
from app.logger import get_logger

logger = get_logger(__name__)


class AgentManager:
    """Manages OpenAI Agent SDK interactions"""
    
    def __init__(self, api_key: str):
        self.client = OpenAI(api_key=api_key)
        self.model = "gpt-4o-mini"
        logger.info(f"AgentManager initialized with model: {self.model}")
        
    def load_instructions(self, context: Context) -> str:
        """Load and format instructions with dynamic context"""
        instructions_path = Path(__file__).parent / "instructions.md"
        
        logger.debug("Loading agent instructions")
        
        with open(instructions_path, 'r') as f:
            template = f.read()
        
        conversation_history = "\n".join([
            f"- {msg.role}: {msg.content}" 
            for msg in context.conversation[-5:]
        ])
        
        available_tools = ", ".join(tools.get_tool_names())
        
        instructions = template.format(
            current_date=context.current_date.strftime("%Y-%m-%d"),
            current_time=context.current_date.strftime("%H:%M:%S"),
            user_name=context.user_name,
            page_context=context.current_page_context or "N/A",
            rag_context=context.get_rag_context() or "No RAG context available",
            conversation_history=conversation_history or "No previous messages",
            available_tools=available_tools
        )
        
        return instructions
    
    async def stream_response(
        self, 
        context: Context, 
        user_message: str
    ) -> AsyncGenerator[str, None]:
        """Stream agent response with tool calls"""
        start_time = time.time()
        
        logger.info(
            f"Starting agent response stream",
            extra={
                "user_name": context.user_name,
                "message_preview": user_message[:50] + "..." if len(user_message) > 50 else user_message
            }
        )
        
        context.add_message("user", user_message)
        
        instructions = self.load_instructions(context)
        
        messages = [
            {"role": "system", "content": instructions},
            *context.get_conversation_history()
        ]
        
        tools_schema = tools.get_openai_schema()
        logger.debug(f"Using {len(tools_schema)} tools")
        
        max_iterations = 5
        iteration = 0
        total_tokens = 0
        
        while iteration < max_iterations:
            iteration += 1
            logger.debug(f"Agent iteration {iteration}/{max_iterations}")
            
            try:
                stream = self.client.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    tools=tools_schema,
                    stream=True,
                    temperature=0.7
                )
            except Exception as e:
                logger.error(f"Failed to create completion stream: {e}", exc_info=True)
                yield json.dumps({
                    "type": "error",
                    "message": f"API error: {str(e)}"
                }) + "\n"
                break
            
            full_response = ""
            tool_calls = []
            current_tool_call = None
            finish_reason = None
            
            for chunk in stream:
                delta = chunk.choices[0].delta
                finish_reason = chunk.choices[0].finish_reason
                
                if delta.tool_calls:
                    for tool_call_delta in delta.tool_calls:
                        if tool_call_delta.index is not None:
                            if current_tool_call is None or tool_call_delta.index != current_tool_call.get('index'):
                                current_tool_call = {
                                    'index': tool_call_delta.index,
                                    'id': tool_call_delta.id or '',
                                    'name': '',
                                    'arguments': ''
                                }
                                tool_calls.append(current_tool_call)
                        
                        if tool_call_delta.function:
                            if tool_call_delta.function.name:
                                current_tool_call['name'] = tool_call_delta.function.name
                                logger.info(
                                    f"Tool call initiated: {current_tool_call['name']}",
                                    extra={"tool_name": current_tool_call['name']}
                                )
                                yield json.dumps({
                                    "type": "tool_call_start",
                                    "tool_name": current_tool_call['name'],
                                    "tool_id": current_tool_call['id']
                                }) + "\n"
                            
                            if tool_call_delta.function.arguments:
                                current_tool_call['arguments'] += tool_call_delta.function.arguments
                
                if delta.content:
                    content = delta.content
                    full_response += content
                    yield json.dumps({
                        "type": "content",
                        "data": content
                    }) + "\n"
            
            if finish_reason != "tool_calls":
                logger.debug(f"Stream finished with reason: {finish_reason}")
                break
            
            if tool_calls:
                logger.info(f"Executing {len(tool_calls)} tool calls")
                tool_messages = []
                
                for tool_call in tool_calls:
                    tool_start = time.time()
                    
                    try:
                        args = json.loads(tool_call['arguments'])
                    except Exception as e:
                        logger.error(f"Failed to parse tool arguments: {e}")
                        args = {}
                    
                    logger.info(
                        f"Executing tool: {tool_call['name']}",
                        extra={
                            "tool_name": tool_call['name'],
                            "arguments": args
                        }
                    )
                    
                    yield json.dumps({
                        "type": "tool_executing",
                        "tool_name": tool_call['name'],
                        "arguments": args
                    }) + "\n"
                    
                    try:
                        result = await tools.execute(tool_call['name'], args)
                        tool_duration = (time.time() - tool_start) * 1000
                        
                        logger.info(
                            f"Tool execution completed: {tool_call['name']}",
                            extra={
                                "tool_name": tool_call['name'],
                                "duration": round(tool_duration, 2)
                            }
                        )
                        
                        yield json.dumps({
                            "type": "tool_result",
                            "tool_name": tool_call['name'],
                            "result": result
                        }) + "\n"
                    except Exception as e:
                        logger.error(
                            f"Tool execution failed: {tool_call['name']} - {e}",
                            exc_info=True,
                            extra={"tool_name": tool_call['name']}
                        )
                        result = json.dumps({"error": str(e)})
                    
                    tool_messages.append({
                        "role": "assistant",
                        "tool_calls": [{
                            "id": tool_call['id'],
                            "type": "function",
                            "function": {
                                "name": tool_call['name'],
                                "arguments": tool_call['arguments']
                            }
                        }]
                    })
                    tool_messages.append({
                        "role": "tool",
                        "tool_call_id": tool_call['id'],
                        "content": result
                    })
                
                messages.extend(tool_messages)
            else:
                break
        
        if full_response:
            context.add_message("assistant", full_response)
        
        total_duration = (time.time() - start_time) * 1000
        logger.info(
            f"Agent response completed",
            extra={
                "duration": round(total_duration, 2),
                "iterations": iteration,
                "response_length": len(full_response)
            }
        )
