function MoveFileEx(const Existing, NewName: String; Flags: Cardinal): Boolean;
external 'MoveFileExW@kernel32.dll stdcall';

function ValidOperationId(const Value: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(Value) <> 32 then exit;
  for I := 1 to Length(Value) do
    if Pos(LowerCase(Value[I]), '0123456789abcdef') = 0 then exit;
  Result := True;
end;

function RestartPending: Boolean;
var
  Operations: String;
begin
  Result := VcRedistNeedsRestart or
    RegKeyExists(HKLM64, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') or
    RegKeyExists(HKLM64, 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired');
  if RegQueryMultiStringValue(HKLM64,
    'SYSTEM\CurrentControlSet\Control\Session Manager',
    'PendingFileRenameOperations', Operations) then
    Result := Result or (Length(Operations) > 2);
end;

procedure WriteOperationResult(const Status, MessageText: String);
var
  Path, TemporaryPath, Content, CleanMessage: String;
  Lines: TArrayOfString;
begin
  if not OperationStarted or (InstallationLock = 0) then exit;
  { Fixed machine metadata directory under protected Program Files. Unlike
    the VPN log directory, ordinary users cannot create a redirected .tmp
    file here for the elevated setup to overwrite. Never accept /RESULT paths. }
  Path := ExpandConstant('{autopf}\TrustTunnelInstaller\update-result.ini');
  TemporaryPath := Path + '.tmp';
  CleanMessage := MessageText;
  StringChangeEx(CleanMessage, #13, ' ', True);
  StringChangeEx(CleanMessage, #10, ' ', True);
  Content := '[update]' + #13#10 +
    'schema=1' + #13#10 +
    'operation=' + OperationId + #13#10 +
    'status=' + Status + #13#10 +
    'committed=' + BooleanAsText(InstallationCommitted) + #13#10 +
    'version={#AppVersion}' + #13#10 +
    'previous_version=' + PreviousVersion + #13#10 +
    'restart_required=' + BooleanAsText(RestartPending) + #13#10 +
    'time=' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10 +
    'message=' + CleanMessage + #13#10;
  SetArrayLength(Lines, 1);
  Lines[0] := Content;
  if not ForceDirectories(ExtractFileDir(Path)) or
     not SaveStringsToUTF8FileWithoutBOM(TemporaryPath, Lines, False) then
  begin
    Log('[update] Unable to write operation result.');
    exit;
  end;
  if not MoveFileEx(TemporaryPath, Path, 1 or 8) then
    Log('[update] Unable to publish operation result.');
end;

function InitializeUpdateMode: Boolean;
var
  ErrorMessage, Path, PidText: String;
  Session, SetupSession: Cardinal;
begin
  Result := False;
  AppInitiatedUpdate := ExpandConstant('{param:UPDATE|0}') = '1';
  ReadPreviousInstallDirectory;
  UpdateMode := RegKeyExists(HKLM64, AppUninstallRegistryKey);
  if not UpdateMode and
     (RegKeyExists(HKLM32, AppUninstallRegistryKey) or
      RegKeyExists(HKCU64, AppUninstallRegistryKey) or
      RegKeyExists(HKCU32, AppUninstallRegistryKey)) then
    ErrorMessage := 'A TrustTunnel installation is registered in an unsupported registry scope. Remove it before installing.'
  else if UpdateMode and
    ((PreviousInstallDirectory = '') or not DirExists(PreviousInstallDirectory) or
     not FileExists(AddBackslash(PreviousInstallDirectory) + '{#AppExeName}')) then
    ErrorMessage := 'The registered TrustTunnel installation is incomplete. Repair it before updating.'
  else if AppInitiatedUpdate and not UpdateMode then
    ErrorMessage := '/UPDATE=1 requires a valid previous TrustTunnel installation.';

  if (ErrorMessage = '') and UpdateMode then
  begin
    Path := ExpandConstant('{param:DIR|}');
    if (Path <> '') and not PathsEqual(Path, PreviousInstallDirectory) then
      ErrorMessage := 'An update must use the previous installation directory. Remove the conflicting /DIR parameter.';
  end;
  if (ErrorMessage = '') and AppInitiatedUpdate then
  begin
    OperationId := LowerCase(ExpandConstant('{param:OPERATION|}'));
    PidText := ExpandConstant('{param:INITIATORPID|}');
    InitiatorPid := StrToIntDef(PidText, 0);
    if (InitiatorPid = 0) or not ValidOperationId(OperationId) then
    begin
      OperationId := '';
      ErrorMessage := '/UPDATE=1 requires /INITIATORPID and a 32-character hexadecimal /OPERATION.';
    end
    else if (ExpandConstant('{param:TASKS|}') <> '') or
            (ExpandConstant('{param:MERGETASKS|}') <> '') then
      ErrorMessage := 'Application updates must preserve installation tasks. Remove /TASKS and /MERGETASKS.'
    else
    begin
      InitiatorHandle := OpenProcess(ProcessQueryLimitedInformation or SynchronizeAccess, False, InitiatorPid);
      if (InitiatorHandle = 0) or
         not ProcessExecutable(InitiatorHandle, Path) or
         not PathsEqual(Path, AddBackslash(PreviousInstallDirectory) + '{#AppExeName}') or
         not ProcessIdToSessionId(InitiatorPid, Session) or
         not ProcessIdToSessionId(GetCurrentProcessId, SetupSession) or
         (Session <> SetupSession) then
        ErrorMessage := 'The update initiator does not match the installed application in this Windows session.'
      else
      begin
        ReadyEvent := OpenEvent(2, False, 'Local\TrustTunnel.UpdateReady.' +
          IntToStr(InitiatorPid) + '.' + OperationId);
        if ReadyEvent = 0 then
          ErrorMessage := 'The update readiness event was not found.';
      end;
    end;
  end;
  if ErrorMessage <> '' then
  begin
    OperationError := ErrorMessage;
    Log('[update] ' + ErrorMessage);
    SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    exit;
  end;
  if UpdateMode then
  begin
    RegQueryStringValue(HKLM64, AppUninstallRegistryKey, 'DisplayVersion', PreviousVersion);
    RegQueryStringValue(HKLM64, AppUninstallRegistryKey,
      'Inno Setup: Selected Tasks', PreviousTasks);
  end;
  Result := True;
end;

procedure InitializeWizard;
begin
  if UpdateMode then WizardForm.DirEdit.Text := PreviousInstallDirectory;
end;

function ValidateUpdateInstallation(var ErrorMessage: String): Boolean;
var
  InstalledVersion, SetupVersion: Int64;
  RegisteredDirectory: String;
begin
  Result := False;
  if AppInitiatedUpdate then WizardSelectTasks(PreviousTasks);
  if UpdateMode then
  begin
    if not RegQueryStringValue(HKLM64, AppUninstallRegistryKey,
      'InstallLocation', RegisteredDirectory) or
       not PathsEqual(RegisteredDirectory, PreviousInstallDirectory) or
       not PathsEqual(ExpandConstant('{app}'), PreviousInstallDirectory) then
    begin
      ErrorMessage := 'The previous installation directory changed during setup.';
      exit;
    end;
    if not GetPackedVersion(ExpandConstant('{app}\{#AppExeName}'), InstalledVersion) or
       not GetPackedVersion(ExpandConstant('{srcexe}'), SetupVersion) then
    begin
      ErrorMessage := 'Unable to validate the installed application version.';
      exit;
    end;
    if ComparePackedVersion(InstalledVersion, SetupVersion) > 0 then
    begin
      ErrorMessage := 'Installing an older TrustTunnel version is not supported.';
      exit;
    end;
  end
  else if RegKeyExists(HKLM64, AppUninstallRegistryKey) then
  begin
    ErrorMessage := 'A TrustTunnel installation appeared during setup. Restart the installer.';
    exit;
  end;
  Result := True;
end;

procedure LaunchUpdatedApplication;
var
  ResultCode: Integer;
  Started: Boolean;
begin
  ResultCode := 0;
  try
    Started := ExecAsOriginalUser(ExpandConstant('{app}\{#AppExeName}'), '',
      ExpandConstant('{app}'), SW_SHOWNORMAL, ewNoWait, ResultCode);
  except
    Started := False;
    Log('[update] GUI launch exception: ' + GetExceptionMessage);
  end;
  if not Started then
  begin
    GuiLaunchFailed := True;
    Log('[update] Unable to launch GUI: ' + IntToStr(ResultCode));
    if InstallationCommitted then
      WriteOperationResult('launch_failed', 'The update succeeded, but Windows could not launch the GUI.')
    else
      WriteOperationResult('rollback_launch_failed', 'The previous version was restored, but Windows could not launch the GUI.');
  end;
end;
