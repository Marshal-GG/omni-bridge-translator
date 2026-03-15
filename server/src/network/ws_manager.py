import json
from typing import Set
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.add(websocket)

    async def disconnect(self, websocket: WebSocket):
        self.active_connections.discard(websocket)

    async def broadcast(self, message: dict):
        """Send a JSON message to all connected Flutter clients."""
        if not self.active_connections:
            return
        dead = set()
        for ws in list(self.active_connections):
            try:
                await ws.send_text(json.dumps(message))
            except Exception:
                dead.add(ws)
        self.active_connections.difference_update(dead)

    async def broadcast_status(self, orchestrator):
        """Broadcast the current status of all models to all connected clients."""
        if orchestrator:
            status_data = orchestrator.get_all_statuses()
            message = {
                "type": "model_status",
                "models": status_data
            }
            await self.broadcast(message)
