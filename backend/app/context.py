from datetime import datetime
from typing import List, Dict, Optional
from pydantic import BaseModel


class Message(BaseModel):
    role: str
    content: str
    timestamp: datetime = datetime.now()


class RAGChunk(BaseModel):
    content: str
    metadata: Dict
    score: float


class Context:
    """Holds conversation state and context information"""
    
    def __init__(self, user_name: str):
        self.user_name = user_name
        self.conversation: List[Message] = []
        self.current_date = datetime.now()
        self.current_page_context: Optional[str] = None
        self.rag_chunks: List[RAGChunk] = []
    
    def add_message(self, role: str, content: str):
        """Add a message to conversation history"""
        self.conversation.append(Message(role=role, content=content))
    
    def get_conversation_history(self) -> List[Dict]:
        """Get conversation as list of dicts"""
        return [{"role": msg.role, "content": msg.content} 
                for msg in self.conversation]
    
    def set_rag_chunks(self, chunks: List[RAGChunk]):
        """Update RAG chunks"""
        self.rag_chunks = chunks
    
    def get_rag_context(self) -> str:
        """Get formatted RAG context"""
        if not self.rag_chunks:
            return ""
        return "\n\n".join([f"[Chunk {i+1}]: {chunk.content}" 
                            for i, chunk in enumerate(self.rag_chunks)])
    
    def update_page_context(self, context: str):
        """Update current page context"""
        self.current_page_context = context
