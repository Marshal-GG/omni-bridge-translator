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
3. Test checkout flow end-to-end: tap Upgrade → Razorpay opens → payment → tier updates in Firestore

---

---

---

## HIGH — Fix before first real user

### 4. History Panel — Free Tier Hard-Block
**File:** `lib/features/history/presentation/screens/history/history_panel.dart`

**What:** Free tier users trigger `showUpgradeSheet()` from `initState()` which shows a modal over a duplicate "History Unavailable" empty state — two overlapping UX flows. Should show only the gated empty state with an inline upgrade prompt.

**Fix:** Remove the `showUpgradeSheet()` `addPostFrameCallback` and let the existing gated view render naturally.

---

---

---

## MEDIUM — Before scaling up users

### 7. `_updateCurrentStatus()` Does Not Preserve `monthlyResetAt`
**File:** `lib/features/subscription/data/datasources/subscription_remote_datasource.dart`

**What:** Every status broadcast constructs a fresh `QuotaStatus` without forwarding the existing `monthlyResetAt`. Paid tier users lose their reset date on every Firestore snapshot.

**Fix:** Pass `monthlyResetAt: _currentStatus?.monthlyResetAt` in the `QuotaStatus(...)` constructor inside `_updateCurrentStatus()`. Also read it from the Firestore snapshot when available.

---



## LOW — Polish / post-launch

### 12. App Update Auto-Download
**What:** Update check reads `system/app_version` from Firestore and shows a prompt, but users must manually open GitHub releases to download. No in-app download.

**Consideration:** Acceptable for v1 — manual download is standard for desktop apps.

---

### 13. Account Name Editor Size
**File:** `lib/features/auth/presentation/screens/account/components/account_name_editor.dart:41`

`// TODO: Refine size, currently perceived as too big compared to TextField` — cosmetic fix.

---

### 14. `activeEngineFallbacks` `ValueNotifier` Never Disposed
**File:** `lib/features/subscription/data/datasources/subscription_remote_datasource.dart`

**What:** `activeEngineFallbacks = ValueNotifier<Set<String>>({})` is never disposed on logout. Low risk but violates lifecycle discipline.

**Fix:** Add `activeEngineFallbacks.dispose()` to `reset()`.

---

### 15. CORS `allow_origins=["*"]` on Local Server
**File:** `server/flutter_server.py`

**What:** Server binds to `127.0.0.1` so wildcard CORS is safe in practice, but bad practice.

**Fix:** Scope to loopback:
```python
allow_origins=["http://127.0.0.1", "http://localhost"],
```

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
| WebSocket transport security | ✅ `flutter_server.py` always binds to `127.0.0.1` — loopback traffic never leaves the machine so `ws://` is correct. `ServerConfig` and `TranslationWebsocketClient` now auto-select `wss://`/`https://` if the host is ever changed to a non-loopback address. |
| Server restart recovery | ✅ `PythonServerManager` already had an `exitCode` listener for crash restarts. Gap fixed: `_checkHealthOnce()` in `TranslationBloc` now calls `PythonServerManager.startServer()` when the HTTP health check fails — covers the case where `_serverProcess` is null (externally-started server). Added `_isStarting` flag to guard against concurrent restart attempts from the 3-second health poll. |
| `whisper_suspended` dead code | ✅ Removed: flag was never set to `True` (Flutter never sent it, `base_handler.py` hardcoded `False`). Deleted `whisper_suspended` from `ASRDispatcher`, the guarded early-return in `process_chunk`, the `suspended` param from `start_stream`, `initial_suspension` from `get_server_context`, and the pass-through in `audio/handler.py`. |
| Trial expiry warning UI | ✅ Scoped down from banners/snackbars to a passive countdown timer. `QuotaStatus` now carries `trialExpiresAt: DateTime?` (populated from Firestore in `subscription_remote_datasource`). Usage screen and Plan screen both show "Xd Yh remaining" (amber, timer icon) when tier is `'trial'`. Formatter lives in `core/utils/duration_utils.dart`. |
| `QuotaStatus.copyWith()` missing `monthlyResetAt` | ✅ Added `monthlyResetAt?` param to `copyWith()`. `_updateCurrentStatus()` now accepts and forwards `monthlyResetAt` from the Firestore snapshot, falling back to the preserved value on `_currentStatus`. |
| Trial auto-downgrade code bug + missing data | ✅ Added `return` after `_checkTrialExpiry()` in `_listenToUserDoc` — status now waits for the next Firestore snapshot (with `tier: 'free'`) instead of broadcasting stale trial data. Added `monthlyResetAt` to `activateTrial()` Firestore write so upgrade from trial to paid tier has a valid reset date. |
| Race condition — model unload on tier downgrade | ✅ `stopTranslationUseCase()` is now awaited before `unloadModelUseCase()` in the tier-downgrade path of `TranslationBloc`. Prevents model unload while audio streams are still draining. |
| `endSession()` errors swallowed on logout | ✅ `catch (_) {}` replaced with `catch (e) { AppLogger.e(...) }` in `AuthRemoteDataSource.signOut()`. Logout failures are now visible in logs. |
