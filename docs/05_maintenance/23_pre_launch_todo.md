# 23 — Pre-Launch TODO

Remaining work before Omni Bridge can be publicly launched. Items are ordered by priority within each section.

---

## CRITICAL — Must do before any build ships

### 0d. Update Firestore `system/app_version`
**What:** Firestore `system/app_version` must reflect `2.0.0` as the latest version so existing installs prompt users to update.

**Fields to set:**
```json
{
  "latest": "2.0.0",
  "min_supported": "<oldest version you still support>",
  "update_url": "https://github.com/Marshal-GG/omni-bridge-translator/releases",
  "download_url": "https://<direct installer download link>"
}
```

---

## BLOCKERS — Must complete before any public user

> All blockers resolved. See Completed section below.

---

## ARCHITECTURE — Clean Architecture Violations (must fix before declaring v2.0 stable)

The codebase has accumulated significant clean architecture violations. The strict rules are: **presentation → domain ← data**, BLoCs in presentation only, use-cases own all logic, repository interfaces in domain, DI via `get_it` only, no cross-feature internal imports.

### ~~A1. Eliminate `SubscriptionRemoteDataSource` singleton~~ ✅ COMPLETE

**Completed:** All 15+ `.instance` callsites across presentation, domain, and core layers have been replaced. `flutter analyze` reports zero issues.

**What was done:**
- Expanded `ISubscriptionRepository` interface to cover all callers' needs (billing notifiers, tier helpers, model access, config data, cancel/resume)
- `SubscriptionRepositoryImpl` delegates every method to `SubscriptionRemoteDataSource` via constructor injection
- New use-cases: `CancelSubscriptionUseCase`, `ResumeSubscriptionUseCase` — registered in `usecase_di.dart`
- `OpenCheckout` return type unified to `Future<String?>` (was `Future<void>` in interface, `Future<String?>` in datasource)
- `HistoryBloc` and `SettingsBloc` now inject `ISubscriptionRepository` instead of the datasource
- `TranslationRepositoryImpl` accepts `ISubscriptionRepository` (was `SubscriptionRemoteDataSource`)
- All presentation widgets (`billing_screen`, `plan_card`, `upgrade_sheet`, `current_usage_display`, `history_panel`, `languages_tab`, `subscription_screen`) use `sl<ISubscriptionRepository>()`
- Core callsites (`app_initializer`, `data_maintenance_remote_datasource`, `engine_usage_dto`) updated
- `admin_panel.dart` uses `sl<ISubscriptionRepository>()` for all interface methods; retains `sl<SubscriptionRemoteDataSource>()` only for the two debug-only admin methods (`setTierForOtherUser`, `setTierDebug`) — guarded by `kDebugMode`
- Test mocks updated: `MockSubscriptionRemoteDataSource` now implements `ISubscriptionRepository`; `SettingsBloc` test wired with `MockISubscriptionRepository`

**Verified:** `flutter analyze` → `No issues found!`

---

### A2. Eliminate `AuthRemoteDataSource` singleton from presentation (CRITICAL)

`AuthRemoteDataSource.instance` accessed directly from presentation widgets.

**Affected files:**
- `lib/features/auth/presentation/screens/account/account_screen.dart:6` — calls `currentUser.value`, `updateDisplayName(newName)`
- `lib/features/auth/presentation/screens/account/components/admin_panel.dart:5` — calls `auth.currentUser`, `firestore`
- `lib/features/about/presentation/screens/about_screen.dart:7` — cross-feature import

**Fix:** Use the existing `IAuthRepository` interface (already exists for admin check). Add use-cases: `WatchCurrentUserUseCase`, `UpdateDisplayNameUseCase`. Account screen and admin panel inject these via `get_it`.

---

### A3. Build out missing `startup/domain/` layer (CRITICAL — vertical slice violation)

`features/startup/` has only `data/datasources/` and `presentation/`. No `domain/entities/`, `domain/repositories/`, or `domain/usecases/` at all.

**What to create:**
```
features/startup/domain/
  entities/
    update_info.dart           ← move from presentation/notifiers
    startup_phase.dart
  repositories/
    i_startup_repository.dart
    i_update_repository.dart
  usecases/
    run_startup_sequence.dart
    watch_update_available.dart
    download_update.dart
```

**Then fix:**
- `lib/features/startup/data/datasources/update_remote_datasource.dart:9` — currently imports presentation `UpdateNotifier`. The notifier should become a presentation-side wrapper around `WatchUpdateAvailableUseCase` returning a `Stream<UpdateInfo?>`.
- `lib/features/about/presentation/blocs/about_bloc.dart:5` — replace `UpdateNotifier.instance.value` with the use-case
- `lib/features/translation/presentation/screens/components/translation_header.dart:9` — same
- `lib/features/shell/presentation/widgets/shell_overlay.dart:3` — same
- `lib/features/about/data/repositories/update_repository.dart:3` — currently imports `startup/data/datasources/update_remote_datasource.dart` (data → data cross-feature). Should depend on `IUpdateRepository` interface from `startup/domain/`.

---

### A4. Split `TranslationBloc` (834 lines) into use-cases (MAJOR)

`lib/features/translation/presentation/blocs/translation_bloc.dart` — 834 lines with embedded business logic. BLoCs should orchestrate, not contain logic.

**Extract these into use-cases under `translation/domain/usecases/`:**
- `CheckQuotaBeforeStartUseCase` — currently inlined in `_onToggleRunning` (lines 250-276)
- `SwitchEngineFallbackUseCase` — currently inlined as fallback engine switching logic
- `HandleAuthStateChangeUseCase` — currently in `_onAuthChanged` (lines 133-149)
- `InitializeTranslationSessionUseCase` — currently in `_onInitialize` (lines 102-131)
- `MonitorModelStatusUseCase` — model status orchestration scattered through event handlers

After extraction, the BLoC should be ~200-300 lines: only event→use-case→state mapping.

---

### A5. Remove `data/` → `data/` cross-feature imports (CRITICAL)

| File | Currently imports | Fix |
|---|---|---|
| `lib/features/settings/data/repositories/audio_device_repository_impl.dart:2` | `translation/data/datasources/asr_websocket_datasource.dart` | Settings should not know about ASR transport. Either move shared audio device code to `core/`, or expose via `translation/domain` interface |
| ~~`lib/features/translation/data/repositories/translation_repository_impl.dart:4`~~ | ~~`subscription/data/datasources/...`~~ | ✅ Fixed in A1 — now injects `ISubscriptionRepository` |
| `lib/features/startup/data/datasources/startup_remote_datasource.dart:5-6` | `subscription/data/...` and `translation/data/...` | Inject `ISubscriptionRepository` + `ITranscriptionRepository` interfaces |

---

### A6. Remove `data/` → `presentation/` imports (CRITICAL)

| File | Issue | Fix |
|---|---|---|
| `lib/features/startup/data/datasources/update_remote_datasource.dart:9` | Writes to `UpdateNotifier` (presentation) | Datasource should return data, not push to a notifier. Move notifier-update to a use-case in domain that the presentation listens to |
| `lib/features/usage/data/models/engine_usage_dto.dart:2` | Calls `SubscriptionRemoteDataSource.instance.getModelType(engine)` from a DTO | DTO should be pure data. Move `getModelType` resolution to a use-case that wraps the DTO mapping |

---

### A7. Remove presentation imports from domain layer (CRITICAL)

`lib/features/usage/domain/usecases/get_usage_stats.dart:4` imports `usage/presentation/widgets/usage_utils.dart` and calls `UsageUtils.getDisplayName(s.engine, s.type)` at line 60.

**Fix:** `getDisplayName` is domain logic (mapping engine → display name). Move to `usage/domain/services/usage_display_resolver.dart` or directly into the entity. Presentation can keep using it from there if needed.

---

### A8. Audit `get_it` registration completeness

After A1–A7, re-check `lib/core/di/parts/` to ensure every repository interface and use-case is registered, and there are no manual `Foo.instance` accesses remaining outside of declared singletons in `core/`.

**Search to run after refactor:**
```bash
grep -rn "SubscriptionRemoteDataSource\.instance" lib/ --include="*.dart"
```
**Status after A1:** Zero matches in `lib/features/`. Remaining `.instance` usages in `lib/features/` are legitimate DI registrations in `datasource_di.dart` (registering the singleton into `get_it`) and two debug-only admin methods guarded by `kDebugMode`.

Re-run this audit after A2–A7 complete.

---

### Suggested order of operations

1. ~~**A1** (subscription singleton)~~ ✅ **DONE** — all callsites eliminated, `flutter analyze` clean
2. **A3** (startup domain) — adds missing layer, unblocks A6
3. **A2** (auth singleton) — small surface, quick win
4. **A5/A6** (data ↔ data, data ↔ presentation) — `translation_repository_impl.dart` already resolved by A1; remaining: `settings/audio_device_repository_impl.dart`, `startup/startup_remote_datasource.dart`, `update_remote_datasource.dart`
5. **A7** (domain → presentation) — single file, easy
6. **A4** (TranslationBloc split) — largest refactor but isolated to one feature
7. **A8** (DI audit) — verification step

---

## DESIGN SYSTEM — follow-up after shipping `DESIGN.md`

`DESIGN.md` at the repo root now mirrors `lib/core/theme/app_theme.dart` and captures motion, iconography, components, and the 27 s demo-video spec. A pointer exists in `CLAUDE.md` so future Claude sessions read it before generating UI. These are follow-ups to validate and leverage it.

### D1. Test-drive the design system end-to-end

**What:** Paste `DESIGN.md` into Claude or Google Stitch with a prompt for a *new* screen (e.g. "generate a first-run onboarding step explaining microphone permissions"). Compare output against the existing app.

**Why:** The real test of the spec is whether an AI agent that's never seen the app produces on-brand UI. If it doesn't, the failing section is too vague and needs tightening.

**Exit criterion:** One generation pass produces correct palette, typography, motion, and component choices — no manual correction of hex values or easing names needed.

---

### D2. Export the demo HTML to an actual video file

**What:** The demo (`design_export/Omni Bridge Demo.html`) is a 27 s HTML animation that's unusable on LinkedIn until it's rendered to MP4. Write a Puppeteer + ffmpeg script that:

1. Loads the HTML at 1200 × 750
2. Scrubs the timeline from 0 → 27 s at 60 fps (via a `?t=` param or `postMessage` seek)
3. Captures each frame as PNG
4. Pipes the frames to ffmpeg with `-c:v libx264 -pix_fmt yuv420p -r 60` to produce:
   - `omni_bridge_demo.mp4` — 1920 × 1080 (upscaled)
   - `omni_bridge_demo_square.mp4` — 1080 × 1080 centered crop
   - `omni_bridge_demo.gif` — 600 × 375 at 20 fps, `-loop 0`, target ≤ 8 MB

**Where it goes:** `design_export/export/` (gitignored large binaries, keep the script committed at `design_export/convert_video.js` or similar).

**Why:** §9.8 of `DESIGN.md` promises these outputs — they need to actually exist before the LinkedIn post goes live.

---

### D3. Commit a poster frame alongside `DESIGN.md`

**What:** Capture the demo at `t = 2.2 s` (logo + tagline reveal — the moment defined in §9.8 of `DESIGN.md`) and save as `docs/06_tools/design_poster.png` at 1920 × 1080. Reference it from `DESIGN.md` as the visual ground-truth snapshot.

**Why:** The spec is 1300+ lines of text. A single PNG tells a human reader "yes, the colors and motion I'm describing look like this." Cheap insurance against the spec drifting into fiction.

---

### D4. Add a theme-drift check

**What:** A ~20-line Dart test or Python script that parses `lib/core/theme/app_theme.dart` and verifies every hex value declared as a `const` in `AppColors` / `UsageColors` also appears somewhere in `DESIGN.md`. Fail CI if the two diverge.

**Suggested location:** `test/design/theme_drift_test.dart`

**Sketch:**
```dart
test('every AppColors hex appears in DESIGN.md', () async {
  final theme = File('lib/core/theme/app_theme.dart').readAsStringSync();
  final design = File('DESIGN.md').readAsStringSync().toLowerCase();
  final hexes = RegExp(r'0xFF([0-9A-Fa-f]{6})').allMatches(theme)
      .map((m) => '#${m.group(1)!.toLowerCase()}').toSet();
  final missing = hexes.where((h) => !design.contains(h)).toList();
  expect(missing, isEmpty, reason: 'Hexes in app_theme.dart but not in DESIGN.md: $missing');
});
```

**Why:** Someone will change `AppColors` and forget to update `DESIGN.md`. The spec will rot silently — this catches it at CI time.

---

## LOW — Polish / post-launch

### 18. Switch Razorpay to Live Mode Before Public Launch

See [Going Live](../04_features/16_monetization_plan.md#going-live-test--production) in the monetization doc for the full step-by-step. Summary:

1. Create live Razorpay plans (same amounts as test)
2. Rotate `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` Firebase secrets to live values
3. Update webhook secret in Razorpay Dashboard (Live Mode)
4. `firebase deploy --only functions`
5. Update `plan_ids` in `admin_panel.dart` seed data with live plan IDs → Seed System Config in app

> The `function_urls` and webhook URL do not change between test and production.

---

### 15. Compile Inno Setup Installer
**What:** Once both the server and Flutter app are rebuilt, compile the installer.

**Steps:**
1. Confirm `server/dist/omni_bridge_server.exe` exists (freshly built, obfuscated)
2. Confirm `build/windows/x64/runner/Release/omni_bridge.exe` exists (freshly built, `2.0.0+2`)
3. Open `installer_setup.iss` in Inno Setup 6.7.1 and Build → Compile
4. Output: `installers/OmniBridge_Setup_v2.0.0.exe`
5. Test on a clean VM before publishing — verify first install, upgrade, and uninstall

**Installer is production-ready** — all known issues resolved:
- User stays signed in across updates (`WipeUserData` skipped when `IsUpgrade()` is true)
- Whisper/AI models survive updates (`BackupModels` → `[InstallDelete]` → `RestoreModels`)
- PyInstaller `%TEMP%` dirs cleaned on both install and uninstall
- Server kill-on-close fixed (`setPreventClose(true)` + always `taskkill` by name)

See [11 GitHub Releases Guide](../03_guides/11_github_releases_guide.md) for the full publish flow.

---

### 16. Graceful Riva Import Fallback
**Files:** `server/src/models/asr/riva_asr.py:7` · `server/src/models/translation/riva_nmt.py:7`

Both files have `import riva.client` at module top-level. If the riva package is not available (e.g., non-GPU build), the import failure crashes the entire server on startup rather than just disabling Riva engines.

**Fix:** Wrap with try/except:
```python
try:
    import riva.client  # type: ignore[import]
    RIVA_AVAILABLE = True
except ImportError:
    RIVA_AVAILABLE = False
```
Then guard class instantiation / method bodies with `if not RIVA_AVAILABLE: raise RuntimeError("Riva not available")`.

---

### 14. Remove Debug Tier Panel Before Release
**What:** A `_DebugTierPanel` widget is rendered at the bottom of `SubscriptionScreen` behind a `kDebugMode` guard. It must be removed (or the whole block deleted) before shipping a release build — while it won't appear in release mode, the dead code and debug methods should be cleaned up.

**Files to clean up:**

| File | What to remove |
|---|---|
| `lib/features/subscription/presentation/screens/subscription_screen.dart` | `import 'package:flutter/foundation.dart'` · `import '...subscription_remote_datasource.dart'` · `if (kDebugMode) _DebugTierPanel()` line · entire `_DebugTierPanel` class |
| `lib/features/subscription/data/datasources/subscription_remote_datasource.dart` | `setTierDebug()` · `activateExpiredTrialDebug()` · `resetTrialDebug()` · `activateFreshTrialDebug()` |

**Debug methods summary (for reference):**
- `setTierDebug(tier)` — writes `tier` field directly to the user doc (bypasses all checks). Non-trial tiers only; trial button uses `activateFreshTrialDebug()` instead.
- `activateFreshTrialDebug()` — sets `tier: 'trial'` with a proper future `trialExpiresAt` (reads `trial_duration_hours` from `system/monetization → tiers → trial`). Bypasses the `trial_used` guard.
- `activateExpiredTrialDebug()` — sets `tier: 'trial'` with `trialExpiresAt` 1 minute in the past. Triggers `_checkTrialExpiry` on next Firestore snapshot → auto-downgrades to free within ~2 s. Used to test the expiry flow without waiting a full day.
- `resetTrialDebug()` — clears `trial_used`, `trialExpiresAt`, `trialActivatedAt` so the trial can be re-activated via the normal flow.

**Why the `trial` button needs special handling:** `setTierDebug('trial')` without a `trialExpiresAt` causes `_checkTrialExpiry` to see `expiresAt == null` and immediately downgrade back to free. `activateFreshTrialDebug()` sets a valid future expiry to prevent this.

---

## Completed / Not Applicable

| Item | Status |
|---|---|
| **A1 — Eliminate `SubscriptionRemoteDataSource` singleton** | ✅ `ISubscriptionRepository` interface expanded to cover all 15+ callsites. New use-cases: `CancelSubscriptionUseCase`, `ResumeSubscriptionUseCase`. All presentation widgets, BLoCs, repositories, and core datasources now route through `sl<ISubscriptionRepository>()`. `flutter analyze` → zero issues. |
| Billing screen (`/billing`) | ✅ Full billing management UI: status card (plan badge, status pill, countdown chip, 30-day progress bar, member since, next billing, last payment + `pay_XXXXX` copy, subscription ID copy), `_PendingCancelCard` for cancelled-but-active state, `_HaltedCard`, `_CancelledCard`, upsell card. Payment history section reads `subscription_events` subcollection via `invoicesNotifier`. Back button in header. `BillingInfo` entity includes `lastPaymentId`, `isCancelPending` getter. `PaymentEvent` entity for history entries. |
| `cancelSubscription` Cloud Function | ✅ Authenticated HTTP endpoint. Verifies subscription belongs to caller before calling Razorpay `cancel_at_cycle_end: 1`. Optimistic UI update in datasource — billing screen shows pending-cancel state immediately without waiting for webhook. URL: `https://cancelsubscription-f3n57yyena-uc.a.run.app` |
| `resumeSubscription` Cloud Function | ✅ Authenticated HTTP endpoint. Reactivates a pending-cancel subscription via Razorpay `POST /v1/subscriptions/{id}/resume` with `{ resume_at: "now" }`. Same subscription, original billing schedule, no new subscription created. Writes `subscriptionStatus:'active'` to Firestore directly so UI updates without waiting for webhook. Optimistic update in datasource. URL: `https://resumesubscription-f3n57yyena-uc.a.run.app` |
| `subscription.cancelled` webhook fix | ✅ Previously treated same as `halted` (immediate downgrade). Now `handleSubscriptionCancelled()` sets `subscriptionStatus:'cancelled'` + `subscriptionEndedAt: entity.current_end` (real period end) — does NOT downgrade tier. Tier only drops when `subscription.completed` fires. Redeployed. |
| Webhook payment data completeness | ✅ `subscription.activated` now saves `lastPaymentId`, `lastPaymentAmountPaise`, `lastPaymentAt` to root doc and `paymentId`, `amountPaise` to event doc (first payment was previously unrecorded). `payment.captured` now also saves `lastPaymentAmountPaise` and `amountPaise` in event doc. All three charge events (`activated`, `charged`, `captured`) now write identical payment fields. |
| Razorpay subscription creation — programmatic flow | ✅ `createSubscription` Cloud Function (Gen 2, `us-central1`) creates a Razorpay subscription per user via API with `notes: {uid, tier}` baked in. Flutter `openCheckout()` calls the function with a Firebase ID token, gets back a unique `short_url`, opens it in the browser. No static payment links used — each customer gets their own subscription instance. |
| Razorpay webhook — all 7 events | ✅ `razorpayWebhook` Cloud Function handles `payment.captured`, `payment.failed`, `subscription.activated`, `subscription.charged`, `subscription.halted`, `subscription.cancelled`, `subscription.completed`. HMAC-SHA256 signature verified on every request. UID resolved via `notes.uid` (primary), `razorpaySubscriptionId` query (renewals), email lookup (fallback). |
| Payment pending state + failure detection | ✅ `_PlanCardState` implements `WidgetsBindingObserver`. On checkout: button shows "Awaiting Payment..." spinner, disabled. On app resume: 30s grace timer starts — if tier unchanged, orange SnackBar shown and state resets. If tier flips before timer fires, success. 10-minute hard timeout as final fallback. |
| Admin panel extracted to dedicated `/admin` route | ✅ `AdminScreen` (`lib/features/auth/presentation/screens/admin/admin_screen.dart`) wraps `AdminPanel` in `AppDashboardShell`. Registered as `/admin` in `AppRouter`. Admin tile appears in nav rail when `AppShellState.isAdmin == true`. Window correctly resizes on back — `AppRouter.admin` added to `MyNavigatorObserver.didPop` list. |
| `AppShellBloc` admin check — clean arch | ✅ `CheckAdminStatusUseCase → IAuthRepository.isAdmin → AuthRepositoryImpl → AuthRemoteDataSource.checkAdminStatus` chain. Bloc no longer imports datasource or firebase paths directly. |
| Firestore config — `plan_ids` + `function_urls` | ✅ `system/monetization` seeded with `plan_ids: {pro, enterprise}` (Razorpay plan IDs) and `function_urls.create_subscription`. Admin panel seed data updated. Static `payment_links` removed. |
| Account screen rewrite | ✅ Rewritten with inline `_ProfileHero` (avatar, name, email, provider badge), `_SectionLabel`, `_InfoRow`. Uses `AppColors` theme tokens. Admin panel removed from account screen (now at `/admin`). Orphaned component files (`account_avatar.dart`, `account_name_editor.dart`, `account_email_info.dart`) can be deleted. |
| Orphaned account components deleted | ✅ `account_avatar.dart`, `account_name_editor.dart`, `account_email_info.dart` deleted. No references remain. `flutter analyze` clean. |
| API keys / `.env` security | ✅ Already in `.gitignore`, keys are secure |
| GitHub Actions CI/release pipeline | ✅ Not using automated CI — manual release process |
| Firebase `system/monetization` seed | ✅ Seeded via admin panel (minor adjustments pending) |
| `forceLogout` listener | ✅ Fully implemented in `SessionRemoteDataSource` (`_userSub` + `_sessionSub`). On trigger: resets flag to `false`, then calls `AuthRemoteDataSource.signOut()` via injected callback — runs the full IResettable reset chain identically to manual logout. |
| Server-side quota enforcement | ✅ `SessionHandler` checks `quota_daily_used`/`quota_daily_limit` from `start` payload — refuses if exceeded. `wrap_callback` deducts chars per chunk and stops mid-session when `quota_remaining` hits 0, broadcasting `quota_exceeded`. Flutter passes live `QuotaStatus` fields on every start and stops `TranslationBloc` on `quota_exceeded` receipt. |
| Windows installer / PyInstaller build | ✅ `omni_bridge_server.spec` updated: correct module paths, `pyarmor_runtime_000000` now included in datas (was missing — would have caused runtime crash). Bare `except:` fixed in `ws_manager.py` and `asr_dispatcher.py`. Still needs: fresh rebuild + Inno Setup compile + clean VM test. |
| RTDB security rules | ✅ `database.rules.json` created: `users/$uid` read/write locked to authenticated owner. Added `database` key to `firebase.json`. Deployed to `omni-bridge-ai-translator-default-rtdb`. |
| Engine key mapping (EngineRegistry) | ✅ Complete |
| MyMemory disabled in settings | ✅ Works once DB is seeded |
| Retry count on WS disconnect UI | ⏭ Skipped — not needed |
| Firebase Auth token expiry | ✅ Firestore SDK auto-refreshes internally. RTDB REST client (`RTDBClient.request`) now detects 401/403 and calls `getIdToken(true)` so the next request (which re-fetches the URL via `getRTDBUrl`) carries a fresh token. |
| RTDBClient 401 without retry | ✅ `request()` now takes a `buildUrl` lambda alongside `makeRequest(client, url)`. On 401/403: force-refreshes token, calls `buildUrl()` again for a fresh-token URL, retries once. All 11 call sites updated to pass URL builders. |
| Google credentials logged at INFO | ✅ Downgraded two `logging.info` calls in `google_api_translation.py` to `logging.debug`. Removed credential key names and string prefix from the log messages. |
| `taskkill` no try-catch on first boot | ✅ Wrapped `Process.runSync('taskkill', ...)` in `startServer()` with `try/catch(_)`. |
| Audio meter exceptions swallowed | ✅ Moved `import logging` to module top. Inner read-loop `except Exception: break` now logs a warning before breaking. Redundant local `import logging` stmts in `_measure_loop` and `_resolve_device` removed. |
| `activeEngineFallbacks` ValueNotifier never disposed | ✅ Field changed from `final` to reassignable. `reset()` now calls `dispose()` then replaces it with a fresh `ValueNotifier<Set<String>>({})` — safe for logout/re-login on the singleton. |
| CORS `allow_origins=["*"]` on local server | ✅ Scoped to `["http://127.0.0.1", "http://localhost"]` in `flutter_server.py`. Server already binds to loopback only. |
| History panel free-tier hard-block | ✅ Removed `showUpgradeSheet()` `addPostFrameCallback` from `_HistoryPanelBodyState.initState()`. Free tier now renders only the `_TierGateView` with an inline "View Plans" button — no overlapping modal. Removed unused `upgrade_sheet.dart` import. |
| App update auto-download | ✅ `UpdateResult` and `UpdateNotifier` now carry `downloadUrl` (from `download_url` in Firestore `system/app_version`). `UpdateDownloadButton` widget streams the installer to `Directory.systemTemp`, shows a progress indicator, then launches it via `Process.start(..., detached)`. Falls back to opening `releaseUrl` in the browser if no direct URL is seeded. Used in both `AboutScreen` and `ForceUpdateScreen`. |
| WebSocket transport security | ✅ `flutter_server.py` always binds to `127.0.0.1` — loopback traffic never leaves the machine so `ws://` is correct. `ServerConfig` and `TranslationWebsocketClient` now auto-select `wss://`/`https://` if the host is ever changed to a non-loopback address. |
| Server restart recovery | ✅ `PythonServerManager` already had an `exitCode` listener for crash restarts. Gap fixed: `_checkHealthOnce()` in `TranslationBloc` now calls `PythonServerManager.startServer()` when the HTTP health check fails — covers the case where `_serverProcess` is null (externally-started server). Added `_isStarting` flag to guard against concurrent restart attempts from the 3-second health poll. |
| `whisper_suspended` dead code | ✅ Removed: flag was never set to `True` (Flutter never sent it, `base_handler.py` hardcoded `False`). Deleted `whisper_suspended` from `ASRDispatcher`, the guarded early-return in `process_chunk`, the `suspended` param from `start_stream`, `initial_suspension` from `get_server_context`, and the pass-through in `audio/handler.py`. |
| Trial expiry warning UI | ✅ Scoped down from banners/snackbars to a passive countdown timer. `QuotaStatus` now carries `trialExpiresAt: DateTime?` (populated from Firestore in `subscription_remote_datasource`). Usage screen and Plan screen both show "Xd Yh remaining" (amber, timer icon) when tier is `'trial'`. Formatter lives in `core/utils/duration_utils.dart`. |
| `_updateCurrentStatus()` does not preserve `monthlyResetAt` | ✅ `_updateCurrentStatus()` now accepts `monthlyResetAt` and forwards it from the Firestore snapshot, falling back to `_currentStatus?.monthlyResetAt`. `QuotaStatus.copyWith()` also gained the missing `monthlyResetAt?` param. |
| Trial auto-downgrade code bug + missing data | ✅ Added `return` after `_checkTrialExpiry()` in `_listenToUserDoc` — status now waits for the next Firestore snapshot (with `tier: 'free'`) instead of broadcasting stale trial data. Added `monthlyResetAt` to `activateTrial()` Firestore write so upgrade from trial to paid tier has a valid reset date. |
| Race condition — model unload on tier downgrade | ✅ `stopTranslationUseCase()` is now awaited before `unloadModelUseCase()` in the tier-downgrade path of `TranslationBloc`. Prevents model unload while audio streams are still draining. |
| `endSession()` errors swallowed on logout | ✅ `catch (_) {}` replaced with `catch (e) { AppLogger.e(...) }` in `AuthRemoteDataSource.signOut()`. Logout failures are now visible in logs. |
| Trial tier not updating when switching to trial | ✅ `_listenToUserDoc` was returning early after `_checkTrialExpiry()` even for valid (non-expired) trials. Fixed by inlining the expiry check — only `return` when trial is expired; valid trials fall through to `_updateCurrentStatus()`. |
| Debug tier switcher (subscription screen) | ✅ `_DebugTierPanel` added to `SubscriptionScreen` behind `kDebugMode`. Tier buttons use `SubscriptionRemoteDataSource.tierOrder` (dynamic from Firestore). Trial button calls `activateFreshTrialDebug()` (sets valid `trialExpiresAt`). Extra buttons: "Set trial → already expired" and "Reset trial". See item 14 for cleanup checklist. |
| Server rebuild (pyarmor_runtime_000000) | ✅ `omni_bridge_server.spec` updated to include `pyarmor_runtime_000000` in datas. Server rebuilt via `pyarmor gen --output dist_obfuscated . && pyinstaller omni_bridge_server.spec`. |
| Flutter app rebuild (`2.0.0+2`) | ✅ Rebuilt with `flutter build windows --release`. Includes: trial tier fix, per-engine cap enforcement, parallel startup, navigation/window transition fixes, usage screen cache + parallel load, refresh button, `ClearUsageCache` use-case, account screen shell. |
| Per-engine monthly cap enforcement not implemented | ✅ `EngineLimitReachedEvent` was defined and handled in `TranslationBloc` but never fired. Fixed: `UsageRemoteDataSource` now checks `_engineMonthlyUsages` against `engineMonthlyLimit` (via `EngineRegistry` stats→settings key translation) on every poll. First breach emits the settings key on `engineLimitStream`. `TranslationBloc._engineLimitSub` subscribes and dispatches `EngineLimitReachedEvent` — first time stops translation and shows the engine-limit dialog; subsequent calls silently fall back to Google. `_engineLimitFired` set prevents duplicate events per session; cleared on `reset()`. |
| `subscription_monthly_models` seed doc had `"riva"` instead of `"riva-asr"`/`"riva-nmt"` | ✅ Fixed model IDs in `07_database_schema.md` and `16_monetization_plan.md`. Admin panel seed code (`admin_panel.dart`) was already correct — docs were stale. |
