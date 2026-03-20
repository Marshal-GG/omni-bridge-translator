# Troubleshooting: Python Interpreter Path Resolution with VS Code

## Issue Description

When setting up your `.vscode/settings.json`, you might encounter an issue where the `python.defaultInterpreterPath` is not correctly resolved.

If you use relative paths or VS Code's built-in `${workspaceFolder}` variables like so:

```json
{
    "python.defaultInterpreterPath": "${workspaceFolder}/.venv/Scripts/python.exe",
    "python.venvFolders": ["server", ".venv"],
    "python.analysis.extraPaths": ["${workspaceFolder}/server"]
}
```

Or just relative paths:

```json
{
    "python.defaultInterpreterPath": ".venv\\Scripts\\python.exe"
}
```

This configuration often works fine inside standard VS Code terminals. However, some extensions (e.g., AI Agent extensions) may resolve relative paths using a different root directory context than your workspace folder, resulting in errors like:

> Default interpreter path '.venv\Scripts\python.exe' could not be resolved

## The Fix

Update `.vscode/settings.json` to reference the virtual environment relative to the project name. The project `.vscode/settings.json` is pre-configured with:

```json
{
    "python.defaultInterpreterPath": "omni_bridge\\.venv\\Scripts\\python.exe",
    "python.venvFolders": [
        "omni_bridge/.venv"
    ],
    "python.analysis.extraPaths": [
        "omni_bridge/server"
    ]
}
```

### Note on Portability
Because these paths reference the project folder by name, they will need updating if you rename the project directory or move it to a machine where the folder has a different name.
