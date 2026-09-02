unit FilterClass_U;

{$mode delphi}{$H+}

interface

uses
  Classes, IniFiles;

type
  {$M+}
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

implementation

uses
  SysUtils, TypInfo, CommonU;

const
  sFiltersFileName = 'Filters.ini';

var
  FPropList: PPropList;
  FPropCount: Integer;

procedure TFilterData.Assign(Source: TFilterData);
var
  I: Integer;
  PropInfo: PPropInfo;
begin
  for I := 0 to FPropCount - 1 do
  begin
    PropInfo := FPropList^[I];
    SetStrProp(Self, PropInfo, GetStrProp(Source, PropInfo));
  end;
end;

constructor TFilterData.Create;
var
  I: Integer;
begin
  inherited Create;
  for I := 0 to FPropCount - 1 do
    SetStrProp(Self, FPropList^[I], '');
end;

procedure Filters_LoadFromFile;
var
  IniFile: TIniFile;
  Sections: TStringList;
  FilterName: string;
  FilterData: TFilterData;
  PropInfo: PPropInfo;
  I, J: Integer;
begin
  for I := Filters.Count - 1 downto 0 do
    Filters.Objects[I].Free;
  Filters.Clear;

  IniFile := TIniFile.Create(ExtractFilePath(ParamStr(0)) + sFiltersFileName);
  Sections := TStringList.Create;
  try
    IniFile.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
    begin
      FilterName := Sections[I];
      FilterData := TFilterData.Create;
      for J := 0 to FPropCount - 1 do
      begin
        PropInfo := FPropList^[J];
        SetStrProp(FilterData, PropInfo,
          IniFile.ReadString(FilterName, string(PropInfo^.Name), ''));
      end;
      Filters.AddObject(FilterName, FilterData);
    end;
  finally
    Sections.Free;
    IniFile.Free;
  end;
end;

procedure Filters_SaveToFile;
var
  FileName, NewFileName, FilterName: string;
  IniFile: TIniFile;
  PropInfo: PPropInfo;
  I, J: Integer;
begin
  FileName := ExtractFilePath(ParamStr(0)) + sFiltersFileName;
  NewFileName := ExtractFilePath(ParamStr(0)) + 'new-' + sFiltersFileName;

  if FileExists(NewFileName) and (not DeleteFile(NewFileName)) then
    RaiseLastOSError;

  IniFile := TIniFile.Create(NewFileName);
  try
    for I := 0 to Filters.Count - 1 do
    begin
      FilterName := Filters[I];
      for J := 0 to FPropCount - 1 do
      begin
        PropInfo := FPropList^[J];
        IniFile.WriteString(FilterName, string(PropInfo^.Name),
          GetStrProp(TFilterData(Filters.Objects[I]), PropInfo));
      end;
    end;
  finally
    IniFile.Free;
  end;

  if (FileExists(FileName) and (not DeleteFile(FileName))) or
    (not RenameFile(NewFileName, FileName)) then
    RaiseLastOSError;
end;

function Filters_GetFilterByFilename(const AFileName: string): TFilterData;
var
  I: Integer;
  FilterData: TFilterData;
begin
  Result := nil;
  for I := 0 to Filters.Count - 1 do
  begin
    FilterData := TFilterData(Filters.Objects[I]);
    if MyMatchesExtensions(AFileName, FilterData.Extensions) then
      Exit(FilterData);
  end;
end;

initialization
  FPropCount := GetTypeData(TFilterData.ClassInfo)^.PropCount;
  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  GetPropInfos(TFilterData.ClassInfo, FPropList);
  Filters := TStringList.Create;
  Filters_LoadFromFile;

finalization
  while Filters.Count > 0 do
  begin
    Filters.Objects[Filters.Count - 1].Free;
    Filters.Delete(Filters.Count - 1);
  end;
  Filters.Free;
  FreeMem(FPropList);

end.
