# Omni Bridge: Comprehensive Isolation & Cleanup Technical Guide

This document provides a detailed technical overview of how Omni Bridge maintains separate environments for **Development (Debug)** and **Production (Release)**.

---

## 1. Environment Isolation Deep-Dive

To prevent "Session Bleed" (where logging into one version affects the other), we have decoupled four critical layers of the Windows application.

### A. Persistent Storage & Folder Isolation
**Location**: `windows/runner/Runner.rc`
**Mechanism**: Windows determines the storage paths for `shared_preferences`, localized databases, and Firebase caches based on the `ProductName` field in the application resources.
- **Release Name**: `Omni Bridge: Live AI Translator`
- **Debug Name**: `Omni Bridge: Live AI Translator (Debug)`
- **Path Separation**:
  - Release Data: `%LOCALAPPDATA%\Marshal-GG\Omni Bridge_ Live AI Translator`
  - Debug Data: `%LOCALAPPDATA%\Marshal-GG\Omni Bridge_ Live AI Translator (Debug)`

### B. Windows Application Identity (AUMID)
**Location**: `windows/runner/main.cpp`
**Mechanism**: We use `SetCurrentProcessExplicitAppUserModelID` to tell Windows that these are different apps for taskbar grouping and notification management.
- **Debug ID**: `Marshal.OmniBridge.Debug`
- **Release ID**: `Marshal.OmniBridge.Release`
- **Why it matters**: This prevents Windows from "merging" the two apps in the taskbar and ensures that toast notifications or deep link activations are routed correctly to the specific process.

### C. Single-Instance Logic
**Location**: `lib/core/app_initializer.dart`
**Mechanism**: The `windows_single_instance` package uses a global named Mutex/Pipe to prevent multiple launches.
- **Logic**: Use `kDebugMode` to toggle the instance ID string.
  - `omni_bridge_translator_instance_debug`
  - `omni_bridge_translator_instance`
- **Result**: You can run both the Debug version and the Installed version simultaneously without one "swallowing" the other's launch request.

### D. Deep Link & OAuth Isolation
**Location**: `lib/core/services/firebase/auth_service.dart` and `app_initializer.dart`
**Mechanism**: Google Sign-In relies on a "Custom URI Scheme" redirect.
- **Debug Protocol**: `omni-bridge-debug://auth`
- **Release Protocol**: `omni-bridge://auth`
- **Isolation Fix**: When you click "Sign in with Google" in the Debug app, the browser now knows specifically to look for `omni-bridge-debug://`. This prevents the "Production" app from accidentally hijacking the login credentials if it was already open.

### E. Named Firebase App Isolation (Session Separation)
**Location**: `app_initializer.dart` and Firebase Services
**Mechanism**: We use Named Firebase Apps (`OmniBridge-Debug` and `OmniBridge-Release`) instead of the default singleton.
- **Why it matters**: Firebase's default app uses a shared persistent data store for authentication and Firestore caching. By using a named app, Firebase creates completely isolated storage for each build mode.
- **Implementation**:
  - `AuthService`, `TrackingService`, and `SubscriptionService` all use `FirebaseAuth.instanceFor(app: ...)` and `FirebaseFirestore.instanceFor(app: ...)` referencing the mode-specific app name.
  - This ensures that logging in as User A in Debug DOES NOT affect the Release version, even if they share the same OS-level product name (though they don't).

## The Two-App Strategy

To ensure absolute cache isolation between the Development (Debug) environment and the Production (Release) environment, Omni Bridge uses two distinct Firebase Project IDs:

- **Debug**: `omni-bridge-test`
- **Release**: `omni-bridge-prod`

This strategy prevents the "Permission Denied" errors that occur when a single Firebase project's local cache is accessed by two differently signed executables.

### Implementation Details

1.  **Dynamic Initialization**: `AppInitializer` detects the build mode (`kDebugMode`) and selects the appropriate `FirebaseOptions`.
2.  **Isolated Storage**: The Firebase SDK creates separate cache directories based on the App ID/Project ID, ensuring no overlap.
3.  **Cleanup**: The `clear_app_data.ps1` script is configured to respect these boundaries, only targeting the relevant environment's cache when needed.

---

## 2. Advanced Data Cleanup Utility

The cleanup suite is designed to "factory reset" the app state when something gets corrupted or when you need to switch accounts cleanly.

### The PowerShell Engine (`scripts/clear_app_data.ps1`)
The core logic performs several "deep cleans" that standard uninstallers might miss:

1.  **Process Termination**: Automatically kills any running `omni_bridge.exe` or `dart.exe` processes to release file locks.
2.  **Character Substitution**: Windows folder names often replace colons (`:`) with underscores (`_`). The script is programmed to handle the mapping of `Omni Bridge: (Debug)` to `Omni_Bridge_ (Debug)` accurately.
3.  **Firebase Specialist Cleaning**:
    - **Auth Tokens**: Clears `%LOCALAPPDATA%\google-services-desktop-auth`
    - **Firestore Cache**: Clears `%LOCALAPPDATA%\firestore`
    - **Telemetry**: Clears `%LOCALAPPDATA%\firebase-heartbeat`
4.  **Registry Purge**: Deletes `HKCU\Software\Marshal-GG\omni_bridge` which stores window state and some persistent settings.

### How to Use the Utility
1.  **Run `scripts/clear_app_data.cmd`**: This is a simple batch wrapper that handles the PowerShell execution policy.
2.  **Select Your Target**:
    - **[1] Debug Only**: Resets your development environment. **Preserves your Installed session.**
    - **[2] Installed Only**: Resets the production app. **Preserves your Debug session.**
    - **[3] Both**: Full system wipe, including shared login tokens.

> [!NOTE]
> Thanks to the **Named Firebase App** implementation, debug and release versions no longer share login sessions. Modern cleaning (Option 1 or 2) is now even more targeted as tokens are stored in mode-specific sub-folders by Firebase.

> [!IMPORTANT]
> **Safety for Other Projects**: The script now strictly avoids touching root Firebase folders (e.g., `%LOCALAPPDATA%\firestore`). It only targets the isolated `OmniBridge-Debug` and `OmniBridge-Release` subfolders. This ensures that resetting Omni Bridge will **never** log you out of other Firebase-based applications on your system.

---

## 3. Verification Checklist

To confirm isolation is working as expected, perform these steps:

1.  **Run Debug**: Log in with User A.
2.  **Open Installed App**: Verify it asks for a login (it should not see User A).
3.  **Log in Installed**: Log in with User B.
4.  **Switch Back**: Verify the Debug app still sees User A. 
5.  **Check Taskbar**: You should see two different icons/positions if both are pinned separately.
