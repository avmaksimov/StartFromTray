unit frmExtensions_U;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls,
  ExtCtrls, ImgList, EditBtn, FilterClass_U;

{$PUSH}
{$WARN 5024 OFF}
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
    OpenDialog: TOpenDialog;
    ImageList: TImageList;
    lblEditHelper: TLabel;
    edtEditHelper: TEditButton;
    edtEditParams: TLabeledEdit;
    pbEdit: TPaintBox;
    edtRunHelper: TEditButton;
    lblRunHelper: TLabel;
    edtRunParams: TLabeledEdit;
    pbRun: TPaintBox;
    lblHint: TLabel;
    procedure btnExtensionAddClick(Sender: TObject);
    procedure btnExtensionDeleteClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnExtensionUpClick(Sender: TObject);
    procedure btnExtensionDownClick(Sender: TObject);
    procedure edtNameChange(Sender: TObject);
    procedure lvFiltersClick(Sender: TObject);
    procedure edtEdit_or_RunHelperRightButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lvFiltersDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure lvFiltersDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure pbEdit_or_RunPaint(Sender: TObject);
    procedure edtEdit_or_RunHelperChange(Sender: TObject);
  private
    FAssignedCaption: string;
    FAssignedData: TFilterData;
    FAssignedListItemIndex: Integer;
    FIsAssigningListItemIndex: Boolean;
    FIsModified: Boolean;
    procedure AssignCurrentItem;
    function SaveAssignedItem: Boolean;
    function GetIsModified: Boolean;
    procedure ClearLocalFilters;
  public
    procedure AssignFilters(AFilters: TStringList);
    procedure MoveToList(AFilters: TStringList);
    procedure ApplicationOnFormIdle(Sender: TObject; var Done: Boolean);
  end;

var
  frmExtensions: TfrmExtensions;

implementation

uses
  LangsU, CommonU;

{$R *.lfm}

procedure TfrmExtensions.AssignFilters(AFilters: TStringList);
var
  I: Integer;
  Filter: TFilterData;
begin
  for I := 0 to AFilters.Count - 1 do
  begin
    Filter := TFilterData.Create;
    Filter.Assign(TFilterData(AFilters.Objects[I]));
    lvFilters.Items.AddObject(AFilters[I], Filter);
  end;
  if AFilters.Count > 0 then
    lvFilters.ItemIndex := 0;
  AssignCurrentItem;
end;

procedure TfrmExtensions.MoveToList(AFilters: TStringList);
var
  I: Integer;
begin
  for I := 0 to AFilters.Count - 1 do
    AFilters.Objects[I].Free;
  AFilters.Clear;
  for I := 0 to lvFilters.Items.Count - 1 do
    AFilters.AddObject(lvFilters.Items[I], lvFilters.Items.Objects[I]);
  lvFilters.Clear;
end;

procedure TfrmExtensions.ClearLocalFilters;
var
  I: Integer;
begin
  for I := 0 to lvFilters.Items.Count - 1 do
    lvFilters.Items.Objects[I].Free;
  lvFilters.Clear;
  FAssignedData := nil;
  FAssignedListItemIndex := -1;
end;

procedure TfrmExtensions.pbEdit_or_RunPaint(Sender: TObject);
const
  TextKeys: array[0..1] of string = ('ActionForEdit', 'ActionForRun');
  TextLeftIndent = 20;
  TextLineIndent = 5;
var
  PaintBox: TPaintBox;
  Canvas: TCanvas;
  Text, BeforeBold, BoldText, AfterBold: string;
  OpenPos, ClosePos, LeftPos, LineY, TextY: Integer;

  procedure BevelLine(AColor: TColor; X1, X2: Integer);
  begin
    Canvas.Pen.Color := AColor;
    Canvas.MoveTo(X1, LineY);
    Canvas.LineTo(X2, LineY);
  end;

  procedure DrawPart(const S: string; Bold: Boolean);
  begin
    if S = '' then
      Exit;
    if Bold then
      Canvas.Font.Style := [fsBold]
    else
      Canvas.Font.Style := [];
    Canvas.TextOut(LeftPos, TextY, S);
    Inc(LeftPos, Canvas.TextWidth(S));
  end;

begin
  PaintBox := TPaintBox(Sender);
  Canvas := PaintBox.Canvas;
  Text := GetLangString('frmExtensions', TextKeys[PaintBox.Tag]);
  OpenPos := Pos('<b>', Text);
  ClosePos := Pos('</b>', Text);
  if (OpenPos > 0) and (ClosePos > OpenPos) then
  begin
    BeforeBold := Copy(Text, 1, OpenPos - 1);
    BoldText := Copy(Text, OpenPos + 3, ClosePos - OpenPos - 3);
    AfterBold := Copy(Text, ClosePos + 4, MaxInt);
  end
  else
  begin
    BeforeBold := Text;
    BoldText := '';
    AfterBold := '';
  end;

  PaintBox.Height := Canvas.TextHeight('Hg') + 2;
  LineY := PaintBox.Height div 2;
  TextY := 0;
  BevelLine(clBtnShadow, 0, TextLeftIndent);
  Inc(LineY);
  BevelLine(clBtnHighlight, 0, TextLeftIndent);
  Dec(LineY);

  LeftPos := TextLeftIndent + TextLineIndent;
  DrawPart(BeforeBold, False);
  DrawPart(BoldText, True);
  DrawPart(AfterBold, False);
  Inc(LeftPos, TextLineIndent);
  Canvas.Font.Style := [];
  BevelLine(clBtnShadow, LeftPos, PaintBox.Width);
  Inc(LineY);
  BevelLine(clBtnHighlight, LeftPos, PaintBox.Width);
end;

procedure TfrmExtensions.ApplicationOnFormIdle(Sender: TObject;
  var Done: Boolean);
var
  ItemIndex: Integer;
begin
  btnOK.Enabled := FIsModified or GetIsModified;
  ItemIndex := lvFilters.ItemIndex;
  btnExtensionUp.Enabled := ItemIndex > 0;
  btnExtensionDown.Enabled := (ItemIndex >= 0) and
    (ItemIndex < lvFilters.Count - 1);
  btnExtensionDelete.Enabled := ItemIndex >= 0;
  Done := True;
end;

procedure TfrmExtensions.AssignCurrentItem;
var
  Selected: Boolean;
begin
  FIsAssigningListItemIndex := True;
  try
    FAssignedListItemIndex := lvFilters.ItemIndex;
    Selected := FAssignedListItemIndex >= 0;
    M_SetChildsEnable(gbExtensionProperties, Selected);
    if Selected then
    begin
      FAssignedCaption := lvFilters.Items[FAssignedListItemIndex];
      FAssignedData := TFilterData(
        lvFilters.Items.Objects[FAssignedListItemIndex]);
      edtName.Text := FAssignedCaption;
      edtExtensions.Text := FAssignedData.Extensions;
      edtEditHelper.Text := FAssignedData.Edit;
      edtEditParams.Text := FAssignedData.EditParams;
      edtRunHelper.Text := FAssignedData.Run;
      edtRunParams.Text := FAssignedData.RunParams;
    end
    else
    begin
      FAssignedCaption := '';
      FAssignedData := nil;
      edtName.Text := '';
      edtExtensions.Text := '';
      edtEditHelper.Text := '';
      edtEditParams.Text := '';
      edtRunHelper.Text := '';
      edtRunParams.Text := '';
    end;
  finally
    FIsAssigningListItemIndex := False;
  end;
end;

function TfrmExtensions.SaveAssignedItem: Boolean;
var
  Name, Extensions, ExceptionText: string;
begin
  if (FAssignedListItemIndex < 0) or (not Assigned(FAssignedData)) then
    Exit(True);

  FIsModified := FIsModified or GetIsModified;
  Name := Trim(edtName.Text);
  Extensions := Trim(edtExtensions.Text);
  ExceptionText := '';
  if Name = '' then
    ExceptionText := GetLangString('frmExtensions', 'ErrorEmptyName');
  if Extensions = '' then
  begin
    if ExceptionText <> '' then
      ExceptionText := ExceptionText + LineEnding + LineEnding;
    ExceptionText := ExceptionText +
      GetLangString('frmExtensions', 'ErrorEmptyExtensions');
  end;
  if ExceptionText <> '' then
  begin
    ErrorDialog(Self, ExceptionText);
    Exit(False);
  end;

  lvFilters.Items[FAssignedListItemIndex] := Name;
  FAssignedData.Extensions := Extensions;
  FAssignedData.Edit := Trim(edtEditHelper.Text);
  FAssignedData.EditParams := Trim(edtEditParams.Text);
  FAssignedData.Run := Trim(edtRunHelper.Text);
  FAssignedData.RunParams := Trim(edtRunParams.Text);
  FAssignedCaption := Name;
  Result := True;
end;

procedure TfrmExtensions.btnCancelClick(Sender: TObject);
begin
  ClearLocalFilters;
  ModalResult := mrCancel;
end;

procedure TfrmExtensions.btnExtensionUpClick(Sender: TObject);
var
  NewItemIndex: Integer;
begin
  if lvFilters.ItemIndex <= 0 then
    Exit;
  NewItemIndex := lvFilters.ItemIndex - 1;
  lvFilters.Items.Exchange(lvFilters.ItemIndex, NewItemIndex);
  lvFilters.ItemIndex := NewItemIndex;
  FAssignedListItemIndex := NewItemIndex;
  FIsModified := True;
end;

procedure TfrmExtensions.btnExtensionDownClick(Sender: TObject);
var
  NewItemIndex: Integer;
begin
  if (lvFilters.ItemIndex < 0) or
    (lvFilters.ItemIndex >= lvFilters.Count - 1) then
    Exit;
  NewItemIndex := lvFilters.ItemIndex + 1;
  lvFilters.Items.Exchange(lvFilters.ItemIndex, NewItemIndex);
  lvFilters.ItemIndex := NewItemIndex;
  FAssignedListItemIndex := NewItemIndex;
  FIsModified := True;
end;

procedure TfrmExtensions.btnExtensionAddClick(Sender: TObject);
begin
  if not SaveAssignedItem then
    Exit;
  lvFilters.Items.AddObject('', TFilterData.Create);
  lvFilters.ItemIndex := lvFilters.Items.Count - 1;
  FIsModified := True;
  AssignCurrentItem;
  edtName.SetFocus;
end;

procedure TfrmExtensions.btnExtensionDeleteClick(Sender: TObject);
var
  NewItemIndex: Integer;
begin
  if (lvFilters.ItemIndex < 0) or
    (not AskForDeletion(Self, lvFilters.Items[lvFilters.ItemIndex])) then
    Exit;
  NewItemIndex := lvFilters.ItemIndex;
  if NewItemIndex = lvFilters.Count - 1 then
    Dec(NewItemIndex);
  lvFilters.Items.Objects[lvFilters.ItemIndex].Free;
  lvFilters.Items.Delete(lvFilters.ItemIndex);
  lvFilters.ItemIndex := NewItemIndex;
  FIsModified := True;
  AssignCurrentItem;
end;

procedure TfrmExtensions.btnOKClick(Sender: TObject);
begin
  if not SaveAssignedItem then
    Exit;
  MoveToList(Filters);
  Filters_SaveToFile;
  ModalResult := mrOK;
end;

procedure TfrmExtensions.edtEdit_or_RunHelperChange(Sender: TObject);
var
  Edit: TEditButton;
begin
  Edit := TEditButton(Sender);
  if (Trim(Edit.Text) = '') or FileExists(Edit.Text) or
    (FileSearch(Edit.Text, GetEnvironmentVariable('PATH')) <> '') then
    Edit.Font.Color := clWindowText
  else
    Edit.Font.Color := clRed;
end;

procedure TfrmExtensions.edtNameChange(Sender: TObject);
begin
  if (not FIsAssigningListItemIndex) and (lvFilters.ItemIndex >= 0) then
    lvFilters.Items[lvFilters.ItemIndex] := edtName.Text;
end;

procedure TfrmExtensions.edtEdit_or_RunHelperRightButtonClick(Sender: TObject);
const
  Titles: array[0..1] of string = ('ChooseFileForEdit', 'ChooseFileForRun');
var
  Edit: TEditButton;
begin
  Edit := TEditButton(Sender);
  OpenDialog.InitialDir := ExtractFilePath(Edit.Text);
  OpenDialog.FileName := ExtractFileName(Edit.Text);
  OpenDialog.Title := GetLangString('frmExtensions', Titles[Edit.Tag]);
  if OpenDialog.Execute then
    Edit.Text := OpenDialog.FileName;
end;

procedure TfrmExtensions.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.OnIdle := nil;
  if (ModalResult <> mrOK) and (lvFilters.Items.Count > 0) then
    ClearLocalFilters;
end;

procedure TfrmExtensions.FormShow(Sender: TObject);
begin
  if ImageList.Count = 0 then
    BuildBrowseButtonImages(ImageList, False);
  ClearLocalFilters;
  FIsModified := False;
  FIsAssigningListItemIndex := False;
  edtRunHelper.Tag := 1;
  OpenDialog.Filter := GetLangString('LangStrings',
    'FileDialogExecutableFile') + '|*.exe|' +
    GetLangString('LangStrings', 'FileDialogAnyFile') + '|*.*';
  OpenDialog.FilterIndex := 1;
  AssignFilters(Filters);
  Application.OnIdle := ApplicationOnFormIdle;
end;

function TfrmExtensions.GetIsModified: Boolean;
begin
  Result := edtName.Text <> FAssignedCaption;
  if (not Result) and Assigned(FAssignedData) then
    Result := (edtExtensions.Text <> FAssignedData.Extensions) or
      (edtEditHelper.Text <> FAssignedData.Edit) or
      (edtEditParams.Text <> FAssignedData.EditParams) or
      (edtRunHelper.Text <> FAssignedData.Run) or
      (edtRunParams.Text <> FAssignedData.RunParams);
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
    Exit;
  end;
  AssignCurrentItem;
end;

procedure TfrmExtensions.lvFiltersDragDrop(Sender, Source: TObject;
  X, Y: Integer);
var
  NewItemIndex: Integer;
begin
  if (Source <> Sender) or (Sender <> lvFilters) or
    (lvFilters.ItemIndex < 0) then
    Exit;
  NewItemIndex := lvFilters.ItemAtPos(Point(X, Y), True);
  if NewItemIndex = -1 then
    if Y < 0 then
      NewItemIndex := 0
    else
      NewItemIndex := lvFilters.Count - 1;
  lvFilters.Items.Move(lvFilters.ItemIndex, NewItemIndex);
  lvFilters.ItemIndex := NewItemIndex;
  FAssignedListItemIndex := NewItemIndex;
  FIsModified := True;
end;

procedure TfrmExtensions.lvFiltersDragOver(Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Sender = Source) and (Sender = lvFilters) and
    (TListBox(Sender).ItemIndex >= 0);
end;

{$POP}
end.
