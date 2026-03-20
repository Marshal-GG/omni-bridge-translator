# GitHub Releases Guide for Omni Bridge

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

The app's `UpdateService` hits the GitHub API:
`https://api.github.com/repos/Marshal-GG/omni-bridge-translator/releases/latest`

It compares the `tag_name` from GitHub with the local version fetched via `package_info_plus`. If the GitHub tag is "newer" (based on semantic versioning), the app shows the "Update available" prompt.
