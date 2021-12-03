program StartFromTray;

uses
  Forms,
  CommandsClass_U in 'CommandsClass_U.pas',
  CommonU in 'CommonU.pas',
  frmConfig_U in 'frmConfig_U.pas' {frmConfig},
  FilterClass_U in 'FilterClass_U.pas',
  frmExtensions_U in 'frmExtensions_U.pas' {frmExtensions},
  frmCommandConfig_U in 'frmCommandConfig_U.pas' {frmCommandConfig: TFrame},
  Vcl.Themes,
  Vcl.Styles,
  System.SysUtils,
  System.IniFiles,
  WinAPI.Windows,
  LangsU in 'LangsU.pas',
  MPPopupMenu in 'MPPopupMenu.pas',
  frmChooseExt_U in 'frmChooseExt_U.pas' {frmChooseExt};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmConfig, frmConfig);
  Application.CreateForm(TfrmExtensions, frmExtensions);
  Application.CreateForm(TfrmChooseExt, frmChooseExt);
  Application.ShowMainForm := False;

  GenDefaultFileLang;

  with frmConfig do
  begin
    miOptionsLangClick(miOptionsLang.Items[LangFillListAndGetCurrent(ppOptionsMenu,
      miOptionsLang, miOptionsLangClick)]);
  end;

  if frmConfig.tvItems.Items.Count <= 0 then
    frmConfig.Show;

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      if ReadBool('Main', 'ConfigShow', False) then
        frmConfig.Show;
        //ShowWindow(frmConfig.Handle, SW_Restore);
      if ReadBool('Main', 'FiltersShow', False) then
        frmExtensions.ShowModal;
    finally
      Free;
    end;

  // it has to be before Run, after all initialization
  frmConfig.TrayIcon.Visible := True;
  Application.Run;

end.
