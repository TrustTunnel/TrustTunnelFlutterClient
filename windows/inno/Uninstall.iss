procedure SelectUninstallOptions;
var
  OptionsForm: TSetupForm;
  DeleteUserDataCheckBox: TNewCheckBox;
  ExplanationLabel: TNewStaticText;
  ContinueButton: TNewButton;
  CancelButton: TNewButton;
begin
  OptionsForm := CreateCustomForm(ScaleX(440), ScaleY(145), False, False);
  try
    OptionsForm.Caption := 'Uninstall TrustTunnel';
    OptionsForm.Position := poScreenCenter;

    DeleteUserDataCheckBox := TNewCheckBox.Create(OptionsForm);
    DeleteUserDataCheckBox.Parent := OptionsForm;
    DeleteUserDataCheckBox.Left := ScaleX(20);
    DeleteUserDataCheckBox.Top := ScaleY(20);
    DeleteUserDataCheckBox.Width := OptionsForm.ClientWidth - ScaleX(40);
    DeleteUserDataCheckBox.Caption := 'Delete user data';
    DeleteUserDataCheckBox.Checked := False;

    ExplanationLabel := TNewStaticText.Create(OptionsForm);
    ExplanationLabel.Parent := OptionsForm;
    ExplanationLabel.Left := ScaleX(40);
    ExplanationLabel.Top := ScaleY(50);
    ExplanationLabel.Width := OptionsForm.ClientWidth - ScaleX(60);
    ExplanationLabel.Height := ScaleY(42);
    ExplanationLabel.AutoSize := False;
    ExplanationLabel.WordWrap := True;
    ExplanationLabel.Caption :=
      'Deletes settings, connection profiles, and logs for the current ' +
      'Windows user.';

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

procedure DeleteSelectedUserData(const UserSid: String);
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

  Parameters := '';
  if UserSid <> '' then
    Parameters := '/USERSID="' + UserSid + '"';

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
      Log('[user-data cleanup] All selected user data was removed.');
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
        'Cleanup was stopped because a computed path was outside the ' +
        'allowed cleanup directories.'
      );
  else
    ShowCleanupWarning(
      'The user-data cleanup utility failed with exit code ' +
      IntToStr(ResultCode) + '.'
    );
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
  UserSid := '';
  if UninstallSilent then
  begin
    if CompareText(
      ExpandConstant('{param:DELETEUSERDATA|0}'),
      '1'
    ) = 0 then
    begin
      UserSid := ExpandConstant('{param:USERSID|}');
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
  if not RemoveService(ErrorMessage) then
  begin
    SuppressibleMsgBox(ErrorMessage, mbCriticalError, MB_OK, IDOK);
    Abort;
  end;

  if DeleteUserData then
    DeleteSelectedUserData(UserSid);
end;
