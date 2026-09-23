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

          if
            (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0
          then
          begin
            if
              (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0
            then
            begin
              Log(
                '[rollback] Refusing to follow reparse point: ' +
                SourcePath
              );
              Result := False;
              exit;
            end;

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


function GetRollbackRootDirectory: String;
begin
  Result := ExpandConstant(
    '{commonappdata}\TrustTunnelInstaller\rollback'
  );
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

  if Result then
  begin
    RemoveDir(GetRollbackRootDirectory);
    RemoveDir(ExtractFileDir(GetRollbackRootDirectory));
  end;
end;

function CreateRollbackSnapshot(var ErrorMessage: String): Boolean;
var
  BaseDirectory: String;
  CandidateDirectory: String;
  Suffix: Integer;
begin
  Result := False;
  ErrorMessage := '';

  BaseDirectory :=
    EnsureTrailingBackslash(GetRollbackRootDirectory) +
    GetDateTimeString('yyyymmdd-hhnnss', '', '');
  CandidateDirectory := BaseDirectory;
  Suffix := 0;
  while DirExists(CandidateDirectory) do
  begin
    Suffix := Suffix + 1;
    CandidateDirectory := BaseDirectory + '-' + IntToStr(Suffix);
  end;
  RollbackDirectory := CandidateDirectory;

  if not ForceDirectories(RollbackDirectory + '\bundle') then
  begin
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

  RollbackReady := True;
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

  if not ServiceExists then
  begin
    if not RunServiceInstallHelper(OperationError) then
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

  if DeleteRollbackSnapshot then
    Log('[rollback] Previous installation was restored successfully.')
  else
    Log(
      '[rollback] Previous installation was restored, but the rollback ' +
      'directory could not be removed: ' + RollbackDirectory
    );
  RollbackReady := False;
  Result := True;
end;
