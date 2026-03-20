# 01 — Project Overview

## What is Omni Bridge?

**Omni Bridge** is a real-time, AI-powered speech translation desktop application for Windows. It captures audio from any source on your PC (system audio or microphone), transcribes it using your chosen ASR engine, and translates it into your target language — displaying the result as a live transparent overlay on top of all your windows.

No extra hardware. No complex setup for the default configuration. Just launch and start translating.

---

## Core Value Proposition

| Problem | Omni Bridge Solution |
|---------|----------------------|
| Foreign-language meetings, streams, and videos | Live caption overlay — always visible without alt-tabbing |
| Privacy-sensitive content | Whisper offline mode — nothing leaves your PC |
| Need for high accuracy | NVIDIA Riva ASR + NMT via NVIDIA NIM API |
| No budget for premium tools | Google Translate + MyMemory free tier — zero cost to start |

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│               Flutter Desktop App (UI)           │
│  Overlay · Settings · History · Account · Auth   │
│                                                  │
│  State: BLoC  ·  DI: GetIt  ·  Nav: GoRouter    │
└───────────────────────┬─────────────────────────┘
                        │ WebSocket (ws://127.0.0.1:8765)
┌───────────────────────▼─────────────────────────┐
│           Python FastAPI Server (local)          │
│                                                  │
│  Audio Capture ──► ASR Engine ──► Translation   │
│  (PyAudio/WASAPI)   (Riva/Whisper/Google)       │
│                      (Google/Llama/Riva NMT)    │
└─────────────────────────────────────────────────┘
                        │
                   Firebase (cloud)
           Auth · Firestore · Realtime DB
```

- The **Flutter UI** connects to the local Python server via WebSocket
- The **Python server** runs as a background process, managed by the Flutter app
- **Firebase** handles authentication, settings sync, and usage tracking
- Everything runs **locally on the user's machine** — no cloud audio processing

---

## Audience

| User Type | Use Case |
|-----------|----------|
| End users | Download installer and use immediately |
| Developers | Run from source, extend AI engines, contribute |
| Power users | Bring own NVIDIA API key to bypass quotas |

---

## Key Constraints

- **Windows only** (WASAPI system audio capture requires Windows APIs)
- Python server must be running for translation to work
- Whisper models must be downloaded before first offline use
- NVIDIA Riva and Llama require a valid NVIDIA NIM API key

---

## Related Docs

| Document | Description |
|----------|-------------|
| [02_tech_stack.md](02_tech_stack.md) | All technologies, frameworks, and dependencies |
| [03_project_structure.md](03_project_structure.md) | Full directory layout with annotations |
| [04_flutter_architecture.md](04_flutter_architecture.md) | Flutter client architecture deep-dive |
| [05_python_architecture.md](05_python_architecture.md) | Python server architecture deep-dive |
| [07_developer_setup.md](07_developer_setup.md) | How to run from source |
