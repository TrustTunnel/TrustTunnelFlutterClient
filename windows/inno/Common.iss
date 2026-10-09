{ Inno Setup's default installer process is 32-bit, independently of the
  target OS/bundle architecture. Use our own alias across Inno 6 and 7. }
type
  TInstallerHandle = Integer;

const
  ServiceName = '{#ServiceName}';
  ServiceRegistryKey =
    'SYSTEM\CurrentControlSet\Services\{#ServiceName}';
  AppUninstallRegistryKey =
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{{#AppGuid}}_is1';
  ServiceStopped = 1;
  ServiceStartPending = 2;
  ServiceStopPending = 3;
  ServiceRunning = 4;
  ServiceControlStop = 1;
  ServiceQueryStatus = $0004;
  ServiceStart = $0010;
  ServiceStop = $0020;
  ServiceChangeConfig = $0002;
  ScManagerConnect = $0001;
  ServiceNoChange = $FFFFFFFF;
  ServiceDemandStart = 3;
  ErrorServiceDoesNotExist = 1060;

type
  TTrustTunnelServiceStatus = record
    ServiceType: Cardinal;
    CurrentState: Cardinal;
    ControlsAccepted: Cardinal;
    Win32ExitCode: Cardinal;
    ServiceSpecificExitCode: Cardinal;
    CheckPoint: Cardinal;
    WaitHint: Cardinal;
  end;

var
  VcRedistNeedsRestart: Boolean;
  UpdateMode: Boolean;
  AppInitiatedUpdate: Boolean;
  OriginalStateCaptured: Boolean;
  PrerequisitesReady: Boolean;
  PreparationCompleted: Boolean;
  GuiExited: Boolean;
  ServiceStopAttempted: Boolean;
  SnapshotReady: Boolean;
  FilesReplacementStarted: Boolean;
  ServiceValidated: Boolean;
  InstallationCommitted: Boolean;
  GuiLaunchFailed: Boolean;
  OperationStarted: Boolean;
  InitiatorPid: Cardinal;
  OperationId: String;
  OperationError: String;
  PreviousVersion: String;
  PreviousTasks: String;
  DeleteUserData: Boolean;
  UninstallPrepared: Boolean;
  ServiceExistedBeforeInstall: Boolean;
  ServiceWasRunning: Boolean;
  OldServiceImagePath: String;
  OldServiceStartType: Cardinal;
  ServiceCreatedByCurrentInstall: Boolean;
  PreviousInstallDirectory: String;
  RollbackDirectory: String;

  AppDirectoryExistedBeforeInstall: Boolean;
  ServiceHelperWasRun: Boolean;
  ServiceHelperExitCode: Integer;

function OpenSCManager(
  MachineName: TInstallerHandle;
  DatabaseName: TInstallerHandle;
  DesiredAccess: Cardinal
): TInstallerHandle;
external 'OpenSCManagerW@advapi32.dll stdcall';

function OpenService(
  ScManager: TInstallerHandle;
  ServiceNameValue: String;
  DesiredAccess: Cardinal
): TInstallerHandle;
external 'OpenServiceW@advapi32.dll stdcall';

function QueryServiceStatus(
  Service: TInstallerHandle;
  var Status: TTrustTunnelServiceStatus
): Boolean;
external 'QueryServiceStatus@advapi32.dll stdcall';

function ControlService(
  Service: TInstallerHandle;
  Control: Cardinal;
  var Status: TTrustTunnelServiceStatus
): Boolean;
external 'ControlService@advapi32.dll stdcall';

function StartService(
  Service: TInstallerHandle;
  ArgumentCount: Cardinal;
  Arguments: TInstallerHandle
): Boolean;
external 'StartServiceW@advapi32.dll stdcall';

function ChangeServiceConfig(
  Service: TInstallerHandle;
  ServiceType: Cardinal;
  StartType: Cardinal;
  ErrorControl: Cardinal;
  BinaryPathName: String;
  LoadOrderGroup: TInstallerHandle;
  TagId: TInstallerHandle;
  Dependencies: TInstallerHandle;
  ServiceStartName: TInstallerHandle;
  Password: TInstallerHandle;
  DisplayName: TInstallerHandle
): Boolean;
external 'ChangeServiceConfigW@advapi32.dll stdcall';

function CloseServiceHandle(Service: TInstallerHandle): Boolean;
external 'CloseServiceHandle@advapi32.dll stdcall';


function EnsureTrailingBackslash(const Path: String): String;
begin
  Result := Path;
  if (Result <> '') and (Result[Length(Result)] <> '\') then
    Result := Result + '\';
end;

function GetLongPathName(Path, Buffer: String; Capacity: Cardinal): Cardinal;
external 'GetLongPathNameW@kernel32.dll stdcall';

function NormalizePath(const Path: String): String;
var
  LongPath: String;
  PathLength: Cardinal;
begin
  Result := Trim(Path);
  StringChangeEx(Result, '/', '\', True);

  if CompareText(Copy(Result, 1, 4), '\??\') = 0 then
    Delete(Result, 1, 4)
  else if CompareText(Copy(Result, 1, 4), '\\?\') = 0 then
    Delete(Result, 1, 4);

  if Result <> '' then
  begin
    Result := ExpandFileName(Result);
    SetLength(LongPath, 32768);
    PathLength := GetLongPathName(Result, LongPath, 32768);
    if (PathLength > 0) and (PathLength < 32768) then
    begin
      SetLength(LongPath, PathLength);
      Result := LongPath;
    end;
  end;

  while
    (Length(Result) > 3) and
    (Result[Length(Result)] = '\')
  do
    Delete(Result, Length(Result), 1);
end;

function ExtractServiceExecutable(const ImagePath: String): String;
var
  Value: String;
  ClosingQuote: Integer;
  ExePosition: Integer;
begin
  Result := '';
  Value := Trim(ImagePath);
  if Value = '' then
    exit;

  if Value[1] = '"' then
  begin
    ClosingQuote := Pos('"', Copy(Value, 2, Length(Value) - 1));
    if ClosingQuote > 0 then
      Result := Copy(Value, 2, ClosingQuote - 1);
  end
  else
  begin
    ExePosition := Pos('.exe', LowerCase(Value));
    if ExePosition > 0 then
      Result := Copy(Value, 1, ExePosition + 3);
  end;

  if Result <> '' then
    Result := NormalizePath(Result);
end;

function PathsEqual(const LeftPath, RightPath: String): Boolean;
begin
  Result := CompareText(
    NormalizePath(LeftPath),
    NormalizePath(RightPath)
  ) = 0;
end;


procedure ReadPreviousInstallDirectory;
begin
  PreviousInstallDirectory := '';
  RegQueryStringValue(HKLM64, AppUninstallRegistryKey,
    'InstallLocation', PreviousInstallDirectory);
end;

function BooleanAsText(const Value: Boolean): String;
begin
  if Value then
    Result := 'true'
  else
    Result := 'false';
end;

function ExpectedServiceMachine: Cardinal;
begin
  if IsArm64 then
    Result := $AA64
  else
    Result := $8664;
end;

function BundledServiceHelperPath: String;
begin
  if IsArm64 then
    Result := ExpandConstant(
      '{tmp}\service_install\arm64\trusttunnel_service_installer.exe'
    )
  else
    Result := ExpandConstant(
      '{tmp}\service_install\x64\trusttunnel_service_installer.exe'
    );
end;
