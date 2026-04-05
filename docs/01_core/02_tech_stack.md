# 02 — Tech Stack

## Flutter Client

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Framework** | Flutter | SDK ^3.10.7 | Desktop UI (Windows) |
| **State Management** | flutter_bloc + bloc | ^9.1.1 | BLoC pattern |
| **BLoC Concurrency** | bloc_concurrency | ^0.3.0 | Event transformers: `sequential()` (settings save), `droppable()` (settings load) |
| **DI** | get_it | ^7.7.0 | Service locator / dependency injection |
| **Navigation** | go_router | (via core/router) | Declarative routing |
| **Firebase** | firebase_core, firebase_auth, cloud_firestore, firebase_database | ^4.5.0 / ^6.2.0 / ^6.1.3 / ^12.1.4 | Auth, settings sync, usage tracking |
| **Auth** | google_sign_in_all_platforms, desktop_webview_auth, app_links, protocol_handler | ^2.0.2 / ^0.0.16 / ^7.0.0 / ^0.2.0 | Google OAuth & deep linking |
| **WebSocket** | web_socket_channel | ^3.0.3 | Communication with local Python server |
| **Networking** | http | ^1.2.2 | REST calls (update check, etc.) |
| **Storage** | flutter_secure_storage, shared_preferences | ^9.2.2 / latest | Secure token storage, app prefs |
| **Windowing** | bitsdojo_window, window_manager, flutter_acrylic, windows_single_instance | ^0.1.6 / ^0.4.3 / ^1.1.4 / ^1.1.0 | Custom title bar, multi-instance prevention |
| **System Tray** | tray_manager, system_tray | ^0.2.3 / ^2.0.3 | Background tray icon |
| **UI / UX** | google_fonts, flutter_markdown | latest / ^0.7.7+1 | Typography, markdown rendering |
| **Device Info** | device_info_plus, network_info_plus, package_info_plus | ^11.3.0 / ^7.0.0 / ^9.0.0 | Hardware/network fingerprinting |
| **Payments** | razorpay_flutter (via protocol_handler, app_links) | latest | In-app subscription upgrade |
| **Utilities** | intl, path, equatable, dartz | ^0.20.2 / ^1.9.0 / ^2.0.8 / ^0.10.1 | i18n, path ops, value equality, functional programming |

---

## Python Server

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Framework** | FastAPI + Uvicorn | latest | HTTP + WebSocket server |
| **Audio Capture** | PyAudio + WASAPI | latest | System and mic audio (Windows) |
| **ASR — Online** | Google Speech Recognition (SpeechRecognition lib) | latest | Free online ASR |
| **ASR — Offline** | Whisper (OpenAI via torch) | tiny/base/small/medium | Local offline transcription |
| **ASR — Premium** | NVIDIA Riva ASR via gRPC | latest | High-accuracy multilingual (Parakeet/Canary) |
| **Translation — Free** | Google Translate (unofficial) | latest | Default engine |
| **Translation — Cloud** | Google Cloud Translation v3 (gRPC) | latest | Professional grade |
| **Translation — Free Alt** | MyMemory API | latest | No-key alternative |
| **Translation — AI** | NVIDIA Llama 3.1 8B via NIM | latest | Context-aware neural translation |
| **Translation — Premium** | NVIDIA Riva NMT via gRPC | latest | High-quality neural translation |
| **Translation — Engines** | deep-translator | ^1.11.0 | Google, MyMemory integration |
| **Networking** | websockets, httpx | ^11.0.0 / latest | Async communication and API calls |
| **NLP** | pysbd | latest | Sentence boundary detection (stutter removal) |
| **Logging** | structlog | latest | Structured logging |
| **Numerics** | numpy, resampy | latest | Audio RMS calculation and resampling |
| **Packaging** | PyInstaller + InnoSetup | latest | Windows installer (.exe) build |

---

## Firebase Services Used

| Service | Used For |
|---------|----------|
| **Firebase Auth** | User authentication (Google, Email/Pass, Anonymous) |
| **Cloud Firestore** | User profiles, settings, session tokens, audit logs |
| **Firebase Realtime Database** | Live usage counters (token tracking) |

---

## Dev Tools

| Tool | Purpose |
|------|---------|
| PyArmor | Server obfuscation for release builds |
| InnoSetup (`installer_setup.iss`) | Windows installer generator |
| flutter_launcher_icons | App icon generation |
| bloc_test + mocktail | BLoC unit testing |
| pytest | Python server unit testing (server/ tests/) |
| `analysis_options.yaml` | Custom lint config: `unused_import` as error, safety rules (`unawaited_futures`, `cancel_subscriptions`, `avoid_print`, etc.) |
| `flutter_ci.yml` | GitHub Actions: analyze + BLoC unit tests + Codecov coverage + Windows build verification |
| `release.yml` | GitHub Actions: full installer build (PyInstaller + Inno Setup) + GitHub Release creation |

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Local Python server | WASAPI requires native Windows API; Python ecosystem best for AI model integration |
| WebSocket for Flutter↔Python | Low-latency, bidirectional, works without HTTP overhead |
| BLoC over Provider | Explicit event/state contracts; better for testability and debugging |
| flutter_secure_storage | Prevents debug/release session cross-contamination (see `08_session_isolation_guide.md`) |
| Firebase on desktop | Handles auth + cloud sync without a custom backend |
| `model_changed` flag in settings sync | Backend skips expensive model reinitialization when only non-model settings change (volume, VAD, etc.) |
| Script-aware `estimate_tokens()` | Accurate BPE token estimation per script (CJK/Devanagari ≈1 tok/char vs Latin ≈1/4); used for token quota tracking |
| gRPC warmup on session start | Pre-establishes TLS connection to NVIDIA NIM on first session start, eliminating 5–6s first-caption delay |
| `ThreadPoolExecutor` for ASR | Parallel chunk submission with ordered `deque[Future]` drain preserves caption order without blocking |
