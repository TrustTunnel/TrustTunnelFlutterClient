function CopyDirectoryTree(
  const SourceDirectory: String;
  const DestinationDirectory: String
): Boolean;
var
  FindRec: TFindRec;
  SourcePath: String;
  DestinationPath: String;
begin
  Result := True;
  if not DirExists(SourceDirectory) then
    exit;

  if not ForceDirectories(DestinationDirectory) then
  begin
    Result := False;
    exit;
  end;

  if FindFirst(EnsureTrailingBackslash(SourceDirectory) + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
        begin
          SourcePath :=
            EnsureTrailingBackslash(SourceDirectory) + FindRec.Name;
          DestinationPath :=
            EnsureTrailingBackslash(DestinationDirectory) + FindRec.Name;

          if (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
          begin
            Log('[rollback] Refusing to follow reparse point: ' + SourcePath);
            Result := False;
            exit;
          end;

          if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          begin
            if not CopyDirectoryTree(
              SourcePath,
              DestinationPath
            ) then
            begin
              Result := False;
              exit;
            end;
          end
          else
          begin
            if not CopyFile(SourcePath, DestinationPath, False) then
            begin
              Log('[rollback] Unable to copy: ' + SourcePath);
              Result := False;
              exit;
            end;
          end;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

function CopyDirectoryContents(
  const SourceDirectory: String;
  const DestinationDirectory: String
): Boolean;
begin
  Result := CopyDirectoryTree(
    SourceDirectory,
    DestinationDirectory
  );
end;


type
  TRollbackSecurityAttributes = record
    Length: Cardinal;
    Descriptor: TInstallerHandle;
    Inherit: Integer;
  end;

function GenerateRollbackGuid(var Id: TGUID): Integer;
external 'CoCreateGuid@ole32.dll stdcall';
function FormatRollbackGuid(var Id: TGUID; Buffer: String; Count: Integer): Integer;
external 'StringFromGUID2@ole32.dll stdcall';
function RollbackSecurityDescriptor(Value: String; Revision: Cardinal;
  var Descriptor: TInstallerHandle; Size: TInstallerHandle): Boolean;
external 'ConvertStringSecurityDescriptorToSecurityDescriptorW@advapi32.dll stdcall';
function CreateProtectedRollbackDirectory(Path: String;
  var Security: TRollbackSecurityAttributes): Boolean;
external 'CreateDirectoryW@kernel32.dll stdcall';
function FreeRollbackSecurity(Memory: TInstallerHandle): TInstallerHandle;
external 'LocalFree@kernel32.dll stdcall';

function CreateRollbackDirectory: Boolean;
var
  Id: TGUID;
  Name: String;
  GuidLength: Integer;
  Security: TRollbackSecurityAttributes;
begin
  Result := False;
  if GenerateRollbackGuid(Id) <> 0 then exit;
  SetLength(Name, 40);
  GuidLength := FormatRollbackGuid(Id, Name, 40);
  if GuidLength = 0 then exit;
  SetLength(Name, GuidLength - 1);
  RollbackDirectory := ExpandConstant('{commonappdata}\TrustTunnelInstaller-rollback-') + Name;
  Security.Length := SizeOf(Security);
  Security.Inherit := 0;
  { Snapshots become executable files and privileged registry data on rollback.
    Create an exclusive directory with an administrator owner and inherited
    admin/SYSTEM-only ACL, rather than trusting a pre-existing shared folder. }
  if not RollbackSecurityDescriptor(
    'O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)', 1, Security.Descriptor, 0) then exit;
  try
    Result := CreateProtectedRollbackDirectory(RollbackDirectory, Security);
  finally
    FreeRollbackSecurity(Security.Descriptor);
  end;
  if not Result then RollbackDirectory := '';
end;

function DeleteRollbackSnapshot: Boolean;
begin
  if RollbackDirectory = '' then
  begin
    Result := True;
    exit;
  end;

  if DirExists(RollbackDirectory) then
    Result := DelTree(RollbackDirectory, True, True, True)
  else
    Result := True;
end;

function RunRegistryTool(const Parameters: String): Boolean;
var
  Code: Integer;
#if Ver < 0x07000000
  RedirectionWasEnabled: Boolean;
#endif
begin
#if Ver >= 0x07000000
  Result := ExecWithNativeSysDir(ExpandConstant('{sys}\reg.exe'), Parameters,
    '', SW_HIDE, ewWaitUntilTerminated, Code);
  Result := Result and (Code = 0);
#else
  RedirectionWasEnabled := EnableFsRedirection(False);
  try
    Result := Exec(ExpandConstant('{sys}\reg.exe'), Parameters,
      '', SW_HIDE, ewWaitUntilTerminated, Code);
    Result := Result and (Code = 0);
  finally
    EnableFsRedirection(RedirectionWasEnabled);
  end;
#endif
end;

function SaveInstallationMetadata(var ErrorMessage: String): Boolean;
begin
  Result := RunRegistryTool('export "HKLM\' + AppUninstallRegistryKey +
    '" "' + RollbackDirectory + '\uninstall.reg" /y');
  if RegKeyExists(HKLM64, 'Software\Classes\tt') then
    Result := RunRegistryTool('export "HKLM\Software\Classes\tt" "' +
      RollbackDirectory + '\protocol.reg" /y') and Result;
  if not Result then
    ErrorMessage := 'Unable to back up installation registry metadata.';
end;

function RestoreInstallationMetadata(var ErrorMessage: String): Boolean;
begin
  Result := True;
  { Inno's own failure cleanup may already have removed this key. }
  if RegKeyExists(HKLM64, AppUninstallRegistryKey) then
    Result := RegDeleteKeyIncludingSubkeys(HKLM64, AppUninstallRegistryKey);
  Result := RunRegistryTool('import "' + RollbackDirectory +
    '\uninstall.reg" /reg:64') and Result;
  if RegKeyExists(HKLM64, 'Software\Classes\tt') then
    Result := RegDeleteKeyIncludingSubkeys(HKLM64, 'Software\Classes\tt') and Result;
  if FileExists(RollbackDirectory + '\protocol.reg') then
    Result := RunRegistryTool('import "' + RollbackDirectory +
      '\protocol.reg" /reg:64') and Result;
  if not Result then
    ErrorMessage := 'Unable to restore installation registry metadata. Snapshot: ' + RollbackDirectory;
end;

function CreateRollbackSnapshot(var ErrorMessage: String): Boolean;
begin
  Result := False;
  ErrorMessage := '';

  if not CreateRollbackDirectory then
  begin
    ErrorMessage := 'Unable to create a protected installation rollback directory.';
    exit;
  end;

  if not ForceDirectories(RollbackDirectory + '\bundle') then
  begin
    DeleteRollbackSnapshot;
    ErrorMessage := 'Unable to create the installation rollback directory.';
    exit;
  end;

  Log('[rollback] Saving previous installation to: ' + RollbackDirectory);
  if DirExists(ExpandConstant('{app}')) and
     not CopyDirectoryTree(
       ExpandConstant('{app}'),
       RollbackDirectory + '\bundle'
     ) then
  begin
    ErrorMessage := 'Unable to back up the installed application files.';
    DeleteRollbackSnapshot;
    RollbackDirectory := '';
    exit;
  end;


  if not SaveInstallationMetadata(ErrorMessage) then
  begin
    DeleteRollbackSnapshot;
    exit;
  end;
  Result := True;
end;

function RestorePreviousInstallation(var ErrorMessage: String): Boolean;
var
  CurrentImagePath: String;
  CurrentStartType: Cardinal;
  OperationError: String;
  RestoredImagePath: String;
  RestoredStartType: Cardinal;
begin
  Result := False;
  ErrorMessage := '';
  Log('[rollback] Restoring previous installation from: ' +
    RollbackDirectory);

  if ServiceExists then
  begin
    if not ReadServiceConfiguration(CurrentImagePath, CurrentStartType) or
       not IsOwnedServiceImagePath(CurrentImagePath) then
    begin
      ErrorMessage :=
        'The service no longer belongs to TrustTunnel; Setup did not ' +
        'modify it. Rollback files were preserved at: ' + RollbackDirectory;
      exit;
    end;

    if not StopServiceAndWait(OperationError) then
    begin
      ErrorMessage := OperationError + ' Rollback files were preserved at: ' +
        RollbackDirectory;
      exit;
    end;
  end;

  if DirExists(ExpandConstant('{app}')) and
     not DelTree(ExpandConstant('{app}'), True, True, True) then
  begin
    ErrorMessage :=
      'Unable to remove the incomplete application files. Rollback files ' +
      'were preserved at: ' + RollbackDirectory;
    exit;
  end;

  if not CopyDirectoryContents(
    RollbackDirectory + '\bundle',
    ExpandConstant('{app}')
  ) then
  begin
    ErrorMessage :=
      'Unable to restore the previous application files. Rollback files ' +
      'were preserved at: ' + RollbackDirectory;
    exit;
  end;

  if not ServiceExistedBeforeInstall then
  begin
    if not RemoveService(OperationError) then
    begin
      ErrorMessage := OperationError;
      exit;
    end;
  end
  else
  begin
    if not ServiceExists then
    begin
      { The restored helper belongs to the previous service architecture. }
      if not RunServiceInstallHelper(True, OperationError) then
      begin
        ErrorMessage :=
          'Unable to recreate the previous service: ' + OperationError +
          ' Rollback files were preserved at: ' + RollbackDirectory;
        exit;
      end;

      { The helper starts a newly created service. Stop it before restoring
        the old configuration and previous running/stopped state. }
      if not StopServiceAndWait(OperationError) then
      begin
        ErrorMessage := OperationError + ' Rollback files were preserved at: ' +
          RollbackDirectory;
        exit;
      end;
    end;

    if not ChangeExistingServiceConfiguration(
      OldServiceImagePath,
      OldServiceStartType,
      OperationError
    ) then
    begin
      ErrorMessage := OperationError + ' Rollback files were preserved at: ' +
        RollbackDirectory;
      exit;
    end;

    if not ReadServiceConfiguration(
      RestoredImagePath,
      RestoredStartType
    ) or
       (CompareText(RestoredImagePath, OldServiceImagePath) <> 0) or
       (RestoredStartType <> OldServiceStartType) then
    begin
      ErrorMessage :=
        'The previous service configuration could not be verified. Rollback ' +
        'files were preserved at: ' + RollbackDirectory;
      exit;
    end;

    if ServiceWasRunning and not StartServiceAndWait(OperationError) then
    begin
      ErrorMessage := OperationError + ' Rollback files were preserved at: ' +
        RollbackDirectory;
      exit;
    end;
  end;

  if not RestoreInstallationMetadata(ErrorMessage) then exit;

  if DeleteRollbackSnapshot then
    Log('[rollback] Previous installation was restored successfully.')
  else
    Log(
      '[rollback] Previous installation was restored, but the rollback ' +
      'directory could not be removed: ' + RollbackDirectory
    );
  SnapshotReady := False;
  Result := True;
end;
