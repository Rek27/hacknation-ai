"""
VoiceAgent — stateful voice interaction orchestrator.

Manages voice-based event planning flow through multiple phases:
1. Greeting & event type collection
2. Category selection from tree
3. Subcategory selection per category
4. Completion check
5. Form data collection
6. Shopping list generation & readout
7. Purchase confirmation
"""

import os
import hashlib
import json
from typing import Optional, AsyncGenerator
from openai import AsyncOpenAI
from rapidfuzz import fuzz, process

from app.models.context import Context
from app.models import TreeNode
from pydantic import TypeAdapter
from app.tree_agent import TreeAgent
from app.form_agent import FormAgent
from app.shopping_list_agent import ShoppingListAgent
from app.shopping_agent import ShoppingAgent
from app.logger import get_logger

logger = get_logger(__name__)


class VoiceAgent:
    """Orchestrates voice-based interaction flow with TTS/STT."""

    def __init__(
        self,
        api_key: str,
        tree_agent: TreeAgent,
        form_agent: FormAgent,
        shopping_list_agent: ShoppingListAgent,
        shopping_agent: ShoppingAgent,
        model: str = "gpt-4.1",
        tts_voice: str = "alloy",
    ):
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model
        self.tts_voice = tts_voice
        self.tree_agent = tree_agent
        self.form_agent = form_agent
        self.shopping_list_agent = shopping_list_agent
        self.shopping_agent = shopping_agent
        
        # TTS audio cache (in-memory, audio_id -> bytes)
        self.tts_cache: dict[str, bytes] = {}
        
        logger.info(f"VoiceAgent initialized with model: {model}, voice: {tts_voice}")

    # ── TTS & STT utilities ─────────────────────────────────────────────

    async def generate_tts(self, text: str) -> tuple[bytes, str]:
        """Generate TTS audio and return (audio_bytes, cache_id)."""
        # Generate cache key from text
        cache_key = hashlib.md5(text.encode()).hexdigest()
        
        if cache_key in self.tts_cache:
            logger.debug(f"TTS cache hit: {cache_key}")
            return self.tts_cache[cache_key], cache_key
        
        logger.info(f"Generating TTS for: {text[:50]}...")
        response = await self.client.audio.speech.create(
            model="tts-1",
            voice=self.tts_voice,
            input=text,
            response_format="mp3",
        )
        
        audio_bytes = response.content
        self.tts_cache[cache_key] = audio_bytes
        logger.debug(f"TTS generated: {cache_key}, size: {len(audio_bytes)} bytes")
        return audio_bytes, cache_key

    async def transcribe_audio(self, audio_bytes: bytes) -> str:
        """Transcribe audio using Whisper API."""
        logger.info(f"Transcribing audio, size: {len(audio_bytes)} bytes")
        
        # Save to temp file (Whisper requires file input)
        temp_path = f"/tmp/voice_input_{hashlib.md5(audio_bytes).hexdigest()}.webm"
        with open(temp_path, "wb") as f:
            f.write(audio_bytes)
        
        try:
            with open(temp_path, "rb") as f:
                transcript = await self.client.audio.transcriptions.create(
                    model="whisper-1",
                    file=f,
                    language="en",
                )
            
            logger.info(f"Transcribed: {transcript.text}")
            return transcript.text
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def get_cached_audio(self, audio_id: str) -> Optional[bytes]:
        """Retrieve cached TTS audio by ID."""
        return self.tts_cache.get(audio_id)

    # ── Fuzzy matching utilities ────────────────────────────────────────

    def fuzzy_match_categories(
        self, user_input: str, categories: list[str]
    ) -> list[tuple[str, float]]:
        """
        Match user input against available categories using fuzzy matching.
        Returns list of (category, score) tuples with score > 50.
        """
        if not categories:
            return []
        
        # First try to find all categories mentioned in the input
        matched_categories = []
        user_lower = user_input.lower()
        
        # Check each category individually
        for category in categories:
            category_lower = category.lower()
            
            # Check for exact match in the input
            if category_lower in user_lower:
                matched_categories.append((category, 100.0))
                continue
            
            # Use fuzzy matching for individual category
            score = fuzz.token_set_ratio(user_input, category)
            if score > 50:  # Lower threshold for better matching
                matched_categories.append((category, score))
        
        # Sort by score descending
        matched_categories.sort(key=lambda x: x[1], reverse=True)
        
        logger.debug(f"Fuzzy match '{user_input}' against {categories} -> {matched_categories}")
        return matched_categories

    def extract_yes_no(self, user_input: str) -> Optional[bool]:
        """Extract yes/no from user input. Returns True for yes, False for no, None if unclear."""
        text = user_input.lower().strip()
        
        # Positive responses
        if any(word in text for word in ["yes", "yeah", "yep", "sure", "correct", "right", "ok", "okay"]):
            return True
        
        # Negative responses
        if any(word in text for word in ["no", "nope", "nah", "incorrect", "wrong"]):
            return False
        
        return None

    def words_to_numbers(self, text: str) -> str:
        """Convert word numbers to digits (e.g., 'one hundred' -> '100')."""
        # Common word to number mappings
        word_to_num = {
            'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
            'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
            'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
            'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
            'eighteen': '18', 'nineteen': '19', 'twenty': '20', 'thirty': '30',
            'forty': '40', 'fifty': '50', 'sixty': '60', 'seventy': '70',
            'eighty': '80', 'ninety': '90', 'hundred': '100', 'thousand': '1000'
        }
        
        words = text.lower().split()
        result = []
        i = 0
        
        while i < len(words):
            word = words[i]
            
            # Check for simple word-to-number conversion
            if word in word_to_num:
                # Handle "one hundred", "two hundred", etc.
                if i > 0 and result and result[-1].isdigit() and word == 'hundred':
                    result[-1] = str(int(result[-1]) * 100)
                elif i > 0 and result and result[-1].isdigit() and word == 'thousand':
                    result[-1] = str(int(result[-1]) * 1000)
                # Handle "twenty one", "thirty five", etc.
                elif i + 1 < len(words) and words[i + 1] in word_to_num and int(word_to_num.get(words[i + 1], 0)) < 10:
                    result.append(str(int(word_to_num[word]) + int(word_to_num[words[i + 1]])))
                    i += 1  # Skip next word
                else:
                    result.append(word_to_num[word])
            else:
                result.append(word)
            
            i += 1
        
        return ' '.join(result)

    # ── State initialization ────────────────────────────────────────────

    def init_voice_state(self) -> dict:
        """Initialize fresh voice state."""
        return {
            "phase": "greeting",
            "event_description": None,
            "selected_categories": [],
            "current_category_index": 0,
            "pending_confirmation": None,
            "form_fields": [
                {"label": "Address", "key": "address", "value": None},
                {"label": "Budget", "key": "budget", "value": None},
                {"label": "Date", "key": "date", "value": None},
                {"label": "Duration (hours)", "key": "duration", "value": None},
                {"label": "Number of attendees", "key": "numberOfAttendees", "value": None},
            ],
            "form_field_index": 0,
            "shopping_list_items": [],
            "shopping_list_generated": False,
            "cart": None,
        }

    # ── Main processing method ──────────────────────────────────────────

    async def process_voice_input(
        self, context: Context, transcribed_text: str
    ) -> dict:
        """
        Process transcribed user input and return next voice response.
        Returns dict with: text, audio_id, phase, data
        """
        state = context.get_voice_state()
        if not state:
            state = self.init_voice_state()
            context.save_voice_state(state)
        
        phase = state.get("phase", "greeting")
        logger.info(f"Processing voice input in phase: {phase}")
        
        # Route to appropriate handler
        if phase == "greeting":
            return await self.handle_greeting_phase(context, state)
        elif phase == "event_type":
            return await self.handle_event_type_phase(context, state, transcribed_text)
        elif phase == "category_confirmation":
            return await self.handle_category_confirmation(context, state, transcribed_text)
        elif phase == "category_selection":
            return await self.handle_category_selection_phase(context, state, transcribed_text)
        elif phase == "subcategory_selection":
            return await self.handle_subcategory_selection_phase(context, state, transcribed_text)
        elif phase == "completion_check":
            return await self.handle_completion_check_phase(context, state, transcribed_text)
        elif phase == "form_collection":
            return await self.handle_form_collection_phase(context, state, transcribed_text)
        elif phase == "shopping_list_readout_prompt":
            return await self.handle_shopping_list_prompt(context, state, transcribed_text)
        elif phase == "shopping_list_readout":
            return await self.handle_shopping_list_readout(context, state, transcribed_text)
        elif phase == "purchase_confirmation":
            return await self.handle_purchase_confirmation(context, state, transcribed_text)
        elif phase == "done":
            return await self.handle_done_phase(context, state)
        else:
            return await self.handle_error(f"Unknown phase: {phase}")

    # ── Phase handlers ──────────────────────────────────────────────────

    async def handle_greeting_phase(self, context: Context, state: dict) -> dict:
        """Initial greeting - ask what they're organizing."""
        text = "Hello, please tell me what you are organizing so I can further assist you."
        audio_bytes, audio_id = await self.generate_tts(text)
        
        state["phase"] = "event_type"
        context.save_voice_state(state)
        
        return {"text": text, "audio_id": audio_id, "phase": "event_type", "data": {}}

    async def handle_event_type_phase(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Process event description and generate trees."""
        logger.info(f"Event type: {user_input}")
        state["event_description"] = user_input
        
        # Generate trees using TreeAgent
        logger.info("Generating trees with TreeAgent...")
        people_tree = []
        place_tree = []
        
        try:
            async for output_json in self.tree_agent.stream_response(context, user_input):
                output = json.loads(output_json)
                logger.debug(f"TreeAgent output type: {output.get('type')}")
                if output.get("type") == "people_tree":
                    people_tree = output.get("nodes", [])
                    logger.info(f"Got people_tree with {len(people_tree)} nodes")
                elif output.get("type") == "place_tree":
                    place_tree = output.get("nodes", [])
                    logger.info(f"Got place_tree with {len(place_tree)} nodes")
        except Exception as e:
            logger.error(f"Error generating trees: {e}", exc_info=True)
            return await self.handle_error(f"Failed to generate event plan: {str(e)}")
        
        # Save trees to context
        if people_tree or place_tree:
            context.save_trees(people_tree, place_tree)
        else:
            # If no trees generated, try again with more explicit prompt
            logger.warning("No trees generated, retrying with explicit prompt")
            enhanced_prompt = f"Create a complete event planning tree for: {user_input}. Include both people-related needs (food, drinks, etc.) and place-related needs (furniture, decorations, etc.)."
            
            async for output_json in self.tree_agent.stream_response(context, enhanced_prompt):
                output = json.loads(output_json)
                if output.get("type") == "people_tree":
                    people_tree = output.get("nodes", [])
                    logger.info(f"Retry: Got people_tree with {len(people_tree)} nodes")
                elif output.get("type") == "place_tree":
                    place_tree = output.get("nodes", [])
                    logger.info(f"Retry: Got place_tree with {len(place_tree)} nodes")
            
            if people_tree or place_tree:
                context.save_trees(people_tree, place_tree)
        
        # Extract top-level category names
        categories = [node["label"] for node in people_tree]
        if not categories:
            logger.error("No categories in people_tree after tree generation")
            return await self.handle_error("I couldn't generate categories for your event. Please try describing it again with more details.")
        
        # Move to category selection
        state["phase"] = "category_selection"
        context.save_voice_state(state)
        
        categories_str = ", ".join(categories[:-1]) + f" and {categories[-1]}" if len(categories) > 1 else categories[0]
        text = f"I've prepared a plan for your event. The main categories are: {categories_str}. Which of these do you need? You can say them one by one or all at once."
        
        audio_bytes, audio_id = await self.generate_tts(text)
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": "category_selection",
            "data": {"categories": categories}
        }

    async def handle_category_selection_phase(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Match user input to categories with fuzzy matching."""
        people_tree = context.people_tree or []
        categories = [node["label"] for node in people_tree]
        
        # Fuzzy match
        matches = self.fuzzy_match_categories(user_input, categories)
        
        if not matches:
            text = "I didn't catch any valid categories. Could you repeat which categories you need?"
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "category_selection", "data": {}}
        
        # Check if all matches are perfect (100 score) - skip confirmation for exact matches
        all_perfect = all(score >= 95 for _, score in matches)
        high_confidence = [cat for cat, score in matches if score > 70]
        
        if all_perfect and high_confidence:
            # Perfect matches - accept immediately without confirmation
            matched_str = ", ".join(high_confidence[:-1]) + f" and {high_confidence[-1]}" if len(high_confidence) > 1 else high_confidence[0]
            logger.info(f"Perfect match(es): {high_confidence}, skipping confirmation")
            
            state["selected_categories"] = high_confidence
            state["current_category_index"] = 0
            state["phase"] = "subcategory_selection"
            context.save_voice_state(state)
            
            # Start subcategory selection for first category
            return await self.start_subcategory_selection(context, state)
            
        elif high_confidence:
            # High confidence but not perfect - ask for confirmation
            matched_str = ", ".join(high_confidence[:-1]) + f" and {high_confidence[-1]}" if len(high_confidence) > 1 else high_confidence[0]
            text = f"I heard {matched_str}. Is that correct?"
            audio_bytes, audio_id = await self.generate_tts(text)
            
            state["pending_confirmation"] = {
                "type": "categories",
                "items": high_confidence
            }
            state["phase"] = "category_confirmation"
            context.save_voice_state(state)
            
            return {"text": text, "audio_id": audio_id, "phase": "category_confirmation", "data": {"matched": high_confidence}}
        else:
            # Low confidence - ask for clarification
            text = f"I think you said {matches[0][0]}, but I'm not sure. Could you repeat which categories you need?"
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "category_selection", "data": {}}

    async def handle_category_confirmation(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Handle yes/no confirmation for matched categories."""
        confirmation = self.extract_yes_no(user_input)
        pending = state.get("pending_confirmation", {})
        
        if confirmation is True:
            # User confirmed - save selected categories
            categories = pending.get("items", [])
            state["selected_categories"] = categories
            state["current_category_index"] = 0
            state["pending_confirmation"] = None
            state["phase"] = "subcategory_selection"
            context.save_voice_state(state)
            
            # Start subcategory selection for first category
            return await self.start_subcategory_selection(context, state)
        elif confirmation is False:
            # User rejected - go back to category selection
            text = "Okay, which categories do you need?"
            audio_bytes, audio_id = await self.generate_tts(text)
            
            state["pending_confirmation"] = None
            state["phase"] = "category_selection"
            context.save_voice_state(state)
            
            return {"text": text, "audio_id": audio_id, "phase": "category_selection", "data": {}}
        else:
            # Unclear - ask again
            text = "I didn't understand. Please say yes or no."
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "category_confirmation", "data": {}}

    async def start_subcategory_selection(self, context: Context, state: dict) -> dict:
        """Start subcategory selection for current category."""
        selected_categories = state.get("selected_categories", [])
        current_index = state.get("current_category_index", 0)
        
        if current_index >= len(selected_categories):
            # Done with all categories - move to completion check
            state["phase"] = "completion_check"
            context.save_voice_state(state)
            return await self.handle_completion_check_start(context, state)
        
        current_category = selected_categories[current_index]
        
        # Find the category node in people_tree
        people_tree = context.people_tree or []
        category_node = None
        for node in people_tree:
            if node["label"] == current_category:
                category_node = node
                break
        
        if not category_node or not category_node.get("children"):
            # No subcategories - move to next category
            state["current_category_index"] += 1
            context.save_voice_state(state)
            return await self.start_subcategory_selection(context, state)
        
        # List subcategories
        subcategories = [child["label"] for child in category_node["children"]]
        subcat_str = ", ".join(subcategories[:-1]) + f" and {subcategories[-1]}" if len(subcategories) > 1 else subcategories[0]
        
        text = f"For {current_category}, the options are: {subcat_str}. Which do you need?"
        audio_bytes, audio_id = await self.generate_tts(text)
        
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": "subcategory_selection",
            "data": {"category": current_category, "subcategories": subcategories}
        }

    async def handle_subcategory_selection_phase(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Handle subcategory selection within a category."""
        selected_categories = state.get("selected_categories", [])
        current_index = state.get("current_category_index", 0)
        
        if current_index >= len(selected_categories):
            # Shouldn't happen but handle gracefully
            logger.warning("Current index exceeds selected categories")
            state["phase"] = "completion_check"
            context.save_voice_state(state)
            return await self.handle_completion_check_start(context, state)
        
        current_category = selected_categories[current_index]
        
        # Find category node
        people_tree = context.people_tree or []
        category_node = None
        for node in people_tree:
            if node["label"] == current_category:
                category_node = node
                break
        
        if not category_node:
            return await self.handle_error("Category not found")
        
        subcategories = [child["label"] for child in category_node.get("children", [])]
        
        # Fuzzy match subcategories (more lenient matching)
        matches = self.fuzzy_match_categories(user_input, subcategories)
        
        if not matches:
            # List the subcategories again to help user
            subcat_str = ", ".join(subcategories[:-1]) + f" and {subcategories[-1]}" if len(subcategories) > 1 else subcategories[0]
            text = f"I didn't catch any valid subcategories for {current_category}. The options are: {subcat_str}. Which do you need?"
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "subcategory_selection", "data": {}}
        
        # Mark matched subcategories as selected (lower threshold)
        matched_items = [cat for cat, score in matches if score > 60]
        if not matched_items:
            # If no matches above 60, take the best match if > 50
            matched_items = [matches[0][0]] if matches and matches[0][1] > 50 else []
        
        logger.info(f"Matched subcategories for {current_category}: {matched_items}")
        
        for child in category_node["children"]:
            if child["label"] in matched_items:
                child["selected"] = True
        
        # Mark parent as selected too
        category_node["selected"] = True
        
        # Save updated tree
        context.save_trees(people_tree, context.place_tree or [])
        
        # Move to next category
        state["current_category_index"] += 1
        context.save_voice_state(state)
        
        return await self.start_subcategory_selection(context, state)

    async def handle_completion_check_start(self, context: Context, state: dict) -> dict:
        """Ask user if they're done or want to add more."""
        text = "We've gone through your selected categories. Would you like to hear the remaining categories, add more specific categories, or are you done and ready to proceed?"
        audio_bytes, audio_id = await self.generate_tts(text)
        return {"text": text, "audio_id": audio_id, "phase": "completion_check", "data": {}}

    async def handle_completion_check_phase(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Handle completion check - done/hear remaining/add more."""
        user_lower = user_input.lower()
        
        # Check if user wants to hear remaining categories
        if any(word in user_lower for word in ["remaining", "rest", "other", "more categories", "what else"]):
            people_tree = context.people_tree or []
            selected_cats = state.get("selected_categories", [])
            remaining = [node["label"] for node in people_tree if node["label"] not in selected_cats]
            
            if remaining:
                remaining_str = ", ".join(remaining[:-1]) + f" and {remaining[-1]}" if len(remaining) > 1 else remaining[0]
                text = f"The remaining categories are: {remaining_str}. Which of these do you need?"
                state["phase"] = "category_selection"
                context.save_voice_state(state)
            else:
                text = "There are no remaining categories. Are you ready to proceed?"
            
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": state["phase"], "data": {}}
        
        # Check if user wants to add more categories
        elif any(word in user_lower for word in ["add", "more", "another", "also"]):
            text = "Which additional categories would you like to add?"
            state["phase"] = "category_selection"
            context.save_voice_state(state)
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "category_selection", "data": {}}
        
        # Check if user is done
        elif any(word in user_lower for word in ["done", "proceed", "ready", "continue", "yes", "finish"]):
            # Move to form collection
            state["phase"] = "form_collection"
            state["form_field_index"] = 0
            context.save_voice_state(state)
            return await self.start_form_collection(context, state)
        
        else:
            # Unclear - ask again
            text = "I didn't understand. Would you like to hear the remaining categories, add more, or are you done?"
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "completion_check", "data": {}}

    async def start_form_collection(self, context: Context, state: dict) -> dict:
        """Start collecting form data."""
        form_fields = state.get("form_fields", [])
        field_index = state.get("form_field_index", 0)
        
        if field_index >= len(form_fields):
            # All fields collected - generate shopping list
            return await self.generate_shopping_list(context, state)
        
        field = form_fields[field_index]
        text = f"What is the {field['label'].lower()} for your event?"
        audio_bytes, audio_id = await self.generate_tts(text)
        
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": "form_collection",
            "data": {"field": field["label"], "field_index": field_index}
        }

    async def handle_form_collection_phase(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Collect form field values."""
        form_fields = state.get("form_fields", [])
        field_index = state.get("form_field_index", 0)
        
        if field_index >= len(form_fields):
            return await self.generate_shopping_list(context, state)
        
        # Convert word numbers to digits for numeric fields
        processed_input = self.words_to_numbers(user_input)
        
        # Save the value
        field = form_fields[field_index]
        field["value"] = processed_input
        
        # Confirm and move to next field
        confirmation = f"Got it, the {field['label'].lower()} is {user_input}."
        field_index += 1
        state["form_field_index"] = field_index
        context.save_voice_state(state)
        
        if field_index >= len(form_fields):
            # All fields collected - save form data
            from app.models import TextFieldChunk
            form_data_list = []
            for f in form_fields:
                form_data_list.append(TextFieldChunk(label=f["label"], content=f["value"] or ""))
            context.save_form(form_data_list)
            
            # Immediately generate shopping list without waiting for more input
            text = confirmation + " I have all the information I need. Let me prepare your shopping list."
            audio_bytes, audio_id = await self.generate_tts(text)
            
            # Generate shopping list right away
            logger.info("All form fields collected, generating shopping list...")
            try:
                # Convert dict trees to TreeNode objects
                tree_adapter = TypeAdapter(list[TreeNode])
                people_tree_nodes = tree_adapter.validate_python(context.people_tree) if context.people_tree else []
                place_tree_nodes = tree_adapter.validate_python(context.place_tree) if context.place_tree else []
                
                items, price_ranges, quantities = await self.shopping_list_agent.generate_shopping_list(
                    context=context,
                    people_tree=people_tree_nodes,
                    place_tree=place_tree_nodes,
                    form_data=context.form_data,
                )
                
                # Build cart (async) - returns 5 values (sponsorship streamed separately)
                cart, tool_events, missing_items, _retailer_items, _ctx = await self.shopping_agent.build_cart(
                    items=items,
                    price_ranges=price_ranges,
                    quantities=quantities,
                    form_data=context.form_data,
                )
                
                state["shopping_list_items"] = items
                state["shopping_list_generated"] = True
                state["cart"] = cart.model_dump()
                state["phase"] = "shopping_list_readout_prompt"
                context.save_voice_state(state)
                
                # Append the question about reading the list
                text = text + f" I've prepared your shopping list with {len(items)} items. Would you like me to read it out?"
                audio_bytes, audio_id = await self.generate_tts(text)
                
                return {
                    "text": text,
                    "audio_id": audio_id,
                    "phase": "shopping_list_readout_prompt",
                    "data": {"items_count": len(items)}
                }
            except Exception as e:
                logger.error(f"Error generating shopping list: {e}", exc_info=True)
                return await self.handle_error(f"Failed to generate shopping list: {str(e)}")
        else:
            # Ask for next field
            next_field = form_fields[field_index]
            text = confirmation + f" What is the {next_field['label'].lower()}?"
            audio_bytes, audio_id = await self.generate_tts(text)
            
            return {
                "text": text,
                "audio_id": audio_id,
                "phase": "form_collection",
                "data": {"field": next_field["label"], "field_index": field_index}
            }

    async def generate_shopping_list(self, context: Context, state: dict) -> dict:
        """Generate shopping list using ShoppingListAgent and ShoppingAgent."""
        logger.info("Generating shopping list...")
        
        # Generate shopping list
        items, price_ranges, quantities = await self.shopping_list_agent.generate_shopping_list(
            context=context,
            people_tree=context.people_tree,
            place_tree=context.place_tree,
            form_data=context.form_data,
        )
        
        # Build cart (sponsorship streamed separately in non-voice flow)
        cart, tool_events, missing_items, _retailer_items, _ctx = await self.shopping_agent.build_cart(
            items=items,
            price_ranges=price_ranges,
            quantities=quantities,
            form_data=context.form_data,
        )
        
        state["shopping_list_items"] = items
        state["shopping_list_generated"] = True
        state["cart"] = cart.model_dump()
        state["phase"] = "shopping_list_readout_prompt"
        context.save_voice_state(state)
        
        text = "I've prepared your shopping list. Would you like me to read it out?"
        audio_bytes, audio_id = await self.generate_tts(text)
        
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": "shopping_list_readout_prompt",
            "data": {"items_count": len(items)}
        }

    async def handle_shopping_list_prompt(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Handle yes/no for reading out shopping list."""
        confirmation = self.extract_yes_no(user_input)
        
        if confirmation is True:
            # Read out the shopping list
            state["phase"] = "shopping_list_readout"
            context.save_voice_state(state)
            return await self.read_shopping_list(context, state)
        elif confirmation is False:
            # Skip to purchase confirmation
            state["phase"] = "purchase_confirmation"
            context.save_voice_state(state)
            return await self.start_purchase_confirmation(context, state)
        else:
            text = "I didn't understand. Would you like me to read out the shopping list? Please say yes or no."
            audio_bytes, audio_id = await self.generate_tts(text)
            return {"text": text, "audio_id": audio_id, "phase": "shopping_list_readout_prompt", "data": {}}

    async def read_shopping_list(self, context: Context, state: dict) -> dict:
        """Read out each item in the shopping list."""
        cart_data = state.get("cart", {})
        items = cart_data.get("items", [])
        total_price = cart_data.get("price", 0.0)
        
        if not items:
            text = "The shopping list is empty."
            audio_bytes, audio_id = await self.generate_tts(text)
            state["phase"] = "purchase_confirmation"
            context.save_voice_state(state)
            return {"text": text, "audio_id": audio_id, "phase": "purchase_confirmation", "data": {}}
        
        # Build readout text
        readout_parts = ["Here is your shopping list:"]
        for item in items:
            recommended = item.get("recommendedItem", {}) or item.get("recommended_item", {})
            name = recommended.get("name", "Unknown item")
            amount = recommended.get("amount", 0)
            price = recommended.get("price", 0.0)
            item_total = amount * price
            
            readout_parts.append(
                f"{name}, quantity {amount} pieces, at the price of {price:.2f} euros each, totaling {item_total:.2f} euros."
            )
        
        readout_parts.append(f"The total cost is {total_price:.2f} euros.")
        
        text = " ".join(readout_parts)
        audio_bytes, audio_id = await self.generate_tts(text)
        
        state["phase"] = "purchase_confirmation"
        context.save_voice_state(state)
        
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": "purchase_confirmation",
            "data": {"total": total_price}
        }

    async def start_purchase_confirmation(self, context: Context, state: dict) -> dict:
        """Ask if user wants to proceed with purchase."""
        cart_data = state.get("cart", {})
        total_price = cart_data.get("price", 0.0)
        
        text = f"Would you like to continue with the purchase for a total of {total_price:.2f} euros?"
        audio_bytes, audio_id = await self.generate_tts(text)
        
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": "purchase_confirmation",
            "data": {"total": total_price}
        }

    async def handle_purchase_confirmation(
        self, context: Context, state: dict, user_input: str
    ) -> dict:
        """Handle purchase confirmation."""
        confirmation = self.extract_yes_no(user_input)
        
        if confirmation is True:
            text = "Great! Your purchase was successful. Thank you for using our service!"
            state["phase"] = "done"
            context.save_voice_state(state)
        elif confirmation is False:
            text = "No problem. Your shopping list has been saved. You can come back anytime to complete your purchase."
            state["phase"] = "done"
            context.save_voice_state(state)
        else:
            text = "I didn't understand. Would you like to continue with the purchase? Please say yes or no."
        
        audio_bytes, audio_id = await self.generate_tts(text)
        return {
            "text": text,
            "audio_id": audio_id,
            "phase": state["phase"],
            "data": {}
        }

    async def handle_done_phase(self, context: Context, state: dict) -> dict:
        """Handle done state."""
        text = "The voice session is complete. Thank you!"
        audio_bytes, audio_id = await self.generate_tts(text)
        return {"text": text, "audio_id": audio_id, "phase": "done", "data": {}}

    async def handle_error(self, error_message: str) -> dict:
        """Handle error state."""
        text = f"I'm sorry, there was an error: {error_message}. Please try again."
        audio_bytes, audio_id = await self.generate_tts(text)
        return {"text": text, "audio_id": audio_id, "phase": "error", "data": {"error": error_message}}
