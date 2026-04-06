# Copyright (c) 2026 Omni Bridge. All rights reserved.

import logging
from typing import Dict, Any
from .base_handler import BaseHandler

class ConfigHandler(BaseHandler):
    async def update_settings(self, websocket, msg: Dict[str, Any]):
        new_source = msg.get("source", self.ctx.config["source_lang"])
        new_target = msg.get("target", self.ctx.config["target_lang"])
        new_engine = msg.get("ai_engine", self.ctx.config["ai_engine"])
        new_mic = msg.get("use_mic", self.ctx.config["use_mic"])
        new_key = msg.get("nvidia_nim_key", self.ctx.config["nvidia_nim_key"])
        new_trans = msg.get("transcription_model", self.ctx.config["transcription_model"])
        new_tl = msg.get("translation_model", self.ctx.config["translation_model"])
        new_google_creds = msg.get("google_credentials", self.ctx.config["google_credentials"])
        new_riva_tl_id = msg.get("riva_translation_function_id", self.ctx.config["riva_translation_function_id"]) or msg.get("rivaTranslationFunctionId") or ""
        new_riva_asr_p_id = msg.get("riva_asr_parakeet_function_id", self.ctx.config["riva_asr_parakeet_function_id"]) or msg.get("rivaAsrParakeetFunctionId") or ""
        new_riva_asr_c_id = msg.get("riva_asr_canary_function_id", self.ctx.config["riva_asr_canary_function_id"]) or msg.get("rivaAsrCanaryFunctionId") or ""
 
        # Whether model-level settings changed (requires full pipeline restart + model reinit)
        has_model_changed = (
            msg.get("model_changed", True) and (  # Flutter sends False when only lang/device changed
                self.ctx.config["nvidia_nim_key"] != new_key or
                self.ctx.config["transcription_model"] != new_trans or
                self.ctx.config["translation_model"] != new_tl or
                self.ctx.config["google_credentials"] != new_google_creds or
                self.ctx.config["riva_translation_function_id"] != new_riva_tl_id or
                self.ctx.config["riva_asr_parakeet_function_id"] != new_riva_asr_p_id or
                self.ctx.config["riva_asr_canary_function_id"] != new_riva_asr_c_id
            )
        )

        # Whether any config changed at all (lang, mic, device, model, etc.)
        has_changed = (
            has_model_changed or
            self.ctx.config["source_lang"] != new_source or
            self.ctx.config["target_lang"] != new_target or
            self.ctx.config["ai_engine"] != new_engine or
            self.ctx.config["use_mic"] != new_mic
        )

        self.ctx.config.update({
            "source_lang": new_source,
            "target_lang": new_target,
            "ai_engine": new_engine,
            "use_mic": new_mic,
            "nvidia_nim_key": new_key,
            "transcription_model": new_trans,
            "translation_model": new_tl,
            "google_credentials": new_google_creds,
            "riva_translation_function_id": new_riva_tl_id,
            "riva_asr_parakeet_function_id": new_riva_asr_p_id,
            "riva_asr_canary_function_id": new_riva_asr_c_id,
        })

        if self.ctx.is_running and has_changed:
            if has_model_changed:
                logging.info("[Handler] Model settings changed while running. Full restart...")
            else:
                logging.info("[Handler] Config-only change (lang/device). Light restart, skipping model reinit...")
            from .session_handler import SessionHandler
            await SessionHandler(self.ctx).start(websocket, self.ctx.config, reload_models=has_model_changed)
        elif not self.ctx.is_running:
            if self.ctx.orchestrator:
                self.ctx.orchestrator.set_api_keys(
                    new_key, 
                    self.ctx.config["google_credentials"],
                    riva_translation_id=new_riva_tl_id,
                    riva_asr_parakeet_id=new_riva_asr_p_id,
                    riva_asr_canary_id=new_riva_asr_c_id
                )
                await self.ctx.manager.broadcast_status(self.ctx.orchestrator)

    async def update_volume(self, websocket, msg: Dict[str, Any]):
        self.ctx.config["desktop_volume"] = float(msg.get("desktop_volume", self.ctx.config["desktop_volume"]) or 0.0)
        self.ctx.config["mic_volume"] = float(msg.get("mic_volume", self.ctx.config["mic_volume"]) or 0.0)
        if self.ctx.audio_capture:
            self.ctx.audio_capture.desktop_volume = max(0.0, self.ctx.config["desktop_volume"])
            self.ctx.audio_capture.mic_volume = max(0.0, self.ctx.config["mic_volume"])
