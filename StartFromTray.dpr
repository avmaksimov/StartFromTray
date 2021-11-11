// JCL_DEBUG_EXPERT_INSERTJDBG ON
program StartFromTray;

uses
  Forms,
  CommandsClass_U in 'CommandsClass_U.pas',
  CommonU in 'CommonU.pas',
  frmConfig_U in 'frmConfig_U.pas' {frmConfig},
  FilterClass_U in 'FilterClass_U.pas',
  frmFilters_U in 'frmFilters_U.pas' {frmFilters},
  frmCommandConfig_U in 'frmCommandConfig_U.pas' {frmCommandConfig: TFrame},
  Vcl.Themes,
  Vcl.Styles,
  System.SysUtils, System.IniFiles,
  LangsU in 'LangsU.pas',
  MPPopupMenu in 'MPPopupMenu.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmConfig, frmConfig);
  Application.CreateForm(TfrmFilters, frmFilters);
  Application.ShowMainForm := False;

  GenDefaultFileLang;

  with frmConfig do
  begin
    cbLangs.ItemIndex := LangFillListAndGetCurrent(cbLangs.Items);
    cbLangsChange(cbLangs);
  end;

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      if ReadBool('Main', 'FiltersShow', False) then
        frmFilters.ShowModal;
    finally
      Free;
    end;

  Application.Run;

end.
