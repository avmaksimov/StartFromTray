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
    cbRunAt: TCheckBox;
    cbIsRepeatRun: TCheckBox;
    edtCaption: TLabeledEdit;
    edtRepeatRunAtTime: TDateTimePicker;
    edtRunAtTime: TDateTimePicker;
    gbRunAtTime: TGroupBox;
    edtRunAtDate: TDateTimePicker;
    lblCommand: TLabel;
    btnEdit: TButton;
    btnRun: TButton;
    edtCommand: TButtonedEdit;
    edtCommandOpenDialog: TFileOpenDialog;
    lblIsRunning: TLabel;
    Timer: TTimer;
    lblRunInfo: TLabel;
    ImageList: TImageList;
    cbisRun_isWhenFolderChange: TCheckBox;
    edtisRun_WhenFolderChange: TButtonedEdit;
    lblisRun_FolderChanged: TLabel;
    lblNextRun: TLabel;
    edtCommandParameters: TLabeledEdit;
    procedure cbIsRepeatRunChange(Sender: TObject);
    procedure cbRunAtChange(Sender: TObject);
    procedure edtCaptionChange(Sender: TObject);
    { procedure edtCommandBeforeDialog(Sender: TObject; var AName: string;
      var AAction: Boolean); }
    procedure btnEditClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure edtCommandChange(Sender: TObject);
    procedure edtCommandRightButtonClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure cbisRun_isWhenFolderChangeClick(Sender: TObject);
    procedure edtisRun_WhenFolderChangeRightButtonClick(Sender: TObject);
  private
    { private declarations }
    FAssignedTreeNode: TTreeNode;
    FAssignedCaption: string; // чтобы понять, что название изменилось
    FAssigningState: boolean;

    FOldCommandText: string;

    FisCommand: boolean;
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
    procedure SaveAssigned;
    function CheckFileCommandExists: boolean;

    // procedure RefreshCaption;

    property AssignedTreeNode: TTreeNode read FAssignedTreeNode;
    property TreeImageList: TImageList read FTreeImageList write FTreeImageList;
  published
    property Caption: string write SetCaption;
    property IsModified: boolean read GetIsModified;
  end;

implementation

uses LangsU, System.StrUtils, CommonU, System.Masks, System.Math;

{$R *.dfm}
{ TfrmCommandConfig }

procedure TfrmCommandConfig.cbRunAtChange(Sender: TObject);
var
  vNow: TDateTime;
  vSysTime: TSystemTime;
begin
  edtRunAtDate.Enabled := cbRunAt.Checked;
  edtRunAtTime.Enabled := cbRunAt.Checked;
  cbIsRepeatRun.Enabled := cbRunAt.Checked;

  lblNextRun.Visible := cbRunAt.Checked;

  // if now checked and before didn't checked
  if cbRunAt.Checked then
  begin
    lblNextRun.Caption := '';
    if not TCommandData(FAssignedTreeNode.Data).isRunAt then
    begin
      vNow := Now;

      edtRunAtDate.Date := Trunc(vNow);

      DateTimeToSystemTime(vNow, vSysTime);
      edtRunAtTime.Time := EncodeTime(vSysTime.wHour, vSysTime.wMinute, 0, 0);
    end;
  end; {
    else
    begin
    edtRunAtDate.Date := NullDate;
    edtRunAtTime.Time := NullDate;
    end; }

  cbIsRepeatRunChange(cbIsRepeatRun);
end;

procedure TfrmCommandConfig.cbisRun_isWhenFolderChangeClick(Sender: TObject);
begin
  edtisRun_WhenFolderChange.Enabled := cbisRun_isWhenFolderChange.Checked;
  edtisRun_WhenFolderChange.RightButton.Enabled :=
    cbisRun_isWhenFolderChange.Checked;
end;

procedure TfrmCommandConfig.btnEditClick(Sender: TObject);
begin
  SaveAssigned;
  TCommandData(FAssignedTreeNode.Data).Edit;
end;

procedure TfrmCommandConfig.btnRunClick(Sender: TObject);
begin
  SaveAssigned;
  TCommandData(FAssignedTreeNode.Data).Run(crtNormalRun);
end;

procedure TfrmCommandConfig.cbIsRepeatRunChange(Sender: TObject);
begin
  edtRepeatRunAtTime.Enabled := cbRunAt.Checked and cbIsRepeatRun.Checked;

  if cbIsRepeatRun.Checked and not TCommandData(FAssignedTreeNode.Data).isRepeatRun
  then
  begin
    // скопируем из RunAtDateTime только, если ранее было выключено
    // if TCommandData(FAssignedTreeNode.Data).isRepeatRun then
    // if IsNullDate(edtRepeatRunAtTime.Time) then
    edtRepeatRunAtTime.Time := edtRunAtTime.Time;
  end
  { else
    edtRepeatRunAtTime.Time := NullDate; }
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
  vImageIndex: Integer;
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

  if FAssignedTreeNode.HasChildren then
    vImageIndex := 0
  else
    vImageIndex := ImageList_ReplaceIcon(TreeImageList.Handle,
      FAssignedTreeNode.ImageIndex, MyExtractIcon(edtCommand.Text));

  FAssignedTreeNode.ImageIndex := vImageIndex;
  FAssignedTreeNode.SelectedIndex := vImageIndex;

  FAssignedTreeNode.Owner.Owner.Repaint;

  CheckFileCommandExists;
end;

procedure TfrmCommandConfig.edtCommandRightButtonClick(Sender: TObject);
var
  i, j: Integer;
  vExtensions, sCommand: string;
  bMatchedMaskFound: boolean;
  vExtensionArray: TStringDynArray;
begin
  sCommand := Trim(edtCommand.Text);
  with edtCommandOpenDialog do
  begin
    FileTypes.Clear;

    with FileTypes.Add do
    begin
      DisplayName := GetLangString('LangStrings', 'FileDialogExecutableFile');
      FileMask := '*.exe';
    end;

    bMatchedMaskFound := MatchesMask(sCommand, '*.exe');

    if bMatchedMaskFound then
      FileTypeIndex := 1
    else
    begin
      // find FileType
      for i := 0 to Filters.Count - 1 do
      begin
        vExtensions := TFilterData(Filters.Objects[i]).Extensions;
        with FileTypes.Add do
        begin
          vExtensionArray := vExtensions.Split([';']);
          FileMask := '*.' + vExtensionArray[0].Trim;
          for j := 1 to High(vExtensionArray) do
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

procedure TfrmCommandConfig.edtisRun_WhenFolderChangeRightButtonClick
  (Sender: TObject);
var
  s: string;
begin
  s := edtisRun_WhenFolderChange.Text;
  if SelectDirectory('Select folder to watch', '', s,
    [sdNewFolder, sdShowShares], Self) then
    edtisRun_WhenFolderChange.Text := s;
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
        (cbIsVisible.Checked <> isVisible) or (cbRunAt.Checked <> isRunAt) or
        (cbRunAt.Checked and ((Trunc(edtRunAtDate.Date) <> Trunc(RunAtDateTime))
        or (CompareTime(edtRunAtTime.Time, RunAtDateTime) <> EqualsValue))) or
        (cbIsRepeatRun.Checked <> isRepeatRun) or
        (cbIsRepeatRun.Checked and (CompareTime(edtRepeatRunAtTime.Time,
        RepeatRunAtTime) <> EqualsValue)) or
        (cbisRun_isWhenFolderChange.Checked <> isRun_isWhenOnlyFolderChange) or
        (cbisRun_isWhenFolderChange.Checked and
        (edtisRun_WhenFolderChange.Text <> isRun_WhenOnlyFolderChange));
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

  if Value then
    edtRepeatRunAtTime.Enabled := cbRunAt.Checked and cbIsRepeatRun.Checked;
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
    with TCommandData(FAssignedTreeNode.Data) do
    begin
      vErrPlace := 110;
      lblIsRunning.Caption := GetLangString('frmConfig\frmCommandConfig',
        vArLangStr[isRunning]);
      // IfThen(isRunning, GetLangString('LangStrings', 'ElementIsRunning'], LangStrings['ElementIsNotRunning']);
      vErrPlace := 120;
      lblisRun_FolderChanged.Caption := 'Folder changed: ' +
        BoolToStr(isRun_FolderChanged, True);
      vErrPlace := 130;
      if isRunAt then
        lblNextRun.Caption := 'Next: ' + DateTimeToStr(NextRunAtDateTime)
      else
        lblNextRun.Caption := '';
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

      edtCaption.Text := FAssignedTreeNode.Text;
      CheckFileCommandExists;
      if Self.Parent.Parent.Visible then
        edtCaption.SetFocus;

      CommandData := TCommandData(FAssignedTreeNode.Data);

      if CommandData = nil then // в случае Отмены
        Exit;

      FisCommand := not FAssignedTreeNode.HasChildren;

      with CommandData do
      begin
        edtCommand.Text := Command;
        FOldCommandText := Command;
        edtCommandParameters.Text := CommandParameters;
        cbIsVisible.Checked := isVisible;

        if FisCommand then
        begin
          cbRunAt.Checked := isRunAt;

          if isRunAt then // иначе заполнится при cbRunAtChange
          begin
            edtRunAtDate.Date := Trunc(RunAtDateTime);
            edtRunAtTime.Time := Frac(RunAtDateTime);
          end;

          cbIsRepeatRun.Checked := isRepeatRun;

          if cbIsRepeatRun.Checked then
            edtRepeatRunAtTime.Time := RepeatRunAtTime;

          cbisRun_isWhenFolderChange.Checked := isRun_isWhenOnlyFolderChange;
          edtisRun_WhenFolderChange.Text := isRun_WhenOnlyFolderChange;
        end;
      end;

      cbRunAtChange(cbRunAt);

      for i := 0 to ControlCount - 1 do
        with Controls[i] do
          if Tag <> 1 then
            Visible := FisCommand;

      Timer.Enabled := True;
    end
    else // nil (initialization)
    begin
      FAssignedTreeNode := nil;
      edtCaption.Text := '';
      cbIsVisible.Checked := False;
      lblIsRunning.Caption := '';
      edtCommand.Text := '';
      edtCommandParameters.Text := '';
    end;
  finally
    FAssigningState := False;
  end;
end;

procedure TfrmCommandConfig.SaveAssigned;
var
  CommandData: TCommandData;
begin
  if (FAssignedTreeNode = nil) or not IsModified then
    Exit;

  FAssignedTreeNode.Text := Trim(edtCaption.Text);
  FAssignedCaption := FAssignedTreeNode.Text;

  CommandData := TCommandData(FAssignedTreeNode.Data);

  with CommandData do
  begin
    Command := Trim(edtCommand.Text);
    CommandParameters := Trim(edtCommandParameters.Text);
    isVisible := cbIsVisible.Checked;

    isGroup := FAssignedTreeNode.HasChildren;

    { if FisCommand then
      begin
      isRunAt := cbRunAt.Checked;

      if isRunAt then
      begin
      //RunAtDateTime := ComposeDateTime(edtRunAtDate.Date, edtRunAtTime.Time);
      RunAtDateTime := Trunc(edtRunAtDate.Date) + Frac(edtRunAtTime.Time);

      isRepeatRun := cbIsRepeatRun.Checked;
      if isRepeatRun then
      RepeatRunAtTime := edtRepeatRunAtTime.Time;

      CalcNextRunAtDateTime;

      if not isRunAt then //user fail with past time
      begin
      cbRunAt.Checked := False;
      cbRunAtChange(cbRunAt);
      end;
      end; //isRunAt
      if cbisRun_isWhenFolderChange.Checked then
      isRun_WhenOnlyFolderChange := edtisRun_WhenFolderChange.Text;

      // it must be after setting isRun_WhenOnlyFolderChange (Folder to watch)
      isRun_isWhenOnlyFolderChange := cbisRun_isWhenFolderChange.Checked;
      end; //FisCommand }
  end;
end;

{ procedure TfrmCommandConfig .RefreshCaption ;
  begin
  edtCaption.Text := FAssignedTreeNode.Text;
  end; }

end.
