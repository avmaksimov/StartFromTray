unit frmChooseMMC_U;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ImgList, ComCtrls, IniFiles;

type
  TMmcSnapInInfo = class
  public
    DisplayName: string;
    Description: string;
    FileName: string;
    IconFileName: string;
    IconIndex: Integer;
    RemoteParameters: string;
  end;

  { TfrmChooseMMC }

  TfrmChooseMMC = class(TForm)
    gbExtensions: TGroupBox;
    edtSearch: TLabeledEdit;
    ImageList: TImageList;
    lvSnapIns: TListView;
    lblSnapIns: TLabel;
    lblDescription: TLabel;
    mmoDescription: TMemo;
    gbTarget: TGroupBox;
    rbLocal: TRadioButton;
    rbRemote: TRadioButton;
    cbComputerName: TComboBox;
    gbButtons: TGroupBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate({%H-}Sender: TObject);
    procedure FormDestroy({%H-}Sender: TObject);
    procedure FormHide({%H-}Sender: TObject);
    procedure FormResize({%H-}Sender: TObject);
    procedure FormShow({%H-}Sender: TObject);
    procedure edtSearchChange({%H-}Sender: TObject);
    procedure btnOKClick({%H-}Sender: TObject);
    procedure lvSnapInsDblClick({%H-}Sender: TObject);
    procedure lvSnapInsMouseUp({%H-}Sender: TObject; Button: TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure lvSnapInsSelectItem({%H-}Sender: TObject;
      {%H-}Item: TListItem; {%H-}Selected: Boolean);
    procedure TargetClick({%H-}Sender: TObject);
    procedure cbComputerNameChange({%H-}Sender: TObject);
  private
    FRemoteCaptionTemplate: string;
    FUpdatingTarget: Boolean;
    FInitialSnapInDisplayName: string;
    procedure CenterOnMainForm;
    procedure ClearSnapIns;
    procedure FillSnapIns;
    function GetMaxRecentComputerCount: Integer;
    function GetSelectedRemoteParameters: string;
    function GetSuggestedCaption: string;
    procedure LoadRecentComputers;
    procedure RestoreFormProperties;
    procedure SaveFormProperties;
    procedure SaveRecentComputer(const AComputerName: string);
    procedure SelectSnapIn(const AFileName: string);
    procedure UpdateColumnWidths;
    procedure UpdateDescription;
    procedure UpdateOKButton;
    procedure UpdateTargetControls;
  public
    { Reference to StartFromTray.ini. It is owned by the application. }
    MainIniFile: TCustomIniFile;

    { Input: a file name or any full path to an .msc file.
      Output after mrOK: always the file name without a path. }
    SnapInFileName: string;

    { Input: the current command parameters. Output after mrOK: empty for
      the local computer or parameters generated from mmc-remote.ini. }
    SnapInParameters: string;

    { Additional output values. DisplayName is suitable for an automatically
      generated item caption. IconFileName and IconIndex can be stored as
      citFromFileRes when a persistent icon resource is available. }
    SnapInDisplayName: string;
    IconFileName: string;
    IconIndex: Integer;
    OriginalAutomaticCaption: string;
    property InitialSnapInDisplayName: string
	read FInitialSnapInDisplayName;
    procedure Initialize(const AMainIniFile: TCustomIniFile);
  end;

var
  frmChooseMMC: TfrmChooseMMC;

implementation

uses
  Windows, LazUTF8, CommonU, LangsU, MmcUtils_U;

{$R *.lfm}

const
  C_REMOTE_INI_FILE_NAME = 'mmc-remote.ini';
  C_REMOTE_INI_SECTION = 'Remote';
  C_COMPUTER_NAME_TOKEN = '{computername}';
  C_SETTINGS_INI_SECTION = 'MMC';
  C_SETTINGS_MAX_RECENT = 'MaxRecentComputers';
  C_SETTINGS_RECENT = 'RecentComputers';
  C_DEFAULT_MAX_RECENT = 10;
  C_HIGHEST_MAX_RECENT = 100;
  C_INI_FORM_SECTION = 'FormChooseMMC';
  C_INI_FORM_WIDTH = 'Width';
  C_INI_FORM_HEIGHT = 'Height';
  C_MIN_FORM_WIDTH = 500;
  C_MIN_FORM_HEIGHT = 503;
  C_FILE_NAME_COLUMN_WIDTH = 135;

function ContainsTextUTF8(const AText, ASearchText: string): Boolean;
begin
  Result := UTF8Pos(UTF8LowerCase(ASearchText),
    UTF8LowerCase(AText)) > 0;
end;

function NormalizeSnapInFileName(const AFileName: string): string;
var
  Value: string;
begin
  Value := Trim(AFileName);
  if (Length(Value) >= 2) and
    (Value[1] = '"') and (Value[Length(Value)] = '"') then
    Value := Copy(Value, 2, Length(Value) - 2);
  Result := ExtractFileName(Value);
end;

function GetMmcRemoteIniFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(
    ExtractFilePath(Application.ExeName)) + C_REMOTE_INI_FILE_NAME;
end;

function HasComputerNameToken(const AParametersTemplate: string): Boolean;
begin
  Result := Pos(C_COMPUTER_NAME_TOKEN,
    LowerCase(AParametersTemplate)) > 0;
end;

function BuildRemoteParameters(const AParametersTemplate,
  AComputerName: string): string;
begin
  Result := StringReplace(AParametersTemplate, C_COMPUTER_NAME_TOKEN,
    Trim(AComputerName), [rfReplaceAll, rfIgnoreCase]);
end;

function TryExtractComputerName(const AParametersTemplate,
  AParameters: string; out AComputerName: string): Boolean;
var
  ParametersTemplate, Parameters, Prefix, Suffix: string;
  TokenPosition, ComputerNameLength: Integer;
begin
  Result := False;
  AComputerName := '';
  ParametersTemplate := Trim(AParametersTemplate);
  Parameters := Trim(AParameters);
  TokenPosition := Pos(C_COMPUTER_NAME_TOKEN,
    LowerCase(ParametersTemplate));
  if (TokenPosition <= 0) or (Parameters = '') then
    Exit;

  Prefix := Copy(ParametersTemplate, 1, TokenPosition - 1);
  Suffix := Copy(ParametersTemplate,
    TokenPosition + Length(C_COMPUTER_NAME_TOKEN), MaxInt);
  ComputerNameLength := Length(Parameters) - Length(Prefix) - Length(Suffix);
  if ComputerNameLength <= 0 then
    Exit;

  if not SameText(Copy(Parameters, 1, Length(Prefix)), Prefix) then
    Exit;
  if (Suffix <> '') and not SameText(
    Copy(Parameters, Length(Parameters) - Length(Suffix) + 1, MaxInt),
    Suffix) then
    Exit;

  AComputerName := Trim(Copy(Parameters, Length(Prefix) + 1,
    ComputerNameLength));
  Result := AComputerName <> '';
end;

{ TfrmChooseMMC }

procedure TfrmChooseMMC.CenterOnMainForm;
var
  WorkArea: TRect;
  WorkWidth, WorkHeight: Integer;
begin
  if Assigned(Application.MainForm) then
  begin
    WorkArea := Application.MainForm.Monitor.WorkareaRect;
    Left := Application.MainForm.Left +
      (Application.MainForm.Width - Width) div 2;
    Top := Application.MainForm.Top +
      (Application.MainForm.Height - Height) div 2;
  end
  else
  begin
    WorkArea := Screen.PrimaryMonitor.WorkareaRect;
    WorkWidth := WorkArea.Right - WorkArea.Left;
    WorkHeight := WorkArea.Bottom - WorkArea.Top;
    Left := WorkArea.Left + (WorkWidth - Width) div 2;
    Top := WorkArea.Top + (WorkHeight - Height) div 2;
  end;

  if Left < WorkArea.Left then
    Left := WorkArea.Left
  else if Left + Width > WorkArea.Right then
    Left := WorkArea.Right - Width;

  if Top < WorkArea.Top then
    Top := WorkArea.Top
  else if Top + Height > WorkArea.Bottom then
    Top := WorkArea.Bottom - Height;
end;

procedure TfrmChooseMMC.ClearSnapIns;
var
  I: Integer;
begin
  for I := 0 to lvSnapIns.Items.Count - 1 do
    TMmcSnapInInfo(lvSnapIns.Items[I].Data).Free;
  lvSnapIns.Items.Clear;
  ImageList.Clear;
  mmoDescription.Clear;
end;

procedure TfrmChooseMMC.FillSnapIns;
var
  SystemDirectory, BaseFileName, LocalizedFileName: string;
  DisplayName, SnapInID, SnapInIconFileName: string;
  BaseDisplayName, BaseSnapInID, BaseIconFileName: string;
  RegisteredName, Description, AboutClassID, RegisteredIconFileName: string;
  AboutDescription: string;
  SnapInIconIndex, BaseIconIndex, RegisteredIconIndex: Integer;
  SearchRec: TSearchRec;
  Info: TMmcSnapInInfo;
  Item: TListItem;
  AboutIcon: HICON;
  RemoteIniFile: TIniFile;
begin
  ClearSnapIns;

  SystemDirectory := GetNativeSystemDirectoryForAccess;
  if SystemDirectory = '' then
    Exit;

  RemoteIniFile := nil;
  try
    if FileExists(GetMmcRemoteIniFileName) then
      RemoteIniFile := TIniFile.Create(GetMmcRemoteIniFileName);

    FRemoteCaptionTemplate := '{snapin} {computername}';
    if Assigned(RemoteIniFile) then
      FRemoteCaptionTemplate := Trim(RemoteIniFile.ReadString(
        'Caption', 'Remote', FRemoteCaptionTemplate));

    if (Pos('{snapin}', LowerCase(FRemoteCaptionTemplate)) = 0) or
       (Pos('{computername}', LowerCase(FRemoteCaptionTemplate)) = 0) then
      FRemoteCaptionTemplate := '{snapin} {computername}';
    lvSnapIns.Items.BeginUpdate;
    try
      if FindFirst(SystemDirectory + '*.msc', faAnyFile, SearchRec) = 0 then
        try
          repeat
            if (SearchRec.Attr and faDirectory) <> 0 then
              Continue;

            BaseFileName := SystemDirectory + SearchRec.Name;
            LocalizedFileName := GetLocalizedMscPath(BaseFileName);
            ReadConsoleMetadata(LocalizedFileName, DisplayName, SnapInID,
              SnapInIconFileName, SnapInIconIndex);

            if not SameText(LocalizedFileName, BaseFileName) and
              ((SnapInID = '') or (SnapInIconFileName = '') or
               (DisplayName = '')) then
            begin
              ReadConsoleMetadata(BaseFileName, BaseDisplayName,
                BaseSnapInID, BaseIconFileName, BaseIconIndex);
              if DisplayName = '' then
                DisplayName := BaseDisplayName;
              if SnapInID = '' then
                SnapInID := BaseSnapInID;
              if SnapInIconFileName = '' then
              begin
                SnapInIconFileName := BaseIconFileName;
                SnapInIconIndex := BaseIconIndex;
              end;
            end;

            RegisteredName := '';
            Description := '';
            AboutClassID := '';
            RegisteredIconFileName := '';
            RegisteredIconIndex := -1;
            AboutDescription := '';
            AboutIcon := 0;

            if ReadSnapInRegistration(SnapInID, RegisteredName,
              Description, AboutClassID, RegisteredIconFileName,
              RegisteredIconIndex) then
            begin
              ReadSnapInAbout(AboutClassID, AboutDescription, AboutIcon);
              { Keep a meaningful console title, but replace a missing or
                technical title such as "lusrmgr" with the snap-in name. }
              if (RegisteredName <> '') and
                ((DisplayName = '') or SameText(DisplayName,
                  ChangeFileExt(SearchRec.Name, ''))) then
                DisplayName := RegisteredName;
              if AboutDescription <> '' then
                Description := AboutDescription;
              if RegisteredIconFileName <> '' then
              begin
                SnapInIconFileName := RegisteredIconFileName;
                SnapInIconIndex := RegisteredIconIndex;
              end;
            end;

            if DisplayName = '' then
              DisplayName := ChangeFileExt(SearchRec.Name, '');

            Info := TMmcSnapInInfo.Create;
            Info.DisplayName := DisplayName;
            Info.Description := Description;
            Info.FileName := SearchRec.Name;
            Info.IconFileName := SnapInIconFileName;
            Info.IconIndex := SnapInIconIndex;
            Info.RemoteParameters := '';
            if Assigned(RemoteIniFile) then
              Info.RemoteParameters := Trim(RemoteIniFile.ReadString(
                C_REMOTE_INI_SECTION, SearchRec.Name, ''));
            if not HasComputerNameToken(Info.RemoteParameters) then
              Info.RemoteParameters := '';

            Item := lvSnapIns.Items.Add;
            Item.Caption := Info.DisplayName;
            Item.SubItems.Add(Info.FileName);
            Item.Data := Info;
            Item.ImageIndex := AddSmallIcon(ImageList, BaseFileName,
              Info.IconFileName, Info.IconIndex, AboutIcon);
          until FindNext(SearchRec) <> 0;
        finally
          SysUtils.FindClose(SearchRec);
        end;
    finally
      lvSnapIns.Items.EndUpdate;
    end;
  finally
    RemoteIniFile.Free;
  end;

  lvSnapIns.AlphaSort;
end;

function TfrmChooseMMC.GetMaxRecentComputerCount: Integer;
begin
  Result := C_DEFAULT_MAX_RECENT;
  if Assigned(MainIniFile) then
    Result := MainIniFile.ReadInteger(C_SETTINGS_INI_SECTION,
      C_SETTINGS_MAX_RECENT, C_DEFAULT_MAX_RECENT);

  if Result < 0 then
    Result := C_DEFAULT_MAX_RECENT
  else if Result > C_HIGHEST_MAX_RECENT then
    Result := C_HIGHEST_MAX_RECENT;
end;

function TfrmChooseMMC.GetSelectedRemoteParameters: string;
var
  Info: TMmcSnapInInfo;
begin
  Result := '';
  if not Assigned(lvSnapIns.Selected) or
    not Assigned(lvSnapIns.Selected.Data) then
    Exit;

  Info := TMmcSnapInInfo(lvSnapIns.Selected.Data);
  Result := Info.RemoteParameters;
end;

function TfrmChooseMMC.GetSuggestedCaption: string;
var
  Info: TMmcSnapInInfo;
begin
  Result := '';
  if not Assigned(lvSnapIns.Selected) or
     not Assigned(lvSnapIns.Selected.Data) then Exit;

  Info := TMmcSnapInInfo(lvSnapIns.Selected.Data);
  Result := Info.DisplayName;
  if not rbRemote.Checked or (Trim(cbComputerName.Text) = '') then Exit;

  Result := StringReplace(FRemoteCaptionTemplate, '{snapin}',
    Info.DisplayName, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{computername}',
    Trim(cbComputerName.Text), [rfReplaceAll, rfIgnoreCase]);
  Result := Trim(Result);
end;

procedure TfrmChooseMMC.LoadRecentComputers;
var
  RecentComputers: TStringList;
  ComputerName: string;
  I, J, MaxRecent: Integer;
  AlreadyAdded: Boolean;
begin
  cbComputerName.Items.BeginUpdate;
  try
    cbComputerName.Items.Clear;
    if not Assigned(MainIniFile) then
      Exit;

    MaxRecent := GetMaxRecentComputerCount;
    if MaxRecent <= 0 then
      Exit;

    RecentComputers := TStringList.Create;
    try
      RecentComputers.StrictDelimiter := True;
      RecentComputers.Delimiter := ';';
      RecentComputers.DelimitedText := MainIniFile.ReadString(
        C_SETTINGS_INI_SECTION, C_SETTINGS_RECENT, '');

      for I := 0 to RecentComputers.Count - 1 do
      begin
        ComputerName := Trim(RecentComputers[I]);
        if ComputerName = '' then
          Continue;

        AlreadyAdded := False;
        for J := 0 to cbComputerName.Items.Count - 1 do
          if SameText(cbComputerName.Items[J], ComputerName) then
          begin
            AlreadyAdded := True;
            Break;
          end;
        if AlreadyAdded then
          Continue;

        cbComputerName.Items.Add(ComputerName);
        if cbComputerName.Items.Count >= MaxRecent then
          Break;
      end;
    finally
      RecentComputers.Free;
    end;
  finally
    cbComputerName.Items.EndUpdate;
  end;
end;

procedure TfrmChooseMMC.RestoreFormProperties;
var
  SavedWidth, SavedHeight: Integer;
  WorkArea: TRect;
begin
  if not Assigned(MainIniFile) then
    Exit;

  SavedWidth := MainIniFile.ReadInteger(C_INI_FORM_SECTION,
    C_INI_FORM_WIDTH, Width);
  SavedHeight := MainIniFile.ReadInteger(C_INI_FORM_SECTION,
    C_INI_FORM_HEIGHT, Height);

  if SavedWidth < C_MIN_FORM_WIDTH then
    SavedWidth := C_MIN_FORM_WIDTH;
  if SavedHeight < C_MIN_FORM_HEIGHT then
    SavedHeight := C_MIN_FORM_HEIGHT;

  if Assigned(Application.MainForm) then
    WorkArea := Application.MainForm.Monitor.WorkareaRect
  else
    WorkArea := Screen.PrimaryMonitor.WorkareaRect;

  if SavedWidth > WorkArea.Right - WorkArea.Left then
    SavedWidth := WorkArea.Right - WorkArea.Left;
  if SavedHeight > WorkArea.Bottom - WorkArea.Top then
    SavedHeight := WorkArea.Bottom - WorkArea.Top;

  Width := SavedWidth;
  Height := SavedHeight;
end;

procedure TfrmChooseMMC.SaveFormProperties;
begin
  if not Assigned(MainIniFile) then
    Exit;

  MainIniFile.WriteInteger(C_INI_FORM_SECTION, C_INI_FORM_WIDTH, Width);
  MainIniFile.WriteInteger(C_INI_FORM_SECTION, C_INI_FORM_HEIGHT, Height);
end;

procedure TfrmChooseMMC.SaveRecentComputer(const AComputerName: string);
var
  RecentComputers: TStringList;
  ComputerName: string;
  I, MaxRecent: Integer;
begin
  if not Assigned(MainIniFile) then
    Exit;

  if not MainIniFile.ValueExists(C_SETTINGS_INI_SECTION,
    C_SETTINGS_MAX_RECENT) then
    MainIniFile.WriteInteger(C_SETTINGS_INI_SECTION,
      C_SETTINGS_MAX_RECENT, C_DEFAULT_MAX_RECENT);

  MaxRecent := GetMaxRecentComputerCount;
  if MaxRecent <= 0 then
  begin
    MainIniFile.DeleteKey(C_SETTINGS_INI_SECTION, C_SETTINGS_RECENT);
    Exit;
  end;

  ComputerName := Trim(AComputerName);
  if ComputerName = '' then
    Exit;

  RecentComputers := TStringList.Create;
  try
    RecentComputers.CaseSensitive := False;
    RecentComputers.StrictDelimiter := True;
    RecentComputers.Delimiter := ';';
    RecentComputers.Add(ComputerName);
    for I := 0 to cbComputerName.Items.Count - 1 do
      if RecentComputers.IndexOf(cbComputerName.Items[I]) < 0 then
        RecentComputers.Add(cbComputerName.Items[I]);
    while RecentComputers.Count > MaxRecent do
      RecentComputers.Delete(RecentComputers.Count - 1);

    cbComputerName.Items.Assign(RecentComputers);
    MainIniFile.WriteString(C_SETTINGS_INI_SECTION, C_SETTINGS_RECENT,
      RecentComputers.DelimitedText);
  finally
    RecentComputers.Free;
  end;
end;

procedure TfrmChooseMMC.SelectSnapIn(const AFileName: string);
var
  FileToSelect: string;
  Info: TMmcSnapInInfo;
  I: Integer;
begin
  FileToSelect := NormalizeSnapInFileName(AFileName);
  if FileToSelect = '' then
    Exit;

  for I := 0 to lvSnapIns.Items.Count - 1 do
  begin
    Info := TMmcSnapInInfo(lvSnapIns.Items[I].Data);
    if Assigned(Info) and SameText(Info.FileName, FileToSelect) then
    begin
      lvSnapIns.Selected := lvSnapIns.Items[I];
      lvSnapIns.Items[I].MakeVisible(False);
      Exit;
    end;
  end;
end;

procedure TfrmChooseMMC.UpdateColumnWidths;
var
  FirstColumnWidth: Integer;
begin
  if not Assigned(lvSnapIns) or (lvSnapIns.Columns.Count < 2) then
    Exit;

  { Keep the file-name column fixed. The first column uses the remaining
    client width, with room reserved for the vertical scrollbar. }
  lvSnapIns.Columns[1].Width := C_FILE_NAME_COLUMN_WIDTH;
  FirstColumnWidth := lvSnapIns.ClientWidth -
    C_FILE_NAME_COLUMN_WIDTH - GetSystemMetrics(SM_CXVSCROLL) - 8;
  if FirstColumnWidth < 120 then
    FirstColumnWidth := 120;
  lvSnapIns.Columns[0].Width := FirstColumnWidth;
end;

procedure TfrmChooseMMC.UpdateDescription;
var
  Info: TMmcSnapInInfo;
begin
  mmoDescription.Clear;
  if not Assigned(lvSnapIns.Selected) or
    not Assigned(lvSnapIns.Selected.Data) then
    Exit;

  Info := TMmcSnapInInfo(lvSnapIns.Selected.Data);
  mmoDescription.Text := Info.Description;
  mmoDescription.SelStart := 0;
end;

procedure TfrmChooseMMC.UpdateOKButton;
begin
  btnOK.Enabled := Assigned(lvSnapIns.Selected) and
    (not rbRemote.Checked or
     (rbRemote.Enabled and (Trim(cbComputerName.Text) <> '')));
end;

procedure TfrmChooseMMC.UpdateTargetControls;
var
  SupportsRemote: Boolean;
begin
  SupportsRemote := HasComputerNameToken(GetSelectedRemoteParameters);

  FUpdatingTarget := True;
  try
    rbRemote.Enabled := SupportsRemote;
    if not SupportsRemote then
      rbLocal.Checked := True;
    cbComputerName.Enabled := SupportsRemote and rbRemote.Checked;
  finally
    FUpdatingTarget := False;
  end;

  UpdateOKButton;
end;

procedure TfrmChooseMMC.FormCreate(Sender: TObject);
begin
  MainIniFile := nil;
  FUpdatingTarget := False;
  SnapInFileName := '';
  SnapInParameters := '';
  SnapInDisplayName := '';
  FInitialSnapInDisplayName := '';
  IconFileName := '';
  IconIndex := -1;
  UpdateOKButton;
end;

procedure TfrmChooseMMC.Initialize(const AMainIniFile: TCustomIniFile);
begin
  if Assigned(MainIniFile) then
    Exit;

  if not Assigned(AMainIniFile) then
    raise Exception.Create('Main INI file is not assigned.');

  MainIniFile := AMainIniFile;
  RestoreFormProperties;
end;

procedure TfrmChooseMMC.FormDestroy(Sender: TObject);
begin
  ClearSnapIns;
end;

procedure TfrmChooseMMC.FormHide(Sender: TObject);
begin
  SaveFormProperties;
end;

procedure TfrmChooseMMC.FormResize(Sender: TObject);
begin
  UpdateColumnWidths;
end;

procedure TfrmChooseMMC.FormShow(Sender: TObject);
var
  InitialFileName, InitialParameters, ComputerName: string;
begin
  InitialFileName := SnapInFileName;
  InitialParameters := SnapInParameters;
  edtSearch.Text := '';
  cbComputerName.Text := '';
  rbLocal.Checked := True;
  LoadRecentComputers;
  FillSnapIns;
  UpdateColumnWidths;
  SelectSnapIn(InitialFileName);
  FInitialSnapInDisplayName := '';
  if Assigned(lvSnapIns.Selected) and
    Assigned(lvSnapIns.Selected.Data) then
    FInitialSnapInDisplayName :=
      TMmcSnapInInfo(lvSnapIns.Selected.Data).DisplayName;
  UpdateDescription;
  UpdateTargetControls;
  if TryExtractComputerName(GetSelectedRemoteParameters,
    InitialParameters, ComputerName) then
  begin
    rbRemote.Checked := True;
    cbComputerName.Text := ComputerName;
  end;
  UpdateTargetControls;
  CenterOnMainForm;
  edtSearch.SetFocus;
end;

procedure TfrmChooseMMC.edtSearchChange(Sender: TObject);
var
  SearchText: string;
  Info: TMmcSnapInInfo;
  I: Integer;
begin
  SearchText := Trim(edtSearch.Text);
  if SearchText = '' then
    Exit;

  for I := 0 to lvSnapIns.Items.Count - 1 do
  begin
    Info := TMmcSnapInInfo(lvSnapIns.Items[I].Data);
    if Assigned(Info) and
      (ContainsTextUTF8(Info.DisplayName, SearchText) or
       ContainsTextUTF8(Info.FileName, SearchText) or
       ContainsTextUTF8(Info.Description, SearchText)) then
    begin
      lvSnapIns.Selected := lvSnapIns.Items[I];
      lvSnapIns.Items[I].MakeVisible(False);
      UpdateDescription;
      UpdateTargetControls;
      Exit;
    end;
  end;

  lvSnapIns.Selected := nil;
  UpdateDescription;
  UpdateTargetControls;
end;

procedure TfrmChooseMMC.lvSnapInsSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  UpdateDescription;
  UpdateTargetControls;
end;

procedure TfrmChooseMMC.TargetClick(Sender: TObject);
begin
  if FUpdatingTarget then
    Exit;

  UpdateTargetControls;
  if rbRemote.Checked and cbComputerName.Enabled then
    cbComputerName.SetFocus;
end;

procedure TfrmChooseMMC.cbComputerNameChange(Sender: TObject);
begin
  UpdateOKButton;
end;

procedure TfrmChooseMMC.lvSnapInsMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  { A mouse selection immediately returns typing to the search field.
    Keyboard navigation (including Tab) does not invoke this handler. }
  if Button = mbLeft then
    edtSearch.SetFocus;
end;

procedure TfrmChooseMMC.lvSnapInsDblClick(Sender: TObject);
begin
  if Assigned(lvSnapIns.Selected) then
    btnOK.Click;
end;

procedure TfrmChooseMMC.btnOKClick(Sender: TObject);
var
  Info: TMmcSnapInInfo;
begin
  if not Assigned(lvSnapIns.Selected) or
    not Assigned(lvSnapIns.Selected.Data) then
  begin
    ModalResult := mrNone;
    Exit;
  end;

  Info := TMmcSnapInInfo(lvSnapIns.Selected.Data);
  if rbRemote.Checked and
    ((Info.RemoteParameters = '') or
     (Trim(cbComputerName.Text) = '')) then
  begin
    ModalResult := mrNone;
    UpdateOKButton;
    Exit;
  end;

  SnapInFileName := Info.FileName;
  if rbRemote.Checked then
  begin
    SnapInParameters := BuildRemoteParameters(Info.RemoteParameters,
      cbComputerName.Text);
    SaveRecentComputer(cbComputerName.Text);
  end
  else
    SnapInParameters := '';
  SnapInDisplayName := Info.DisplayName;
  IconFileName := Info.IconFileName;
  IconIndex := Info.IconIndex;
  ModalResult := mrOK;
end;

end.
