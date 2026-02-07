/**
 * AI Agent Chat - Frontend
 * Handles structured streaming outputs from the backend
 */

// Configuration
const API_URL = 'http://localhost:8000';
const SESSION_ID = 'session-' + Date.now();

// DOM Elements
const chatContainer = document.getElementById('chatContainer');
const messageInput = document.getElementById('messageInput');
const sendButton = document.getElementById('sendButton');
const typingIndicator = document.getElementById('typingIndicator');
const statusElement = document.getElementById('status');
const documentsList = document.getElementById('documentsList');
const uploadProgress = document.getElementById('uploadProgress');
const fileInput = document.getElementById('fileInput');

// State
let isProcessing = false;
let currentAssistantMessageDiv = null;
let currentTextContent = null;
let activeTools = new Map(); // Track active tool calls

/**
 * Initialize the application
 */
function init() {
    checkStatus();
    setInterval(checkStatus, 30000); // Check every 30 seconds

    // Event listeners
    sendButton.addEventListener('click', sendMessage);
    console.log('Clicked');
    messageInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });
}

/**
 * Check server health and update status
 */
async function checkStatus() {
    try {
        const response = await fetch(`${API_URL}/health`);
        const data = await response.json();
        statusElement.textContent = `🟢 Connected (${data.documents_count} chunks)`;
        statusElement.style.color = '#d4edda';
        loadDocuments();
    } catch (error) {
        statusElement.textContent = '🔴 Disconnected';
        statusElement.style.color = '#f8d7da';
        console.error('Status check failed:', error);
    }
}

/**
 * Load documents from the server
 */
async function loadDocuments() {
    try {
        const response = await fetch(`${API_URL}/documents`);
        const data = await response.json();

        if (data.documents && data.documents.length > 0) {
            documentsList.innerHTML = data.documents.map(doc => `
                <div class="document-item">
                    <span class="document-name" title="${escapeHtml(doc.filename)}">${escapeHtml(doc.filename)}</span>
                    <span class="document-chunks">${doc.chunks} chunks</span>
                    <button class="delete-btn" onclick="deleteDocument('${escapeHtml(doc.filename)}')">×</button>
                </div>
            `).join('');
        } else {
            documentsList.innerHTML = '<p style="color: #999; font-size: 12px;">No documents yet</p>';
        }
    } catch (error) {
        console.error('Failed to load documents:', error);
    }
}

/**
 * Upload document
 */
function uploadDocument() {
    fileInput.click();
}

fileInput.addEventListener('change', async () => {
    const file = fileInput.files[0];
    if (!file) return;

    uploadProgress.textContent = `Uploading ${file.name}...`;

    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch(`${API_URL}/upload`, {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (result.success) {
            uploadProgress.textContent = `✓ Uploaded ${file.name} (${result.chunks_added} chunks)`;
            setTimeout(() => uploadProgress.textContent = '', 3000);
            loadDocuments();
            checkStatus();
        } else {
            uploadProgress.textContent = `✗ Failed to upload`;
        }
    } catch (error) {
        uploadProgress.textContent = `✗ Error: ${error.message}`;
        console.error('Upload failed:', error);
    }

    fileInput.value = '';
});

/**
 * Delete document
 */
async function deleteDocument(filename) {
    if (!confirm(`Delete ${filename}?`)) return;

    try {
        const response = await fetch(`${API_URL}/documents/${encodeURIComponent(filename)}`, {
            method: 'DELETE'
        });

        const result = await response.json();

        if (result.success) {
            loadDocuments();
            checkStatus();
        }
    } catch (error) {
        alert(`Failed to delete: ${error.message}`);
    }
}

/**
 * Send a message
 */
async function sendMessage() {
    const message = messageInput.value.trim();
    if (!message || isProcessing) return;

    isProcessing = true;
    sendButton.disabled = true;
    messageInput.value = '';

    addUserMessage(message);
    typingIndicator.classList.add('active');

    // Reset state for new message
    currentAssistantMessageDiv = null;
    currentTextContent = null;
    activeTools.clear();

    try {
        const response = await fetch(`${API_URL}/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                user_name: 'User',
                message: message,
                session_id: SESSION_ID,
                page_context: window.location.href
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
            const {done, value} = await reader.read();
            if (done) break;

            buffer += decoder.decode(value, {stream: true});
            const lines = buffer.split('\n');

            // Keep the last incomplete line in the buffer
            buffer = lines.pop() || '';

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const data = line.substring(6).trim();
                    if (!data) continue;

                    try {
                        const output = JSON.parse(data);
                        handleOutputItem(output);
                    } catch (e) {
                        console.warn('Failed to parse output:', data, e);
                    }
                }
            }
        }
    } catch (error) {
        console.error('Chat error:', error);
        ensureAssistantMessage();
        addErrorToMessage(`Connection error: ${error.message}`);
    } finally {
        typingIndicator.classList.remove('active');
        isProcessing = false;
        sendButton.disabled = false;
        messageInput.focus();
    }
}

/**
 * Handle different output types from the backend
 */
function handleOutputItem(output) {
    switch (output.type) {
        case 'tool':
            handleToolOutput(output);
            break;

        case 'tool_result':
            handleToolResultOutput(output);
            break;

        case 'text':
            handleTextChunk(output);
            break;

        case 'thinking':
            handleThinkingChunk(output);
            break;

        case 'answer':
            handleApiAnswerOutput(output);
            break;

        case 'error':
            handleErrorOutput(output);
            break;

        default:
            console.warn('Unknown output type:', output.type);
    }
}

/**
 * Handle tool invocation signal
 */
function handleToolOutput(output) {
    ensureAssistantMessage();

    const toolId = `tool-${output.name}-${Date.now()}`;
    const toolDiv = document.createElement('div');
    toolDiv.className = 'tool-indicator executing';
    toolDiv.id = toolId;
    toolDiv.innerHTML = `
        <span class="tool-spinner"></span>
        <span>🔧 Using tool: <strong>${escapeHtml(output.name)}</strong></span>
    `;

    if (output.reason) {
        toolDiv.innerHTML += `<span style="margin-left: 8px; opacity: 0.8;">(${escapeHtml(output.reason)})</span>`;
    }

    currentAssistantMessageDiv.querySelector('.message-content').appendChild(toolDiv);
    activeTools.set(output.name, toolId);
    scrollToBottom();
}

/**
 * Handle tool execution result
 */
function handleToolResultOutput(output) {
    const toolId = activeTools.get(output.name);

    if (toolId) {
        const toolDiv = document.getElementById(toolId);
        if (toolDiv) {
            toolDiv.className = 'tool-indicator completed';
            toolDiv.innerHTML = `
                <span>✓</span>
                <span>Tool completed: <strong>${escapeHtml(output.name)}</strong></span>
            `;

            if (!output.success) {
                toolDiv.style.background = '#f8d7da';
                toolDiv.style.borderLeftColor = '#dc3545';
                toolDiv.style.color = '#721c24';
                toolDiv.innerHTML = `
                    <span>✗</span>
                    <span>Tool failed: <strong>${escapeHtml(output.name)}</strong></span>
                `;
            }
        }
        activeTools.delete(output.name);
    }

    scrollToBottom();
}

/**
 * Handle streaming text chunk
 */
function handleTextChunk(output) {
    ensureAssistantMessage();
    ensureTextContent();

    currentTextContent.textContent += output.content;
    scrollToBottom();
}

/**
 * Handle thinking chunk (for models that support it)
 */
function handleThinkingChunk(output) {
    ensureAssistantMessage();

    const thinkingDiv = document.createElement('div');
    thinkingDiv.className = 'thinking';
    thinkingDiv.innerHTML = `💭 ${escapeHtml(output.content)}`;

    currentAssistantMessageDiv.querySelector('.message-content').appendChild(thinkingDiv);
    scrollToBottom();
}

/**
 * Handle final answer
 */
function handleApiAnswerOutput(output) {
    ensureAssistantMessage();

    // If we have text content, we're already displaying it
    // The answer output signals completion

    // Optionally add metadata display
    if (output.metadata && output.metadata.finish_reason) {
        console.log('Answer completed:', output.metadata.finish_reason);
    }

    scrollToBottom();
}

/**
 * Handle error output
 */
function handleErrorOutput(output) {
    ensureAssistantMessage();
    addErrorToMessage(`${output.message}${output.code ? ` (${output.code})` : ''}`);
}

/**
 * Add user message to chat
 */
function addUserMessage(text) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message user-message';
    messageDiv.innerHTML = `
        <div class="message-header">
            <span>You</span>
            <span>👤</span>
        </div>
        <div class="message-content">${escapeHtml(text)}</div>
    `;
    chatContainer.appendChild(messageDiv);
    scrollToBottom();
}

/**
 * Ensure assistant message exists
 */
function ensureAssistantMessage() {
    if (!currentAssistantMessageDiv) {
        currentAssistantMessageDiv = document.createElement('div');
        currentAssistantMessageDiv.className = 'message assistant-message';
        currentAssistantMessageDiv.innerHTML = `
            <div class="message-header">
                <span>🤖</span>
                <span>Assistant</span>
            </div>
            <div class="message-content"></div>
        `;
        chatContainer.appendChild(currentAssistantMessageDiv);
        scrollToBottom();
    }
}

/**
 * Ensure text content span exists
 */
function ensureTextContent() {
    if (!currentTextContent) {
        currentTextContent = document.createElement('span');
        currentAssistantMessageDiv.querySelector('.message-content').appendChild(currentTextContent);
    }
}

/**
 * Add error to current message
 */
function addErrorToMessage(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error';
    errorDiv.textContent = `⚠️ ${message}`;
    currentAssistantMessageDiv.querySelector('.message-content').appendChild(errorDiv);
    scrollToBottom();
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * Scroll chat to bottom
 */
function scrollToBottom() {
    chatContainer.scrollTop = chatContainer.scrollHeight;
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}