; Omni Bridge - Inno Setup Installer Script

#define MyAppName "Omni Bridge - Live AI Translator"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "Marshal"
#define MyAppExeName "omni_bridge.exe"
#define MyAppURL "https://github.com/Marshal-GG/omni-bridge-translator"

[Setup]
AppId={{D9BEBE4B-A480-4D46-A223-952F3DB6D5D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=assets\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Install for current user only (no UAC prompt required)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=installers
OutputBaseFilename=OmniBridge_Setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Minimum Windows 10
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
