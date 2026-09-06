unit frmChooseExt_U;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ImgList, Generics.Collections;

type
  TfrmChooseExt = class(TForm)
    ImageList: TImageList;
    gbExtensions: TGroupBox;
    edtExt: TLabeledEdit;
    lbExtensions: TListBox;
    lblExtensions: TLabel;
    gbButtons: TGroupBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}Action: TCloseAction);
    procedure lbExtensionsClick(Sender: TObject);
    procedure lbExtensionsDrawItem({%H-}Control: TWinControl; Index: Integer;
      ARect: Types.TRect; State: StdCtrls.TOwnerDrawState);
    procedure edtExtChange(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FlbChanging: Boolean;
    FExtensionIcons: TObjectList<TIcon>;
    FExtensionIconIndexes: array of Integer;
    function FindExtInList(const Ext: string): Integer;
  public
    Extension: string;
    StartWithExtensions: TList<string>;
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmChooseExt: TfrmChooseExt;

implementation

uses
  Windows, ShellApi, Registry, StrUtils, LCLType;

{$R *.lfm}

const
  clbPairDelimiter = '/';

function ExtensionPart(const ItemText: string): string;
var
  DelimiterPos: Integer;
begin
  DelimiterPos := Pos(clbPairDelimiter, ItemText);
  if DelimiterPos > 0 then
    Result := Copy(ItemText, 1, DelimiterPos - 1)
  else
    Result := ItemText;
end;
{
function MyCompareStr(const Left, Right: string): Integer;
var
  LeftExtension, RightExtension: string;
begin
  LeftExtension := ExtensionPart(Left);
  RightExtension := ExtensionPart(Right);
  Result := Length(LeftExtension) - Length(RightExtension);
  if Result = 0 then
    Result := AnsiCompareText(LeftExtension, RightExtension);
end;
}
function MyStringListSortCompare(List: TStringList;
  LeftIndex, RightIndex: Integer): Integer;
begin
  Result := AnsiCompareText(List[LeftIndex], List[RightIndex]);//MyCompareStr(List[LeftIndex], List[RightIndex]);
end;

procedure TfrmChooseExt.btnOKClick(Sender: TObject);
begin
  Extension := edtExt.Text;
end;

constructor TfrmChooseExt.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Extension := '';
  StartWithExtensions := TList<string>.Create;
  FExtensionIcons := TObjectList<TIcon>.Create(True);
  lbExtensions.Items.NameValueSeparator := clbPairDelimiter;
end;

procedure TfrmChooseExt.edtExtChange(Sender: TObject);
var
  NewIndex: Integer;
begin
  if FlbChanging or (edtExt.Text = '') then
    Exit;
  NewIndex := FindExtInList(edtExt.Text);
  if lbExtensions.ItemIndex <> NewIndex then
  begin
    lbExtensions.ItemIndex := NewIndex;
    lbExtensions.Repaint;
  end;
end;

function TfrmChooseExt.FindExtInList(const Ext: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to lbExtensions.Items.Count - 1 do
    if AnsiStartsText(Ext, ExtensionPart(lbExtensions.Items[I])) then
      Exit(I);
end;

procedure TfrmChooseExt.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Extension := edtExt.Text;
  StartWithExtensions.Clear;
end;

procedure TfrmChooseExt.FormDestroy(Sender: TObject);
begin
  SetLength(FExtensionIconIndexes, 0);
  FreeAndNil(FExtensionIcons);
  FreeAndNil(StartWithExtensions);
end;

procedure TfrmChooseExt.FormShow(Sender: TObject);
var
  Reg: TRegistry;
  RegistryKeys, SortedExtensions: TStringList;
  I, StartIndex: Integer;
  KeyName, StartExtension: string;
begin
  FlbChanging := True;
  lbExtensions.Items.BeginUpdate;
  try
    edtExt.Text := Extension;
    lbExtensions.Items.Clear;
    FExtensionIcons.Clear;
    SetLength(FExtensionIconIndexes, 0);
    RegistryKeys := TStringList.Create;
    SortedExtensions := TStringList.Create;
    Reg := TRegistry.Create(KEY_READ);
    try
      Reg.RootKey := HKEY_CLASSES_ROOT;
      if Reg.OpenKeyReadOnly('') then
        Reg.GetKeyNames(RegistryKeys);
      for I := 0 to RegistryKeys.Count - 1 do
      begin
        KeyName := RegistryKeys[I];
        if (Length(KeyName) > 1) and (KeyName[1] = '.') then
          SortedExtensions.Add(LowerCase(Copy(KeyName, 2, MaxInt)));
      end;
      SortedExtensions.CustomSort(@MyStringListSortCompare);
      lbExtensions.Items.Assign(SortedExtensions);
      SetLength(FExtensionIconIndexes, lbExtensions.Items.Count);
      for I := 0 to High(FExtensionIconIndexes) do
        FExtensionIconIndexes[I] := -1;
    finally
      Reg.Free;
      SortedExtensions.Free;
      RegistryKeys.Free;
    end;

    for I := 0 to StartWithExtensions.Count - 1 do
    begin
      StartExtension := StartWithExtensions[I];
      StartIndex := FindExtInList(StartExtension);
      if StartIndex >= 0 then
      begin
        Extension := ExtensionPart(lbExtensions.Items[StartIndex]);
        Break;
      end;
    end;
    edtExt.Text := Extension;
  finally
    FlbChanging := False;
    lbExtensions.Items.EndUpdate;
  end;
  edtExtChange(edtExt);
  edtExt.SetFocus;
end;

procedure TfrmChooseExt.lbExtensionsClick(Sender: TObject);
begin
  if lbExtensions.ItemIndex >= 0 then
    edtExt.Text := ExtensionPart(lbExtensions.Items[lbExtensions.ItemIndex]);
end;

procedure TfrmChooseExt.lbExtensionsDrawItem(Control: TWinControl;
  Index: Integer; ARect: Types.TRect; State: StdCtrls.TOwnerDrawState);
var
  ExtensionText: string;
  IconIndex, TextTop: Integer;
  Info: TSHFileInfoW;
  Icon: TIcon;
  WideExtension: UnicodeString;
begin
  if (Index < 0) or (Index >= lbExtensions.Items.Count) then
    Exit;
  lbExtensions.Canvas.FillRect(ARect);
  ExtensionText := ExtensionPart(lbExtensions.Items[Index]);
  IconIndex := -1;

  if (Index >= 0) and (Index <= High(FExtensionIconIndexes)) then
  begin
    IconIndex := FExtensionIconIndexes[Index];
    if IconIndex = -1 then
    begin
      { Mark the row before asking the Shell. This prevents a nested paint
        notification from trying to load the same icon again. }
      FExtensionIconIndexes[Index] := -2;
      Info := Default(TSHFileInfoW);
      WideExtension := UTF8Decode('.' + ExtensionText);
      if SHGetFileInfoW(PWideChar(WideExtension), FILE_ATTRIBUTE_NORMAL, Info,
        SizeOf(Info), SHGFI_ICON or SHGFI_SMALLICON or
        SHGFI_USEFILEATTRIBUTES) <> 0 then
      begin
        Icon := TIcon.Create;
        try
          Icon.Handle := Info.hIcon;
          IconIndex := FExtensionIcons.Add(Icon);
          Icon := nil;
          FExtensionIconIndexes[Index] := IconIndex;
        finally
          Icon.Free;
        end;
      end;
    end;
  end;

  if (IconIndex >= 0) and (IconIndex < FExtensionIcons.Count) then
    lbExtensions.Canvas.Draw(ARect.Left + 1, ARect.Top + 1,
      FExtensionIcons[IconIndex]);
  TextTop := ARect.Top + (ARect.Height -
    lbExtensions.Canvas.TextHeight(ExtensionText)) div 2;
  lbExtensions.Canvas.TextOut(ARect.Left + 20, TextTop, ExtensionText);
  if LCLType.odFocused in State then
    lbExtensions.Canvas.DrawFocusRect(ARect);
end;

end.
