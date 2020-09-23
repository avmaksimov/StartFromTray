unit LangsU;

interface

uses Vcl.Forms, System.Classes, System.Generics.Collections;

// ASaveAndExit - true, if it's called by the param and we have to save to Default.ini
// otherwise - only to use in the app
procedure GenDefaultFileLang { (const ASaveAndExit: Boolean) };
function GetLangString(const ASection, AString: string): string;
procedure SetLang(const ALangCode: string);

// get Index with gen default LCID
function LangFillListAndGetCurrent(const AStringList: TStrings): Integer;

function AskForConfirmation(const AForm: TForm;
  const AConfirmation: string): Boolean;
function AskForDeletion(const AForm: TForm; const ACaption: string): Boolean;
// (const AFormHandle: THandle; const ACaption, AFormCaption: string): Boolean;

// var LangStrings: TStringList;

// type TLangStrings = TDictionary <string, string>;

// var LangStrings: TLangStrings;

implementation

uses System.SysUtils, System.IniFiles, System.TypInfo,
  System.StrUtils, Vcl.StdCtrls, Vcl.Controls, Vcl.ExtCtrls, Vcl.ActnList,
  Vcl.Menus, Vcl.Dialogs, System.Generics.Defaults, Winapi.Windows,
  System.IOUtils;

const
  cLangFolderName = 'Langs';

var
  FLangFile: TMemIniFile = nil;
  FLangPath: string; // Path to Lang folder in app

  // const cLangStrings: array of string = ('OK', 'Apply', 'Close', 'Cancel',
  // 'Up', 'Down', 'Add', 'Add child', 'Delete', 'Copy');

const
  ExcludesForFrameCommandConfig: TArray<string> = ['gbRunAtTime',
    'lblisRun_FolderChanged', 'lblNextRun', 'cbRunAt', 'cbIsRepeatRun',
    'cbisRun_isWhenFolderChange', 'cbIsVisible', 'lblIsRunning'];
  // var vMemIniFile: TMemIniFile;

procedure LangAddDefaultStrings(const AForcedWrite: Boolean); forward;

// ASaveAndExit - true, if it's called by the param and we have to save to Default.ini
// otherwise - only to use in the app
procedure GenDefaultFileLang { (const ASaveAndExit: Boolean) };
  procedure WriteToLangFile(const ASectionName: string; AIdentPrefix: string;
    AComponent: TComponent);
  var
    i, FPropCount: Integer;
    TypeData: PTypeData;
    FPropList: PPropList;
    FProp: PPropInfo;
    sDataToSave: string;
  begin
    if { (AComponent is TFrame) or } (AComponent is TAction) then
      Exit;
    if AComponent is TLabeledEdit then
      AComponent := TLabeledEdit(AComponent).EditLabel;

    if AIdentPrefix <> '' then
      AIdentPrefix := AIdentPrefix + '.';

    TypeData := GetTypeData(AComponent.ClassInfo);
    FPropCount := TypeData.PropCount;
    GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
    try
      GetPropInfos(AComponent.ClassInfo, FPropList);
      for i := 0 to FPropCount - 1 do
      begin
        FProp := FPropList[i];
        if (FProp.PropType^.Kind = tkUString) and (FProp.Name <> 'Name') and
          not((AComponent is TFileOpenDialog) and
          (FProp.Name = 'DefaultExtension')) then
        begin
          sDataToSave := GetStrProp(AComponent, FProp);
          if (sDataToSave <> '') and
            not((AComponent is TMenuItem) and (FProp.Name = 'Caption') and
            (sDataToSave = '-')) then
            FLangFile.WriteString(ASectionName,
              AIdentPrefix + String(FProp.Name), sDataToSave);
        end;
      end; // for i .. FPropCount-1
    finally
      FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
    end;
  end;

  procedure WriteComponents(const ASectionName: string;
    AFormOrFrame: TScrollingWinControl);
  var
    viCompoment: Integer;
    vComponent: TComponent;
  begin
    for viCompoment := 0 to AFormOrFrame.ComponentCount - 1 do
    begin
      vComponent := AFormOrFrame.Components[viCompoment];
      if not(vComponent is TFrame) then
      begin // now only hardcode
        if not(((AFormOrFrame.Name = 'frmCommandConfig') and
          MatchStr(vComponent.Name, ExcludesForFrameCommandConfig)) or
          ((AFormOrFrame.Name = 'frmConfig') and (vComponent.Name = 'btnClose')))
        then
          WriteToLangFile(ASectionName, vComponent.Name, vComponent);
      end
      else
        WriteComponents(ASectionName + '\' + vComponent.Name,
          vComponent as TFrame)
        // WriteToLangFile(vComponent.Name, vComponent.Name, vComponent)
    end;
  end;

var
  vFileName: string;
  viForm: Integer;
  vForm: TForm; // vKey: string;
  // vLangStringKeys: TArray<string>;
begin
  vFileName := { ExtractFilePath(ParamStr(0)) + cLangFolderName } FLangPath +
    'Default.ini';
  FLangFile := TMemIniFile.Create(vFileName);
  with FLangFile do
  begin
    WriteString('LangProperties', '@LCID', '1033');
    WriteString('LangProperties', '@Name', 'English - United States');
    LangAddDefaultStrings(True);
    for viForm := 0 to Screen.FormCount - 1 do
    begin
      vForm := Screen.Forms[viForm];
      WriteToLangFile(vForm.Name, '', vForm);
      WriteComponents(vForm.Name, vForm);
    end;
    DeleteFile(PChar(vFileName));
    UpdateFile;
    // Free; // after it we Exit the App
  end; // with
end;

function GetLangString(const ASection, AString: string): string;
begin
  Result := FLangFile.ReadString(ASection, '@' + AString, '');
end;

procedure SetLang(const ALangCode: string);

// var vIniFile: TMemIniFile;
  procedure SetComponentPropertyFromIni(const AFormName: String;
    const AControl: TComponent; const APropertyName, APropertyIdent: string);
  var
    vPropertyValue: string;
  begin
    vPropertyValue := FLangFile.ReadString(AFormName, APropertyIdent, '');
    if vPropertyValue <> '' then
    begin
      SetStrProp(AControl, APropertyName, vPropertyValue);
    end;

  end;

  procedure ReadFromLangFile(const ASectionName, AIdentPrefix: string;
    const AFormOrFrame: TScrollingWinControl);
  var
    vPropertyName, vPropertyValue: string;
    vSection: TStringList;
    i: Integer;
    vComponentName: string;
    vComponent: TComponent;
    DelimetedPropertyName: TArray<string>;
  begin
    vSection := TStringList.Create;
    FLangFile.ReadSection(ASectionName, vSection);
    for i := 0 to vSection.Count - 1 do
    begin
      vPropertyName := vSection[i];
      if vPropertyName[1] = '@' then
        Continue; // it's not a property

      vPropertyValue := FLangFile.ReadString(ASectionName, vPropertyName, '');
      if vPropertyValue = '' then
        Continue;

      DelimetedPropertyName := vPropertyName.Split(['.'], 2);

      // viDelimiter := Pos('.', vPropertyName);
      if Length(DelimetedPropertyName) = 2 { viDelimiter > 0 } then
      // there is a point, so it's component with propery
      begin
        vComponentName := DelimetedPropertyName[0];
        // LeftStr(vPropertyName, viDelimiter - 1);
        vComponent := AFormOrFrame.FindComponent(vComponentName);
        if not Assigned(vComponent) then
          Continue;
        if vComponent is TLabeledEdit then
          vComponent := TLabeledEdit(vComponent).EditLabel;
        vPropertyName := DelimetedPropertyName[1];
        // Copy(vPropertyName, viDelimiter + 1, Length(vPropertyName))
      end
      else // form's or frame's properties
      begin
        vComponent := AFormOrFrame; // vPropertyName is the same
      end;

      try
        SetStrProp(vComponent, vPropertyName, vPropertyValue);
      except // nothing
      end;
    end;
  end;

var
  vLangFileName: string;
  viSection: Integer;
  vSections: TStringList;
  vSectionName, vFormName { , vFrameName } : string;
  DelimetedSectionName: TArray<string>;
  vForm, vFrame: TComponent;
  vFrameFound: Boolean; // delimiter \ for frame
  // vLangStringKeys: TStringList; vLangStringKey: string;
begin
  vLangFileName := { ExtractFilePath(ParamStr(0)) + cLangFolderName + '\' }
    FLangPath + ALangCode + '.ini';
  if not FileExists(vLangFileName) then
    raise Exception.CreateFmt('Language file "%s" is not found',
      [vLangFileName]);
  FreeAndNil(FLangFile); // prev lang ini
  FLangFile := TMemIniFile.Create(vLangFileName);
  vSections := TStringList.Create;
  with FLangFile do
  begin
    // try
    LangAddDefaultStrings(False); // Default strings
    ReadSections(vSections);
    for viSection := 0 to vSections.Count - 1 do
    begin
      vSectionName := vSections[viSection];
      if (vSectionName <> 'LangStrings') and (vSectionName <> 'LangProperties')
      then
      begin
        DelimetedSectionName := vSectionName.Split(['\'], 2);

        vFrameFound := Length(DelimetedSectionName) = 2;
        vFormName := DelimetedSectionName[0];

        vForm := Application.FindComponent(vFormName);
        if not Assigned(vForm) then
          Continue;

        if not vFrameFound then
          ReadFromLangFile(vFormName, '', vForm as TForm)
        else // must be frame
        begin
          vFrame := (vForm as TForm).FindComponent(DelimetedSectionName[1]);
          if not Assigned(vFrame) or not(vFrame is TFrame) then
            Continue;

          ReadFromLangFile(vSectionName, '', vFrame as TFrame)
        end;
      end;
    end;
  end;
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      WriteString('Main', 'LangCode', ALangCode);
    finally
      Free;
    end;
end;

// Add default strings. AForcedWrite - without check (for the first time in the app)
procedure LangAddDefaultStrings(const AForcedWrite: Boolean);
  procedure MyWriteString(const ASection, AIdent, AValue: string);
  begin
    if AForcedWrite or not FLangFile.ValueExists(ASection, AIdent) then
      FLangFile.WriteString(ASection, AIdent, AValue);
  end;

begin
  // with FLangFile do
  // begin
  MyWriteString('LangStrings', '@Cancel', 'Cancel');
  MyWriteString('LangStrings', '@Close', 'Close');
  MyWriteString('LangStrings', '@DeleteConfirm',
    'Are you sure to delete "%s"?');
  MyWriteString('LangStrings', '@CancelConfirm',
    'Are you sure to cancel changes?');
  MyWriteString('LangStrings', '@FileDialogExecutableFile', 'Executable file');
  MyWriteString('LangStrings', '@FileDialogAnyFile', 'Any file');
  MyWriteString('frmConfig\frmCommandConfig', '@IsRunning', 'Running');
  MyWriteString('frmConfig\frmCommandConfig', '@IsNotRunning', 'Not running');
  MyWriteString('frmExtensions', '@ChooseFileForRun',
    'Choose file for Run action');
  MyWriteString('frmExtensions', '@ChooseFileForEdit',
    'Choose file for Edit action');
  // end;
end;

function LangFillListAndGetCurrent(const AStringList: TStrings): Integer;
var
  vSR: TSearchRec; { vIni: TIniFile; }
  sLangCode, sLangCaption: string;
  vUserDefaultLCID: LCID;
  vCurrentItemIndex, vCurrentItemIndexForLCID,
    vCurrentItemIndexForIniLang: Integer;
  vCurrentIniLangCode: string;
begin
  Result := 0; // LCID for user not found
  vUserDefaultLCID := GetUserDefaultUILanguage(); // GetUserDefaultLCID();
  // ShowMessage(UIntToStr(vUserDefaultLCID) + #13#10 + UIntToStr(GetUserDefaultLCID()));

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      vCurrentIniLangCode := ReadString('Main', 'LangCode', '');
    finally
      Free;
    end;

  AStringList.AddObject('Default - English', TObject(StrNew(PChar('Default'))));
  vCurrentItemIndex := 1;
  // vCurrentItemIndexForLCID := 0;
  // vCurrentItemIndexForIniLang := 0;

  if vCurrentIniLangCode = 'Default' then
    vCurrentItemIndexForIniLang := 0
  else
    vCurrentItemIndexForIniLang := -1;

  if StrToUIntDef(GetLangString('LangProperties', 'LCID'), 0) = vUserDefaultLCID
  then
    vCurrentItemIndexForLCID := 0
  else
    vCurrentItemIndexForLCID := -1;
  // ShowMessageFmt('vCurrentItemIndexForIniLang: %d; vCurrentItemIndexForLCID: %d',
  // [vCurrentItemIndexForIniLang, vCurrentItemIndexForLCID]);
  if FindFirst(FLangPath + '???.ini', faNormal, vSR) = 0 then
  begin
    repeat
      sLangCode := TPath.GetFileNameWithoutExtension(vSR.Name);
      with TIniFile.Create(FLangPath + vSR.Name) do
        try
          // ShowMessage(IntToStr(LCID(ReadInteger('LangProperties', '@LCID', 0))) + #13#10 + vCurrentItemIndex.ToString);
          sLangCaption := ReadString('LangProperties', '@Name', '');
          if sLangCaption <> '' then
          begin
            if (vCurrentItemIndexForLCID = -1) and
              (LCID(ReadInteger('LangProperties', '@LCID', 0))
              = vUserDefaultLCID) then
              vCurrentItemIndexForLCID := vCurrentItemIndex;
            if (vCurrentItemIndexForIniLang = -1) and
              (sLangCode = vCurrentIniLangCode) then
              vCurrentItemIndexForIniLang := vCurrentItemIndex;
            AStringList.AddObject(sLangCaption,
              TObject(StrNew(PChar(sLangCode))));
          end;
        finally
          Free;
        end;
      vCurrentItemIndex := vCurrentItemIndex + 1;
    until (FindNext(vSR) <> 0);
    System.SysUtils.FindClose(vSR);
  end;
  // ShowMessageFmt('vCurrentItemIndexForIniLang: %d; vCurrentItemIndexForLCID: %d',
  // [vCurrentItemIndexForIniLang, vCurrentItemIndexForLCID]);
  // choose the best match
  if vCurrentItemIndexForIniLang >= 0 then
    Result := vCurrentItemIndexForIniLang
  else if vCurrentItemIndexForLCID >= 0 then
    Result := vCurrentItemIndexForLCID;
end;

function AskForConfirmation(const AForm: TForm;
  const AConfirmation: string): Boolean;
begin
  Result := MessageBoxEx(AForm.Handle, PChar(AConfirmation),
    PChar(AForm.Caption), MB_ICONWARNING or MB_YESNO or MB_DEFBUTTON2,
    StrToIntDef(GetLangString('LangProperties', 'LCID'), 0)) = mrYes;
end;

function AskForDeletion(const AForm: TForm; const ACaption: string): Boolean;
// (const AFormHandle: THandle; const ACaption, AFormCaption: string): Boolean;
begin
  Result := AskForConfirmation(AForm,
    Format(GetLangString('LangStrings', 'DeleteConfirm'), [ACaption]));
  { Result := MessageBoxEx(AForm.Handle, PChar(Format(GetLangString('LangStrings', 'DeleteConfirm'),
    [ACaption])), PChar(AForm.Caption), MB_ICONWARNING or MB_YESNO or MB_DEFBUTTON2,
    StrToIntDef(GetLangString('LangProperties', 'LCID'), 0)) = mrYes; }
end;

initialization

FLangPath := ExtractFilePath(ParamStr(0)) + cLangFolderName + '\';

end.
