from fastapi import FastAPI, HTTPException, Request, UploadFile, File
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import os
import time
from dotenv import load_dotenv
from app.models.context import Context
from app.agent_manager import AgentManager
from app.rag_pipeline import RAGPipeline
from app.tools import tools
from app.logger import setup_logging, get_logger

load_dotenv()

# Setup logging
setup_logging(
    log_level=os.getenv("LOG_LEVEL", "INFO"),
    log_to_file=True,
    log_to_console=True,
    json_logs=os.getenv("JSON_LOGS", "false").lower() == "true"
)

logger = get_logger(__name__)

app = FastAPI(title="Agent MVP API", version="1.0.0")

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
        f"Incoming request: {request.method} {request.url.path}",
        extra={
            "method": request.method,
            "path": request.url.path,
            "client": request.client.host if request.client else "unknown"
        }
    )

    response = await call_next(request)

    duration = (time.time() - start_time) * 1000

    logger.info(
        f"Request completed: {request.method} {request.url.path} - {response.status_code}",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration": round(duration, 2)
        }
    )

    return response


# Initialize RAG pipeline and connect to tools
logger.info("Initializing RAG pipeline...")
rag_pipeline = RAGPipeline()
tools.set_rag_pipeline(rag_pipeline)
logger.info("RAG pipeline initialized successfully")

# Initialize agent manager
logger.info("Initializing agent manager...")
agent_manager = AgentManager(api_key=os.getenv("OPENAI_API_KEY"))
logger.info("Agent manager initialized successfully")

contexts = {}


class ChatRequest(BaseModel):
    user_name: str
    message: str
    session_id: str
    page_context: Optional[str] = None


class IngestRequest(BaseModel):
    filepath: str


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("Starting application...")

    if os.path.exists("documents"):
        try:
            logger.info("Ingesting documents from 'documents' directory...")
            count = rag_pipeline.ingest_directory("documents")
            logger.info(f"Successfully ingested {count} chunks from documents directory")
        except Exception as e:
            logger.error(f"Failed to ingest documents: {e}", exc_info=True)
    else:
        logger.warning("Documents directory not found, skipping auto-ingestion")

    logger.info("Application started successfully")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down application...")
    logger.info(f"Active sessions: {len(contexts)}")


@app.get("/")
async def root():
    logger.debug("Root endpoint accessed")
    doc_count = rag_pipeline.collection.count()
    return {
        "message": "Agent MVP API",
        "version": "1.0.0",
        "tools": tools.get_tool_names(),
        "rag_status": "initialized" if tools.rag_pipeline else "not initialized",
        "documents_count": doc_count
    }


@app.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    """Upload a document to the RAG pipeline"""
    logger.info(f"Receiving file upload: {file.filename}")

    # Validate file type
    allowed_extensions = ['.txt', '.pdf']
    file_ext = os.path.splitext(file.filename)[1].lower()

    if file_ext not in allowed_extensions:
        logger.warning(f"Unsupported file type: {file_ext}")
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported file type. Allowed: {', '.join(allowed_extensions)}"
        )

    try:
        # Read file content
        content = await file.read()
        logger.info(f"File read: {len(content)} bytes")

        # Ingest the document
        chunks_added = rag_pipeline.ingest_from_bytes(
            content, 
            file.filename,
            metadata={"uploaded": True}
        )

        total_chunks = rag_pipeline.collection.count()

        return {
            "success": True,
            "filename": file.filename,
            "chunks_added": chunks_added,
            "total_chunks": total_chunks
        }
    except Exception as e:
        logger.error(f"Failed to upload document: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/documents")
async def list_documents():
    """List all documents in the RAG pipeline"""
    logger.info("Listing documents")

    try:
        documents = rag_pipeline.list_documents()
        total_chunks = rag_pipeline.collection.count()

        return {
            "success": True,
            "documents": documents,
            "total_chunks": total_chunks
        }
    except Exception as e:
        logger.error(f"Failed to list documents: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/documents/{filename}")
async def delete_document(filename: str):
    """Delete a document from the RAG pipeline"""
    logger.info(f"Deleting document: {filename}")

    try:
        chunks_deleted = rag_pipeline.delete_document(filename)

        if chunks_deleted == 0:
            raise HTTPException(status_code=404, detail="Document not found")

        return {
            "success": True,
            "filename": filename,
            "chunks_deleted": chunks_deleted
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete document: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat")
async def chat_stream(request: ChatRequest):
    """
    Streaming endpoint with structured outputs.

    Returns Server-Sent Events with JSON objects:
    - ToolOutput: Tool invocation signal
    - ToolResultOutput: Tool execution result
    - TextChunk: Streaming text from model
    - ApiAnswerOutput: Final complete answer
    - ErrorOutput: Error information
    """
    logger.info(
        f"Chat request from user: {request.user_name}",
        extra={
            "session_id": request.session_id,
            "user_name": request.user_name,
            "message_length": len(request.message)
        }
    )

    if request.session_id not in contexts:
        logger.info(f"Creating new context for session: {request.session_id}")
        contexts[request.session_id] = Context(user_name=request.user_name)

    context = contexts[request.session_id]

    if request.page_context:
        context.update_page_context(request.page_context)
        logger.debug(f"Updated page context: {request.page_context}")

    async def generate():
        try:
            async for output_json in agent_manager.stream_response(context, request.message):
                # Each output_json is already a JSON string of an OutputItem
                yield f"data: {output_json}\n\n"
        except Exception as e:
            logger.error(
                f"Error during chat streaming: {e}",
                exc_info=True,
                extra={"session_id": request.session_id}
            )
            from app.models import ErrorOutput
            error = ErrorOutput(message=str(e), code="STREAM_ERROR")
            yield f"data: {error.model_dump_json()}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )


@app.post("/rag-search")
async def rag_search(query: str, n_results: int = 3):
    """Search RAG pipeline for relevant chunks"""
    logger.info(f"RAG search query: '{query}' (n_results={n_results})")

    try:
        results = rag_pipeline.search(query, n_results)

        logger.info(f"RAG search returned {len(results)} results")
        logger.debug(f"Search results: {results}")

        return {
            "success": True,
            "query": query,
            "results": results
        }
    except Exception as e:
        logger.error(f"RAG search failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health():
    doc_count = rag_pipeline.collection.count() if rag_pipeline else 0
    return {
        "status": "healthy",
        "rag_pipeline": "initialized" if rag_pipeline else "not initialized",
        "tools_available": len(tools.get_tool_names()),
        "documents_count": doc_count
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None)