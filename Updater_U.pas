unit Updater_U;

{$mode delphi}{$H+}

interface

uses
  Classes, ExtCtrls, Process, SysUtils;

type
  TUpdateOperation = (uoIdle, uoCheck, uoUpdate);

  { Checks GitHub Releases without blocking the main application thread. }
  TUpdater = class(TComponent)
  private
    FTimer: TTimer;
    FProcess: TProcess;
    FOperation: TUpdateOperation;
    FInitialCheck: Boolean;
    FPreviousFailurePending: Boolean;
    FManualCheck: Boolean;
    FNextCheckTick: QWord;
    FDeclinedVersion: string;
    FAppDirectory: string;
    procedure TimerTick(Sender: TObject);
    function StartScript(const AMode: string;
      AOperation: TUpdateOperation): Boolean;
    procedure ReportPreviousFailure;
    procedure OfferUpdate(const AManual: Boolean);
    function StateFileName: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start;
    procedure CheckNow;
  end;

implementation

uses
  IniFiles, Windows, Forms, LangsU;

const
  cCheckIntervalMs = 3600000;
  cReleasePrefix = 'https://github.com/avmaksimov/StartFromTray/releases/tag/v';

function IsVersionText(const AVersion: string): Boolean;
var
  I, Dots: Integer;
begin
  Result := False;
  Dots := 0;
  if (Length(AVersion) < 5) or (Length(AVersion) > 40) then Exit;
  if (AVersion[1] = '.') or (AVersion[Length(AVersion)] = '.') then Exit;
  for I := 1 to Length(AVersion) do
  begin
    if AVersion[I] = '.' then
    begin
      Inc(Dots);
      if (I > 1) and (AVersion[I - 1] = '.') then Exit;
    end
    else if not (AVersion[I] in ['0'..'9']) then Exit;
  end;
  Result := Dots = 2;
end;

constructor TUpdater.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOperation := uoIdle;
  FProcess := nil;
  FInitialCheck := True;
  FPreviousFailurePending := True;
  FManualCheck := False;
  FNextCheckTick := 0;
  { ExtractFilePath already includes the platform's trailing separator. }
  FAppDirectory := ExtractFilePath(ParamStr(0));
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 1500;
  FTimer.OnTimer := TimerTick;
end;

destructor TUpdater.Destroy;
begin
  FTimer.Enabled := False;
  FreeAndNil(FProcess);
  inherited Destroy;
end;

function TUpdater.StateFileName: string;
begin
  Result := FAppDirectory + 'StartFromTray.update.ini';
end;

procedure TUpdater.Start;
begin
  if not FileExists(FAppDirectory + 'update.ps1') then Exit;
  FTimer.Interval := 1500;
  FTimer.Enabled := True;
end;

procedure TUpdater.CheckNow;
begin
  if FOperation <> uoIdle then
  begin
    InfoDialog(Application.MainForm,
      GetLangString('LangStrings', 'UpdateAlreadyRunning'));
    Exit;
  end;
  if not FileExists(FAppDirectory + 'update.ps1') then
  begin
    ErrorDialog(Application.MainForm, Format(
      GetLangString('LangStrings', 'UpdateScriptMissing'),
      [FAppDirectory + 'update.ps1']));
    Exit;
  end;

  FInitialCheck := False;
  FNextCheckTick := GetTickCount64 + cCheckIntervalMs;
  FManualCheck := True;
  StartScript('-Check', uoCheck);
end;

procedure TUpdater.ReportPreviousFailure;
var
  Ini: TIniFile;
  ErrorText, Version: string;
begin
  if not FileExists(StateFileName) then Exit;
  Ini := TIniFile.Create(StateFileName);
  try
    if (Ini.ReadString('Update', 'Status', '') <> 'Failed') or
       (Ini.ReadString('Update', 'Reported', '1') <> '0') then Exit;
    ErrorText := Ini.ReadString('Update', 'Error', '');
    Version := Ini.ReadString('Update', 'Version', '');
    Ini.WriteString('Update', 'Reported', '1');
  finally
    Ini.Free;
  end;
  ErrorDialog(Application.MainForm,
    Format(GetLangString('LangStrings', 'UpdateFailure'),
    [Version, ErrorText, FAppDirectory + 'StartFromTray.update.log']));
end;

function TUpdater.StartScript(const AMode: string;
  AOperation: TUpdateOperation): Boolean;
var
  ScriptName: string;
begin
  Result := False;
  ScriptName := FAppDirectory + 'update.ps1';
  if not FileExists(ScriptName) then
  begin
    ErrorDialog(Application.MainForm,
      Format(GetLangString('LangStrings', 'UpdateScriptMissing'),
      [ScriptName]));
    Exit;
  end;

  try
    FreeAndNil(FProcess);
    FProcess := TProcess.Create(Self);
    FProcess.Executable := 'powershell.exe';
    FProcess.CurrentDirectory := FAppDirectory;
    FProcess.Options := [poNoConsole];
    FProcess.Parameters.Add('-NoLogo');
    FProcess.Parameters.Add('-NoProfile');
    FProcess.Parameters.Add('-NonInteractive');
    FProcess.Parameters.Add('-ExecutionPolicy');
    FProcess.Parameters.Add('Bypass');
    FProcess.Parameters.Add('-File');
    FProcess.Parameters.Add(ScriptName);
    FProcess.Parameters.Add(AMode);
    FProcess.Execute;
    FOperation := AOperation;
    FTimer.Interval := 500;
    FTimer.Enabled := True;
    Result := True;
  except
    on E: Exception do
    begin
      FreeAndNil(FProcess);
      FOperation := uoIdle;
      FTimer.Interval := 60000;
      ErrorDialog(Application.MainForm,
        Format(GetLangString('LangStrings', 'UpdateLaunchFailed'),
        [E.Message]));
    end;
  end;
end;

procedure TUpdater.OfferUpdate(const AManual: Boolean);
var
  Ini: TIniFile;
  Version, Confirmation: string;
begin
  if not FileExists(StateFileName) then Exit;
  Ini := TIniFile.Create(StateFileName);
  try
    Version := Ini.ReadString('Check', 'LatestVersion', '');
  finally
    Ini.Free;
  end;
  if not IsVersionText(Version) then Exit;
  if (not AManual) and (Version = FDeclinedVersion) then Exit;

  Confirmation := Format(GetLangString('LangStrings', 'UpdateAvailable'),
    [Version]) + LineEnding + LineEnding +
    GetLangString('LangStrings', 'UpdateQuestion');

  { Avoid automatic checks while a modal confirmation is on screen. }
  FTimer.Enabled := False;
  try
    if AskForConfirmationWithURI(Application.MainForm, Confirmation,
      cReleasePrefix + Version,
      GetLangString('LangStrings', 'UpdateReleaseLink')) then
      StartScript('-Update', uoUpdate)
    else
      FDeclinedVersion := Version;
  finally
    FTimer.Enabled := True;
  end;
end;

procedure TUpdater.TimerTick(Sender: TObject);
var
  ExitCode: Integer;
  Manual: Boolean;
  FinishedOperation: TUpdateOperation;
  Ini: TIniFile;
  InstalledVersion, ErrorText: string;
begin
  if Application.Terminated then
  begin
    FTimer.Enabled := False;
    Exit;
  end;

  try
    if FOperation = uoIdle then
    begin
      if FPreviousFailurePending then
      begin
        FPreviousFailurePending := False;
        ReportPreviousFailure;
      end;
      if FInitialCheck or (GetTickCount64 >= FNextCheckTick) then
      begin
        FInitialCheck := False;
        FManualCheck := False;
        FNextCheckTick := GetTickCount64 + cCheckIntervalMs;
        StartScript('-Check', uoCheck);
      end;
      Exit;
    end;

    if (not Assigned(FProcess)) or FProcess.Running then Exit;

    ExitCode := FProcess.ExitStatus;
    FinishedOperation := FOperation;
    Manual := FManualCheck;
    FManualCheck := False;
    FOperation := uoIdle;
    FTimer.Interval := 60000;
    FreeAndNil(FProcess);

    if FinishedOperation = uoCheck then
    begin
      if ExitCode = 10 then
        OfferUpdate(Manual)
      else if Manual and (ExitCode = 0) then
      begin
        InstalledVersion := '';
        if FileExists(StateFileName) then
        begin
          Ini := TIniFile.Create(StateFileName);
          try
            InstalledVersion := Ini.ReadString('Check', 'CurrentVersion', '');
          finally
            Ini.Free;
          end;
        end;
        InfoDialog(Application.MainForm,
          Format(GetLangString('LangStrings', 'UpdateNoUpdates'),
          [InstalledVersion]));
      end
      else if Manual then
      begin
        ErrorText := '';
        if FileExists(StateFileName) then
        begin
          Ini := TIniFile.Create(StateFileName);
          try
            ErrorText := Ini.ReadString('Check', 'Error', '');
          finally
            Ini.Free;
          end;
        end;
        ErrorDialog(Application.MainForm,
          Format(GetLangString('LangStrings', 'UpdateCheckFailed'),
          [ErrorText]));
      end;
    end
    else if (FinishedOperation = uoUpdate) and (ExitCode <> 0) then
      ReportPreviousFailure;
  except
    on E: Exception do
    begin
      FOperation := uoIdle;
      FTimer.Interval := 60000;
      FreeAndNil(FProcess);
      ErrorDialog(Application.MainForm,
        Format(GetLangString('LangStrings', 'UpdateLaunchFailed'),
        [E.Message]));
    end;
  end;
end;

end.
