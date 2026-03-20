# Copyright (c) 2026 Omni Bridge. All rights reserved.

import logging
from typing import Dict, Any
from .base_handler import BaseHandler

class DeviceHandler(BaseHandler):
    async def get_device_list(self):
        """Returns the list of input and output devices."""
        import pyaudiowpatch as pyaudio
        inputs, outputs = [], []
        async with self.ctx.pyaudio_lock:
            try:
                from src.audio.shared_pyaudio import get_pyaudio
                p = get_pyaudio()
                wasapi_index = -1
                for i in range(p.get_host_api_count()):
                    if p.get_host_api_info_by_index(i).get("type") == pyaudio.paWASAPI:
                        wasapi_index = i
                        break

                if wasapi_index == -1:
                    return {"error": "WASAPI not found"}

                for i in range(p.get_device_count()):
                    info = p.get_device_info_by_index(i)
                    name = info.get("name", "")
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name: continue
                    if info.get("hostApi") == wasapi_index and info.get("maxInputChannels", 0) > 0 and not info.get("isLoopbackDevice", False):
                        inputs.append({"index": i, "name": name})
                
                for loopback in p.get_loopback_device_info_generator():
                    name = loopback.get("name", "")
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name: continue
                    outputs.append({"index": loopback["index"], "name": name.replace(" [Loopback]", "").strip()})

                return {
                    "input": inputs,
                    "output": outputs
                }
            except Exception as e:
                logging.error(f"[Handler] Device listing error: {e}")
                return {"error": str(e)}

    async def list_devices(self, websocket, msg: Dict[str, Any]):
        devices = await self.get_device_list()
        import json
        response = {"type": "devices"}
        if isinstance(devices, dict):
            response.update(devices)
        await websocket.send_text(json.dumps(response))
