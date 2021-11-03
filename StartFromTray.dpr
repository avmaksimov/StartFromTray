// JCL_DEBUG_EXPERT_INSERTJDBG ON
program StartFromTray;

uses
  Forms,
  CommandsClass_U in 'CommandsClass_U.pas',
  CommonU in 'CommonU.pas',
  frmConfig_U in 'frmConfig_U.pas' {frmConfig},
  FilterClass_U in 'FilterClass_U.pas',
  frmFilters_U in 'frmFilters_U.pas' {frmExtensions},
  frmCommandConfig_U in 'frmCommandConfig_U.pas' {frmCommandConfig: TFrame},
  Vcl.Themes,
  Vcl.Styles,
  System.SysUtils,
  LangsU in 'LangsU.pas',
  MPPopupMenu in 'MPPopupMenu.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmConfig, frmConfig);
  Application.CreateForm(TfrmExtensions, frmExtensions);
  Application.ShowMainForm := False;

  GenDefaultFileLang;

  { if FindCmdLineSwitch('GenDefaultFileLang') then
    begin
    GenDefaultFileLang;
    Exit;
    end; }

  // SetLang('rus');

  with frmConfig do
  begin
    cbLangs.ItemIndex := LangFillListAndGetCurrent(cbLangs.Items);
    cbLangsChange(cbLangs);
  end;

  Application.Run;

end.
