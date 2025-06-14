from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import json
import logging
import socket
from typing import Dict, Set
from datetime import datetime
from prometheus_fastapi_instrumentator import Instrumentator

logger = logging.getLogger("uvicorn")

app = FastAPI()

# Instrument FastAPI app for Prometheus metrics
Instrumentator().instrument(app).expose(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.rooms: Dict[str, Set[str]] = {
            "general": set(),
            "support": set(),
            "random": set()
        }
        self.user_rooms: Dict[str, str] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        self.active_connections[client_id] = websocket

    async def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
        if client_id in self.user_rooms:
            room = self.user_rooms[client_id]
            self.rooms[room].remove(client_id)
            del self.user_rooms[client_id]
            await self.broadcast_to_room(room, {
                "type": "user_left",
                "userId": client_id,
                "username": client_id
            })

    async def join_room(self, client_id: str, room: str):
        if client_id in self.user_rooms:
            old_room = self.user_rooms[client_id]
            self.rooms[old_room].remove(client_id)
        
        self.rooms[room].add(client_id)
        self.user_rooms[client_id] = room
        
        await self.broadcast_to_room(room, {
            "type": "user_joined",
            "userId": client_id,
            "username": client_id
        })
        
        return list(self.rooms[room])

    async def broadcast_to_room(self, room: str, message: dict):
        if room in self.rooms:
            for client_id in self.rooms[room]:
                if client_id in self.active_connections:
                    try:
                        await self.active_connections[client_id].send_json(message)
                    except Exception as e:
                        logger.error(f"Error broadcasting to {client_id}: {str(e)}")

manager = ConnectionManager()

@app.get("/")
async def root():
    hostname = socket.gethostname()
    return {"message": f"WebSocket server is running on {hostname}"}

@app.get("/health")
async def health_check():
    hostname = socket.gethostname()
    return {
        "status": "healthy",
        "hostname": hostname,
        "connections": len(manager.active_connections),
        "active_clients": list(manager.active_connections.keys())
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    try:
        await websocket.accept()
        client_id = str(id(websocket))
        await manager.connect(websocket, client_id)
        hostname = socket.gethostname()
        logger.info(f"New WebSocket connection established: {client_id} on {hostname}")
        
        # Send initial connection info
        await websocket.send_json({
            "type": "connection",
            "status": "connected",
            "client_id": client_id,
            "hostname": hostname
        })
        
        try:
            while True:
                data = await websocket.receive_text()
                logger.info(f"Received message from {client_id}: {data}")
                
                try:
                    # Try to parse as JSON first
                    message_data = json.loads(data)
                    
                    if message_data.get("type") == "join":
                        room = message_data.get("room", "general")
                        users = await manager.join_room(client_id, room)
                        await websocket.send_json({
                            "type": "room_users",
                            "users": list(users)
                        })
                    elif message_data.get("type") == "message":
                        room = manager.user_rooms.get(client_id, "general")
                        # Send echo response to sender
                        await websocket.send_json({
                            "type": "message",
                            "sender": "server",
                            "content": message_data.get("content", ""),
                            "timestamp": datetime.now().isoformat()
                        })
                        # Broadcast to room
                        await manager.broadcast_to_room(room, {
                            "type": "message",
                            "sender": client_id,
                            "content": message_data.get("content", ""),
                            "timestamp": datetime.now().isoformat()
                        })
                except json.JSONDecodeError:
                    # If not JSON, treat as plain text message
                    room = manager.user_rooms.get(client_id, "general")
                    # Send echo response to sender
                    await websocket.send_json({
                        "type": "message",
                        "sender": "server",
                        "content": data,
                        "timestamp": datetime.now().isoformat()
                    })
                    # Broadcast to room
                    await manager.broadcast_to_room(room, {
                        "type": "message",
                        "sender": client_id,
                        "content": data,
                        "timestamp": datetime.now().isoformat()
                    })
                
        except WebSocketDisconnect:
            logger.info(f"WebSocket disconnected: {client_id}")
            await manager.disconnect(client_id)
        except Exception as e:
            logger.error(f"Error in WebSocket connection {client_id}: {str(e)}")
            await websocket.close(code=1011, reason="Internal server error")
    except Exception as e:
        logger.error(f"Failed to establish WebSocket connection: {str(e)}")
        if websocket.client_state.CONNECTED:
            await websocket.close(code=1011, reason="Connection failed")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 