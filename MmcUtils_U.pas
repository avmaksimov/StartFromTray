unit MmcUtils_U;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Graphics, ImgList, Windows;

function GetLocalizedMscPath(const AFileName: string): string;
procedure ReadConsoleMetadata(const AFileName: string;
  out ADisplayName, ASnapInID, AIconFileName: string;
  out AIconIndex: Integer);
function ReadSnapInRegistration(const ASnapInID: string;
  out ADisplayName, ADescription, AAboutClassID, AIconFileName: string;
  out AIconIndex: Integer): Boolean;
procedure ReadSnapInAbout(const AAboutClassID: string;
  out ADescription: string; out AIcon: HICON);
function AddSmallIcon(const AImageList: TCustomImageList;
  const ABaseFileName, AIconFileName: string;
  const AIconIndex: Integer; var AAboutIcon: HICON): Integer;

function TryLoadMmcSnapInIcon(const AMscFileName: string;
  AIcon: TIcon): Boolean;

implementation

uses
  ActiveX, Registry, ShellApi, DOM, XMLRead, CommonU, LangsU;

const
  C_MUI_LANGUAGE_ID = $00000004;
  C_MUI_USER_PREFERRED_UI_LANGUAGES = $00000010;
  C_MUI_NON_LANG_NEUTRAL_FILE = $00000200;
  C_LOCALE_NAME_MAX_LENGTH = 85;
  C_SNAPINS_REGISTRY_KEY = '\SOFTWARE\Microsoft\MMC\SnapIns\';
  C_MMC_FOLDER_SNAPIN_ID = '{C96401CC-0E17-11D3-885B-00C04F72C717}';
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
  ComInitializationResult: HRESULT;
  MustUninitializeCOM: Boolean;
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

  ComInitializationResult := CoInitialize(nil);
  MustUninitializeCOM :=
    (ComInitializationResult = S_OK) or
    (ComInitializationResult = S_FALSE);
  About := nil;
  try
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
  finally
    About := nil;
    if MustUninitializeCOM then
      CoUninitialize;
  end;
end;

function TryLoadSmallIcon(const ABaseFileName, AIconFileName: string;
  const AIconIndex: Integer; AIcon: TIcon): Boolean;
var
  IconHandle, LargeIcon, SmallIcon: HICON;
  FileInfo: TSHFileInfoW;
  WideFileName: UnicodeString;
begin
  Result := False;
  if not Assigned(AIcon) then
    Exit;

  IconHandle := 0;
  LargeIcon := 0;
  SmallIcon := 0;
  try
    if AIconFileName <> '' then
    begin
      WideFileName := UTF8Decode(AIconFileName);
      ExtractIconExW(PWideChar(WideFileName), AIconIndex,
        @LargeIcon, @SmallIcon, 1);
      if SmallIcon <> 0 then
      begin
        IconHandle := SmallIcon;
        SmallIcon := 0;
      end
      else if LargeIcon <> 0 then
      begin
        IconHandle := LargeIcon;
        LargeIcon := 0;
      end;
    end;

    if IconHandle = 0 then
    begin
      FileInfo := Default(TSHFileInfoW);
      WideFileName := UTF8Decode(ABaseFileName);
      if SHGetFileInfoW(PWideChar(WideFileName), 0, FileInfo,
        SizeOf(FileInfo), SHGFI_ICON or SHGFI_SMALLICON) <> 0 then
        IconHandle := FileInfo.hIcon;
    end;

    if IconHandle = 0 then
      Exit;

    AIcon.Handle := IconHandle;
    IconHandle := 0;
    Result := AIcon.Handle <> 0;
  finally
    if IconHandle <> 0 then
      DestroyIcon(IconHandle);
    if LargeIcon <> 0 then
      DestroyIcon(LargeIcon);
    if SmallIcon <> 0 then
      DestroyIcon(SmallIcon);
  end;
end;

function AddSmallIcon(const AImageList: TCustomImageList;
  const ABaseFileName, AIconFileName: string;
  const AIconIndex: Integer; var AAboutIcon: HICON): Integer;
var
  Icon: TIcon;
begin
  Result := -1;
  if not Assigned(AImageList) then
    Exit;

  Icon := TIcon.Create;
  try
    if AAboutIcon <> 0 then
    begin
      Icon.Handle := AAboutIcon;
      AAboutIcon := 0;
    end
    else if not TryLoadSmallIcon(ABaseFileName, AIconFileName,
      AIconIndex, Icon) then
      Exit;

    Result := AImageList.AddIcon(Icon);
  finally
    Icon.Free;
  end;
end;

function TryLoadMmcSnapInIcon(const AMscFileName: string;
  AIcon: TIcon): Boolean;
var
  BaseFileName, LocalizedFileName: string;
  DisplayName, SnapInID, IconFileName: string;
  BaseDisplayName, BaseSnapInID, BaseIconFileName: string;
  RegisteredName, Description, AboutClassID: string;
  RegisteredIconFileName, AboutDescription: string;
  IconIndex, BaseIconIndex, RegisteredIconIndex: Integer;
  AboutIcon: HICON;
begin
  Result := False;
  if not Assigned(AIcon) or (Trim(AMscFileName) = '') then
    Exit;

  BaseFileName := Trim(AMscFileName);
  if ExtractFilePath(BaseFileName) = '' then
    BaseFileName :=
      IncludeTrailingPathDelimiter(GetNativeSystemDirectoryForAccess) +
      BaseFileName;

  if not FileExists(BaseFileName) then
    Exit;

  LocalizedFileName := GetLocalizedMscPath(BaseFileName);

  ReadConsoleMetadata(LocalizedFileName, DisplayName, SnapInID,
    IconFileName, IconIndex);

  if not SameText(LocalizedFileName, BaseFileName) and
    ((SnapInID = '') or (IconFileName = '')) then
  begin
    ReadConsoleMetadata(BaseFileName, BaseDisplayName, BaseSnapInID,
      BaseIconFileName, BaseIconIndex);

    if DisplayName = '' then
      DisplayName := BaseDisplayName;

    if SnapInID = '' then
      SnapInID := BaseSnapInID;

    if IconFileName = '' then
    begin
      IconFileName := BaseIconFileName;
      IconIndex := BaseIconIndex;
    end;
  end;

  RegisteredName := '';
  Description := '';
  AboutClassID := '';
  RegisteredIconFileName := '';
  RegisteredIconIndex := -1;
  AboutDescription := '';
  AboutIcon := 0;

  try
    if ReadSnapInRegistration(SnapInID, RegisteredName, Description,
      AboutClassID, RegisteredIconFileName, RegisteredIconIndex) then
    begin
      ReadSnapInAbout(AboutClassID, AboutDescription, AboutIcon);
      if AboutIcon <> 0 then
      begin
        AIcon.Handle := AboutIcon;
        AboutIcon := 0;
        Exit(AIcon.Handle <> 0);
      end;

      if RegisteredIconFileName <> '' then
      begin
        IconFileName := RegisteredIconFileName;
        IconIndex := RegisteredIconIndex;
      end;
    end;

    Result := TryLoadSmallIcon(BaseFileName, IconFileName,
      IconIndex, AIcon);
  finally
    if AboutIcon <> 0 then
      DestroyIcon(AboutIcon);
  end;
end;

end.
