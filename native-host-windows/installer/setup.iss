; InnoSetup script for Tab Switcher Windows
; Build with: iscc setup.iss

#define MyAppName "Tab Switcher"
#define MyAppVersion "3.7.4"
#define MyAppPublisher "Tab Switcher"
#define MyAppURL "https://tabswitcher.app"
#define MyAppExeName "TabSwitcher.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\dist
OutputBaseFilename=TabSwitcher-{#MyAppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\TabSwitcher\Resources\app-icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Start Tab Switcher when Windows starts"; GroupDescription: "Other:"; Flags: unchecked

[Files]
Source: "..\dist\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Native messaging host registry entries for supported browsers
; Chrome
Root: HKCU; Subkey: "SOFTWARE\Google\Chrome\NativeMessagingHosts\com.tabswitcher.native"; ValueType: string; ValueData: "{app}\com.tabswitcher.native.json"; Flags: uninsdeletekey
; Brave
Root: HKCU; Subkey: "SOFTWARE\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.tabswitcher.native"; ValueType: string; ValueData: "{app}\com.tabswitcher.native.json"; Flags: uninsdeletekey
; Edge
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.tabswitcher.native"; ValueType: string; ValueData: "{app}\com.tabswitcher.native.json"; Flags: uninsdeletekey
; Vivaldi
Root: HKCU; Subkey: "SOFTWARE\Vivaldi\NativeMessagingHosts\com.tabswitcher.native"; ValueType: string; ValueData: "{app}\com.tabswitcher.native.json"; Flags: uninsdeletekey
; Chromium
Root: HKCU; Subkey: "SOFTWARE\Chromium\NativeMessagingHosts\com.tabswitcher.native"; ValueType: string; ValueData: "{app}\com.tabswitcher.native.json"; Flags: uninsdeletekey
; Auto-start (optional)
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "TabSwitcher"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Create native messaging manifest JSON during install
procedure CurStepChanged(CurStep: TSetupStep);
var
  ManifestPath: string;
  ManifestContent: string;
begin
  if CurStep = ssPostInstall then
  begin
    ManifestPath := ExpandConstant('{app}\com.tabswitcher.native.json');
    ManifestContent :=
      '{' + #13#10 +
      '  "name": "com.tabswitcher.native",' + #13#10 +
      '  "description": "Tab Switcher Native Helper",' + #13#10 +
      '  "path": "' + ExpandConstant('{app}\{#MyAppExeName}') + '",' + #13#10 +
      '  "type": "stdio",' + #13#10 +
      '  "allowed_origins": ["chrome-extension://*/"]' + #13#10 +
      '}';
    // Replace backslashes in path for JSON
    StringChangeEx(ManifestContent, '\', '\\', True);
    SaveStringToFile(ManifestPath, ManifestContent, False);
  end;
end;
