"""
Context management models for conversation state.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class Message(BaseModel):
    """A single message in the conversation."""

    role: str = Field(..., description="Role: 'user', 'assistant', or 'system'")
    content: str = Field(..., description="Message content")
    timestamp: datetime = Field(default_factory=datetime.now)


class RAGChunk(BaseModel):
    """A retrieved chunk from RAG pipeline."""

    content: str = Field(..., description="Chunk content")
    metadata: dict = Field(default_factory=dict, description="Chunk metadata")
    score: float = Field(..., description="Relevance score")


class Context:
    """Holds conversation state and context information."""

    def __init__(self, user_name: str):
        self.user_name = user_name
        self.conversation: list[Message] = []
        self.current_date = datetime.now()
        self.current_page_context: Optional[str] = None
        self.rag_chunks: list[RAGChunk] = []

    def add_message(self, role: str, content: str) -> None:
        """Add a message to conversation history."""
        self.conversation.append(Message(role=role, content=content))

    def get_conversation_history(self) -> list[dict]:
        """Get conversation as list of dicts for API calls."""
        return [
            {"role": msg.role, "content": msg.content} 
            for msg in self.conversation
        ]

    def set_rag_chunks(self, chunks: list[RAGChunk]) -> None:
        """Update RAG chunks."""
        self.rag_chunks = chunks

    def get_rag_context(self) -> str:
        """Get formatted RAG context for prompt."""
        if not self.rag_chunks:
            return ""
        return "\n\n".join([
            f"[Chunk {i+1}]: {chunk.content}" 
            for i, chunk in enumerate(self.rag_chunks)
        ])

    def update_page_context(self, context: str) -> None:
        """Update current page context."""
        self.current_page_context = context