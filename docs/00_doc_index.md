# 00 — Documentation Index

> Master index of all Omni Bridge documentation. Start here.

---

## Quick Links by Role

| I am a… | Start with… |
|---------|-------------|
| **New user** | [01 — Project Overview](01_project_overview.md) |
| **Developer setting up from source** | [07 — Developer Setup](07_developer_setup.md) |
| **Flutter contributor** | [04 — Flutter Architecture](04_flutter_architecture.md) |
| **Python/server contributor** | [05 — Python Architecture](05_python_architecture.md) |
| **Admin / Firebase manager** | [09 — Admin Features](09_admin_features.md) |
| **Shipping a release** | [18 — GitHub Workflow Guide](18_github_workflow_guide.md) |

---

## All Documents

| # | Document | Audience | Topic |
|---|----------|----------|-------|
| 01 | [01_project_overview.md](01_project_overview.md) | Everyone | What is Omni Bridge, high-level architecture |
| 02 | [02_tech_stack.md](02_tech_stack.md) | Developers | All dependencies, frameworks, and design decisions |
| 03 | [03_project_structure.md](03_project_structure.md) | Developers | Full directory layout with restructure history |
| 04 | [04_flutter_architecture.md](04_flutter_architecture.md) | Flutter devs | BLoCs, UseCases, DI, routing, unit tests |
| 05 | [05_python_architecture.md](05_python_architecture.md) | Python devs | Server architecture, WebSocket protocol, data flow |
| 06 | [06_database_schema.md](06_database_schema.md) | Developers | Firestore & Realtime Database schema |
| 07 | [07_developer_setup.md](07_developer_setup.md) | Developers | How to run from source, build for production |
| 08 | [08_session_isolation_guide.md](08_session_isolation_guide.md) | Developers | FlutterSecureStorage, DPAPI session isolation |
| 09 | [09_admin_features.md](09_admin_features.md) | Admins | Admin panel, user management, Firebase |
| 10 | [10_server_health_checks.md](10_server_health_checks.md) | Operators | REST health and status endpoints |
| 11 | [11_firebase_terminal_management.md](11_firebase_terminal_management.md) | Admins | CLI-based Firebase management |
| 12 | [12_github_releases_guide.md](12_github_releases_guide.md) | Maintainers | Publishing a new versioned release |
| 13 | [13_monetization_plan.md](13_monetization_plan.md) | Product | Subscription tiers, quotas, Razorpay |
| 14 | [14_google_auth_troubleshooting.md](14_google_auth_troubleshooting.md) | Developers | Google OAuth / Sign-In troubleshooting |
| 15 | [15_python_interpreter_troubleshooting.md](15_python_interpreter_troubleshooting.md) | Developers | Python environment issues |
| 16 | [16_restructure_plan.md](16_restructure_plan.md) | Reference | Legacy restructure history (Phases 1–8) ✅ Complete |
| 17 | [17_deep_restructure_plan.md](17_deep_restructure_plan.md) | Reference | Deep restructure history (Phases 9–16) ✅ Complete |
| 18 | [18_github_workflow_guide.md](18_github_workflow_guide.md) | Developers | CI/CD, branching strategy, releasing with GitHub Actions |
| 19 | [19_new_screen_setup_guide.md](19_new_screen_setup_guide.md) | Developers | Guide for setting up new screens and features |
| 20 | [20_usage_analytics_guide.md](20_usage_analytics_guide.md) | Developers | Usage analytics feature: domain, data, presentation layers |

---

## Architecture at a Glance

```
Flutter Desktop App (Windows)
 └─ Feature-Driven Vertical Slices: auth · translation · settings · history · subscription · startup · about · usage
    └─ Each slice: Domain (Entities, UseCases, Repos) / Data (DataSources, Repo Impls) / Presentation (BLoC, Screens)
    └─ Core: DI (get_it) · Navigation (AppRouter) · Platform (Window, Tray) · Infrastructure (PythonServerManager) · Theme · Utils

Python FastAPI Server (local, ws://127.0.0.1:8765)
 └─ Pipeline: InferenceOrchestrator → ASRDispatcher → TranslationDispatcher
 └─ Audio: AudioCapture (WASAPI/mic) + AudioMeter
 └─ Network: CommandRouter → Modular Handlers (Session, Config, Device, Status)
 └─ Models: ASR (Riva, Whisper, Google) + Translation (Riva NMT, Llama, Google Cloud, Google Free, MyMemory)

Firebase (cloud)
 └─ Auth (Google, Email, Anonymous) · Firestore (settings, sessions) · Realtime DB (usage counters)

CI/CD (GitHub Actions)
 └─ flutter_ci.yml — Analyze + Test + Codecov + Windows build (Manual or Auto trigger)
 └─ release.yml — Full installer build → OmniBridge_Setup_v*.exe GitHub Release (Manual trigger)
```
