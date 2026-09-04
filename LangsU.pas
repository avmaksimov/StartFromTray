unit LangsU;

{$mode delphi}{$H+}

interface

uses
  Forms, Classes, Menus, IniFiles;

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
  ImgList, Windows;

const
  cLangFolderName = 'Langs';
  ExcludesForFormConfig: array[0..1] of string = ('btnClose', 'lblVer');
  ExcludesForFrameCommandConfig: array[0..7] of string =
    ('gbRunAtTime', 'lblisRun_FolderChanged', 'lblNextRun', 'cbRunAt',
     'cbIsRepeatRun', 'cbisRun_isWhenFolderChange', 'cbIsVisible',
     'lblIsRunning');

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

function NameInArray(const AName: string; const ANames: array of string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(ANames) to High(ANames) do
    if SameText(AName, ANames[I]) then
      Exit(True);
end;

procedure GenDefaultFileLang;

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
          (string(PropInfo^.Name) <> 'Name') and
          not ((AObject is TOpenDialog) and
            (string(PropInfo^.Name) = 'DefaultExt')) and
          not ((AObject is TForm) and
            (string(PropInfo^.Name) = 'LCLVersion')) then
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
      begin
        if not (((AFormOrFrame.Name = 'frmCommandConfig') and
            NameInArray(Component.Name, ExcludesForFrameCommandConfig)) or
          ((AFormOrFrame.Name = 'frmConfig') and
            NameInArray(Component.Name, ExcludesForFormConfig))) then
          WriteToLangFile(ASectionName, Component.Name, Component);
      end
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
              if CurrentObject is TScrollingWinControl then
                CurrentObject := TScrollingWinControl(CurrentObject).
                  FindComponent(PropertyName)
              else
                CurrentObject := GetObjectProp(CurrentObject, PropertyName);
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
  MyWriteString('LangStrings', '@FileDialogExecutableFile',
    'Executable files');
  MyWriteString('LangStrings', '@FileDialogAnyFile', 'All files');
  MyWriteString('frmConfig', '@Version', 'Version:');
  MyWriteString('frmConfig', '@VersionHint',
    'Open the StartFromTray project website');
  MyWriteString('frmConfig\frmCommandConfig', '@IsRunning', 'Running');
  MyWriteString('frmConfig\frmCommandConfig', '@IsNotRunning', 'Not running');
  MyWriteString('frmConfig\frmCommandConfig', '@ErrorEmptyName',
    'Enter a name.');
  MyWriteString('frmConfig\frmCommandConfig', '@ErrorCommand',
    'Specify a command or file to run.');
  MyWriteString('frmConfig\frmCommandConfig', '@FileDialogTitle',
    'Select a file to run');
  MyWriteString('frmConfig\frmCommandConfig', '@FolderDialogTitle',
    'Select a folder to run');
  MyWriteString('frmExtensions', '@ActionForEdit', '<b>Edit</b> action');
  MyWriteString('frmExtensions', '@ActionForRun', '<b>Run</b> action');
  MyWriteString('frmExtensions', '@ChooseFileForRun',
    'Select a program for the Run action');
  MyWriteString('frmExtensions', '@ChooseFileForEdit',
    'Select a program for the Edit action');
  MyWriteString('frmExtensions', '@ErrorEmptyName', 'Enter a name.');
  MyWriteString('frmExtensions', '@ErrorEmptyExtensions',
    'Enter at least one file extension.');
end;

function LangFillListAndGetCurrent(const AMainIniFile: TIniFile;
  const AMenu: TPopupMenu; const AmiLang: TMenuItem;
  const AOnClick: TNotifyEvent): Integer;

  procedure AddSubMenuItem(const ALangName, ALangCode: string);
  var
    MenuItem: TMenuItem;
  begin
    MenuItem := TMenuItem.Create(AMenu);
    MenuItem.Caption := ALangName;
    MenuItem.Tag := PtrInt(StrNew(PChar(ALangCode)));
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
