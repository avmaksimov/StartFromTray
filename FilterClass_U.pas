unit FilterClass_U;

interface

uses Classes;

type
  { TFilterData }
  TFilterData = class(TObject)
  private
    FRunHelper: string;
    FEditHelper: string;
    FExtensions: string;

  public
    constructor Create;

    procedure Assign(Source: TFilterData);

    property Extensions: string read FExtensions write FExtensions;

    property EditHelper: string read FEditHelper write FEditHelper;
    property RunHelper: string read FRunHelper write FRunHelper;
  end;

var
  Filters: TStringList;

procedure Filters_LoadFromFile;
procedure Filters_SaveToFile;
// function Filters_CreateFilter: string; // creating filter from Filters (include sFilterAllFiles)
function Filters_GetFilterByFilename(const AFileName: string): TFilterData;
// nil if not Founded

implementation

uses IniFiles, SysUtils, Windows, CommonU;

const
  sFiltersFileName = 'Filters.ini';

  // sFiltersAllFiles = 'All files (*.*)|*.*';

  // don't translate it!
  sFilterProperty_Extensions = 'Extensions';
  sFilterProperty_EditHelper = 'Edit';
  sFilterProperty_RunHelper = 'Run';

  { TFilterData }

procedure TFilterData.Assign(Source: TFilterData);
begin
  FExtensions := Source.Extensions;

  FEditHelper := Source.EditHelper;
  FRunHelper := Source.RunHelper;
end;

constructor TFilterData.Create;
begin
  FExtensions := '';

  FEditHelper := '';
  FRunHelper := '';
end;

procedure Filters_LoadFromFile;
var
  Sections: TStringList;
  i: Integer;
  FFilterData: TFilterData;
  sSection: string;
begin
  with TIniFile.Create(ExtractFilePath(ParamStr(0)) + sFiltersFileName) do
    try
      Sections := TStringList.Create;
      ReadSections(Sections);
      for i := 0 to Sections.Count - 1 do
      begin
        sSection := Sections[i];
        FFilterData := TFilterData.Create;

        FFilterData.Extensions := ReadString(Trim(sSection),
          sFilterProperty_Extensions, '');

        FFilterData.EditHelper := ReadString(Trim(sSection),
          sFilterProperty_EditHelper, '');
        FFilterData.RunHelper := ReadString(Trim(sSection),
          sFilterProperty_RunHelper, '');
        Filters.AddObject(Trim(sSection), FFilterData);
      end;
    finally
      Free;
    end;
end;

procedure Filters_SaveToFile;
var
  i: Integer;
  s: string;
  FFilterData: TFilterData;
var
  vFilename, vFilenameNew: string;
begin
  vFilename := ExtractFilePath(ParamStr(0)) + sFiltersFileName;
  vFilenameNew := ExtractFilePath(ParamStr(0)) + 'new-' + sFiltersFileName;
  { if FileExists(s) then
    If not SysUtils.DeleteFile(s) then
    begin
    MessageBox(0, PChar('Can''t delete file "' + s + '" to save Filters'), PChar('Saving Filters'), MB_ICONERROR);
    Exit;
    end; }

  with TIniFile.Create(vFilenameNew) do
    try
      for i := 0 to Filters.Count - 1 do
      begin
        s := Filters[i];
        FFilterData := TFilterData(Filters.Objects[i]);

        WriteString(s, sFilterProperty_Extensions, FFilterData.Extensions);

        WriteString(s, sFilterProperty_EditHelper, FFilterData.EditHelper);
        WriteString(s, sFilterProperty_RunHelper, FFilterData.RunHelper);

      end;
    finally
      Free;
    end;
  if FileExists(vFilename) then
    if not DeleteFile(PChar(vFilename)) then
      RaiseLastOSError;
  if not RenameFile(vFilenameNew, vFilename) then
    RaiseLastOSError;
end;

{ function Filters_CreateFilter: string; // creating filter from Filters (include sFilterAllFiles)
  var i: Integer; s: string;
  begin
  Result := '';
  for i := 0 to Filters.Count - 1 do
  begin
  s := TFilterData(Filters.Objects[i]).FExtensions;

  Result := Result + Filters[i] + ' (' + s + ')|' + s + '|';
  end;

  s := Result + sFiltersAllFiles;
  Result := s;
  end; }

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
