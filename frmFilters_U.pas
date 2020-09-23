unit frmFilters_U;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Mask, {JvExMask, JvToolEdit,} ComCtrls,
  FilterClass_U, Vcl.ImgList, System.ImageList;

type
  TfrmExtensions = class(TForm)
    gbExtensions: TGroupBox;
    gbFiltersActions: TGroupBox;
    btnExtensionAdd: TButton;
    btnExtensionDelete: TButton;
    gbMainButtons: TGroupBox;
    btnOK: TButton;
    btnCancel: TButton;
    lvExtensions: TListBox;
    btnExtensionDown: TButton;
    btnExtensionUp: TButton;
    gbExtensionProperties: TGroupBox;
    lblRunHelper: TLabel;
    lblEditHelper: TLabel;
    edtExtensions: TLabeledEdit;
    edtName: TLabeledEdit;
    OpenDialog: TFileOpenDialog;
    ImageList: TImageList;
    edtEditHelper: TButtonedEdit;
    edtRunHelper: TButtonedEdit;
    procedure btnExtensionAddClick(Sender: TObject);
    procedure btnExtensionDeleteClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnExtensionUpClick(Sender: TObject);
    procedure btnExtensionDownClick(Sender: TObject);
    procedure edtNameChange(Sender: TObject);
    procedure lvExtensionsClick(Sender: TObject);
    procedure edtEditRunHelperAfterDialog(Sender: TObject; var AName: string;
      var AAction: Boolean);
    procedure edtEdit_or_RunHelperRightButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    FAssignedData: TFilterData;
    FAssignedListItemIndex: Integer;
    FAssigningListItemIndex: Boolean;

    procedure AssignCurrentItem;
    procedure SaveAssignedItem;
  public
    { Public declarations }
    procedure AssignFilters(AFilters: TStringList);
    procedure MoveToFilters(AFilters: TStringList);
    procedure ClearAllIfCancel;
  end;

var
  frmExtensions: TfrmExtensions;

implementation

uses LangsU, CommonU;

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

    lvExtensions.Items.AddObject(AFilters[i], vFilter);
  end;

  if AFilters.Count > 0 then
    lvExtensions.ItemIndex := 0;

  AssignCurrentItem;
end;

procedure TfrmExtensions.MoveToFilters(AFilters: TStringList);
var
  i: Integer;
begin
  for i := 0 to AFilters.Count - 1 do
    AFilters.Objects[i].Free;

  AFilters.Clear;

  for i := 0 to lvExtensions.Items.Count - 1 do
    AFilters.AddObject(lvExtensions.Items[i],
      TFilterData(lvExtensions.Items.Objects[i]));

  lvExtensions.Clear;

end;

procedure TfrmExtensions.AssignCurrentItem;
var
  bSelected: Boolean;
begin
  bSelected := lvExtensions.ItemIndex > -1;

  M_SetChildsEnable(gbExtensionProperties, bSelected);

  FAssigningListItemIndex := True;

  if bSelected then
  begin
    FAssignedListItemIndex := lvExtensions.ItemIndex;

    edtName.Text := lvExtensions.Items[FAssignedListItemIndex];

    if Visible then
      edtName.SetFocus;

    FAssignedData := TFilterData(lvExtensions.Items.Objects
      [FAssignedListItemIndex]);

    with FAssignedData do
    begin
      edtExtensions.Text := Extensions;

      edtEditHelper.Text := EditHelper;
      edtRunHelper.Text := RunHelper;
    end;
  end
  else
  begin
    edtName.Text := '';

    edtExtensions.Text := '';

    edtEditHelper.Text := '';
    edtRunHelper.Text := '';

    FAssignedData := nil;
    FAssignedListItemIndex := -1;
  end;
  FAssigningListItemIndex := False;
end;

procedure TfrmExtensions.SaveAssignedItem;
begin
  if (FAssignedListItemIndex < 0) or not Assigned(FAssignedData) then
    Exit;

  lvExtensions.Items[FAssignedListItemIndex] := Trim(edtName.Text);
  with FAssignedData do
  begin
    Extensions := Trim(edtExtensions.Text);

    EditHelper := Trim(edtEditHelper.Text);
    RunHelper := Trim(edtRunHelper.Text);
  end;
end;

procedure TfrmExtensions.btnCancelClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to lvExtensions.Items.Count - 1 do
    TFilterData(lvExtensions.Items.Objects[i]).Free;

  lvExtensions.Clear;
end;

procedure TfrmExtensions.btnExtensionUpClick(Sender: TObject);
var
  newItemIndex: Integer;
begin
  with lvExtensions do
    if (ItemIndex > 0) then
    begin
      newItemIndex := ItemIndex - 1;
      Items.Exchange(ItemIndex, newItemIndex);
      ItemIndex := newItemIndex;
      FAssignedListItemIndex := newItemIndex;
    end;
end;

procedure TfrmExtensions.btnExtensionDownClick(Sender: TObject);
var
  newItemIndex: Integer;
begin
  with lvExtensions do
    if (ItemIndex > -1) and (ItemIndex < Count - 1) then
    begin
      newItemIndex := ItemIndex + 1;
      Items.Exchange(ItemIndex, newItemIndex);
      ItemIndex := newItemIndex;
      FAssignedListItemIndex := newItemIndex;
    end;
end;

procedure TfrmExtensions.btnExtensionAddClick(Sender: TObject);
begin
  SaveAssignedItem;

  with lvExtensions do
  begin
    Items.AddObject('', TFilterData.Create);

    ItemIndex := Items.Count - 1;
  end;

  AssignCurrentItem;
end;

procedure TfrmExtensions.btnExtensionDeleteClick(Sender: TObject);
var
  newItemIndex: Integer;
begin
  with lvExtensions do
  begin
    // if (ItemIndex <= -1) and (Count > 0) then Exit;

    if (ItemIndex <= -1) or not AskForDeletion(Self, Items[ItemIndex]) then
      Exit;

    newItemIndex := ItemIndex;

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
end;

procedure TfrmExtensions.ClearAllIfCancel;
var
  i: Integer;
begin
  with lvExtensions do
  begin
    for i := 0 to Items.Count - 1 do
      TFilterData(Items.Objects[i]).Free;

    Clear;
  end;
end;

procedure TfrmExtensions.edtEditRunHelperAfterDialog(Sender: TObject;
  var AName: string; var AAction: Boolean);
begin
  AName := ExtractRelativePath(GetCurrentDir, AName);
end;

procedure TfrmExtensions.edtNameChange(Sender: TObject);
begin
  if not FAssigningListItemIndex then
    lvExtensions.Items[lvExtensions.ItemIndex] := edtName.Text;
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

procedure TfrmExtensions.FormShow(Sender: TObject);
begin
  FAssigningListItemIndex := False;
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
end;

procedure TfrmExtensions.lvExtensionsClick(Sender: TObject);
begin
  if (lvExtensions.ItemIndex < 0) or
    (lvExtensions.ItemIndex = FAssignedListItemIndex) then
    Exit;

  SaveAssignedItem;

  AssignCurrentItem;
end;

end.
