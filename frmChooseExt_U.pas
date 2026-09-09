unit frmChooseExt_U;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ImgList, ComCtrls, Generics.Collections;

type
  TSystemIconCache = TDictionary<Integer, Integer>;

  { TfrmChooseExt }

  TfrmChooseExt = class(TForm)
    ImageList: TImageList;
    gbExtensions: TGroupBox;
    edtExt: TLabeledEdit;
    lvExtensions: TListView;
    lblExtensions: TLabel;
    gbButtons: TGroupBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}Action: TCloseAction);
    procedure edtExtChange(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lvExtensionsDblClick(Sender: TObject);
    procedure lvExtensionsSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
  private
    FlvChanging: Boolean;

    FSystemIconCache: TSystemIconCache;
    FIconTimer: TTimer;

    procedure IconTimerTimer(Sender: TObject);
    procedure InitExtensionItemData(AItem: TListItem);
    procedure LoadIconForItem(Index: Integer);
    procedure InsertExtensionItem(AIndex: Integer;
      const AExtension: string);
    function FindNextIconToLoad: Integer;
    function IsIconNotLoaded(AItem: TListItem): Boolean;
    function FindExtInList(const Ext: string): Integer;
  public
    Extension: string;
    StartWithExtensions: TList<string>;
  end;

var
  frmChooseExt: TfrmChooseExt;

implementation

uses
  Windows, ShellApi, Registry, StrUtils;

{$R *.lfm}

type
  TExtensionIconState = (
    eisNotLoaded,
    eisLoading,
    eisFailed,
    eisLoaded
  );

  PExtensionItemData = ^TExtensionItemData;

  TExtensionItemData = record
    IconState: TExtensionIconState;
  end;

const
  { We don’t let a single Timer event occupy the GUI for too long }
  ICON_MAX_PER_TICK = 8;
  ICON_TIME_BUDGET_MS = 8;

{ TfrmChooseExt }

procedure TfrmChooseExt.btnOKClick(Sender: TObject);
begin
  Extension := edtExt.Text;
end;

procedure TfrmChooseExt.edtExtChange(Sender: TObject);
var
  NewIndex: Integer;
begin
  if FlvChanging or (edtExt.Text = '') then
    Exit;

  NewIndex := FindExtInList(edtExt.Text);

  FlvChanging := True;
  try
    if NewIndex >= 0 then
    begin
      lvExtensions.Selected := lvExtensions.Items[NewIndex];
      lvExtensions.Items[NewIndex].MakeVisible(False);
    end
    else
      lvExtensions.Selected := nil;
  finally
    FlvChanging := False;
  end;
end;

function TfrmChooseExt.FindExtInList(const Ext: string): Integer;
var
  LeftIndex, RightIndex, MiddleIndex: Integer;
  SearchExt: string;
begin
  Result := -1;

  SearchExt := Ext;

  if StartsStr('.', SearchExt) then
    Delete(SearchExt, 1, 1);

  if SearchExt = '' then
    Exit;

  LeftIndex := 0;
  RightIndex := lvExtensions.Items.Count;

  while LeftIndex < RightIndex do
  begin
    MiddleIndex := LeftIndex + (RightIndex - LeftIndex) div 2;

    if AnsiCompareText(
         lvExtensions.Items[MiddleIndex].Caption,
         SearchExt
       ) < 0 then
      LeftIndex := MiddleIndex + 1
    else
      RightIndex := MiddleIndex;
  end;

  if (LeftIndex < lvExtensions.Items.Count) and
     AnsiStartsText(
       SearchExt,
       lvExtensions.Items[LeftIndex].Caption
     ) then
    Result := LeftIndex;
end;

procedure TfrmChooseExt.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  FIconTimer.Enabled := False;

  Extension := edtExt.Text;
  StartWithExtensions.Clear;
end;

procedure TfrmChooseExt.FormDestroy(Sender: TObject);
var
  I: Integer;
  ItemData: PExtensionItemData;
begin
  FIconTimer.Enabled := False;

  for I := 0 to lvExtensions.Items.Count - 1 do
  begin
    ItemData := PExtensionItemData(lvExtensions.Items[I].Data);

    if Assigned(ItemData) then
    begin
      Dispose(ItemData);
      lvExtensions.Items[I].Data := nil;
    end;
  end;

  FreeAndNil(FSystemIconCache);
  FreeAndNil(StartWithExtensions);
end;

procedure TfrmChooseExt.lvExtensionsDblClick(Sender: TObject);
begin
  if Assigned(lvExtensions.Selected) then
  begin
    edtExt.Text := lvExtensions.Selected.Caption;
    btnOK.Click;
  end;
end;

procedure TfrmChooseExt.lvExtensionsSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  if not Selected or FlvChanging then
    Exit;

  FlvChanging := True;
  try
    edtExt.Text := Item.Caption;
  finally
    FlvChanging := False;
  end;
end;

procedure TfrmChooseExt.FormShow(Sender: TObject);
var
  Reg: TRegistry;
  RegistryKeys: TStringList;
  I, ExtensionCount: Integer;
  StartIndex, ListIndex, CompareResult: Integer;
  KeyName, StartExtension: string;
  Item: TListItem;
begin
  FIconTimer.Enabled := False;
  FlvChanging := True;

  lvExtensions.Items.BeginUpdate;
  try
    edtExt.Text := Extension;

    RegistryKeys := TStringList.Create;
    try
      Reg := TRegistry.Create(KEY_READ);
      try
        Reg.RootKey := HKEY_CLASSES_ROOT;

        if Reg.OpenKeyReadOnly('') then
        begin
          try
            Reg.GetKeyNames(RegistryKeys);
          finally
            Reg.CloseKey;
          end;
        end;
      finally
        Reg.Free;
      end;

      { Keep only extension keys in the same list }
      ExtensionCount := 0;

      for I := 0 to RegistryKeys.Count - 1 do
      begin
        KeyName := RegistryKeys[I];

        if (Length(KeyName) > 1) and (KeyName[1] = '.') then
        begin
          RegistryKeys[ExtensionCount] :=
            LowerCase(Copy(KeyName, 2, MaxInt));
          Inc(ExtensionCount);
        end;
      end;

      while RegistryKeys.Count > ExtensionCount do
        RegistryKeys.Delete(RegistryKeys.Count - 1);

      RegistryKeys.CaseSensitive := False;
      RegistryKeys.Sort;

      if lvExtensions.Items.Count = 0 then
      begin
        for I := 0 to RegistryKeys.Count - 1 do
        begin
          Item := lvExtensions.Items.Add;
          Item.Caption := RegistryKeys[I];
          Item.SubItems.Add('');
          Item.ImageIndex := -1;
          InitExtensionItemData(Item);
        end;
      end
      else
      begin
        { Merge new extensions into the cached ListView }
        ListIndex := 0;

        for I := 0 to RegistryKeys.Count - 1 do
        begin
          KeyName := RegistryKeys[I];

          while ListIndex < lvExtensions.Items.Count do
          begin
            CompareResult := AnsiCompareText(
              lvExtensions.Items[ListIndex].Caption,
              KeyName
            );

            if CompareResult >= 0 then
              Break;

            Inc(ListIndex);
          end;

          if ListIndex >= lvExtensions.Items.Count then
          begin
            InsertExtensionItem(
              ListIndex,
              KeyName
            );
          end
          else if AnsiCompareText(
            lvExtensions.Items[ListIndex].Caption,
            KeyName
          ) <> 0 then
          begin
            InsertExtensionItem(
              ListIndex,
              KeyName
            );
          end;

          Inc(ListIndex);
        end;
      end;

    finally
      RegistryKeys.Free;
    end;

    for I := 0 to StartWithExtensions.Count - 1 do
    begin
      StartExtension := StartWithExtensions[I];

      StartIndex := FindExtInList(StartExtension);

      if StartIndex >= 0 then
      begin
        Extension :=
          lvExtensions.Items[StartIndex].Caption;
        Break;
      end;
    end;

    edtExt.Text := Extension;

  finally
    FlvChanging := False;
    lvExtensions.Items.EndUpdate;
  end;

  // for resizing last column width
  lvExtensions.AutoWidthLastColumn := False;
  lvExtensions.AutoWidthLastColumn := True;

  edtExtChange(edtExt);

  FIconTimer.Enabled :=
    FindNextIconToLoad >= 0;

  edtExt.SetFocus;
end;

procedure TfrmChooseExt.FormCreate(Sender: TObject);
begin
  Extension := '';

  StartWithExtensions := TList<string>.Create;
  FSystemIconCache := TSystemIconCache.Create;

  lvExtensions.Items.Clear;
  ImageList.Clear;

  lvExtensions.Columns[0].Width :=
    ImageList.Width +
    lvExtensions.Canvas.TextWidth('mmmmm...') + 16;

  FIconTimer := TTimer.Create(Self);
  FIconTimer.Enabled := False;
  FIconTimer.Interval := 15;
  FIconTimer.OnTimer := IconTimerTimer;
end;

function TfrmChooseExt.FindNextIconToLoad: Integer;
var
  I: Integer;
  FirstVisible, LastVisible: Integer;
  FirstPriority, LastPriority: Integer;
  VisibleRows: Integer;
  PrefetchBelow, PrefetchAbove: Integer;
  TopItem: TListItem;
begin
  Result := -1;

  if lvExtensions.Items.Count = 0 then
    Exit;

  TopItem := lvExtensions.TopItem;

  if Assigned(TopItem) then
    FirstVisible := TopItem.Index
  else
    FirstVisible := 0;

  VisibleRows := lvExtensions.VisibleRowCount;

  if VisibleRows <= 0 then
    VisibleRows := 20;

  LastVisible := FirstVisible + VisibleRows - 1;

  if LastVisible >= lvExtensions.Items.Count then
    LastVisible := lvExtensions.Items.Count - 1;

  PrefetchBelow := VisibleRows * 2;
  PrefetchAbove := VisibleRows;

  LastPriority := LastVisible + PrefetchBelow;

  if LastPriority >= lvExtensions.Items.Count then
    LastPriority := lvExtensions.Items.Count - 1;

  for I := FirstVisible to LastPriority do
    if IsIconNotLoaded(lvExtensions.Items[I]) then
       Exit(I);

  FirstPriority := FirstVisible - PrefetchAbove;

  if FirstPriority < 0 then
    FirstPriority := 0;

  for I := FirstPriority to FirstVisible - 1 do
    if IsIconNotLoaded(lvExtensions.Items[I]) then
      Exit(I);

  for I := 0 to lvExtensions.Items.Count - 1 do
    if IsIconNotLoaded(lvExtensions.Items[I]) then
      Exit(I);
end;

function TfrmChooseExt.IsIconNotLoaded(AItem: TListItem): Boolean;
var
  ItemData: PExtensionItemData;
begin
  ItemData := PExtensionItemData(AItem.Data);

  Result :=
    Assigned(ItemData) and
    (ItemData^.IconState = eisNotLoaded);
end;

procedure TfrmChooseExt.LoadIconForItem(Index: Integer);
var
  Info: TSHFileInfoW;
  Icon: TIcon;
  IconIndex: Integer;
  WideFileName: UnicodeString;
  TypeName: string;
  Item: TListItem;
  ItemData: PExtensionItemData;
begin
  if (Index < 0) or
     (Index >= lvExtensions.Items.Count) then
    Exit;

  Item := lvExtensions.Items[Index];
  ItemData := PExtensionItemData(Item.Data);

  if not Assigned(ItemData) or
     (ItemData^.IconState <> eisNotLoaded) then
    Exit;

  ItemData^.IconState := eisLoading;

  Info := Default(TSHFileInfoW);
  WideFileName := UTF8Decode('dummy.' + Item.Caption);

  try
    if SHGetFileInfoW(
         PWideChar(WideFileName),
         FILE_ATTRIBUTE_NORMAL,
         Info,
         SizeOf(Info),
         SHGFI_ICON or
         SHGFI_SMALLICON or
         SHGFI_TYPENAME or
         SHGFI_USEFILEATTRIBUTES
       ) = 0 then
    begin
      ItemData^.IconState := eisFailed;
      Exit;
    end;

    TypeName :=
      UTF8Encode(
        UnicodeString(
          PWideChar(@Info.szTypeName[0])
        )
      );

    if TypeName <> '' then
      Item.SubItems[0] := TypeName;

    if Info.hIcon = 0 then
    begin
      ItemData^.IconState := eisFailed;
      Exit;
    end;

    if FSystemIconCache.TryGetValue(
         Info.iIcon,
         IconIndex
       ) then
    begin
      Item.ImageIndex := IconIndex;
      ItemData^.IconState := eisLoaded;
      Exit;
    end;

    Icon := TIcon.Create;
    try
      Icon.Handle := Info.hIcon;
      Info.hIcon := 0;

      IconIndex := ImageList.AddIcon(Icon);

      if IconIndex >= 0 then
      begin
        FSystemIconCache.Add(
          Info.iIcon,
          IconIndex
        );

        Item.ImageIndex := IconIndex;
        ItemData^.IconState := eisLoaded;
      end
      else
        ItemData^.IconState := eisFailed;

    finally
      Icon.Free;
    end;

  finally
    if Info.hIcon <> 0 then
      DestroyIcon(Info.hIcon);
  end;
end;

procedure TfrmChooseExt.InsertExtensionItem(AIndex: Integer;
  const AExtension: string);
var
  Item: TListItem;
begin
  if AIndex < lvExtensions.Items.Count then
    Item := lvExtensions.Items.Insert(AIndex)
  else
    Item := lvExtensions.Items.Add;

  Item.Caption := AExtension;
  Item.SubItems.Add('');
  Item.ImageIndex := -1;
  InitExtensionItemData(Item);
end;

procedure TfrmChooseExt.IconTimerTimer(Sender: TObject);
var
  Index: Integer;
  LoadedCount: Integer;
  StartedAt: QWord;
begin
  StartedAt := GetTickCount64;
  LoadedCount := 0;

  repeat
    Index := FindNextIconToLoad;

    if Index < 0 then
    begin
      { All icons have been loaded or resulted in an error }
      FIconTimer.Enabled := False;
      Exit;
    end;

    LoadIconForItem(Index);
    Inc(LoadedCount);

  until
    (LoadedCount >= ICON_MAX_PER_TICK) or
    (GetTickCount64 - StartedAt >= ICON_TIME_BUDGET_MS);
end;

procedure TfrmChooseExt.InitExtensionItemData(AItem: TListItem);
var
  ItemData: PExtensionItemData;
begin
  New(ItemData);

  ItemData^.IconState := eisNotLoaded;

  AItem.Data := ItemData;
end;

end.
