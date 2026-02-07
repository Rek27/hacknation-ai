from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import os
import time
from dotenv import load_dotenv

from app.models import TreeNode, TextFieldChunk, ErrorOutput
from app.models.context import Context
from app.tree_agent import TreeAgent
from app.form_agent import FormAgent
from app.logger import setup_logging, get_logger

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
app = FastAPI(title="Event Shopping Agent API", version="2.0.0")

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

# In-memory session store (swap for DB in production)
sessions: dict[str, Context] = {}


def _get_or_create_session(session_id: str, user_name: str = "User") -> Context:
    if session_id not in sessions:
        logger.info(f"New session: {session_id}")
        sessions[session_id] = Context(user_name=user_name)
    return sessions[session_id]


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


# ── Endpoints ──────────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {
        "service": "Event Shopping Agent API",
        "version": "2.0.0",
        "endpoints": ["/chat", "/submit-tree", "/submit-form", "/health", "/test"],
    }


@app.get("/test")
async def test_page():
    """Serve the test UI."""
    html_path = os.path.join(os.path.dirname(__file__), "test.html")
    with open(html_path, "r", encoding="utf-8") as f:
        return HTMLResponse(f.read())


@app.post("/chat")
async def chat_stream(request: ChatRequest):
    """TreeAgent streaming endpoint (SSE).

    Returns TextChunk | PeopleTreeTrunk | PlaceTreeTrunk | ErrorOutput.
    """
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


@app.post("/submit-tree")
async def submit_tree(request: SubmitTreeRequest):
    """Persist confirmed trees and stream a form via FormAgent (SSE).

    Returns TextChunk (intro) + TextFormChunk.
    """
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


@app.post("/submit-form")
async def submit_form(request: SubmitFormRequest):
    """Persist confirmed form data. Stub for future BuyerAgent."""
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

    items_summary = [
        f"{f.label}: {f.content}" for f in fields if f.content
    ]

    return {
        "success": True,
        "message": "Form submitted. BuyerAgent will process your request.",
        "session_id": request.session_id,
        "items_summary": items_summary,
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "active_sessions": len(sessions)}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None)