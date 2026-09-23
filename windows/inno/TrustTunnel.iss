#ifndef AppVersion
  #define AppVersion "1.2.0"
#endif

#ifndef NumericVersion
  #define NumericVersion "1.2.0.0"
#endif

#ifndef AppArchitecture
  #define AppArchitecture "x64"
#endif

#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "Output"
#endif

#ifndef VcRedistPath
  #define VcRedistPath ".cache\vc_redist.x64.exe"
#endif

#if AppArchitecture == "arm64"
  #define AllowedArchitecture "arm64"
#else
  #define AllowedArchitecture "x64compatible"
#endif

#define AppName "TrustTunnel"
#define AppExeName "TrustTunnel.exe"
#define ServiceName "TrustTunnelVPN"

[Setup]
AppId={{1343AF0C-89EB-44AE-AE55-6251A45376C5}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Adguard Software Limited
AppPublisherURL=https://github.com/TrustTunnel/TrustTunnelFlutterClient
AppSupportURL=https://github.com/TrustTunnel/TrustTunnelFlutterClient/issues
AppUpdatesURL=https://github.com/TrustTunnel/TrustTunnelFlutterClient/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=TrustTunnelSetup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
ArchitecturesAllowed={#AllowedArchitecture}
ArchitecturesInstallIn64BitMode={#AllowedArchitecture}
MinVersion=10.0
PrivilegesRequired=admin
AppMutex=TrustTunnelFlutterClient
CloseApplications=yes
RestartApplications=no
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
AppCopyright=Copyright (C) 2026 Adguard Software Limited. All rights reserved.
VersionInfoVersion={#NumericVersion}
VersionInfoCompany=Adguard Software Limited
VersionInfoDescription=TrustTunnel installer
VersionInfoProductName=TrustTunnel
VersionInfoProductVersion={#AppVersion}
VersionInfoCopyright=Copyright (C) 2026 Adguard Software Limited. All rights reserved.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#VcRedistPath}"; DestName: "vc_redist.exe"; Flags: dontcopy
Source: "{#BuildDir}\trusttunnel_service_installer.exe"; DestDir: "service_install"; Flags: dontcopy
Source: "{#BuildDir}\trusttunnel.dll"; DestDir: "service_install"; Flags: dontcopy
Source: "{#BuildDir}\wintun.dll"; DestDir: "service_install"; Flags: dontcopy
Source: "{#BuildDir}\*"; DestDir: "{app}"; Excludes: "*.exp,*.ilk,*.lib,*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
Name: "{commonappdata}\TrustTunnel"; Permissions: users-modify
Name: "{commonappdata}\TrustTunnel\logs"; Permissions: users-modify

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCR; Subkey: "tt"; ValueType: string; ValueData: "URL:TrustTunnel Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "tt"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "tt\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExeName},0"
Root: HKCR; Subkey: "tt\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExeName}"" ""%1"""

[UninstallDelete]
Type: filesandordirs; Name: "{commonappdata}\TrustTunnel\logs"
Type: files; Name: "{commonappdata}\TrustTunnel\vpn_query_log.ring"
Type: dirifempty; Name: "{commonappdata}\TrustTunnel"

[Code]

#include "Common.iss"
#include "Service.iss"
#include "Rollback.iss"
#include "Uninstall.iss"

function InstallVcRedist(var ErrorMessage: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  ErrorMessage := '';
  ExtractTemporaryFile('vc_redist.exe');

  ResultCode := -1;
  if not Exec(
    ExpandConstant('{tmp}\vc_redist.exe'),
    '/install /quiet /norestart',
    ExpandConstant('{tmp}'),
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  ) then
  begin
    ErrorMessage :=
      'Unable to launch the Microsoft Visual C++ Runtime installer: ' +
      SysErrorMessage(ResultCode);
    exit;
  end;

  VcRedistNeedsRestart := ResultCode = 3010;
  if
    (ResultCode <> 0) and
    (ResultCode <> 1638) and
    (ResultCode <> 3010)
  then
  begin
    ErrorMessage :=
      'Unable to install Microsoft Visual C++ Runtime. Error code: ' +
      IntToStr(ResultCode);
    exit;
  end;

  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ErrorMessage: String;
  RestartError: String;
begin
  ReadPreviousInstallDirectory;
  if not InspectExistingService(ErrorMessage) then
  begin
    Result := ErrorMessage;
    exit;
  end;

  if not InstallVcRedist(ErrorMessage) then
  begin
    Result := ErrorMessage;
    exit;
  end;

  AppDirectoryExistedBeforeInstall := DirExists(ExpandConstant('{app}'));
  if ServiceExistedBeforeInstall then
  begin
    if not StopServiceAndWait(ErrorMessage) then
    begin
      Result := ErrorMessage;
      exit;
    end;

    if not CreateRollbackSnapshot(ErrorMessage) then
    begin
      if ServiceWasRunning and not StartServiceAndWait(RestartError) then
        ErrorMessage := ErrorMessage + ' ' + RestartError;
      Result := ErrorMessage;
      exit;
    end;
  end;

  InstallWorkStarted := True;
  Result := '';
end;

function NeedRestart: Boolean;
begin
  Result := VcRedistNeedsRestart;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ErrorMessage: String;
begin
  if CurStep = ssPostInstall then
  begin
    if not InstallOrUpdateService(ErrorMessage) then
      RaiseException(ErrorMessage);
  end
  else if CurStep = ssDone then
  begin
    InstallationCompleted := True;
    if RollbackReady then
    begin
      if not DeleteRollbackSnapshot then
        Log(
          '[rollback] Installation succeeded, but the rollback directory ' +
          'could not be removed: ' + RollbackDirectory
        );
      RollbackReady := False;
      if not DirExists(RollbackDirectory) then
        Log('[rollback] Installation succeeded; rollback files were removed.');
    end;
  end;
end;

procedure DeinitializeSetup;
var
  ErrorMessage: String;
begin
  if InstallationCompleted or not InstallWorkStarted then
    exit;

  if ServiceCreatedByCurrentInstall then
  begin
    if not RemoveService(ErrorMessage) then
    begin
      Log('[rollback] ' + ErrorMessage);
      SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    end
    else if not AppDirectoryExistedBeforeInstall then
      DelTree(ExpandConstant('{app}'), True, True, True);
  end
  else if ServiceExistedBeforeInstall and RollbackReady then
  begin
    if not RestorePreviousInstallation(ErrorMessage) then
    begin
      Log('[rollback] ' + ErrorMessage);
      SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    end;
  end
  else if not AppDirectoryExistedBeforeInstall then
    DelTree(ExpandConstant('{app}'), True, True, True);
end;

