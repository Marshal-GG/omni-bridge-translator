# Copyright (c) 2026 Omni Bridge. All rights reserved.

from typing import Dict, Any
from .base_handler import BaseHandler
from src.pipeline import InferenceOrchestrator

class StatusHandler(BaseHandler):
    async def get_system_status(self):
        """Basic health check and session info."""
        return {
            "status": "online",
            "session_id": self.ctx.session_id,
            "is_running": self.ctx.is_running,
            "active_clients": len(self.ctx.manager.active_connections)
        }

    async def get_model_status(self):
        """Physical model health and capabilities."""
        if not self.ctx.orchestrator:
            self.ctx.orchestrator = InferenceOrchestrator(
                nvidia_api_key=self.ctx.config["api_key"],
                google_credentials_json=self.ctx.config["google_credentials_json"]
            )
        
        return {
            "type": "models_status",
            "models": self.ctx.orchestrator.get_all_statuses()
        }

    async def whisper_unload(self):
        """Unload Whisper model from memory."""
        if self.ctx.orchestrator:
            self.ctx.orchestrator.whisper_unload()
            return {"status": "unloaded"}
        return {"status": "no_orchestrator"}

    async def reset_session(self, websocket, data):
        """Resets the server context and informs all clients."""
        self.ctx.reset()
        # Broadcast a reset message if needed, or just let clients know via status
        if self.ctx.manager:
            await self.ctx.manager.broadcast({
                "type": "server_reset",
                "message": "Server state has been reset due to session change."
            })
        return {"type": "reset_success"}
