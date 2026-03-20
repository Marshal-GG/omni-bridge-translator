# Copyright (c) 2026 Omni Bridge. All rights reserved.

import logging
from typing import Dict, Any
from src.network.base_handler import BaseHandler

class ConfigHandler(BaseHandler):
    async def update_settings(self, websocket, msg: Dict[str, Any]):
        new_source = msg.get("source", self.ctx.config["source_lang"])
        new_target = msg.get("target", self.ctx.config["target_lang"])
        new_engine = msg.get("ai_engine", self.ctx.config["ai_engine"])
        new_mic = msg.get("use_mic", self.ctx.config["use_mic"])
        new_key = msg.get("api_key", self.ctx.config["api_key"])
        new_trans = msg.get("transcription_model", self.ctx.config["transcription_model"])
        new_tl = msg.get("translation_model", self.ctx.config["translation_model"])
        new_google_creds = msg.get("google_credentials_json", self.ctx.config["google_credentials_json"])

        has_changed = (
            self.ctx.config["source_lang"] != new_source or
            self.ctx.config["target_lang"] != new_target or
            self.ctx.config["ai_engine"] != new_engine or
            self.ctx.config["use_mic"] != new_mic or
            self.ctx.config["api_key"] != new_key or
            self.ctx.config["transcription_model"] != new_trans or
            self.ctx.config["translation_model"] != new_tl or
            self.ctx.config["google_credentials_json"] != new_google_creds
        )

        self.ctx.config.update({
            "source_lang": new_source,
            "target_lang": new_target,
            "ai_engine": new_engine,
            "use_mic": new_mic,
            "api_key": new_key,
            "transcription_model": new_trans,
            "translation_model": new_tl,
            "google_credentials_json": new_google_creds,
        })

        if self.ctx.is_running and has_changed:
            logging.info("[Handler] Settings changed while running. Restarting...")
            from src.network.session_handler import SessionHandler
            await SessionHandler(self.ctx).start(websocket, self.ctx.config)
        elif not self.ctx.is_running:
            if self.ctx.orchestrator:
                self.ctx.orchestrator.set_api_keys(new_key, self.ctx.config["google_credentials_json"])
                await self.ctx.manager.broadcast_status(self.ctx.orchestrator)

    async def update_volume(self, websocket, msg: Dict[str, Any]):
        self.ctx.config["desktop_volume"] = float(msg.get("desktop_volume", self.ctx.config["desktop_volume"]) or 0.0)
        self.ctx.config["mic_volume"] = float(msg.get("mic_volume", self.ctx.config["mic_volume"]) or 0.0)
        if self.ctx.audio_capture:
            self.ctx.audio_capture.desktop_volume = max(0.0, self.ctx.config["desktop_volume"])
            self.ctx.audio_capture.mic_volume = max(0.0, self.ctx.config["mic_volume"])
