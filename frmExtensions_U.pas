unit frmExtensions_U;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Mask, ComCtrls,
  FilterClass_U, Vcl.ImgList, System.ImageList, Vcl.TitleBarCtrls;

type
  TfrmExtensions = class(TForm)
    gbExtensions: TGroupBox;
    gbFiltersActions: TGroupBox;
    btnExtensionAdd: TButton;
    btnExtensionDelete: TButton;
    gbMainButtons: TGroupBox;
    btnOK: TButton;
    btnCancel: TButton;
    lvFilters: TListBox;
    btnExtensionDown: TButton;
    btnExtensionUp: TButton;
    gbExtensionProperties: TGroupBox;
    edtExtensions: TLabeledEdit;
    edtName: TLabeledEdit;
    OpenDialog: TFileOpenDialog;
    ImageList: TImageList;
    TitleBarPanel: TTitleBarPanel;
    lblEditHelper: TLabel;
    edtEditHelper: TButtonedEdit;
    edtEditParams: TLabeledEdit;
    pbEdit: TPaintBox;
    edtRunHelper: TButtonedEdit;
    lblRunHelper: TLabel;
    edtRunParams: TLabeledEdit;
    pbRun: TPaintBox;
    procedure btnExtensionAddClick(Sender: TObject);
    procedure btnExtensionDeleteClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnExtensionUpClick(Sender: TObject);
    procedure btnExtensionDownClick(Sender: TObject);
    procedure edtNameChange(Sender: TObject);
    procedure lvFiltersClick(Sender: TObject);
    procedure edtEditRunHelperAfterDialog(Sender: TObject; var AName: string;
      var AAction: Boolean);
    procedure edtEdit_or_RunHelperRightButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lvFiltersDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure lvFiltersDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TitleBarPanelCustomButtons0Click(Sender: TObject);
    procedure pbEdit_or_RunPaint(Sender: TObject);
    procedure edtEdit_or_RunHelperChange(Sender: TObject);
  private
    { Private declarations }
    FAssignedCaption: string;
    FAssignedData: TFilterData;
    FAssignedListItemIndex: Integer;
    FIsAssigningListItemIndex: Boolean;
    FIsModified: Boolean;

    procedure AssignCurrentItem;
    function SaveAssignedItem: Boolean;
    function GetIsModified: Boolean;
  public
    { Public declarations }
    procedure AssignFilters(AFilters: TStringList);
    procedure MoveToList(AFilters: TStringList);
    procedure ApplicationOnFormIdle(Sender: TObject; var Done: Boolean);
  end;

var
  frmExtensions: TfrmExtensions;

implementation

uses System.Math, System.UITypes, VCL.Themes, LangsU, CommonU;

{$R *.dfm}

procedure TfrmExtensions.AssignFilters(AFilters: TStringList);
var
  i: Integer;
  vFilter: TFilterData;
begin
  for i := 0 to AFilters.Count - 1 do
  begin
    vFilter := TFilterData.Create;
    vFilter.Assign(TFilterData(AFilters.Objects[i]));

    lvFilters.Items.AddObject(AFilters[i], vFilter);
  end;

  if AFilters.Count > 0 then
    lvFilters.ItemIndex := 0;

  AssignCurrentItem;
end;

procedure TfrmExtensions.MoveToList(AFilters: TStringList);
var
  i: Integer;
begin
  for i := 0 to AFilters.Count - 1 do
    AFilters.Objects[i].Free;

  AFilters.Clear;

  for i := 0 to lvFilters.Items.Count - 1 do
    AFilters.AddObject(lvFilters.Items[i],
      TFilterData(lvFilters.Items.Objects[i]));

  lvFilters.Clear;

end;

procedure TfrmExtensions.pbEdit_or_RunPaint(Sender: TObject);
  procedure BevelLine(const ACanvas: TCanvas; const C: TColor; const X1, Y1, X2, Y2: Integer);
  begin
    with ACanvas do
    begin
      Pen.Color := C;
      MoveTo(X1, Y1);
      LineTo(X2, Y2);
    end;
  end;

  procedure TextOutAndIncPos(const ACanvas: TCanvas; const AString: string;
    var APosStr: Integer; const ANewPosStr: Integer;
    var ALeft: Integer; const ATop: Integer);
  begin
  if ANewPosStr > APosStr then
    begin
    var s := Copy(AString, APosStr, ANewPosStr - APosStr);
    with ACanvas do
      begin
      TextOut(ALeft, ATop, s);
      Inc(ALeft, TextWidth(s));
      APosStr := ANewPosStr;
      end;
    end;
  end;

const cTextLeftIndent = 20; cTextLineIndent = 5;
  cTextAr: array of string = ['ActionForEdit', 'ActionForRun'];
begin
var vPaintBox := Sender as TPaintBox;
var LStyle: TCustomStyleServices := StyleServices(vPaintBox);

var vCanvas: TCanvas := vPaintBox.Canvas;
var vColor1: TColor := LStyle.GetSystemColor(clBtnShadow);
var vColor2: TColor := LStyle.GetSystemColor(clBtnHighlight);

var vLeft: Integer := 0;

var vText: string := GetLangString('frmExtensions', cTextAr[vPaintBox.Tag]);

with vCanvas do
  begin
  Pen.Style := psSolid;
  Pen.Mode  := pmCopy;
  Pen.Width := 1;
  Brush.Style := bsSolid;

  vPaintBox.Height := TextHeight(vText);
  var vTop4Line: Integer := Ceil(vPaintBox.Height{TextHeight(vText)} / 2);

  BevelLine(vCanvas, vColor1, vLeft, vTop4Line, cTextLeftIndent, vTop4Line);
  BevelLine(vCanvas, vColor2, vLeft, vTop4Line + 1, cTextLeftIndent, vTop4Line + 1);

  Inc(vLeft, cTextLeftIndent + cTextLineIndent);

  var iStrPos: Integer := 1; var vStrLen := vText.Length;
  var vIsNormalText := True;
  while iStrPos <= vStrLen do
    begin
    var i, vEndPos: Integer;
    if vIsNormalText then
      begin
      i := Pos('<b>', vText, iStrPos);
      if i >= 1 then
        begin
        vEndPos := i;
        vIsNormalText := False;
        end
      else
        vEndPos := vStrLen + 1;
      vCanvas.Font.Style := [];
      TextOutAndIncPos(vCanvas, vText, iStrPos, vEndPos, vLeft, 0);
      if i >= 1 then
        Inc(iStrPos, 3);
      end
    else // vIsNormalText = False
      begin
      i := Pos('</b>', vText, iStrPos);
      if i >= 1 then
        begin
        vEndPos := i;
        vIsNormalText := True;
        end
      else
        vEndPos := vStrLen + 1;
      vCanvas.Font.Style := [TFontStyle.fsBold];
      TextOutAndIncPos(vCanvas, vText, iStrPos, vEndPos, vLeft, 0);
      if i >= 1 then
        Inc(iStrPos, 4);
      end;
    end;

  Inc(vLeft, cTextLineIndent);

  BevelLine(vCanvas, vColor1, vLeft, vTop4Line, vPaintBox.Width, vTop4Line);
  BevelLine(vCanvas, vColor2, vLeft, vTop4Line + 1, vPaintBox.Width, vTop4Line + 1);

  end;
end;

procedure TfrmExtensions.ApplicationOnFormIdle(Sender: TObject; var Done: Boolean);
begin
  btnOK.Enabled := FIsModified or GetIsModified;

  var vItemIndex := lvFilters.ItemIndex;
  btnExtensionUp.Enabled := vItemIndex > 0;
  btnExtensionDown.Enabled := (vItemIndex >= 0) and (vItemIndex < lvFilters.Count - 1);
  btnExtensionDelete.Enabled := vItemIndex > -1;
end;

procedure TfrmExtensions.AssignCurrentItem;
var
  bSelected: Boolean;
begin
  FIsAssigningListItemIndex := True;

  FAssignedListItemIndex := lvFilters.ItemIndex;
  bSelected := FAssignedListItemIndex > -1;

  M_SetChildsEnable(gbExtensionProperties, bSelected);

  if bSelected then
    begin
    FAssignedCaption := lvFilters.Items[FAssignedListItemIndex];
    FAssignedData := TFilterData(lvFilters.Items.Objects
      [FAssignedListItemIndex]);

    edtName.Text := FAssignedCaption;

    with FAssignedData do
      begin
      edtExtensions.Text := Extensions;

      edtEditHelper.Text := Edit;
      edtEditParams.Text := EditParams;
      edtRunHelper.Text := Run;
      edtRunParams.Text := RunParams;
      end;
    end
  else
    begin
    FAssignedCaption := '';
    edtName.Text := '';

    edtExtensions.Text := '';

    edtEditHelper.Text := '';
    edtEditParams.Text := '';
    edtRunHelper.Text := '';
    edtRunParams.Text := '';

    FAssignedData := nil;
    end;
  FIsAssigningListItemIndex := False;
end;

function TfrmExtensions.SaveAssignedItem: Boolean;
begin
  if (FAssignedListItemIndex < 0) or not Assigned(FAssignedData) then
    Exit(True);

  FIsModified := FIsModified or GetIsModified;

  var vName := Trim(edtName.Text);
  var vExtensions := Trim(edtExtensions.Text);

  var vExceptionStr := '';

  if (vName = '') then
    vExceptionStr := GetLangString('frmExtensions', 'ErrorEmptyName');

  if (vExtensions = '') then
    begin
    if vExceptionStr <> '' then
      vExceptionStr := vExceptionStr + #13#10#13#10;
    vExceptionStr := vExceptionStr + GetLangString('frmExtensions', 'ErrorEmptyExtensions');
    end;

  if (vExceptionStr <> '') then
    begin
    ErrorDialog(Self, vExceptionStr);
    Exit(False);
    end;

  lvFilters.Items[FAssignedListItemIndex] := vName;
  with FAssignedData do
    begin
    Extensions := vExtensions;

    Edit := Trim(edtEditHelper.Text);
    EditParams := Trim(edtEditParams.Text);
    Run := Trim(edtRunHelper.Text);
    RunParams := Trim(edtRunParams.Text);
    end;
  Result := True;
end;

procedure TfrmExtensions.TitleBarPanelCustomButtons0Click(Sender: TObject);
begin
  Application.Minimize;
end;

procedure TfrmExtensions.btnCancelClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to lvFilters.Items.Count - 1 do
    TFilterData(lvFilters.Items.Objects[i]).Free;

  lvFilters.Clear;
end;

procedure TfrmExtensions.btnExtensionUpClick(Sender: TObject);
begin
  with lvFilters do
    if (ItemIndex > 0) then
    begin
      var newItemIndex := ItemIndex - 1;
      Items.Exchange(ItemIndex, newItemIndex);
      ItemIndex := newItemIndex;
      FAssignedListItemIndex := newItemIndex;
    end;
end;

procedure TfrmExtensions.btnExtensionDownClick(Sender: TObject);
begin
  with lvFilters do
    if (ItemIndex > -1) and (ItemIndex < Count - 1) then
    begin
      var newItemIndex := ItemIndex + 1;
      Items.Exchange(ItemIndex, newItemIndex);
      ItemIndex := newItemIndex;
      FAssignedListItemIndex := newItemIndex;
    end;
end;

procedure TfrmExtensions.btnExtensionAddClick(Sender: TObject);
begin
  if not SaveAssignedItem then
    Exit;

  with lvFilters do
  begin
    Items.AddObject('', TFilterData.Create);

    ItemIndex := Items.Count - 1;
  end;

  AssignCurrentItem;
  edtName.SetFocus;
end;

procedure TfrmExtensions.btnExtensionDeleteClick(Sender: TObject);
begin
  with lvFilters do
  begin
    if (ItemIndex <= -1) or not AskForDeletion(Self, Items[ItemIndex]) then
      Exit;

    var newItemIndex := ItemIndex;

    if ItemIndex = Count - 1 then
      newItemIndex := newItemIndex - 1;

    TFilterData(Items.Objects[ItemIndex]).Free;
    Items.Delete(ItemIndex);

    ItemIndex := newItemIndex;
  end;

  AssignCurrentItem;
end;

procedure TfrmExtensions.btnOKClick(Sender: TObject);
begin
  SaveAssignedItem;
  for var i := 0 to Filters.Count - 1 do
    Filters.Objects[i].Free;

  Filters.Clear;

  for var i := 0 to lvFilters.Items.Count - 1 do
    Filters.AddObject(lvFilters.Items[i],
      TFilterData(lvFilters.Items.Objects[i]));

  lvFilters.Clear;

  Filters_SaveToFile;
end;

procedure TfrmExtensions.edtEdit_or_RunHelperChange(Sender: TObject);
begin
  var vButtonedEdit := Sender as TButtonedEdit;

  vButtonedEdit.Font.Color := IfThen(FileSearch(vButtonedEdit.Text, GetEnvironmentVariable('PATH')) <> '',
    TColors.SysWindowText, TColors.Red);
end;

procedure TfrmExtensions.edtEditRunHelperAfterDialog(Sender: TObject;
  var AName: string; var AAction: Boolean);
begin
  AName := ExtractRelativePath(GetCurrentDir, AName);
end;

procedure TfrmExtensions.edtNameChange(Sender: TObject);
begin
  if not FIsAssigningListItemIndex then
    lvFilters.Items[lvFilters.ItemIndex] := edtName.Text;
end;

procedure TfrmExtensions.edtEdit_or_RunHelperRightButtonClick(Sender: TObject);
const
  cTitles: array of string = ['ChooseFileForEdit', 'ChooseFileForRun'];
var
  Edit: TButtonedEdit;
begin
  Edit := Sender as TButtonedEdit;
  with OpenDialog do
  begin
    DefaultFolder := ExtractFilePath(Edit.Text);
    FileName := ExtractFileName(Edit.Text);
    Title := GetLangString('frmExtensions', cTitles[Edit.Tag]);
    if Execute then
      Edit.Text := OpenDialog.FileName;
  end;
end;

procedure TfrmExtensions.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.OnIdle := nil;
end;

procedure TfrmExtensions.FormShow(Sender: TObject);
begin
  FIsModified := False;

  AssignFilters(Filters);

  FIsAssigningListItemIndex := False;
  with OpenDialog.FileTypes do
  begin
    Clear;
    with Add do
    begin
      DisplayName := GetLangString('LangStrings', 'FileDialogExecutableFile');
      FileMask := '*.exe';
    end;
    with Add do
    begin
      DisplayName := GetLangString('LangStrings', 'FileDialogAnyFile');
      FileMask := '*';
    end;
  end;

  Application.OnIdle := ApplicationOnFormIdle;
end;

function TfrmExtensions.GetIsModified: Boolean;
begin
  Result := edtName.Text <> FAssignedCaption;
  if not Result and Assigned(FAssignedData) then
  begin
    with FAssignedData do
      Result := Result or (edtExtensions.Text <> Extensions) or
        (edtEditHelper.Text <> Edit) or (edtEditParams.Text <> EditParams) or
        (edtRunHelper.Text <> Run) or (edtRunParams.Text <> RunParams);
  end;
end;

procedure TfrmExtensions.lvFiltersClick(Sender: TObject);
begin
  if (lvFilters.ItemIndex < 0) or
    (lvFilters.ItemIndex = FAssignedListItemIndex) then
    Exit;

  if not SaveAssignedItem then
    begin
    lvFilters.ItemIndex := FAssignedListItemIndex;
    lvFilters.EndDrag(False);
    edtName.SetFocus;
    end;

  AssignCurrentItem;
end;

procedure TfrmExtensions.lvFiltersDragDrop(Sender, Source: TObject; X,
  Y: Integer);
begin
  if (Source <> Sender) or (Sender <> lvFilters) then
    Exit;
with lvFilters do
  begin
    if ItemIndex < 0 then Exit;
    var vNewItemIndex := ItemAtPos(TPoint.Create(X, Y), True);
    if vNewItemIndex = -1 then
      if Y < 0 then
        vNewItemIndex := 0
      else
        vNewItemIndex := Count - 1;

    Items.Move(ItemIndex, vNewItemIndex);
    ItemIndex := vNewItemIndex;
    FAssignedListItemIndex := ItemIndex;
  end;
end;

procedure TfrmExtensions.lvFiltersDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Sender = Source) and (Sender = lvFilters) and
    ((Sender as TListBox).ItemIndex >= 0);
end;

end.
