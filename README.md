# HackNation AI - Chat Agent API

A FastAPI-based chat agent API with support for both streaming and non-streaming responses.

## Features

- **Non-streaming chat endpoint**: Get complete responses in a single request
- **Streaming chat endpoint**: Receive responses in real-time chunks using Server-Sent Events (SSE)
- **Simple and extensible**: Easy to integrate with any LLM or chat agent backend
- **Type-safe**: Built with Pydantic models for request/response validation
- **Auto-documented**: Interactive API documentation via FastAPI's built-in Swagger UI

## Installation

1. Install dependencies:

```bash
pip install -r requirements.txt
```

Or using the pyproject.toml:

```bash
pip install -e .
```

## Running the Server

Start the server with:

```bash
python main.py
```

Or using uvicorn directly:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

## API Documentation

Once the server is running, you can access:

- **Interactive API docs (Swagger UI)**: http://localhost:8000/docs
- **Alternative API docs (ReDoc)**: http://localhost:8000/redoc
- **OpenAPI schema**: http://localhost:8000/openapi.json

## API Endpoints

### 1. Non-streaming Chat: `POST /chat`

Get a complete chat response in a single request.

**Request:**
```json
{
  "messages": [
    {"role": "user", "content": "Hello, how are you?"}
  ],
  "agent_id": "default",
  "max_tokens": 1000,
  "temperature": 0.7
}
```

**Response:**
```json
{
  "message": {
    "role": "assistant",
    "content": "I'm doing well, thank you for asking!"
  },
  "agent_id": "default",
  "timestamp": "2024-01-01T12:00:00.000000",
  "tokens_used": 8
}
```

### 2. Streaming Chat: `POST /chat/stream`

Get a streaming chat response using Server-Sent Events (SSE).

**Request:** (same as non-streaming)
```json
{
  "messages": [
    {"role": "user", "content": "Tell me a story"}
  ],
  "agent_id": "storyteller",
  "max_tokens": 1000,
  "temperature": 0.7
}
```

**Response:** (Server-Sent Events stream)
```
data: {"content": "Once ", "done": false, "agent_id": "storyteller", "timestamp": "..."}

data: {"content": "upon ", "done": false, "agent_id": "storyteller", "timestamp": "..."}

data: {"content": "a time", "done": false, "agent_id": "storyteller", "timestamp": "..."}

data: {"content": "", "done": true, "agent_id": "storyteller", "timestamp": "..."}
```

### 3. Health Check: `GET /health`

Check if the API is running.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00.000000"
}
```

## Example Usage

### Using Python requests library:

```python
import requests
import json

# Non-streaming
response = requests.post(
    "http://localhost:8000/chat",
    json={
        "messages": [{"role": "user", "content": "Hello!"}],
        "agent_id": "default"
    }
)
print(response.json())

# Streaming
response = requests.post(
    "http://localhost:8000/chat/stream",
    json={
        "messages": [{"role": "user", "content": "Hello!"}],
        "agent_id": "default"
    },
    stream=True
)

for line in response.iter_lines():
    if line:
        line_str = line.decode('utf-8')
        if line_str.startswith("data: "):
            chunk = json.loads(line_str[6:])
            if not chunk['done']:
                print(chunk['content'], end='', flush=True)
```

### Using curl:

**Non-streaming:**
```bash
curl -X POST "http://localhost:8000/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "agent_id": "default"
  }'
```

**Streaming:**
```bash
curl -X POST "http://localhost:8000/chat/stream" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "agent_id": "default"
  }'
```

### Using the example script:

Run the provided example script to test both endpoints:

```bash
python example_usage.py
```

## Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| messages | List[ChatMessage] | Yes | - | List of conversation messages |
| agent_id | string | No | "default" | ID of the agent to use |
| max_tokens | integer | No | 1000 | Maximum tokens to generate |
| temperature | float | No | 0.7 | Temperature for response generation (0.0-1.0) |

## ChatMessage Schema

| Field | Type | Description |
|-------|------|-------------|
| role | string | Role of message sender (user, assistant, system) |
| content | string | Content of the message |

## Extending the Agent Logic

The current implementation uses simple placeholder logic. To integrate with a real LLM or chat service:

1. Update the `generate_chat_response()` function in `main.py`
2. Update the `generate_chat_response_stream()` function for streaming responses
3. Add any necessary API keys or configuration as environment variables

Example integration points:
- OpenAI GPT
- Anthropic Claude
- Local LLM models (Ollama, LLaMA, etc.)
- Custom chat agents

## Development

The code is structured for easy extension:

- `main.py`: Main application with endpoints and agent logic
- `example_usage.py`: Example client code
- `requirements.txt`: Python dependencies
- `pyproject.toml`: Project metadata

## License

[Add your license information here]