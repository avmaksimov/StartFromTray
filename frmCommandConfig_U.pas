unit frmCommandConfig_U;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  Dialogs, ImgList, Menus, Buttons, Generics.Collections, CommandsClass_U;

type
  TImageIndexList = class(TList<Integer>);

  TfrmCommandConfig = class(TFrame)
    edtCaption: TLabeledEdit;
    lblCommand: TLabel;
    btnEdit: TButton;
    btnRun: TButton;
    edtCommand: TEdit;
    edtCommandOpenDialog: TOpenDialog;
    lblIsRunning: TLabel;
    Timer: TTimer;
    lblRunInfo: TLabel;
    ImageList: TImageList;
    edtCommandParameters: TLabeledEdit;
    btnChangeIcon: TButton;
    ppMenuChangeIcon: TPopupMenu;
    miChooseFromFileRes: TMenuItem;
    miDefaultIcon: TMenuItem;
    miChooseFromFileExt: TMenuItem;
    cbRunAsAdmin: TCheckBox;
    Bevel: TBevel;
    btnChooseFile: TSpeedButton;
    btnChooseFolder: TSpeedButton;
    procedure edtCaptionChange(Sender: TObject);
    procedure btnEditClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure edtCommandChange(Sender: TObject);
    procedure btnChooseFileClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure miDefaultIconClick(Sender: TObject);
    procedure miChooseFromFileResClick(Sender: TObject);
    procedure btnChangeIconClick(Sender: TObject);
    procedure miChooseFromFileExtClick(Sender: TObject);
    procedure edtCommandParametersChange(Sender: TObject);
    procedure cbRunAsAdminClick(Sender: TObject);
    procedure btnChooseFolderClick(Sender: TObject);
  private
    FAssignedTreeNode: TTreeNode;
    FAssignedCaption: string;
    FAssignedCommandData: TCommandData;
    FAssigningState: Boolean;
    FOldCommandText: string;
    FTreeImageList: TImageList;
    FListDeletedImageIndexes: TImageIndexList;
    function GetIsModified: Boolean;
    procedure SetCaption(const AValue: string);
    procedure UpdateIcon;
  protected
    procedure SetEnabled(Value: Boolean); override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure SetFocus; override;
    procedure ClearAssigned;
    function SaveAssigned: Boolean;
    function CheckFileCommandExists: Boolean;
    property AssignedTreeNode: TTreeNode read FAssignedTreeNode;
    property TreeImageList: TImageList read FTreeImageList write FTreeImageList;
    property ListDeletedImageIndexes: TImageIndexList read FListDeletedImageIndexes write FListDeletedImageIndexes;
    property Caption: string write SetCaption;
    property IsModified: Boolean read GetIsModified;
  end;

implementation

uses
  Windows, Masks, Graphics,
  LangsU, frmChooseExt_U, CommonU, FilterClass_U;

function PickIconDlgCompat(AOwnerWnd: HWND; AIconPath: PWideChar;
  AIconPathLength: UINT; var AIconIndex: Integer): Integer; stdcall;
  external 'shell32.dll' name 'PickIconDlg';

threadvar
  GCenterDialogHook: HHOOK;
  GCenterDialogOwner: HWND;

procedure CenterWindowOnOwner(AWindow, AOwner: HWND);
var
  WindowRect, OwnerRect: TRect;
  X, Y: Integer;
begin
  if (AWindow = 0) or (AOwner = 0) then
    Exit;

  if not GetWindowRect(AWindow, WindowRect) then
    Exit;

  if not GetWindowRect(AOwner, OwnerRect) then
    Exit;

  X := OwnerRect.Left +
    ((OwnerRect.Right - OwnerRect.Left -
      (WindowRect.Right - WindowRect.Left)) div 2);

  Y := OwnerRect.Top +
    ((OwnerRect.Bottom - OwnerRect.Top -
      (WindowRect.Bottom - WindowRect.Top)) div 2);

  SetWindowPos(
    AWindow,
    0,
    X,
    Y,
    0,
    0,
    SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE
  );
end;

function CenterDialogHookProc(Code: Integer; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
var
  CurrentHook: HHOOK;
  DialogWindow: HWND;
begin
  CurrentHook := GCenterDialogHook;

  if (Code = HCBT_ACTIVATE) and (GCenterDialogOwner <> 0) then
  begin
    DialogWindow := HWND(WParam);

    if DialogWindow <> GCenterDialogOwner then
    begin
      CenterWindowOnOwner(DialogWindow, GCenterDialogOwner);

      GCenterDialogOwner := 0;
      GCenterDialogHook := 0;
      UnhookWindowsHookEx(CurrentHook);
    end;
  end;

  Result := CallNextHookEx(CurrentHook, Code, WParam, LParam);
end;

function PickIconDlgCentered(AOwnerWnd: HWND; AIconPath: PWideChar;
  AIconPathLength: UINT; var AIconIndex: Integer): Integer;
begin
  AOwnerWnd := GetAncestor(AOwnerWnd, GA_ROOT);

  GCenterDialogOwner := AOwnerWnd;
  GCenterDialogHook := SetWindowsHookEx(
    WH_CBT,
    @CenterDialogHookProc,
    0,
    GetCurrentThreadId
  );

  try
    Result := PickIconDlgCompat(
      AOwnerWnd,
      AIconPath,
      AIconPathLength,
      AIconIndex
    );
  finally
    if GCenterDialogHook <> 0 then
    begin
      UnhookWindowsHookEx(GCenterDialogHook);
      GCenterDialogHook := 0;
    end;

    GCenterDialogOwner := 0;
  end;
end;

const
  sLangFormFramePath = 'frmConfig\frmCommandConfig';

{$R *.lfm}

function FileNameWithoutExtension(const FileName: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(FileName), '');
end;

function SetDefFolderAndReturnFilename(const ACommand: string;
  out ADefaultFolder: string): string;
var
  Command, NewDefaultDir: string;
begin
  if Trim(ACommand) = '' then
  begin
    ADefaultFolder := '';
    Exit('');
  end;

  Command := ExpandFileName(ACommand);
  Command := ExcludeTrailingPathDelimiter(Command);
  ADefaultFolder := Command;
  while (ADefaultFolder <> '') and (not DirectoryExists(ADefaultFolder)) do
  begin
    NewDefaultDir := ExtractFileDir(ADefaultFolder);
    if NewDefaultDir <> ADefaultFolder then
      ADefaultFolder := NewDefaultDir
    else
    begin
      ADefaultFolder := '';
      Exit(ACommand);
    end;
  end;

  if ADefaultFolder = '' then
    Result := ACommand
  else
    Result := Copy(Command, Length(ADefaultFolder) + 2, MaxInt);
end;

procedure TfrmCommandConfig.btnChangeIconClick(Sender: TObject);
var
  PopupPoint: TPoint;
begin
  if Assigned(FAssignedCommandData) then
    case FAssignedCommandData.IconType of
        citFromFileRes: miChooseFromFileRes.Checked := True;
        citFromFileExt: miChooseFromFileExt.Checked := True;
        else miDefaultIcon.Checked := True;
      end;

  PopupPoint := btnChangeIcon.ClientToScreen(
    Types.Point(0, btnChangeIcon.Height));
  btnChangeIcon.PopupMenu.Popup(PopupPoint.X, PopupPoint.Y);
end;

procedure TfrmCommandConfig.btnChooseFolderClick(Sender: TObject);
var
  SelectedFolder: string;
begin
  SelectedFolder := Trim(edtCommand.Text);
    if not DirectoryExists(SelectedFolder) then
      SelectedFolder := ExtractFileDir(SelectedFolder);
  if SelectDirectory(btnChooseFolder.Hint, '', SelectedFolder) then
    edtCommand.Text := IncludeTrailingPathDelimiter(SelectedFolder);
end;

procedure TfrmCommandConfig.btnEditClick(Sender: TObject);
begin
  if Assigned(FAssignedCommandData) then
    FAssignedCommandData.Edit;
end;

procedure TfrmCommandConfig.btnRunClick(Sender: TObject);
begin
  if Assigned(FAssignedCommandData) then
    FAssignedCommandData.Run(crtNormalRun);
end;

procedure TfrmCommandConfig.cbRunAsAdminClick(Sender: TObject);
begin
  if (not FAssigningState) and Assigned(FAssignedCommandData) then
    FAssignedCommandData.IsRunAsAdmin := cbRunAsAdmin.Checked;
end;

procedure TfrmCommandConfig.edtCaptionChange(Sender: TObject);
begin
  if (not FAssigningState) and Assigned(FAssignedCommandData) and
    Assigned(FAssignedTreeNode) then
    FAssignedTreeNode.Text := edtCaption.Text;
end;

procedure TfrmCommandConfig.edtCommandChange(Sender: TObject);
begin
  if FAssigningState or (not Assigned(FAssignedCommandData)) then
    Exit;

  if edtCaption.Text = FileNameWithoutExtension(FOldCommandText) then
    edtCaption.Text := FileNameWithoutExtension(edtCommand.Text);
  FOldCommandText := edtCommand.Text;
  FAssignedCommandData.Command := edtCommand.Text;
  CheckFileCommandExists;
  UpdateIcon;
end;

procedure TfrmCommandConfig.edtCommandParametersChange(Sender: TObject);
begin
  if (not FAssigningState) and Assigned(FAssignedCommandData) then
    FAssignedCommandData.CommandParameters := edtCommandParameters.Text;
end;

procedure TfrmCommandConfig.btnChooseFileClick(Sender: TObject);
var
  Command, DefaultFolder, Extensions, Mask, Extension, BaseFilter: string;
  I, J, FilterPosition: Integer;
  ExtensionList: TStringList;
begin
  Command := Trim(edtCommand.Text);
  BaseFilter := edtCommandOpenDialog.Filter;

  edtCommandOpenDialog.FilterIndex := 1;
  if MatchesMask(Command, '*.exe') then
    edtCommandOpenDialog.FilterIndex := 2;

  FilterPosition := 2;
  ExtensionList := TStringList.Create;
  try
    for I := 0 to Filters.Count - 1 do
    begin
      Extensions := Trim(TFilterData(Filters.Objects[I]).Extensions);
      if Extensions = '' then
        Continue;

      ExtensionList.Clear;
      ExtensionList.StrictDelimiter := True;
      ExtensionList.Delimiter := ';';
      ExtensionList.DelimitedText := Extensions;

      Mask := '';
      for J := 0 to ExtensionList.Count - 1 do
      begin
        Extension := Trim(ExtensionList[J]);
        if Extension = '' then
          Continue;

        if Mask <> '' then
          Mask := Mask + ';';
        Mask := Mask + '*.' + Extension;
      end;

      if Mask = '' then
        Continue;

      Inc(FilterPosition);
      edtCommandOpenDialog.Filter :=
        edtCommandOpenDialog.Filter + '|' +
        Filters[I] + ' (' + Mask + ')|' + Mask;

      if (edtCommandOpenDialog.FilterIndex = 1) and
        MyMatchesExtensions(Command, Extensions) then
        edtCommandOpenDialog.FilterIndex := FilterPosition;
    end;

    if FileExists(Command) then
    begin
      edtCommandOpenDialog.InitialDir := ExtractFileDir(Command);
      edtCommandOpenDialog.FileName := ExtractFileName(Command);
    end
    else
    begin
      edtCommandOpenDialog.FileName :=
        SetDefFolderAndReturnFilename(Command, DefaultFolder);
      edtCommandOpenDialog.InitialDir := DefaultFolder;
    end;

    if edtCommandOpenDialog.Execute then
      edtCommand.Text := edtCommandOpenDialog.FileName;
  finally
    edtCommandOpenDialog.Filter := BaseFilter;
    ExtensionList.Free;
  end;
end;

function TfrmCommandConfig.GetIsModified: Boolean;
begin
  if not Enabled then
    Exit(False);

  Result := edtCaption.Text <> FAssignedCaption;
  if (not Result) and Assigned(FAssignedTreeNode) and
    Assigned(FAssignedTreeNode.Data) and Assigned(FAssignedCommandData) then
    with TCommandData(FAssignedTreeNode.Data) do
      Result := (FAssignedCommandData.Command <> Command) or
        (FAssignedCommandData.CommandParameters <> CommandParameters) or
        (FAssignedCommandData.IsRunAsAdmin <> IsRunAsAdmin) or
        (FAssignedCommandData.IconType <> IconType) or
        ((FAssignedCommandData.IconType = citFromFileExt) and
          (FAssignedCommandData.IconExt <> IconExt)) or
        ((FAssignedCommandData.IconType = citFromFileRes) and
          ((FAssignedCommandData.IconFilename <> IconFileName) or
           (FAssignedCommandData.IconFileIndex <> IconFileIndex)));
end;

procedure TfrmCommandConfig.miChooseFromFileExtClick(Sender: TObject);
var
  Parameters, Extension: string;
  Parts: TStringList;
  I: Integer;
begin
  if not Assigned(FAssignedCommandData) then
    Exit;

  frmChooseExt.Extension := FAssignedCommandData.IconExt;
  if frmChooseExt.Extension = '' then
  begin
    Parts := TStringList.Create;
    try
      Parameters := edtCommandParameters.Text;
      ExtractStrings([' ', #9], ['"'], PChar(Parameters), Parts);
      for I := 0 to Parts.Count - 1 do
      begin
        Extension := ExtractFileExt(Parts[I]);
        if Length(Extension) > 1 then
          frmChooseExt.StartWithExtensions.Add(Copy(Extension, 2, MaxInt));
      end;
    finally
      Parts.Free;
    end;
  end;

  if frmChooseExt.ShowModal = mrOK then
  begin
    FAssignedCommandData.IconType := citFromFileExt;
    FAssignedCommandData.IconExt := frmChooseExt.Extension;
    UpdateIcon;
    miChooseFromFileExt.Checked := True;
  end;
end;

procedure TfrmCommandConfig.miChooseFromFileResClick(Sender: TObject);
var
  FileName, Extension: string;
  IconIndex, CharIndex: Integer;
  FileNameBuffer: array[0..MAX_PATH] of WideChar;
  WideFileName: UnicodeString;
begin
  if not Assigned(FAssignedTreeNode) or
    not Assigned(FAssignedTreeNode.Data) then
    Exit;

  FileName := FAssignedCommandData.IconFilename;
  if FileName = '' then
  begin
    Extension := LowerCase(ExtractFileExt(FAssignedCommandData.Command));
    if (Extension = '.exe') or (Extension = '.dll') or
      (Extension = '.ico') then
      FileName := FAssignedCommandData.Command;
  end;
  IconIndex := FAssignedCommandData.IconFileIndex;
  WideFileName := Copy(UTF8Decode(FileName), 1, High(FileNameBuffer));
  for CharIndex := 1 to Length(WideFileName) do
    FileNameBuffer[CharIndex - 1] := WideFileName[CharIndex];
  FileNameBuffer[Length(WideFileName)] := #0;
  if PickIconDlgCentered(
    HWND(GetParentForm(Self).Handle),
    PWideChar(@FileNameBuffer[0]),
    Length(FileNameBuffer),
    IconIndex
  ) = 1 then
  begin
    FAssignedCommandData.IconType := citFromFileRes;
    FAssignedCommandData.IconFilename :=
      UTF8Encode(UnicodeString(PWideChar(@FileNameBuffer[0])));
    FAssignedCommandData.IconFileIndex := IconIndex;
    UpdateIcon;
    miChooseFromFileRes.Checked := True;
  end;
end;

procedure TfrmCommandConfig.miDefaultIconClick(Sender: TObject);
begin
  if not Assigned(FAssignedCommandData) then
    Exit;
  FAssignedCommandData.IconType := citDefault;
  UpdateIcon;
  miDefaultIcon.Checked := True;
end;

procedure TfrmCommandConfig.SetCaption(const AValue: string);
begin
  if edtCaption.Text <> AValue then
    edtCaption.Text := AValue;
end;

procedure TfrmCommandConfig.SetEnabled(Value: Boolean);
begin
  if Enabled = Value then
    Exit;
  inherited SetEnabled(Value);
  M_SetChildsEnable(Self, Value);
end;

procedure TfrmCommandConfig.SetFocus;
begin
  edtCaption.SetFocus;
end;

procedure TfrmCommandConfig.TimerTimer(Sender: TObject);
const
  LangKeys: array[Boolean] of string = ('IsNotRunning', 'IsRunning');
begin
  if not Assigned(FAssignedCommandData) then
  begin
    lblIsRunning.Caption := '';
    Exit;
  end;
  lblIsRunning.Caption := GetLangString(sLangFormFramePath,
    LangKeys[FAssignedCommandData.isRunning]);
end;

procedure TfrmCommandConfig.UpdateIcon;
var
  ImageIndex: Integer;
begin
  if not Assigned(FAssignedCommandData) or
    not Assigned(FAssignedTreeNode) or not Assigned(TreeImageList) then
    Exit;
  ImageIndex := FAssignedCommandData.GetImageIndex(TreeImageList);
  if (FAssignedTreeNode.ImageIndex > 0) and
    Assigned(ListDeletedImageIndexes) then
    ListDeletedImageIndexes.Add(FAssignedTreeNode.ImageIndex);
  FAssignedTreeNode.ImageIndex := ImageIndex;
  FAssignedTreeNode.SelectedIndex := ImageIndex;
  FAssignedTreeNode.TreeView.Invalidate;
end;

function TfrmCommandConfig.CheckFileCommandExists: Boolean;
begin
  Result := Assigned(FAssignedCommandData) and
    (FAssignedCommandData.ExtendCommandToFullName <> '');
  if Result then
    edtCommand.Font.Color := clWindowText
  else
    edtCommand.Font.Color := clRed;
end;

procedure TfrmCommandConfig.ClearAssigned;
begin
  FAssigningState := True;
  try
    FAssignedTreeNode := nil;
    FAssignedCaption := '';
    FreeAndNil(FAssignedCommandData);
    edtCaption.Text := '';
    edtCommand.Text := '';
    FOldCommandText := '';
    lblIsRunning.Caption := '';
    edtCommandParameters.Text := '';
    cbRunAsAdmin.Checked := False;
  finally
    FAssigningState := False;
  end;
end;

constructor TfrmCommandConfig.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  CommonU.BuildBrowseButtonImages(ImageList);
  FAssignedCommandData := nil;
  ClearAssigned;
end;

destructor TfrmCommandConfig.Destroy;
begin
  FAssignedTreeNode := nil;
  FreeAndNil(FAssignedCommandData);
  inherited Destroy;
end;

procedure TfrmCommandConfig.Assign(Source: TPersistent);
var
  IsCommand: Boolean;
  I: Integer;
begin
  if not (Source is TTreeNode) then
    raise Exception.Create('TfrmCommandConfig.Assign expects TTreeNode');

  FAssigningState := True;
  try
    FAssignedTreeNode := TTreeNode(Source);
    if not Assigned(FAssignedTreeNode.Data) then
      raise Exception.Create('not Assigned(FAssignedTreeNode.Data)');
    Enabled := True;
    FAssignedCaption := FAssignedTreeNode.Text;
    edtCaption.Text := FAssignedCaption;
    FreeAndNil(FAssignedCommandData);
    FAssignedCommandData := TCommandData.Create;
    TCommandData(FAssignedTreeNode.Data).Assign(FAssignedCommandData);
    IsCommand := not FAssignedCommandData.isGroup;

    edtCommand.Text := FAssignedCommandData.Command;
    FOldCommandText := FAssignedCommandData.Command;
    edtCommandParameters.Text := FAssignedCommandData.CommandParameters;
    cbRunAsAdmin.Checked := FAssignedCommandData.IsRunAsAdmin;
    case FAssignedCommandData.IconType of
      citFromFileRes: miChooseFromFileRes.Checked := True;
      citFromFileExt: miChooseFromFileExt.Checked := True;
      else miDefaultIcon.Checked := True;
    end;
    CheckFileCommandExists;
    for I := 0 to ControlCount - 1 do
      if Controls[I].Tag <> 1 then
        Controls[I].Visible := IsCommand;
    Timer.Enabled := True;
  finally
    FAssigningState := False;
  end;
end;

function TfrmCommandConfig.SaveAssigned: Boolean;
var
  ExceptionText, NewCaption: string;
begin
  if (FAssignedTreeNode = nil) or (FAssignedCommandData = nil) then
    Exit(True);

  ExceptionText := '';
  NewCaption := Trim(edtCaption.Text);
  if NewCaption = '' then
    ExceptionText := GetLangString('LangStrings', 'ErrorEmptyName');
  if (not FAssignedCommandData.isGroup) and
    (FAssignedCommandData.Command = '') then
  begin
    if ExceptionText <> '' then
      ExceptionText := ExceptionText + LineEnding + LineEnding;
    ExceptionText := ExceptionText +
      GetLangString(sLangFormFramePath, 'ErrorCommand');
  end;
  if ExceptionText <> '' then
  begin
    ErrorDialog(Owner as TForm, ExceptionText);
    Exit(False);
  end;

  FAssignedCommandData.Assign(TCommandData(FAssignedTreeNode.Data));
  FAssignedTreeNode.Text := NewCaption;
  FAssignedCaption := NewCaption;
  Result := True;
end;

end.
