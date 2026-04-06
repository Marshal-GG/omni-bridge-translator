# 23 — Pre-Launch TODO

Remaining work before Omni Bridge can be publicly launched. Items are ordered by priority within each section.

---

## BLOCKERS — Must complete before any public user

### 1. Windows Installer / PyInstaller Build
**What:** The installer (`installer_setup.iss`) requires `server/dist/omni_bridge_server.exe` to exist. This is produced by running `pyinstaller omni_bridge_server.spec` inside `/server`. It is not automated.

**Steps:**
1. `cd server && pyinstaller omni_bridge_server.spec`
2. Verify `server/dist/omni_bridge_server.exe` exists and runs standalone
3. Run the Inno Setup compiler against `installer_setup.iss`
4. Test full install/uninstall on a clean Windows 10/11 VM
5. Verify Python server auto-starts and auto-restarts on crash after install

---

### 2. Razorpay Payment Links
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

### 3. Server-Side Quota Enforcement
**What:** The Python server never checks quotas. It will translate indefinitely even if a user is over their daily/monthly limit. Client-side enforcement is easily bypassed.

**File:** `server/src/pipeline/orchestrator.py` or `server/src/network/handlers/session_handler.py`

**What to implement:**
- On `start` command, server reads user's current quota from RTDB `users/{uid}/daily_usage/{today}/tokens`
- Compares against the tier's `daily_tokens` limit from Firestore `system/monetization`
- If exceeded, returns error and refuses to start the session
- Optionally check again mid-session at a configurable interval

---

### 4. Trial Auto-Downgrade — Verify and Test
**What:** `_checkTrialExpiry()` is called when tier is `'trial'`, but whether it actually writes `tier: 'free'` back to Firestore on expiry has not been end-to-end tested.

**Steps:**
1. Read `subscription_remote_datasource.dart` → find `_checkTrialExpiry()`
2. Confirm it writes `tier: 'free'` to `users/{uid}` when `trialExpiresAt` is in the past
3. Manual test: activate trial, set `trialExpiresAt` to 1 minute in the future, wait, verify auto-downgrade
4. Verify the UI reflects the tier change without requiring app restart

---

## MEDIUM — Before scaling up users

### 6. Firebase Auth Token Expiry Handling
**What:** If a session runs long enough for the Firebase ID token to expire, Firestore/RTDB writes fail silently. No token refresh is currently implemented.

**What to implement:**
- Ensure `FirebaseAuth.instance.currentUser?.getIdToken(true)` (force refresh) is called when a 401/permission denied is returned from Firestore or RTDB
- Or rely on Firebase SDK auto-refresh — verify this is happening correctly in the current auth flow

---

### 7. Trial Expiry Warning UI
**What:** Users get no warning that their trial is nearing expiry.

**What to implement:**
- Show a banner or snackbar when trial has less than 24 hours remaining
- Show another warning at 1 hour remaining
- Source: `SubscriptionStatus.trialExpiresAt` is already available

---

### 8. WebSocket Transport Security
**What:** The NVIDIA API key is transmitted over the WebSocket from Flutter to the Python server. Ensure the connection uses `wss://` (TLS) in production, not `ws://`.

**File:** `lib/core/config/server_config.dart` or wherever the WebSocket URL is built

**Steps:**
1. Confirm the WebSocket URL scheme in the config
2. Ensure the Python server's `flutter_server.py` supports TLS when deployed outside localhost
3. Document the expected transport configuration

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
| Engine key mapping (EngineRegistry) | ✅ Complete |
| MyMemory disabled in settings | ✅ Works once DB is seeded |
| Retry count on WS disconnect UI | ⏭ Skipped — not needed |