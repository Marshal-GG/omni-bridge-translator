# 00 — Documentation Index

> Master index of all Omni Bridge documentation. Start here.

---

## Quick Links by Role

| I am a… | Start with… |
|---------|-------------|
| **New user** | [01 — Project Overview](01_core/01_project_overview.md) |
| **Developer setting up from source** | [08 — Developer Setup](03_guides/08_developer_setup.md) |
| **Flutter contributor** | [05 — Flutter Architecture](02_architecture/05_flutter_architecture.md) |
| **Python/server contributor** | [06 — Python Architecture](02_architecture/06_python_architecture.md) |
| **Admin / Firebase manager** | [15 — Admin Features](04_features/15_admin_features.md) |
| **Shipping a release** | [12 — GitHub Workflow Guide](03_guides/12_github_workflow_guide.md) |

---

## All Documents

| # | Document | Audience | Topic |
|---|----------|----------|-------|
| 01 | [01_project_overview.md](01_core/01_project_overview.md) | Everyone | What is Omni Bridge, high-level architecture |
| 02 | [02_tech_stack.md](01_core/02_tech_stack.md) | Developers | All dependencies, frameworks, and design decisions |
| 03 | [03_project_structure.md](01_core/03_project_structure.md) | Developers | Full directory layout with restructure history |
| 04 | [04_architecture_diagrams.md](01_core/04_architecture_diagrams.md) | Everyone | Visual system architecture and component interconnection |
| 05 | [05_flutter_architecture.md](02_architecture/05_flutter_architecture.md) | Flutter devs | BLoCs, UseCases, DI, routing, unit tests |
| 06 | [06_python_architecture.md](02_architecture/06_python_architecture.md) | Python devs | Server architecture, WebSocket protocol, data flow |
| 07 | [07_database_schema.md](02_architecture/07_database_schema.md) | Developers | Firestore & Realtime Database schema |
| 08 | [08_developer_setup.md](03_guides/08_developer_setup.md) | Developers | How to run from source, build for production |
| 09 | [09_session_isolation_guide.md](03_guides/09_session_isolation_guide.md) | Developers | FlutterSecureStorage, DPAPI session isolation |
| 10 | [10_firebase_terminal_management.md](03_guides/10_firebase_terminal_management.md) | Admins | CLI-based Firebase management |
| 11 | [11_github_releases_guide.md](03_guides/11_github_releases_guide.md) | Maintainers | Publishing a new versioned release |
| 12 | [12_github_workflow_guide.md](03_guides/12_github_workflow_guide.md) | Developers | CI/CD, branching strategy, releasing with GitHub Actions |
| 13 | [13_new_screen_setup_guide.md](03_guides/13_new_screen_setup_guide.md) | Developers | Guide for setting up new screens and features |
| 14 | [14_usage_analytics_guide.md](03_guides/14_usage_analytics_guide.md) | Developers | Usage analytics feature: domain, data, presentation layers |
| 15 | [15_admin_features.md](04_features/15_admin_features.md) | Admins | Admin panel, user management, Firebase |
| 16 | [16_monetization_plan.md](04_features/16_monetization_plan.md) | Product | Subscription tiers, quotas, Razorpay |
| 17 | [17_uncensored_translation_plan.md](04_features/17_uncensored_translation_plan.md) | Developers | Detailed implementation guide for the "Uncensored" toggle |
| 18 | [18_support_feature_guide.md](04_features/18_support_feature_guide.md) | Developers | Support feature: ticketing, chat, and system snapshots |
| 19 | [19_server_health_checks.md](05_maintenance/19_server_health_checks.md) | Operators | REST health and status endpoints |
| 20 | [20_google_auth_troubleshooting.md](05_maintenance/20_google_auth_troubleshooting.md) | Developers | Google OAuth / Sign-In troubleshooting |
| 21 | [21_python_interpreter_troubleshooting.md](05_maintenance/21_python_interpreter_troubleshooting.md) | Developers | Python environment issues |
| 22 | [22_token_estimation.md](02_architecture/22_token_estimation.md) | Developers | Token counting logic for all ASR and translation engines |
| 23 | [23_pre_launch_todo.md](05_maintenance/23_pre_launch_todo.md) | Maintainers | Remaining work before public launch — blockers, high, medium, low |

---

## Archival Documents

| # | Document | Audience | Topic |
|---|----------|----------|-------|
| 98 | [98_restructure_plan.md](01_core/98_restructure_plan.md) | Reference | Legacy restructure history (Phases 1–8) |
| 99 | [99_deep_restructure_plan.md](01_core/99_deep_restructure_plan.md) | Reference | Deep restructure history (Phases 9–16) |

---

## Architecture at a Glance

```
Flutter Desktop App (Windows)
 └─ Feature-Driven Vertical Slices: auth · translation · settings · history · subscription · startup · about · usage · support
    └─ Each slice: Domain (Entities, UseCases, Repos) / Data (DataSources, Repo Impls) / Presentation (BLoC, Screens)
    └─ Shell: AppShellBloc (root BLoC) · AppDashboardShell · AppNavigationRail · ShellOverlay
    └─ Core: DI (get_it) · Navigation (AppRouter + RouteChangeNotifier) · Platform (Window, Tray) · Infrastructure (PythonServerManager) · Theme · Utils

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
