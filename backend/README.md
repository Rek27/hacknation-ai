# 🤖 AI Agent Chat with RAG

FastAPI-based AI chat application with document upload, RAG search, and custom tools.

## 📋 Requirements

- **Python 3.9+** (uv will auto-install if missing)
- **OpenAI API Key** - Get one at [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

## 🚀 Installation

### 1. Install uv

**macOS/Linux:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell as Admin):**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Close and reopen your terminal after installation.

### 2. Setup & Run

```bash
# Navigate to project
cd hacknation-ai

# Copy example environment file
cp .env.example .env

# Edit .env and add your OpenAI API key
# (Open .env in any text editor and replace 'your-key-here')

# Setup environment and install everything
uv venv
uv pip install -e .

# Start the server
python -m app.main
```

### 3. Open the UI

**macOS:**
```bash
open index.html
```

**Windows:**
```bash
start index.html
```

**Linux:**
```bash
xdg-open index.html
```

That's it! Upload documents and start chatting.

## 💡 Usage

- **Upload documents:** Click "📤 Upload Document" (supports .txt and .pdf)
- **Ask questions:** "What does the document say about X?"
- **Use tools:** "What's the weather in Berlin?" or "Calculate 42 * 137"

## 🔧 Common Issues

**"uv: command not found"**  
→ Close and reopen your terminal

**Port 8000 already in use**  
→ Edit `index.html`, change `API_URL` to `http://localhost:8001`  
→ Run: `python -m app.main --port 8001`

**ChromaDB errors**  
→ Run: `uv pip install pysqlite3-binary`

**View logs**  
→ Check `logs/app.log` for errors

## 📂 Project Structure

```
hacknation-ai/
├── app/                    # Backend code
│   ├── main.py            # API server
│   ├── agent_manager.py   # AI logic
│   ├── rag_pipeline.py    # Document search
│   └── tools.py           # Custom tools
├── index.html          # Web interface
├── pyproject.toml        # Dependencies
├── .env.example          # Example environment file
├── .env                  # Your API key (create from .env.example)
└── chroma_db/            # Document storage (auto-created)
```

## 📝 Features

- ✅ Upload & search documents (PDF/TXT)
- ✅ RAG-powered AI responses
- ✅ Real-time streaming
- ✅ Tool usage visualization
- ✅ Conversation history
- ✅ Full logging

**Note:** First run takes ~2 minutes (downloads 80MB embedding model), then it's fast!

---