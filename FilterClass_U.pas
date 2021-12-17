unit FilterClass_U;

interface

uses Classes, IniFiles;

type
  {$M+}
  { TFilterData }
  TFilterData = class(TObject)
  private
    FRun: string;
    FEdit: string;
    FExtensions: string;
    FRunParams: string;
    FEditParams: string;

  public
    constructor Create;

    procedure Assign(Source: TFilterData);
  published
    property Extensions: string read FExtensions write FExtensions;
    property Edit: string read FEdit write FEdit;
    property EditParams: string read FEditParams write FEditParams;
    property Run: string read FRun write FRun;
    property RunParams: string read FRunParams write FRunParams;
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

var FPropList: PPropList; FPropCount: Integer;

  { TFilterData }

procedure TFilterData.Assign(Source: TFilterData);
begin
  for var i := 0 to FPropCount - 1 do
    begin
    var vProp := FPropList[i];
    SetStrProp(Self, vProp, GetStrProp(Source, vProp));
    end;
end;

constructor TFilterData.Create;
begin
  for var i := 0 to FPropCount - 1 do
    begin
    SetStrProp(Self, FPropList[i], '');
    end;
end;

procedure Filters_LoadFromFile;
begin
  var vIniFile := TIniFile.Create(ExtractFilePath(ParamStr(0)) + sFiltersFileName);
  with vIniFile do
    try
      var Sections := TStringList.Create;
      ReadSections(Sections);
      for var vFilterName in Sections do
        begin
        var vFilterData := TFilterData.Create;

        for var i := 0 to FPropCount - 1 do
          begin
          var vProp := FPropList[i];
          SetStrProp(vFilterData, vProp, ReadString(vFilterName, string(vProp.Name), ''));
          end;

        Filters.AddObject(vFilterName, vFilterData)
        end;
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
      for var i := 0 to Filters.Count - 1 do
        begin
        var vFilterName := Filters[i];
        for var j := 0 to FPropCount - 1 do
          begin
          var vProp := FPropList[j];
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

FPropCount := PTypeData(GetTypeData(TFilterData.ClassInfo))^.PropCount;
GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
GetPropInfos(TFilterData.ClassInfo, FPropList);

Filters := TStringList.Create;
Filters_LoadFromFile;

finalization

//Filters.Free;
//FreeMem(FPropList);

end.
