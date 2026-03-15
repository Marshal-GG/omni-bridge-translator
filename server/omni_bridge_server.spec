# -*- mode: python ; coding: utf-8 -*-
import os

# To build with obfuscation:
# 1. cd server
# 2. pyarmor gen --output dist_obfuscated .
# 3. pyinstaller omni_bridge_server.spec

is_obfuscated = os.path.exists('dist_obfuscated')
entry_script = 'dist_obfuscated/flutter_server.py' if is_obfuscated else 'flutter_server.py'

a = Analysis(
    [entry_script],
    pathex=['dist_obfuscated' if is_obfuscated else '.'],
    binaries=[],
    datas=[],
    hiddenimports=[
        'src.network.orchestrator',
        'src.audio.capture',
        'src.audio.meter',
        'src.audio.shared_pyaudio',
        'src.models.whisper_model',
        'src.models.riva_model',
        'src.models.google_model',
        'src.models.llama_model',
        'src.models.mymemory_model',
        'src.models.google_cloud_model',
        'src.models.speech_recognition_model',

        # Core dependencies (manually listed because obfuscation masks them)
        'fastapi',
        'uvicorn',
        'websockets',
        'sounddevice',
        'numpy',
        'requests',
        'httpx',
        'multipart',
        'pyaudiowpatch',
        'pyaudio',
        'openai',
        'nvidia_riva_client',
        'riva',
        'riva.client',
        'psutil',
        'speech_recognition',
        'whisper',
        'deep_translator',
        'resampy',
        'google.cloud.translate_v3',
        # Internals
        'starlette.routing',
        'starlette.middleware.cors',
        'fastapi.middleware.cors',
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
        'websockets',
        'websockets.legacy',
        'websockets.legacy.server',
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
