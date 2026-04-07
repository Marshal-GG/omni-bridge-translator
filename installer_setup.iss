; Omni Bridge — Inno Setup Installer Script
; Build: Release  |  Target: Windows 10 x64+

#define MyAppName        "Omni Bridge - Live AI Translator"
#define MyAppVersion     "2.0.0"
#define MyAppPublisher   "Marshal"
#define MyAppExeName     "omni_bridge.exe"
#define MyAppServerExe   "omni_bridge_server.exe"
#define MyAppURL         "https://github.com/Marshal-GG/omni-bridge-translator"
#define MyAppCopyright   "Copyright (C) 2026 Marshal. All rights reserved."
#define MyAppMutex       "OmniBridgeMutex"
#define MyAppSetupMutex  "OmniBridgeSetupMutex"

[Setup]
; Stable GUID — never change this after first release or upgrades will break
AppId={{D9BEBE4B-A480-4D46-A223-952F3DB6D5D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright={#MyAppCopyright}
AppReadmeFile={#MyAppURL}

; Version info embedded into the installer .exe itself
; Must be 4-part (N.N.N.N) — Inno Setup requires this format
VersionInfoVersion=2.0.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright={#MyAppCopyright}

; Install to Program Files (system-wide, consistent across users)
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes

; 64-bit Windows only — required for Flutter x64 and server .exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Minimum Windows 10 1809 (build 17763) — required for WebView2 and bitsdojo_window
MinVersion=10.0.17763

; Icons
SetupIconFile=assets\app\icons\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Privileges — admin required; no downgrade option shown to user
PrivilegesRequired=admin

; Prevent running app and duplicate installer simultaneously
AppMutex={#MyAppMutex}
SetupMutex={#MyAppSetupMutex}
CloseApplications=yes
RestartApplications=no

; Output
OutputDir=installers
OutputBaseFilename=OmniBridge_Setup_v{#MyAppVersion}

; Compression
Compression=lzma2/ultra64
CompressionThreads=auto
SolidCompression=yes
LZMAUseSeparateProcess=yes

; Wizard
WizardStyle=modern
WizardResizable=no

; Legal
LicenseFile=docs\legal\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "startupicon"; Description: "Launch Omni Bridge on Windows startup"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Flutter app — all release DLLs, exe, data folders, plugins, assets
; Exclude .lib/.exp build artifacts — not needed at runtime, just bloat
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp"; Flags: ignoreversion recursesubdirs createallsubdirs

; Python backend server (obfuscated + PyInstaller standalone)
Source: "server\dist\{#MyAppServerExe}"; DestDir: "{app}"; Flags: ignoreversion

; Legal documents (shown during install and accessible from app dir)
Source: "docs\legal\*"; DestDir: "{app}\docs\legal"; Flags: ignoreversion recursesubdirs createallsubdirs

; (Uncomment if users see "VCRUNTIME140.dll missing" on clean machines)
; Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[InstallDelete]
; Wipe existing install dir so stale DLLs, old server builds, and leftover
; Whisper model files never conflict with the incoming version.
Type: filesandordirs; Name: "{app}"

[UninstallDelete]
; Remove entire app dir on uninstall — clears runtime files, Whisper models, logs
Type: filesandordirs; Name: "{app}"

[Icons]
; Start Menu
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
; Desktop (optional, checked by default once)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; Startup (optional, unchecked by default)
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
; Launch app after install completes (skipped in silent mode)
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
; ── Custom URL scheme: omni-bridge:// ─────────────────────────────────────────
; Required for deep linking and Google Sign-In redirect on Windows.
Root: HKCR; Subkey: "omni-bridge";                           ValueType: string; ValueData: "URL:Omni Bridge Protocol";  Flags: uninsdeletekey
Root: HKCR; Subkey: "omni-bridge";                           ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "omni-bridge\DefaultIcon";               ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "omni-bridge\shell\open\command";        ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

; ── Reversed Google Client ID scheme ─────────────────────────────────────────
; Required for the browser → app OAuth redirect to trigger the "Open App" dialog.
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-7c9m4sag4p7lubjsim25f76ha9oja77g";                             ValueType: string; ValueData: "URL:Google Auth Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-7c9m4sag4p7lubjsim25f76ha9oja77g";                             ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-7c9m4sag4p7lubjsim25f76ha9oja77g\DefaultIcon";                 ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-7c9m4sag4p7lubjsim25f76ha9oja77g\shell\open\command";          ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[UninstallRun]
; Kill both processes before uninstaller removes files — prevents file-lock errors
; Must use full path to taskkill — Inno Setup does not search PATH for [UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM {#MyAppServerExe} /T"; Flags: runhidden; RunOnceId: "KillServer"
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM {#MyAppExeName} /T";   Flags: runhidden; RunOnceId: "KillApp"

[Code]
// ── Helpers ───────────────────────────────────────────────────────────────────

procedure DeleteRegKeyIfExists(RootKey: Integer; SubKey: String);
begin
  if RegKeyExists(RootKey, SubKey) then
    RegDeleteKeyIncludingSubkeys(RootKey, SubKey);
end;

procedure KillAppProcesses();
var
  ResultCode: Integer;
  Taskkill: String;
begin
  // Use full path — Exec() does not search PATH
  Taskkill := ExpandConstant('{sys}\taskkill.exe');
  Exec(Taskkill, '/F /IM {#MyAppServerExe} /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(Taskkill, '/F /IM {#MyAppExeName} /T',   '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure WipeUserData();
begin
  // Flutter SharedPreferences (registry) — all known key locations
  DeleteRegKeyIfExists(HKCU, 'Software\omni_bridge');
  DeleteRegKeyIfExists(HKCU, 'Software\com.marshal\omni_bridge');
  DeleteRegKeyIfExists(HKCU, 'Software\Marshal\omni_bridge');
  DeleteRegKeyIfExists(HKCU, 'Software\Marshal\Omni Bridge: Live AI Translator');
  DeleteRegKeyIfExists(HKCU, 'Software\com.marshal\Omni Bridge');

  // AppData Roaming + Local (com.marshal = CompanyName in Runner.rc)
  DelTree(ExpandConstant('{userappdata}\com.marshal\{#MyAppName}'), True, True, True);
  DelTree(ExpandConstant('{localappdata}\com.marshal\{#MyAppName}'), True, True, True);

  // Firebase / Firestore / Auth caches (scoped to OmniBridge-Release app name)
  DelTree(ExpandConstant('{localappdata}\firestore\OmniBridge-Release'),                    True, True, True);
  DelTree(ExpandConstant('{localappdata}\firebase-heartbeat\OmniBridge-Release'),           True, True, True);
  DelTree(ExpandConstant('{localappdata}\google-services-desktop-auth\OmniBridge-Release'), True, True, True);
end;

// ── Pre-install cleanup ───────────────────────────────────────────────────────
// Runs before files are copied. Order matters:
//   1. Kill processes (release file locks)
//   2. Run existing uninstaller (HKLM = admin install, HKCU = legacy user install)
//   3. Wipe SharedPreferences registry keys
//   4. Remove outdated Google OAuth registry key from previous scheme
//   5. Delete stale PyInstaller %TEMP%\omni_bridge* extractions
//   6. Remove leftover user-level install dir (from old lowest-privilege builds)
//   7. Wipe persistent session/auth data (prevents "still logged in after reinstall")

procedure CurStepChanged(CurStep: TSetupStep);
var
  UninstPath: String;
  UninstExe:  String;
  ResultCode: Integer;
  TempDir:    String;
  FindRec:    TFindRec;
begin
  if CurStep = ssInstall then
  begin
    // 1. Kill stale processes
    KillAppProcesses();

    // 2. Run old uninstaller silently
    UninstPath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';
    if RegQueryStringValue(HKLM, UninstPath, 'UninstallString', UninstExe) or
       RegQueryStringValue(HKCU, UninstPath, 'UninstallString', UninstExe) then
    begin
      Exec(RemoveQuotes(UninstExe), '/VERYSILENT /NORESTART', '', SW_HIDE,
           ewWaitUntilTerminated, ResultCode);
    end;

    // 3. Wipe Flutter SharedPreferences + AppData + Firebase caches
    WipeUserData();

    // 4. Remove outdated Google OAuth registry key (old Client ID scheme — no longer used)
    DeleteRegKeyIfExists(HKCR, 'com.googleusercontent.apps.883780252017-c3h4v2pha56t4939hld31sdhllg1tcc9');

    // 5. Delete stale PyInstaller %TEMP%\omni_bridge* extractions
    TempDir := ExpandConstant('{%TEMP}\');
    if FindFirst(TempDir + 'omni_bridge*', FindRec) then
    begin
      repeat
        if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
        begin
          if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
            DelTree(TempDir + FindRec.Name, True, True, True)
          else
            DeleteFile(TempDir + FindRec.Name);
        end;
      until not FindNext(FindRec);
      FindClose(FindRec);
    end;

    // 6. Remove leftover user-level install dir (legacy builds installed to LocalAppData)
    DelTree(ExpandConstant('{localappdata}\Programs\{#MyAppName}'), True, True, True);
  end;
end;

// ── Uninstall cleanup ─────────────────────────────────────────────────────────

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // Kill processes before files are removed
    KillAppProcesses();
    // Wipe all user data
    WipeUserData();
  end;
end;
