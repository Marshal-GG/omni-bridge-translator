# Troubleshooting: Python Interpreter Path Resolution with VS Code and Antigravity

## Issue Description

When setting up your `.vscode/settings.json`, you might encounter an issue where the `python.defaultInterpreterPath` is not correctly resolved.

If you use relative paths or VS Code's built-in `${workspaceFolder}` variables like so:

```json
{
    "python.defaultInterpreterPath": "${workspaceFolder}/server/.venv/Scripts/python.exe",
    "python.venvFolders": ["server"],
    "python.analysis.extraPaths": ["${workspaceFolder}/server"]
}
```

Or just relative paths:

```json
{
    "python.defaultInterpreterPath": "server\\.venv\\Scripts\\python.exe"
}
```

This configuration often works fine inside standard VS Code terminals. However, if you are running the **Antigravity AI Agent** extension, you may encounter this error:

> Default interpreter path 'server\.venv\Scripts\python.exe' could not be resolved: Could not resolve interpreter path 'server\.venv\Scripts\python.exe'

**Why this happens:** Antigravity sometimes resolves relative paths using a different root directory context than your workspace folder. To guarantee both VS Code and Antigravity point to the same correct Virtual Environment without ambiguity, the paths must be absolute.

## The Fix

To resolve this issue, you must update `.vscode/settings.json` to use **absolute paths** hardcoded to your machine's location for the virtual environment and analysis paths.

### Corrected `settings.json` Example:

Change the paths to exactly match where the project resides on your local machine. Ensure you are using forward slashes (`/`) even on Windows.

```json
{
    "python.defaultInterpreterPath": "c:/Users/marsh/OneDrive/Desktop/New folder/omni_bridge/server/.venv/Scripts/python.exe",
    "python.venvFolders": [
        "c:/Users/marsh/OneDrive/Desktop/New folder/omni_bridge/server/.venv"
    ],
    "python.analysis.extraPaths": [
        "c:/Users/marsh/OneDrive/Desktop/New folder/omni_bridge/server"
    ]
}
```

### Note on Portability
Because these are absolute paths, if you move the project to a different directory or computer, or give the source code to a teammate, these settings will break. You will need to manually update the paths in `.vscode/settings.json` to match the new location whenever the folder is moved.
