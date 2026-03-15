# Copyright (c) 2026 Omni Bridge. All rights reserved.

import json
import logging
from typing import Dict, Any, Callable, Awaitable

class CommandRouter:
    """
    Routes incoming WebSocket messages to registered handlers.
    """
    def __init__(self):
        self.handlers: Dict[str, Callable[[Any, Dict[str, Any]], Awaitable[None]]] = {}

    def register(self, cmd: str, handler: Callable[[Any, Dict[str, Any]], Awaitable[None]]):
        """Register a handler function for a specific command."""
        self.handlers[cmd] = handler

    async def handle(self, websocket, data: str):
        """Parse and route the message."""
        try:
            msg = json.loads(data)
            cmd = msg.get("cmd")
            
            if not cmd:
                logging.warning(f"[Router] Received message without 'cmd': {msg}")
                return

            if cmd in self.handlers:
                await self.handlers[cmd](websocket, msg)
            else:
                logging.warning(f"[Router] No handler registered for command: {cmd}")
        except json.JSONDecodeError:
            logging.error(f"[Router] Failed to decode JSON message: {data}")
        except Exception as e:
            logging.error(f"[Router] Error handling command: {e}", exc_info=True)
