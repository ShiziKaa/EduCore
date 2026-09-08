; =============================================================================
; Bilim ?e?mesi — Inno Setup 6 script
; =============================================================================
; Before compiling:
;   1) .\scripts\build_windows.ps1   (or flutter build windows --release)
;   2) Open this file in Inno Setup Compiler and Build
;
; Packs the Flutter Windows Release folder next to this script:
;   EduCoreApp\build\windows\x64\runner\Release\
;     educore.exe
;     EduCore_DB\          (search_engine, models, chroma_db, media...)
;     Flutter runtime DLLs + data\
; =============================================================================

#define MyAppName "Bilim Cesmesi"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Akmammedow Akmammet"
#define MyAppURL "https://tdbsi.edu.tm"
#define MyAppExeName "educore.exe"
#define MyAppDbFolder "EduCore_DB"
#define MyReleaseDir "EduCoreApp\build\windows\x64\runner\Release"

[Setup]
AppId={{8FFA843B-6B7B-4E43-953D-96A472F3F6D3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=installer
OutputBaseFilename=BilimCesmesi_Setup
SetupIconFile=EduCoreApp\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
InfoBeforeFile=Hokman Okamaly.txt
CloseApplications=yes
CloseApplicationsFilter=educore.exe,search_engine.exe
RestartApplications=no
; Keep user media / chroma when upgrading over an existing install
UsePreviousAppDir=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Full Flutter Windows release (exe + DLLs + data\ + EduCore_DB\)
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; \
    Excludes: "*.pdb,*.ilk,*.exp,*.lib"

; Must-read guide (also shown before install)
Source: "Hokman Okamaly.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; Comment: "{#MyAppName} — yerli gozleg programmasy"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; Tasks: desktopicon; Comment: "{#MyAppName}"
Name: "{autoprograms}\{#MyAppName}\Hokman Okamaly"; Filename: "{app}\Hokman Okamaly.txt"; \
    Comment: "Gurnama we admin gollanmasy"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; \
    Flags: nowait postinstall skipifsilent runascurrentuser; WorkingDir: "{app}"

[UninstallDelete]
; Optional leftover runtime folders under the install dir (do not touch user exports)
Type: filesandordirs; Name: "{app}\{#MyAppDbFolder}\.drafts"
Type: files; Name: "{app}\{#MyAppDbFolder}\*.tmp"
