unit CommonU;

interface

uses
  Classes, SysUtils, StrUtils, ComCtrls, Menus, dialogs {debug} ,
  Vcl.Controls, Winapi.ShellAPI, Winapi.CommCtrl, Winapi.Windows,
  Vcl.StdCtrls;

const
  cItemsFileName = 'Items.xml';
  cIconHeigh = 19;
  cIconWidth = 10;

function MyExtendFileNameToFull(const AFileName: string): string;

function MyExtractHIconFromRes(AFileName: string; const AIconIndex: Integer): HIcon;
function MyExtractHIcon(ACommand: string; const AIconFileName: string;
  AIconFileIndex: Integer): HIcon;

// Matches masks (can be divided by ';' and only Extensions without point) to AFileName
// u can use mask in exts
function MyMatchesExtensions(const AFileName, AExtensions: string): Boolean;

procedure M_Error(const ErrorMessage: string);

// устанавливает доступность (Enabled) для себя и дочерних компонентов
procedure M_SetChildsEnable(AControl: TControl; const AEnabled: Boolean);

procedure ShowMsgIfDebug(const AParam, AValue: string);

var
  gDebug: Boolean;
  gMenuItemBmpWidth, gMenuItemBmpHeight: integer;

implementation

uses Forms, Types, IniFiles, Vcl.Graphics, System.Masks, System.UITypes;

// If Filename exists than return it else check in Path and result Fullname
// from Path or return '' if not found
function MyExtendFileNameToFull(const AFileName: string): string;
var
  i: integer;
  s: string;
  vPaths: TStringDynArray;
begin
  if FileExists(AFileName) then
  begin
    Result := AFileName;
    Exit;
  end;

  vPaths := SplitString(GetEnvironmentVariable('PATH'), ';');
  for i := 0 to High(vPaths) do
    begin
    s := vPaths[i] + '\' + AFileName;
    if FileExists(s) then
      begin
      Result := s;
      Exit;
      end;
    end;
  Result := ''; // else
end;

function MyExtractHIconFromRes(AFileName: string; const AIconIndex: Integer): HIcon;
begin
  AFileName := AFileName.Trim;

  if IsRelativePath(AFileName) then
      AFileName := MyExtendFileNameToFull(AFileName);

  if AFileName = '' then
    Exit(0);

  var vLargeIcon: hIcon := 0;
  var vSmallIcon: HIcon := 1;
  Result := ExtractIconEx(PChar(AFileName), AIconIndex, vLargeIcon, vSmallIcon, 1);
  if Result > 0 then
    Result := vSmallIcon;
end;

// now AFileName can be not full and be in Path
function MyExtractHIcon(ACommand: string; const AIconFileName: string;
  AIconFileIndex: Integer): HIcon;
var
  vExt: string;
  Info: TSHFileInfo;
begin
  if AIconFileName <> '' then
    begin
    var vLargeIcon: hIcon := 0;
    var vSmallIcon: HIcon := 1; // non zero
    if ExtractIconEx(PChar(AIconFileName), AIconFileIndex, vLargeIcon, vSmallIcon, 1) > 0 then
      Exit(vSmallIcon);
    end;

  vExt := ExtractFileExt(ACommand);
  if (vExt = '') or (vExt = '.') then
    Exit(0);

  vExt := vExt.ToLower;

  if (vExt = '.exe') or (vExt = '.dll') or (vExt = '.ico') then
  begin
    if IsRelativePath(ACommand) then
      ACommand := MyExtendFileNameToFull(ACommand);
    if ACommand = '' then
      ACommand := vExt; // not found - so default
  end
  else // common document - enough only Ext
    ACommand := vExt;

  Result := SHGetFileInfo(PChar(ACommand), FILE_ATTRIBUTE_NORMAL, Info,
    SizeOf(TSHFileInfo), SHGFI_ICON or SHGFI_SMALLICON or
    SHGFI_USEFILEATTRIBUTES);
  If Result <> 0 then
    Result := Info.HIcon
    // Result := ExtractAssociatedIcon(Application.Handle, PChar(AFileName), w)
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
  gMenuItemBmpWidth := GetSystemMetrics(SM_CXMENUCHECK);
  gMenuItemBmpHeight := GetSystemMetrics(SM_CYMENUCHECK);

end.
