{ Shared with windows_update_lifecycle.h. Global objects cover all sessions;
  the installer owns the handle, so a crash cannot leave a stale lock. }
const
  InstallationLockName = 'Global\TrustTunnel.Installation';
  ProcessQueryLimitedInformation = $1000;
  SynchronizeAccess = $00100000;
  WaitObject0 = 0;
  WaitTimeout = 258;

type
  TProcessEntry = record
    Size: Cardinal;
    Usage: Cardinal;
    ProcessId: Cardinal;
    DefaultHeapId: UINT_PTR;
    ModuleId: Cardinal;
    Threads: Cardinal;
    ParentProcessId: Cardinal;
    Priority: Integer;
    Flags: Cardinal;
    ExeFile: array[0..259] of WideChar;
  end;
  TApplicationProcess = record
    Id: Cardinal;
    Handle: TInstallerHandle;
  end;

var
  InstallationLock: TInstallerHandle;
  ApplicationProcesses: array of TApplicationProcess;
  WindowSearchPid: Cardinal;
  ApplicationWindow: TInstallerHandle;
  WindowSearchCallback: TInstallerHandle;
  InitiatorHandle: TInstallerHandle;
  ReadyEvent: TInstallerHandle;

function CreateInstallationMutex(Security: TInstallerHandle; InitialOwner: Boolean; Name: String): TInstallerHandle;
external 'CreateMutexW@kernel32.dll stdcall';
function CloseHandle(Handle: TInstallerHandle): Boolean;
external 'CloseHandle@kernel32.dll stdcall';
function OpenProcess(Access: Cardinal; Inherit: Boolean; Id: Cardinal): TInstallerHandle;
external 'OpenProcess@kernel32.dll stdcall';
function QueryFullProcessImageName(Process: TInstallerHandle; Flags: Cardinal;
  Path: String; var Size: Cardinal): Boolean;
external 'QueryFullProcessImageNameW@kernel32.dll stdcall';
function WaitForSingleObject(Handle: TInstallerHandle; Milliseconds: Cardinal): Cardinal;
external 'WaitForSingleObject@kernel32.dll stdcall';
function ProcessIdToSessionId(Id: Cardinal; var SessionId: Cardinal): Boolean;
external 'ProcessIdToSessionId@kernel32.dll stdcall';
function GetCurrentProcessId: Cardinal;
external 'GetCurrentProcessId@kernel32.dll stdcall';
function GetTickCount: Cardinal;
external 'GetTickCount@kernel32.dll stdcall';
function CreateToolhelp32Snapshot(Flags, Id: Cardinal): TInstallerHandle;
external 'CreateToolhelp32Snapshot@kernel32.dll stdcall';
function Process32First(Snapshot: TInstallerHandle; var Entry: TProcessEntry): Boolean;
external 'Process32FirstW@kernel32.dll stdcall';
function Process32Next(Snapshot: TInstallerHandle; var Entry: TProcessEntry): Boolean;
external 'Process32NextW@kernel32.dll stdcall';
function EnumWindows(Callback: TInstallerHandle; Param: Integer): Boolean;
external 'EnumWindows@user32.dll stdcall';
function GetWindowThreadProcessId(Window: TInstallerHandle; var Id: Cardinal): Cardinal;
external 'GetWindowThreadProcessId@user32.dll stdcall';
function GetClassName(Window: TInstallerHandle; Name: String; Size: Integer): Integer;
external 'GetClassNameW@user32.dll stdcall';
function OpenEvent(Access: Cardinal; Inherit: Boolean; Name: String): TInstallerHandle;
external 'OpenEventW@kernel32.dll stdcall';
function SetEvent(Event: TInstallerHandle): Boolean;
external 'SetEvent@kernel32.dll stdcall';

function ProcessExecutable(Process: TInstallerHandle; var Path: String): Boolean;
var
  Size: Cardinal;
begin
  Size := 32768;
  SetLength(Path, Size);
  Result := QueryFullProcessImageName(Process, 0, Path, Size);
  if Result then SetLength(Path, Size) else Path := '';
end;

function AcquireInstallationLock(var ErrorMessage: String): Boolean;
var
  Error: Cardinal;
begin
  Result := True;
  if InstallationLock <> 0 then exit;
  InstallationLock := CreateInstallationMutex(0, False, InstallationLockName);
  Error := DLLGetLastError;
  if (InstallationLock = 0) or (Error = 183) then
  begin
    if InstallationLock <> 0 then CloseHandle(InstallationLock);
    InstallationLock := 0;
    ErrorMessage := 'Another TrustTunnel installation or uninstall is running.';
    Result := False;
  end
  else
    OperationStarted := True;
end;

procedure ReleaseInstallationLock;
begin
  if InstallationLock <> 0 then CloseHandle(InstallationLock);
  InstallationLock := 0;
end;

procedure ReleaseApplicationHandles;
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(ApplicationProcesses) - 1 do
    CloseHandle(ApplicationProcesses[I].Handle);
  SetArrayLength(ApplicationProcesses, 0);
  if InitiatorHandle <> 0 then CloseHandle(InitiatorHandle);
  InitiatorHandle := 0;
  if ReadyEvent <> 0 then CloseHandle(ReadyEvent);
  ReadyEvent := 0;
end;

function FindApplicationWindow(Window: TInstallerHandle; Param: Integer): BOOL;
var
  Id: Cardinal;
  ClassName: String;
  ClassNameLength: Integer;
begin
  Result := True;
  GetWindowThreadProcessId(Window, Id);
  if Id <> WindowSearchPid then exit;
  SetLength(ClassName, 128);
  ClassNameLength := GetClassName(Window, ClassName, 128);
  SetLength(ClassName, ClassNameLength);
  if ClassName = 'FLUTTER_RUNNER_WIN32_WINDOW' then
  begin
    ApplicationWindow := Window;
    Result := False;
  end;
end;

function CollectApplicationProcesses(var ErrorMessage: String): Boolean;
var
  Snapshot, Process: TInstallerHandle;
  Entry: TProcessEntry;
  Name, Path: String;
  I, Count: Integer;
  Session, SetupSession: Cardinal;
begin
  Result := False;
  { Preserve the initiator handle separately to protect against PID reuse. }
  for I := 0 to GetArrayLength(ApplicationProcesses) - 1 do
    CloseHandle(ApplicationProcesses[I].Handle);
  SetArrayLength(ApplicationProcesses, 0);
  if not ProcessIdToSessionId(GetCurrentProcessId, SetupSession) then
  begin
    ErrorMessage := 'Unable to determine the installer session.';
    exit;
  end;
  Snapshot := CreateToolhelp32Snapshot(2, 0);
  if Snapshot = TInstallerHandle(-1) then
  begin
    ErrorMessage := 'Unable to enumerate running applications.';
    exit;
  end;
  try
    Entry.Size := SizeOf(Entry);
    if not Process32First(Snapshot, Entry) then
    begin
      ErrorMessage := 'Unable to read the process list.';
      exit;
    end;
    repeat
      Name := '';
      for I := 0 to 259 do
      begin
        if Entry.ExeFile[I] = #0 then break;
        Name := Name + Entry.ExeFile[I];
      end;
      if CompareText(Name, '{#AppExeName}') = 0 then
      begin
        Process := OpenProcess(ProcessQueryLimitedInformation or SynchronizeAccess,
          False, Entry.ProcessId);
        if Process = 0 then
        begin
          { A process which exited during enumeration is harmless. }
          if DLLGetLastError <> 87 then
          begin
            ErrorMessage := 'Unable to inspect a running TrustTunnel process. Close it and retry.';
            exit;
          end;
        end
        else
        begin
          if WaitForSingleObject(Process, 0) = WaitObject0 then CloseHandle(Process)
          else if not ProcessExecutable(Process, Path) then
          begin
            CloseHandle(Process);
            ErrorMessage := 'Unable to verify the executable of a running TrustTunnel process.';
            exit;
          end
          else if not PathsEqual(Path, ExpandConstant('{app}\{#AppExeName}')) then
            CloseHandle(Process)
          else
          begin
            if not ProcessIdToSessionId(Entry.ProcessId, Session) or
               (Session <> SetupSession) then
            begin
              CloseHandle(Process);
              ErrorMessage := 'TrustTunnel is running in another Windows session. Close it in that session and retry.';
              exit;
            end;
            Count := GetArrayLength(ApplicationProcesses);
            SetArrayLength(ApplicationProcesses, Count + 1);
            ApplicationProcesses[Count].Id := Entry.ProcessId;
            ApplicationProcesses[Count].Handle := Process;
          end;
        end;
      end;
    until not Process32Next(Snapshot, Entry);
    if DLLGetLastError <> 18 then
    begin
      ErrorMessage := 'Process enumeration did not complete.';
      exit;
    end;
    Result := True;
  finally
    CloseHandle(Snapshot);
  end;
end;

function PrepareApplicationExit(AllowExit, FromApplication: Boolean;
  var ErrorMessage: String): Boolean;
var
  I: Integer;
  Started, Message: Cardinal;
  Requested, AllExited: Boolean;
begin
  Result := False;
  if not CollectApplicationProcesses(ErrorMessage) then exit;
  if (GetArrayLength(ApplicationProcesses) > 0) and not AllowExit then
  begin
    ErrorMessage := 'TrustTunnel is running from the target directory. Close it before installing or uninstalling.';
    exit;
  end;
  { Silent installation over a registered version is still an update.
    Suppressed message boxes must not turn its confirmation into a refusal. }
  if AllowExit and not FromApplication and not WizardSilent and not GuiExited then
  begin
    if SuppressibleMsgBox('Updating TrustTunnel will interrupt the VPN connection and close the application. Continue?',
      mbConfirmation, MB_YESNO, IDNO) <> IDYES then
    begin
      ErrorMessage := 'The update was cancelled before stopping the VPN.';
      exit;
    end;
  end;
  if FromApplication and not GuiExited then
  begin
    if (WaitForSingleObject(InitiatorHandle, 0) <> WaitTimeout) or
       not SetEvent(ReadyEvent) then
    begin
      ErrorMessage := 'The update initiator exited or the readiness handshake failed.';
      exit;
    end;
  end;
  Message := RegisterWindowMessage('TrustTunnel.ExitForUpdate');
  if Message = 0 then
  begin
    ErrorMessage := 'Unable to register the update exit message.';
    exit;
  end;
  if WindowSearchCallback = 0 then
    WindowSearchCallback := CreateCallback(@FindApplicationWindow);
  Started := GetTickCount;
  repeat
    AllExited := True;
    for I := 0 to GetArrayLength(ApplicationProcesses) - 1 do
    begin
      if WaitForSingleObject(ApplicationProcesses[I].Handle, 0) <> WaitObject0 then
      begin
        AllExited := False;
        WindowSearchPid := ApplicationProcesses[I].Id;
        ApplicationWindow := 0;
        EnumWindows(WindowSearchCallback, 0);
        if ApplicationWindow <> 0 then
        begin
          Requested := PostMessage(ApplicationWindow, Message, GetCurrentProcessId, 0);
          if not Requested then
          begin
            ErrorMessage := 'Unable to request TrustTunnel shutdown. Close the application and retry.';
            exit;
          end;
        end;
      end;
    end;
    if AllExited then break;
    Sleep(100);
  until GetTickCount - Started >= 30000;
  if not AllExited then
  begin
    ErrorMessage := 'TrustTunnel did not exit within 30 seconds. No application files were replaced.';
    exit;
  end;
  if GetArrayLength(ApplicationProcesses) > 0 then GuiExited := True;
  { Catch a process already starting when the global lock was acquired. }
  if not CollectApplicationProcesses(ErrorMessage) then exit;
  if GetArrayLength(ApplicationProcesses) > 0 then
  begin
    ErrorMessage := 'A new TrustTunnel process appeared during update preparation. Retry the installation.';
    exit;
  end;
  Result := True;
end;
