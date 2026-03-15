# Copyright (c) 2026 Omni Bridge. All rights reserved.

import asyncio
import os
import sys
import logging
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Internal imports
from src.utils.server_utils import kill_other_instances, detect_google_json, setup_logging
from src.network.ws_manager import ConnectionManager
from src.network.router import CommandRouter
from src.network.handlers import ServerContext, SessionHandler, ConfigHandler, DeviceHandler

# --- Setup Logging ---
def get_log_dir():
    is_frozen = getattr(sys, 'frozen', False)
    is_debug = os.environ.get("OMNI_BRIDGE_DEBUG") == "true"
    if not is_frozen or is_debug:
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
    appdata = os.environ.get("APPDATA", "")
    return os.path.join(appdata, "com.marshal", "Omni Bridge", "logs")

log_dir = get_log_dir()
os.makedirs(log_dir, exist_ok=True)
logger = setup_logging(os.path.join(log_dir, "server.log"))

# --- Global Components ---
manager = ConnectionManager()
ctx = ServerContext(manager)
router = CommandRouter()

# Initialize Handlers
session_h = SessionHandler(ctx)
config_h = ConfigHandler(ctx)
device_h = DeviceHandler(ctx)

# Register Commands
router.register("start", session_h.start)
router.register("stop", session_h.stop)
router.register("settings_update", config_h.update_settings)
router.register("volume_update", config_h.update_volume)
router.register("list_devices", device_h.list_devices)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Server starting up...")
    # Any boot-time logic (e.g. killing instances) happens in __main__
    yield
    logger.info("Server shutting down...")

app = FastAPI(lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.websocket("/captions")
async def captions_ws(websocket: WebSocket):
    await manager.connect(websocket)
    # Capabilities Handshake
    if ctx.orchestrator:
        caps = ctx.orchestrator.get_capabilities()
        await websocket.send_text(json.dumps({"type": "capabilities", "capabilities": caps}))
    
    try:
        while True:
            data = await websocket.receive_text()
            await router.handle(websocket, data)
    except WebSocketDisconnect:
        await manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket Error: {e}")
        await manager.disconnect(websocket)

if __name__ == "__main__":
    kill_other_instances()
    logger.info("Standardizing on port 8765")
    uvicorn.run(app, host="127.0.0.1", port=8765, log_level="info")

# Note: Old monolithic flutter_server.py logic has been refactored into:
# - src/network/router.py (Command Dispatch)
# - src/network/handlers.py (State & Logic)
# - src/utils/server_utils.py (Infrastructure helpers)
