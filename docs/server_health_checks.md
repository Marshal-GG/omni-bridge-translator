# Server Health Checks Guide

This guide explains how to verify the status of the Omni Bridge Python server and its AI models using the built-in REST endpoints.

## 1. Using a Web Browser

The easiest way to check the server is to open these URLs in your browser:

- **Server Status**: [http://127.0.0.1:8765/status](http://127.0.0.1:8765/status)
- **Model Status**: [http://127.0.0.1:8765/models/status](http://127.0.0.1:8765/models/status)

## 2. Using the Terminal (PowerShell)

If you are working in a terminal, use the following commands:

### Check General Status
Returns basic server information and uptime.
```powershell
Invoke-RestMethod http://127.0.0.1:8765/status
```

### Check Available Audio Devices
```powershell
Invoke-RestMethod http://127.0.0.1:8765/devices
```

### Unload Whisper Model
```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8765/whisper/unload
```

### Check Model Status
Checks if the transcription and translation models are initialized and ready.
```powershell
Invoke-RestMethod http://127.0.0.1:8765/models/status
```

## 3. Using curl (Command Prompt / Linux / macOS)

If you have `curl` installed:

```bash
# General Status
curl http://127.0.0.1:8765/status

# Model Status
curl http://127.0.0.1:8765/models/status
```

## Troubleshooting

- **404 Not Found**: Ensure you have restarted the server after the latest updates.
- **Connection Refused**: Ensure the server is actually running (terminal shows `Uvicorn running on http://127.0.0.1:8765`).
- **Initialization Issues**: If `models/status` shows `ready: false`, it means the orchestrator hasn't loaded the models yet. This usually happens on the first request or if a session hasn't started.
- **Excessive Log Output**: If your console is too busy, ensure you ARE NOT running with `OMNI_BRIDGE_DEBUG=true`. By default, per-event logs are hidden to keep the console clean.
