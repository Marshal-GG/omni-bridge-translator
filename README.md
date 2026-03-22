# Omni Bridge — Live AI Translator

> **Real-time speech translation, right on your desktop.**  
> Capture any audio from your PC or mic, translate it instantly, and see it as a live transparent overlay — no extra hardware required.

<div align="center">

[![Download Latest](https://img.shields.io/github/v/release/Marshal-GG/omni-bridge-translator?label=Download&style=for-the-badge&color=teal)](https://github.com/Marshal-GG/omni-bridge-translator/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue?style=for-the-badge&logo=windows)](https://github.com/Marshal-GG/omni-bridge-translator/releases)
[![License](https://img.shields.io/badge/License-Restricted_Study_Only-black.svg)](LICENSE)

</div>

---

<div align="center">

| Translator Overlay | Mini Mode |
| :---: | :---: |
| <img src="assets/screenshots/image3.png" width="420"/> | <img src="assets/screenshots/image2.png" width="420"/> |

| Settings Panel |
| :---: |
| <img src="assets/screenshots/image1.png" width="380"/> |

</div>

---

## ✨ Features

### 🎙️ Universal Audio Capture
- Translates **any audio playing on your PC** — videos, calls, streams, meetings
- Switch between **system audio** and **microphone** with one toggle
- Fine-grained **volume controls** for desktop and mic independently

### 🌐 Multiple Speech Recognition Engines
| Engine | Best For |
|--------|----------|
| **Google Online** | Fast, no setup required |
| **NVIDIA Riva** | High-accuracy multilingual (API key needed) |
| **Whisper Offline** | Privacy-first, works without internet |

Whisper comes in 4 sizes — **Tiny, Base, Small, and Medium** — downloadable directly from the Settings panel.

### 🔤 Multiple Translation Engines
| Engine | Notes |
|--------|-------|
| **Google Translate** | Recommended — free, fast, 100+ languages |
| **Google Cloud (v3)** | Professional grade gRPC translation (Service Account needed) |
| **MyMemory** | Free alternative, no key needed |
| **NVIDIA Riva NMT** | High-quality neural translation |
| **Llama 3.1 8B** | AI-powered, great for context-aware translations |

### 🗣️ 20+ Languages Supported
Auto-detect source language, or manually select from: English, Spanish, French, German, Chinese, Japanese, Korean, Russian, Portuguese, Italian, Arabic, Hindi, Dutch, Turkish, Vietnamese, Polish, Indonesian, Thai, Bengali, and more.

### 🪟 Transparent Always-on-Top Overlay
- Fully **draggable, resizable** transparent overlay — stays above all windows
- **Collapse to Mini Mode** — single caption line that takes up minimal screen space
- **Adjustable opacity** and font size from Settings
- **Bold text** toggle for better readability

### 📜 Caption History
- Every translated caption is saved to a searchable, premium **History Panel** with a glassy dark aesthetic.
- Standardized window controls (Minimize, Close, Drag) and a dedicated "Clear History" action.
- **Contextual Upgrades**: Free-tier users are automatically presented with the `UpgradeSheet` upon entering the history view, providing a seamless path to premium features.

### 🚀 Startup & Onboarding
- **Seamless onboarding** flow for new users (Splash -> Onboarding -> Login).
- **Proactive update checks** on startup to ensure you're always on the latest version.

### ℹ️ About & Updates
- Dedicated **About Panel** showing version info, licensing, and credits.
- **Manual update check** button with real-time status feedback.

### 👤 Account & Sync
- Sign in with **Google**, **Email/Password**, or use as **Guest**
- Settings sync to the cloud — your preferences follow you
- **Remote Device Management**: Revoke sessions or sign out of all devices from your account settings
- **Weekly Usage Tracking**: Monitor your token consumption across daily, weekly, and monthly periods
- Session activity and translation usage are tracked securely per session

### 💳 Subscription Tiers

| Feature | **Free** | **Pro** (₹799/mo) | **Enterprise** (₹2,499/mo) |
|---------|----------|-------------------|---------------------------|
| **Daily Quota** | 5,000 tokens | 25,000 tokens | 75,000 tokens |
| **Monthly Quota** | 50,000 tokens | 250,000 tokens | 750,000 tokens |
| **Translation Engines** | Google, MyMemory | All (+ Google Cloud, Riva, Llama) | All |
| **Transcription** | Google Online | + Whisper (tiny–small) | + Whisper medium, Riva |
| **Microphone Audio** | — | Yes | Yes |
| **Caption History** | — | 7-day retention | 30-day retention |
| **Session Duration** | 15 min | 2 hours | 8 hours |
| **Concurrent Sessions** | 1 | 2 | 5 |
| **Per-Engine Limits** | — | google_api: 100k, riva: 100k, llama: 150k | google_api: 300k, riva: 300k, llama: 500k |

> Usage is calculated as the sum of input (source) and output (translated) tokens across all engines. A one-time **Trial** tier is also available for new users to test Pro-level features before committing.

Pro unlocks caption history, microphone audio, and all AI engines. Clear visual indicators (teal highlights) and real-time usage tracking in the Account screen help you manage your plan. Upgrade from within the app via Razorpay.

> Users with their own NVIDIA API Key bypass the daily quota for NVIDIA-backed engines.

---

## ⬇️ Download & Install

### Option 1 — Installer (Recommended)

1. Go to the [**Releases page**](https://github.com/Marshal-GG/omni-bridge-translator/releases/latest)
2. Download **`OmniBridge_Setup.exe`**
3. Run the installer — it bundles everything (Python server + UI)
4. Launch **Omni Bridge** from your Start Menu or Desktop

> No Python or Flutter installation required when using the installer.

### Option 2 — Run from Source

See [Developer Setup →](docs/developer_setup.md)

---

## 🚀 Quick Start

1. **Launch** Omni Bridge from Start Menu (or run `start_server.bat` if running from source)
2. **Sign in** with Google, Email, or continue as Guest
3. **Open Settings** (gear icon or click the `auto → en` language badge in the header)
4. Choose your **Speech Recognition** and **Translation Engine**
5. Select your **Target Language**
6. **Close Settings** — captions appear live as audio plays on your PC

That's it. No complex configuration needed for the default Google setup.

---

## ⚙️ Using an NVIDIA API Key

For NVIDIA Riva ASR / NMT or Llama translation:
1. Get a free API key at [build.nvidia.com](https://build.nvidia.com)
2. Open **Settings → Translation Engine** and paste your key
3. Select **NVIDIA Riva** or **Llama** as your engine

---

| Desktop Volume | 1.0 (Wait for Live Update) |
| Audio not captured | Check playback device and WebSocket logs |

---

OmniBridge follows **Clean Architecture** principles across both its components:

### 📱 Flutter Client
- **Feature-Driven Structure**: 100% organized by vertical slices: `auth`, `translation`, `settings`, `history`, `subscription`, `startup`, and `about`.
- **Domain Layer**: Pure business logic with Entities, abstract Repositories, and **UseCases** (22+ specialized logic blocks).
- **Data Layer**: Feature-specific **RemoteDataSources** (Firebase, WebSocket, REST) and Repository implementations. Legacy `lib/data` has been consolidated.
- **Presentation Layer**: UI screens and widgets using the **BLoC pattern** with route-scoped injection for optimized memory management.
- **Dependency Injection**: Centralized `injection.dart` using `get_it`, following the `DataSource -> Repository -> UseCase -> Bloc` hierarchy.

### 🐍 Python Server
- **Orchestration Layer**: Thin coordinator managing session lifecycle and queues.
- **Dispatcher Layer**: Modular ASR and Translation dispatchers handling model selection, silence gating, and comprehensive fallbacks.
- **Model Layer**: Abstracted AI model implementations (Riva, Whisper, Llama, Google).
- **Network Layer**: Specialized handlers for protocol concerns (Config, Status, Session, Device).
- **Testing Suite**: Robust `pytest` suite for core server logic with full AI engine mocking.

---

## 📄 License

Personal Study & Learning License (Restricted) — see [LICENSE](LICENSE) for details. **No commercial use or mod distribution.**

---

<div align="center">

Made with ❤️ · [Report a Bug](https://github.com/Marshal-GG/omni-bridge-translator/issues) · [Request a Feature](https://github.com/Marshal-GG/omni-bridge-translator/issues)

</div>
