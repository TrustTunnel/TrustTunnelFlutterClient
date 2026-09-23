function QueryServiceExistence(var Exists: Boolean): Boolean;
var
  Manager: THandle;
  Service: THandle;
  ErrorCode: Cardinal;
begin
  Result := False;
  Exists := True;
  Manager := OpenSCManager(0, 0, ScManagerConnect);
  if Manager = 0 then
    exit;

  try
    Service := OpenService(Manager, ServiceName, ServiceQueryStatus);
    if Service <> 0 then
    begin
      CloseServiceHandle(Service);
      Exists := True;
      Result := True;
    end;
    if Service = 0 then
    begin
      ErrorCode := DLLGetLastError;
      if ErrorCode = ErrorServiceDoesNotExist then
      begin
        Exists := False;
        Result := True;
      end;
    end;
  finally
    CloseServiceHandle(Manager);
  end;
end;

function ServiceExists: Boolean;
var
  Exists: Boolean;
begin
  if QueryServiceExistence(Exists) then
    Result := Exists
  else
    Result := True;
end;

function QueryCurrentServiceState(var State: Cardinal): Boolean;
var
  Manager: THandle;
  Service: THandle;
  Status: TTrustTunnelServiceStatus;
begin
  Result := False;
  State := 0;
  Manager := OpenSCManager(0, 0, ScManagerConnect);
  if Manager = 0 then
    exit;

  try
    Service := OpenService(Manager, ServiceName, ServiceQueryStatus);
    if Service = 0 then
      exit;

    try
      Result := QueryServiceStatus(Service, Status);
      if Result then
        State := Status.CurrentState;
    finally
      CloseServiceHandle(Service);
    end;
  finally
    CloseServiceHandle(Manager);
  end;
end;

function ReadServiceConfiguration(
  var ImagePath: String;
  var StartType: Cardinal
): Boolean;
begin
  ImagePath := '';
  StartType := 0;
  Result :=
    RegQueryStringValue(
      HKLM64,
      ServiceRegistryKey,
      'ImagePath',
      ImagePath
    ) and
    RegQueryDWordValue(
      HKLM64,
      ServiceRegistryKey,
      'Start',
      StartType
    );
end;


function IsAllowedServiceExecutable(const ExecutablePath: String): Boolean;
var
  CurrentExecutable: String;
  PreviousExecutable: String;
  DefaultExecutable: String;
begin
  CurrentExecutable :=
    ExpandConstant('{app}\trusttunnel_service.exe');
  DefaultExecutable :=
    ExpandConstant('{autopf}\{#AppName}\trusttunnel_service.exe');

  Result :=
    PathsEqual(ExecutablePath, CurrentExecutable) or
    PathsEqual(ExecutablePath, DefaultExecutable);

  if (not Result) and (PreviousInstallDirectory <> '') then
  begin
    PreviousExecutable :=
      EnsureTrailingBackslash(PreviousInstallDirectory) +
      'trusttunnel_service.exe';
    Result := PathsEqual(ExecutablePath, PreviousExecutable);
  end;
end;

function IsOwnedServiceImagePath(const ImagePath: String): Boolean;
var
  ExecutablePath: String;
begin
  ExecutablePath := ExtractServiceExecutable(ImagePath);
  Result :=
    (ExecutablePath <> '') and
    IsAllowedServiceExecutable(ExecutablePath);
end;

function WaitForServiceState(
  const ExpectedState: Cardinal;
  const Attempts: Integer
): Boolean;
var
  Attempt: Integer;
  State: Cardinal;
begin
  for Attempt := 1 to Attempts do
  begin
    if QueryCurrentServiceState(State) and (State = ExpectedState) then
    begin
      Result := True;
      exit;
    end;
    Sleep(1000);
  end;

  Result := False;
end;

function StopServiceAndWait(var ErrorMessage: String): Boolean;
var
  Manager: THandle;
  Service: THandle;
  Status: TTrustTunnelServiceStatus;
  State: Cardinal;
begin
  Result := False;
  ErrorMessage := '';

  if not QueryCurrentServiceState(State) then
  begin
    ErrorMessage :=
      'Unable to query the TrustTunnel VPN service state.';
    exit;
  end;

  if State = ServiceStopped then
  begin
    Result := True;
    exit;
  end;

  if State = ServiceStopPending then
  begin
    if WaitForServiceState(ServiceStopped, 60) then
      Result := True
    else
      ErrorMessage :=
        'The TrustTunnel VPN service did not stop within 60 seconds.';
    exit;
  end;

  Manager := OpenSCManager(0, 0, ScManagerConnect);
  if Manager = 0 then
  begin
    ErrorMessage := 'Unable to open the Windows Service Control Manager.';
    exit;
  end;

  try
    Service := OpenService(
      Manager,
      ServiceName,
      ServiceQueryStatus or ServiceStop
    );
    if Service = 0 then
    begin
      ErrorMessage := 'Unable to open the TrustTunnel VPN service.';
      exit;
    end;

    try
      if not ControlService(Service, ServiceControlStop, Status) then
      begin
        if not QueryServiceStatus(Service, Status) then
        begin
          ErrorMessage := 'Unable to stop the TrustTunnel VPN service.';
          exit;
        end;

        if Status.CurrentState = ServiceStopped then
        begin
          Result := True;
          exit;
        end;

        if Status.CurrentState <> ServiceStopPending then
        begin
          ErrorMessage := 'Unable to stop the TrustTunnel VPN service.';
          exit;
        end;
      end;
    finally
      CloseServiceHandle(Service);
    end;
  finally
    CloseServiceHandle(Manager);
  end;

  if not WaitForServiceState(ServiceStopped, 60) then
  begin
    ErrorMessage :=
      'The TrustTunnel VPN service did not stop within 60 seconds.';
    exit;
  end;

  Result := True;
end;

function StartServiceAndWait(var ErrorMessage: String): Boolean;
var
  Manager: THandle;
  Service: THandle;
  State: Cardinal;
  Status: TTrustTunnelServiceStatus;
begin
  Result := False;
  ErrorMessage := '';

  if not QueryCurrentServiceState(State) then
  begin
    ErrorMessage :=
      'Unable to query the TrustTunnel VPN service state.';
    exit;
  end;

  if State = ServiceRunning then
  begin
    Result := True;
    exit;
  end;

  if State = ServiceStartPending then
  begin
    if WaitForServiceState(ServiceRunning, 60) then
      Result := True
    else
      ErrorMessage :=
        'The TrustTunnel VPN service did not start within 60 seconds.';
    exit;
  end;

  Manager := OpenSCManager(0, 0, ScManagerConnect);
  if Manager = 0 then
  begin
    ErrorMessage := 'Unable to open the Windows Service Control Manager.';
    exit;
  end;

  try
    Service := OpenService(
      Manager,
      ServiceName,
      ServiceQueryStatus or ServiceStart
    );
    if Service = 0 then
    begin
      ErrorMessage := 'Unable to open the TrustTunnel VPN service.';
      exit;
    end;

    try
      if not StartService(Service, 0, 0) then
      begin
        if not QueryServiceStatus(Service, Status) then
        begin
          ErrorMessage := 'Unable to start the TrustTunnel VPN service.';
          exit;
        end;

        if Status.CurrentState = ServiceRunning then
        begin
          Result := True;
          exit;
        end;

        if Status.CurrentState <> ServiceStartPending then
        begin
          ErrorMessage := 'Unable to start the TrustTunnel VPN service.';
          exit;
        end;
      end;
    finally
      CloseServiceHandle(Service);
    end;
  finally
    CloseServiceHandle(Manager);
  end;

  if not WaitForServiceState(ServiceRunning, 60) then
  begin
    ErrorMessage :=
      'The TrustTunnel VPN service did not start within 60 seconds.';
    exit;
  end;

  Result := True;
end;

function WaitForServiceRemoval: Boolean;
var
  Attempts: Integer;
begin
  for Attempts := 1 to 30 do
  begin
    if not ServiceExists then
    begin
      Result := True;
      exit;
    end;
    Sleep(1000);
  end;

  Result := False;
end;

function RemoveService(var ErrorMessage: String): Boolean;
var
  HelperPath: String;
  CurrentImagePath: String;
  CurrentStartType: Cardinal;
  ResultCode: Integer;
  StopError: String;
  CommandStarted: Boolean;
  ServiceStillExists: Boolean;
begin
  Result := True;
  ErrorMessage := '';

  if not ServiceExists then
    exit;

  if not ReadServiceConfiguration(CurrentImagePath, CurrentStartType) or
     not IsOwnedServiceImagePath(CurrentImagePath) then
  begin
    Result := False;
    ErrorMessage :=
      'A Windows service named TrustTunnelVPN already exists and does not ' +
      'belong to this installation. It was not changed.';
    exit;
  end;

  if not StopServiceAndWait(StopError) then
  begin
    if QueryServiceExistence(ServiceStillExists) and
       not ServiceStillExists then
      exit;

    Result := False;
    ErrorMessage := StopError;
    exit;
  end;
  if not ServiceExists then
    exit;

  HelperPath := ExpandConstant('{app}\trusttunnel_service_installer.exe');
  if not FileExists(HelperPath) then
    HelperPath :=
      ExpandConstant(
        '{tmp}\service_install\trusttunnel_service_installer.exe'
      );

  if FileExists(HelperPath) then
  begin
    ResultCode := -1;
    if Exec(
      HelperPath,
      'uninstall "' + ServiceName + '"',
      ExtractFileDir(HelperPath),
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    ) and (ResultCode = 0) and WaitForServiceRemoval then
      exit;
    if not ServiceExists then
      exit;
  end;

  ResultCode := -1;
  CommandStarted := Exec(
    ExpandConstant('{sys}\sc.exe'),
    'delete "' + ServiceName + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  if not ServiceExists then
    exit;

  if (not CommandStarted) or
     (ResultCode <> 0) or
     not WaitForServiceRemoval then
  begin
    Result := False;
    ErrorMessage :=
      'Unable to remove the TrustTunnel VPN service. Restart Windows and ' +
      'run Setup again.';
  end;
end;

function ChangeExistingServiceConfiguration(
  const ImagePath: String;
  const StartType: Cardinal;
  var ErrorMessage: String
): Boolean;
var
  Manager: THandle;
  Service: THandle;
begin
  Result := False;
  ErrorMessage := '';
  Manager := OpenSCManager(0, 0, ScManagerConnect);
  if Manager = 0 then
  begin
    ErrorMessage := 'Unable to open the Windows Service Control Manager.';
    exit;
  end;

  try
    Service := OpenService(
      Manager,
      ServiceName,
      ServiceQueryStatus or ServiceChangeConfig
    );
    if Service = 0 then
    begin
      ErrorMessage := 'Unable to open the TrustTunnel VPN service.';
      exit;
    end;

    try
      if not ChangeServiceConfig(
        Service,
        ServiceNoChange,
        StartType,
        ServiceNoChange,
        ImagePath,
        0,
        0,
        0,
        0,
        0,
        0
      ) then
      begin
        ErrorMessage :=
          'Unable to update the TrustTunnel VPN service configuration.';
        exit;
      end;
    finally
      CloseServiceHandle(Service);
    end;
  finally
    CloseServiceHandle(Manager);
  end;

  Result := True;
end;

function BuildExpectedServiceImagePath: String;
begin
  Result :=
    '"' + ExpandConstant('{app}\trusttunnel_service.exe') + '" ' +
    '"' + ExpandConstant('{commonappdata}\TrustTunnel\logs') + '" ' +
    '"\\.\pipe\trusttunnel_vpn" ' +
    '"' +
      ExpandConstant('{commonappdata}\TrustTunnel\vpn_query_log.ring') +
    '"';
end;

function RunServiceInstallHelper(var ErrorMessage: String): Boolean;
var
  HelperPath: String;
  Parameters: String;
begin
  Result := False;
  ErrorMessage := '';
  ExtractTemporaryFiles('service_install\*');

  HelperPath := ExpandConstant(
    '{tmp}\service_install\trusttunnel_service_installer.exe'
  );
  Parameters :=
    'install ' +
    '"' + ExpandConstant('{app}\trusttunnel_service.exe') + '" ' +
    '"' + ExpandConstant('{commonappdata}\TrustTunnel\logs') + '" ' +
    '"\\.\pipe\trusttunnel_vpn" ' +
    '"' + ServiceName + '" ' +
    '"TrustTunnel VPN Service" ' +
    '"Provides VPN connectivity for the TrustTunnel client." ' +
    '"' + ExpandConstant(
      '{commonappdata}\TrustTunnel\vpn_query_log.ring'
    ) + '"';

  ServiceHelperWasRun := True;
  ServiceHelperExitCode := -1;
  if not Exec(
    HelperPath,
    Parameters,
    ExtractFileDir(HelperPath),
    SW_HIDE,
    ewWaitUntilTerminated,
    ServiceHelperExitCode
  ) then
  begin
    ErrorMessage :=
      'Unable to launch the TrustTunnel VPN service installer: ' +
      SysErrorMessage(ServiceHelperExitCode);
    exit;
  end;

  Log(
    '[service] Service installer helper exit code: ' +
    IntToStr(ServiceHelperExitCode)
  );

  if ServiceHelperExitCode <> 0 then
  begin
    ErrorMessage :=
      'Unable to install the TrustTunnel VPN service. Error code: ' +
      IntToStr(ServiceHelperExitCode);
    exit;
  end;

  Result := True;
end;

function ReadPeMachine(
  const FileName: String;
  var Machine: Cardinal
): Boolean;
var
  Stream: TFileStream;
  DosHeader: AnsiString;
  PeHeader: AnsiString;
  PeOffset: Cardinal;
begin
  Result := False;
  Machine := 0;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(DosHeader, 64);
    if Stream.Read(DosHeader, 64) <> 64 then
      exit;
    if (DosHeader[1] <> 'M') or (DosHeader[2] <> 'Z') then
      exit;

    PeOffset :=
      Ord(DosHeader[61]) +
      (Ord(DosHeader[62]) * $100) +
      (Ord(DosHeader[63]) * $10000) +
      (Ord(DosHeader[64]) * $1000000);
    if (PeOffset < 64) or (PeOffset > Stream.Size - 6) then
      exit;

    Stream.Seek(PeOffset, soFromBeginning);
    SetLength(PeHeader, 6);
    if Stream.Read(PeHeader, 6) <> 6 then
      exit;
    if
      (PeHeader[1] <> 'P') or
      (PeHeader[2] <> 'E') or
      (Ord(PeHeader[3]) <> 0) or
      (Ord(PeHeader[4]) <> 0)
    then
      exit;

    Machine := Ord(PeHeader[5]) + (Ord(PeHeader[6]) * $100);
    Result := True;
  finally
    Stream.Free;
  end;
end;

function ServiceImagePathMatchesExpected(const ImagePath: String): Boolean;
var
  LowerImagePath: String;
begin
  LowerImagePath := LowerCase(ImagePath);
  Result :=
    PathsEqual(
      ExtractServiceExecutable(ImagePath),
      ExpandConstant('{app}\trusttunnel_service.exe')
    ) and
    (Pos(
      LowerCase(ExpandConstant('{commonappdata}\TrustTunnel\logs')),
      LowerImagePath
    ) > 0) and
    (Pos('\\.\pipe\trusttunnel_vpn', LowerImagePath) > 0) and
    (Pos(
      LowerCase(
        ExpandConstant(
          '{commonappdata}\TrustTunnel\vpn_query_log.ring'
        )
      ),
      LowerImagePath
    ) > 0);
end;


function ValidateInstalledService(var ErrorMessage: String): Boolean;
var
  CurrentImagePath: String;
  CurrentStartType: Cardinal;
  ServiceMachine: Cardinal;
  ServiceExecutable: String;
begin
  Result := False;
  ErrorMessage := '';

  if not ServiceExists then
  begin
    ErrorMessage := 'The TrustTunnel VPN service was not registered.';
    exit;
  end;

  ServiceExecutable := ExpandConstant('{app}\trusttunnel_service.exe');
  if not FileExists(ServiceExecutable) then
  begin
    ErrorMessage := 'The TrustTunnel VPN service executable was not installed.';
    exit;
  end;

  if not ReadServiceConfiguration(CurrentImagePath, CurrentStartType) then
  begin
    ErrorMessage :=
      'Unable to read the TrustTunnel VPN service configuration.';
    exit;
  end;

  if not ServiceImagePathMatchesExpected(CurrentImagePath) then
  begin
    ErrorMessage :=
      'The TrustTunnel VPN service has an unexpected executable path or ' +
      'command-line parameters.';
    exit;
  end;

  if CurrentStartType <> ServiceDemandStart then
  begin
    ErrorMessage :=
      'The TrustTunnel VPN service has an unexpected startup type.';
    exit;
  end;

  try
    if not ReadPeMachine(ServiceExecutable, ServiceMachine) then
    begin
      ErrorMessage :=
        'Unable to determine the TrustTunnel VPN service architecture.';
      exit;
    end;
  except
    ErrorMessage :=
      'Unable to inspect the TrustTunnel VPN service architecture: ' +
      GetExceptionMessage + '.';
    exit;
  end;

  if ServiceMachine <> ExpectedServiceMachine then
  begin
    ErrorMessage :=
      'The TrustTunnel VPN service architecture does not match this ' +
      'installer.';
    exit;
  end;

  if not DirExists(ExpandConstant('{commonappdata}\TrustTunnel\logs')) then
  begin
    ErrorMessage := 'The TrustTunnel log directory was not created.';
    exit;
  end;

  if not DirExists(
    ExtractFileDir(
      ExpandConstant('{commonappdata}\TrustTunnel\vpn_query_log.ring')
    )
  ) then
  begin
    ErrorMessage := 'The TrustTunnel ring-buffer directory was not created.';
    exit;
  end;

  if ServiceHelperWasRun and (ServiceHelperExitCode <> 0) then
  begin
    ErrorMessage :=
      'The TrustTunnel VPN service installer returned error code ' +
      IntToStr(ServiceHelperExitCode) + '.';
    exit;
  end;

  Result := True;
end;

function InstallOrUpdateService(var ErrorMessage: String): Boolean;
var
  CurrentImagePath: String;
  CurrentStartType: Cardinal;
  ExpectedImagePath: String;
begin
  Result := False;
  ErrorMessage := '';
  ExpectedImagePath := BuildExpectedServiceImagePath;

  if not ServiceExistedBeforeInstall then
  begin
    if not RunServiceInstallHelper(ErrorMessage) then
    begin
      if ServiceExists and
         ReadServiceConfiguration(CurrentImagePath, CurrentStartType) and
         IsOwnedServiceImagePath(CurrentImagePath) then
        ServiceCreatedByCurrentInstall := True;
      exit;
    end;

    if not ServiceExists then
    begin
      ErrorMessage := 'The TrustTunnel VPN service was not registered.';
      exit;
    end;

    if not ReadServiceConfiguration(CurrentImagePath, CurrentStartType) or
       not IsOwnedServiceImagePath(CurrentImagePath) then
    begin
      ErrorMessage :=
        'A Windows service named TrustTunnelVPN appeared during Setup and ' +
        'does not belong to this installation.';
      exit;
    end;

    ServiceCreatedByCurrentInstall := True;
  end
  else
  begin
    { The bundled helper only supports CreateService. Keep the existing
      service object (and its ACL) and update the mutable configuration
      directly through the Service Control Manager. }
    if not ServiceExists then
    begin
      ErrorMessage :=
        'The existing TrustTunnel VPN service disappeared during Setup.';
      exit;
    end;

    if not ReadServiceConfiguration(CurrentImagePath, CurrentStartType) or
       not IsOwnedServiceImagePath(CurrentImagePath) then
    begin
      ErrorMessage :=
        'The TrustTunnel VPN service configuration changed unexpectedly ' +
        'during Setup.';
      exit;
    end;

    if
      (CompareText(CurrentImagePath, ExpectedImagePath) <> 0) or
      (CurrentStartType <> ServiceDemandStart)
    then
    begin
      if not ChangeExistingServiceConfiguration(
        ExpectedImagePath,
        ServiceDemandStart,
        ErrorMessage
      ) then
        exit;
      Log('[service] Existing service configuration was updated in place.');
    end;
  end;

  if not ValidateInstalledService(ErrorMessage) then
    exit;

  if ServiceExistedBeforeInstall and ServiceWasRunning then
  begin
    if not StartServiceAndWait(ErrorMessage) then
      exit;
  end;

  Log('[service] Installed service registration was verified.');
  Result := True;
end;

function InspectExistingService(var ErrorMessage: String): Boolean;
var
  State: Cardinal;
  ServiceExecutable: String;
begin
  Result := False;
  ErrorMessage := '';
  if not QueryServiceExistence(ServiceExistedBeforeInstall) then
  begin
    ErrorMessage :=
      'Setup could not determine whether the TrustTunnel VPN service ' +
      'exists. The service was not changed.';
    exit;
  end;
  ServiceWasRunning := False;
  OldServiceImagePath := '';
  OldServiceStartType := 0;

  if not ServiceExistedBeforeInstall then
  begin
    Log('[service] No existing TrustTunnelVPN service was found.');
    Result := True;
    exit;
  end;

  if not ReadServiceConfiguration(
    OldServiceImagePath,
    OldServiceStartType
  ) then
  begin
    ErrorMessage :=
      'A Windows service named TrustTunnelVPN exists, but Setup could not ' +
      'read its configuration. The service was not changed.';
    exit;
  end;

  ServiceExecutable := ExtractServiceExecutable(OldServiceImagePath);
  if not IsAllowedServiceExecutable(ServiceExecutable) then
  begin
    ErrorMessage :=
      'A Windows service named TrustTunnelVPN already exists and does not ' +
      'belong to this installation. The service was not changed.';
    exit;
  end;

  if not QueryCurrentServiceState(State) then
  begin
    ErrorMessage :=
      'Setup could not determine the current state of the TrustTunnel VPN ' +
      'service. The service was not changed.';
    exit;
  end;

  ServiceWasRunning := State <> ServiceStopped;
  Log('[service] Existing service executable: ' + ServiceExecutable);
  Log('[service] Existing service ImagePath: ' + OldServiceImagePath);
  Log('[service] Existing service start type: ' +
    IntToStr(OldServiceStartType));
  Log('[service] Existing service was running: ' +
    BooleanAsText(ServiceWasRunning));
  Result := True;
end;

