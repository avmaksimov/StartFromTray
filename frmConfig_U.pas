unit frmConfig_U;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, Graphics, Dialogs, ComCtrls,
  ExtCtrls, Menus, StdCtrls, ActnList, Registry, Windows, ImgList,
  IniFiles, LMessages, CommandsClass_U,
  frmCommandConfig_U, MPPopupMenu;

const
  cShowTrayMenuMessageName =
    'StartFromTray.ShowTrayMenu.{3A55B01F-07C3-4DC7-A7C0-C71A78C10B66}';
  cMainWindowPropertyName =
    'StartFromTray.MainWindow.{3A55B01F-07C3-4DC7-A7C0-C71A78C10B66}';

  cIniFormIdent = 'FormConfig';
  cIniFormState = 'State';
  cIniFormLeft = 'Left';
  cIniFormTop = 'Top';
  cIniFormWidth = 'Width';
  cIniFormHeight = 'Height';

  cMinFormWidth = 808;
  cMinFormHeight = 525;

type

  { TfrmConfig }

  TfrmConfig = class(TForm)
    actAddElement: TAction;
    actCopy: TAction;
    actDel: TAction;
    actClose: TAction;
    actApply: TAction;
    actItemDown: TAction;
    actItemUp: TAction;
    actOK: TAction;
    ActionList: TActionList;
    btnAddGroup: TButton;
    btnApply: TButton;
    btnClose: TButton;
    btnDel: TButton;
    btnCopy: TButton;
    btnOK: TButton;
    btnAddElement: TButton;
    btnUp: TButton;
    btnDown: TButton;
    gbItems: TGroupBox;
    gbProperties: TGroupBox;
    gbButtons: TGroupBox;
    gbMainButtons: TGroupBox;
    MenuItem1: TMenuItem;
    ppCMExit: TMenuItem;
    ppCMConfig: TMenuItem;
    ppConfigMenu: TPopupMenu;
    TrayIcon: TTrayIcon;
    tvItems: TTreeView;
    TreeImageList: TImageList;
    frmCommandConfig: TfrmCommandConfig;
    lblVer: TLabel;
    actAddGroup: TAction;
    btnOptions: TButton;
    ppOptionsMenu: TPopupMenu;
    miOptionsLang: TMenuItem;
    N1: TMenuItem;
    miOptionsRunAtStart: TMenuItem;
    N2: TMenuItem;
    miOptionsExtensions: TMenuItem;
    N3: TMenuItem;
    miOptionsExitProgram: TMenuItem;
    procedure actAddElementExecute(Sender: TObject);
    procedure actApplyExecute(Sender: TObject);
    procedure actApplyUpdate(Sender: TObject);
    procedure actCloseExecute(Sender: TObject);
    procedure actCloseUpdate(Sender: TObject);
    procedure actDelExecute(Sender: TObject);
    procedure actCopyUpdate(Sender: TObject);
    procedure actItemDownExecute(Sender: TObject);
    procedure actItemDownUpdate(Sender: TObject);
    procedure actItemUpExecute(Sender: TObject);
    procedure actItemUpUpdate(Sender: TObject);
    procedure actOKExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure ppCMConfigClick(Sender: TObject);
    procedure ppCMExitClick(Sender: TObject);
    procedure tvItemsChange(Sender: TObject; Node: TTreeNode);
    procedure tvItemsChanging(Sender: TObject; Node: TTreeNode;
      var AllowChange: Boolean);
    procedure tvItemsDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure tvItemsEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure TrayIconMouseUp(Sender: TObject; Button: TMouseButton;
      {%H-}Shift: TShiftState; X, Y: Integer);
    procedure tvItemsDragOver(Sender, Source: TObject; {%H-}X, {%H-}Y: Integer;
      {%H-}State: TDragState; var Accept: Boolean);
    procedure ppTrayMenuItemMiddleClick(Item: TMenuItem);
    procedure ppTrayMenuItemRightClick(Item: TMenuItem);
    procedure actCopyExecute(Sender: TObject);
    procedure tvItemsCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      {%H-}State: TCustomDrawState; var {%H-}DefaultDraw: Boolean);
    procedure FormHide(Sender: TObject);
    procedure lblVerClick(Sender: TObject);
    procedure FormConstrainedResize(Sender: TObject; var MinWidth, MinHeight,
      {%H-}MaxWidth, {%H-}MaxHeight: Integer);
    procedure miOptionsExitProgramClick(Sender: TObject);
    procedure btnOptionsClick(Sender: TObject);
    procedure miOptionsRunAtStartClick(Sender: TObject);
    procedure miOptionsExtensionsClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    gMenuItemBmpWidth, gMenuItemBmpHeight: Integer;
    IsModified: Boolean;
    MouseButtonSwapped: Boolean;
    ppTrayMenu: TMPPopupMenu;
    FWindowStateBeforeMinimize: TWindowState;
    procedure CorrectTreeViewItemHeight;
    procedure DisposeTreeNodeData(TreeNode: TTreeNode;
      const AddToDeletedImages: Boolean);
    procedure DisposeAllTreeData;
    procedure ReloadData;
    procedure ppTrayMenuItemOnClick(Sender: TObject);
    function ppTrayMenuQueryItemMissing(Item: TMenuItem): Boolean;
    function GetTrayMenuPoint: TPoint;
    procedure TreeToMenu(ATreeNodes: TTreeNodes; AMenuItems: TMenuItem;
      const NotifyEvent: TNotifyEvent);
    procedure UpdateLblVerLeftAndCaption;
    procedure RestoreFormProperties;
    procedure SaveFormProperties;
    procedure MyFormShow;
    procedure ExitProgram;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure WndProc(var Message: TLMessage); override;
  public
    MainIniFile: TIniFile;
    ListDeletedImageIndexes: TImageIndexList;
    destructor Destroy; override;
    procedure Initialize(const AMainIniFile: TIniFile);
    procedure miOptionsLangClick(Sender: TObject);
  end;

var
  frmConfig: TfrmConfig;
  WM_TASKBARCREATED: UINT = 0;
  WM_SHOWTRAYMENU: UINT = 0;

implementation

uses
  CommCtrl, ShellApi, DOM, XMLRead, CommonU, frmExtensions_U,
  LangsU;

{$R *.lfm}

const
  cLCLTrayIconID = 25;

type
  PNotifyIconIdentifierEx = ^TNotifyIconIdentifierEx;
  TNotifyIconIdentifierEx = record
    cbSize: DWORD;
    hWnd: HWND;
    uID: UINT;
    guidItem: TGUID;
  end;

  PTrayIconRect = ^TRect;

function M_Shell_NotifyIconGetRect(
  Identifier: PNotifyIconIdentifierEx;
  IconLocation: PTrayIconRect
): HRESULT; stdcall;
  external 'shell32.dll' name 'Shell_NotifyIconGetRect';

procedure TfrmConfig.CreateWnd;
begin
  inherited CreateWnd;

  if not Windows.SetProp(
    Handle,
    PChar(cMainWindowPropertyName),
    THandle(1)
  ) then
    RaiseLastOSError;
end;

procedure TfrmConfig.DestroyWnd;
begin
  Windows.RemoveProp(Handle, PChar(cMainWindowPropertyName));
  inherited DestroyWnd;
end;

procedure TfrmConfig.actApplyExecute(Sender: TObject);
var
  I, J, ImageIndex, LastImageIndex: Integer;
begin
  if not frmCommandConfig.SaveAssigned then
    Exit;

  TreeToXML(tvItems.Items);
  ppTrayMenu.Items.Clear;
  if ListDeletedImageIndexes.Count > 0 then
  begin
    ListDeletedImageIndexes.Sort;
    tvItems.Items.BeginUpdate;
    try
      LastImageIndex := -1;
      for I := ListDeletedImageIndexes.Count - 1 downto 0 do
      begin
        ImageIndex := ListDeletedImageIndexes[I];
        if (ImageIndex <= 0) or (ImageIndex = LastImageIndex) then
          Continue;
        LastImageIndex := ImageIndex;
        if ImageIndex < TreeImageList.Count then
        begin
          TreeImageList.Delete(ImageIndex);
          for J := 0 to tvItems.Items.Count - 1 do
            if tvItems.Items[J].SelectedIndex > ImageIndex then
            begin
              tvItems.Items[J].SelectedIndex :=
                tvItems.Items[J].SelectedIndex - 1;
              tvItems.Items[J].ImageIndex := tvItems.Items[J].SelectedIndex;
            end;
        end;
      end;
    finally
      ListDeletedImageIndexes.Clear;
      tvItems.Items.EndUpdate;
    end;
  end;
  TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick);
  IsModified := False;
end;

procedure TfrmConfig.actAddElementExecute(Sender: TObject);
var
  ItemTag: PtrInt;
  CommandData: TCommandData;
begin
  if not frmCommandConfig.SaveAssigned then
    Exit;
  ItemTag := TAction(Sender).Tag;
  CommandData := TCommandData.Create;
  CommandData.isGroup := ItemTag = 0;
  tvItems.Selected := tvItems.Items.AddObject(tvItems.Selected, '', CommandData);
  tvItems.Selected.ImageIndex := ItemTag;
  tvItems.Selected.SelectedIndex := ItemTag;
  if tvItems.Items.Count = 1 then
    CorrectTreeViewItemHeight;
  tvItems.Repaint;
  IsModified := True;
  frmCommandConfig.edtCaption.SetFocus;
end;

procedure TfrmConfig.actApplyUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := IsModified or frmCommandConfig.IsModified;
end;

procedure TfrmConfig.actCloseExecute(Sender: TObject);
begin
  if IsModified or frmCommandConfig.IsModified then
  begin
    if not AskForConfirmation(Self,
      GetLangString('LangStrings', 'CancelConfirm')) then
      Exit;
    Hide;
    ppTrayMenu.Items.Clear;
    frmCommandConfig.ClearAssigned;
    tvItems.OnChange := nil;
    tvItems.OnChanging := nil;
    DisposeAllTreeData;
    tvItems.Items.Clear;
    tvItems.OnChange := tvItemsChange;
    tvItems.OnChanging := tvItemsChanging;
    TreeImageList.Clear;
    IsModified := False;
    ReloadData;
  end
  else
    Hide;
end;

procedure TfrmConfig.actCloseUpdate(Sender: TObject);
begin
  if IsModified or frmCommandConfig.IsModified then
    actClose.Caption := GetLangString('LangStrings', 'Cancel')
  else
    actClose.Caption := GetLangString('LangStrings', 'Close');
end;

procedure TfrmConfig.actDelExecute(Sender: TObject);
var
  NodeToDelete, FutureNode: TTreeNode;
begin
  NodeToDelete := tvItems.Selected;
  if (not Assigned(NodeToDelete)) or
    (not AskForDeletion(Self, NodeToDelete.Text)) then
    Exit;

  tvItems.Items.BeginUpdate;
  try
    FutureNode := NodeToDelete.GetNextSibling;
    if not Assigned(FutureNode) then
      FutureNode := NodeToDelete.GetPrevSibling;
    if not Assigned(FutureNode) then
      FutureNode := NodeToDelete.Parent;
    DisposeTreeNodeData(NodeToDelete, True);
    frmCommandConfig.ClearAssigned;
    NodeToDelete.Delete;
    tvItems.Selected := FutureNode;
  finally
    tvItems.Items.EndUpdate;
  end;
  IsModified := True;
end;

procedure TfrmConfig.actCopyExecute(Sender: TObject);

  function CopyTreeNode(TreeNode: TTreeNode;
    ParentTreeNode: TTreeNode): TTreeNode;
  var
    CommandData: TCommandData;
    ImageIndex: Integer;
    Icon: TIcon;
    ChildTreeNode: TTreeNode;
  begin
    CommandData := TCommandData.Create;
    TCommandData(TreeNode.Data).Assign(CommandData);
    if Assigned(ParentTreeNode) then
      Result := tvItems.Items.AddChildObject(ParentTreeNode,
        TreeNode.Text, CommandData)
    else
      Result := tvItems.Items.AddObject(TreeNode, TreeNode.Text, CommandData);

    if TreeNode.ImageIndex <= 0 then
      ImageIndex := TreeNode.ImageIndex
    else
    begin
      Icon := TIcon.Create;
      try
        TreeImageList.GetIcon(TreeNode.ImageIndex, Icon);
        ImageIndex := TreeImageList.AddIcon(Icon);
      finally
        Icon.Free;
      end;
    end;
    Result.ImageIndex := ImageIndex;
    Result.SelectedIndex := ImageIndex;
    ChildTreeNode := TreeNode.GetFirstChild;
    while Assigned(ChildTreeNode) do
    begin
      CopyTreeNode(ChildTreeNode, Result);
      ChildTreeNode := ChildTreeNode.GetNextSibling;
    end;
    Result.Expanded := TreeNode.Expanded;
  end;

var
  SelectedNode: TTreeNode;
begin
  SelectedNode := tvItems.Selected;
  if not Assigned(SelectedNode) then
    Exit;
  if not frmCommandConfig.SaveAssigned then
  begin
    frmCommandConfig.SetFocus;
    Exit;
  end;
  tvItems.Items.BeginUpdate;
  try
    tvItems.Selected := CopyTreeNode(SelectedNode, nil);
  finally
    tvItems.Items.EndUpdate;
  end;
  IsModified := True;
end;

procedure TfrmConfig.actCopyUpdate(Sender: TObject);
var
  HasSelection: Boolean;
begin
  HasSelection := Assigned(tvItems.Selected);
  TAction(Sender).Enabled := HasSelection;
  frmCommandConfig.Enabled := HasSelection;
end;

procedure TfrmConfig.actItemDownExecute(Sender: TObject);
begin
  if (not Assigned(tvItems.Selected)) or
    (not Assigned(tvItems.Selected.GetNextSibling)) then
    Exit;
  tvItems.Selected.GetNextSibling.MoveTo(tvItems.Selected, naInsert);
  IsModified := True;
end;

procedure TfrmConfig.actItemDownUpdate(Sender: TObject);
begin
  actItemDown.Enabled := Assigned(tvItems.Selected) and
    Assigned(tvItems.Selected.GetNextSibling);
end;

procedure TfrmConfig.actItemUpExecute(Sender: TObject);
begin
  if (not Assigned(tvItems.Selected)) or
    (not Assigned(tvItems.Selected.GetPrevSibling)) then
    Exit;
  tvItems.Selected.MoveTo(tvItems.Selected.GetPrevSibling, naInsert);
  IsModified := True;
end;

procedure TfrmConfig.actItemUpUpdate(Sender: TObject);
begin
  actItemUp.Enabled := Assigned(tvItems.Selected) and
    Assigned(tvItems.Selected.GetPrevSibling);
end;

procedure TfrmConfig.actOKExecute(Sender: TObject);
begin
  if not frmCommandConfig.SaveAssigned then
    Exit;
  actApplyExecute(actApply);
  Hide;
end;

procedure TfrmConfig.btnOptionsClick(Sender: TObject);
var
  PopupPoint: TPoint;
begin
  PopupPoint := btnOptions.ClientToScreen(Types.Point(0, btnOptions.Height));
  btnOptions.PopupMenu.Popup(PopupPoint.X, PopupPoint.Y);
end;

procedure TfrmConfig.CorrectTreeViewItemHeight;
var
  ItemHeight: Integer;
begin
  ItemHeight := gMenuItemBmpHeight;
  if Odd(ItemHeight) then
    Inc(ItemHeight, 3)
  else
    Inc(ItemHeight, 2);
  SendMessage(tvItems.Handle, TVM_SETITEMHEIGHT, ItemHeight, 0);
end;

procedure TfrmConfig.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not Application.Terminated then
  begin
    Action := caNone;
    actCloseExecute(actClose);
  end;
end;

procedure TfrmConfig.FormConstrainedResize(Sender: TObject;
  var MinWidth, MinHeight, MaxWidth, MaxHeight: Integer);
begin
  MinWidth := cMinFormWidth;
  MinHeight := cMinFormHeight;
end;

procedure TfrmConfig.FormCreate(Sender: TObject);
var
  Reg: TRegistry;
begin
  MainIniFile := nil;
  MouseButtonSwapped := GetSystemMetrics(SM_SWAPBUTTON) <> 0;
  ShowMsgIfDebug('MouseButtonSwapped',
    BoolToStr(MouseButtonSwapped, True));

  frmCommandConfig := TfrmCommandConfig.Create(Self);
  frmCommandConfig.Name := 'frmCommandConfig';
  frmCommandConfig.Parent := gbProperties;
  frmCommandConfig.Align := alClient;

  ppTrayMenu := TMPPopupMenu.Create(Self);
  ppTrayMenu.Images := TreeImageList;
  ppTrayMenu.OnItemMiddleClick := ppTrayMenuItemMiddleClick;
  ppTrayMenu.OnItemRightClick := ppTrayMenuItemRightClick;
  ppTrayMenu.OnQueryItemMissing := ppTrayMenuQueryItemMissing;

  TrayIcon.PopUpMenu := nil;
  TrayIcon.Icon.Assign(Application.Icon);
  gMenuItemBmpWidth := GetSystemMetrics(SM_CXSMICON);
  gMenuItemBmpHeight := GetSystemMetrics(SM_CYSMICON);
  TreeImageList.Width := gMenuItemBmpWidth;
  TreeImageList.Height := gMenuItemBmpHeight;
  ListDeletedImageIndexes := TImageIndexList.Create;
  frmCommandConfig.ListDeletedImageIndexes := ListDeletedImageIndexes;
  frmCommandConfig.TreeImageList := TreeImageList;
  ReloadData;

  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    miOptionsRunAtStart.Checked :=
      Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Run') and
      Reg.ValueExists('StartFromTray');
  finally
    Reg.Free;
  end;
  IsModified := False;
  WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');
end;

destructor TfrmConfig.Destroy;
var
  I: Integer;
begin
  if Assigned(ppTrayMenu) then
    ppTrayMenu.Items.Clear;
  DisposeAllTreeData;
  ListDeletedImageIndexes.Free;
  inherited Destroy;
end;

procedure TfrmConfig.FormHide(Sender: TObject);
begin
  if Application.Terminated then
    Exit;
  Application.Title := TrayIcon.Hint;
  SaveFormProperties;
end;

procedure TfrmConfig.FormShow(Sender: TObject);
begin
  Application.Title := TrayIcon.Hint + ' - ' + Caption;
  UpdateLblVerLeftAndCaption;
  tvItems.SetFocus;
end;

procedure TfrmConfig.lblVerClick(Sender: TObject);
var
  WideVerb, WideLink: UnicodeString;
begin
  WideVerb := 'open';
  WideLink := 'https://github.com/avmaksimov/StartFromTray/releases';
  ShellExecuteW(Handle, PWideChar(WideVerb), PWideChar(WideLink), nil, nil,
    SW_SHOWNORMAL);
end;

procedure TfrmConfig.MyFormShow;
var
  WasMinimized: Boolean;
  RestoreState: TWindowState;
begin
  WasMinimized := WindowState = wsMinimized;
  RestoreState := FWindowStateBeforeMinimize;

  Show;

  if WasMinimized then
    WindowState := RestoreState;

  BringToFront;
end;

procedure TfrmConfig.ExitProgram;
begin
  if IsModified or frmCommandConfig.IsModified then
  begin
    MyFormShow;

    if not AskForConfirmation(Self,
      GetLangString('LangStrings', 'CancelConfirm')) then
      Exit;
  end;

  SaveFormProperties;
  TrayIcon.Visible := False;
  Application.Terminate;
end;

procedure TfrmConfig.miOptionsExitProgramClick(Sender: TObject);
begin
  ExitProgram;
end;

procedure TfrmConfig.miOptionsExtensionsClick(Sender: TObject);
begin
  frmExtensions.ShowModal;
end;

procedure TfrmConfig.miOptionsLangClick(Sender: TObject);
var
  MenuItem: TLangMenuItem;
begin
  MenuItem := TLangMenuItem(Sender);
  SetLang(MenuItem.LangCode, MainIniFile);
  if Visible then
    UpdateLblVerLeftAndCaption;
  MenuItem.Checked := True;
end;

procedure TfrmConfig.miOptionsRunAtStartClick(Sender: TObject);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True) then
      if miOptionsRunAtStart.Checked then
        Reg.WriteString('StartFromTray', '"' + ParamStr(0) + '"')
      else if Reg.ValueExists('StartFromTray') then
        Reg.DeleteValue('StartFromTray');
  finally
    Reg.Free;
  end;
end;

procedure TfrmConfig.ppCMConfigClick(Sender: TObject);
begin
  MyFormShow;
end;

procedure TfrmConfig.ppCMExitClick(Sender: TObject);
begin
  ExitProgram;
end;

function TfrmConfig.ppTrayMenuQueryItemMissing(Item: TMenuItem): Boolean;
var
  CommandData: TCommandData;
begin
  Result := False;
  if (not Assigned(Item)) or not (Item is TMPMenuItem) or
     (TMPMenuItem(Item).Data = nil) or (Item.Count > 0) then
       Exit;

  CommandData := TCommandData(TMPMenuItem(Item).Data);
  Result := (not CommandData.isGroup) and
    (CommandData.ExtendCommandToFullName = '');
end;

function TfrmConfig.GetTrayMenuPoint: TPoint;
var
  Identifier: TNotifyIconIdentifierEx;
  IconRect: TRect;
begin
  { Запасной вариант — приблизительная позиция LCL. }
  Result := TrayIcon.GetPosition;

  //FillChar(Identifier{%H-}, SizeOf(Identifier), 0);
  Identifier.guidItem := Default(TGUID);
  Identifier.cbSize := SizeOf(Identifier);
  Identifier.hWnd := TrayIcon.Handle;
  Identifier.uID := cLCLTrayIconID;


  if (TrayIcon.Handle <> 0) and
     (M_Shell_NotifyIconGetRect(@Identifier, @IconRect) = 0) then
    Result := Types.Point(
      (IconRect.Left + IconRect.Right) div 2,
      (IconRect.Top + IconRect.Bottom) div 2
    );
end;

procedure TfrmConfig.TrayIconMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SetForegroundWindow(Handle);
  PostMessage(Handle, WM_NULL, 0, 0);
  ppTrayMenu.Close;
  case Button of
    mbLeft:
      ppTrayMenu.Popup(X, Y);
    mbMiddle:
      begin
        MyFormShow;
        if frmExtensions.Visible then
          frmExtensions.SetFocus;
      end;
    mbRight:
      ppConfigMenu.Popup(X, Y);
  end;
end;

procedure TfrmConfig.TreeToMenu(ATreeNodes: TTreeNodes;
  AMenuItems: TMenuItem; const NotifyEvent: TNotifyEvent);

  procedure ProcessTreeItem(TreeNode: TTreeNode; ParentItem: TMenuItem);
  var
    MenuItem: TMPMenuItem;
    ChildNode: TTreeNode;
  begin
    MenuItem := TMPMenuItem.Create(ppTrayMenu);
    MenuItem.Caption := TreeNode.Text;
    MenuItem.ImageIndex := TreeNode.ImageIndex;
    MenuItem.Data := TreeNode.Data;
    MenuItem.OnClick := NotifyEvent;
    ParentItem.Add(MenuItem);
    ChildNode := TreeNode.GetFirstChild;
    while Assigned(ChildNode) do
    begin
      ProcessTreeItem(ChildNode, MenuItem);
      ChildNode := ChildNode.GetNextSibling;
    end;
  end;

var
  TreeNode: TTreeNode;
begin
  TreeNode := ATreeNodes.GetFirstNode;
  while Assigned(TreeNode) do
  begin
    ProcessTreeItem(TreeNode, AMenuItems);
    TreeNode := TreeNode.GetNextSibling;
  end;
end;

procedure TfrmConfig.tvItemsChange(Sender: TObject; Node: TTreeNode);
begin
  if Assigned(Node) then
    frmCommandConfig.Assign(Node)
  else
    frmCommandConfig.ClearAssigned;
end;

procedure TfrmConfig.tvItemsChanging(Sender: TObject; Node: TTreeNode;
  var AllowChange: Boolean);
begin
  if Assigned(tvItems.Selected) and Assigned(Node) and (not Node.Deleting) then
  begin
    if frmCommandConfig.IsModified then
      IsModified := True;
    AllowChange := frmCommandConfig.SaveAssigned;
  end;
end;

procedure TfrmConfig.tvItemsCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  if (not Assigned(Node.Data)) or TCommandData(Node.Data).isGroup or
    ((Node = frmCommandConfig.AssignedTreeNode) and
      frmCommandConfig.CheckFileCommandExists) or
    ((Node <> frmCommandConfig.AssignedTreeNode) and
      (TCommandData(Node.Data).ExtendCommandToFullName <> '')) then
    Sender.Canvas.Font.Style := []
  else
  begin
    Sender.Canvas.Font.Style := [fsStrikeOut];
    Sender.Canvas.Font.Color := clWindowText;
  end;
end;

procedure TfrmConfig.tvItemsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  AttachMode: TNodeAttachMode;
  TargetNode: TTreeNode;
begin
  if (Source <> Sender) or (Sender <> tvItems) or
    (not Assigned(tvItems.Selected)) then
    Exit;
  TargetNode := tvItems.GetNodeAt(X, Y);
  if TargetNode = tvItems.Selected then
    Exit;

  if not Assigned(TargetNode) then
    if Y > 0 then
      AttachMode := naAdd
    else
      AttachMode := naAddFirst
  else if TCommandData(TargetNode.Data).isGroup then
    AttachMode := naAddChild
  else
  begin
    AttachMode := naInsert;
    if tvItems.Selected.Top < Y then
      TargetNode := TargetNode.GetNextSibling;
  end;

  if not frmCommandConfig.SaveAssigned then
  begin
    frmCommandConfig.SetFocus;
    Exit;
  end;

  tvItems.Selected.MoveTo(TargetNode, AttachMode);
  IsModified := True;
end;

procedure TfrmConfig.tvItemsDragOver(Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Sender = Source) and (Sender = tvItems);
end;

procedure TfrmConfig.tvItemsEdited(Sender: TObject; Node: TTreeNode;
  var S: string);
begin
  if Node.Text <> S then
  begin
    frmCommandConfig.Caption := S;
    IsModified := True;
  end;
end;

procedure TfrmConfig.UpdateLblVerLeftAndCaption;

  function GetBuildInfo: string;
  var
    VerInfoSize, Dummy: DWORD;
    VerValueSize: UINT;
    VerInfo, VerValuePointer: Pointer;
    VerValue: PVSFixedFileInfo;
    WideFileName: UnicodeString;
    SubBlock: UnicodeString;
  begin
    Result := '';
    WideFileName := UTF8Decode(ParamStr(0));
    SubBlock := '\';
    Dummy := 0;
    VerInfoSize := GetFileVersionInfoSizeW(PWideChar(WideFileName), Dummy);
    if VerInfoSize = 0 then
      Exit;
    GetMem(VerInfo, VerInfoSize);
    try
      VerValuePointer := nil;
      VerValueSize := 0;
      if GetFileVersionInfoW(PWideChar(WideFileName), 0, VerInfoSize,
        VerInfo) and VerQueryValueW(VerInfo, PWideChar(SubBlock),
        VerValuePointer, VerValueSize) and Assigned(VerValuePointer) then
      begin
        VerValue := PVSFixedFileInfo(VerValuePointer);
        Result := IntToStr(VerValue^.dwFileVersionMS shr 16) + '.' +
          IntToStr(VerValue^.dwFileVersionMS and $FFFF) + '.' +
          IntToStr(VerValue^.dwFileVersionLS and $FFFF);
      end;
    finally
      FreeMem(VerInfo);
    end;
  end;

begin
  Application.Title := TrayIcon.Hint + ' - ' + Caption;
  lblVer.Caption := GetLangString(Name, 'Version') + ' ' + GetBuildInfo;
end;

procedure TfrmConfig.FormWindowStateChange(Sender: TObject);
begin
  if WindowState in [wsNormal, wsMaximized] then
    FWindowStateBeforeMinimize := WindowState;
end;

procedure TfrmConfig.RestoreFormProperties;

  function RectsIntersect(const A, B: TRect): Boolean;
  begin
    Result :=
      (A.Left < B.Right) and
      (A.Right > B.Left) and
      (A.Top < B.Bottom) and
      (A.Bottom > B.Top);
  end;

var
  SavedLeft, SavedTop: Integer;
  SavedWidth, SavedHeight: Integer;
  SavedState: Integer;
  NewLeft, NewTop: Integer;
  WorkWidth, WorkHeight: Integer;
  I: Integer;
  SavedRect, WorkArea: TRect;
  TargetMonitor: Forms.TMonitor;
  HasSavedPosition, PositionIsVisible: Boolean;
begin
  if not Assigned(MainIniFile) then
    Exit;

  SavedWidth := MainIniFile.ReadInteger(
    cIniFormIdent, cIniFormWidth, Width);
  SavedHeight := MainIniFile.ReadInteger(
    cIniFormIdent, cIniFormHeight, Height);

  { Защищаемся от повреждённых или вручную изменённых размеров. }
  if (SavedWidth < cMinFormWidth) or
     (SavedWidth > Screen.DesktopWidth) then
    SavedWidth := cMinFormWidth;

  if (SavedHeight < cMinFormHeight) or
     (SavedHeight > Screen.DesktopHeight) then
    SavedHeight := cMinFormHeight;

  SavedState := MainIniFile.ReadInteger(
    cIniFormIdent, cIniFormState, Integer(wsNormal));

  HasSavedPosition :=
    MainIniFile.ValueExists(cIniFormIdent, cIniFormLeft) and
    MainIniFile.ValueExists(cIniFormIdent, cIniFormTop);

  PositionIsVisible := False;

  if HasSavedPosition then
  begin
    SavedLeft := MainIniFile.ReadInteger(
      cIniFormIdent, cIniFormLeft, Left);
    SavedTop := MainIniFile.ReadInteger(
      cIniFormIdent, cIniFormTop, Top);

    { Не допускаем переполнения при построении прямоугольника. }
    if (Int64(SavedLeft) + SavedWidth <= High(Integer)) and
       (Int64(SavedTop) + SavedHeight <= High(Integer)) then
    begin
      SavedRect := Types.Rect(
        SavedLeft,
        SavedTop,
        Integer(Int64(SavedLeft) + SavedWidth),
        Integer(Int64(SavedTop) + SavedHeight)
      );

      for I := 0 to Screen.MonitorCount - 1 do
        if RectsIntersect(
          SavedRect, Screen.Monitors[I].WorkareaRect) then
        begin
          PositionIsVisible := True;
          Break;
        end;
    end;
  end;

  if PositionIsVisible then
    TargetMonitor := Screen.MonitorFromRect(SavedRect)
  else
    TargetMonitor := Screen.PrimaryMonitor;

  WorkArea := TargetMonitor.WorkareaRect;
  WorkWidth := WorkArea.Right - WorkArea.Left;
  WorkHeight := WorkArea.Bottom - WorkArea.Top;

  { Если разрешение уменьшилось, уменьшаем форму до рабочей области. }
  if SavedWidth > WorkWidth then
    SavedWidth := WorkWidth;

  if SavedHeight > WorkHeight then
    SavedHeight := WorkHeight;

  if PositionIsVisible then
  begin
    NewLeft := SavedLeft;
    NewTop := SavedTop;
  end
  else
  begin
    { Первый запуск или исчезнувший монитор — центр основного экрана. }
    NewLeft := WorkArea.Left + (WorkWidth - SavedWidth) div 2;
    NewTop := WorkArea.Top + (WorkHeight - SavedHeight) div 2;
  end;

  { Полностью возвращаем форму в рабочую область монитора. }
  if NewLeft < WorkArea.Left then
    NewLeft := WorkArea.Left;

  if Int64(NewLeft) + SavedWidth > WorkArea.Right then
    NewLeft := WorkArea.Right - SavedWidth;

  if NewTop < WorkArea.Top then
    NewTop := WorkArea.Top;

  if Int64(NewTop) + SavedHeight > WorkArea.Bottom then
    NewTop := WorkArea.Bottom - SavedHeight;

  Position := poDesigned;
  WindowState := wsNormal;

  SetRestoredBounds(
    NewLeft,
    NewTop,
    SavedWidth,
    SavedHeight,
    False
  );

  { Свёрнутым окно никогда не восстанавливаем. }
  if SavedState = Integer(wsMaximized) then
    WindowState := wsMaximized;
end;

procedure TfrmConfig.Initialize(const AMainIniFile: TIniFile);
begin
  if Assigned(MainIniFile) then
    Exit;

  if not Assigned(AMainIniFile) then
    raise Exception.Create('Main INI file is not assigned.');

  MainIniFile := AMainIniFile;
  RestoreFormProperties;
end;

procedure TfrmConfig.WndProc(var Message: TLMessage);
var
  PopupPoint: TPoint;
begin
  if (WM_SHOWTRAYMENU > 0) and
     (Message.Msg = WM_SHOWTRAYMENU) then
  begin
    if ppTrayMenu.Items.Count > 0 then
    begin
      PopupPoint := GetTrayMenuPoint;
      TrayIconMouseUp(
        TrayIcon,
        mbLeft,
        [],
        PopupPoint.X,
        PopupPoint.Y
      );
    end
    else
      MyFormShow;

    Message.Result := 0;
    Exit;
  end;

  if (WM_TASKBARCREATED > 0) and
     (Message.Msg = WM_TASKBARCREATED) then
  begin
    WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');
    try
      TrayIcon.Visible := False;
    except
    end;
    TrayIcon.Visible := True;
  end;

  inherited WndProc(Message);
end;

procedure TfrmConfig.DisposeTreeNodeData(TreeNode: TTreeNode;
  const AddToDeletedImages: Boolean);
var
  ChildNode, NextChild: TTreeNode;
  CommandData: TCommandData;
begin
  if not Assigned(TreeNode) then
    Exit;
  ChildNode := TreeNode.GetFirstChild;
  while Assigned(ChildNode) do
  begin
    NextChild := ChildNode.GetNextSibling;
    DisposeTreeNodeData(ChildNode, AddToDeletedImages);
    ChildNode := NextChild;
  end;
  if Assigned(TreeNode.Data) then
  begin
    CommandData := TCommandData(TreeNode.Data);
    TreeNode.Data := nil;
    CommandData.Free;
    if AddToDeletedImages and (TreeNode.ImageIndex > 0) then
      ListDeletedImageIndexes.Add(TreeNode.ImageIndex);
  end;
end;

procedure TfrmConfig.DisposeAllTreeData;
var
  Node, NextNode: TTreeNode;
begin
  if not Assigned(tvItems) then
    Exit;
  Node := tvItems.Items.GetFirstNode;
  while Assigned(Node) do
  begin
    NextNode := Node.GetNextSibling;
    DisposeTreeNodeData(Node, False);
    Node := NextNode;
  end;
end;

procedure TfrmConfig.ppTrayMenuItemOnClick(Sender: TObject);
var
  MenuItem: TMPMenuItem;
  CommandData: TCommandData;
begin
  MenuItem := TMPMenuItem(Sender);
  if MenuItem.Count <> 0 then
    Exit;

  CommandData := TCommandData(MenuItem.Data);
  if not MouseButtonSwapped then
    CommandData.Run(crtNormalRun)
  else
    CommandData.Edit;
end;

procedure TfrmConfig.ppTrayMenuItemMiddleClick(Item: TMenuItem);
var
  I: Integer;
  MenuItem: TMPMenuItem;
begin
  if not (Item is TMPMenuItem) then
    Exit;

  MenuItem := TMPMenuItem(Item);

  if MenuItem.Data = nil then
    Exit;

  MyFormShow;

  for I := 0 to tvItems.Items.Count - 1 do
    if tvItems.Items[I].Data = MenuItem.Data then
    begin
      tvItems.Selected := tvItems.Items[I];
      tvItems.Items[I].MakeVisible;
      Exit;
    end;
end;

procedure TfrmConfig.ppTrayMenuItemRightClick(Item: TMenuItem);
var
  CommandData: TCommandData;
begin
  if not (Item is TMPMenuItem) or (Item.Count <> 0) then
    Exit;

  CommandData := TCommandData(TMPMenuItem(Item).Data);
  if not MouseButtonSwapped then
    CommandData.Edit
  else
    CommandData.Run(crtNormalRun);
end;

procedure TfrmConfig.ReloadData;

  procedure XMLToTree(TreeNodes: TTreeNodes);
  var
    XMLDoc: TXMLDocument;
    Node: TDOMNode;
    IconIndex: Word;
    IconPath: array[0..MAX_PATH] of Char;
    FolderIcon: HICON;
    FolderIconImage: TIcon;

    procedure ProcessNode(Element: TDOMElement; ParentNode: TTreeNode);
    var
      TreeNode: TTreeNode;
      CommandData: TCommandData;
      ChildNode: TDOMNode;
      ImageIndex: Integer;
    begin
      CommandData := TCommandData.Create;
      try
        CommandData.AssignFrom(Element);
        TreeNode := TreeNodes.AddChildObject(ParentNode,
          GetPropertyFromNodeAttributes(Element, 'Caption'), CommandData);
      except
        CommandData.Free;
        raise;
      end;
      ChildNode := Element.FirstChild;
      while Assigned(ChildNode) do
      begin
        if ChildNode.NodeType = ELEMENT_NODE then
          ProcessNode(TDOMElement(ChildNode), TreeNode);
        ChildNode := ChildNode.NextSibling;
      end;
      ImageIndex := CommandData.GetImageIndex(TreeImageList);
      TreeNode.ImageIndex := ImageIndex;
      TreeNode.SelectedIndex := ImageIndex;
    end;

  begin
    IconIndex := 3;
    IconPath[0] := #0;
    StrPLCopy(PChar(@IconPath[0]), 'SHELL32.dll', High(IconPath));
    FolderIcon := ExtractAssociatedIcon(HInstance,
      PChar(@IconPath[0]), @IconIndex);
    if FolderIcon <> 0 then
    begin
      FolderIconImage := TIcon.Create;
      try
        FolderIconImage.Handle := FolderIcon;
        TreeImageList.AddIcon(FolderIconImage);
      finally
        FolderIconImage.Free;
      end;
    end;

    if not FileExists(ExtractFilePath(ParamStr(0)) + cItemsFileName) then
      Exit;
    ReadXMLFile(XMLDoc, ExtractFilePath(ParamStr(0)) + cItemsFileName);
    try
      if not Assigned(XMLDoc.DocumentElement) then
        Exit;
      Node := XMLDoc.DocumentElement.FirstChild;
      while Assigned(Node) do
      begin
        if Node.NodeType = ELEMENT_NODE then
          ProcessNode(TDOMElement(Node), nil);
        Node := Node.NextSibling;
      end;
    finally
      XMLDoc.Free;
    end;
    tvItems.FullExpand;
  end;

begin
  XMLToTree(tvItems.Items);
  ListDeletedImageIndexes.Clear;
  TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick);
  if tvItems.Items.Count > 0 then
  begin
    CorrectTreeViewItemHeight;
    tvItems.Selected := tvItems.Items.GetFirstNode;
  end
  else
    frmCommandConfig.ClearAssigned;
end;

procedure TfrmConfig.SaveFormProperties;
var
  StateToSave: TWindowState;
begin
  if not Assigned(MainIniFile) then
    Exit;

  StateToSave := WindowState;
  if StateToSave = wsMinimized then
    StateToSave := FWindowStateBeforeMinimize;

  MainIniFile.WriteInteger(cIniFormIdent, cIniFormState,
    Integer(StateToSave));

  if WindowState = wsNormal then
  begin
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormLeft, Left);
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormTop, Top);
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormWidth, Width);
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormHeight, Height);
  end
  else
  begin
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormLeft, RestoredLeft);
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormTop, RestoredTop);
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormWidth, RestoredWidth);
    MainIniFile.WriteInteger(cIniFormIdent, cIniFormHeight, RestoredHeight);
  end;
end;

end.
