unit frmCommandConfig_U;

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  CommandsClass_U, ComCtrls, Mask, Windows, DateUtils, Types,
  FilterClass_U, Dialogs, Vcl.ImgList, Vcl.FileCtrl, System.UITypes,
  Winapi.ShellAPI, Winapi.CommCtrl, System.ImageList;

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
    imgIcon: TImage;
    btnDefaultIcon: TButton;
    procedure edtCaptionChange(Sender: TObject);
    { procedure edtCommandBeforeDialog(Sender: TObject; var AName: string;
      var AAction: Boolean); }
    procedure btnEditClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure edtCommandChange(Sender: TObject);
    procedure edtCommandRightButtonClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure btnChangeIconClick(Sender: TObject);
    procedure btnDefaultIconClick(Sender: TObject);
  private
    { private declarations }
    FAssignedTreeNode: TTreeNode;
    FAssignedCaption: string; // чтобы понять, что название изменилось
    FAssignedIconFilename: string;
    FAssignedIconFileIndex: Integer;

    FAssigningState: boolean;

    FOldCommandText: string;

    //FisCommand: boolean;
    FTreeImageList: TImageList; // true - command, false - group
    function GetIsModified: boolean;
    procedure SetCaption(const AValue: string);
    // FIsModified: boolean;
  protected
    procedure SetEnabled(Value: boolean); override;
  public
    { public declarations }
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // procedure Assign (Source: TTreeNode);
    procedure Assign(Source: TPersistent); override;
    procedure SetFocus; override;

    function SaveAssigned: Boolean;
    function CheckFileCommandExists: boolean;

    // procedure RefreshCaption;

    property AssignedTreeNode: TTreeNode read FAssignedTreeNode;
    property TreeImageList: TImageList read FTreeImageList write FTreeImageList;
  published
    property Caption: string write SetCaption;
    property IsModified: boolean read GetIsModified;
  end;

implementation

uses LangsU, frmConfig_U, System.StrUtils, CommonU, System.Masks, System.Math,
  Winapi.ShlObj;

{$R *.dfm}
{ TfrmCommandConfig }

procedure TfrmCommandConfig.btnChangeIconClick(Sender: TObject);
begin
  if not Assigned(FAssignedTreeNode) or not Assigned(FAssignedTreeNode.Data) then
    Exit;

  var vCommandData := TCommandData(FAssignedTreeNode.Data);

  //var FileName: string := '';//'C:\Windows\System32\Shell32.dll';
  var vFileName: string := vCommandData.IconFilename;
  if vFileName = '' then
    begin
    var vExt := ExtractFileExt(vCommandData.Command).ToLower;
    if (vExt = '.exe') or (vExt = '.dll') or (vExt = '.ico') then
      begin
      vFileName := vCommandData.Command;
      end;
    end;

  var vIconIndex: Integer := vCommandData.IconFileIndex;

  var pFileName: PChar := AllocMem(MAX_PATH);
  try
    StringToWideChar(PChar(vFileName), pFileName, Max_Path);
    if PickIconDlg(Handle, pFileName, MAX_PATH, vIconIndex) = 1 then
      begin
      FAssignedIconFilename := WideCharToString(pFileName);
      FAssignedIconFileIndex := vIconIndex;
      //vCommandData.IconFilename := WideCharToString(pFileName);
      //vCommandData.IconFileIndex := vIconIndex;
      edtCommandChange(nil);
      end;
  finally
    FreeMem(pFileName, MAX_PATH);
    end;
end;

procedure TfrmCommandConfig.btnDefaultIconClick(Sender: TObject);
begin
  FAssignedIconFilename := '';
  FAssignedIconFileIndex := -1;
  edtCommandChange(nil);
end;

procedure TfrmCommandConfig.btnEditClick(Sender: TObject);
begin
  if SaveAssigned then
    TCommandData(FAssignedTreeNode.Data).Edit;
end;

procedure TfrmCommandConfig.btnRunClick(Sender: TObject);
begin
  if SaveAssigned then
    TCommandData(FAssignedTreeNode.Data).Run(crtNormalRun);
end;

procedure TfrmCommandConfig.edtCaptionChange(Sender: TObject);
begin
  if FAssigningState then
    Exit;

  FAssignedTreeNode.Text := edtCaption.Text;
end;

procedure TfrmCommandConfig.edtCommandChange(Sender: TObject);
var
  s: string;
  i: Integer;
  //vImageIndex: Integer;
begin
  if FAssigningState then
    Exit;

  if edtCaption.Text = FOldCommandText then
  begin
    s := ExtractFileName(edtCommand.Text);
    i := Pos('.', s) - 1;
    if i = -1 then
      i := Length(s);
    edtCaption.Text := Copy(s, 1, i);
  end;
  FOldCommandText := edtCommand.Text;

  //if FAssignedTreeNode.HasChildren then
  //  vImageIndex := 0
  //else
  var vNewHIcon := MyExtractHIcon(edtCommand.Text, FAssignedIconFilename, FAssignedIconFileIndex);
  var vImageIndex := ImageList_ReplaceIcon(TreeImageList.Handle,
      FAssignedTreeNode.ImageIndex, vNewHIcon);
  if vNewHIcon > 0 then
    DestroyIcon(vNewHIcon)
  else if FAssignedTreeNode.ImageIndex > 0 then // if the icon was before but not now
    frmConfig.ListDeletedImageIndexes.Add(FAssignedTreeNode.ImageIndex);
    //frmConfig.TreeImageListRemoveIndexProperly(FAssignedTreeNode.ImageIndex);
  FAssignedTreeNode.ImageIndex := vImageIndex;
  FAssignedTreeNode.SelectedIndex := vImageIndex;

  TreeImageList.GetIcon(FAssignedTreeNode.ImageIndex, imgIcon.Picture.Icon);

  FAssignedTreeNode.Owner.Owner.Repaint; //tvItems.Repaint

  CheckFileCommandExists;
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
var
  CommandData: TCommandData;
begin
  if not Enabled then
    Exit(False); // если заблокировано, то нет смысла

  Result := edtCaption.Text <> FAssignedCaption;
  // Result := False; // по умолчанию, для групп
  if not Result and Assigned(FAssignedTreeNode) { and FisCommand } then
  begin
    CommandData := TCommandData(FAssignedTreeNode.Data);

    if CommandData = nil then
      Exit;

    with CommandData do
      Result := Result or (edtCommand.Text <> Command) or
        (edtCommandParameters.Text <> CommandParameters) or
        (FAssignedIconFilename <> IconFilename) or (FAssignedIconFileIndex <> IconFileIndex);
  end;
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

function TfrmCommandConfig.CheckFileCommandExists: boolean;
begin
  Result := MyExtendFileNameToFull(FOldCommandText) <> '';
  edtCommand.Font.Color := IfThen(Result, TColors.SysWindowText, TColors.Red);
end;

constructor TfrmCommandConfig.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FAssignedTreeNode := nil;
  FOldCommandText := '';
  FAssigningState := False;
end;

destructor TfrmCommandConfig.Destroy;
begin
  FAssignedTreeNode := nil; // иначе пытается сам удалить (а может и не надо)
  inherited Destroy;
end;

procedure TfrmCommandConfig.Assign(Source: TPersistent);
var
  CommandData: TCommandData;
  vNewTreeNodeToAssign: TTreeNode;
  i: Integer;
begin
  FAssigningState := True;
  try
    if Source <> nil then
    begin
      vNewTreeNodeToAssign := (Source as TTreeNode);

      Enabled := True;

      FAssignedTreeNode := vNewTreeNodeToAssign;
      FAssignedCaption := FAssignedTreeNode.Text;
      TreeImageList.GetIcon(FAssignedTreeNode.ImageIndex, imgIcon.Picture.Icon);
      //imgIcon.Picture.

      edtCaption.Text := FAssignedTreeNode.Text;
      CheckFileCommandExists;
      //if Self.Parent.Parent.Visible then
       // edtCaption.SetFocus;

      CommandData := TCommandData(FAssignedTreeNode.Data);

      if CommandData = nil then // в случае Отмены
        Exit;

      var vIsCommand := not CommandData.isGroup; //FAssignedTreeNode.HasChildren;

      with CommandData do
      begin
        FAssignedIconFilename := IconFilename;
        FAssignedIconFileIndex := IconFileIndex;
        edtCommand.Text := Command;
        FOldCommandText := Command;
        edtCommandParameters.Text := CommandParameters;
        //cbIsVisible.Checked := isVisible;
      end;

      for i := 0 to ControlCount - 1 do
        with Controls[i] do
          if Tag <> 1 then
            Visible := vIsCommand;

      Timer.Enabled := True;
    end
    else // nil (initialization)
    begin
      FAssignedTreeNode := nil;
      edtCaption.Text := '';
      imgIcon.Picture := nil; imgIcon.Invalidate;
      FAssignedIconFilename := '';
      FAssignedIconFileIndex := -1;

      //cbIsVisible.Checked := False;
      lblIsRunning.Caption := '';
      edtCommand.Text := '';
      edtCommandParameters.Text := '';
    end;
  finally
    FAssigningState := False;
  end;
end;

function TfrmCommandConfig.SaveAssigned: Boolean;
//var
  //CommandData: TCommandData;
begin
  if (FAssignedTreeNode = nil) then //or not IsModified then
    Exit(True);

  var vExceptionStr := '';

  var vCaption := Trim(edtCaption.Text);
  if (vCaption = '') then
      vExceptionStr := GetLangString('frmConfig\frmCommandConfig', 'ErrorEmptyName');

  with TCommandData(FAssignedTreeNode.Data) do
  begin
    if isGroup then
      begin
      if (vExceptionStr <> '') then
        begin
        ErrorDialog((Self.Owner) as TForm, vExceptionStr);
        Exit(False);
        end;
      end
    else
      begin
      var vCommand := Trim(edtCommand.Text);
      if (vCommand = '') then
        begin
        if vExceptionStr <> '' then
          vExceptionStr := vExceptionStr + #13#10#13#10;
        vExceptionStr := vExceptionStr + GetLangString('frmConfig\frmCommandConfig', 'ErrorCommand');
        end;

      if (vExceptionStr <> '') then
        begin
        ErrorDialog((Self.Owner) as TForm, vExceptionStr);
        Exit(False);
        end;

      Command := vCommand;
      //Command := Trim(edtCommand.Text);
      CommandParameters := Trim(edtCommandParameters.Text);
      IconFilename := FAssignedIconFilename;
      IconFileIndex := FAssignedIconFileIndex;
      //isVisible := cbIsVisible.Checked;
      //isGroup := FAssignedTreeNode.HasChildren;
      end;
  end;
  FAssignedTreeNode.Text := vCaption; //Trim(edtCaption.Text);
  FAssignedCaption := vCaption; //FAssignedTreeNode.Text;
  Result := True;
end;

end.
