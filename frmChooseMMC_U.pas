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
    FUpdatingTarget: Boolean;
    FInitialSnapInDisplayName: string;
    procedure CenterOnMainForm;
    procedure ClearSnapIns;
    procedure FillSnapIns;
    function GetMaxRecentComputerCount: Integer;
    function GetSelectedRemoteParameters: string;
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
    property InitialSnapInDisplayName: string
	read FInitialSnapInDisplayName;
    procedure Initialize(const AMainIniFile: TCustomIniFile);
  end;

var
  frmChooseMMC: TfrmChooseMMC;

implementation

uses
  Windows, ActiveX, Registry, ShellApi, LazUTF8, DOM, XMLRead, CommonU,
  LangsU;

{$R *.lfm}

const
  C_MUI_LANGUAGE_ID = $00000004;
  C_MUI_USER_PREFERRED_UI_LANGUAGES = $00000010;
  C_MUI_NON_LANG_NEUTRAL_FILE = $00000200;
  C_LOCALE_NAME_MAX_LENGTH = 85;
  C_SNAPINS_REGISTRY_KEY = '\SOFTWARE\Microsoft\MMC\SnapIns\';
  C_MMC_FOLDER_SNAPIN_ID = '{C96401CC-0E17-11D3-885B-00C04F72C717}';
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
  IID_ISnapInAbout: TGUID = '{1245208C-A151-11D0-A7D7-00C04FD909DD}';

type
  ISnapInAbout = interface(IUnknown)
    ['{1245208C-A151-11D0-A7D7-00C04FD909DD}']
    function GetSnapinDescription(out ADescription: PWideChar): HRESULT;
      stdcall;
    function GetProvider(out AName: PWideChar): HRESULT; stdcall;
    function GetSnapinVersion(out AVersion: PWideChar): HRESULT; stdcall;
    function GetSnapinImage(out AIcon: HICON): HRESULT; stdcall;
    function GetStaticFolderImage(out ASmallImage: HBITMAP;
      out ASmallImageOpen: HBITMAP; out ALargeImage: HBITMAP;
      out AMaskColor: COLORREF): HRESULT; stdcall;
  end;

function M_GetFileMUIPath(Flags: DWORD; FilePath, Language: PWideChar;
  LanguageLength: PCardinal; MUIPath: PWideChar;
  MUIPathLength: PCardinal; Enumerator: PQWord): BOOL; stdcall;
  external 'kernel32.dll' name 'GetFileMUIPath';

function M_SHLoadIndirectString(Source, OutputBuffer: PWideChar;
  OutputBufferLength: UINT; Reserved: Pointer): HRESULT; stdcall;
  external 'shlwapi.dll' name 'SHLoadIndirectString';

function DomStringToUTF8(const AValue: DOMString): string;
begin
  Result := UTF8Encode(UnicodeString(AValue));
end;

function ContainsTextUTF8(const AText, ASearchText: string): Boolean;
begin
  Result := UTF8Pos(UTF8LowerCase(ASearchText),
    UTF8LowerCase(AText)) > 0;
end;

function FindDirectChildElement(const AParent: TDOMNode;
  const AName: string): TDOMElement;
var
  Node: TDOMNode;
begin
  Result := nil;
  if not Assigned(AParent) then
    Exit;

  Node := AParent.FirstChild;
  while Assigned(Node) do
  begin
    if (Node is TDOMElement) and
      SameText(DomStringToUTF8(Node.NodeName), AName) then
      Exit(TDOMElement(Node));
    Node := Node.NextSibling;
  end;
end;

function FindFirstElementByName(const ANode: TDOMNode;
  const AName: string): TDOMElement;
var
  Child: TDOMNode;
begin
  Result := nil;
  if not Assigned(ANode) then
    Exit;

  Child := ANode.FirstChild;
  while Assigned(Child) do
  begin
    if Child is TDOMElement then
    begin
      if SameText(DomStringToUTF8(Child.NodeName), AName) then
        Exit(TDOMElement(Child));
      Result := FindFirstElementByName(Child, AName);
      if Assigned(Result) then
        Exit;
    end;
    Child := Child.NextSibling;
  end;
end;

function IsMmcFolderSnapIn(const ASnapInID: string): Boolean;
var
  SnapInID: string;
begin
  SnapInID := Trim(ASnapInID);
  if SameText(Copy(SnapInID, 1, 3), 'FX:') then
    Delete(SnapInID, 1, 3);
  Result := SameText(SnapInID, C_MMC_FOLDER_SNAPIN_ID);
end;

function FindFirstUsableSnapInID(const ANode: TDOMNode;
  const AElementName: string): string;
var
  Child: TDOMNode;
  SnapInID: string;
begin
  Result := '';
  if not Assigned(ANode) then
    Exit;

  Child := ANode.FirstChild;
  while Assigned(Child) do
  begin
    if Child is TDOMElement then
    begin
      if SameText(DomStringToUTF8(Child.NodeName), AElementName) then
      begin
        SnapInID := Trim(DomStringToUTF8(
          TDOMElement(Child).GetAttribute('CLSID')));
        if (SnapInID <> '') and not IsMmcFolderSnapIn(SnapInID) then
          Exit(SnapInID);
      end;

      Result := FindFirstUsableSnapInID(Child, AElementName);
      if Result <> '' then
        Exit;
    end;
    Child := Child.NextSibling;
  end;
end;

function FindStringElementByID(const ANode: TDOMNode;
  const AID: string): TDOMElement;
var
  Child: TDOMNode;
  Element: TDOMElement;
begin
  Result := nil;
  if not Assigned(ANode) then
    Exit;

  Child := ANode.FirstChild;
  while Assigned(Child) do
  begin
    if Child is TDOMElement then
    begin
      Element := TDOMElement(Child);
      if SameText(DomStringToUTF8(Element.NodeName), 'String') and
        SameText(DomStringToUTF8(Element.GetAttribute('ID')), AID) then
        Exit(Element);

      Result := FindStringElementByID(Child, AID);
      if Assigned(Result) then
        Exit;
    end;
    Child := Child.NextSibling;
  end;
end;

function TryGetMUIPath(const AFileName, ALanguageID: string;
  const AFlags: DWORD; out AMUIPath: string): Boolean;
var
  WideFileName, WideLanguage, WideMUIPath: UnicodeString;
  LanguageLength, MUIPathLength: Cardinal;
  Enumerator: QWord;
begin
  Result := False;
  AMUIPath := '';

  WideFileName := UTF8Decode(AFileName);

  if ALanguageID <> '' then
  begin
    WideLanguage := UTF8Decode(ALanguageID);
    LanguageLength := Length(WideLanguage) + 1;
  end
  else
  begin
    SetLength(WideLanguage, C_LOCALE_NAME_MAX_LENGTH);
    WideLanguage[1] := #0;
    LanguageLength := C_LOCALE_NAME_MAX_LENGTH;
  end;

  WideMUIPath := '';
  SetLength(WideMUIPath, MAX_PATH);
  MUIPathLength := MAX_PATH;
  Enumerator := 0;

  if not M_GetFileMUIPath(
    AFlags or C_MUI_NON_LANG_NEUTRAL_FILE,
    PWideChar(WideFileName),
    PWideChar(WideLanguage),
    @LanguageLength,
    PWideChar(WideMUIPath),
    @MUIPathLength,
    @Enumerator
  ) then
    Exit;

  AMUIPath := UTF8Encode(UnicodeString(PWideChar(WideMUIPath)));
  Result := AMUIPath <> '';
end;

function GetLocalizedMscPath(const AFileName: string): string;
var
  SelectedLCID: LCID;
  SelectedLanguageID, MUIPath: string;
begin
  SelectedLCID := LCID(StrToIntDef(
    GetLangString('LangProperties', 'LCID'), 1033));
  SelectedLanguageID := IntToHex(LANGIDFROMLCID(SelectedLCID), 4);

  { First use the language selected in StartFromTray. }
  if TryGetMUIPath(AFileName, SelectedLanguageID,
    C_MUI_LANGUAGE_ID, MUIPath) then
    Exit(MUIPath);

  { Then use the Windows user interface fallback list. }
  if TryGetMUIPath(AFileName, '',
    C_MUI_LANGUAGE_ID or C_MUI_USER_PREFERRED_UI_LANGUAGES,
    MUIPath) then
    Exit(MUIPath);

  { Finally try US English explicitly before using the base file. }
  if not SameText(SelectedLanguageID, '0409') and
    TryGetMUIPath(AFileName, '0409', C_MUI_LANGUAGE_ID, MUIPath) then
    Exit(MUIPath);

  Result := AFileName;
end;

procedure ReadConsoleMetadata(const AFileName: string;
  out ADisplayName, ASnapInID, AIconFileName: string;
  out AIconIndex: Integer);
var
  Document: TXMLDocument;
  Root, VisualAttributes, StringTables, ScopeTree, Nodes,
    SnapInCache: TDOMElement;
  Node, TitleNode, IconNode: TDOMNode;
  Element: TDOMElement;
  TitleID, Value: string;
begin
  ADisplayName := '';
  ASnapInID := '';
  AIconFileName := '';
  AIconIndex := -1;
  Document := nil;

  try
    ReadXMLFile(Document, AFileName);
    Root := Document.DocumentElement;
    VisualAttributes := FindDirectChildElement(Root, 'VisualAttributes');
    StringTables := FindDirectChildElement(Root, 'StringTables');

    { The first SnapinCache entry is often MMC's generic Folder snap-in.
      Prefer the first real snap-in used by the visible scope tree. }
    ScopeTree := FindFirstElementByName(Root, 'ScopeTree');
    Nodes := FindDirectChildElement(ScopeTree, 'Nodes');
    ASnapInID := FindFirstUsableSnapInID(Nodes, 'Node');

    { Some consoles have no usable scope-tree node. In that case use the
      first non-Folder entry registered in the console's snap-in cache. }
    if ASnapInID = '' then
    begin
      SnapInCache := FindFirstElementByName(Root, 'SnapinCache');
      ASnapInID := FindFirstUsableSnapInID(SnapInCache, 'SnapIn');
    end;

    TitleID := '';
    IconNode := nil;
    if Assigned(VisualAttributes) then
    begin
      Node := VisualAttributes.FirstChild;
      while Assigned(Node) do
      begin
        if Node is TDOMElement then
        begin
          Element := TDOMElement(Node);
          if SameText(DomStringToUTF8(Element.NodeName), 'String') and
            SameText(DomStringToUTF8(Element.GetAttribute('Name')),
              'ApplicationTitle') then
            TitleID := DomStringToUTF8(Element.GetAttribute('ID'))
          else if SameText(DomStringToUTF8(Element.NodeName), 'Icon') and
            not Assigned(IconNode) then
            IconNode := Node;
        end;
        Node := Node.NextSibling;
      end;
    end;

    if (TitleID <> '') and Assigned(StringTables) then
    begin
      TitleNode := FindStringElementByID(StringTables, TitleID);
      if Assigned(TitleNode) then
        ADisplayName := Trim(DomStringToUTF8(TitleNode.TextContent));
    end;

    if Assigned(IconNode) then
    begin
      Element := TDOMElement(IconNode);
      Value := DomStringToUTF8(Element.GetAttribute('File'));
      if Value <> '' then
      begin
        AIconFileName := MyExpandEnvironmentStrings(Value);
        if (AIconFileName <> '') and
          (ExtractFileDrive(AIconFileName) = '') then
          AIconFileName := ExpandFileName(
            IncludeTrailingPathDelimiter(ExtractFilePath(AFileName)) +
            AIconFileName);

        { Negative resource identifiers are valid for ExtractIconExW. }
        AIconIndex := StrToIntDef(
          DomStringToUTF8(Element.GetAttribute('Index')), 0);
      end;
    end;
  except
    { Some third-party console files are not readable XML. The file remains
      selectable and falls back to its file name and shell icon. }
    ADisplayName := '';
    ASnapInID := '';
    AIconFileName := '';
    AIconIndex := -1;
  end;

  Document.Free;
end;

function ResolveIndirectString(const AValue: string): string;
var
  Value: string;
  WideSource, WideResult: UnicodeString;
begin
  Result := '';

  Value := Trim(AValue);
  if Value = '' then
    Exit;

  WideSource := UTF8Decode(MyExpandEnvironmentStrings(Value));

  WideResult := '';
  SetLength(WideResult, 4096);

  if M_SHLoadIndirectString(
    PWideChar(WideSource),
    PWideChar(WideResult),
    Length(WideResult),
    nil
  ) >= 0 then
    Result := Trim(UTF8Encode(UnicodeString(PWideChar(WideResult))));
end;

function ReadLocalizedRegistryString(const ARegistry: TRegistry;
  const AIndirectValueName, ADirectValueName: string): string;
var
  Value: string;
begin
  Result := '';

  if ARegistry.ValueExists(AIndirectValueName) then
  begin
    Value := ARegistry.ReadString(AIndirectValueName);
    Result := ResolveIndirectString(Value);
  end;

  if (Result = '') and ARegistry.ValueExists(ADirectValueName) then
  begin
    Value := Trim(ARegistry.ReadString(ADirectValueName));
    if (Value <> '') and (Value[1] = '@') then
      Result := ResolveIndirectString(Value);
    if Result = '' then
      Result := Value;
  end;
end;

procedure ParseIndirectIcon(const AValue: string;
  out AFileName: string; out AIconIndex: Integer);
var
  Value, IndexText: string;
  CommaPosition: Integer;
begin
  AFileName := '';
  AIconIndex := -1;
  Value := Trim(AValue);
  if Value = '' then
    Exit;

  if Value[1] = '@' then
    Delete(Value, 1, 1);

  CommaPosition := LastDelimiter(',', Value);
  if CommaPosition > 0 then
  begin
    IndexText := Trim(Copy(Value, CommaPosition + 1, MaxInt));
    if TryStrToInt(IndexText, AIconIndex) then
      Delete(Value, CommaPosition, MaxInt)
    else
      AIconIndex := 0;
  end
  else
    AIconIndex := 0;

  Value := Trim(Value);
  if (Length(Value) >= 2) and (Value[1] = '"') and
    (Value[Length(Value)] = '"') then
    Value := Copy(Value, 2, Length(Value) - 2);
  if (Value <> '') and (Value[1] = '@') then
    Delete(Value, 1, 1);

  AFileName := MyExpandEnvironmentStrings(Value);
end;

function OpenSnapInRegistryKey(const ARegistry: TRegistry;
  const ASnapInID: string): Boolean;
var
  KeyID: string;
begin
  KeyID := Trim(ASnapInID);
  Result := (KeyID <> '') and
    ARegistry.OpenKeyReadOnly(C_SNAPINS_REGISTRY_KEY + KeyID);
  if Result then
    Exit;

  if SameText(Copy(KeyID, 1, 3), 'FX:') then
    Delete(KeyID, 1, 3)
  else
    KeyID := 'FX:' + KeyID;

  Result := (KeyID <> '') and
    ARegistry.OpenKeyReadOnly(C_SNAPINS_REGISTRY_KEY + KeyID);
end;

function ReadSnapInRegistrationFromView(const ASnapInID: string;
  const ARegistryView: LongWord; out ADisplayName, ADescription,
  AAboutClassID, AIconFileName: string; out AIconIndex: Integer): Boolean;
var
  Reg: TRegistry;
begin
  ADisplayName := '';
  ADescription := '';
  AAboutClassID := '';
  AIconFileName := '';
  AIconIndex := -1;
  Result := False;
  Reg := TRegistry.Create(KEY_READ or ARegistryView);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if not OpenSnapInRegistryKey(Reg, ASnapInID) then
      Exit;

    ADisplayName := ReadLocalizedRegistryString(Reg,
      'NameStringIndirect', 'NameString');
    ADescription := ReadLocalizedRegistryString(Reg,
      'DescriptionStringIndirect', 'DescriptionString');

    if Reg.ValueExists('About') then
      AAboutClassID := Trim(Reg.ReadString('About'));
    if Reg.ValueExists('IconIndirect') then
      ParseIndirectIcon(Reg.ReadString('IconIndirect'),
        AIconFileName, AIconIndex);
    Result := True;
  finally
    Reg.Free;
  end;
end;

function ReadSnapInRegistration(const ASnapInID: string;
  out ADisplayName, ADescription, AAboutClassID, AIconFileName: string;
  out AIconIndex: Integer): Boolean;
const
  RegistryViews: array[0..2] of LongWord =
    (0, KEY_WOW64_64KEY, KEY_WOW64_32KEY);
var
  I: Integer;
begin
  ADisplayName := '';
  ADescription := '';
  AAboutClassID := '';
  AIconFileName := '';
  AIconIndex := -1;
  Result := False;

  for I := Low(RegistryViews) to High(RegistryViews) do
    try
      if ReadSnapInRegistrationFromView(ASnapInID, RegistryViews[I],
        ADisplayName, ADescription, AAboutClassID, AIconFileName,
        AIconIndex) then
        Exit(True);
    except
      { A registry view can be unavailable on the current Windows edition. }
    end;
end;

procedure ReadSnapInAbout(const AAboutClassID: string;
  out ADescription: string; out AIcon: HICON);
var
  AboutClassID: TGUID;
  About: ISnapInAbout;
  DescriptionPointer: PWideChar;
  OriginalIcon: HICON;
begin
  ADescription := '';
  AIcon := 0;
  if Trim(AAboutClassID) = '' then
    Exit;

  try
    AboutClassID := StringToGUID(Trim(AAboutClassID));
  except
    Exit;
  end;

  About := nil;
  if CoCreateInstance(AboutClassID, nil, CLSCTX_INPROC_SERVER,
    IID_ISnapInAbout, About) < 0 then
    Exit;

  DescriptionPointer := nil;
  if About.GetSnapinDescription(DescriptionPointer) >= 0 then
    try
      if Assigned(DescriptionPointer) then
        ADescription := Trim(UTF8Encode(
          UnicodeString(DescriptionPointer)));
    finally
      if Assigned(DescriptionPointer) then
        CoTaskMemFree(DescriptionPointer);
    end;

  OriginalIcon := 0;
  if (About.GetSnapinImage(OriginalIcon) >= 0) and
    (OriginalIcon <> 0) then
    { The snap-in owns the returned icon. Keep an independent copy. }
    AIcon := CopyIcon(OriginalIcon);
end;

function AddSmallIcon(const AImageList: TImageList;
  const ABaseFileName, AIconFileName: string;
  const AIconIndex: Integer; const AAboutIcon: HICON): Integer;
var
  Icon: TIcon;
  LargeIcon, SmallIcon: HICON;
  FileInfo: TSHFileInfoW;
  WideFileName: UnicodeString;
begin
  Result := -1;
  LargeIcon := 0;
  SmallIcon := AAboutIcon;

  if (SmallIcon = 0) and (AIconFileName <> '') then
  begin
    WideFileName := UTF8Decode(AIconFileName);
    ExtractIconExW(PWideChar(WideFileName), AIconIndex,
      @LargeIcon, @SmallIcon, 1);
  end;

  if SmallIcon = 0 then
  begin
    if LargeIcon <> 0 then
    begin
      DestroyIcon(LargeIcon);
      LargeIcon := 0;
    end;

    FileInfo := Default(TSHFileInfoW);
    WideFileName := UTF8Decode(ABaseFileName);
    if SHGetFileInfoW(PWideChar(WideFileName), 0, FileInfo,
      SizeOf(FileInfo), SHGFI_ICON or SHGFI_SMALLICON) <> 0 then
      SmallIcon := FileInfo.hIcon;
  end;

  if SmallIcon = 0 then
    Exit;

  Icon := TIcon.Create;
  try
    Icon.Handle := SmallIcon;
    SmallIcon := 0;
    Result := AImageList.AddIcon(Icon);
  finally
    Icon.Free;
    if LargeIcon <> 0 then
      DestroyIcon(LargeIcon);
    if SmallIcon <> 0 then
      DestroyIcon(SmallIcon);
  end;
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
  SystemDirectoryBuffer: array[0..MAX_PATH] of WideChar;
  SystemDirectoryWide: UnicodeString;
  SystemDirectory, BaseFileName, LocalizedFileName: string;
  DisplayName, SnapInID, SnapInIconFileName: string;
  BaseDisplayName, BaseSnapInID, BaseIconFileName: string;
  RegisteredName, Description, AboutClassID, RegisteredIconFileName: string;
  AboutDescription: string;
  SnapInIconIndex, BaseIconIndex, RegisteredIconIndex: Integer;
  LengthRead: UINT;
  SearchRec: TSearchRec;
  Info: TMmcSnapInInfo;
  Item: TListItem;
  AboutIcon: HICON;
  ComInitializationResult: HRESULT;
  MustUninitializeCOM: Boolean;
  RemoteIniFile: TIniFile;
begin
  ClearSnapIns;

  LengthRead := GetSystemDirectoryW(@SystemDirectoryBuffer[0],
    Length(SystemDirectoryBuffer));
  if (LengthRead = 0) or (LengthRead >= Length(SystemDirectoryBuffer)) then
    Exit;

  SetString(SystemDirectoryWide, PWideChar(@SystemDirectoryBuffer[0]),
    LengthRead);
  SystemDirectory := IncludeTrailingPathDelimiter(
    UTF8Encode(SystemDirectoryWide));

  ComInitializationResult := CoInitialize(nil);
  MustUninitializeCOM := (ComInitializationResult = S_OK) or
    (ComInitializationResult = S_FALSE);
  RemoteIniFile := nil;
  try
    if FileExists(GetMmcRemoteIniFileName) then
      RemoteIniFile := TIniFile.Create(GetMmcRemoteIniFileName);
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
    if MustUninitializeCOM then
      CoUninitialize;
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
