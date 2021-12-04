unit frmCommandConfig_U;

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  CommandsClass_U, ComCtrls, Mask, Windows, DateUtils, Types,
  FilterClass_U, Dialogs, Vcl.ImgList, Vcl.FileCtrl, System.UITypes,
  Winapi.ShellAPI, Winapi.CommCtrl, System.ImageList, Vcl.Buttons, Vcl.Menus,
  System.Generics.Collections;

type

  { TfrmCommandConfig }

  TfrmCommandConfig = class(TFrame)
    cbIsVisible: TCheckBox;
    edtCaption: TLabeledEdit;
    lblCommand: TLabel;
    btnEdit: TButton;
    btnRun: TButton;
    edtCommand: TButtonedEdit;
    edtCommandOpenDialog: TFileOpenDialog;
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
    Bevel1: TBevel;
    procedure edtCaptionChange(Sender: TObject);
    { procedure edtCommandBeforeDialog(Sender: TObject; var AName: string;
      var AAction: Boolean); }
    procedure btnEditClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure edtCommandChange(Sender: TObject);
    procedure edtCommandRightButtonClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure miDefaultIconClick(Sender: TObject);
    procedure miChooseFromFileResClick(Sender: TObject);
    procedure btnChangeIconClick(Sender: TObject);
    procedure miChooseFromFileExtClick(Sender: TObject);
    procedure edtCommandParametersChange(Sender: TObject);
    procedure cbRunAsAdminClick(Sender: TObject);
  private
    { private declarations }
    FAssignedTreeNode: TTreeNode;
    FAssignedCaption: string; // чтобы понять, что название изменилось
    FAssignedCommandData: TCommandData;
    //FAssignedIconFilename: string;
    //FAssignedIconFileIndex: Integer;

    FAssigningState: boolean;
    //using then editing edtCommand
    FOldCommandText: string;

    // links to Parent form the component and the list
    FTreeImageList: TImageList;
    FListDeletedImageIndexes: TList<Word>;

    function GetIsModified: boolean;
    procedure SetCaption(const AValue: string);
    procedure UpdateIcon;
  protected
    procedure SetEnabled(Value: boolean); override;
  public
    { public declarations }
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;

    procedure SetFocus; override;

    procedure ClearAssigned;
    function SaveAssigned: Boolean;

    // to draw with red and strikeline for TreeNode and edtCommand
    function CheckFileCommandExists: boolean;

    // procedure RefreshCaption;

    property AssignedTreeNode: TTreeNode read FAssignedTreeNode;
    // links to Parent form the component and the list
    property TreeImageList: TImageList read FTreeImageList write FTreeImageList;
    property ListDeletedImageIndexes: TList<Word> read FListDeletedImageIndexes write FListDeletedImageIndexes;
  published
    property Caption: string write SetCaption;
    property IsModified: boolean read GetIsModified;
  end;

implementation

uses LangsU, frmConfig_U, frmChooseExt_U, System.StrUtils, CommonU, System.Masks, System.Math,
  Winapi.ShlObj;

{$R *.dfm}
{ TfrmCommandConfig }

procedure TfrmCommandConfig.btnChangeIconClick(Sender: TObject);
begin
  //ppMenuChangeIcon.Popup(frmConfig.Left + btnChangeIcon.Left, frmConfig.Top + btnChangeIcon.Top);
  with btnChangeIcon.ClientToScreen(point(0, btnChangeIcon.Height)) do
    btnChangeIcon.PopupMenu.Popup(X, Y);
end;

procedure TfrmCommandConfig.btnEditClick(Sender: TObject);
begin
  {if SaveAssigned then
    TCommandData(FAssignedTreeNode.Data).Edit;}
  if Assigned(FAssignedCommandData) then
    FAssignedCommandData.Edit;
end;

procedure TfrmCommandConfig.btnRunClick(Sender: TObject);
begin
  {if SaveAssigned then
    TCommandData(FAssignedTreeNode.Data).Run(crtNormalRun);}
  if Assigned(FAssignedCommandData) then
    FAssignedCommandData.Run(crtNormalRun);
end;

procedure TfrmCommandConfig.cbRunAsAdminClick(Sender: TObject);
begin
  if not FAssigningState and Assigned(FAssignedCommandData) then
    FAssignedCommandData.IsRunAsAdmin := cbRunAsAdmin.Checked;
end;

procedure TfrmCommandConfig.edtCaptionChange(Sender: TObject);
begin
  if not FAssigningState and Assigned(FAssignedCommandData) then
    FAssignedTreeNode.Text := edtCaption.Text;
end;

procedure TfrmCommandConfig.edtCommandChange(Sender: TObject);
begin
  if FAssigningState then
    Exit;

  if edtCaption.Text = FOldCommandText then
  begin
    var s := ExtractFileName(edtCommand.Text);
    var i := Pos('.', s);
    if i > 0 then
      edtCaption.Text := Copy(s, 1, i - 1)
    else
      edtCaption.Text := s;
  end;

  FOldCommandText := edtCommand.Text;

  CheckFileCommandExists;

  FAssignedCommandData.Command := edtCommand.Text;

  UpdateIcon;

end;

procedure TfrmCommandConfig.edtCommandParametersChange(Sender: TObject);
begin
  if not FAssigningState and Assigned(FAssignedCommandData) then
    FAssignedCommandData.CommandParameters := edtCommandParameters.Text;
end;

procedure TfrmCommandConfig.edtCommandRightButtonClick(Sender: TObject);
begin
  var sCommand := Trim(edtCommand.Text);
  with edtCommandOpenDialog do
  begin
    FileTypes.Clear;

    with FileTypes.Add do
    begin
      DisplayName := GetLangString('LangStrings', 'FileDialogExecutableFile');
      FileMask := '*.exe';
    end;

    var bMatchedMaskFound := MatchesMask(sCommand, '*.exe');

    if bMatchedMaskFound then
      FileTypeIndex := 1
    else
    begin
      // find FileType
      for var i := 0 to Filters.Count - 1 do
      begin
        var vExtensions := (TFilterData(Filters.Objects[i]).Extensions).Trim;
        if vExtensions <> '' then
          begin
            with FileTypes.Add do
            begin
              var vExtensionArray := vExtensions.Split([';']);
              FileMask := '*.' + vExtensionArray[0].Trim;
              for var j := 1 to High(vExtensionArray) do
                FileMask := FileMask + '; *.' + vExtensionArray[j].Trim;
              DisplayName := Filters[i] + ' (' + FileMask + ')';
              // FileMask := vMasks;
            end;
            // found better FileTypeIndex than .exe
            if not bMatchedMaskFound and (MyMatchesExtensions(sCommand, vExtensions))
            then
            begin
              FileTypeIndex := i + 2; // numbering from 1 plus '*' before
              bMatchedMaskFound := True;
            end;
          end;
      end;
    end;

    with FileTypes.Add do
    begin
      DisplayName := GetLangString('LangStrings', 'FileDialogAnyFile');
      // 'Any file';
      FileMask := '*';
    end;

    if not bMatchedMaskFound then
      FileTypeIndex := FileTypes.Count; // default - all files

    DefaultFolder := ExtractFileDir(sCommand);
    FileName := ExtractFileName(sCommand);
    if Execute then
      edtCommand.Text := FileName;
  end;
end;

function TfrmCommandConfig.GetIsModified: boolean;
begin
  if not Enabled then
    Exit(False); // если заблокировано, то нет смысла

  Result := edtCaption.Text <> FAssignedCaption;

  if not Result and Assigned(FAssignedTreeNode) and Assigned(FAssignedTreeNode.Data) and
      Assigned(FAssignedCommandData) then
    begin
    {if (FAssignedTreeNode.Data = nil) or (FAssignedCommandData = nil) then
      Exit;}
    with TCommandData(FAssignedTreeNode.Data) do
      Result := (FAssignedCommandData.Command <> Command) or
        (FAssignedCommandData.CommandParameters <> CommandParameters) or
        (FAssignedCommandData.IsRunAsAdmin <> IsRunAsAdmin) or
        (FAssignedCommandData.IconType <> IconType) or
        ((FAssignedCommandData.IconType = citFromFileExt) and (FAssignedCommandData.IconExt <> IconExt)) or
        ((FAssignedCommandData.IconType = citFromFileRes) and (FAssignedCommandData.IconFilename <> IconFileName)
            and (FAssignedCommandData.IconFileIndex <> IconFileIndex));
    {with TCommandData(FAssignedTreeNode.Data) do
      Result := Result or (edtCommand.Text <> Command) or
        (edtCommandParameters.Text <> CommandParameters) or
        (cbRunAsAdmin.Checked <> IsRunAsAdmin) or
        (FAssignedCommandData.IconFilename <> IconFilename) or
        (FAssignedCommandData.IconFileIndex <> IconFileIndex);}
    end;
end;

procedure TfrmCommandConfig.miChooseFromFileExtClick(Sender: TObject);
begin
with frmChooseExt do
  begin
  Extension := FAssignedCommandData.IconExt;
  if ShowModal = mrOk then
    begin
    FAssignedCommandData.IconType := citFromFileExt;
    FAssignedCommandData.IconExt := Extension;
    UpdateIcon;
    miChooseFromFileExt.Checked := True;
    end;
  end;
end;

procedure TfrmCommandConfig.miChooseFromFileResClick(Sender: TObject);
begin
  if not Assigned(FAssignedTreeNode) or not Assigned(FAssignedTreeNode.Data) then
    Exit;

  var vFileName: string := FAssignedCommandData.IconFilename;
  if vFileName = '' then
    begin
    var vExt := ExtractFileExt(FAssignedCommandData.Command).ToLower;
    if (vExt = '.exe') or (vExt = '.dll') or (vExt = '.ico') then
      begin
      vFileName := FAssignedCommandData.Command;
      end;
    end;

  var vIconIndex: Integer := FAssignedCommandData.IconFileIndex;

  var pFileName: PChar := AllocMem(MAX_PATH);
  try
    StringToWideChar(PChar(vFileName), pFileName, Max_Path);
    if PickIconDlg(Handle, pFileName, MAX_PATH, vIconIndex) = 1 then
      begin
      FAssignedCommandData.IconType := citFromFileRes;
      FAssignedCommandData.IconFilename := WideCharToString(pFileName);
      FAssignedCommandData.IconFileIndex := vIconIndex;

      UpdateIcon;
      miChooseFromFileRes.Checked := True;
      end
  finally
    FreeMem(pFileName, MAX_PATH);
    end;
end;

procedure TfrmCommandConfig.miDefaultIconClick(Sender: TObject);
begin
  FAssignedCommandData.IconType := citDefault;
  //FAssignedCommandData.IconFilename := '';
  //FAssignedCommandData.IconFileIndex := -1;
  UpdateIcon;
  miDefaultIcon.Checked := True;
end;

procedure TfrmCommandConfig.SetCaption(const AValue: string);
begin
  if edtCaption.Text <> AValue then
    edtCaption.Text := AValue;
end;

procedure TfrmCommandConfig.SetEnabled(Value: boolean);
begin
  if Enabled = Value then
    Exit;

  inherited;

  M_SetChildsEnable(Self, Value);

end;

procedure TfrmCommandConfig.SetFocus;
begin
  inherited;
  edtCaption.SetFocus;
end;

procedure TfrmCommandConfig.TimerTimer(Sender: TObject);
const
  vArLangStr: array [boolean] of string = ('IsNotRunning', 'IsRunning');
var
  vErrPlace: word;
begin
  vErrPlace := 0;
  try
    if not Assigned(FAssignedTreeNode) or not Assigned(FAssignedTreeNode.Data)
    then
      Exit;

    vErrPlace := 100;
    var vData := FAssignedTreeNode.Data;
    vErrPlace := 105;
    //with TCommandData(FAssignedTreeNode.Data) do
    with TCommandData(vData) do
    begin
      vErrPlace := 110;
      lblIsRunning.Caption := GetLangString('frmConfig\frmCommandConfig',
        vArLangStr[isRunning]);
      // IfThen(isRunning, GetLangString('LangStrings', 'ElementIsRunning'], LangStrings['ElementIsNotRunning']);
    end;
  except
    on E: Exception do
    begin
      ShowMessage('Try..catch! TfrmCommandConfig.TimerTimer: ' + E.Message +
        #1310 + 'Errplace: ' + vErrPlace.ToString);
      ShowMessage(FAssignedTreeNode.Text);
    end;
  end;
end;

procedure TfrmCommandConfig.UpdateIcon;
begin
  var vNewHIcon := FAssignedCommandData.ExtractHIcon({edtCommand.Text}); //MyExtractHIcon(edtCommand.Text, FAssignedCommandData);
  var vImageIndex := ImageList_ReplaceIcon(TreeImageList.Handle,
      -1, vNewHIcon); //FAssignedTreeNode.ImageIndex
  if vNewHIcon > 0 then
    DestroyIcon(vNewHIcon);
  {else }if FAssignedTreeNode.ImageIndex > 0 then // if the icon was before but not now
    ListDeletedImageIndexes.Add(FAssignedTreeNode.ImageIndex);
  FAssignedTreeNode.ImageIndex := vImageIndex;
  FAssignedTreeNode.SelectedIndex := vImageIndex;
  FAssignedTreeNode.Owner.Owner.Repaint; //tvItems.Repaint
end;

function TfrmCommandConfig.CheckFileCommandExists: boolean;
begin
  Result := {(edtCommand.Text = '') or }(MyExtendFileNameToFull(edtCommand.Text) <> '');
  edtCommand.Font.Color := IfThen(Result, TColors.SysWindowText, TColors.Red);
end;

procedure TfrmCommandConfig.ClearAssigned;
begin
FAssigningState := True;
try
  FAssignedTreeNode := nil;
  FAssignedCaption := '';
  if Assigned(FAssignedCommandData) then
    FreeAndNil(FAssignedCommandData);
  //FAssignedCommandData := nil;

  edtCaption.Text := '';
  edtCommand.Text := '';  FOldCommandText := '';
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
  ClearAssigned;
end;

destructor TfrmCommandConfig.Destroy;
begin
  FAssignedTreeNode := nil; // иначе пытается сам удалить (а может и не надо)
  inherited Destroy;
end;

procedure TfrmCommandConfig.Assign(Source: TPersistent);
begin
  FAssigningState := True;
  try
    if Source <> nil then
    begin
      FAssignedTreeNode := Source as TTreeNode;

      if not Assigned(FAssignedTreeNode.Data) then
        raise Exception.Create('not Assigned(FAssignedTreeNode.Data)');

      Enabled := True;

      FAssignedCaption := FAssignedTreeNode.Text;
      edtCaption.Text := FAssignedCaption;
      //if Self.Parent.Parent.Visible then
       // edtCaption.SetFocus;

      //var CommandData := TCommandData(FAssignedTreeNode.Data);

      if FAssignedTreeNode.Data = nil then // в случае Отмены
        Exit;

      FAssignedCommandData := TCommandData.Create;
      TCommandData(FAssignedTreeNode.Data).Assign(FAssignedCommandData);

      var vIsCommand := not FAssignedCommandData.isGroup; //FAssignedTreeNode.HasChildren;

      with FAssignedCommandData do
      begin
        edtCommand.Text := Command;
        FOldCommandText := Command;
        edtCommandParameters.Text := CommandParameters;
        cbRunAsAdmin.Checked := IsRunAsAdmin;
        case IconType of
          citFromFileRes: miChooseFromFileRes.Checked := True;
          citFromFileExt: miChooseFromFileExt.Checked := True;
          else
            miDefaultIcon.Checked := True;
        end; //end;
        //cbIsVisible.Checked := isVisible;
      end;
      CheckFileCommandExists;
      for var i := 0 to ControlCount - 1 do
        with Controls[i] do
          if Tag <> 1 then
            Visible := vIsCommand;

      Timer.Enabled := True;
    end
    else // nil (initialization)
      raise Exception.Create('TfrmCommandConfig.Assign(nil)');
      //ClearAssigned;
  finally
    FAssigningState := False;
  end;
end;

function TfrmCommandConfig.SaveAssigned: Boolean;
//var
  //CommandData: TCommandData;
begin
  // nothing to save or already saved
  if (FAssignedTreeNode = nil) or (FAssignedCommandData = nil) then //or not IsModified then
    Exit(True);

  var vExceptionStr := '';

  var vCaption := Trim(edtCaption.Text);
  if (vCaption = '') then
      vExceptionStr := GetLangString('frmConfig\frmCommandConfig', 'ErrorEmptyName');

  //with TCommandData(FAssignedTreeNode.Data) do
  with FAssignedCommandData do
  begin
    {if isGroup then
      begin
      if (vExceptionStr <> '') then
        begin
        ErrorDialog((Self.Owner) as TForm, vExceptionStr);
        Exit(False);
        end;
      end
    else}
    if not isGroup then      
      begin
      //var vCommand := Command; //Trim(edtCommand.Text);
      //if (vCommand = '') then
      if (Command = '') then
        begin
        if vExceptionStr <> '' then
          vExceptionStr := vExceptionStr + #13#10#13#10;
        vExceptionStr := vExceptionStr + GetLangString('frmConfig\frmCommandConfig', 'ErrorCommand');
        end;
      end;
    if (vExceptionStr <> '') then
      begin
      ErrorDialog((Self.Owner) as TForm, vExceptionStr);
      Exit(False);
      end;

    FAssignedCommandData.Assign(TCommandData(FAssignedTreeNode.Data));
      {Command := vCommand;
      //Command := Trim(edtCommand.Text);
      CommandParameters := Trim(edtCommandParameters.Text);
      IsRunAsAdmin := cbRunAsAdmin.Checked;
      IconType := FAssignedCommandData.IconType;
      IconFilename := FAssignedCommandData.IconFilename;
      IconFileIndex := FAssignedCommandData.IconFileIndex;
      IconExt := FAssignedCommandData.IconExt;}
      //isVisible := cbIsVisible.Checked;
      //isGroup := FAssignedTreeNode.HasChildren;
      //end;
  end;
  FAssignedTreeNode.Text := vCaption; //Trim(edtCaption.Text);
  FAssignedCaption := vCaption; //FAssignedTreeNode.Text;
  //FreeAndNil(FAssignedCommandData);
  Result := True;
end;

end.
