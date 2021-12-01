unit CommandsClass_U;

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
    FName: string;
    // уникальное имя (используется для автоматизации редактирования скриптов). Генерируется автоматически
    //FisVisible: boolean; // признак видимости
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
    function InternalRun(const AHelper: string; const ADefaultOperation: PChar;
      const RunType: TCommandRunType; const IsRunAsAdmin: Boolean): THandle;

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
    function  ExtractHIcon(const ACommand: string = ''): HIcon;
    // real property
    property isRunning: boolean read FisRunning write FisRunning;
  published // all this properties saves in xmls

    property Name: string read FName write FName;
    //property isVisible: boolean read FisVisible write FisVisible;
    property isGroup: boolean read FisGroup write FisGroup;
    property Childs: TCommandList read FChilds;
    property Command: string read Fcommand write Fcommand;
    property CommandParameters: string read FCommandParameters
      write FCommandParameters;
    property IsRunAsAdmin: Boolean read FIsRunAsAdmin write FIsRunAsAdmin;
    property IconType: TCommandIconType read FIconType write FIconType;
    property IconFilename: string read FIconFilename write FIconFilename;
    property IconFileIndex: Integer read FIconFileIndex write FIconFileIndex;// default -1;
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

//function MyExtractHIcon(ACommand: string; const ACommandData: TCommandData): HIcon;

// var MainCommandList: TCommandList; // основной список

implementation

uses CommonU;

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
  // 'StartFromTray_tvItems.xml';
  vFilenameNew := ExtractFilePath(ParamStr(0)) + 'new-' + cItemsFileName;
  // StartFromTray_tvItems.xml';

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
  // Node: IXMLNode;
  Res: OleVariant;
begin
  Res := (NodeAttributes.Attributes[sProperty]);

  if not VarIsNull(Res) then
    Result := Res
  else
    Result := '';
end;

// now AFileName can be not full and be in Path
// Result: 0 or valid hIcon
{function MyExtractHIcon(ACommand: string; const ACommandData: TCommandData): HIcon;
var
  vExt: string;
  Info: TSHFileInfo;
begin
Result := 0;
case ACommandData.IconType of
  citFromFileRes:
    begin
    var vLargeIcon: hIcon := 0;
    var vSmallIcon: HIcon := 1; // non zero
    if ExtractIconEx(PChar(ACommandData.IconFilename), ACommandData.IconFileIndex, vLargeIcon, vSmallIcon, 1) > 0 then
      Exit(vSmallIcon);
    end;
  else //ACommandData.IconType = 0
    begin
    vExt := ExtractFileExt(ACommand);
    if (vExt = '') or (vExt = '.') then
      Exit(0);

    vExt := vExt.ToLower;

    if (vExt = '.exe') or (vExt = '.dll') or (vExt = '.ico') then
    begin
      if IsRelativePath(ACommand) then
        ACommand := MyExtendFileNameToFull(ACommand);
      if ACommand = '' then
        ACommand := vExt; // not found - so default
    end
    else // common document - enough only Ext
      ACommand := vExt;

    Result := SHGetFileInfo(PChar(ACommand), FILE_ATTRIBUTE_NORMAL, Info,
      SizeOf(TSHFileInfo), SHGFI_ICON or SHGFI_SMALLICON or
      SHGFI_USEFILEATTRIBUTES);
    If Result <> 0 then
      Result := Info.HIcon
      // Result := ExtractAssociatedIcon(Application.Handle, PChar(AFileName), w)
    end;
end; //case
end;}

{ TCommandData }

constructor TCommandData.Create;
begin
  inherited Create;

  FName := '';
  //FisVisible := True; // признак видимости
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

function TCommandData.InternalRun(const AHelper: string;
  const ADefaultOperation: PChar; const RunType: TCommandRunType;
  const IsRunAsAdmin: Boolean): THandle;
const
  strCommandRunType: array [TCommandRunType] of string = ('Normal Run', 'Edit');
var
  vOperation, vFilename, vParameters: PChar;
  SEInfo: TShellExecuteInfo;
  vGetLastError: Cardinal;
  sTechErrorMsg: string;
begin
  Result := 0;

  CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE);

  if AHelper <> '' then
  begin
    vOperation := nil;
    vFilename := PChar('"' + AHelper + '"');
    vParameters := PChar('"' + Fcommand + '"' + FCommandParameters);
  end
  else
  begin
    vOperation := ADefaultOperation;
    vFilename := PChar(Fcommand);
    vParameters := PChar(FCommandParameters);
  end;

  if (vOperation = nil) and IsRunAsAdmin then
    vOperation := PChar('runas');

  FillChar(SEInfo, SizeOf(SEInfo), 0);
  with SEInfo do
  begin
    cbSize := SizeOf(TShellExecuteInfo);
    lpVerb := vOperation;
    lpFile := vFilename;
    lpParameters := vParameters;
    lpDirectory := PChar(ExtractFilePath(Fcommand));
    nShow := SW_SHOWNORMAL;
    if RunType <> crtEdit then
      fMask := SEE_MASK_NOCLOSEPROCESS;
  end;
  if ShellExecuteEx(@SEInfo) then
    Result := SEInfo.hProcess
  else if gDebug then
  begin
    vGetLastError := GetLastError;
    if vGetLastError <> 1155 then
    // не установлена ассоциация (чтобы не было двойного сообщения об ошибке)
    begin
      if vOperation = nil then
        sTechErrorMsg := 'nil'
      else
        sTechErrorMsg := vOperation;
      sTechErrorMsg := sTechErrorMsg + '; ' + vFilename + '; ';
      if vParameters = nil then
        sTechErrorMsg := sTechErrorMsg + 'nil'
      else
        sTechErrorMsg := sTechErrorMsg + vParameters;

      M_Error('Error with ' + strCommandRunType[RunType] + ': ' +
        SysErrorMessage(vGetLastError) + LineFeed + 'Error code: ' +
        IntToStr(vGetLastError) + LineFeed + 'TechErrorMsg: ' + sTechErrorMsg);
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
      AssocQueryString(0, ASSOCSTR_EXECUTABLE, PChar(vFilename), 'edit',
        pResult, @pResultSize);
      Result := pResult;
    finally
      StrDispose(pResult);
    end;
  end;

var
  vFilterData: TFilterData;
  editHelper: string;
begin
  if Fcommand <> '' then
  begin
    vFilterData := Filters_GetFilterByFilename(Fcommand);
    if Assigned(vFilterData) then
    begin
      editHelper := vFilterData.editHelper;
    end
    else
      editHelper := '';
    if (editHelper <> '') or (GetAssociatedExeForEdit(Fcommand) <> '') then
      InternalRun(editHelper, PChar('edit'), crtEdit, IsRunAsAdmin)
    else
      OpenFolderAndSelectFile(Fcommand);
  end;
end;

// now AFileName can be not full and be in Path
// Result: 0 or valid hIcon
function TCommandData.ExtractHIcon(const ACommand: string = ''): HIcon;
begin
Result := 0;
if IconType in [citDefault, citFromFileExt] then
  begin
  var vFileForIcon: string;
  if IconType = citDefault then
    begin
    if vFileForIcon <> '' then
      vFileForIcon := ACommand
    else
      vFileForIcon := Command;

    var vExt := ExtractFileExt(vFileForIcon);
    if (vExt = '') or (vExt = '.') then
      Exit(0);

    vExt := vExt.ToLower;

    if (vExt = '.exe') or (vExt = '.dll') or (vExt = '.ico') then
      begin
      if IsRelativePath(vFileForIcon) then
        vFileForIcon := MyExtendFileNameToFull(vFileForIcon);
      if vFileForIcon = '' then
        vFileForIcon := vExt; // not found - so default
      end
    else // common document - enough only Ext
      vFileForIcon := vExt;
    end
  else //citFromFileExt
    vFileForIcon := '.' + IconExt;
  // IconType in [citDefault, citFromFileExt]
  var Info: TSHFileInfo;
  Result := SHGetFileInfo(PChar(vFileForIcon), FILE_ATTRIBUTE_NORMAL, Info,
    SizeOf(TSHFileInfo), SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES);
  If Result <> 0 then
    Result := Info.HIcon
  end //IconType in [citDefault, citFromFileExt]
else //citFromFileRes
  begin
  var vLargeIcon: hIcon := 0;
  var vSmallIcon: HIcon := 1; // non zero
  if ExtractIconEx(PChar(IconFilename), IconFileIndex, vLargeIcon, vSmallIcon, 1) > 0 then
    Result := vSmallIcon;
  end;
end;

procedure TCommandData.Run(const RunType: TCommandRunType);
var
  vFilterData: TFilterData;
  runHelper: string;
  // CmdWaitForRunningThread: TCmdWaitForRunningThread;
  ProcessHandle: THandle;
begin
  if (Fcommand <> '') and not FisRunning then
  begin
    vFilterData := Filters_GetFilterByFilename(Fcommand);
    if Assigned(vFilterData) then
      runHelper := vFilterData.runHelper
    else
      runHelper := '';

    ProcessHandle := InternalRun(runHelper, nil, RunType, IsRunAsAdmin);
    if ProcessHandle <> 0 then
    begin
      isRunning := True;
      FWaitForRunningThread := TCmdWaitForRunningThread.Create
        (ProcessHandle, Self);
    end;
  end;
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
  //TypeData: PTypeData;
  FPropList: PPropList;
  FProp: PPropInfo;
  //sDataToLoad: string;
  //sDataType: TSymbolName;
begin
  //TypeData := GetTypeData(ClassInfo);
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


  // patch for loading from XML
  {if (IconType = citDefault) and (IconFilename <> '') then
    IconType := citFromFileRes;}
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
          {var vDataInt := GetOrdProp(Self, FProp);
          if vDataInt <> FProp.Default  then
            sDataToSave := IntToStr(vDataInt);}
          sDataToSave := GetOrdProp(Self, FProp).ToString;
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

end.
