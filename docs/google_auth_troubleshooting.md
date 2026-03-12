# Google OAuth 2.0 Setup & Troubleshooting for Windows

This document explains the technical implementation of Google Sign-In for Omni Bridge and provides troubleshooting steps for OAuth 2.0 policy compliance and deep linking issues.

## Technical Implementation Overview

### 1. Redirect URI Strategy
To comply with Google's strict OAuth 2.0 policies for desktop apps, we use a **Custom URL Scheme** redirect.
- **Client Type:** iOS (This is recommended by Google for Desktop/Native apps to enable custom schemes).
- **Redirect URI Format:** `com.googleusercontent.apps.CLIENT_ID:/oauth2redirect` (Note the single slash `:/`).

### 2. Deep Link Handling
The app uses `windows_single_instance` to ensure that when the browser redirects back to the app, the arguments are passed to the *already running* instance rather than opening a second window.
- **Argument Scanning:** `main.dart` scans all startup arguments to find the URI.
- **Protocol Registration:** The installer (`installer_setup.iss`) registers two protocols in the Windows Registry (HKCR):
    1. `omni-bridge`
    2. The reversed Google Client ID (e.g., `com.googleusercontent.apps.XXX`).

---

## Setup Guide (If credentials change)

If you need to update the Google Client ID:
1.  **GCP Console:** Go to the [Google Cloud Console](https://console.cloud.google.com/).
2.  **Create Credential:** Create an **OAuth 2.0 Client ID** with the application type **iOS**.
3.  **Update .env:** Copy the Client ID into your `.env` file:
    ```env
    GOOGLE_CLIENT_ID=your_id_here.apps.googleusercontent.com
    ```
4.  **Update Installer:** Update the `installer_setup.iss` registry section to match the new reversed ID.

---

## Troubleshooting "Redirection Not Working"

If the browser signs in but the app doesn't react:

### 1. Check Protocol Registration
The browser relies on Windows knowing which app handles the `com.google...` scheme.
- **Manual Fix:** Run the app once. It attempts to register the protocol programmatically using `protocol_handler`.
- **Registry Check:** Open `regedit` and look for `HKEY_CLASSES_ROOT\com.googleusercontent.apps.<YOUR_ID>`. It should point to `omni_bridge.exe`.

### 2. "Error 400: invalid_request"
This usually means the `redirect_uri` sent by the app doesn't *exactly* match what Google expects.
- **Solution:** Ensure `AuthService.dart` is building the URI with a **single slash** after the colon (`scheme:/oauth2redirect`). Google's policy for desktop/iOS clients treats `://` as a potential security risk or mismatch.
- **Note:** The Google Client ID must be of type **iOS**, not "Web" or "Desktop", to properly support custom URI scheme redirects on Windows securely.

### 3. App Opens a Second Window Instead of Logging In
This happens if `WindowsSingleInstance` fails to communicate.
- **Solution:** Ensure the "Pipe Name" in `main.dart` (`omni_bridge_translator_instance`) is unique and consistent. Check for hidden background processes of the app and close them.

### 4. "Pipe create failed" / Logs completely missing after redirect
If you see `Pipe create failed` in the terminal or if the `[Auth]` logs don't show up at all when the browser redirects:
- **Cause:** This usually happens when you **Hot Restart** the Flutter debugger, or if the app previously crashed and left a background process running. The `windows_single_instance` named pipe isn't cleaned up, so the new instance fails to connect to it, and args are sent into the void.
- **Solution:** Completely stop the debug session. Check Task Manager for ghost `omni_bridge.exe` background processes. Then start a fresh **Cold Start** debug session (F5).

### 5. Code Extraction Failure
If the app receives the link but fails to log in, it might be unable to "find" the `code` parameter.
- **Solution:** Check the terminal logs. `AuthService` now includes a regex fallback to find `code=` in the raw string even if the URI parser fails.
### 6. "firebase_auth/unknown-error" in Debug Mode
This error often occurs when the app is initialized with one set of project credentials but attempts to authenticate against another project's OAuth client.
- **Cause**: The `DefaultFirebaseOptions.debug` configuration used placeholder values (like `omni-bridge-test`) while the `AuthService` was sending a credential for the production project (`omni-bridge-ai-translator`).
- **Solution**: Ensure that `lib/firebase_options.dart` has identical `apiKey`, `appId`, and `projectId` in both `debug` and `release` configurations if you are using the same Firebase project for both. 
- **Wait, what about Session Isolation?**: You can still maintain local session isolation by using uniquely named Firebase Apps (e.g., `OmniBridge-Debug`) in `Firebase.initializeApp()`, even if they point to the same cloud project. This prevents the debugger from overwriting the installed app's local storage.
