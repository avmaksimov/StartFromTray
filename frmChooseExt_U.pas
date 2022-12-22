unit frmChooseExt_U;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.ImageList, Vcl.ImgList, System.Generics.Collections;

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
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lbExtensionsClick(Sender: TObject);
    procedure lbExtensionsDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure edtExtChange(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FlbChanging: Boolean;
    function FindExtInList(const Ext: string): integer; inline;
  public
    { Public declarations }
    Extension: string;
    StartWithExtensions: TList<string>;

    constructor Create(AOwner: TComponent); override;
  end;

var
  frmChooseExt: TfrmChooseExt;

implementation

uses System.Win.Registry, WinAPI.CommCtrl, WinAPI.ShellAPI, System.Generics.Defaults;

{$R *.dfm}

const clbPairDelimiter: char = '/';

function MyCompareStr(const Left, Right: string): Integer;
begin
  var vLeft := Left.Split(clbPairDelimiter)[0];
  var vRight := Right.Split(clbPairDelimiter)[0];

  Result := vLeft.Length - vRight.Length;
  if Result = 0 then
    Result := AnsiCompareStr(vLeft, vRight);
end;

function MyStringListSortCompare(List: TStringList; LeftIndex, RightIndex: Integer): Integer;
begin
  Result := MyCompareStr(List[LeftIndex], List[RightIndex]);
end;

procedure TfrmChooseExt.btnOKClick(Sender: TObject);
begin
  Extension := edtExt.Text;
end;

constructor TfrmChooseExt.Create(AOwner: TComponent);
begin
  inherited;
  Extension := '';
  StartWithExtensions :=  TList<string>.Create;
  lbExtensions.Items.NameValueSeparator := clbPairDelimiter;
end;

procedure TfrmChooseExt.edtExtChange(Sender: TObject);
begin
if FlbChanging or (Length(edtExt.Text) <= 0) then
  Exit;
var vNewIndex := FindExtInList(edtExt.Text);
//SendMessageW(lbExtensions.Handle, LB_FINDSTRING, -1, NativeInt(PChar(edtExt.Text)));
if lbExtensions.ItemIndex <> vNewIndex then
  begin
  lbExtensions.ItemIndex := vNewIndex;
  lbExtensions.Repaint;
  end;
end;

function TfrmChooseExt.FindExtInList(const Ext: string): integer;
begin
  Result := SendMessageW(lbExtensions.Handle, LB_FINDSTRING, -1, NativeInt(PChar(Ext)));
end;

procedure TfrmChooseExt.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Extension := edtExt.Text;
  StartWithExtensions.Clear;
end;

procedure TfrmChooseExt.FormDestroy(Sender: TObject);
begin
  FreeAndNil(StartWithExtensions);
end;

procedure TfrmChooseExt.FormShow(Sender: TObject);
  // following in the footsteps of the algorithm: http://www.mlsite.net/blog/?p=2250 with some improvements
  procedure SyncToRight(const ALeft: TArray<string>; const ARight: TStringList);
  begin
  var vLeft: Integer := 0; var vRight: Integer := 0;
  var vLeftCount := Length(ALeft); var vRightCount := ARight.Count;
  while (vLeft < vLeftCount) or (vRight < vRightCount) do
    begin
    if vRight >= vRightCount then
      begin
      // If the target list is exhausted,
      // delete the current element from the subject list
      ARight.Add(ALeft[vLeft]);
      Inc(vLeft);
      end
    else if vLeft >= vLeftCount then
      begin
      // O/w, if the subject list is exhausted,
      // insert the current element from the target list
      For var i := vRight to vRightCount - 1 do
        ARight.Delete(vRight);
      break;
      end
    else
      begin
      var vRes := MyCompareStr(ALeft[vLeft], ARight[vRight]);//AnsiCompareStr(ALeft[vLeft], ARight[vRight]);
      if vRes > 0 then // Left > Right
        begin
        // O/w, if the current subject element precedes the current target element,
        // delete the current subject element.
        ARight.Add(ALeft[vLeft]); //We can't use ARight.Insert() because later we'll go throught this (we still need to compare upper value)
        Inc(vLeft);
        end
      else if vRes < 0 then
        begin
        // O/w, if the current subject element follows the current target element,
        // insert the current target element.
        ARight.Delete(vRight);
        Dec(vRightCount);
        end
      else
        begin
        // O/w the current elements match; consider the next pair
        Inc(vLeft);
        Inc(vRight);
        end;
        end;
    end;
  ARight.CustomSort(MyStringListSortCompare);
  end;
begin
FlbChanging := True;
edtExt.Text := Extension;

lbExtensions.Items.BeginUpdate;

var reg: TRegistry := TRegistry.Create;
try
  reg.rootkey := HKEY_CLASSES_ROOT;
  if reg.OpenKey('', False) then
    begin
    try
      var vReg: TArray<string>;
      var vRegCount := 0;

      var vRegInfo: TRegKeyInfo;
      if reg.GetKeyInfo(vRegInfo) then
        begin
        SetLength(vReg, vRegInfo.NumSubKeys);

        var vExtMaxLen: DWORD := vRegInfo.MaxSubKeyLen + 1;
        var vExt: string;
        SetString(vExt, nil, vExtMaxLen);
        for var I := 0 to vRegInfo.NumSubKeys - 1 do
          begin
          var Len := vExtMaxLen;
          RegEnumKeyEx(reg.CurrentKey, I, PChar(vExt), Len, nil, nil, nil, nil);
          if(vExt[1] = '.') then
            begin
            vReg[vRegCount] := PChar(vExt.Substring(1).ToLower);
            Inc(vRegCount);
            end;
          end;
        SetLength(vReg, vRegCount);
        TArray.Sort<string>(vReg, TComparer<string>.Construct(
          function(const Left, Right: string): Integer
            begin
            Result := MyCompareStr(Left, Right);
            end
          )
        );
        end;
      reg.CloseKey;
      if lbExtensions.Items.Count = 0 then
        begin
        for var i := 0 to vRegCount - 1 do
          begin
          lbExtensions.Items.Add(vReg[i]);
          end;
        end
      else // lbExtensions.Items.Count > 0
        begin
        var vLBStringList := TStringList.Create;
        try
          vLBStringList.Assign(lbExtensions.Items);
          SyncToRight(vReg, vLBStringList);
          lbExtensions.Items.Assign(vLBStringList);
        finally
          FreeAndNil(vLBStringList);
          end;
        end;
    finally
      FlbChanging := False;
      end;
    try
      // if list is not empty Extension is not Empty and vise versa
      for var s: string in StartWithExtensions do
        if FindExtInList(s) > -1 then
          begin
          Extension := s;
          break;
          end;
      edtExt.Text := Extension;
      edtExtChange(edtExt);
    finally
      lbExtensions.Items.EndUpdate;
      end;
    end;
  finally
    reg.Free;
    end;
  edtExt.SetFocus;
end;

procedure TfrmChooseExt.lbExtensionsClick(Sender: TObject);
begin
if lbExtensions.ItemIndex >= 0 then
  edtExt.Text := lbExtensions.Items[lbExtensions.ItemIndex].Split(lbExtensions.Items.NameValueSeparator)[0]; //lbExtensions.Items[lbExtensions.ItemIndex];
end;

procedure TfrmChooseExt.lbExtensionsDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  lbExtensions.Canvas.FillRect(Rect);

  var vArText: TArray<string> := lbExtensions.Items[Index].Split(clbPairDelimiter);
  var vText: string := vArText[0];
  if Length(vArText) = 2 then
    begin
    var vIcon := TIcon.Create;
    ImageList.GetIcon(vArText[1].ToInteger, vIcon);
    DrawIconEx(lbExtensions.Canvas.Handle, Rect.Left + 1, Rect.Top + 1,
      vIcon.Handle, 16, 16, 0, 0, DI_NORMAL);
    vIcon.Free;
    end
  else
    begin
    var vInfo: TSHFileInfo;
    if SHGetFileInfo(PChar('.' + vText), FILE_ATTRIBUTE_NORMAL, vInfo,
      SizeOf(TSHFileInfo), SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES) <> 0 then
      begin
      DrawIconEx(lbExtensions.Canvas.Handle, Rect.Left + 1, Rect.Top + 1,
        vInfo.hIcon, 16, 16, 0, 0, DI_NORMAL);
      var vImageListIndexNew := ImageList_ReplaceIcon(ImageList.Handle, -1, vInfo.hIcon);
      DestroyIcon(vInfo.hIcon);
      lbExtensions.Items[Index] := String.Join(lbExtensions.Items.NameValueSeparator,
        [vText, vImageListIndexNew.ToString]);
      end;
    end;

  var vTextRect := TRect.Create(Rect.Left + 18, Rect.Top, Rect.Right, Rect.Bottom);
  DrawTextEx(lbExtensions.Canvas.Handle, PChar(vText), Length(vText), vTextRect,
    DT_SINGLELINE or DT_VCENTER, nil);
  if odFocused in State then  // also check for styles if there's a possibility of using ..
      lbExtensions.Canvas.DrawFocusRect(Rect);
end;

end.
