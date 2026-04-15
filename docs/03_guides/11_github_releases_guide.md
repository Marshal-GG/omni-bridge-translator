# 11 — GitHub Releases Guide

How to build, package, and publish a new Omni Bridge release.

---

## Step 1: Bump the version

Update the version in two places:

| File | Field | Example |
|---|---|---|
| `pubspec.yaml` | `version:` | `2.0.1+3` |
| `installer_setup.iss` | `#define MyAppVersion` + `VersionInfoVersion` | `2.0.1` / `2.0.1.0` |

---

## Step 2: Build the Python server

```powershell
cd server
..\.venv\Scripts\activate
pyarmor gen --output dist_obfuscated .
pyinstaller omni_bridge_server.spec
```

Output: `server/dist/omni_bridge_server.exe`

---

## Step 3: Build the Flutter app

```powershell
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\`

---

## Step 4: Compile the installer

1. Open `installer_setup.iss` in **Inno Setup 6.7.1**
2. Build → Compile (or press `Ctrl+F9`)

Output: `installers/OmniBridge_Setup_v{version}.exe`

> [!IMPORTANT]
> Test the installer on a clean VM before publishing — verify first install, upgrade-over-existing, and uninstall all leave no files behind.

---

## Step 5: Publish the GitHub Release

1. Go to [Marshal-GG/omni-bridge-translator → Releases](https://github.com/Marshal-GG/omni-bridge-translator/releases) → **Draft a new release**
2. **Tag**: `v2.0.1` (semver, `v` prefix)
3. **Title**: `Omni Bridge v2.0.1`
4. **Description**: changelog bullet points
5. **Attach**: `installers/OmniBridge_Setup_v2.0.1.exe`
6. **Publish release**

---

## Step 6: Update Firestore `system/app_version`

After publishing, update these fields so existing installs prompt for the update:

```json
{
  "latest":       "2.0.1",
  "update_url":   "https://github.com/Marshal-GG/omni-bridge-translator/releases",
  "download_url": "https://github.com/Marshal-GG/omni-bridge-translator/releases/download/v2.0.1/OmniBridge_Setup_v2.0.1.exe"
}
```

- `latest` — triggers the orange badge on the settings icon for users below this version
- `download_url` — enables in-app direct download via `UpdateDownloadButton`; if absent, falls back to opening `update_url` in the browser
- `min_supported` — only change this for breaking updates; forces the Force Update screen on older clients

---

## How the update checker works

`UpdateRemoteDataSource` reads `system/app_version` from Firestore on every launch and on manual "Check for updates". It compares the running build version against `latest` and `min_supported`:

| Condition | Result |
|---|---|
| Running version < `min_supported` | Force Update screen — blocks app access |
| Running version < `latest` | Orange dot on settings icon, optional update prompt |
| Running version ≥ `latest` | No notification |
