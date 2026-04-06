import os
import logging
import sys


def estimate_tokens(text: str) -> int:
    """Estimate token count for a string using script-aware heuristics.

    Latin/ASCII text compresses well (BPE ~4 chars/token).
    Indic scripts (Devanagari, Bengali, Tamil, etc.) and CJK compress poorly
    (~1-1.5 chars/token) because BPE rarely merges non-Latin codepoints.

    Unicode ranges checked:
      Devanagari:  0x0900–0x097F  (Hindi, Marathi, Sanskrit)
      Bengali:     0x0980–0x09FF
      Tamil:       0x0B80–0x0BFF
      Telugu:      0x0C00–0x0C7F
      Kannada:     0x0C80–0x0CFF
      Malayalam:   0x0D00–0x0D7F
      CJK Unified: 0x4E00–0x9FFF
      Arabic:      0x0600–0x06FF
      Cyrillic:    0x0400–0x04FF  (Russian etc. — ~2 chars/token)
    """
    if not text:
        return 0

    dense_chars = 0
    medium_chars = 0
    latin_chars = 0

    for ch in text:
        cp = ord(ch)
        if (0x0900 <= cp <= 0x0D7F) or (0x4E00 <= cp <= 0x9FFF) or (0x0600 <= cp <= 0x06FF):
            dense_chars += 1        # ~1 token/char
        elif 0x0400 <= cp <= 0x04FF:
            medium_chars += 1       # ~2 chars/token
        else:
            latin_chars += 1        # ~4 chars/token

    return dense_chars + (medium_chars + 1) // 2 + (latin_chars + 3) // 4

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    psutil = None  # type: ignore[assignment]
    HAS_PSUTIL = False

import structlog

def setup_logging(log_file: str, level: int = logging.INFO):
    """Configures structured logging with structlog."""
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="%Y-%m-%d %H:%M:%S"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.dev.ConsoleRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    
    # Also configure standard logging to pipe into file with logger name included
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
        handlers=[
            logging.FileHandler(log_file, encoding="utf-8"),
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    # Silence noisy third-party logs
    silence_list = [
        "urllib3", "requests", "httpx", "httpcore", "openai", "h2", "h11",
        "openai._base_client", "anyio", "numba", "numba.core",
    ]
    for logger_name in silence_list:
        logging.getLogger(logger_name).setLevel(logging.WARNING)
    
    logging.getLogger("uvicorn").setLevel(logging.INFO)
    logging.getLogger("fastapi").setLevel(logging.INFO)

    return structlog.get_logger()

def kill_process_on_port(port: int):
    """Kill any process listening on the given port using netstat + taskkill (Windows)."""
    import subprocess
    try:
        result = subprocess.run(
            ["netstat", "-ano"],
            capture_output=True, text=True, timeout=5
        )
        current_pid = str(os.getpid())
        for line in result.stdout.splitlines():
            if f":{port}" in line and "LISTENING" in line:
                parts = line.split()
                pid = parts[-1]
                if pid == current_pid:
                    continue
                logging.info(f"[Main] Killing process on port {port} (PID: {pid})")
                subprocess.run(["taskkill", "/F", "/PID", pid],
                               capture_output=True, timeout=5)
    except Exception as e:
        logging.error(f"[Main] Port cleanup failed: {e}")

def kill_other_instances(port: int = 8765):
    """Find and kill other running instances of this server to prevent port conflicts."""
    kill_process_on_port(port)

    if not HAS_PSUTIL:
        return

    current_pid = os.getpid()
    target_exe = "omni_bridge_server.exe"

    logging.info(f"[Main] Checking for existing instances (Current PID: {current_pid})...")

    for proc in psutil.process_iter(['pid', 'name']):
        try:
            pinfo = proc.info
            pid = pinfo['pid']
            name = pinfo['name']

            if pid == current_pid:
                continue

            if name == target_exe:
                logging.info(f"[Main] Terminating stale instance: {name} (PID: {pid})")
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except psutil.TimeoutExpired:
                    logging.warning(f"[Main] Force killing PID {pid}")
                    proc.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
