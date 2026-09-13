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
  const IncludeFolder: Boolean = False;
  const IncludeMMC: Boolean = False);

var
  gDebug: Boolean;

implementation

uses
  Forms, Dialogs, StdCtrls, Masks, Windows, ShellApi;

procedure BuildBrowseButtonImages(AImageList: TImageList;
  const IncludeFolder: Boolean = False;
  const IncludeMMC: Boolean = False);

  function AddWindowsShellImage(const AProbeName: string;
    const AFileAttributes: DWORD): Boolean;
  var
    SmallInfo, LargeInfo: TSHFileInfoW;
    WideProbeName: UnicodeString;
    SmallIcon, LargeIcon: Graphics.TIcon;
    Images: array[0..1] of TRasterImage;
    SmallIconHandle, LargeIconHandle: HICON;
  begin
    Result := False;
    SmallInfo := Default(TSHFileInfoW);
    LargeInfo := Default(TSHFileInfoW);
    WideProbeName := UTF8Decode(AProbeName);
    if SHGetFileInfoW(PWideChar(WideProbeName), AFileAttributes, SmallInfo,
      SizeOf(SmallInfo), SHGFI_ICON or SHGFI_SMALLICON or
      SHGFI_USEFILEATTRIBUTES) = 0 then
      Exit;

    SmallIcon := nil;
    LargeIcon := nil;
    SmallIconHandle := 0;
    LargeIconHandle := 0;
    try
      if SHGetFileInfoW(PWideChar(WideProbeName), AFileAttributes, LargeInfo,
        SizeOf(LargeInfo), SHGFI_ICON or SHGFI_LARGEICON or
        SHGFI_USEFILEATTRIBUTES) = 0 then
        Exit;

      SmallIconHandle := HICON(Windows.CopyImage(SmallInfo.hIcon, IMAGE_ICON,
        16, 16, 0));
      LargeIconHandle := HICON(Windows.CopyImage(LargeInfo.hIcon, IMAGE_ICON,
        32, 32, 0));
      if (SmallIconHandle = 0) or (LargeIconHandle = 0) then
        Exit;

      SmallIcon := Graphics.TIcon.Create;
      LargeIcon := Graphics.TIcon.Create;
      SmallIcon.Handle := SmallIconHandle;
      SmallIconHandle := 0;
      LargeIcon.Handle := LargeIconHandle;
      LargeIconHandle := 0;

      Images[0] := SmallIcon;
      Images[1] := LargeIcon;
      Result := AImageList.AddMultipleResolutions(Images) >= 0;
    finally
      SmallIcon.Free;
      LargeIcon.Free;
      if SmallIconHandle <> 0 then
        DestroyIcon(SmallIconHandle);
      if LargeIconHandle <> 0 then
        DestroyIcon(LargeIconHandle);
      if SmallInfo.hIcon <> 0 then
        DestroyIcon(SmallInfo.hIcon);
      if LargeInfo.hIcon <> 0 then
        DestroyIcon(LargeInfo.hIcon);
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

      AImageList.AddMasked(Bitmap, clFuchsia);
    finally
      Bitmap.Free;
    end;
  end;

  procedure AddMMCImage;
  begin
    if AddWindowsShellImage('sft-browse.msc',
      FILE_ATTRIBUTE_NORMAL) then
      Exit;

    AddFileImage;
  end;

begin
  AImageList.Clear;
  AImageList.Width := 16;
  AImageList.Height := 16;
  AImageList.Scaled := True;
  AImageList.RegisterResolutions([16, 32]);
  AddFileImage;
  if IncludeFolder then
    AddFolderImage;
  if IncludeMMC then
    AddMMCImage;
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

end.
