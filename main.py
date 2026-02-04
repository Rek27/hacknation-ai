"""
FastAPI Chat Agent Application

This application provides endpoints for interacting with chat agents,
supporting both streaming and non-streaming modes.
"""

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import List, Optional, AsyncIterator
import asyncio
import json
from datetime import datetime

# Create FastAPI app
app = FastAPI(
    title="HackNation AI Chat API",
    description="FastAPI endpoints for chat agents with streaming and non-streaming support",
    version="0.1.0"
)


# Pydantic models for request/response
class ChatMessage(BaseModel):
    """Represents a single message in a chat conversation"""
    role: str = Field(..., description="Role of the message sender (user, assistant, system)")
    content: str = Field(..., description="Content of the message")


class ChatRequest(BaseModel):
    """Request model for chat endpoints"""
    messages: List[ChatMessage] = Field(..., description="List of messages in the conversation")
    agent_id: Optional[str] = Field(default="default", description="ID of the agent to use")
    max_tokens: Optional[int] = Field(default=1000, description="Maximum tokens to generate")
    temperature: Optional[float] = Field(default=0.7, description="Temperature for response generation")


class ChatResponse(BaseModel):
    """Response model for non-streaming chat endpoint"""
    message: ChatMessage = Field(..., description="Generated response message")
    agent_id: str = Field(..., description="ID of the agent that generated the response")
    timestamp: str = Field(..., description="Timestamp of the response")
    tokens_used: int = Field(..., description="Number of tokens used")


class StreamChunk(BaseModel):
    """Model for streaming response chunks"""
    content: str = Field(..., description="Chunk of generated content")
    done: bool = Field(default=False, description="Whether this is the final chunk")
    agent_id: Optional[str] = None
    timestamp: Optional[str] = None


# Simple chat agent logic (placeholder implementation)
async def generate_chat_response(
    messages: List[ChatMessage],
    agent_id: str,
    max_tokens: int,
    temperature: float
) -> str:
    """
    Generate a chat response based on the input messages.
    This is a simple placeholder implementation.
    
    In a real application, this would integrate with an LLM or other AI service.
    """
    # Simple echo-style response for demonstration
    last_message = messages[-1].content if messages else ""
    
    response = (
        f"[Agent {agent_id}] I received your message: '{last_message}'. "
        f"This is a simple chat agent response. In a production system, "
        f"this would be replaced with actual LLM integration."
    )
    
    return response


async def generate_chat_response_stream(
    messages: List[ChatMessage],
    agent_id: str,
    max_tokens: int,
    temperature: float
) -> AsyncIterator[str]:
    """
    Generate a streaming chat response.
    Yields chunks of text as they are generated.
    """
    last_message = messages[-1].content if messages else ""
    
    # Simulate streaming response by splitting into chunks
    response_parts = [
        f"[Agent {agent_id}] ",
        "I received ",
        "your message: ",
        f"'{last_message}'. ",
        "This is ",
        "a streaming ",
        "chat response. ",
        "Each chunk ",
        "is sent ",
        "separately ",
        "to simulate ",
        "real-time ",
        "generation."
    ]
    
    for part in response_parts:
        # Simulate processing time
        await asyncio.sleep(0.1)
        yield part


# Non-streaming chat endpoint
@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    """
    Non-streaming chat endpoint.
    
    Receives a chat request and returns a complete response.
    
    Args:
        request: ChatRequest containing messages and configuration
        
    Returns:
        ChatResponse with the generated message
    """
    # Generate response
    response_content = await generate_chat_response(
        messages=request.messages,
        agent_id=request.agent_id,
        max_tokens=request.max_tokens,
        temperature=request.temperature
    )
    
    # Create response message
    response_message = ChatMessage(
        role="assistant",
        content=response_content
    )
    
    # Return complete response
    return ChatResponse(
        message=response_message,
        agent_id=request.agent_id,
        timestamp=datetime.utcnow().isoformat(),
        tokens_used=len(response_content.split())  # Simple token approximation
    )


# Streaming chat endpoint
@app.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    """
    Streaming chat endpoint.
    
    Receives a chat request and streams the response in chunks using Server-Sent Events.
    
    Args:
        request: ChatRequest containing messages and configuration
        
    Returns:
        StreamingResponse with chunks of generated text
    """
    async def generate_stream():
        """Generator function for streaming response"""
        # Stream the response content
        async for chunk in generate_chat_response_stream(
            messages=request.messages,
            agent_id=request.agent_id,
            max_tokens=request.max_tokens,
            temperature=request.temperature
        ):
            # Create chunk object
            chunk_obj = StreamChunk(
                content=chunk,
                done=False,
                agent_id=request.agent_id,
                timestamp=datetime.utcnow().isoformat()
            )
            
            # Yield as JSON with SSE format
            yield f"data: {chunk_obj.model_dump_json()}\n\n"
        
        # Send final chunk to indicate completion
        final_chunk = StreamChunk(
            content="",
            done=True,
            agent_id=request.agent_id,
            timestamp=datetime.utcnow().isoformat()
        )
        yield f"data: {final_chunk.model_dump_json()}\n\n"
    
    return StreamingResponse(
        generate_stream(),
        media_type="text/event-stream"
    )


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }


# Root endpoint with API information
@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "name": "HackNation AI Chat API",
        "version": "0.1.0",
        "endpoints": {
            "non_streaming": "/chat",
            "streaming": "/chat/stream",
            "health": "/health",
            "docs": "/docs"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
