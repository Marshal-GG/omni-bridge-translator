# 11 — GitHub Releases Guide

This guide explains how to build the Windows executable and publish it as a GitHub Release so the built-in update checker can detect new versions.

## Step 1: Build the Executable

Run the following command in your terminal to create a release build:

```powershell
flutter build windows --release
```

The build artifacts will be located at:
`build\windows\x64\runner\Release\`

## Step 2: Package the Application

The executable (`omni_bridge.exe`) requires several DLLs and the `data` folder to run. You must package the **entire contents** of the `Release` folder.

1. Navigate to `build\windows\x64\runner\`.
2. Right-click the `Release` folder and select **Compress to ZIP file**.
3. Rename the resulting zip to something descriptive, e.g., `omni_bridge_v1.2.3_windows.zip`.

## Step 3: Create a GitHub Release

1. Go to your GitHub repository: [Marshal-GG/omni-bridge-translator](https://github.com/Marshal-GG/omni-bridge-translator).
2. On the right sidebar, click **Releases** -> **Create a new release** (or "Draft a new release").
3. **Choose a tag**: Type the version number exactly as it appears in your `pubspec.yaml` (e.g., `v1.2.3`).
   - *Note: The update service expects the "v" prefix or a direct semver string.*
4. **Release title**: Give it a name, e.g., `Omni Bridge Release v1.2.3`.
5. **Describe this release**: Add a few bullet points about what changed.
6. **Attach binaries**: Drag and drop your ZIP file created in Step 2 into the "Attach binaries by dropping them here" area.
7. Click **Publish release**.

## How the Update Checker Works

The app's `UpdateRemoteDataSource` now checks a specific document in your Firebase **Cloud Firestore** database instead of hitting the GitHub API directly. This allows you to force critical updates and provide custom update messages without publishing a new release immediately.

### How to Configure Updates in the Database

To manage app versions, you do **not** need to add any new code. Follow these steps:

1. Open your **Firebase Console** and navigate to your project.
2. Go to **Cloud Firestore**.
3. Create a collection called `system` (if it doesn't exist).
4. Inside the `system` collection, create a document named exactly `app_version`.
5. Add the following **4 String fields** to the `app_version` document:

| Field Name | Type | Value (Example) | What it does |
| :--- | :--- | :--- | :--- |
| `min_supported` | String | `1.0.0` | If the user's app version is **lower** than this, they get permanently blocked on the **Force Update** screen. |
| `latest` | String | `1.1.0` | If the user's version is lower than this (but higher than `min_supported`), they get the **optional orange badge** on the settings icon. |
| `update_url` | String | `https://github.com/omni-bridge/releases` | The link that opens in their web browser when they click the "Download Update" button. |
| `force_update_message` | String | `A critical security patch is available.` | A custom message shown specifically on the Force Update screen explaining why they must update. |

Whenever you release a new version of Omni Bridge via GitHub Releases (Step 3), simply update the `latest` field in Firebase, and all online clients will immediately display the new update badge on their next launch! 

If you introduce a breaking change to the Python server requiring a client update, simply change `min_supported` to the new version, which will instantly force-block all outdated clients until they upgrade.
