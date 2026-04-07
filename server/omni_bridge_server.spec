# -*- mode: python ; coding: utf-8 -*-
import os

# To build with obfuscation:
# 1. cd server
# 2. pyarmor gen --output dist_obfuscated .
# 3. pyinstaller omni_bridge_server.spec

is_obfuscated = os.path.exists('dist_obfuscated')
entry_script = 'dist_obfuscated/flutter_server.py' if is_obfuscated else 'flutter_server.py'
base_path = 'dist_obfuscated' if is_obfuscated else '.'

a = Analysis(
    [entry_script],
    pathex=[base_path],
    binaries=[],
    datas=[
        # Include all src packages so submodule discovery works at runtime
        ('src', 'src'),
        # PyArmor runtime — required when building from dist_obfuscated/
        *([('dist_obfuscated/pyarmor_runtime_000000', 'pyarmor_runtime_000000')] if is_obfuscated else []),
    ],
    hiddenimports=[
        # --- Internal src modules ---
        'src.pipeline.orchestrator',
        'src.asr.asr_dispatcher',
        'src.translation.translation_dispatcher',
        'src.audio.capture',
        'src.audio.handler',
        'src.audio.meter',
        'src.audio.shared_pyaudio',
        'src.models.asr.riva_asr',
        'src.models.asr.whisper_asr',
        'src.models.asr.local_asr',
        'src.models.translation.riva_nmt',
        'src.models.translation.llama_translation',
        'src.models.translation.google_translation',
        'src.models.translation.google_api_translation',
        'src.models.translation.mymemory_translation',
        'src.network.handlers.base_handler',
        'src.network.handlers.session_handler',
        'src.network.handlers.config_handler',
        'src.network.handlers.device_handler',
        'src.network.handlers.status_handler',
        'src.network.router',
        'src.network.ws_manager',
        'src.utils.server_utils',
        'src.utils.language_support',

        # --- Third-party ---
        'fastapi',
        'fastapi.middleware.cors',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.asyncio',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'starlette.routing',
        'starlette.middleware.cors',
        'websockets',
        'websockets.legacy',
        'websockets.legacy.server',
        'sounddevice',
        'pyaudiowpatch',
        'pyaudio',
        'numpy',
        'requests',
        'httpx',
        'multipart',
        'openai',
        'structlog',
        'pysbd',
        'psutil',
        'resampy',
        'speech_recognition',
        'whisper',
        'torch',
        'numba',
        'llvmlite',
        'deep_translator',
        'riva',
        'riva.client',
        'google.cloud.translate_v3',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='omni_bridge_server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    # Keep console=True so errors are visible; Flutter launches this hidden anyway
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
