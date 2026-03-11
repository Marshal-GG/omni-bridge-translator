# Omni Bridge - Data Cleanup Script
# This script clears persistent data, settings, and sessions for Debug and/or Release versions.

$ErrorActionPreference = "SilentlyContinue"

Write-Host "`n--- Omni Bridge Cleanup Utility ---" -ForegroundColor Cyan
Write-Host "Select what you want to clear:"
Write-Host "1) Debug Version (VS Code / Development)"
Write-Host "2) Installed Version (Release / Prodcution)"
Write-Host "3) Everything (Clean Slate)"
Write-Host "Q) Quit"

$Choice = Read-Host "`nEnter your choice (1, 2, 3, or Q)"

if ($Choice -eq 'Q' -or $Choice -eq 'q') { exit }

$ClearDebug = ($Choice -eq '1' -or $Choice -eq '3')
$ClearRelease = ($Choice -eq '2' -or $Choice -eq '3')

if (-not $ClearDebug -and -not $ClearRelease) {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit
}

Write-Host "`n--- Starting Cleanup ---" -ForegroundColor Cyan

# 1. Kill running processes
Write-Host "[1/4] Closing running instances..." -ForegroundColor Yellow
Stop-Process -Name "omni_bridge" -Force
Stop-Process -Name "omni_bridge_server" -Force
taskkill /F /IM "omni_bridge.exe" /T
taskkill /F /IM "omni_bridge_server.exe" /T

# 2. Clear AppData Folders (Roaming and Local)
Write-Host "[2/4] Clearing AppData folders..." -ForegroundColor Yellow
$Company = "Marshal"

$DebugName = "Omni Bridge: Live AI Translator (Debug)"
$ReleaseNames = @(
    "Omni Bridge: Live AI Translator",
    "Omni Bridge - Live AI Translator"
)

function Remove-AppData ($AppName) {
    # Windows/Flutter substitutes some characters (like :) with underscores in folder names
    $AppFolderName = $AppName -replace ':', '_'
    
    $Paths = @(
        (Join-Path $env:APPDATA "$Company\$AppName"),
        (Join-Path $env:APPDATA "$Company\$AppFolderName"),
        (Join-Path $env:LOCALAPPDATA "$Company\$AppName"),
        (Join-Path $env:LOCALAPPDATA "$Company\$AppFolderName"),
        # Also check for direct AppData (no company) just in case some plugins use it
        (Join-Path $env:APPDATA "$AppName"),
        (Join-Path $env:APPDATA "$AppFolderName"),
        (Join-Path $env:LOCALAPPDATA "$AppName"),
        (Join-Path $env:LOCALAPPDATA "$AppFolderName")
    )
    
    foreach ($Path in $Paths) {
        if (Test-Path $Path) {
            Write-Host "  Removing data: $Path"
            Remove-Item -Path $Path -Recurse -Force
        }
    }
}

function Remove-FirebaseTarget ($TargetName) {
    Write-Host "  Removing isolated Firebase session: $TargetName" -ForegroundColor Cyan
    $FirebasePaths = @(
        (Join-Path $env:LOCALAPPDATA "firestore\$TargetName"),
        (Join-Path $env:LOCALAPPDATA "google-services-desktop-auth\$TargetName"),
        (Join-Path $env:LOCALAPPDATA "firebase-heartbeat\$TargetName")
    )

    foreach ($Path in $FirebasePaths) {
        if (Test-Path $Path) {
            Write-Host "    Clearing: $Path"
            Remove-Item -Path $Path -Recurse -Force
        }
    }
}

if ($ClearDebug) {
    Remove-AppData $DebugName
    Remove-FirebaseTarget "OmniBridge-Debug"
}

if ($ClearRelease) {
    foreach ($Name in $ReleaseNames) {
        Remove-AppData $Name
    }
    Remove-FirebaseTarget "OmniBridge-Release"
}

# Note: We specifically avoid touching the 'default' root folders (e.g. AppData\Local\firestore) 
# to ensure other Firebase projects on this system are not affected. 
# Our isolated sessions (OmniBridge-Debug/Release) were handled above.

# 3. Clear Registry Keys (Flutter SharedPreferences)
Write-Host "[3/4] Clearing Registry settings..." -ForegroundColor Yellow

function Remove-RegKey ($Path) {
    if (Test-Path $Path) {
        Write-Host "  Removing Registry key: $Path"
        Remove-Item -Path $Path -Recurse -Force
    }
}

if ($ClearDebug) {
    Remove-RegKey "HKCU:\Software\$Company\$DebugName"
    Remove-RegKey "HKCU:\Software\omni_bridge"
}

if ($ClearRelease) {
    foreach ($Name in $ReleaseNames) {
        Remove-RegKey "HKCU:\Software\$Company\$Name"
    }
    Remove-RegKey "HKCU:\Software\com.marshal\omni_bridge"
    Remove-RegKey "HKCU:\Software\com.marshal\Omni Bridge"
}

# 4. Clear Local Project Logs and Temp Files
Write-Host "[4/4] Clearing local project logs and temp files..." -ForegroundColor Yellow
$LogDir = Join-Path $PSScriptRoot "..\server\logs"
if (Test-Path $LogDir) {
    Write-Host "  Removing local logs directory..."
    Remove-Item -Path $LogDir -Recurse -Force
}

# Clear PyInstaller Temp Extractions
$TempDir = $env:TEMP
$PyExtractions = Get-ChildItem -Path $TempDir -Filter "omni_bridge*"
foreach ($Extraction in $PyExtractions) {
    Write-Host "  Removing PyInstaller temp: $($Extraction.Name)"
    Remove-Item -Path $Extraction.FullName -Recurse -Force
}

Write-Host "--- Cleanup Complete ---" -ForegroundColor Green
Write-Host "The selected app version has been reset. You will need to log in again."
pause
