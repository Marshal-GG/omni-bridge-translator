; Omni Bridge - Inno Setup Installer Script

#define MyAppName "Omni Bridge: Live AI Translator"
#define MyAppVersion "1.2.1"
#define MyAppPublisher "Marshal"
#define MyAppExeName "omni_bridge.exe"
#define MyAppURL "https://github.com/Marshal-GG/omni-bridge-translator"
#define MyAppCopyright "Copyright (C) 2026 Marshal. All rights reserved."

[Setup]
AppId={{D9BEBE4B-A480-4D46-A223-952F3DB6D5D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright={#MyAppCopyright}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Restrict installer to 64-bit Windows only (required for Flutter x64 builds)
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=assets\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Require admin so the app installs to C:\Program Files (system-wide)
PrivilegesRequired=admin
; Close any running instance before installing to prevent file-lock errors
CloseApplications=yes
RestartApplications=no
OutputDir=installers
OutputBaseFilename=OmniBridge_Setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Minimum Windows 10 (1809 / RS5 — build 17763)
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "startupicon"; Description: "Launch Omni Bridge on Windows startup"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main Flutter executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All Flutter release DLLs and data (plugins, assets, etc.)
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Standalone Python backend server
Source: "server\dist\omni_bridge_server.exe"; DestDir: "{app}"; Flags: ignoreversion

; Flutter app .env (contains GOOGLE_CLIENT_ID)
Source: ".env"; DestDir: "{app}"; Flags: ignoreversion

; Python server .env (contains API keys)
Source: "server\.env"; DestDir: "{app}"; Flags: ignoreversion

; (Optional) VC++ Redistributables — uncomment if users see "missing VCRUNTIME" errors:
; Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
; Run after install: {tmp}\vc_redist.x64.exe /quiet /norestart

[InstallDelete]
; Wipe the entire app directory before installing so stale files never linger
Type: filesandordirs; Name: "{app}"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
; Register custom URL scheme for deep linking (omni-bridge://) - needed for Google Sign-In redirect
Root: HKCR; Subkey: "omni-bridge"; ValueType: string; ValueData: "URL:omni-bridge Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "omni-bridge"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "omni-bridge\DefaultIcon"; ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "omni-bridge\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

; Register the reversed Google Client ID as a second protocol
; This is mandatory for Google OAuth redirect to trigger the "Open App" prompt in browsers
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-c3h4v2pha56t4939hld31sdhllg1tcc9"; ValueType: string; ValueData: "URL:Google Auth Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-c3h4v2pha56t4939hld31sdhllg1tcc9"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-c3h4v2pha56t4939hld31sdhllg1tcc9\DefaultIcon"; ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "com.googleusercontent.apps.883780252017-c3h4v2pha56t4939hld31sdhllg1tcc9\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[UninstallRun]
; Kill the Python server process during uninstall
Filename: "taskkill"; Parameters: "/F /IM omni_bridge_server.exe /T"; Flags: runhidden

[Code]
// ── Pre-install cleanup ─────────────────────────────────────────────────────
// Runs the existing uninstaller silently (covers both HKLM and HKCU entries),
// wipes Flutter SharedPreferences from the registry, and removes PyInstaller
// %TEMP% extractions so a truly fresh version is always loaded.

procedure DeleteRegKeyIfExists(RootKey: Integer; SubKey: String);
begin
  if RegKeyExists(RootKey, SubKey) then
    RegDeleteKeyIncludingSubkeys(RootKey, SubKey);
end;

procedure KillServerProcess();
var
  ResultCode: Integer;
begin
  // Kill the Python server process if running
  Exec('taskkill', '/F /IM omni_bridge_server.exe /T', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
end;

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
    // 0. Kill stale processes early
    KillServerProcess();

    // 1. Run old uninstaller (HKLM = admin install, HKCU = old user-level install)
    UninstPath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';
    if RegQueryStringValue(HKLM, UninstPath, 'UninstallString', UninstExe) or
       RegQueryStringValue(HKCU, UninstPath, 'UninstallString', UninstExe) then
    begin
      // /VERYSILENT — no UI; /NORESTART — do not reboot
      Exec(RemoveQuotes(UninstExe), '/VERYSILENT /NORESTART', '', SW_HIDE,
           ewWaitUntilTerminated, ResultCode);
    end;

    // 2. Wipe Flutter Windows SharedPreferences
    // Flutter usually stores these in HKCU\Software\<app_name>
    DeleteRegKeyIfExists(HKCU, 'Software\omni_bridge');
    DeleteRegKeyIfExists(HKCU, 'Software\com.marshal.omni_bridge');

    // 3. Delete any PyInstaller %TEMP%\omni_bridge* extractions from old runs
    TempDir := ExpandConstant('{tmp}');
    TempDir := ExtractFilePath(TempDir); // Parent of {tmp} is the actual %TEMP%
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

    // 4. Remove leftover user-level install dir (from old lowest-privilege installs)
    DelTree(ExpandConstant('{localappdata}\Programs\{#MyAppName}'), True, True, True);

    // 5. Wipe Persistent Session/Auth Data (Fixes "still logged in" issue)
    // - AppData Roaming (com.marshal is the CompanyName from Runner.rc)
    DelTree(ExpandConstant('{userappdata}\com.marshal\{#MyAppName}'), True, True, True);
    // - LocalAppData
    DelTree(ExpandConstant('{localappdata}\com.marshal\{#MyAppName}'), True, True, True);
    // - Firebase/Firestore Caches
    DelTree(ExpandConstant('{localappdata}\firestore'), True, True, True);
    DelTree(ExpandConstant('{localappdata}\firebase-heartbeat'), True, True, True);
  end;
end;
