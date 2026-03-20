import json
import logging
from typing import Set, Any
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
        active_count = len(self.active_connections)
        

        if not self.active_connections:
            return

        # Sanitize message to ensure it's JSON serializable (handles gRPC objects, numpy, etc.)
        try:
            json_str = json.dumps(message, default=self._json_default)
        except Exception as e:
            logging.error(f"[WS] Serialization failed: {e}")
            # Fallback: convert everything to string to at least send something
            try:
                json_str = json.dumps(message, default=str)
            except:
                return

        dead = set()
        for ws in list(self.active_connections):
            try:
                await ws.send_text(json_str)
            except Exception as e:
                # Only print error if it's not a normal disconnection
                if "1001" not in str(e) and "1006" not in str(e):
                    logging.warning(f"[WS] Error sending to client: {e}")
                dead.add(ws)
        self.active_connections.difference_update(dead)

    def _json_default(self, obj: Any) -> Any:
        """Handle non-standard types like gRPC RepeatedScalarContainer or numpy arrays."""
        if hasattr(obj, "tolist"): # numpy
            return obj.tolist()
        if hasattr(obj, "__iter__") and not isinstance(obj, (str, dict)):
            return list(obj)
        try:
            return str(obj)
        except:
            return f"<unserializable {type(obj).__name__}>"

    async def broadcast_status(self, orchestrator):
        """Broadcast the current status of all models to all connected clients."""
        if orchestrator:
            status_data = orchestrator.get_all_statuses()
            message = {
                "type": "model_status",
                "models": status_data
            }
            await self.broadcast(message)
