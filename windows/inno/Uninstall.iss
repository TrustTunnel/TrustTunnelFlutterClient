function InitializeUninstall: Boolean;
var
  ErrorMessage: String;
begin
  { Return False before uninstallation starts; do not rely on exceptions from
    progress notifications to protect files belonging to a running GUI. }
  Result := AcquireInstallationLock(ErrorMessage) and
    PrepareApplicationExit(False, False, ErrorMessage);
  if not Result then
  begin
    SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    ReleaseApplicationHandles;
    ReleaseInstallationLock;
    ReleaseResultPublicationLock;
  end;
end;

procedure SelectUninstallOptions;
var
  OptionsForm: TSetupForm;
  DeleteUserDataCheckBox: TNewCheckBox;
  ExplanationLabel: TNewStaticText;
  ContinueButton: TNewButton;
  CancelButton: TNewButton;
begin
  OptionsForm := CreateCustomForm(ScaleX(500), ScaleY(165), False, False);
  try
    OptionsForm.Caption := 'Uninstall TrustTunnel';
    OptionsForm.Position := poScreenCenter;

    DeleteUserDataCheckBox := TNewCheckBox.Create(OptionsForm);
    DeleteUserDataCheckBox.Parent := OptionsForm;
    DeleteUserDataCheckBox.Left := ScaleX(20);
    DeleteUserDataCheckBox.Top := ScaleY(20);
    DeleteUserDataCheckBox.Width := OptionsForm.ClientWidth - ScaleX(40);
    DeleteUserDataCheckBox.Caption :=
      'Also delete settings and server configurations';
    DeleteUserDataCheckBox.Checked := False;

    ExplanationLabel := TNewStaticText.Create(OptionsForm);
    ExplanationLabel.Parent := OptionsForm;
    ExplanationLabel.Left := ScaleX(40);
    ExplanationLabel.Top := ScaleY(50);
    ExplanationLabel.Width := OptionsForm.ClientWidth - ScaleX(60);
    ExplanationLabel.Height := ScaleY(56);
    ExplanationLabel.AutoSize := False;
    ExplanationLabel.WordWrap := True;
    ExplanationLabel.Caption :=
      'Logs and temporary files are always removed. ' +
      'Leave this unchecked if you plan to reinstall the app.';

    ContinueButton := TNewButton.Create(OptionsForm);
    ContinueButton.Parent := OptionsForm;
    ContinueButton.Width := ScaleX(90);
    ContinueButton.Height := ScaleY(25);
    ContinueButton.Left :=
      OptionsForm.ClientWidth - ContinueButton.Width - ScaleX(20);
    ContinueButton.Top :=
      OptionsForm.ClientHeight - ContinueButton.Height - ScaleY(15);
    ContinueButton.Caption := 'Continue';
    ContinueButton.Default := True;
    ContinueButton.ModalResult := mrOk;

    CancelButton := TNewButton.Create(OptionsForm);
    CancelButton.Parent := OptionsForm;
    CancelButton.Width := ScaleX(90);
    CancelButton.Height := ScaleY(25);
    CancelButton.Left := ContinueButton.Left - CancelButton.Width - ScaleX(10);
    CancelButton.Top := ContinueButton.Top;
    CancelButton.Caption := 'Cancel';
    CancelButton.Cancel := True;
    CancelButton.ModalResult := mrCancel;

    OptionsForm.ActiveControl := DeleteUserDataCheckBox;
    if OptionsForm.ShowModal <> mrOk then
      Abort;
    DeleteUserData := DeleteUserDataCheckBox.Checked;
  finally
    OptionsForm.Free;
  end;
end;

procedure LogCleanupOutput(const Output: TExecOutput);
var
  Index: Integer;
begin
  for Index := 0 to GetArrayLength(Output.StdOut) - 1 do
    Log('[user-data cleanup] ' + Output.StdOut[Index]);
  for Index := 0 to GetArrayLength(Output.StdErr) - 1 do
    Log('[user-data cleanup] stderr: ' + Output.StdErr[Index]);
  if Output.Error then
    Log('[user-data cleanup] Some cleanup output could not be captured.');
end;

procedure ShowCleanupWarning(const MessageText: String);
begin
  Log('[user-data cleanup] ' + MessageText);
  SuppressibleMsgBox(
    MessageText + #13#10 + #13#10 +
      'The application uninstall will continue, but some user data may remain.',
    mbError,
    MB_OK,
    IDOK
  );
end;

procedure CleanupUninstallData(const UserSid: String;
  DeleteSettingsAndServers: Boolean);
var
  CleanupPath: String;
  Parameters: String;
  ResultCode: Integer;
  Output: TExecOutput;
begin
  CleanupPath := ExpandConstant('{app}\cleanup_user_data_helper.exe');

  if not FileExists(CleanupPath) then
  begin
    ShowCleanupWarning('The user-data cleanup utility was not found.');
    exit;
  end;

  if DeleteSettingsAndServers then
    Parameters := '/DELETEUSERDATA=1'
  else
    Parameters := '/DELETEUSERDATA=0';
  if UserSid <> '' then
    Parameters := Parameters + ' /USERSID="' + UserSid + '"';

  ResultCode := -1;
  try
    if not ExecAndCaptureOutput(
      CleanupPath,
      Parameters,
      ExtractFileDir(CleanupPath),
      SW_SHOWNORMAL,
      ewWaitUntilTerminated,
      ResultCode,
      Output
    ) then
    begin
      ShowCleanupWarning(
        'Unable to start the user-data cleanup utility. Windows error: ' +
        IntToStr(ResultCode) + ' (' + SysErrorMessage(ResultCode) + ').'
      );
      exit;
    end;
  except
    ShowCleanupWarning(
      'Unable to capture the user-data cleanup result: ' +
      GetExceptionMessage + '.'
    );
    exit;
  end;

  LogCleanupOutput(Output);

  case ResultCode of
    0:
      begin
        if DeleteSettingsAndServers then
          Log('[user-data cleanup] Logs, temporary files, settings, and ' +
            'server configurations were removed.')
        else
          Log('[user-data cleanup] Logs and temporary files were removed; ' +
            'settings and server configurations were preserved.');
      end;
    1:
      ShowCleanupWarning(
        'Some TrustTunnel user-data paths could not be removed.'
      );
    2:
      ShowCleanupWarning(
        'The target Windows user or profile could not be resolved.'
      );
    3:
      ShowCleanupWarning(
        'An unsafe cleanup path was skipped.'
      );
  else
    ShowCleanupWarning(
      'The user-data cleanup utility failed with exit code ' +
      IntToStr(ResultCode) + '.'
    );
  end;
end;

procedure RemoveInstalledAutostart(const UserSid: String);
var
  CleanupPath, Parameters: String;
  ResultCode: Integer;
  Output: TExecOutput;
  Succeeded: Boolean;
begin
  CleanupPath := ExpandConstant('{app}\cleanup_user_data_helper.exe');
  Parameters := '/REMOVEAUTOSTART="' + ExpandConstant('{app}\{#AppExeName}') + '"';
  if UserSid <> '' then Parameters := Parameters + ' /USERSID="' + UserSid + '"';
  ResultCode := -1;
  Succeeded := False;
  try
    Succeeded := ExecAndCaptureOutput(CleanupPath, Parameters,
      ExtractFileDir(CleanupPath), SW_HIDE, ewWaitUntilTerminated,
      ResultCode, Output);
    if Succeeded then LogCleanupOutput(Output);
  except
    Log('[autostart cleanup] ' + GetExceptionMessage);
  end;
  if not Succeeded or (ResultCode <> 0) then
  begin
    Log('[autostart cleanup] Failed: ' + IntToStr(ResultCode));
    SuppressibleMsgBox(
      'Unable to remove all TrustTunnel login startup registrations. Error code: ' +
      IntToStr(ResultCode) + '. The uninstall will continue; see the uninstall log for details.',
      mbError, MB_OK, IDOK);
  end;
end;


procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ErrorMessage: String;
  UserSid: String;
begin
  if (CurUninstallStep <> usUninstall) or UninstallPrepared then
    exit;
  UninstallPrepared := True;

  DeleteUserData := False;
  UserSid := ExpandConstant('{param:USERSID|}');
  if UninstallSilent then
  begin
    if CompareText(
      ExpandConstant('{param:DELETEUSERDATA|0}'),
      '1'
    ) = 0 then
    begin
      if UserSid = '' then
        Log(
          '[user-data cleanup] /DELETEUSERDATA=1 was ignored because ' +
          '/USERSID was not provided for silent uninstall.'
        )
      else
        DeleteUserData := True;
    end;
  end
  else
    SelectUninstallOptions;

  ReadPreviousInstallDirectory;
  if not AcquireInstallationLock(ErrorMessage) or
     not PrepareApplicationExit(False, False, ErrorMessage) then
  begin
    SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    Abort;
  end;
  if not RemoveService(ErrorMessage) then
  begin
    SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    Abort;
  end;

  RemoveInstalledAutostart(UserSid);
  CleanupUninstallData(UserSid, DeleteUserData);
end;

procedure DeinitializeUninstall;
begin
  ReleaseApplicationHandles;
  ReleaseInstallationLock;
  ReleaseResultPublicationLock;
end;
