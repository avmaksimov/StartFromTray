program StartFromTray;

{$mode delphi}{$H+}

uses
  Interfaces, Forms, SysUtils, IniFiles,
  CommonU, frmConfig_U, FilterClass_U,
  frmExtensions_U, LangsU, MPPopupMenu,
  frmChooseExt_U;

{$R StartFromTray.res}

var
  MainIniFile: TIniFile;
  LangIndex: Integer;

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;

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
  end;
end.
