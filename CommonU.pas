unit CommonU;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList;

const
  cItemsFileName = 'Items.xml';

function MyMatchesExtensions(const AFileName, AExtensions: string): Boolean;
function MyExpandEnvironmentStrings(const FileName: string): string;

procedure M_Error(const ErrorMessage: string);
procedure M_SetChildsEnable(AControl: TControl; const AEnabled: Boolean);
procedure ShowMsgIfDebug(const AParam, AValue: string);
procedure BuildBrowseButtonImages(AImageList: TImageList;
  const IncludeFolder: Boolean = True);

var
  gDebug: Boolean;

implementation

uses
  Forms, Dialogs, StdCtrls, IniFiles, Masks, Windows, ShellApi;

procedure BuildBrowseButtonImages(AImageList: TImageList;
  const IncludeFolder: Boolean);

  procedure DrawBrowseMark(ACanvas: TCanvas);
  begin
    ACanvas.Pen.Width := 2;
    ACanvas.Pen.Color := clHighlight;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Ellipse(8, 7, 13, 12);
    ACanvas.MoveTo(12, 11);
    ACanvas.LineTo(15, 14);
  end;

  function AddWindowsShellImage(const AProbeName: string;
    const AFileAttributes: DWORD): Boolean;
  var
    Info: TSHFileInfoW;
    WideProbeName: UnicodeString;
    Bitmap: Graphics.TBitmap;
    Icon: Graphics.TIcon;
  begin
    Result := False;
    Info := Default(TSHFileInfoW);
    WideProbeName := UTF8Decode(AProbeName);
    if SHGetFileInfoW(PWideChar(WideProbeName), AFileAttributes, Info,
      SizeOf(Info), SHGFI_ICON or SHGFI_SMALLICON or
      SHGFI_USEFILEATTRIBUTES) = 0 then
      Exit;

    Bitmap := Graphics.TBitmap.Create;
    Icon := Graphics.TIcon.Create;
    try
      Bitmap.SetSize(AImageList.Width, AImageList.Height);
      Bitmap.Canvas.Brush.Color := clFuchsia;
      Bitmap.Canvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));
      Icon.Handle := Info.hIcon;
      Bitmap.Canvas.Draw((Bitmap.Width - Icon.Width) div 2,
        (Bitmap.Height - Icon.Height) div 2, Icon);
      DrawBrowseMark(Bitmap.Canvas);
      AImageList.AddMasked(Bitmap, clFuchsia);
      Result := True;
    finally
      Icon.Free;
      Bitmap.Free;
    end;
  end;

  procedure AddFileImage;
  var
    Bitmap: Graphics.TBitmap;
  begin
    if AddWindowsShellImage('.sft-browse-file',
      FILE_ATTRIBUTE_NORMAL) then
      Exit;
    Bitmap := Graphics.TBitmap.Create;
    try
      Bitmap.SetSize(AImageList.Width, AImageList.Height);
      Bitmap.Canvas.Brush.Color := clFuchsia;
      Bitmap.Canvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));

      Bitmap.Canvas.Pen.Color := clNavy;
      Bitmap.Canvas.Brush.Color := clWhite;
      Bitmap.Canvas.Polygon([Types.Point(2, 1), Types.Point(9, 1),
        Types.Point(13, 5), Types.Point(13, 14), Types.Point(2, 14)]);
      Bitmap.Canvas.MoveTo(9, 1);
      Bitmap.Canvas.LineTo(9, 5);
      Bitmap.Canvas.LineTo(13, 5);
      Bitmap.Canvas.Pen.Color := clGray;
      Bitmap.Canvas.MoveTo(4, 8);
      Bitmap.Canvas.LineTo(11, 8);
      Bitmap.Canvas.MoveTo(4, 10);
      Bitmap.Canvas.LineTo(11, 10);
      Bitmap.Canvas.MoveTo(4, 12);
      Bitmap.Canvas.LineTo(7, 12);

      DrawBrowseMark(Bitmap.Canvas);
      AImageList.AddMasked(Bitmap, clFuchsia);
    finally
      Bitmap.Free;
    end;
  end;

  procedure AddFolderImage;
  var
    Bitmap: Graphics.TBitmap;
  begin
    if AddWindowsShellImage('sft-browse-folder',
      FILE_ATTRIBUTE_DIRECTORY) then
      Exit;
    Bitmap := Graphics.TBitmap.Create;
    try
      Bitmap.SetSize(AImageList.Width, AImageList.Height);
      Bitmap.Canvas.Brush.Color := clFuchsia;
      Bitmap.Canvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));

      Bitmap.Canvas.Pen.Color := clOlive;
      Bitmap.Canvas.Brush.Color := clYellow;
      Bitmap.Canvas.Polygon([Types.Point(1, 4), Types.Point(6, 4),
        Types.Point(8, 6), Types.Point(14, 6), Types.Point(14, 14),
        Types.Point(1, 14)]);
      Bitmap.Canvas.Brush.Color := $00A6DFFF;
      Bitmap.Canvas.Polygon([Types.Point(1, 7), Types.Point(14, 7),
        Types.Point(12, 14), Types.Point(1, 14)]);

      DrawBrowseMark(Bitmap.Canvas);
      AImageList.AddMasked(Bitmap, clFuchsia);
    finally
      Bitmap.Free;
    end;
  end;

begin
  AImageList.Clear;
  AImageList.Width := 16;
  AImageList.Height := 16;
  AddFileImage;
  if IncludeFolder then
    AddFolderImage;
end;

function MyMatchesExtensions(const AFileName, AExtensions: string): Boolean;
var
  I: Integer;
  Extensions: TStringList;
begin
  Result := False;
  Extensions := TStringList.Create;
  try
    Extensions.StrictDelimiter := True;
    Extensions.Delimiter := ';';
    Extensions.DelimitedText := AExtensions;
    for I := 0 to Extensions.Count - 1 do
      if MatchesMask(AFileName, '*.' + Trim(Extensions[I])) then
        Exit(True);
  finally
    Extensions.Free;
  end;
end;

function MyExpandEnvironmentStrings(const FileName: string): string;
var
  Required: DWORD;
  WideFileName: UnicodeString;
  WideResult: UnicodeString;
begin
  WideFileName := UTF8Decode(FileName);
  WideResult := '';
  Required := Windows.ExpandEnvironmentStringsW(PWideChar(WideFileName), nil, 0);
  if Required = 0 then
    Exit('');

  SetLength(WideResult, Required);
  if Windows.ExpandEnvironmentStringsW(PWideChar(WideFileName),
    PWideChar(WideResult), Required) = 0 then
    Exit('');
  SetLength(WideResult, Required - 1);
  Result := UTF8Encode(WideResult);
end;

procedure ShowMsgIfDebug(const AParam, AValue: string);
begin
  if gDebug then
    Application.MessageBox(PChar(AParam + ': ' + AValue), 'Debug');
end;

procedure M_Error(const ErrorMessage: string);
begin
  MessageDlg(ErrorMessage, mtError, [mbOK], 0);
end;

procedure M_SetChildsEnable(AControl: TControl; const AEnabled: Boolean);
const
  EnabledColor: array[Boolean] of TColor = (clBtnShadow, clWindowText);
var
  I: Integer;
begin
  AControl.Enabled := AEnabled;
  if AControl is TGroupBox then
    TGroupBox(AControl).Font.Color := EnabledColor[AEnabled];

  if AControl is TWinControl then
    for I := 0 to TWinControl(AControl).ControlCount - 1 do
      M_SetChildsEnable(TWinControl(AControl).Controls[I], AEnabled);
end;

initialization
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
