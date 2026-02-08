from fastapi import FastAPI, Request, UploadFile, File, Form as FastAPIForm
from fastapi.responses import StreamingResponse, HTMLResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import json
import os
import time
from dotenv import load_dotenv

from app.models import (
    TreeNode,
    TextFieldChunk,
    ErrorOutput,
    ItemsChunk,
    TextChunk,
    RetailerOffersChunk,
    CartItem,
)
from app.models.context import Context
from app.tree_agent import TreeAgent
from app.form_agent import FormAgent
from app.shopping_list_agent import ShoppingListAgent
from app.shopping_agent import ShoppingAgent
from app.voice_agent import VoiceAgent
from app.rag_pipeline import RAGPipeline
from app.tools import tools
from app.logger import setup_logging, get_logger
from app.rag_pipeline import RAGPipeline

load_dotenv()

# ── Logging ────────────────────────────────────────────────────────────────
setup_logging(
    log_level=os.getenv("LOG_LEVEL", "INFO"),
    log_to_file=True,
    log_to_console=True,
    json_logs=os.getenv("JSON_LOGS", "false").lower() == "true",
)

logger = get_logger(__name__)

# ── App ────────────────────────────────────────────────────────────────────
_tags_metadata = [
    {
        "name": "Meta",
        "description": "Service metadata and health checks.",
    },
    {
        "name": "Chat",
        "description": "TreeAgent streaming conversation endpoints.",
    },
    {
        "name": "Tree",
        "description": "Submit confirmed trees and generate a form.",
    },
    {
        "name": "Form",
        "description": "Submit the structured form data.",
    },
    {
        "name": "UI",
        "description": "Local test UI for manual verification.",
    },
]

app = FastAPI(
    title="Event Shopping Agent API",
    version="2.0.0",
    description=(
        "API for generating event shopping trees and structured forms. "
        "Streaming endpoints emit Server-Sent Events (SSE) with JSON-encoded "
        "payloads derived from the output models."
    ),
    openapi_tags=_tags_metadata,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    logger.info(
        f"Incoming: {request.method} {request.url.path}",
        extra={
            "method": request.method,
            "path": request.url.path,
            "client": request.client.host if request.client else "unknown",
        },
    )
    response = await call_next(request)
    duration = (time.time() - start_time) * 1000
    logger.info(
        f"Done: {request.method} {request.url.path} → {response.status_code} "
        f"({duration:.0f}ms)",
    )
    return response


# ── Agents & sessions ─────────────────────────────────────────────────────
api_key = os.getenv("OPENAI_API_KEY", "")
tree_agent = TreeAgent(api_key=api_key)
form_agent = FormAgent(api_key=api_key)
rag_pipeline = RAGPipeline()
tools.set_rag_pipeline(rag_pipeline)
shopping_list_agent = ShoppingListAgent(api_key=api_key)
shopping_agent = ShoppingAgent(rag_pipeline=rag_pipeline)
voice_agent = VoiceAgent(
    api_key=api_key,
    tree_agent=tree_agent,
    form_agent=form_agent,
    shopping_list_agent=shopping_list_agent,
    shopping_agent=shopping_agent,
)

# In-memory session store (swap for DB in production)
sessions: dict[str, Context] = {}


def _get_or_create_session(session_id: str, user_name: str = "User") -> Context:
    if session_id not in sessions:
        logger.info(f"New session: {session_id}")
        sessions[session_id] = Context(user_name=user_name)
    return sessions[session_id]


def _collect_selected_labels(nodes: list[TreeNode] | None) -> list[str]:
    labels: list[str] = []
    if not nodes:
        return labels
    for node in nodes:
        if node.selected:
            labels.append(node.label)
        if node.children:
            labels.extend(_collect_selected_labels(node.children))
    return labels


def _build_event_context(
    form_data: dict[str, str],
    people_tree: list[TreeNode] | None,
    place_tree: list[TreeNode] | None,
) -> str:
    parts: list[str] = []
    address = form_data.get("address")
    if address:
        parts.append(f"Address: {address}")
    date = form_data.get("date")
    if date:
        parts.append(f"Date: {date}")
    duration = form_data.get("duration")
    if duration:
        parts.append(f"Duration: {duration}")
    attendees = form_data.get("number of attendees")
    if attendees:
        parts.append(f"Attendees: {attendees}")
    people_labels = _collect_selected_labels(people_tree)
    if people_labels:
        parts.append(f"People selections: {', '.join(people_labels)}")
    place_labels = _collect_selected_labels(place_tree)
    if place_labels:
        parts.append(f"Place selections: {', '.join(place_labels)}")
    return ". ".join(parts)


async def _summarize_sponsorships(
    offers: list[dict],
    event_context: str,
) -> str | None:
    if not offers:
        return None
    try:
        prompt = (
            "Summarize the sponsorship outcomes in 1-2 short sentences. "
            "Reference approvals, rejections, and any notable discounts. "
            "Keep it concise and friendly.\n\n"
            f"Event context: {event_context}\n"
            f"Offers: {json.dumps(offers, ensure_ascii=False)}"
        )
        response = await shopping_list_agent.client.chat.completions.create(
            model=shopping_list_agent.model,
            messages=[
                {"role": "system", "content": "You summarize sponsorship results."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        logger.warning(f"Sponsorship summary failed: {e}", exc_info=True)
        return None




# ── Request models ─────────────────────────────────────────────────────────
class ChatRequest(BaseModel):
    session_id: str
    message: str
    user_name: str = "User"


class SubmitTreeRequest(BaseModel):
    session_id: str
    people_tree: list[TreeNode]
    place_tree: list[TreeNode]


class SubmitFormRequest(BaseModel):
    session_id: str
    address: TextFieldChunk
    budget: TextFieldChunk
    date: TextFieldChunk
    duration: TextFieldChunk
    number_of_attendees: TextFieldChunk = Field(
        ...,
        alias="numberOfAttendees",
    )


class RootResponse(BaseModel):
    service: str
    version: str
    endpoints: list[str]


class HealthResponse(BaseModel):
    status: str
    active_sessions: int


class RecommendationReasonRequest(BaseModel):
    cart_item: CartItem = Field(..., alias="cartItem")


class RecommendationReasonResponse(BaseModel):
    reasoning: str


class StartVoiceResponse(BaseModel):
    session_id: str
    text: str
    audio_id: str
    phase: str


class VoiceInputResponse(BaseModel):
    text: str
    audio_id: str
    phase: str
    data: dict
    transcribed_text: str = Field(default="", description="What the user said")
    wait_for_input: bool = Field(default=True, description="Whether to wait for user input")


# ── Endpoints ──────────────────────────────────────────────────────────────
@app.get(
    "/",
    response_model=RootResponse,
    tags=["Meta"],
    summary="API metadata",
    description="Returns service metadata and available endpoints.",
)
async def root():
    return {
        "service": "Event Shopping Agent API",
        "version": "2.0.0",
        "endpoints": ["/chat", "/submit-tree", "/submit-form", "/start-voice", "/voice-input", "/tts-audio/{id}", "/health", "/test"],
    }


@app.get(
    "/test",
    response_class=HTMLResponse,
    tags=["UI"],
    summary="Serve local test UI",
    description="Returns the bundled HTML test page.",
)
async def test_page():
    html_path = os.path.join(os.path.dirname(__file__), "test.html")
    with open(html_path, "r", encoding="utf-8") as f:
        return HTMLResponse(f.read())


@app.post(
    "/chat",
    tags=["Chat"],
    summary="Stream TreeAgent output",
    description=(
        "Streams Server-Sent Events (SSE). Each event is a JSON-encoded "
        "OutputItem such as TextChunk, PeopleTreeTrunk, PlaceTreeTrunk, or ErrorOutput."
    ),
    responses={
        200: {
            "description": "SSE stream of JSON-encoded OutputItem events.",
            "content": {
                "text/event-stream": {
                    "schema": {"type": "string"},
                    "example": 'data: {"type":"text","content":"Hello"}\\n\\n',
                }
            },
        }
    },
)
async def chat_stream(request: ChatRequest):
    logger.info(
        f"/chat from {request.user_name} (session={request.session_id}): "
        f"{request.message[:80]!r}"
    )
    context = _get_or_create_session(request.session_id, request.user_name)

    async def generate():
        try:
            async for output_json in tree_agent.stream_response(
                context, request.message
            ):
                yield f"data: {output_json}\n\n"
        except Exception as e:
            logger.error(f"/chat stream error: {e}", exc_info=True)
            error = ErrorOutput(message=str(e), code="STREAM_ERROR")
            yield f"data: {error.model_dump_json()}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.post(
    "/submit-tree",
    tags=["Tree"],
    summary="Submit trees and stream form",
    description=(
        "Persists the confirmed people/place trees and streams an intro TextChunk "
        "followed by a TextFormChunk via SSE."
    ),
    responses={
        200: {
            "description": "SSE stream containing TextChunk and TextFormChunk.",
            "content": {
                "text/event-stream": {
                    "schema": {"type": "string"},
                    "example": 'data: {"type":"text_form","address":{"label":"Address","content":""}}\\n\\n',
                }
            },
        }
    },
)
async def submit_tree(request: SubmitTreeRequest):
    logger.info(
        f"/submit-tree session={request.session_id} "
        f"people_nodes={len(request.people_tree)} "
        f"place_nodes={len(request.place_tree)}"
    )
    context = _get_or_create_session(request.session_id)
    context.save_trees(request.people_tree, request.place_tree)

    async def generate():
        try:
            async for output_json in form_agent.stream_form(
                context,
                request.people_tree,
                request.place_tree,
                context.form_data,
            ):
                yield f"data: {output_json}\n\n"
        except Exception as e:
            logger.error(f"/submit-tree stream error: {e}", exc_info=True)
            error = ErrorOutput(message=str(e), code="FORM_ERROR")
            yield f"data: {error.model_dump_json()}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.post(
    "/submit-form",
    tags=["Form"],
    summary="Submit form data and stream cart",
    description=(
        "Streams Server-Sent Events (SSE): TextChunk reasoning, ItemsChunk, "
        "tool/tool_result events, then final cart."
    ),
    responses={
        200: {
            "description": "SSE stream of JSON-encoded OutputItem events.",
            "content": {
                "text/event-stream": {
                    "schema": {"type": "string"},
                    "example": 'data: {"type":"cart","items":[]}\\n\\n',
                }
            },
        }
    },
)
async def submit_form(request: SubmitFormRequest):
    fields = [
        request.address,
        request.budget,
        request.date,
        request.duration,
        request.number_of_attendees,
    ]
    logger.info(
        f"/submit-form session={request.session_id} "
        f"fields={len(fields)}"
    )
    context = _get_or_create_session(request.session_id)
    context.save_form(fields)

    async def generate():
        try:
            items, price_ranges, quantities = await shopping_list_agent.generate_shopping_list(
                context=context,
                people_tree=context.people_tree,
                place_tree=context.place_tree,
                form_data=context.form_data,
            )

            async for output_json in shopping_list_agent.stream_reasoning(
                context=context,
                items=items,
                price_ranges=price_ranges,
                quantities=quantities,
                people_tree=context.people_tree,
                place_tree=context.place_tree,
                form_data=context.form_data,
            ):
                yield f"data: {output_json}\n\n"

            event_context = _build_event_context(
                context.form_data,
                context.people_tree,
                context.place_tree,
            )
            cart, tool_events, missing_items, retailer_offers = await shopping_agent.build_cart(
                items=items,
                price_ranges=price_ranges,
                quantities=quantities,
                form_data=context.form_data,
                event_context=event_context,
            )
            yield (
                "data: "
                + RetailerOffersChunk(offers=retailer_offers).model_dump_json(
                    by_alias=True
                )
                + "\n\n"
            )
            if retailer_offers:
                summary = await _summarize_sponsorships(
                    retailer_offers,
                    event_context,
                )
                if summary:
                    yield (
                        "data: "
                        + TextChunk(content=summary).model_dump_json()
                        + "\n\n"
                    )
            if missing_items:
                missing_text = (
                    "I couldn't find these items in the inventory: "
                    + ", ".join(missing_items)
                    + "."
                )
                yield f"data: {TextChunk(content=missing_text).model_dump_json()}\n\n"
            yield f"data: {cart.model_dump_json(by_alias=True)}\n\n"
        except Exception as e:
            logger.error(f"/submit-form stream error: {e}", exc_info=True)
            error = ErrorOutput(message=str(e), code="SHOPPING_ERROR")
            yield f"data: {error.model_dump_json()}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["Meta"],
    summary="Health check",
    description="Returns service health and active session count.",
)
async def health():
    return {"status": "healthy", "active_sessions": len(sessions)}


@app.post(
    "/start-voice",
    response_model=StartVoiceResponse,
    tags=["Voice"],
    summary="Start voice interaction",
    description="Initialize a voice session and return greeting prompt with TTS audio.",
)
async def start_voice(request: ChatRequest):
    logger.info(f"/start-voice from {request.user_name} (session={request.session_id})")
    context = _get_or_create_session(request.session_id, request.user_name)
    
    try:
        # Initialize voice state and get greeting
        state = voice_agent.init_voice_state()
        context.save_voice_state(state)
        
        response = await voice_agent.handle_greeting_phase(context, state)
        
        return {
            "session_id": request.session_id,
            "text": response["text"],
            "audio_id": response["audio_id"],
            "phase": response["phase"],
        }
    except Exception as e:
        logger.error(f"/start-voice error: {e}", exc_info=True)
        raise


@app.post(
    "/voice-input",
    response_model=VoiceInputResponse,
    tags=["Voice"],
    summary="Process voice input",
    description="Receives audio file, transcribes it, processes input, and returns next TTS prompt.",
)
async def voice_input(
    session_id: str = FastAPIForm(...),
    audio: UploadFile = File(...),
):
    logger.info(f"/voice-input session={session_id}, audio={audio.filename}")
    context = _get_or_create_session(session_id)
    
    try:
        # Read audio file
        audio_bytes = await audio.read()
        
        # Transcribe audio
        transcribed_text = await voice_agent.transcribe_audio(audio_bytes)
        logger.info(f"Transcribed: {transcribed_text}")
        
        # Process voice input
        response = await voice_agent.process_voice_input(context, transcribed_text)
        
        # Check if we should wait for input based on phase
        wait_for_input = response["phase"] not in ["done", "error"]
        
        return {
            "text": response["text"],
            "audio_id": response["audio_id"],
            "phase": response["phase"],
            "data": response.get("data", {}),
            "transcribed_text": transcribed_text,
            "wait_for_input": wait_for_input,
        }
    except Exception as e:
        logger.error(f"/voice-input error: {e}", exc_info=True)
        # Return error response
        error_response = await voice_agent.handle_error(str(e))
        return {
            "text": error_response["text"],
            "audio_id": error_response["audio_id"],
            "phase": "error",
            "data": {"error": str(e)},
            "transcribed_text": "",
            "wait_for_input": False,
        }


@app.get(
    "/tts-audio/{audio_id}",
    tags=["Voice"],
    summary="Get TTS audio file",
    description="Returns cached TTS audio file by ID.",
)
async def get_tts_audio(audio_id: str):
    logger.info(f"/tts-audio/{audio_id}")
    
    audio_bytes = voice_agent.get_cached_audio(audio_id)
    if not audio_bytes:
        logger.warning(f"Audio not found: {audio_id}")
        return Response(status_code=404, content="Audio not found")
    
    return Response(
        content=audio_bytes,
        media_type="audio/mpeg",
        headers={
            "Cache-Control": "public, max-age=3600",
            "Content-Disposition": f"inline; filename={audio_id}.mp3",
        },
    )


@app.post(
    "/recommendation-reason",
    tags=["Form"],
    summary="Explain why the recommended item was chosen",
    description=(
        "Returns a concise, user-friendly explanation for why the recommended "
        "item was selected over the alternatives."
    ),
    response_model=RecommendationReasonResponse,
)
async def recommendation_reason(request: RecommendationReasonRequest):
    cart_item = request.cart_item
    payload = cart_item.model_dump(by_alias=True)
    prompt = (
        "You are a helpful shopping assistant. Explain in 2-4 sentences why "
        "the recommended item was chosen over the cheapest, fastest delivery, "
        "and best rating options. Mention price, delivery time, and rating "
        "tradeoffs when relevant, and keep it factual.\n\n"
        f"Cart item data: {json.dumps(payload, ensure_ascii=False)}"
    )
    try:
        response = await shopping_list_agent.client.chat.completions.create(
            model=shopping_list_agent.model,
            messages=[
                {
                    "role": "system",
                    "content": "You explain recommendation decisions.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
        )
        reasoning = response.choices[0].message.content.strip()
    except Exception as e:
        logger.error(f"Recommendation summary failed: {e}", exc_info=True)
        reasoning = (
            "The recommended item balances price, delivery time, and overall "
            "quality better than the alternatives."
        )

    return RecommendationReasonResponse(reasoning=reasoning)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None)