unit CommandsClass_U;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, ComCtrls, ImgList, DOM, Windows,
  FilterClass_U;

type
  TCommandRunType = (crtNormalRun, crtEdit);
  TCommandIconType = (citDefault, citFromFileRes, citFromFileExt);

  TCmdWaitForRunningThread = class;
  TCommandList = TObjectList;

  {$M+}
  TCommandData = class
  private
    FisGroup: Boolean;
    Fcommand: string;
    FisRunning: Boolean;
    FChilds: TCommandList;
    FCommandParameters: string;
    FWaitForRunningThread: TCmdWaitForRunningThread;
    FIconFilename: string;
    FIconFileIndex: Integer;
    FIconType: TCommandIconType;
    FIconExt: string;
    FIsRunAsAdmin: Boolean;
    function InternalRun(const AHelper, AHelperParams: string;
      const RunType: TCommandRunType; out AProcessHandle: THandle): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Edit;
    procedure Run(const RunType: TCommandRunType);
    procedure Assign(Dest: TCommandData);
    procedure AssignFrom(SrcNode: TDOMElement);
    procedure AssignTo(DestNode: TDOMElement; const ACaption: string);
    function ExtendCommandToFullName: string;
    function GetImageIndex(const AImageList: TCustomImageList): Integer;

    property isRunning: Boolean read FisRunning write FisRunning;
  published
    property isGroup: Boolean read FisGroup write FisGroup default False;
    property Childs: TCommandList read FChilds;
    property Command: string read Fcommand write Fcommand;
    property CommandParameters: string read FCommandParameters
      write FCommandParameters;
    property IsRunAsAdmin: Boolean read FIsRunAsAdmin write FIsRunAsAdmin
      default False;
    property IconType: TCommandIconType read FIconType write FIconType
      default citDefault;
    property IconFilename: string read FIconFilename write FIconFilename;
    property IconFileIndex: Integer read FIconFileIndex write FIconFileIndex
      default -1;
    property IconExt: string read FIconExt write FIconExt;
  end;
  {$M-}

  TCmdWaitForRunningThread = class(TThread)
  private
    FProcessHandle: THandle;
    FCommand: TCommandData;
  protected
    procedure Execute; override;
  public
    constructor Create(const AProcessHandle: THandle; Command: TCommandData);
  end;

procedure TreeToXML(ATreeNodes: TTreeNodes);
function GetPropertyFromNodeAttributes(const NodeAttributes: TDOMElement;
  const PropertyName: string): string;

implementation

uses
  Dialogs, TypInfo, Graphics, ShellApi, ShlObj, ShLwApi, Registry,
  CommonU;

function ToDOMString(const S: string): DOMString;
begin
  Result := DOMString(UTF8Decode(S));
end;

function FromDOMString(const S: DOMString): string;
begin
  Result := UTF8Encode(UnicodeString(S));
end;

function IsStringKind(AKind: TTypeKind): Boolean;
begin
  Result := AKind in [tkSString, tkLString, tkAString, tkWString, tkUString];
end;

function IsRelativeWindowsPath(const FileName: string): Boolean;
var
  WideFileName: UnicodeString;
begin
  WideFileName := UTF8Decode(FileName);
  if PathIsRelativeW(PWideChar(WideFileName)) then
    Result := True
  else
    Result := False;
end;

function EscapeXMLAttribute(const S: string): string;
var
  I, J, L: Integer;

  procedure Put(const V: string);
  var
    N: Integer;
  begin
    N := Length(V);
    Move(V[1], Result[J], N);
    Inc(J, N);
  end;

begin
  L := Length(S);

  for I := 1 to Length(S) do
    case S[I] of
      '&':  Inc(L, 4); // &amp;
      '"':  Inc(L, 5); // &quot;
      '<':  Inc(L, 3); // &lt;
      '>':  Inc(L, 3); // &gt;
      #9:   Inc(L, 3); // &#9;
      #13,
      #10:  Inc(L, 4); // &#13; / &#10;
    end;

  if L = Length(S) then
    Exit(S);

  SetLength(Result, L);
  J := 1;

  for I := 1 to Length(S) do
    case S[I] of
      '&':  Put('&amp;');
      '"':  Put('&quot;');
      '<':  Put('&lt;');
      '>':  Put('&gt;');
      #9:   Put('&#9;');
      #13:  Put('&#13;');
      #10:  Put('&#10;');
    else
      Result[J] := S[I];
      Inc(J);
    end;
end;

procedure WriteCompatibleXMLFile(ADocument: TXMLDocument;
  const FileName: string);
var
  Lines: TStringList;

  procedure WriteElement(AElement: TDOMElement; Indent: Integer);
  var
    I: Integer;
    Line: string;
    Child: TDOMNode;
    HasElementChildren: Boolean;
  begin
    Line := StringOfChar(' ', Indent * 2) + '<' +
      FromDOMString(AElement.NodeName);
    if Assigned(AElement.Attributes) then
      for I := 0 to AElement.Attributes.Length - 1 do
        Line := Line + ' ' +
          FromDOMString(AElement.Attributes.Item[I].NodeName) + '="' +
          EscapeXMLAttribute(FromDOMString(
            AElement.Attributes.Item[I].NodeValue)) + '"';

    HasElementChildren := False;
    Child := AElement.FirstChild;
    while Assigned(Child) do
    begin
      if Child.NodeType = ELEMENT_NODE then
      begin
        HasElementChildren := True;
        Break;
      end;
      Child := Child.NextSibling;
    end;

    if not HasElementChildren then
    begin
      Lines.Add(Line + '/>');
      Exit;
    end;

    Lines.Add(Line + '>');
    Child := AElement.FirstChild;
    while Assigned(Child) do
    begin
      if Child.NodeType = ELEMENT_NODE then
        WriteElement(TDOMElement(Child), Indent + 1);
      Child := Child.NextSibling;
    end;
    Lines.Add(StringOfChar(' ', Indent * 2) + '</' +
      FromDOMString(AElement.NodeName) + '>');
  end;

begin
  Lines := TStringList.Create;
  try
    Lines.LineBreak := #13#10;
    if Assigned(ADocument.DocumentElement) then
      WriteElement(ADocument.DocumentElement, 0);
    Lines.SaveToFile(FileName);
  finally
    Lines.Free;
  end;
end;

procedure TreeToXML(ATreeNodes: TTreeNodes);
var
  TreeNode: TTreeNode;
  XMLDoc: TXMLDocument;
  RootNode: TDOMElement;
  FileName, NewFileName: string;

  procedure ProcessTreeItem(ANode: TTreeNode; AParent: TDOMElement);
  var
    ChildElement: TDOMElement;
    CommandData: TCommandData;
    ChildTreeNode: TTreeNode;
  begin
    ChildElement := XMLDoc.CreateElement('item');
    AParent.AppendChild(ChildElement);
    CommandData := TCommandData(ANode.Data);
    CommandData.AssignTo(ChildElement, ANode.Text);

    ChildTreeNode := ANode.GetFirstChild;
    while Assigned(ChildTreeNode) do
    begin
      ProcessTreeItem(ChildTreeNode, ChildElement);
      ChildTreeNode := ChildTreeNode.GetNextSibling;
    end;
  end;

begin
  XMLDoc := TXMLDocument.Create;
  try
    RootNode := XMLDoc.CreateElement('tree2xml');
    XMLDoc.AppendChild(RootNode);
    RootNode.SetAttribute('name', 'tvItems');

    TreeNode := ATreeNodes.GetFirstNode;
    while Assigned(TreeNode) do
    begin
      ProcessTreeItem(TreeNode, RootNode);
      TreeNode := TreeNode.GetNextSibling;
    end;

    FileName := ExtractFilePath(ParamStr(0)) + cItemsFileName;
    NewFileName := ExtractFilePath(ParamStr(0)) + 'new-' + cItemsFileName;
    if FileExists(NewFileName) and (not SysUtils.DeleteFile(NewFileName)) then
      RaiseLastOSError;
    WriteCompatibleXMLFile(XMLDoc, NewFileName);
    if FileExists(FileName) and (not SysUtils.DeleteFile(FileName)) then
      RaiseLastOSError;
    if not RenameFile(NewFileName, FileName) then
      RaiseLastOSError;
  finally
    XMLDoc.Free;
  end;
end;

function GetPropertyFromNodeAttributes(const NodeAttributes: TDOMElement;
  const PropertyName: string): string;
begin
  if Assigned(NodeAttributes) then
    Result := FromDOMString(NodeAttributes.GetAttribute(ToDOMString(PropertyName)))
  else
    Result := '';
end;

function QueryAssociatedExecutable(const AFileName, AVerb: string): string;
var
  BufferSize: DWORD;
  WideAssociation, WideVerb, WideResult: UnicodeString;
begin
  Result := '';
  WideAssociation := UTF8Decode(ExtractFileExt(AFileName));
  WideVerb := UTF8Decode(AVerb);
  if WideAssociation = '' then
    Exit;

  BufferSize := 0;
  AssocQueryStringW(0, ASSOCSTR_EXECUTABLE,
    PWideChar(WideAssociation), PWideChar(WideVerb), nil, @BufferSize);
  if BufferSize <= 1 then
    Exit;

  WideResult := '';
  SetLength(WideResult, BufferSize);
  if AssocQueryStringW(0, ASSOCSTR_EXECUTABLE,
    PWideChar(WideAssociation), PWideChar(WideVerb),
    PWideChar(WideResult), @BufferSize) = S_OK then
  begin
    SetLength(WideResult, BufferSize - 1);
    Result := UTF8Encode(WideResult);
  end;
end;

function QueryAssociatedCommand(const AFileName, AVerb: string): string;
var
  BufferSize: DWORD;
  WideAssociation, WideVerb, WideResult: UnicodeString;
begin
  Result := '';
  WideAssociation := UTF8Decode(ExtractFileExt(AFileName));
  WideVerb := UTF8Decode(AVerb);
  if WideAssociation = '' then
    Exit;

  BufferSize := 0;
  AssocQueryStringW(0, ASSOCSTR_COMMAND,
    PWideChar(WideAssociation), PWideChar(WideVerb), nil, @BufferSize);
  if BufferSize <= 1 then
    Exit;

  WideResult := '';
  SetLength(WideResult, BufferSize);
  if AssocQueryStringW(0, ASSOCSTR_COMMAND,
    PWideChar(WideAssociation), PWideChar(WideVerb),
    PWideChar(WideResult), @BufferSize) = S_OK then
  begin
    SetLength(WideResult, BufferSize - 1);
    Result := UTF8Encode(WideResult);
  end;
end;

function AssociationCommandParameters(const ACommandLine: string): string;
var
  I: Integer;
  CommandLine: string;
begin
  Result := '';
  CommandLine := TrimLeft(ACommandLine);
  if CommandLine = '' then
    Exit;

  I := 1;
  if CommandLine[I] = '"' then
  begin
    Inc(I);
    while (I <= Length(CommandLine)) and (CommandLine[I] <> '"') do
      Inc(I);
    if I <= Length(CommandLine) then
      Inc(I);
  end
  else
    while (I <= Length(CommandLine)) and
      (CommandLine[I] > ' ') do
      Inc(I);

  Result := TrimLeft(Copy(CommandLine, I, MaxInt));
end;

function ReplaceAssociationToken(var AValue: string;
  const AToken, AReplacement: string): Boolean;
begin
  Result := Pos(LowerCase(AToken), LowerCase(AValue)) > 0;
  if Result then
    AValue := StringReplace(AValue, AToken, AReplacement,
      [rfReplaceAll, rfIgnoreCase]);
end;

function BuildAssociatedParameters(const AParametersTemplate,
  AFileName, AAdditionalParameters: string; out AParameters: string): Boolean;
const
  FileTokenMarker = #1#2#3#4;
  ParametersTokenMarker = #5#6#7#8;
var
  FileInserted, AdditionalParametersInserted: Boolean;
  QuotedFileName: string;
begin
  AParameters := AParametersTemplate;
  QuotedFileName := '"' + AFileName + '"';

  FileInserted := ReplaceAssociationToken(AParameters, '"%1"',
    FileTokenMarker);
  FileInserted := ReplaceAssociationToken(AParameters, '"%L"',
    FileTokenMarker) or FileInserted;
  FileInserted := ReplaceAssociationToken(AParameters, '%1',
    FileTokenMarker) or FileInserted;
  FileInserted := ReplaceAssociationToken(AParameters, '%L',
    FileTokenMarker) or FileInserted;
  if not FileInserted then
    Exit(False);

  AdditionalParametersInserted := ReplaceAssociationToken(AParameters,
    '%*', ParametersTokenMarker);
  AParameters := StringReplace(AParameters, FileTokenMarker,
    QuotedFileName, [rfReplaceAll]);
  AParameters := StringReplace(AParameters, ParametersTokenMarker,
    Trim(AAdditionalParameters), [rfReplaceAll]);
  if (not AdditionalParametersInserted) and
    (Trim(AAdditionalParameters) <> '') then
    AParameters := TrimRight(AParameters) + ' ' + AAdditionalParameters;

  AParameters := Trim(AParameters);
  Result := True;
end;

function TryBuildAssociatedCommand(const AFileName, AVerb,
  AAdditionalParameters: string; out AExecutable,
  AParameters: string): Boolean;
var
  AssociationCommand, ExpandedExecutable: string;
begin
  Result := False;
  AExecutable := QueryAssociatedExecutable(AFileName, AVerb);
  AssociationCommand := QueryAssociatedCommand(AFileName, AVerb);
  if (AExecutable = '') or (AssociationCommand = '') then
    Exit;

  ExpandedExecutable := MyExpandEnvironmentStrings(AExecutable);
  if ExpandedExecutable <> '' then
    AExecutable := ExpandedExecutable;

  Result := BuildAssociatedParameters(
    AssociationCommandParameters(AssociationCommand), AFileName,
    AAdditionalParameters, AParameters);
end;

constructor TCommandData.Create;
begin
  inherited Create;
  FisGroup := False;
  Fcommand := '';
  FCommandParameters := '';
  FIconType := citDefault;
  FIconFilename := '';
  FIconFileIndex := -1;
  FIconExt := '';
  FWaitForRunningThread := nil;
  FisRunning := False;
  FChilds := TCommandList.Create(True);
end;

destructor TCommandData.Destroy;
begin
  if Assigned(FWaitForRunningThread) then
  begin
    FWaitForRunningThread.FCommand := nil;
    FWaitForRunningThread.Terminate;
    FWaitForRunningThread := nil;
  end;
  FChilds.Free;
  inherited Destroy;
end;

function TCommandData.InternalRun(const AHelper, AHelperParams: string;
  const RunType: TCommandRunType; out AProcessHandle: THandle): Boolean;
const
  RunTypeNames: array[TCommandRunType] of string = ('Normal Run', 'Edit');
  HelperCommandMarker = '{file}';
var
  FileName, Parameters, Operation, TechMessage: string;
  AssociationVerb, AssociatedFileName: string;
  AssociatedExecutable, AssociatedParameters: string;
  WideFileName, WideParameters, WideOperation, WideDirectory: UnicodeString;
  SEInfo: TShellExecuteInfoW;
  LastErrorCode: Cardinal;
begin
  Result := False;
  AProcessHandle := 0;
  if AHelper = '' then
  begin
    FileName := Fcommand;
    Parameters := FCommandParameters;

    AssociationVerb := '';
    if RunType = crtEdit then
      AssociationVerb := 'edit'
    else if (Trim(Parameters) <> '') and
      (ExtractFileExt(FileName) <> '') and
      not SameText(ExtractFileExt(FileName), '.exe') and
      not SameText(ExtractFileExt(FileName), '.com') and
      not DirectoryExists(FileName) then
      AssociationVerb := 'open';

    { ShellExecuteEx parameters are not defined for document files. Use the
      complete Windows association command when a document has parameters,
      or when the Edit verb was requested. }
    if AssociationVerb <> '' then
    begin
      AssociatedFileName := ExtendCommandToFullName;
      if AssociatedFileName = '' then
        AssociatedFileName := Fcommand;

      if TryBuildAssociatedCommand(AssociatedFileName, AssociationVerb,
        FCommandParameters, AssociatedExecutable,
        AssociatedParameters) then
      begin
        FileName := AssociatedExecutable;
        Parameters := AssociatedParameters;
      end
      else if RunType = crtEdit then
        Exit;
    end;
  end
  else
  begin
    FileName := AHelper;
    if Pos(HelperCommandMarker, AHelperParams) > 0 then
      Parameters := StringReplace(AHelperParams, HelperCommandMarker,
        Fcommand, [rfReplaceAll])
    else
      Parameters := AHelperParams + ' "' + Fcommand + '"';
    Parameters := TrimRight(Parameters + ' ' + FCommandParameters);
  end;

  if IsRunAsAdmin then
    Operation := 'runas'
  else
    Operation := '';

  WideFileName := UTF8Decode(FileName);
  WideParameters := UTF8Decode(Parameters);
  WideOperation := UTF8Decode(Operation);
  WideDirectory := UTF8Decode(ExtractFilePath(Fcommand));

  SEInfo := Default(TShellExecuteInfoW);
  SEInfo.cbSize := SizeOf(TShellExecuteInfoW);
  if Operation <> '' then
    SEInfo.lpVerb := PWideChar(WideOperation);
  SEInfo.lpFile := PWideChar(WideFileName);
  SEInfo.lpParameters := PWideChar(WideParameters);
  SEInfo.lpDirectory := PWideChar(WideDirectory);
  SEInfo.nShow := SW_SHOWNORMAL;
  if RunType <> crtEdit then
    SEInfo.fMask := SEE_MASK_NOCLOSEPROCESS;

  TechMessage := 'InternalRun: ' + RunTypeNames[RunType] + LineEnding;
  if Operation = '' then
    TechMessage := TechMessage + 'nil'
  else
    TechMessage := TechMessage + Operation;
  TechMessage := TechMessage + '; ' + FileName + '; ';
  if Parameters = '' then
    TechMessage := TechMessage + '<empty string>'
  else
    TechMessage := TechMessage + Parameters;

  if gDebug then
    MessageDlg(TechMessage, mtInformation, [mbOK], 0);

  if ShellExecuteExW(@SEInfo) then
  begin
    Result := True;
    AProcessHandle := SEInfo.hProcess;
  end
  else if gDebug then
  begin
    LastErrorCode := GetLastError;
    if LastErrorCode <> ERROR_NO_ASSOCIATION then
      M_Error('Error: ' + SysErrorMessage(LastErrorCode) + LineEnding +
        'Error code: ' + IntToStr(LastErrorCode) + LineEnding +
        'TechErrorMsg: ' + TechMessage);
  end;
end;

procedure TCommandData.Edit;

  function OpenFolderAndSelectFile(const FileName: string): Boolean;
  var
    ItemIDList: PItemIDList;
    WideFileName: UnicodeString;
  begin
    Result := False;
    WideFileName := UTF8Decode(FileName);
    ItemIDList := ILCreateFromPathW(PWideChar(WideFileName));
    if Assigned(ItemIDList) then
      try
        Result := SHOpenFolderAndSelectItems(ItemIDList, 0,
          LPPCITEMIDLIST(nil), 0) = S_OK;
      finally
        ILFree(ItemIDList);
      end;
  end;

var
  FilterData: TFilterData;
  EditHelper, EditParams: string;
  ProcessHandle: THandle;
begin
  if Fcommand = '' then
    Exit;

  ProcessHandle := 0;
  FilterData := Filters_GetFilterByFilename(Fcommand);
  EditHelper := '';
  EditParams := '';
  if Assigned(FilterData) then
  begin
    EditHelper := FilterData.Edit;
    EditParams := FilterData.EditParams;
  end;
  if EditHelper <> '' then
    InternalRun(EditHelper, EditParams, crtEdit, ProcessHandle)
  else if not InternalRun('', '', crtEdit, ProcessHandle) then
    OpenFolderAndSelectFile(Fcommand);
  if ProcessHandle <> 0 then
    CloseHandle(ProcessHandle);
end;

procedure TCommandData.Run(const RunType: TCommandRunType);
var
  FilterData: TFilterData;
  RunHelper, RunParams: string;
  ProcessHandle: THandle;
begin
  if (Fcommand = '') or FisRunning then
    Exit;

  FilterData := Filters_GetFilterByFilename(Fcommand);
  RunHelper := '';
  RunParams := '';
  if Assigned(FilterData) then
  begin
    RunHelper := FilterData.Run;
    RunParams := FilterData.RunParams;
  end;

  if InternalRun(RunHelper, RunParams, RunType, ProcessHandle) and
    (ProcessHandle <> 0) then
  begin
    isRunning := True;
    TCmdWaitForRunningThread.Create(ProcessHandle, Self);
  end;
end;

function TCommandData.ExtendCommandToFullName: string;
const
  RootKeys: array[0..1] of HKEY = (HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE);
var
  Reg: TRegistry;
  RootKeyIndex: Integer;
  KeyPath: string;
begin
  if DirectoryExists(Command) and (not IsRelativeWindowsPath(Command)) then
    Exit(Command);

  Result := '';
  if SameText(ExtractFileExt(Command), '.exe') then
  begin
    Reg := TRegistry.Create(KEY_READ);
    try
      for RootKeyIndex := Low(RootKeys) to High(RootKeys) do
      begin
        Reg.RootKey := RootKeys[RootKeyIndex];
        KeyPath := '\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\' +
          Command;
        if Reg.OpenKeyReadOnly(KeyPath) then
          case Reg.GetDataType('') of
            rdString:
              Result := Reg.ReadString('');
            rdExpandString:
              Result := MyExpandEnvironmentStrings(Reg.ReadString(''));
          end;
        if Result <> '' then
          Exit;
      end;
    finally
      Reg.Free;
    end;
  end;

  Result := FileSearch(Command, SysUtils.GetEnvironmentVariable('PATH'));
end;

function TCommandData.GetImageIndex(
  const AImageList: TCustomImageList): Integer;
var
  IconHandle, LargeIcon, SmallIcon: HICON;
  Icon: TIcon;
  FileForIcon, Extension: string;
  WideFileForIcon, WideIconFileName: UnicodeString;
  Mask: Cardinal;
  Info: TSHFileInfoW;
begin
  if not Assigned(AImageList) then
    Exit(-1);

  IconHandle := 0;
  if IconType in [citDefault, citFromFileExt] then
  begin
    FileForIcon := '';
    Mask := SHGFI_USEFILEATTRIBUTES;
    if IconType = citDefault then
    begin
      if isGroup then
        Exit(0);

      if (not DirectoryExists(Command)) or IsRelativeWindowsPath(Command) then
      begin
        Extension := LowerCase(ExtractFileExt(Command));
        if (Extension <> '') and (Extension <> '.') then
        begin
          if SameText(Extension, '.exe') or SameText(Extension, '.dll') or
            SameText(Extension, '.ico') then
          begin
            FileForIcon := ExtendCommandToFullName;
            if FileForIcon = '' then
              FileForIcon := Extension;
          end
          else
            FileForIcon := Extension;
        end
        else
          FileForIcon := Command;
      end
      else
      begin
        FileForIcon := Command;
        Mask := 0;
      end;
    end
    else
      FileForIcon := '.' + IconExt;

    Info := Default(TSHFileInfoW);
    WideFileForIcon := UTF8Decode(FileForIcon);
    if SHGetFileInfoW(PWideChar(WideFileForIcon), FILE_ATTRIBUTE_NORMAL, Info,
      SizeOf(Info), Mask or SHGFI_SMALLICON or SHGFI_ICON or
      SHGFI_OPENICON) <> 0 then
      IconHandle := Info.hIcon;
  end
  else
  begin
    LargeIcon := 0;
    SmallIcon := 0;
    WideIconFileName := UTF8Decode(IconFilename);
    if ExtractIconExW(PWideChar(WideIconFileName), IconFileIndex,
      LargeIcon, SmallIcon, 1) > 0 then
    begin
      if SmallIcon <> 0 then
        IconHandle := SmallIcon
      else
      begin
        IconHandle := LargeIcon;
        LargeIcon := 0;
      end;
      if LargeIcon <> 0 then
        DestroyIcon(LargeIcon);
    end;
  end;

  if IconHandle <> 0 then
  begin
    Icon := TIcon.Create;
    try
      Icon.Handle := IconHandle;
      Result := AImageList.AddIcon(Icon);
    finally
      Icon.Free;
    end;
  end
  else
    Result := -1;
end;

procedure TCommandData.Assign(Dest: TCommandData);
var
  I, PropCount: Integer;
  PropList: PPropList;
  PropInfo: PPropInfo;
begin
  PropCount := GetTypeData(ClassInfo)^.PropCount;
  GetMem(PropList, SizeOf(PPropInfo) * PropCount);
  try
    GetPropInfos(ClassInfo, PropList);
    for I := 0 to PropCount - 1 do
    begin
      PropInfo := PropList^[I];
      if IsStringKind(PropInfo^.PropType^.Kind) then
        SetStrProp(Dest, PropInfo, GetStrProp(Self, PropInfo))
      else
        case PropInfo^.PropType^.Kind of
          tkEnumeration, tkInteger, tkBool, tkInt64, tkQWord:
            SetOrdProp(Dest, PropInfo, GetOrdProp(Self, PropInfo));
          tkFloat:
            SetFloatProp(Dest, PropInfo, GetFloatProp(Self, PropInfo));
        end;
    end;
  finally
    FreeMem(PropList);
  end;
end;

procedure TCommandData.AssignFrom(SrcNode: TDOMElement);
var
  I, PropCount: Integer;
  PropList: PPropList;
  PropInfo: PPropInfo;
  DataToLoad, DataType: string;
begin
  PropCount := GetTypeData(ClassInfo)^.PropCount;
  GetMem(PropList, SizeOf(PPropInfo) * PropCount);
  try
    GetPropInfos(ClassInfo, PropList);
    for I := 0 to PropCount - 1 do
    begin
      PropInfo := PropList^[I];
      DataToLoad := GetPropertyFromNodeAttributes(SrcNode,
        string(PropInfo^.Name));
      if DataToLoad = '' then
        Continue;

      if IsStringKind(PropInfo^.PropType^.Kind) then
        SetStrProp(Self, PropInfo, DataToLoad)
      else
        case PropInfo^.PropType^.Kind of
          tkEnumeration, tkInteger, tkBool, tkInt64, tkQWord:
            SetOrdProp(Self, PropInfo, StrToInt64(DataToLoad));
          tkFloat:
            begin
              DataType := string(PropInfo^.PropType^.Name);
              if DataType = 'TDateTime' then
                SetFloatProp(Self, PropInfo, StrToDateTime(DataToLoad))
              else if DataType = 'TTime' then
                SetFloatProp(Self, PropInfo, StrToTime(DataToLoad));
            end;
        end;
    end;
  finally
    FreeMem(PropList);
  end;
end;

procedure TCommandData.AssignTo(DestNode: TDOMElement;
  const ACaption: string);
var
  I, PropCount: Integer;
  PropList: PPropList;
  PropInfo: PPropInfo;
  DataToSave, DataType: string;
  OrdValue: Int64;
begin
  DestNode.SetAttribute('Caption', ToDOMString(ACaption));
  PropCount := GetTypeData(ClassInfo)^.PropCount;
  GetMem(PropList, SizeOf(PPropInfo) * PropCount);
  try
    GetPropInfos(ClassInfo, PropList);
    for I := 0 to PropCount - 1 do
    begin
      PropInfo := PropList^[I];
      DataToSave := '';
      if IsStringKind(PropInfo^.PropType^.Kind) then
        DataToSave := GetStrProp(Self, PropInfo)
      else
        case PropInfo^.PropType^.Kind of
          tkEnumeration, tkInteger, tkBool, tkInt64, tkQWord:
            begin
              OrdValue := GetOrdProp(Self, PropInfo);
              if (PropInfo^.Default = Low(LongInt)) or
                (OrdValue <> PropInfo^.Default) then
                DataToSave := IntToStr(OrdValue);
            end;
          tkFloat:
            begin
              DataType := string(PropInfo^.PropType^.Name);
              if DataType = 'TDateTime' then
                DataToSave := FormatDateTime('c', GetFloatProp(Self, PropInfo))
              else if DataType = 'TTime' then
                DataToSave := TimeToStr(GetFloatProp(Self, PropInfo));
            end;
        end;

      if DataToSave <> '' then
        DestNode.SetAttribute(ToDOMString(string(PropInfo^.Name)),
          ToDOMString(DataToSave));
    end;
  finally
    FreeMem(PropList);
  end;
end;

constructor TCmdWaitForRunningThread.Create(const AProcessHandle: THandle;
  Command: TCommandData);
begin
  FProcessHandle := AProcessHandle;
  FCommand := Command;
  inherited Create(True);
  Priority := tpLower;
  FreeOnTerminate := True;
  Command.FWaitForRunningThread := Self;
  Start;
end;

procedure TCmdWaitForRunningThread.Execute;
var
  WaitResult: Cardinal;
begin
  try
    while not Terminated do
    begin
      WaitResult := WaitForSingleObject(FProcessHandle, 1000);
      if WaitResult <> WAIT_TIMEOUT then
      begin
        if (WaitResult = WAIT_OBJECT_0) and (not Terminated) and
          Assigned(FCommand) then
          FCommand.FisRunning := False;
        Break;
      end;
    end;
  finally
    CloseHandle(FProcessHandle);
    if Assigned(FCommand) then
      FCommand.FWaitForRunningThread := nil;
  end;
end;

end.
