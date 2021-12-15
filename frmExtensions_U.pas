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
    lblRunHelper: TLabel;
    lblEditHelper: TLabel;
    edtExtensions: TLabeledEdit;
    edtName: TLabeledEdit;
    OpenDialog: TFileOpenDialog;
    ImageList: TImageList;
    edtEditHelper: TButtonedEdit;
    edtRunHelper: TButtonedEdit;
    TitleBarPanel: TTitleBarPanel;
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
    //FAssignedListItemIndex := lvFilters.ItemIndex;

    //edtName.Text := lvFilters.Items[FAssignedListItemIndex];

    FAssignedCaption := lvFilters.Items[FAssignedListItemIndex];
    FAssignedData := TFilterData(lvFilters.Items.Objects
      [FAssignedListItemIndex]);

    edtName.Text := FAssignedCaption;

    //if Visible then
    //  edtName.SetFocus;

    with FAssignedData do
    begin
      edtExtensions.Text := Extensions;

      edtEditHelper.Text := Edit;
      edtRunHelper.Text := Run;
    end;
  end
  else
  begin
    FAssignedCaption := '';
    edtName.Text := '';

    edtExtensions.Text := '';

    edtEditHelper.Text := '';
    edtRunHelper.Text := '';

    FAssignedData := nil;
    //FAssignedListItemIndex := -1;
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

  lvFilters.Items[FAssignedListItemIndex] := vName; //Trim(edtName.Text);
  with FAssignedData do
  begin
    Extensions := vExtensions; //Trim(edtExtensions.Text);

    Edit := Trim(edtEditHelper.Text);
    Run := Trim(edtRunHelper.Text);
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
var
  newItemIndex: Integer;
begin
  with lvFilters do
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
  with lvFilters do
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
var
  newItemIndex: Integer;
begin
  with lvFilters do
  begin
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
var
  i: Integer;
begin
  SaveAssignedItem;
  for i := 0 to Filters.Count - 1 do
    Filters.Objects[i].Free;

  Filters.Clear;

  for i := 0 to lvFilters.Items.Count - 1 do
    Filters.AddObject(lvFilters.Items[i],
      TFilterData(lvFilters.Items.Objects[i]));

  lvFilters.Clear;

  Filters_SaveToFile;
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
        (edtRunHelper.Text <> Run) or (edtEditHelper.Text <> Edit);
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
