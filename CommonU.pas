unit CommonU;

interface

uses
  Classes, SysUtils, StrUtils, ComCtrls, Menus, dialogs {debug} ,
  Vcl.Controls, Winapi.ShellAPI, Winapi.CommCtrl, Winapi.Windows,
  Vcl.StdCtrls;

const
  cItemsFileName = 'Items.xml';

// Matches masks (can be divided by ';' and only Extensions without point) to AFileName
// u can use mask in exts
function MyMatchesExtensions(const AFileName, AExtensions: string): Boolean;
// just correct Delphi implementation for WinAPI ExpandEnvironmentStrings
function MyExpandEnvironmentStrings(const FileName: string): string;

procedure M_Error(const ErrorMessage: string);

// устанавливает доступность (Enabled) для себя и дочерних компонентов
procedure M_SetChildsEnable(AControl: TControl; const AEnabled: Boolean);

procedure ShowMsgIfDebug(const AParam, AValue: string);

var
  gDebug: Boolean;

implementation

uses Forms, Types, IniFiles, Vcl.Graphics, System.Masks, System.UITypes;

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

function MyExpandEnvironmentStrings(const FileName: string): string;
var
  Buffer: array[0..MAX_PATH - 1] of Char;
  Len: Integer;
begin
  Len := ExpandEnvironmentStrings(PChar(FileName), Buffer, Length(Buffer));
  if Len <= Length(Buffer) then
    SetString(Result, Buffer, Len - 1)
  else
    if Len > 0 then
      begin
        SetLength(Result, Len);
        Len := ExpandEnvironmentStrings(PChar(FileName), Buffer, Length(Buffer));
        if Len <= Length(Result) then
          SetString(Result, Buffer, Len - 1)
      end
    else
      Result := ''
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
