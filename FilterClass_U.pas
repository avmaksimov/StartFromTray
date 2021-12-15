unit FilterClass_U;

interface

uses Classes, IniFiles;

type
  {$M+}
  { TFilterData }
  TFilterData = class(TObject)
  private
    FRunHelper: string;
    FEditHelper: string;
    FExtensions: string;

  public
    constructor Create;

    procedure Assign(Source: TFilterData);
    procedure AssignTo(const AIniFile: TIniFile; const ACaption: string);
  published
    property Extensions: string read FExtensions write FExtensions;
    property Edit: string read FEditHelper write FEditHelper;
    property Run: string read FRunHelper write FRunHelper;
  end;
  {$M-}

var
  Filters: TStringList;

procedure Filters_LoadFromFile;
procedure Filters_SaveToFile;
function Filters_GetFilterByFilename(const AFileName: string): TFilterData;
// nil if not Founded

implementation

uses SysUtils, System.TypInfo, Windows, CommonU;

const
  sFiltersFileName = 'Filters.ini';

  { TFilterData }

procedure TFilterData.Assign(Source: TFilterData);
begin
  FExtensions := Source.Extensions;

  FEditHelper := Source.Edit;
  FRunHelper := Source.Run;
end;

procedure TFilterData.AssignTo(const AIniFile: TIniFile;
  const ACaption: string);
begin
  var TypeData: PTypeData := GetTypeData(ClassInfo);
  var FPropCount: Integer := TypeData.PropCount;

  var FPropList: PPropList;
  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for var i := 0 to FPropCount - 1 do
    begin
      var FProp: PPropInfo := FPropList[i];
      AIniFile.WriteString(ACaption, string(FProp.Name), GetStrProp(Self, FProp));
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;
end;

constructor TFilterData.Create;
begin
  FExtensions := '';

  FEditHelper := '';
  FRunHelper := '';
end;

procedure Filters_LoadFromFile;
begin
  var vIniFile := TIniFile.Create(ExtractFilePath(ParamStr(0)) + sFiltersFileName);
  with vIniFile do
    try
      var vPropCount: Integer := PTypeData(GetTypeData(TFilterData.ClassInfo))^.PropCount;
      var vPropList: PPropList;
      GetMem(vPropList, SizeOf(PPropInfo) * vPropCount);
      GetPropInfos(TFilterData.ClassInfo, vPropList);

      var Sections := TStringList.Create;
      ReadSections(Sections);
      for var vFilterName in Sections do
        begin
        var vFilterData := TFilterData.Create;

        for var i := 0 to vPropCount - 1 do
          begin
          var vProp := vPropList[i];
          SetStrProp(vFilterData, vProp, ReadString(vFilterName, string(vProp.Name), ''));
          end;

        Filters.AddObject(vFilterName, vFilterData)
        end;
      FreeMem(vPropList);
    finally
      Free;
    end;
end;

procedure Filters_SaveToFile;
begin
  var vFilename := ExtractFilePath(ParamStr(0)) + sFiltersFileName;
  var vFilenameNew := ExtractFilePath(ParamStr(0)) + 'new-' + sFiltersFileName;

  var vIniFile := TIniFile.Create(vFilenameNew);
  with vIniFile do
    try
      var vPropCount: Integer := PTypeData(GetTypeData(TFilterData.ClassInfo))^.PropCount;
      var vPropList: PPropList;
      GetMem(vPropList, SizeOf(PPropInfo) * vPropCount);
      GetPropInfos(TFilterData.ClassInfo, vPropList);

      for var i := 0 to Filters.Count - 1 do
        begin
        var vFilterName := Filters[i];
        for var j := 0 to vPropCount - 1 do
          begin
          var vProp := vPropList[j];
          vIniFile.WriteString(vFilterName, string(vProp.Name), GetStrProp(TFilterData(Filters.Objects[i]), vProp));
          end;
        end;
    finally
      Free;
    end;
  if (FileExists(vFilename) and not DeleteFile(PChar(vFilename))) or
    not RenameFile(vFilenameNew, vFilename) then
      RaiseLastOSError;
end;

function Filters_GetFilterByFilename(const AFileName: string): TFilterData;
// nil if not Founded
var
  i: Integer;
  vFilterData: TFilterData;
begin
  Result := nil;

  for i := 0 to Filters.Count - 1 do
  begin
    vFilterData := TFilterData(Filters.Objects[i]);

    if MyMatchesExtensions(AFileName, vFilterData.Extensions) then
    begin
      Result := vFilterData;
      Break;
    end;
  end;
end;

initialization

Filters := TStringList.Create;
Filters_LoadFromFile;

finalization

if Assigned(Filters) then
  FreeAndNil(Filters);

end.
