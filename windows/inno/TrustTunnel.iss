#ifndef AppVersion
  #define AppVersion "1.2.0"
#endif

#ifndef NumericVersion
  #define NumericVersion "1.2.0.0"
#endif

#ifndef X64BuildDir
  #define X64BuildDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef MixedArm64BuildDir
  #define MixedArm64BuildDir "..\..\build\windows\arm64-mixed\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "Output"
#endif

#ifndef VcRedistPath
  #define VcRedistPath ".cache\vc_redist.x64.exe"
#endif

#define AppName "TrustTunnel"
#define AppExeName "TrustTunnel.exe"
#define ServiceName "TrustTunnelVPN"
#include "Identity.iss"

[Setup]
AppId={{{#AppGuid}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Adguard Software Limited
AppPublisherURL=https://github.com/TrustTunnel/TrustTunnelFlutterClient
AppSupportURL=https://github.com/TrustTunnel/TrustTunnelFlutterClient/issues
AppUpdatesURL=https://github.com/TrustTunnel/TrustTunnelFlutterClient/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableReadyPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=TrustTunnelSetup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
CloseApplications=no
UsePreviousAppDir=yes
UsePreviousTasks=yes
AllowCancelDuringInstall=no
RestartIfNeededByRun=no
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

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#VcRedistPath}"; DestName: "vc_redist.exe"; Flags: dontcopy
Source: "{#X64BuildDir}\trusttunnel_service_installer.exe"; DestDir: "service_install\x64"; Flags: dontcopy; Check: not IsArm64
Source: "{#MixedArm64BuildDir}\trusttunnel_service_installer.exe"; DestDir: "service_install\arm64"; Flags: dontcopy; Check: IsArm64
Source: "{#X64BuildDir}\*"; DestDir: "{app}"; Excludes: "*.exp,*.ilk,*.lib,*.pdb,trusttunnel_service.exe,trusttunnel_service_installer.exe,wintun.dll,WINTUN_LICENSE.txt"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#X64BuildDir}\trusttunnel_service.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#MixedArm64BuildDir}\trusttunnel_service.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#X64BuildDir}\trusttunnel_service_installer.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#MixedArm64BuildDir}\trusttunnel_service_installer.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#X64BuildDir}\WINTUN_LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#MixedArm64BuildDir}\WINTUN_LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#X64BuildDir}\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64; AfterInstall: InstallAndValidateService
Source: "{#MixedArm64BuildDir}\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64; AfterInstall: InstallAndValidateService

[Dirs]
Name: "{commonappdata}\TrustTunnel"; Permissions: users-modify
Name: "{commonappdata}\TrustTunnel\logs"; Permissions: users-modify

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKLM; Subkey: "Software\Classes\tt"; ValueType: string; ValueData: "URL:TrustTunnel Protocol"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\tt"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKLM; Subkey: "Software\Classes\tt\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExeName},0"
Root: HKLM; Subkey: "Software\Classes\tt\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExeName}"" ""%1"""

[UninstallDelete]
Type: filesandordirs; Name: "{commonappdata}\TrustTunnel\logs"
Type: files; Name: "{commonappdata}\TrustTunnel\vpn_query_log.ring"
Type: dirifempty; Name: "{commonappdata}\TrustTunnel"

[Code]

#include "Common.iss"
#include "ApplicationLifecycle.iss"
#include "Service.iss"
#include "Rollback.iss"
#include "UpdateMode.iss"
#include "Uninstall.iss"

function InitializeSetup: Boolean;
var
  WindowsVersion: TWindowsVersion;
begin
  Result := InitializeUpdateMode;
  if not Result then exit;
  if IsArm64 then
  begin
    GetWindowsVersionEx(WindowsVersion);
    if (WindowsVersion.Major < 10) or (WindowsVersion.Build < 22000) then
    begin
      OperationError := 'TrustTunnel requires Windows 11 on ARM64.';
      SuppressibleMsgBox(OperationError, mbCriticalError, MB_OK, IDOK);
      Result := False;
    end;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectTasks then
    WizardForm.NextButton.Caption := SetupMessage(msgButtonInstall)
  else if CurPageID = wpFinished then
    WizardForm.NextButton.Caption := SetupMessage(msgButtonFinish)
  else
    WizardForm.NextButton.Caption := SetupMessage(msgButtonNext);
end;

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
begin
  Result := '';
  if PreparationCompleted then exit;

  if not OriginalStateCaptured then
  begin
    if not ValidateUpdateInstallation(ErrorMessage) or
       not InspectExistingService(ErrorMessage) then
    begin
      Result := ErrorMessage;
      OperationError := Result;
      exit;
    end;
    AppDirectoryExistedBeforeInstall := DirExists(ExpandConstant('{app}'));
    OriginalStateCaptured := True;
  end;

  if not PrerequisitesReady then
  begin
    if not InstallVcRedist(ErrorMessage) then
    begin
      Result := ErrorMessage;
      OperationError := Result;
      exit;
    end;
    PrerequisitesReady := True;
  end;

  if not AcquireInstallationLock(ErrorMessage) or
     not ValidateUpdateInstallation(ErrorMessage) or
     not VerifyOriginalService(ErrorMessage) or
     not PrepareApplicationExit(UpdateMode, AppInitiatedUpdate, ErrorMessage) then
  begin
    Result := ErrorMessage;
    OperationError := Result;
    { A timeout before service/file changes must let the still-running GUI
      resume, even if the interactive setup stays open on its error page. }
    if not ServiceStopAttempted and not GuiExited then ReleaseInstallationLock;
    exit;
  end;

  if ServiceExistedBeforeInstall then
  begin
    ServiceStopAttempted := True;
    if not StopServiceAndWait(ErrorMessage) then
    begin
      Result := ErrorMessage;
      OperationError := Result;
      exit;
    end;
  end;

  if UpdateMode and not SnapshotReady then
  begin
    if not CreateRollbackSnapshot(ErrorMessage) then
    begin
      Result := ErrorMessage;
      OperationError := Result;
      exit;
    end;
    SnapshotReady := True;
  end;
  PreparationCompleted := True;
end;

function NeedRestart: Boolean;
begin
  { No restartreplace files: prerequisite reboot requests are reported via
    the result file and GetCustomSetupExitCode, never an automatic reboot. }
  Result := False;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (UpdateMode and (PageID = wpSelectDir)) or
    (AppInitiatedUpdate and (PageID = wpSelectTasks));
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := 0;
  if FilesReplacementStarted and not InstallationCommitted then Result := 21
  else if InstallationCommitted and RestartPending then Result := 3010
  else if GuiLaunchFailed then Result := 20;
end;

procedure InstallAndValidateService;
var
  ErrorMessage: String;
begin
  { AfterInstall on the final bundle file runs inside PerformInstall, where
    exceptions are fatal. ssPostInstall exceptions are handled by Inno and
    otherwise allow setup to display success despite service failure. }
  if ServiceValidated then exit;
  if not InstallOrUpdateService(ErrorMessage) then
  begin
    OperationError := ErrorMessage;
    RaiseException(ErrorMessage);
  end;
  ServiceValidated := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    if not PreparationCompleted or (UpdateMode and not SnapshotReady) then
      RaiseException('Installation preparation did not complete.');
    FilesReplacementStarted := True;
  end
  else if CurStep = ssDone then
  begin
    InstallationCommitted := ServiceValidated;
    if not InstallationCommitted then RaiseException('Service validation did not complete.');
    if SnapshotReady then
    begin
      if not DeleteRollbackSnapshot then
        Log('[rollback] Unable to remove snapshot: ' + RollbackDirectory);
      SnapshotReady := False;
    end;
    WriteOperationResult('success', '');
    ReleaseInstallationLock;
    if UpdateMode and not VcRedistNeedsRestart and not RestartPending then
      LaunchUpdatedApplication;
  end;
end;

procedure DeinitializeSetup;
var
  ErrorMessage: String;
  RollbackSucceeded: Boolean;
begin
  try
    if InstallationCommitted then exit;
    { Preparation errors also get a machine-readable result if no competing
      installer owns the lock. UAC cancellation never reaches setup code. }
    if InstallationLock = 0 then AcquireInstallationLock(ErrorMessage);
    RollbackSucceeded := True;
    if FilesReplacementStarted and SnapshotReady then
      RollbackSucceeded := RestorePreviousInstallation(ErrorMessage)
    else if FilesReplacementStarted then
    begin
      if ServiceCreatedByCurrentInstall then
        RollbackSucceeded := RemoveService(ErrorMessage);
      if RollbackSucceeded and not AppDirectoryExistedBeforeInstall then
        RollbackSucceeded := DelTree(ExpandConstant('{app}'), True, True, True);
    end
    else if ServiceStopAttempted and ServiceWasRunning then
      RollbackSucceeded := StartServiceAndWait(ErrorMessage);

    if not RollbackSucceeded then
    begin
      OperationError := OperationError + ' ' + ErrorMessage;
      Log('[rollback] ' + OperationError);
      WriteOperationResult('rollback_failed', OperationError);
      SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    end
    else
    begin
      if OperationError = '' then OperationError := 'Setup did not complete.';
      if FilesReplacementStarted and UpdateMode then
        WriteOperationResult('rolled_back', OperationError)
      else
        WriteOperationResult('failed', OperationError);
      if SnapshotReady then DeleteRollbackSnapshot;
    end;
    ReleaseInstallationLock;
    if RollbackSucceeded and UpdateMode and GuiExited and
       not VcRedistNeedsRestart and not RestartPending then
      LaunchUpdatedApplication;
  finally
    ReleaseApplicationHandles;
    ReleaseInstallationLock;
  end;
end;
