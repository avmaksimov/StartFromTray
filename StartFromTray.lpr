program StartFromTray;

{$mode delphi}{$H+}

uses
  Interfaces, Forms, SysUtils, IniFiles, Windows,
  CommonU, frmConfig_U, FilterClass_U,
  frmExtensions_U, LangsU, MPPopupMenu,
  frmChooseExt_U;

{$R StartFromTray.res}

function M_AllowSetForegroundWindow(dwProcessId: DWORD): BOOL; stdcall;
  external 'user32.dll' name 'AllowSetForegroundWindow';

const
  cSingleInstanceMutexName =
    'Local\StartFromTray.{3A55B01F-07C3-4DC7-A7C0-C71A78C10B66}';
var
  MainIniFile: TIniFile;
  LangIndex: Integer;

  InstanceMutex: THandle;
  AlreadyRunning: Boolean;

  ExistingWindow: HWND;

function EnumStartFromTrayWindows(Wnd: HWND;
  {%H-}LParam: LPARAM): BOOL; stdcall;
begin
  Result := True;

  if Windows.GetProp(
    Wnd,
    PChar(cMainWindowPropertyName)
  ) <> 0 then
  begin
    ExistingWindow := Wnd;
    Result := False;
  end;
end;

function FindStartFromTrayWindow: HWND;
var
  I: Integer;
begin
  Result := 0;

  { Даём первому экземпляру до секунды на создание окна. }
  for I := 1 to 20 do
  begin
    ExistingWindow := 0;
    Windows.EnumWindows(@EnumStartFromTrayWindows, 0);

    if ExistingWindow <> 0 then
    begin
      Result := ExistingWindow;
      Exit;
    end;

    Windows.Sleep(50);
  end;
end;

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;

  // begin: show tray menu when launched again
  WM_SHOWTRAYMENU :=
    RegisterWindowMessage(cShowTrayMenuMessageName);
  if WM_SHOWTRAYMENU = 0 then
    RaiseLastOSError;

  InstanceMutex := CreateMutex(
    nil,
    False,
    PChar(cSingleInstanceMutexName)
  );

  if InstanceMutex = 0 then
    RaiseLastOSError;

  AlreadyRunning := GetLastError = ERROR_ALREADY_EXISTS;

  if AlreadyRunning then
  begin
    ExistingWindow := FindStartFromTrayWindow;

    if ExistingWindow = 0 then
    begin
      Windows.MessageBox(
        0,
        PChar('StartFromTray is running, but its window was not found.'),
        PChar('StartFromTray'),
        MB_OK or MB_ICONERROR
      );

      CloseHandle(InstanceMutex);
      Exit;
    end;

    M_AllowSetForegroundWindow(DWORD(-1));

    if not Windows.PostMessage(
      ExistingWindow,
      WM_SHOWTRAYMENU,
      0,
      0
    ) then
    begin
      CloseHandle(InstanceMutex);
      RaiseLastOSError;
    end;

    CloseHandle(InstanceMutex);
    Exit;
  end;
  // end: show tray menu when launched again

  with FormatSettings do
  begin
    DateSeparator := '.';
    TimeSeparator := ':';
    ShortDateFormat := 'dd/mm/yyyy';
    LongTimeFormat := 'hh:nn:ss';
  end;

  MainIniFile := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  try
    gDebug := MainIniFile.ReadBool('Debug', 'Debug', False);

    Application.CreateForm(TfrmConfig, frmConfig);
    frmConfig.HandleNeeded;

    Application.CreateForm(TfrmExtensions, frmExtensions);
    Application.CreateForm(TfrmChooseExt, frmChooseExt);
    Application.ShowMainForm := False;

    GenDefaultFileLang;

    frmConfig.Initialize(MainIniFile);

    with frmConfig do
    begin
      LangIndex := LangFillListAndGetCurrent(MainIniFile,
        ppOptionsMenu, miOptionsLang, miOptionsLangClick);
      if (LangIndex >= 0) and (LangIndex < miOptionsLang.Count) then
        miOptionsLangClick(miOptionsLang.Items[LangIndex]);
    end;

    if frmConfig.tvItems.Items.Count <= 0 then
      frmConfig.Show;

    with MainIniFile do
    begin
      if ReadBool('Main', 'ConfigShow', False) then
        frmConfig.Show;
      if ReadBool('Main', 'FiltersShow', False) then
        frmExtensions.ShowModal;
    end;

    frmConfig.TrayIcon.Visible := True;
    Application.Run;
  finally
    if Assigned(frmConfig) then
      frmConfig.MainIniFile := nil;
    MainIniFile.Free;
    CloseHandle(InstanceMutex);
  end;
end.
