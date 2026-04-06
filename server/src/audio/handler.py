import asyncio
import json
import logging
import threading
import time
from typing import Any, Callable, Dict, TYPE_CHECKING

if TYPE_CHECKING:
    from .capture import AudioCapture
    from src.pipeline import InferenceOrchestrator
    from src.network.ws_manager import ConnectionManager
    from .meter import AudioMeter

def caption_callback(text, is_error, is_final=True, original_text=None, usage_stats=None, 
                    event_loop=None, manager=None, session_id=0, source_lang="auto", target_lang="en"):
    """Called by the orchestrator on each transcript/translation. Broadcasts to all clients.
    This runs in a background sync thread, so we schedule onto uvicorn's event loop."""
    msg = {
        "type": "error" if is_error else "caption",
        "text": text,
        "original": original_text or "",
        "is_final": is_final,
        "session_id": session_id,
    }
    stats_list = (usage_stats if isinstance(usage_stats, list) else [usage_stats]) if usage_stats else []
    asr_stat   = stats_list[0] if len(stats_list) > 0 else None
    trans_stat = stats_list[1] if len(stats_list) > 1 else None

    def _engine_name(s): return s.get("engine") or s.get("model") or "?"
    asr_src = original_text or text
    logging.info(f"[ASR]   '{asr_src[:70]}' | {_engine_name(asr_stat)} | {asr_stat.get('latency_ms', '?')}ms" if asr_stat else f"[ASR]   '{asr_src[:70]}'")
    if trans_stat:
        logging.info(f"[Trans] '{text[:70]}' | {_engine_name(trans_stat)} | {trans_stat.get('latency_ms', '?')}ms")
    if event_loop and not event_loop.is_closed() and manager:
        asyncio.run_coroutine_threadsafe(manager.broadcast(msg), event_loop)
        # Emit usage stats as a separate message so Flutter can log them independently
        if usage_stats and not is_error and is_final:
            if isinstance(usage_stats, list):
                for stat in usage_stats:
                    if not stat.get("total_tokens"):
                        # Handle both 'tokens' and 'chars' for different engines
                        in_t = stat.get("input_tokens") or stat.get("input_chars") or 0
                        out_t = stat.get("output_tokens") or stat.get("output_chars") or 0
                        stat["total_tokens"] = in_t + out_t

                    stats_msg = {
                        "type": "usage_stats",
                        "session_id": session_id,
                        "source_lang": source_lang,
                        "target_lang": target_lang,
                        **stat,
                    }
                    asyncio.run_coroutine_threadsafe(manager.broadcast(stats_msg), event_loop)
            else:
                if not usage_stats.get("total_tokens"):
                    # Robust total tokens calculation
                    in_t = usage_stats.get("input_tokens") or usage_stats.get("input_chars") or 0
                    out_t = usage_stats.get("output_tokens") or usage_stats.get("output_chars") or 0
                    usage_stats["total_tokens"] = in_t + out_t

                stats_msg = {
                    "type": "usage_stats",
                    "session_id": session_id,
                    "source_lang": source_lang,
                    "target_lang": target_lang,
                    **usage_stats,
                }
                asyncio.run_coroutine_threadsafe(manager.broadcast(stats_msg), event_loop)

async def audio_level_broadcast_loop(is_running_func, audio_meter, manager):
    """Broadcast audio RMS levels to all connected Flutter clients ~13 fps."""
    while is_running_func():
        msg = {
            "type": "audio_levels",
            "input_level": audio_meter.input_level,
            "output_level": audio_meter.output_level,
        }
        await manager.broadcast(msg)
        await asyncio.sleep(0.075)

async def status_broadcast_loop(is_running_func, manager, orchestrator):
    """Broadcast model statuses periodically while the server is running."""
    while is_running_func():
        await manager.broadcast_status(orchestrator)
        await asyncio.sleep(2.0)

def audio_poll_loop(session_id, is_running_func, audio_capture, orchestrator, get_context_func, callback):
    """Background thread: polls audio capture queue and feeds to orchestrator."""
    logging.info(f"[audio_poll_loop] Started session {session_id}")
    try:
        ctx = get_context_func()
        orchestrator.start_stream(
            sample_rate=getattr(audio_capture, "sample_rate", 16000),
            source_lang=ctx["source_lang"],
            target_lang=ctx["target_lang"],
            ai_engine=ctx["ai_engine"],
            transcription_model=ctx["transcription_model"],
            translation_model=ctx["translation_model"],
            callback=callback,
        )
        while is_running_func() and session_id == get_context_func()["session_id"]:
            if audio_capture is None:
                time.sleep(0.1)
                continue
            item = audio_capture.get_audio_chunk()
            if item is not None:
                chunk, _sample_rate = item
                orchestrator.append_audio(chunk)
            else:
                time.sleep(0.01)
        
        current_session_id = get_context_func()["session_id"]
        if session_id != current_session_id:
            logging.info(f"[audio_poll_loop] Session {session_id} superseded by {current_session_id}. Exiting.")
        else:
            logging.info(f"[audio_poll_loop] Session {session_id} stopping normally.")

    except Exception as e:
        logging.error(f"[audio_poll_loop] Session {session_id} Crashed: {e}")
        # We don't set is_running to False here to avoid circular dependency easily, 
        # but the caller should handle it if needed.
