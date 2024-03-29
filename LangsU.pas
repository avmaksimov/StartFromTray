unit LangsU;

interface

uses Vcl.Forms, System.Classes, System.Generics.Collections, Vcl.Menus, System.IniFiles;

procedure GenDefaultFileLang;
function GetLangString(const ASection, AString: string): string;
procedure SetLang(const ALangCode: string);

//get Index for AmiLang.Items with gen default LCID
function LangFillListAndGetCurrent(const AMainIniFile: TIniFile; const AMenu: TPopupMenu;
  const AmiLang: TMenuItem; const AOnClick: TNotifyEvent): Integer;
// get Index with gen default LCID

function AskForConfirmation(const AForm: TForm;
  const AConfirmation: string): Boolean;
function AskForDeletion(const AForm: TForm; const ACaption: string): Boolean;
procedure ErrorDialog(const AForm: TForm; const ACaption: string);

implementation

uses System.SysUtils, System.TypInfo,
  System.StrUtils, Vcl.StdCtrls, Vcl.Controls, Vcl.ExtCtrls, Vcl.ActnList,
  Vcl.Dialogs, System.Generics.Defaults, Winapi.Windows, System.IOUtils;

const
  cLangFolderName = 'Langs';

var
  FDefLangFile: TMemIniFile = nil;
  FLangFile   : TMemIniFile = nil;
  FLangPath   : string; // Path to Lang folder in app

const
  ExcludesForFormConfig: TArray<string> = ['btnClose', 'lblVer'];
  ExcludesForFrameCommandConfig: TArray<string> = ['gbRunAtTime',
    'lblisRun_FolderChanged', 'lblNextRun', 'cbRunAt', 'cbIsRepeatRun',
    'cbisRun_isWhenFolderChange', 'cbIsVisible', 'lblIsRunning'];

procedure LangAddDefaultStrings(const AForcedWrite: Boolean); forward;

procedure GenDefaultFileLang;
  procedure WriteToLangFile(const ASectionName: string; AIdentPrefix: string;
    AComponent: TComponent);
  var
    i, FPropCount: Integer;
    TypeData: PTypeData;
    FPropList: PPropList;
    FProp: PPropInfo;
    sDataToSave: string;
  begin
    if (AComponent is TAction) then
      Exit;

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
        if((FProp.PropType^.Kind = tkClass) and (FProp.Name <> 'FocusControl')) then
          begin
          var vComponent := TComponent(GetObjectProp(AComponent, FProp));
          if Assigned(vComponent) then
            WriteToLangFile(ASectionName, AIdentPrefix + String(FProp.Name), vComponent)
          end
        else if (FProp.PropType^.Kind = tkUString) and (FProp.Name <> 'Name') and
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
          ((AFormOrFrame.Name = 'frmConfig') and MatchStr(vComponent.Name, ExcludesForFormConfig)))
        then
          WriteToLangFile(ASectionName, vComponent.Name, vComponent);
      end
      else
        WriteComponents(ASectionName + '\' + vComponent.Name,
          vComponent as TFrame)
      end;
  end;

var
  vFileName: string;
  viForm: Integer;
  vForm: TForm;
begin
  vFileName := FLangPath + 'Default.ini';
  System.SysUtils.DeleteFile(vFileName);
  FLangFile := TMemIniFile.Create(vFileName, System.SysUtils.TEncoding.UTF8);
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
    UpdateFile;
  end; // with

  FDefLangFile := TMemIniFile.Create(TMemoryStream.Create);
  var vStringList := TStringList.Create;
  FLangFile.GetStrings(vStringList);
  FDefLangFile.SetStrings(vStringList);
end;

function GetLangString(const ASection, AString: string): string;
begin
  Result := FLangFile.ReadString(ASection, '@' + AString, '');
end;

procedure SetLang(const ALangCode: string);

  procedure ReadFromLangFile(const ASectionName, AIdentPrefix: string;
    const AFormOrFrame: TScrollingWinControl);
  begin
    var vSection := TStringList.Create;
    FLangFile.ReadSection(ASectionName, vSection);
    for var SectionIndex := 0 to vSection.Count - 1 do
      begin
      var vPropertyName: string := vSection[SectionIndex];
      if vPropertyName[1] = '@' then
        Continue; // it's not a property

      var vPropertyValue: string := FLangFile.ReadString(ASectionName, vPropertyName, '');
      if vPropertyValue = '' then
        Continue;  //default string

      var vComponent: TComponent := AFormOrFrame;
      var DelimetedPropertyNames: TArray<string> := vPropertyName.Split(['.']);

      for var TextIndex := Low(DelimetedPropertyNames) to High(DelimetedPropertyNames) do
        begin
        vPropertyName := DelimetedPropertyNames[TextIndex];
        if TextIndex <> High(DelimetedPropertyNames) then
          begin
          if not ((vComponent is TForm) or (vComponent is TFrame)) then
            try
              vComponent := TComponent(GetObjectProp(vComponent, vPropertyName))
            except
              on EPropertyError do
                break;
            end
          else
            vComponent := vComponent.FindComponent(vPropertyName);
          end
        else
          try
            SetStrProp(vComponent, vPropertyName, vPropertyValue);
          except // nothing
            end;
        end;
      end;
  end;

var
  vLangFileName: string;
  viSection: Integer;
  vSections: TStringList;
  vFormName: string;
  DelimetedSectionName: TArray<string>;
  vForm, vFrame: TComponent;
  vFrameFound: Boolean; // delimiter \ for frame
begin
  vLangFileName := FLangPath + ALangCode + '.ini';
  if not FileExists(vLangFileName) then
    raise Exception.CreateFmt('Language file "%s" is not found',
      [vLangFileName]);
  FreeAndNil(FLangFile); // prev lang ini
  FLangFile := TMemIniFile.Create(vLangFileName, System.SysUtils.TEncoding.UTF8);

  vSections := TStringList.Create;

  // Default strings
  LangAddDefaultStrings(False);
  if ALangCode.ToLower <> 'default' then
    begin
    FDefLangFile.ReadSections(vSections);
    for var i := 0 to vSections.Count - 1 do
      begin
      var vSectionName := vSections[i];
      var vSectionKeys := TStringList.Create;
      FDefLangFile.ReadSection(vSectionName, vSectionKeys);
      for var j := 0 to vSectionKeys.Count - 1 do
        begin
        var vSectionKey := vSectionKeys[j];
        if not FLangFile.ValueExists(vSectionName, vSectionKey) then
          FLangFile.WriteString(vSectionName, vSectionKey,
            FDefLangFile.ReadString(vSectionName, vSectionKey, ''));
        end;

      end;
    end;

  with FLangFile do
    begin
    ReadSections(vSections);
    for viSection := 0 to vSections.Count - 1 do
      begin
      var vSectionName := vSections[viSection];
      if (vSectionName <> 'LangStrings') and (vSectionName <> 'LangProperties') then
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
    if Modified then
      UpdateFile;
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
  MyWriteString('LangStrings', '@Cancel', 'Cancel');
  MyWriteString('LangStrings', '@Close', 'Close');
  MyWriteString('LangStrings', '@DeleteConfirm',
    'Are you sure to delete "%s"?');
  MyWriteString('LangStrings', '@CancelConfirm',
    'Are you sure to cancel changes?');
  MyWriteString('LangStrings', '@FileDialogExecutableFile', 'Executable file');
  MyWriteString('LangStrings', '@FileDialogAnyFile', 'Any file');
  MyWriteString('frmConfig', '@Version', 'Version:');
  MyWriteString('frmConfig', '@VersionHint', 'Open the StartFromTray project website');
  MyWriteString('frmConfig\frmCommandConfig', '@IsRunning', 'Running');
  MyWriteString('frmConfig\frmCommandConfig', '@IsNotRunning', 'Not running');
  MyWriteString('frmConfig\frmCommandConfig', '@ErrorEmptyName', 'Empty name. You have to write one');
  MyWriteString('frmConfig\frmCommandConfig', '@ErrorCommand', 'Empty command (file to run). You have to write it');
  MyWriteString('frmConfig\frmCommandConfig', '@FileDialogTitle', 'Browsing file to run');
  MyWriteString('frmConfig\frmCommandConfig', '@FolderDialogTitle', 'Browsing folder to run');
  MyWriteString('frmExtensions', '@ActionForEdit', 'Action for <b>Edit</b>');
  MyWriteString('frmExtensions', '@ActionForRun', 'Action for <b>Run</b>');
  MyWriteString('frmExtensions', '@ChooseFileForRun',
    'Choose file for Run action');
  MyWriteString('frmExtensions', '@ChooseFileForEdit',
    'Choose file for Edit action');
  MyWriteString('frmExtensions', '@ErrorEmptyName',
    'Empty name. You have to write one');
  MyWriteString('frmExtensions', '@ErrorEmptyExtensions',
    'Empty extensions. You need at least one.');
end;

function LangFillListAndGetCurrent(const AMainIniFile: TIniFile; const AMenu: TPopupMenu;
  const AmiLang: TMenuItem; const AOnClick: TNotifyEvent): Integer;
  procedure AddSubMenuItem(const ALangName, ALangCode: string);
  begin
  var vMenuItem := TMenuItem.Create(AMenu);
  with vMenuItem do
    begin
    Caption := ALangName;
    Tag := Integer(StrNew(PChar(ALangCode)));
    RadioItem := True;
    OnClick := AOnClick;
    end;
  AmiLang.Add(vMenuItem);
  end;
begin
  Result := 0; // LCID for user not found
  var vUserDefaultLCID := GetUserDefaultUILanguage(); // GetUserDefaultLCID();

  var vCurrentIniLangCode: string := AMainIniFile.ReadString('Main', 'LangCode', '');

  AddSubMenuItem('Default - English', 'Default');

  var vCurrentItemIndexForIniLang: Integer;
  if vCurrentIniLangCode = 'Default' then
    vCurrentItemIndexForIniLang := 0
  else
    vCurrentItemIndexForIniLang := -1;

  var vCurrentItemIndexForLCID: Integer;
  if StrToUIntDef(GetLangString('LangProperties', 'LCID'), 0) = vUserDefaultLCID
  then
    vCurrentItemIndexForLCID := 0
  else
    vCurrentItemIndexForLCID := -1;

  var vSR: TSearchRec; var vCurrentItemIndex: Integer := 1;
  if FindFirst(FLangPath + '???.ini', faNormal, vSR) = 0 then
  begin
    repeat
      var sLangCode := TPath.GetFileNameWithoutExtension(vSR.Name);
      with TMemIniFile.Create(FLangPath + vSR.Name, System.SysUtils.TEncoding.UTF8) do
        try
          var sLangCaption := ReadString('LangProperties', '@Name', '');
          if sLangCaption <> '' then
          begin
            if (vCurrentItemIndexForLCID = -1) and
              (LCID(ReadInteger('LangProperties', '@LCID', 0)) = vUserDefaultLCID) then
              vCurrentItemIndexForLCID := vCurrentItemIndex;
            if (vCurrentItemIndexForIniLang = -1) and
              (sLangCode = vCurrentIniLangCode) then
              vCurrentItemIndexForIniLang := vCurrentItemIndex;
            AddSubMenuItem(sLangCaption, sLangCode);
          end;
        finally
          Free;
        end;
      vCurrentItemIndex := vCurrentItemIndex + 1;
    until (FindNext(vSR) <> 0);
    System.SysUtils.FindClose(vSR);
  end;
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
begin
  Result := AskForConfirmation(AForm,
    Format(GetLangString('LangStrings', 'DeleteConfirm'), [ACaption]));
end;

procedure ErrorDialog(const AForm: TForm; const ACaption: string);
begin
  MessageBoxEx(AForm.Handle, PChar(ACaption),
    PChar(AForm.Caption), MB_ICONERROR, StrToIntDef(GetLangString('LangProperties', 'LCID'), 0))
end;

initialization

FLangPath := ExtractFilePath(ParamStr(0)) + cLangFolderName + '\';

end.
