# 23 — Pre-Launch TODO

Remaining work before Omni Bridge can be publicly launched. Items are ordered by priority within each section.

---

## BLOCKERS — Must complete before any public user

### 1. Razorpay Payment Links
**What:** `openCheckout()` reads payment links from Firestore `system/monetization → payment_links`. Currently empty — users cannot upgrade.

**Steps:**
1. Create Razorpay payment links for `pro` and `enterprise` tiers
2. Seed them into Firestore:
   ```json
   "payment_links": {
     "pro":        "https://razorpay.me/...",
     "enterprise": "https://razorpay.me/..."
   }
   ```
   > Trial is free — no payment link needed for it.
3. Test checkout flow end-to-end: tap Upgrade → Razorpay opens → payment → tier updates in Firestore

---

## LOW — Polish / post-launch

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

### 13. Account Name Editor Size
**File:** `lib/features/auth/presentation/screens/account/components/account_name_editor.dart:41`

`// TODO: Refine size, currently perceived as too big compared to TextField` — cosmetic fix.

---

## Completed / Not Applicable

| Item | Status |
|---|---|
| API keys / `.env` security | ✅ Already in `.gitignore`, keys are secure |
| GitHub Actions CI/release pipeline | ✅ Not using automated CI — manual release process |
| Firebase `system/monetization` seed | ✅ Seeded via admin panel (minor adjustments pending) |
| `forceLogout` listener | ✅ Fully implemented in `SessionRemoteDataSource` (`_userSub` + `_sessionSub`). On trigger: resets flag to `false`, then calls `AuthRemoteDataSource.signOut()` via injected callback — runs the full IResettable reset chain identically to manual logout. |
| Server-side quota enforcement | ✅ `SessionHandler` checks `quota_daily_used`/`quota_daily_limit` from `start` payload — refuses if exceeded. `wrap_callback` deducts chars per chunk and stops mid-session when `quota_remaining` hits 0, broadcasting `quota_exceeded`. Flutter passes live `QuotaStatus` fields on every start and stops `TranslationBloc` on `quota_exceeded` receipt. |
| Windows installer / PyInstaller build | ✅ `omni_bridge_server.spec` updated with correct module paths for current codebase. `pyinstaller omni_bridge_server.spec` produces `server/dist/omni_bridge_server.exe` (234 MB). Still needs: Inno Setup compile + clean VM test. |
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
| Per-engine monthly cap enforcement not implemented | ✅ `EngineLimitReachedEvent` was defined and handled in `TranslationBloc` but never fired. Fixed: `UsageRemoteDataSource` now checks `_engineMonthlyUsages` against `engineMonthlyLimit` (via `EngineRegistry` stats→settings key translation) on every poll. First breach emits the settings key on `engineLimitStream`. `TranslationBloc._engineLimitSub` subscribes and dispatches `EngineLimitReachedEvent` — first time stops translation and shows the engine-limit dialog; subsequent calls silently fall back to Google. `_engineLimitFired` set prevents duplicate events per session; cleared on `reset()`. |
| `subscription_monthly_models` seed doc had `"riva"` instead of `"riva-asr"`/`"riva-nmt"` | ✅ Fixed model IDs in `07_database_schema.md` and `16_monetization_plan.md`. Admin panel seed code (`admin_panel.dart`) was already correct — docs were stale. |
