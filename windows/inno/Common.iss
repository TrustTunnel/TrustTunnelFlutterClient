const
  ServiceName = '{#ServiceName}';
  ServiceRegistryKey =
    'SYSTEM\CurrentControlSet\Services\{#ServiceName}';
  AppUninstallRegistryKey =
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{1343AF0C-89EB-44AE-AE55-6251A45376C5}_is1';
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
#if AppArchitecture == "arm64"
  ExpectedServiceMachine = $AA64;
#else
  ExpectedServiceMachine = $8664;
#endif

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
  InstallationCompleted: Boolean;
  InstallWorkStarted: Boolean;
  DeleteUserData: Boolean;
  UninstallPrepared: Boolean;
  ServiceExistedBeforeInstall: Boolean;
  ServiceWasRunning: Boolean;
  OldServiceImagePath: String;
  OldServiceStartType: Cardinal;
  ServiceCreatedByCurrentInstall: Boolean;
  PreviousInstallDirectory: String;
  RollbackDirectory: String;
  RollbackReady: Boolean;
  AppDirectoryExistedBeforeInstall: Boolean;
  ServiceHelperWasRun: Boolean;
  ServiceHelperExitCode: Integer;

function OpenSCManager(
  MachineName: THandle;
  DatabaseName: THandle;
  DesiredAccess: Cardinal
): THandle;
external 'OpenSCManagerW@advapi32.dll stdcall';

function OpenService(
  ScManager: THandle;
  ServiceNameValue: String;
  DesiredAccess: Cardinal
): THandle;
external 'OpenServiceW@advapi32.dll stdcall';

function QueryServiceStatus(
  Service: THandle;
  var Status: TTrustTunnelServiceStatus
): Boolean;
external 'QueryServiceStatus@advapi32.dll stdcall';

function ControlService(
  Service: THandle;
  Control: Cardinal;
  var Status: TTrustTunnelServiceStatus
): Boolean;
external 'ControlService@advapi32.dll stdcall';

function StartService(
  Service: THandle;
  ArgumentCount: Cardinal;
  Arguments: THandle
): Boolean;
external 'StartServiceW@advapi32.dll stdcall';

function ChangeServiceConfig(
  Service: THandle;
  ServiceType: Cardinal;
  StartType: Cardinal;
  ErrorControl: Cardinal;
  BinaryPathName: String;
  LoadOrderGroup: THandle;
  TagId: THandle;
  Dependencies: THandle;
  ServiceStartName: THandle;
  Password: THandle;
  DisplayName: THandle
): Boolean;
external 'ChangeServiceConfigW@advapi32.dll stdcall';

function CloseServiceHandle(Service: THandle): Boolean;
external 'CloseServiceHandle@advapi32.dll stdcall';


function EnsureTrailingBackslash(const Path: String): String;
begin
  Result := Path;
  if (Result <> '') and (Result[Length(Result)] <> '\') then
    Result := Result + '\';
end;

function NormalizePath(const Path: String): String;
begin
  Result := Trim(Path);
  StringChangeEx(Result, '/', '\', True);

  if CompareText(Copy(Result, 1, 4), '\??\') = 0 then
    Delete(Result, 1, 4)
  else if CompareText(Copy(Result, 1, 4), '\\?\') = 0 then
    Delete(Result, 1, 4);

  if Result <> '' then
    Result := ExpandFileName(Result);

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
  if not RegQueryStringValue(
    HKLM64,
    AppUninstallRegistryKey,
    'InstallLocation',
    PreviousInstallDirectory
  ) then
  begin
    if not RegQueryStringValue(
      HKLM32,
      AppUninstallRegistryKey,
      'InstallLocation',
      PreviousInstallDirectory
    ) then
    begin
      if not RegQueryStringValue(
        HKCU64,
        AppUninstallRegistryKey,
        'InstallLocation',
        PreviousInstallDirectory
      ) then
        RegQueryStringValue(
          HKCU32,
          AppUninstallRegistryKey,
          'InstallLocation',
          PreviousInstallDirectory
        );
    end;
  end;
end;

function BooleanAsText(const Value: Boolean): String;
begin
  if Value then
    Result := 'true'
  else
    Result := 'false';
end;
