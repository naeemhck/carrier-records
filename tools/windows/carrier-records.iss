; Stable identity: upgrades replace binaries only, never public config or sessions.
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef BuildNumber
  #error BuildNumber is required
#endif

[Setup]
AppId={{A7649C5F-D9C5-4C3C-9A57-6C918B977193}
AppName=Carrier Records
AppVersion={#AppVersion}
AppVerName=Carrier Records {#AppVersion} (build {#BuildNumber})
VersionInfoVersion={#AppVersion}.{#BuildNumber}
AppPublisher=Carrier Records
DefaultDirName={localappdata}\Programs\CarrierRecords
DefaultGroupName=Carrier Records
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir={#OutputDir}
OutputBaseFilename=CarrierRecords-{#AppVersion}+{#BuildNumber}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\carrier_records.exe
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
SetupLogging=yes

[Files]
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Carrier Records"; Filename: "{app}\carrier_records.exe"

[Run]
Filename: "{app}\carrier_records.exe"; Description: "Launch Carrier Records"; Flags: nowait postinstall skipifsilent

; No Registry credentials, UninstallDelete data, scheduler or privileged helper.

[Code]
function InitializeSetup(): Boolean;
var
  Installed, Major, Minor, Build: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) and
    RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Major', Major) and
    RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Minor', Minor) and
    RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Bld', Build);
  if Result then
    Result := (Installed = 1) and ((Major > 14) or ((Major = 14) and
      ((Minor > 44) or ((Minor = 44) and (Build >= 35207)))));
  if not Result then
    MsgBox('Microsoft Visual C++ v14 x64 runtime 14.44.35207 or later is required. Ask your administrator to install the official Microsoft x64 redistributable, then run this installer again. See INSTALLATION.md from the release package.', mbError, MB_OK);
end;
