from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
import uvicorn
import json
import logging
import traceback

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store active connections
active_connections: dict[str, WebSocket] = {}

# HTML template for testing
html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>WebSocket Test</title>
    <style>
        #messages {
            height: 200px;
            overflow-y: scroll;
            border: 1px solid #ccc;
            padding: 10px;
            margin-bottom: 10px;
            font-family: monospace;
        }
        .error { color: red; }
        .success { color: green; }
        .info { color: blue; }
        #status {
            padding: 5px;
            margin-bottom: 10px;
            font-weight: bold;
        }
        .connected { background-color: #dff0d8; }
        .disconnected { background-color: #f2dede; }
    </style>
</head>
<body>
    <h2>WebSocket Test</h2>
    <div id="status" class="disconnected">Disconnected</div>
    <div id="messages"></div>
    <input type="text" id="messageInput" placeholder="Type a message...">
    <button onclick="sendMessage()">Send</button>

    <script>
        const messagesDiv = document.getElementById('messages');
        const messageInput = document.getElementById('messageInput');
        const statusDiv = document.getElementById('status');
        let ws = null;
        let reconnectAttempts = 0;
        const maxReconnectAttempts = 5;
        const reconnectDelay = 3000; // 3 seconds

        function connect() {
            try {
                ws = new WebSocket('ws://localhost:8000/ws');
                
                ws.onopen = () => {
                    appendMessage('Connected to WebSocket server', 'success');
                    statusDiv.textContent = 'Connected';
                    statusDiv.className = 'connected';
                    reconnectAttempts = 0;
                };

                ws.onmessage = (event) => {
                    try {
                        const data = JSON.parse(event.data);
                        if (data.type === 'error') {
                            appendMessage(`Error: ${data.message}`, 'error');
                        } else {
                            appendMessage(`Received: ${JSON.stringify(data)}`, 'info');
                        }
                    } catch (e) {
                        appendMessage(`Received: ${event.data}`, 'info');
                    }
                };

                ws.onclose = () => {
                    appendMessage('Disconnected from WebSocket server', 'error');
                    statusDiv.textContent = 'Disconnected';
                    statusDiv.className = 'disconnected';
                    
                    if (reconnectAttempts < maxReconnectAttempts) {
                        reconnectAttempts++;
                        appendMessage(`Attempting to reconnect (${reconnectAttempts}/${maxReconnectAttempts})...`, 'info');
                        setTimeout(connect, reconnectDelay);
                    } else {
                        appendMessage('Max reconnection attempts reached. Please refresh the page.', 'error');
                    }
                };

                ws.onerror = (error) => {
                    appendMessage(`Error: ${error.message || 'Unknown error'}`, 'error');
                };
            } catch (error) {
                appendMessage(`Connection error: ${error.message}`, 'error');
            }
        }

        function sendMessage() {
            const message = messageInput.value;
            if (message && ws && ws.readyState === WebSocket.OPEN) {
                ws.send(message);
                appendMessage(`Sent: ${message}`, 'info');
                messageInput.value = '';
            } else if (!ws || ws.readyState !== WebSocket.OPEN) {
                appendMessage('Cannot send message: WebSocket is not connected', 'error');
            }
        }

        function appendMessage(message, type = 'info') {
            const messageElement = document.createElement('div');
            messageElement.textContent = message;
            messageElement.className = type;
            messagesDiv.appendChild(messageElement);
            messagesDiv.scrollTop = messagesDiv.scrollHeight;
        }

        // Allow sending message with Enter key
        messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });

        // Initial connection
        connect();
    </script>
</body>
</html>
"""

@app.get("/", response_class=HTMLResponse)
async def root():
    return html_content

# @app.get("/")
# async def root():
#     return {"message": "WebSocket server is running"}



@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    try:
        await websocket.accept()
        client_id = str(id(websocket))
        active_connections[client_id] = websocket
        logger.info(f"Client {client_id} connected. Total connections: {len(active_connections)}")
        
        # Send initial connection success message
        await websocket.send_json({
            "type": "connection",
            "status": "connected",
            "client_id": client_id
        })
        
        while True:
            try:
                # Receive message from client
                data = await websocket.receive_text()
                logger.info(f"Received message from {client_id}: {data}")
                
                # Echo the message back to the client
                response = {
                    "type": "echo",
                    "message": data,
                    "client_id": client_id
                }
                await websocket.send_json(response)
                
            except WebSocketDisconnect:
                raise
            except Exception as e:
                logger.error(f"Error processing message: {str(e)}")
                await websocket.send_json({
                    "type": "error",
                    "message": "Error processing message",
                    "error": str(e)
                })
                
    except WebSocketDisconnect:
        if client_id in active_connections:
            del active_connections[client_id]
        logger.info(f"Client {client_id} disconnected. Total connections: {len(active_connections)}")
    except Exception as e:
        logger.error(f"Error handling WebSocket connection: {str(e)}")
        logger.error(traceback.format_exc())
        if client_id in active_connections:
            del active_connections[client_id]

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "connections": len(active_connections),
        "active_clients": list(active_connections.keys())
    }

if __name__ == "__main__":
    try:
        logger.info("Starting WebSocket server...")
        uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
    except Exception as e:
        logger.error(f"Failed to start server: {str(e)}")
        logger.error(traceback.format_exc()) 