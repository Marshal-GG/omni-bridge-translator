import asyncio
import json
import logging
import threading
import time
from typing import Any, Callable, Dict, TYPE_CHECKING

if TYPE_CHECKING:
    from src.audio.capture import AudioCapture
    from src.network.orchestrator import InferenceOrchestrator
    from src.network.ws_manager import ConnectionManager
    from src.audio.meter import AudioMeter

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
    logging.info(f"[caption_callback] Text: '{text[:50]}...', session: {session_id}, manager: {manager is not None}")
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
        stream_started = False
        while is_running_func() and session_id == get_context_func()["session_id"]:
            if audio_capture is None:
                time.sleep(0.1)
                continue
            item = audio_capture.get_audio_chunk()
            if item is not None:
                chunk, sample_rate = item
                if not stream_started:
                    ctx = get_context_func()
                    orchestrator.start_stream(
                        sample_rate=sample_rate,
                        source_lang=ctx["source_lang"],
                        target_lang=ctx["target_lang"],
                        ai_engine=ctx["ai_engine"],
                        transcription_model=ctx["transcription_model"],
                        translation_model=ctx["translation_model"],
                        callback=callback,
                        suspended=ctx["initial_suspension"],
                    )
                    stream_started = True
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
