"""
Context management models for conversation state and persisted data.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

from app.models.outputs import TreeNode, TextFieldChunk


class Message(BaseModel):
    """A single message in the conversation."""

    role: str = Field(..., description="Role: 'user', 'assistant', or 'system'")
    content: str = Field(..., description="Message content")
    timestamp: datetime = Field(default_factory=datetime.now)


class Context:
    """Holds conversation state, trees, and form data for a session."""

    def __init__(self, user_name: str = "User"):
        self.user_name = user_name
        self.conversation: list[Message] = []
        self.current_date = datetime.now()

        # Persisted trees (set via /submit-tree)
        self.people_tree: Optional[list[TreeNode]] = None
        self.place_tree: Optional[list[TreeNode]] = None

        # Persisted form data (label -> content)
        self.form_data: dict[str, str] = {}

        # Voice interaction state
        self.voice_state: Optional[dict] = None

    # ── Conversation helpers ────────────────────────────────────────────

    def add_message(self, role: str, content: str) -> None:
        """Add a message to conversation history."""
        self.conversation.append(Message(role=role, content=content))

    def get_conversation_history(self) -> list[dict]:
        """Get conversation as list of dicts for OpenAI API."""
        return [
            {"role": msg.role, "content": msg.content}
            for msg in self.conversation
        ]

    # ── Tree persistence ────────────────────────────────────────────────

    def save_trees(
        self,
        people_tree: list[TreeNode],
        place_tree: list[TreeNode],
    ) -> None:
        """Persist the submitted trees."""
        self.people_tree = people_tree
        self.place_tree = place_tree

    # ── Form persistence ────────────────────────────────────────────────

    def save_form(self, fields: list[TextFieldChunk]) -> None:
        """Persist the submitted form data (label -> content)."""
        data: dict[str, str] = {}
        for field in fields:
            label = field.label.strip()
            if label:
                data[label.lower()] = (field.content or "").strip()
        self.form_data = data

    # ── Voice state persistence ─────────────────────────────────────────

    def save_voice_state(self, state: dict) -> None:
        """Persist voice interaction state."""
        self.voice_state = state

    def get_voice_state(self) -> dict:
        """Get current voice state or empty dict."""
        return self.voice_state or {}