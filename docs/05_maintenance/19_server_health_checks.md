# 19 — Server Health Checks

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
curl http://127.0.0.1:8765/status
curl http://127.0.0.1:8765/models/status
```

---

## 4. Model Status Reference

Each model in the `models/status` response reports a `status` string. Full reference:

| Status | Meaning | Action |
|--------|---------|--------|
| `ready` | Model is initialized and accepting requests | None — all good |
| `loading` | Model is connecting to API or loading into VRAM | Wait 5–10s then check again |
| `fallback` | Llama has no API key — system falls back to Google Free | Configure NVIDIA API key in Settings if Llama is needed |
| `no_api_key` | Riva ASR has no NVIDIA API key | Configure NVIDIA API key in Settings |
| `error` | Riva ASR setup failed (bad key or network error) | Check API key validity; check network access to `grpc.nvcf.nvidia.com:443` |
| `downloaded` | Whisper model file is on disk but not yet loaded into memory | Start a translation session — it loads on first use |
| `downloading` | Whisper model file is being downloaded | Wait for download to complete (`progress` field shows %) |
| `not_downloaded` | Whisper model has never been downloaded | Download via Settings → Whisper tab |

---

## 5. Troubleshooting

### First caption takes 5–6 seconds after session start
**Cause**: NVIDIA Riva ASR uses gRPC over TLS to `grpc.nvcf.nvidia.com:443`. The first connection pays a cold-start TLS handshake cost of ~5–6s.

**What the app does**: On session start, a background warmup sends a 100ms silent chunk to pre-establish the TLS connection before the first real audio chunk arrives. On subsequent sessions, the connection is already warm.

**If still slow**: Check network latency to NVIDIA's endpoint. A VPN or firewall blocking gRPC port 443 will prevent warmup from succeeding.

---

### 502 / 503 errors for Riva ASR in server logs
**Cause**: Transient NVIDIA NIM gateway overload — happens occasionally under load.

**What the app does**: `RivaASRModel.transcribe()` automatically retries up to 3 times with 0.5s and 1.0s backoff on `502`, `503`, or `UNAVAILABLE` errors before dropping the chunk. These errors are logged as `WARNING`, not `ERROR`.

**If persistent**: NVIDIA NIM may be under heavy load. The chunk is silently dropped after 3 failed retries — translation continues on the next chunk. Check the [NVIDIA NIM status page](https://status.build.nvidia.com/).

---

### `ready: false` on models/status after session start
**Cause**: The orchestrator initializes models on the first `start` command, not at server boot. Models show `ready: false` until a session starts.

**Solution**: Start a translation session from the app. Models are initialized during `SessionHandler.start()`. If a model fails to initialize (e.g. bad API key), the server sends a descriptive error WebSocket message to the client.

---

### Llama shows `fallback` status
**Cause**: The Llama model has no NVIDIA API key configured. This is intentional — `fallback` (not `error`) is shown to avoid a red error indicator since the system automatically falls back to Google Free translation.

**Solution**: Enter a valid NVIDIA API key in Settings → Languages → NVIDIA API Key. The key is validated live before the Save button is enabled.

---

### Excessive Log Output
If your console is too busy, ensure you are **not** running with `OMNI_BRIDGE_DEBUG=true`. By default, per-event logs (ASR results, translation stats) are hidden to keep the console clean. Set `OMNI_BRIDGE_DEBUG=true` only when actively debugging a specific issue.

---

### 404 Not Found
Ensure you have restarted the server after the latest updates.

### Connection Refused
Ensure the server is actually running — terminal should show `Uvicorn running on http://127.0.0.1:8765`.
