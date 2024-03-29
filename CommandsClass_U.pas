﻿unit CommandsClass_U;

interface

uses
  SysUtils, ShellApi, Dialogs, contnrs, ComCtrls, XMLDoc, XMLIntf, Windows,
  Variants, System.TypInfo, Winapi.ShlObj, Winapi.ShLwApi,
  DateUtils, Types, FilterClass_U, ComObj, ActiveX, System.UITypes,
  System.Classes;

type
  TCommandRunType = (crtNormalRun, crtEdit); // crtByTimeRun
  TCommandIconType = (citDefault, citFromFileRes, citFromFileExt);

  TCmdWaitForRunningThread = class;

  { TCommandData }

  TCommandList = TObjectList;

  // директива для работы с RTTI
{$M+}
  TCommandData = class
  private
    FisGroup: boolean;
    Fcommand: String; // команда для выполнения
    FisRunning: boolean; // сейчас команда запущена

    FChilds: TCommandList;

    FCommandParameters: string;

    FWaitForRunningThread: TCmdWaitForRunningThread;

    FIconFilename: string;  // ='' when default
    FIconFileIndex: Integer;
    FIconType: TCommandIconType;
    FIconExt: string;
    FIsRunAsAdmin: Boolean;

    // just RunCommand
    {function InternalRun(const AHelper: string; const ADefaultOperation: PChar;
      const RunType: TCommandRunType; const IsRunAsAdmin: Boolean): THandle;}
    function InternalRun(const AHelper: string; const AHelperParams: string; const RunType: TCommandRunType): THandle;

  public
    constructor Create; overload;
    //constructor Create(const NodeAttributes: IXMLNode); overload;

    destructor Destroy; override;

    // edit
    procedure Edit;
    // запуск
    procedure Run(const RunType: TCommandRunType);

    procedure Assign(Dest: TCommandData);
    procedure AssignFrom(SrcNode: IXMLNode);
    procedure AssignTo(DestNode: IXMLNode; const ACaption: String);
    // If Command exists than return it else check in Path and result Fullname
    // from Path or return '' if not found
    function ExtendCommandToFullName: string;
    function GetImageIndex(const AImageListHandle: Integer): Integer;
    // real property
    property isRunning: boolean read FisRunning write FisRunning;
  published // all this properties saves in xmls

    //property Name: string read FName write FName;
    //property isVisible: boolean read FisVisible write FisVisible;
    property isGroup: boolean read FisGroup write FisGroup default False;
    property Childs: TCommandList read FChilds;
    property Command: string read Fcommand write Fcommand;
    property CommandParameters: string read FCommandParameters
      write FCommandParameters;
    property IsRunAsAdmin: Boolean read FIsRunAsAdmin write FIsRunAsAdmin default False;
    property IconType: TCommandIconType read FIconType write FIconType default citDefault;
    property IconFilename: string read FIconFilename write FIconFilename;
    property IconFileIndex: Integer read FIconFileIndex write FIconFileIndex default -1;
    property IconExt: string read FIconExt write FIconExt;
  end;
{$M-}
  { TCommandWaitForRunningThread }

  TCmdWaitForRunningThread = class(TThread)
  private
    FProcessHandle: THandle;
    Fcommand: TCommandData;
  protected
    procedure Execute; override;
  public
    constructor Create(const AProcessHandle: THandle; Command: TCommandData);
  end;

procedure TreeToXML(ATreeNodes: TTreeNodes);

// получение значения свойства из атрибута (обход nil)
function GetPropertyFromNodeAttributes(const NodeAttributes: IXMLNode;
  const sProperty: String): string;

implementation

uses CommonU, Winapi.CommCtrl, System.Win.Registry;

procedure TreeToXML(ATreeNodes: TTreeNodes);
var
  tn: TTreeNode;
  XMLDoc: IXMLDocument;
  Node: IXMLNode;

  procedure ProcessTreeItem(atn: TTreeNode; aNode: IXMLNode);
  var
    cNode: IXMLNode;
    vCommonData: TCommandData;
  begin
    // такая проверка все равно есть перед заходом в рекурсию
    cNode := aNode.AddChild('item');

    vCommonData := TCommandData(atn.Data);
    // vCommonData.CalcNextRunAtDateTime;

    // showmessage(atn.Text);
    vCommonData.AssignTo(cNode, atn.Text);

    // child nodes
    atn := atn.GetFirstChild;
    while atn <> nil do
    begin
      ProcessTreeItem(atn, cNode);
      atn := atn.getNextSibling;
    end;
  end; (* ProcessTreeItem *)

var
  vFilename, vFilenameNew: string;
begin
  XMLDoc := TXMLDocument.Create(nil);
  // XMLDoc.Encoding := 'UTF-8';
  XMLDoc.Active := True;
  XMLDoc.Options := XMLDoc.Options + [doNodeAutoIndent];

  Node := XMLDoc.AddChild('tree2xml');
  Node.Attributes['name'] := 'tvItems';

  tn := ATreeNodes.GetFirstNode; // TopNode;
  while tn <> nil do
  begin
    ProcessTreeItem(tn, Node);

    tn := tn.getNextSibling;
  end;

  vFilename := ExtractFilePath(ParamStr(0)) + cItemsFileName;
  vFilenameNew := ExtractFilePath(ParamStr(0)) + 'new-' + cItemsFileName;

  XMLDoc.SaveToFile(vFilenameNew);
  if FileExists(vFilename) then
    if not DeleteFile(PChar(vFilename)) then
      RaiseLastOSError;
  if not RenameFile(vFilenameNew, vFilename) then
    RaiseLastOSError;
end; // TreeToXML

// получение значения свойства из атрибута (обход nil)
function GetPropertyFromNodeAttributes(const NodeAttributes: IXMLNode;
  const sProperty: String): string;
var
  Res: OleVariant;
begin
  Res := (NodeAttributes.Attributes[sProperty]);

  if not VarIsNull(Res) then
    Result := Res
  else
    Result := '';
end;

{ TCommandData }

constructor TCommandData.Create;
begin
  inherited Create;

  FisGroup := false; // признак группы
  Fcommand := ''; // команда для выполнения
  FCommandParameters := ''; // параметр команды для выполнения
  FIconType := citDefault; // by Default
  FIconFilename := '';
  FIconFileIndex := -1;
  FIconExt := '';

  FWaitForRunningThread := nil;

  // real properties
  FisRunning := false;
end;

destructor TCommandData.Destroy;
begin
  if FWaitForRunningThread <> nil then
    FWaitForRunningThread.Terminate;
end;

function TCommandData.InternalRun(const AHelper: string; const AHelperParams: string; const RunType: TCommandRunType): THandle;
const
  strCommandRunType: array [TCommandRunType] of string = ('Normal Run', 'Edit');

  cHelperParamForCommand = ':(command)';
begin
  Result := 0;

  //CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE);
  var vFilename, vParameters: string;
  if AHelper = '' then
    begin
    vFilename := Fcommand;
    vParameters := FCommandParameters;
    end
  else
    begin
    vFilename := AHelper; //'"' + AHelper + '"';
    //var vHelperParams: string := '';
    if AHelperParams.Contains(cHelperParamForCommand) then
      vParameters := AHelperParams.Replace(cHelperParamForCommand, Fcommand)
    else
      vParameters := AHelperParams + ' "' + Fcommand + '"';
    vParameters := vParameters + ' ' + FCommandParameters;
    //vParameters := '"' + Fcommand + '"' + FCommandParameters;
    end;

  var vOperation: PChar;
  if not IsRunAsAdmin then
    vOperation := nil
  else
    vOperation := PChar('runas');

  var SEInfo: TShellExecuteInfo;
  FillChar(SEInfo, SizeOf(SEInfo), 0);
  with SEInfo do
    begin
    cbSize := SizeOf(TShellExecuteInfo);
    lpVerb := vOperation;
    lpFile := PChar(vFilename);
    lpParameters := PChar(vParameters);
    lpDirectory := PChar(ExtractFilePath(Fcommand));
    nShow := SW_SHOWNORMAL;
    if RunType <> crtEdit then
      fMask := SEE_MASK_NOCLOSEPROCESS;
    end;

   var sTechMsg: string;
   if gDebug then
      begin
      sTechMsg := 'InternalRun: ' +
          strCommandRunType[RunType] + LineFeed;
      if vOperation = nil then
        sTechMsg := sTechMsg + 'nil'
      else
        sTechMsg := sTechMsg + vOperation;
      sTechMsg := sTechMsg + '; ' + vFilename + '; ';
      if vParameters = '' then
        sTechMsg := sTechMsg + '<empty string>'
      else
        sTechMsg := sTechMsg + vParameters;
      MessageDlg(sTechMsg, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);
      end;

  if ShellExecuteEx(@SEInfo) then
    Result := SEInfo.hProcess
  else if gDebug then
    begin
    var vGetLastError: Cardinal := GetLastError;
    if vGetLastError <> ERROR_NO_ASSOCIATION then  // avoid double error messages
      begin
      M_Error('Error with ' + ': ' +
        SysErrorMessage(vGetLastError) + LineFeed + 'Error code: ' +
        IntToStr(vGetLastError) + LineFeed + 'TechErrorMsg: ' +
          sTechMsg);
      end;
    end;
end;

procedure TCommandData.Edit;
  function OpenFolderAndSelectFile(const FileName: string): boolean;
  var
    IIDL: PItemIDList;
  begin
    Result := false;
    IIDL := ILCreateFromPath(PChar(FileName));
    if IIDL <> nil then
      try
        Result := SHOpenFolderAndSelectItems(IIDL, 0, nil, 0) = S_OK;
      finally
        ILFree(IIDL);
      end;
  end;
  function GetAssociatedExeForEdit(const vFilename: string): string;
  var
    pResult: PChar;
    pResultSize: DWORD;
  begin
    Result := '';
    pResultSize := 255;
    pResult := StrAlloc(MAX_PATH);
    try
      if AssocQueryString(0, ASSOCSTR_EXECUTABLE, PChar(vFilename), 'edit',
        pResult, @pResultSize) = S_OK then
          Result := pResult;
    finally
      StrDispose(pResult);
    end;
  end;

begin
  if Fcommand <> '' then
  begin
    var vFilterData := Filters_GetFilterByFilename(Fcommand);
    var editHelper: string := '';
    var editParams: string := '';
    if Assigned(vFilterData) then
      begin
      editHelper := vFilterData.Edit;
      editParams := vFilterData.EditParams;
      end;
    // if empty edit helper
    if editHelper = '' then
      begin
      editHelper := GetAssociatedExeForEdit(Fcommand);
      editParams := '';
      end;
    if editHelper <> '' then
      InternalRun(editHelper, editParams, crtEdit)
    else
      OpenFolderAndSelectFile(Fcommand);
  end;
end;

procedure TCommandData.Run(const RunType: TCommandRunType);
begin
  if (Fcommand <> '') and not FisRunning then
  begin
    var vFilterData := Filters_GetFilterByFilename(Fcommand);
    var runHelper: string;
    var runParams: string;
    if Assigned(vFilterData) then
      begin
      runHelper := vFilterData.Run;
      runParams := vFilterData.RunParams;
      end;
    // if empty run helper
    if runHelper = '' then
      begin
      runHelper := '';
      runParams := '';
      end;

    var ProcessHandle := InternalRun(runHelper, runParams, RunType);
    if ProcessHandle <> 0 then
      begin
      isRunning := True;
      FWaitForRunningThread := TCmdWaitForRunningThread.Create
        (ProcessHandle, Self);
      end;
  end;
end;

// If Command exists than return it else check in Path and result Fullname
// from Path or return '' if not found
function TCommandData.ExtendCommandToFullName: string;
begin
  //directory must be absolute path
  if DirectoryExists(Command) and not IsRelativePath(Command) then
    begin
    Exit(Command);
    end;
  Result := '';
  // todo: extractfilename for Command?
  if(ExtractFileExt(Command).ToLower = '.exe') then
    begin
      var reg: TRegistry := TRegistry.Create(KEY_READ);
      try
        var vRootKey: HKEY;
        for vRootKey in [HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE] do
          begin
            reg.RootKey := vRootKey;
            var vKeyPath: string := '\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\' + Command;
            if Reg.OpenKeyReadOnly(vKeyPath) then
              begin
                case Reg.GetDataType('') of
                  rdString:
                    Result := Reg.ReadString('');
                  rdExpandString:
                    Result := MyExpandEnvironmentStrings(Reg.ReadString(''));
                end;
              end;
          if Result <> '' then
            Exit(Result);
          end;
      finally
        reg.Free;
      end;
    end;
  if Result = '' then
    Result := FileSearch(Command, GetEnvironmentVariable('PATH'));
end;

// now AFileName can be not full and be in Path
// Result: 0 or valid hIcon
function TCommandData.GetImageIndex(const AImageListHandle: Integer): Integer;
begin
var vHIcon: HIcon := 0;
if IconType in [citDefault, citFromFileExt] then
  begin
  var vFileForIcon: string;
  // must be zero only for directory with full path because if it's relative may it's not a folder)).
  var vMask: Cardinal := SHGFI_USEFILEATTRIBUTES;
  if IconType = citDefault then
    begin
    if isGroup then
      Exit(0); // already created for group and Default IconType

    if not DirectoryExists(Command) or IsRelativePath(Command) then
      begin
      var vExt := ExtractFileExt(Command);
      if (vExt <> '') and (vExt <> '.') then
        begin
        vExt := vExt.ToLower;
        if (vExt = '.exe') or (vExt = '.dll') or (vExt = '.ico') then
          begin
          vFileForIcon := ExtendCommandToFullName;
          if vFileForIcon = '' then
            vFileForIcon := vExt; // not found - so default
          end
        else // common document - enough only Ext
          vFileForIcon := vExt;
        end
      else
        vFileForIcon := Command;
      end
    else
      begin
      vFileForIcon := Command;
      vMask := SHGFI_SYSICONINDEX;
      end;
    end  // IconType = citDefault
  else //citFromFileExt
    vFileForIcon := '.' + IconExt;
  // IconType in [citDefault, citFromFileExt]
  var Info: TSHFileInfo;
  ZeroMemory(@Info, SizeOf(Info));
  Result := SHGetFileInfo(PChar(vFileForIcon), FILE_ATTRIBUTE_NORMAL, Info,
    SizeOf(TSHFileInfo), {SHGFI_USEFILEATTRIBUTES} vMask or SHGFI_SMALLICON or SHGFI_ICON or SHGFI_OPENICON);
  If Result <> 0 then
    begin
    if vMask <> SHGFI_SYSICONINDEX then
      vHIcon := Info.HIcon
    else
      begin
      DestroyIcon(Info.HIcon);
      vHIcon := ImageList_GetIcon(Result, Info.iIcon, ILD_NORMAL);
      end;
    end;
  end //IconType in [citDefault, citFromFileExt]
else //citFromFileRes
  begin
  var vLargeIcon: hIcon := 0;
  var vSmallIcon: HIcon := 1; // non zero
  if ExtractIconEx(PChar(IconFilename), IconFileIndex, vLargeIcon, vSmallIcon, 1) > 0 then
    vHIcon := vSmallIcon;
  end;
if vHIcon > 0 then
  begin
  Result := ImageList_ReplaceIcon(AImageListHandle, -1, vHIcon);
  DestroyIcon(vHIcon);
  end
else
  Result := -1;
end;

procedure TCommandData.Assign(Dest: TCommandData);
var
  i, FPropCount: integer;
  TypeData: PTypeData;
  FPropList: PPropList;
  FProp: PPropInfo;
begin
  TypeData := GetTypeData(ClassInfo);
  FPropCount := TypeData.PropCount;

  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for i := 0 to FPropCount - 1 do
    begin
      FProp := FPropList[i];

      case FProp.PropType^.Kind of
        tkUString:
          SetStrProp(Dest, FProp, GetStrProp(Self, FProp));
        tkEnumeration, tkInteger:
          SetOrdProp(Dest, FProp, GetOrdProp(Self, FProp));
        tkFloat:
          SetFloatProp(Dest, FProp, GetFloatProp(Self, FProp));
        { else
          begin
          Raise EInvalidCast.Create('TCommandData.Assign: неожиданный тип ' + FProp.PropType^.Name + ' для свойства: ' + FProp.Name);
          end; }
      end; // case
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;
end;

procedure TCommandData.AssignFrom(SrcNode: IXMLNode);
var
  FPropList: PPropList;
  FProp: PPropInfo;
begin
  var FPropCount := GetTypeData(ClassInfo).PropCount;
  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for var i := 0 to FPropCount - 1 do
    begin
      FProp := FPropList[i];

      var sDataToLoad := GetPropertyFromNodeAttributes(SrcNode,
        string(FProp.Name));

      if sDataToLoad = '' then
        Continue;

      case FProp.PropType^.Kind of
        tkUString:
          SetStrProp(Self, FProp, sDataToLoad);
        tkEnumeration, tkInteger:
          SetOrdProp(Self, FProp, System.SysUtils.StrToInt(sDataToLoad));
        tkFloat:
          begin
            var sDataType := FProp.PropType^.Name;
            if sDataType = 'TDateTime' then
              SetFloatProp(Self, FProp, StrToDateTime(sDataToLoad))
            else if sDataType = 'TTime' then
              SetFloatProp(Self, FProp, StrToTime(sDataToLoad))
          end;
      end; // case
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;
end;

procedure TCommandData.AssignTo(DestNode: IXMLNode; const ACaption: String);
var
  i, FPropCount: integer;
  TypeData: PTypeData;
  FPropList: PPropList;
  FProp: PPropInfo;
  sDataToSave: string;
  sDataType: TSymbolName;
begin
  DestNode.SetAttribute('Caption', ACaption);

  TypeData := GetTypeData(ClassInfo);
  FPropCount := TypeData.PropCount;

  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for i := 0 to FPropCount - 1 do
    begin
      FProp := FPropList[i];

      sDataToSave := '';
      case FProp.PropType^.Kind of
        tkUString:
          sDataToSave := GetStrProp(Self, FProp);
        tkEnumeration, tkInteger:
          begin
          var vDataInt := GetOrdProp(Self, FProp);
          if (FProp.Default = Low(Integer)) or (vDataInt <> FProp.Default) then
            sDataToSave := IntToStr(vDataInt);
          //sDataToSave := GetOrdProp(Self, FProp).ToString;
          end;
        tkFloat:
          begin
            sDataType := FProp.PropType^.Name;
            if sDataType = 'TDateTime' then
              sDataToSave := FormatDateTime('c', GetFloatProp(Self, FProp))
            else if sDataType = 'TTime' then
              sDataToSave := TimeToStr(GetFloatProp(Self, FProp))
          end;
      end; // case
      if sDataToSave <> '' then
        DestNode.SetAttribute(string(FProp.Name), sDataToSave);
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;
end;

{ TCmdWaitForRunningThread }

constructor TCmdWaitForRunningThread.Create(const AProcessHandle: THandle;
  Command: TCommandData);
begin
  FProcessHandle := AProcessHandle;
  Fcommand := Command;

  inherited Create(false);

  Priority := tpLower;
  FreeOnTerminate := True;
end;

procedure TCmdWaitForRunningThread.Execute;
var
  Res: Cardinal;
begin
  while not Terminated do
  begin
    Res := WaitForSingleObject(FProcessHandle, 1000);
    if Res <> WAIT_TIMEOUT then
    begin
      if (Res = WAIT_OBJECT_0) and not Terminated then
        Fcommand.FisRunning := false;
      Break;
    end;
  end;
  Fcommand.FWaitForRunningThread := nil;
end;

//initialization
//SystemImageList := SHGetFileInfo('',0,Info,SizeOf(Info),SHGFI_SYSICONINDEX or SHGFI_ICON);

end.
