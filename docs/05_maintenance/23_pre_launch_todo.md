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

## HIGH — Fix before first real user

### 3. Trial Auto-Downgrade — Verify and Test
**What:** `_checkTrialExpiry()` is called when tier is `'trial'`, but whether it actually writes `tier: 'free'` back to Firestore on expiry has not been end-to-end tested.

**Steps:**
1. Read `subscription_remote_datasource.dart` → find `_checkTrialExpiry()`
2. Confirm it writes `tier: 'free'` to `users/{uid}` when `trialExpiresAt` is in the past
3. Manual test: activate trial, set `trialExpiresAt` to 1 minute in the future, wait, verify auto-downgrade
4. Verify the UI reflects the tier change without requiring app restart

---

## MEDIUM — Before scaling up users

---

### 7. Trial Expiry Warning UI
**What:** Users get no warning that their trial is nearing expiry.

**What to implement:**
- Show a banner or snackbar when trial has less than 24 hours remaining
- Show another warning at 1 hour remaining
- Source: `SubscriptionStatus.trialExpiresAt` is already available

---

---

### 9. History Panel — Free Tier UX
**What:** Free tier users are blocked from history entirely (upgrade sheet shown immediately). Should show an empty state with an upgrade prompt instead of hard-blocking.

**File:** `lib/features/history/presentation/screens/history/history_panel.dart`

---

### 10. Server Restart Recovery — End-to-End Test
**What:** If the Python server crashes mid-session, Flutter reconnects with exponential backoff. This has not been tested end-to-end.

**Steps:**
1. Start a live translation session
2. Kill the Python server process externally
3. Verify Flutter shows "Reconnecting…" and retries
4. Restart the server, verify session resumes without requiring a manual restart of the app

---

## LOW — Polish / post-launch

### 11. App Update Auto-Download
**What:** Update check reads `system/app_version` from Firestore and shows a prompt, but users must manually open GitHub releases to download. No in-app download.

**Consideration:** Low priority for desktop app — manual download is acceptable for v1.

---

### 12. Remove Dead Code: `whisper_suspended` Flag
**File:** `server/src/asr/asr_dispatcher.py`

The `if self.whisper_suspended: return None, None` check exists but the flag is never set. Either implement the suspend/unload flow or remove the dead code.

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
| WebSocket transport security | ✅ `flutter_server.py` always binds to `127.0.0.1` — loopback traffic never leaves the machine so `ws://` is correct. `ServerConfig` and `TranslationWebsocketClient` now auto-select `wss://`/`https://` if the host is ever changed to a non-loopback address. |