unit CommonU;

interface

uses
  Classes, SysUtils, StrUtils, ComCtrls, Menus, dialogs {debug} ,
  Vcl.Controls, Winapi.ShellAPI, Winapi.CommCtrl, Winapi.Windows,
  Vcl.StdCtrls;

const
  cItemsFileName = 'Items.xml';
  //cIconHeigh = 19;
  //cIconWidth = 10;

function MyExtendFileNameToFull(const AFileName: string): string;

// Matches masks (can be divided by ';' and only Extensions without point) to AFileName
// u can use mask in exts
function MyMatchesExtensions(const AFileName, AExtensions: string): Boolean;

procedure M_Error(const ErrorMessage: string);

// устанавливает доступность (Enabled) для себя и дочерних компонентов
procedure M_SetChildsEnable(AControl: TControl; const AEnabled: Boolean);

procedure ShowMsgIfDebug(const AParam, AValue: string);

var
  gDebug: Boolean;

implementation

uses Forms, Types, IniFiles, Vcl.Graphics, System.Masks, System.UITypes;

// If Filename exists than return it else check in Path and result Fullname
// from Path or return '' if not found
function MyExtendFileNameToFull(const AFileName: string): string;
begin
  //directory must be absolute path
  if DirectoryExists(AFileName) and not IsRelativePath(AFileName) then
    begin
    Exit(AFileName);
    end;

  Result := FileSearch(AFileName, GetEnvironmentVariable('PATH'));

  {if FileExists(AFileName) or //directory must be absolute path
    (DirectoryExists(AFileName) and not IsRelativePath(AFileName)) then
  begin
    Result := AFileName;
    Exit;
  end;

  var vPaths := SplitString(GetEnvironmentVariable('PATH'), ';');
  for var i := 0 to High(vPaths) do
    begin
    Result := vPaths[i] + '\' + AFileName;
    if FileExists(Result) then
      begin
      Exit;
      end;
    end;
  Result := ''; // else}
end;

// Matches masks (can be divided by ';' and only Extensions without point) to AFileName
// u can use mask in exts
function MyMatchesExtensions(const AFileName, AExtensions: string): Boolean;
var
  i: integer;
  vExtensionArray: TStringDynArray;
begin
  Result := False;

  vExtensionArray := AExtensions.Split([';']);
  for i := 0 to High(vExtensionArray) do
  begin
    Result := MatchesMask(AFileName, '*.' + vExtensionArray[i]);
    if Result then
      Exit;
  end;
end;

procedure ShowMsgIfDebug(const AParam, AValue: string);
begin
  if gDebug then
    Application.MessageBox(PChar(AParam + ': ' + AValue), 'Debug');
end;

procedure M_Error(const ErrorMessage: string); inline;
begin
  MessageDlg(ErrorMessage, mtError, [mbOK], 0);
end;

procedure M_SetChildsEnable(AControl: TControl; const AEnabled: Boolean);
const
  EnabledColor: array [Boolean] of TColor = (clBtnShadow, clWindowText);
var
  i: integer;
begin
  with AControl do
  begin
    Enabled := AEnabled;
    if AControl is TGroupBox then
      TGroupBox(AControl).Font.Color := EnabledColor[AEnabled];

    if AControl is TWinControl then
      for i := 0 to TWinControl(AControl).ControlCount - 1 do
        M_SetChildsEnable(TWinControl(AControl).Controls[i], AEnabled);
  end;
end;

// initialization
begin
  // IntFormatSettings := FormatSettings;
  // чтобы были стандартные
  with FormatSettings do
  begin
    DateSeparator := '.';
    TimeSeparator := ':';
    ShortDateFormat := 'dd/mm/yyyy';
    LongTimeFormat := 'hh:nn:ss';
  end;
  with TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini')) do
    try
      gDebug := ReadBool('Debug', 'Debug', False);
    finally
      Free;
    end;

end.
