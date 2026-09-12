unit LangsU;

{$mode delphi}{$H+}

interface

uses
  Forms, Classes, Menus, IniFiles;

type
  TLangMenuItem = class(TMenuItem)
  private
    FLangCode: string;
  public
    property LangCode: string read FLangCode write FLangCode;
  end;

procedure GenDefaultFileLang;
function GetLangString(const ASection, AString: string): string;
procedure SetLang(const ALangCode: string;
  const AMainIniFile: TIniFile);

function LangFillListAndGetCurrent(const AMainIniFile: TIniFile;
  const AMenu: TPopupMenu; const AmiLang: TMenuItem;
  const AOnClick: TNotifyEvent): Integer;

function AskForConfirmation(const AForm: TForm;
  const AConfirmation: string): Boolean;
function AskForDeletion(const AForm: TForm; const ACaption: string): Boolean;
procedure ErrorDialog(const AForm: TForm; const ACaption: string);

implementation

uses
  SysUtils, TypInfo, Controls, ExtCtrls, ActnList, Dialogs,
  ImgList, ComCtrls, Windows;

const
  cLangFolderName = 'Langs';

function M_GetUserDefaultUILanguage: LANGID; stdcall;
  external 'kernel32.dll' name 'GetUserDefaultUILanguage';

function M_SetProcessPreferredUILanguages(Flags: DWORD;
  Languages: PWideChar; var LanguageCount: ULONG): BOOL; stdcall;
  external 'kernel32.dll' name 'SetProcessPreferredUILanguages';

var
  FDefLangFile: TMemIniFile;
  FLangFile: TMemIniFile;
  FLangPath: string;

procedure LangAddDefaultStrings(const AForcedWrite: Boolean); forward;

function IsStringKind(AKind: TTypeKind): Boolean;
begin
  Result := AKind in [tkSString, tkLString, tkAString, tkWString, tkUString];
end;

procedure GenDefaultFileLang;

  function IsRuntimeCaption(const AObject: TObject): Boolean;
  begin
    Result := (AObject is TComponent) and
      (SameText(TComponent(AObject).Name, 'btnClose') or
       SameText(TComponent(AObject).Name, 'lblVer') or
       SameText(TComponent(AObject).Name, 'lblIsRunning'));
  end;

  function IsTranslatableProperty(const AObject: TObject;
    const APropertyName: string): Boolean;
  begin
    Result :=
      (SameText(APropertyName, 'Caption') and
        not IsRuntimeCaption(AObject)) or
      SameText(APropertyName, 'Hint') or
      ((AObject is TOpenDialog) and
        (SameText(APropertyName, 'Title') or
         SameText(APropertyName, 'Filter')));
  end;

  procedure WriteToLangFile(const ASectionName: string; AIdentPrefix: string;
    AObject: TObject);
  var
    I, PropCount: Integer;
    PropList: PPropList;
    PropInfo: PPropInfo;
    DataToSave: string;
    ChildObject: TObject;
  begin
    if (not Assigned(AObject)) or (AObject is TAction) then
      Exit;

    if AObject is TListColumns then
    begin
      for I := 0 to TListColumns(AObject).Count - 1 do
        WriteToLangFile(ASectionName,
          AIdentPrefix + '[' + IntToStr(I) + ']',
          TListColumns(AObject).Items[I]);
      Exit;
    end;

    if AIdentPrefix <> '' then
      AIdentPrefix := AIdentPrefix + '.';

    PropCount := GetTypeData(AObject.ClassInfo)^.PropCount;
    GetMem(PropList, SizeOf(PPropInfo) * PropCount);
    try
      GetPropInfos(AObject.ClassInfo, PropList);
      for I := 0 to PropCount - 1 do
      begin
        PropInfo := PropList^[I];
        if (PropInfo^.PropType^.Kind = tkClass) and
          (string(PropInfo^.Name) <> 'FocusControl') then
        begin
          ChildObject := GetObjectProp(AObject, PropInfo);
          if Assigned(ChildObject) and (ChildObject <> AObject) and
            (ChildObject is TPersistent) and
            not (ChildObject is TWinControl) and
            not (ChildObject is TCustomImageList) then
            WriteToLangFile(ASectionName,
              AIdentPrefix + string(PropInfo^.Name), ChildObject);
        end
        else if IsStringKind(PropInfo^.PropType^.Kind) and
            IsTranslatableProperty(AObject, string(PropInfo^.Name)) then
        begin
          DataToSave := GetStrProp(AObject, PropInfo);
          if (DataToSave <> '') and
            not ((AObject is TMenuItem) and
              (string(PropInfo^.Name) = 'Caption') and
              (DataToSave = '-')) then
            FLangFile.WriteString(ASectionName,
              AIdentPrefix + string(PropInfo^.Name), DataToSave);
        end;
      end;
    finally
      FreeMem(PropList);
    end;
  end;

  procedure WriteComponents(const ASectionName: string;
    AFormOrFrame: TScrollingWinControl);
  var
    I: Integer;
    Component: TComponent;
  begin
    for I := 0 to AFormOrFrame.ComponentCount - 1 do
    begin
      Component := AFormOrFrame.Components[I];
      if not (Component is TFrame) then
        WriteToLangFile(ASectionName, Component.Name, Component)
      else
        WriteComponents(ASectionName + '\' + Component.Name,
          TFrame(Component));
    end;
  end;

var
  FileName: string;
  I: Integer;
  Form: TForm;
begin
  if not DirectoryExists(FLangPath) then
    ForceDirectories(FLangPath);

  FileName := FLangPath + 'Default.ini';
  SysUtils.DeleteFile(FileName);
  FreeAndNil(FLangFile);
  FLangFile := TMemIniFile.Create(FileName);
  FLangFile.WriteString('LangProperties', '@LCID', '1033');
  FLangFile.WriteString('LangProperties', '@Name',
    'English - United States');
  LangAddDefaultStrings(True);
  for I := 0 to Screen.FormCount - 1 do
  begin
    Form := Screen.Forms[I];
    WriteToLangFile(Form.Name, '', Form);
    WriteComponents(Form.Name, Form);
  end;
  FLangFile.UpdateFile;

  FreeAndNil(FDefLangFile);
  FDefLangFile := TMemIniFile.Create(FileName);
end;

function GetLangString(const ASection, AString: string): string;
begin
  if Assigned(FLangFile) then
    Result := FLangFile.ReadString(ASection, '@' + AString, '')
  else
    Result := '';
end;

procedure SetLang(const ALangCode: string;
  const AMainIniFile: TIniFile);

  function ResolveChildObject(AObject: TObject;
    const APropertyPart: string): TObject;
  var
    OpenBracketPos, ItemIndex: Integer;
    PropertyName, IndexText: string;
    CollectionObject: TObject;
    Collection: TCollection;
  begin
    Result := nil;
    if not Assigned(AObject) then
      Exit;

    OpenBracketPos := Pos('[', APropertyPart);
    if OpenBracketPos > 1 then
    begin
      if APropertyPart[Length(APropertyPart)] <> ']' then
        Exit;

      PropertyName := Copy(APropertyPart, 1, OpenBracketPos - 1);
      IndexText := Copy(APropertyPart, OpenBracketPos + 1,
        Length(APropertyPart) - OpenBracketPos - 1);

      if not TryStrToInt(IndexText, ItemIndex) then
        Exit;

      CollectionObject := GetObjectProp(AObject, PropertyName);
      if not (CollectionObject is TCollection) then
        Exit;

      Collection := TCollection(CollectionObject);
      if (ItemIndex < 0) or (ItemIndex >= Collection.Count) then
        Exit;

      Result := Collection.Items[ItemIndex];
    end
    else if AObject is TScrollingWinControl then
      Result := TScrollingWinControl(AObject).FindComponent(APropertyPart)
    else
      Result := GetObjectProp(AObject, APropertyPart);
  end;

  procedure ReadFromLangFile(const ASectionName: string;
    AFormOrFrame: TScrollingWinControl);
  var
    Section, PropertyParts: TStringList;
    I, PartIndex: Integer;
    PropertyPath, PropertyName, PropertyValue: string;
    CurrentObject: TObject;
  begin
    Section := TStringList.Create;
    PropertyParts := TStringList.Create;
    try
      FLangFile.ReadSection(ASectionName, Section);
      for I := 0 to Section.Count - 1 do
      begin
        PropertyPath := Section[I];
        if (PropertyPath = '') or (PropertyPath[1] = '@') then
          Continue;

        PropertyValue := FLangFile.ReadString(ASectionName,
          PropertyPath, '');
        if PropertyValue = '' then
          Continue;

        PropertyParts.Clear;
        PropertyParts.StrictDelimiter := True;
        PropertyParts.Delimiter := '.';
        PropertyParts.DelimitedText := PropertyPath;
        CurrentObject := AFormOrFrame;

        for PartIndex := 0 to PropertyParts.Count - 1 do
        begin
          PropertyName := PropertyParts[PartIndex];
          if PartIndex < PropertyParts.Count - 1 then
          begin
            try
              CurrentObject := ResolveChildObject(CurrentObject,
                PropertyName);
            except
              on EPropertyError do
                CurrentObject := nil;
            end;
            if not Assigned(CurrentObject) then
              Break;
          end
          else
            try
              SetStrProp(CurrentObject, PropertyName, PropertyValue);
            except
              on EPropertyError do ;
            end;
        end;
      end;
    finally
      PropertyParts.Free;
      Section.Free;
    end;
  end;

var
  LangFileName, SectionName, FormName, FrameName: string;
  Sections, SectionKeys: TStringList;
  I, J, SeparatorPos: Integer;
  FormComponent, FrameComponent: TComponent;

  SelectedLCID: LCID;
  LanguageList: UnicodeString;
  LanguageCount: ULONG;

  LastError: DWORD;
begin
  LangFileName := FLangPath + ALangCode + '.ini';
  if not FileExists(LangFileName) then
    raise Exception.CreateFmt('Language file "%s" is not found',
      [LangFileName]);

  FreeAndNil(FLangFile);
  FLangFile := TMemIniFile.Create(LangFileName);

  SelectedLCID :=
    LCID(FLangFile.ReadInteger('LangProperties', '@LCID', 0));

  if SelectedLCID = 0 then
    raise Exception.CreateFmt(
      'The language file "%s" does not contain a valid LCID.',
      [LangFileName]
    );

  LanguageList :=
    UnicodeString(IntToHex(LANGIDFROMLCID(SelectedLCID), 4)) +
    WideChar(#0);

  LanguageCount := 0;

  if not M_SetProcessPreferredUILanguages(
     $00000004, // MUI_LANGUAGE_ID
     PWideChar(LanguageList),
     LanguageCount
     ) then
  begin
    LastError := GetLastError;

    ErrorDialog(
      Application.MainForm,
      Format(
        'Windows could not apply the UI language with LCID %d.%s%s',
        [
          SelectedLCID,
          LineEnding,
          SysErrorMessage(LastError)
        ]
      )
    );
  end
  else if LanguageCount = 0 then
  begin
    ErrorDialog(
      Application.MainForm,
      Format(
        'Windows could not apply the UI language with LCID %d.',
        [SelectedLCID]
      )
    );
  end;

  Sections := TStringList.Create;
  SectionKeys := TStringList.Create;
  try
    LangAddDefaultStrings(False);
    if not SameText(ALangCode, 'default') then
    begin
      FDefLangFile.ReadSections(Sections);
      for I := 0 to Sections.Count - 1 do
      begin
        SectionName := Sections[I];
        SectionKeys.Clear;
        FDefLangFile.ReadSection(SectionName, SectionKeys);
        for J := 0 to SectionKeys.Count - 1 do
          if not FLangFile.ValueExists(SectionName, SectionKeys[J]) then
            FLangFile.WriteString(SectionName, SectionKeys[J],
              FDefLangFile.ReadString(SectionName, SectionKeys[J], ''));
      end;
    end;

    Sections.Clear;
    FLangFile.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
    begin
      SectionName := Sections[I];
      if (SectionName = 'LangStrings') or
        (SectionName = 'LangProperties') then
        Continue;

      SeparatorPos := Pos('\', SectionName);
      if SeparatorPos = 0 then
      begin
        FormName := SectionName;
        FrameName := '';
      end
      else
      begin
        FormName := Copy(SectionName, 1, SeparatorPos - 1);
        FrameName := Copy(SectionName, SeparatorPos + 1, MaxInt);
      end;

      FormComponent := Application.FindComponent(FormName);
      if not (FormComponent is TForm) then
        Continue;

      if FrameName = '' then
        ReadFromLangFile(SectionName, TForm(FormComponent))
      else
      begin
        FrameComponent := TForm(FormComponent).FindComponent(FrameName);
        if FrameComponent is TFrame then
          ReadFromLangFile(SectionName, TFrame(FrameComponent));
      end;
    end;

    FLangFile.UpdateFile;
  finally
    SectionKeys.Free;
    Sections.Free;
  end;

  if Assigned(AMainIniFile) then
    AMainIniFile.WriteString('Main', 'LangCode', ALangCode);
end;

procedure LangAddDefaultStrings(const AForcedWrite: Boolean);

  procedure MyWriteString(const ASection, AIdent, AValue: string);
  begin
    if AForcedWrite or (not FLangFile.ValueExists(ASection, AIdent)) then
      FLangFile.WriteString(ASection, AIdent, AValue);
  end;

  begin
    MyWriteString('LangStrings', '@Cancel', 'Cancel');
    MyWriteString('LangStrings', '@Close', 'Close');
    MyWriteString('LangStrings', '@DeleteConfirm',
      'Are you sure you want to delete "%s"?');
    MyWriteString('LangStrings', '@CancelConfirm',
      'Discard unsaved changes?');
    MyWriteString('LangStrings', '@ErrorEmptyName',
      'Enter a name.');

    MyWriteString('frmConfig', '@Version', 'Version:');

    MyWriteString('frmConfig\frmCommandConfig',
      '@IsRunning', 'Running');
    MyWriteString('frmConfig\frmCommandConfig',
      '@IsNotRunning', 'Not running');
    MyWriteString('frmConfig\frmCommandConfig',
      '@ErrorCommand', 'Specify a command or file to run.');

    MyWriteString('frmExtensions',
      '@ActionForEdit', '<b>Edit</b> action');
    MyWriteString('frmExtensions',
      '@ActionForRun', '<b>Run</b> action');
    MyWriteString('frmExtensions',
      '@ErrorEmptyExtensions',
      'Enter at least one file extension.');
  end;

function LangFillListAndGetCurrent(const AMainIniFile: TIniFile;
  const AMenu: TPopupMenu; const AmiLang: TMenuItem;
  const AOnClick: TNotifyEvent): Integer;

  procedure AddSubMenuItem(const ALangName, ALangCode: string);
  var
    MenuItem: TLangMenuItem;
  begin
    MenuItem := TLangMenuItem.Create(AMenu);
    MenuItem.Caption := ALangName;
    MenuItem.LangCode := ALangCode;
    MenuItem.RadioItem := True;
    MenuItem.OnClick := AOnClick;
    AmiLang.Add(MenuItem);
  end;

var
  UserDefaultLCID: LANGID;
  CurrentIniLangCode, LangCode, LangCaption: string;
  CurrentItemIndexForIniLang, CurrentItemIndexForLCID: Integer;
  SearchRec: TSearchRec;
  CurrentItemIndex: Integer;
  LangIni: TMemIniFile;
begin
  Result := 0;
  UserDefaultLCID := M_GetUserDefaultUILanguage;
  CurrentIniLangCode := AMainIniFile.ReadString('Main', 'LangCode', '');

  AddSubMenuItem('Default - English', 'Default');
  if SameText(CurrentIniLangCode, 'Default') then
    CurrentItemIndexForIniLang := 0
  else
    CurrentItemIndexForIniLang := -1;

  if StrToUIntDef(GetLangString('LangProperties', 'LCID'), 0) =
    UserDefaultLCID then
    CurrentItemIndexForLCID := 0
  else
    CurrentItemIndexForLCID := -1;

  CurrentItemIndex := 1;
  if SysUtils.FindFirst(FLangPath + '???.ini', faAnyFile,
    SearchRec) = 0 then
    try
      repeat
        LangCode := ChangeFileExt(SearchRec.Name, '');
        LangIni := TMemIniFile.Create(FLangPath + SearchRec.Name);
        try
          LangCaption := LangIni.ReadString('LangProperties', '@Name', '');
          if LangCaption <> '' then
          begin
            if (CurrentItemIndexForLCID = -1) and
              (LANGID(LangIni.ReadInteger('LangProperties', '@LCID', 0)) =
                UserDefaultLCID) then
              CurrentItemIndexForLCID := CurrentItemIndex;
            if (CurrentItemIndexForIniLang = -1) and
              SameText(LangCode, CurrentIniLangCode) then
              CurrentItemIndexForIniLang := CurrentItemIndex;
            AddSubMenuItem(LangCaption, LangCode);
          end;
        finally
          LangIni.Free;
        end;
        Inc(CurrentItemIndex);
      until SysUtils.FindNext(SearchRec) <> 0;
    finally
      SysUtils.FindClose(SearchRec);
    end;

  if CurrentIniLangCode = '' then
    Result := 0
  else if CurrentItemIndexForIniLang >= 0 then
    Result := CurrentItemIndexForIniLang
  else if CurrentItemIndexForLCID >= 0 then
    Result := CurrentItemIndexForLCID;
end;

function AskForConfirmation(const AForm: TForm;
  const AConfirmation: string): Boolean;
var
  WideConfirmation, WideCaption: UnicodeString;
begin
  WideConfirmation := UTF8Decode(AConfirmation);
  WideCaption := UTF8Decode(AForm.Caption);
  Result := MessageBoxExW(AForm.Handle, PWideChar(WideConfirmation),
    PWideChar(WideCaption), MB_ICONWARNING or MB_OKCANCEL or MB_DEFBUTTON2,
    StrToIntDef(GetLangString('LangProperties', 'LCID'), 0)) = IDOK;
end;

function AskForDeletion(const AForm: TForm; const ACaption: string): Boolean;
begin
  Result := AskForConfirmation(AForm,
    Format(GetLangString('LangStrings', 'DeleteConfirm'), [ACaption]));
end;

procedure ErrorDialog(const AForm: TForm; const ACaption: string);
var
  WideText, WideCaption: UnicodeString;
begin
  WideText := UTF8Decode(ACaption);
  WideCaption := UTF8Decode(AForm.Caption);
  MessageBoxExW(AForm.Handle, PWideChar(WideText), PWideChar(WideCaption),
    MB_ICONERROR, StrToIntDef(GetLangString('LangProperties', 'LCID'), 0));
end;

initialization
  FDefLangFile := nil;
  FLangFile := nil;
  FLangPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)) +
    cLangFolderName);

finalization
  FDefLangFile.Free;
  FLangFile.Free;

end.
