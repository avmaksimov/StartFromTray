unit frmConfig_U;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ComCtrls, ExtCtrls, Menus, StdCtrls, ActnList, registry,
  CommandsClass_U, windows, Messages,   TypInfo, System.Actions,
  Vcl.ImgList, frmCommandConfig_U, MPPopupMenu,
  Winapi.CommCtrl, System.Math, System.ImageList, Vcl.TitleBarCtrls,
  System.Generics.Collections;

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
    lblVer: TLinkLabel;
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
    procedure btnDelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ppCMConfigClick(Sender: TObject);
    procedure ppCMExitClick(Sender: TObject);
    procedure tvItemsChange(Sender: TObject; Node: TTreeNode);
    procedure tvItemsChanging(Sender: TObject; Node: TTreeNode;
      var AllowChange: Boolean);
    procedure tvItemsDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure tvItemsEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure TrayIconMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure tvItemsDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure ppTrayMenuItemMiddleClick(Item: TMenuItem);
    procedure ppTrayMenuItemRightClick(Item: TMenuItem);
    procedure actCopyExecute(Sender: TObject);
    procedure tvItemsCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure FormHide(Sender: TObject);
    procedure lblVerLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
    procedure TitleBarPanelCustomButtons0Click(Sender: TObject);
    procedure FormConstrainedResize(Sender: TObject; var MinWidth, MinHeight,
      MaxWidth, MaxHeight: Integer);
    procedure miOptionsExitProgramClick(Sender: TObject);
    procedure btnOptionsClick(Sender: TObject);
    procedure miOptionsRunAtStartClick(Sender: TObject);
    procedure miOptionsExtensionsClick(Sender: TObject);
  private
    { private declarations }
    gMenuItemBmpWidth, gMenuItemBmpHeight: integer;

    IsModified: Boolean;
    // IsTreeViewItemChanging: Boolean; // true if list changing

    MouseButtonSwapped: Boolean;

    ppTrayMenu: TMPPopupMenu;

    //procedure UpdateTreeNodeIcon(const ATreeNode: TTreeNode);
    procedure CorrectTreeViewItemHeight;

    //function CopyTreeNode(TreeNode: TTreeNode; ParentTreeNode: TTreeNode = nil): TTreeNode;
    procedure DisposeTreeViewData;
    procedure DisposeTreeNodeData(TreeNode: TTreeNode);

    procedure ppTrayMenuItemOnClick(Sender: TObject);
    // procedure XMLToMenu(MenuItems: TMenuItem; const NotifyEvent: TNotifyEvent);
    procedure XMLToTree(TreeNodes: TTreeNodes);
    procedure TreeToMenu(ATreeNodes: TTreeNodes; AMenuItems: TMenuItem;
      const NotifyEvent: TNotifyEvent);//; AOldCommonDataList: TList);
    // it can't be updated because Width for Autosize can't be evaluated when Form is not Visible
    procedure UpdateLblVerLeftAndCaption;
    // due to don't terminate the App after close main window
    procedure WMClose(var Message: TMessage); message WM_CLOSE;
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    { public declarations }
    ListDeletedImageIndexes: TList<Word>;
    procedure miOptionsLangClick(Sender: TObject);
    //procedure TreeImageListRemoveIndexProperly(const AIndex: Integer);
  end;

var
  frmConfig: TfrmConfig;

  WM_TASKBARCREATED: UINT = 0;

implementation

uses CommonU, frmExtensions_U, FilterClass_U, LangsU, XMLDoc, XMLIntf,
  Winapi.ShellAPI, System.IniFiles, System.Types, System.UITypes;

{$R *.dfm}
{ TfrmConfig }

procedure TfrmConfig.actApplyExecute(Sender: TObject);
begin
  // сохраним редактируемые данные
  if not frmCommandConfig.SaveAssigned then
    Exit;

  TreeToXML(tvItems.Items); // заполнение RunAtTime здесь

  ppTrayMenu.Items.Clear;

  TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick); //, oldCommonData);

  IsModified := False;
end;

procedure TfrmConfig.actAddElementExecute(Sender: TObject);
begin
  if frmCommandConfig.SaveAssigned then
    begin
    var vTag := (Sender as TAction).Tag; // -1 for Element and 0 for Group
    var vComData := TCommandData.Create;
    vComData.isGroup := (vTag = 0);
    tvItems.Selected := tvItems.Items.AddObject(tvItems.Selected, '', vComData);

    tvItems.Selected.ImageIndex := vTag;
    tvItems.Selected.SelectedIndex := vTag;

    if tvItems.Items.Count = 1 then // first adding
      CorrectTreeViewItemHeight;

    tvItems.Repaint;

    IsModified := True;
    end;

  frmCommandConfig.edtCaption.SetFocus;
end;

procedure TfrmConfig.actApplyUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := IsModified or frmCommandConfig.IsModified;
end;

procedure TfrmConfig.actCloseExecute(Sender: TObject);
begin
  if (IsModified or frmCommandConfig.IsModified) then
  begin
    if AskForConfirmation(Self, GetLangString('LangStrings', 'CancelConfirm'))
    then
    begin //Cancel
      Hide;

      ppTrayMenu.Items.Clear; // Data will be cleared below

      DisposeTreeViewData;
      frmCommandConfig.ClearAssigned;//Assign(nil);
      tvItems.OnChange := nil;
      tvItems.Items.Clear;
      tvItems.OnChange := tvItemsChange;
      //frmCommandConfig.ClearAssigned;//Assign(nil);
      TreeImageList.Clear;
      IsModified := False;

      // перечитать из файла
      XMLToTree(tvItems.Items);

      TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick);//, nil);

      // если первый элемент есть, то эмулируем его Change
      { if tvItems.Items.Count > 1 then
        tvItemsChange(tvItems, tvItems.Items[0]); }
    end
  end
  else
  begin
    Hide;
  end;
  { else
    begin
    Hide;
    Application.Title := TrayIcon.Hint; //'Quick run from Tray';
    end; }
end;

procedure TfrmConfig.actCloseUpdate(Sender: TObject);
begin
  if IsModified or frmCommandConfig.IsModified then
    actClose.Caption := GetLangString('LangStrings', 'Cancel') // 'Cancel'
  else
    actClose.Caption := GetLangString('LangStrings', 'Close'); // 'Close';
end;

procedure TfrmConfig.actDelExecute(Sender: TObject);
var
  futureSelNode: TTreeNode;
  //needToUpdateIsGroup: Boolean;
begin
  if Assigned(tvItems.Selected) and AskForDeletion(Self, tvItems.Selected.Text)
  then
  begin
    //needToUpdateIsGroup := False;
    try
    tvItems.Items.BeginUpdate;
    DisposeTreeNodeData(tvItems.Selected);

    // определим, что оставить выделенным
    futureSelNode := tvItems.Selected.GetNextSibling;
    // попробуем выделить следующий элемент того же уровня
    if futureSelNode = nil then
    begin
      futureSelNode := tvItems.Selected.GetPrevSibling;
      // попробуем выделить предыдущий элемент того же уровня
      if futureSelNode = nil then
      begin
        futureSelNode := tvItems.Selected.Parent;
        // тогда пробуем выделить родителя
        if futureSelNode = nil then
          futureSelNode := tvItems.TopItem // пробуем выделить самый верхний
        //else // если есть родитель, то надо проверить его свойство группы
         // needToUpdateIsGroup := True;
        // TCommandData(futureSelNode).isGroup := futureSelNode.HasChildren;
      end;
    end;
    frmCommandConfig.ClearAssigned;//Assign(nil);
    // avoid possible bug and better empty view for properties
    tvItems.Selected.Delete;

    tvItems.Selected := futureSelNode;
    finally
      tvItems.Items.EndUpdate;
    end;

    IsModified := True;
  end;
end;

procedure TfrmConfig.actCopyExecute(Sender: TObject);
  function CopyTreeNode(TreeNode: TTreeNode; ParentTreeNode: TTreeNode = nil): TTreeNode;
  begin
  var vCommandData := TCommandData.Create;
  TCommandData(TreeNode.Data).Assign(vCommandData);

  if ParentTreeNode = nil then
    Result := tvItems.Items.AddObject(TreeNode, TreeNode.Text, vCommandData)
  else
    Result := tvItems.Items.AddChildObject(ParentTreeNode, TreeNode.Text, vCommandData);

  var vImageIndex: Integer;
  // 0 for group, -1 for undef element
  if TreeNode.ImageIndex <= 0 then
    vImageIndex := TreeNode.ImageIndex
  else
    begin
    var vIcon := TIcon.Create;
    try
      TreeImageList.GetIcon(TreeNode.ImageIndex, vIcon);
      vImageIndex := TreeImageList.AddIcon(vIcon);
    finally
      vIcon.Free;
    end; //try..finaly
    end;
  Result.ImageIndex := vImageIndex;
  Result.SelectedIndex := vImageIndex;
  // child nodes
  var vChildTreeNode := TreeNode.GetFirstChild;
  while vChildTreeNode <> nil do
    begin
    CopyTreeNode(vChildTreeNode, Result);
    vChildTreeNode := vChildTreeNode.getNextSibling;
    end;

  Result.Expanded := TreeNode.Expanded;
  end;
begin
  var vSelected := tvItems.Selected;
  if not Assigned(vSelected) then
    Exit;

  if frmCommandConfig.SaveAssigned then
    begin
    tvItems.Items.BeginUpdate;
    try
      tvItems.Selected := CopyTreeNode(vSelected, nil);
    finally
      tvItems.Items.EndUpdate;
    end;

    IsModified := True;
    end
  else
    frmCommandConfig.SetFocus;
end;

procedure TfrmConfig.actCopyUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := tvItems.Selected <> nil;
  // gbProperties.Enabled := (tvItems.Selected <> nil);
  frmCommandConfig.Enabled := (tvItems.Selected <> nil);
end;

procedure TfrmConfig.actItemDownExecute(Sender: TObject);
begin
  if (tvItems.Selected = nil) or (tvItems.Selected.GetNextSibling = nil) then
    Exit;

  tvItems.Selected.GetNextSibling.MoveTo(tvItems.Selected, naInsert);
  IsModified := True;
end;

procedure TfrmConfig.actItemDownUpdate(Sender: TObject);
begin
  actItemDown.Enabled := (tvItems.Selected <> nil) and
    (tvItems.Selected.GetNextSibling <> nil);
end;

procedure TfrmConfig.actItemUpExecute(Sender: TObject);
begin
  if (tvItems.Selected = nil) or (tvItems.Selected.GetPrevSibling = nil) then
    Exit;

  tvItems.Selected.MoveTo(tvItems.Selected.GetPrevSibling, naInsert);
  IsModified := True;
end;

procedure TfrmConfig.actItemUpUpdate(Sender: TObject);
begin
  actItemUp.Enabled := (tvItems.Selected <> nil) and
    (tvItems.Selected.GetPrevSibling <> nil);
end;

procedure TfrmConfig.actOKExecute(Sender: TObject);
begin
  actApplyExecute(actApply);
  Hide;
end;

procedure TfrmConfig.btnDelClick(Sender: TObject);
begin
  if tvItems.Selected <> nil then
    tvItems.Items.Delete(tvItems.Selected);
end;

procedure TfrmConfig.btnOptionsClick(Sender: TObject);
begin
 with btnOptions.ClientToScreen(point(0, btnOptions.Height)) do
    btnOptions.PopupMenu.Popup(X, Y);
end;

procedure TfrmConfig.CorrectTreeViewItemHeight;
begin
  TreeView_SetItemHeight(tvItems.Items[0].Handle, gMenuItemBmpHeight +
    IfThen(Odd(gMenuItemBmpHeight), 3, 2));
end;

procedure TfrmConfig.FormConstrainedResize(Sender: TObject; var MinWidth,
  MinHeight, MaxWidth, MaxHeight: Integer);
begin
  MinWidth := 808;
  MinHeight := 525;
end;

procedure TfrmConfig.FormCreate(Sender: TObject);
begin
  MouseButtonSwapped := GetSystemMetrics(SM_SWAPBUTTON) <> 0;

  ShowMsgIfDebug('MouseButtonSwapped', BoolToStr(MouseButtonSwapped, True));

  ppTrayMenu := TMPPopupMenu.Create(Self);
  with ppTrayMenu do
  begin
    Images := TreeImageList;
    //OwnerDraw := True;
    OnItemMiddleClick := ppTrayMenuItemMiddleClick;
    OnItemRightClick := ppTrayMenuItemRightClick;
  end;

  // if not Swapped then tbRightButton else tbLeftButton
  // ppTrayMenu.TrackButton := TTrackButton(MouseButtonSwapped);
  ppConfigMenu.TrackButton := TTrackButton(MouseButtonSwapped);

  TrayIcon.Icon := Application.Icon;

  gMenuItemBmpWidth := GetSystemMetrics(SM_CXSMICON);//SM_CXMENUCHECK);
  gMenuItemBmpHeight := GetSystemMetrics(SM_CYSMICON);//SM_CYMENUCHECK);
  TreeImageList.Width := gMenuItemBmpWidth;
  TreeImageList.Height := gMenuItemBmpHeight;

  ListDeletedImageIndexes := TList<Word>.Create;
  frmCommandConfig.ListDeletedImageIndexes := ListDeletedImageIndexes;
  frmCommandConfig.TreeImageList := TreeImageList;

  XMLToTree(tvItems.Items);

  TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick);//, nil);

  if tvItems.Items.Count > 0 then
  begin
    CorrectTreeViewItemHeight;
  end
  else
    begin
    frmCommandConfig.ClearAssigned;
    end;

  with TRegistry.Create(KEY_READ) do
    try
      RootKey := HKEY_CURRENT_USER;
      miOptionsRunAtStart.Checked :=
        OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Run') and
          ValueExists('StartFromTray');
      {cbRunOnWindowsStart.Checked :=
        OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Run') and
        ValueExists('StartFromTray');}
      IsModified := False;
    finally
      Free;
    end;

  IsModified := False;

  WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');

end;

procedure TfrmConfig.FormHide(Sender: TObject);
begin
  Application.Title := TrayIcon.Hint;
end;

procedure TfrmConfig.FormShow(Sender: TObject);
begin
  Application.Title := TrayIcon.Hint + ' - ' + Caption;
  UpdateLblVerLeftAndCaption;
  tvItems.SetFocus;
end;

procedure TfrmConfig.lblVerLinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
begin
  ShellExecute(Handle, 'open', PChar(Link), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmConfig.miOptionsExitProgramClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmConfig.miOptionsExtensionsClick(Sender: TObject);
begin
  frmExtensions.ShowModal;
end;

procedure TfrmConfig.miOptionsLangClick(Sender: TObject);
  function _GetBuildInfo: string;
  var
    VerInfoSize, VerValueSize, Dummy: DWORD;
    VerInfo: Pointer;
    VerValue: PVSFixedFileInfo;
  begin
    VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
    if VerInfoSize > 0 then
    begin
        GetMem(VerInfo, VerInfoSize);
        try
          if GetFileVersionInfo(PChar(ParamStr(0)), 0, VerInfoSize, VerInfo) then
          begin
            VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
            with VerValue^ do
            begin
              Result := (dwFileVersionMS shr 16).ToString + '.' +
                (dwFileVersionMS and $FFFF).ToString + '.' +
                (dwFileVersionLS shr 16).ToString + '.' +
                (dwFileVersionLS and $FFFF).ToString;
            end;
          end;
        finally
          FreeMem(VerInfo, VerInfoSize);
        end;
    end;
  end;
begin
  var vMenuItem := TMenuItem(Sender);

  SetLang(StrPas(PChar(vMenuItem.Tag)));
  if Visible then
    UpdateLblVerLeftAndCaption;
  lblVer.Hint := GetLangString(Name, 'VersionHint');

  vMenuItem.Checked := True;
end;

procedure TfrmConfig.miOptionsRunAtStartClick(Sender: TObject);
begin
  with TRegistry.Create(KEY_READ or KEY_WRITE or KEY_SET_VALUE) do
    try
      RootKey := HKEY_CURRENT_USER;
      if OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True) then
        if miOptionsRunAtStart.Checked then
          WriteString('StartFromTray', ParamStr(0))
        else
          DeleteValue('StartFromTray');
    finally
      Free;
    end;
end;

procedure TfrmConfig.ppCMConfigClick(Sender: TObject);
begin
  Show;
end;

procedure TfrmConfig.ppCMExitClick(Sender: TObject);
begin
  Close;
  //Application.Terminate;
end;

procedure TfrmConfig.TitleBarPanelCustomButtons0Click(Sender: TObject);
begin
  Application.Minimize;
end;

procedure TfrmConfig.TrayIconMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // иначе не закрывается по клику в другой области и повторно не открывается
  SetForegroundWindow(Handle);
  PostMessage(Handle, WM_NULL, 0, 0);

  ppTrayMenu.CloseMenu;
  // all right with button swap (so mbLeft may be sometimes as mbRight :) )
  if Button = mbLeft then
  begin
    ppTrayMenu.Popup(X, Y);
  end
  else if Button = mbMiddle then
    begin
    Show;
    ShowWindow(Handle, SW_RESTORE);
    if frmExtensions.Visible then
      begin
      frmExtensions.SetFocus;
      end;
    end;
end;

procedure TfrmConfig.TreeToMenu(ATreeNodes: TTreeNodes; AMenuItems: TMenuItem;
  const NotifyEvent: TNotifyEvent);//; AOldCommonDataList: TList);

  procedure ProcessTreeItem(atn: TTreeNode; ami: TMenuItem);
  var
    newMenuItem: TMPMenuItem;
    vtn: TTreeNode;
  begin
    newMenuItem := TMPMenuItem.Create(AMenuItems);

    with newMenuItem do
    begin
      Caption := atn.Text;
      ImageIndex := atn.ImageIndex;
      Tag := LongInt(atn.Data);
      OnClick := NotifyEvent;
    end;

    ami.Add(newMenuItem);

    // child nodes
    vtn := atn.GetFirstChild;
    while vtn <> nil do
    begin
      ProcessTreeItem(vtn, newMenuItem);
      vtn := vtn.GetNextSibling;
    end;
  end; (* ProcessTreeItem *)

begin

  if ListDeletedImageIndexes.Count > 0 then
    begin
    ListDeletedImageIndexes.Sort;
    try
      ATreeNodes.BeginUpdate;
      for var I := ListDeletedImageIndexes.Count - 1 downto 0 do
        begin
        var vIndex: Integer := Integer(ListDeletedImageIndexes[I]);
        if ImageList_Remove(TreeImageList.Handle, vIndex)then
          for var J := 0 to ATreeNodes.Count - 1 do
            begin
            var vTVItem := ATreeNodes[J];
            if vTVItem.SelectedIndex > vIndex then
              begin
              vTVItem.SelectedIndex := vTVItem.SelectedIndex - 1;
              vTVItem.ImageIndex := vTVItem.SelectedIndex;
              end;
            end;
        end;
      finally
        ListDeletedImageIndexes.Clear;
        ATreeNodes.EndUpdate;
      end;
    end;

  var tn := ATreeNodes.GetFirstNode; // TopNode;
  while tn <> nil do
  begin
    ProcessTreeItem(tn, AMenuItems);

    tn := tn.GetNextSibling;
  end;
end;

procedure TfrmConfig.tvItemsChange(Sender: TObject; Node: TTreeNode);
begin
  // gbProperties.Enabled := True;
  // frmCommandConfig.edtCaption.SetFocus;

  // if (Node <> nil) and (Node.Data <> nil) then
  begin
    // IsTreeViewItemChanging := True;
    // if Showing then
    // if Visible then
    // нет смысла в оптимизации - вызывается один раз и для корня - так и надо!
    frmCommandConfig.Assign(Node);

    // IsTreeViewItemChanging := False;
  end
  { else // скорей всего, первый элемент создается
    begin
    gbProperties.Enabled := True;
    frmCommandConfig.edtCaption.SetFocus;
    end; }

end;

procedure TfrmConfig.tvItemsChanging(Sender: TObject; Node: TTreeNode;
  var AllowChange: Boolean);
begin
  // AllowChange := (tvItems.Selected <> nil) and not Node.Deleting;
  if (tvItems.Selected <> nil) and not Node.Deleting then
    begin
    if frmCommandConfig.IsModified then
      IsModified := True;
    AllowChange := frmCommandConfig.SaveAssigned;
    end;
end;

procedure TfrmConfig.tvItemsCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  //var vNormal: boolean := not Assigned(Node.Data);
  if not Assigned(Node.Data) or TCommandData(Node.Data).isGroup  or
    ((Node = frmCommandConfig.AssignedTreeNode) and
      frmCommandConfig.CheckFileCommandExists) or
    ((Node <> frmCommandConfig.AssignedTreeNode) and
    (TCommandData(Node.Data).ExtendCommandToFullName <> '')) then
    Sender.Canvas.Font.Style := [] // .Color := TColors.SysWindowText
  else
  begin
    Sender.Canvas.Font.Style := [fsStrikeOut]; // .Color := TColors.Red;
    Sender.Canvas.Font.Color := clWindowText; // непонятно, почему белый по умолчанию
  end;
  {if Node.HasChildren or not Assigned(Node.Data) or
    ((Node = frmCommandConfig.AssignedTreeNode) and
      frmCommandConfig.CheckFileCommandExists) or
    ((Node <> frmCommandConfig.AssignedTreeNode) and
    (MyExtendFileNameToFull(TCommandData(Node.Data).Command) <> '')) then
    Sender.Canvas.Font.Style := [] // .Color := TColors.SysWindowText
  else
  begin
    Sender.Canvas.Font.Style := [fsStrikeOut]; // .Color := TColors.Red;
    Sender.Canvas.Font.Color := clWindowText; // непонятно, почему белый по умолчанию
  end;}
end;

procedure TfrmConfig.tvItemsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  vMode: TNodeAttachMode; // vOldParentImageIndex: Integer;
begin
  if (Source <> Sender) or (Sender <> tvItems) then
    Exit;

  var vTreeNode := tvItems.GetNodeAt(X, Y); // element under mouse

  if vTreeNode = tvItems.Selected then
    Exit; // the same element

  IsModified := True;

  if vTreeNode = nil then
    // если переносим в пустое место, то добавить
    if Y > 0 then
      vMode := naAdd // at the end
    else
      vMode := naAddFirst // at the begin
  else
    begin
      var vTreeNodeData := TCommandData(vTreeNode.Data);
      if vTreeNodeData.isGroup then
        begin
        vMode := naAddChild;
        end
      else
        begin
        vMode := naInsert;
        if (tvItems.Selected.DisplayRect(False)).Top < Y then
          vTreeNode := vTreeNode.getNextSibling;
        end;
    end;

  tvItems.Selected.MoveTo(vTreeNode, vMode);
end;

procedure TfrmConfig.tvItemsDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  //var vNode := tvItems.GetNodeAt(X, Y);
  Accept := (Sender = Source) and (Sender = tvItems);// and
    //((vNode = nil) or ((vNode <> nil) and (TCommandData(vNode.Data).isGroup)));
end;

procedure TfrmConfig.tvItemsEdited(Sender: TObject; Node: TTreeNode;
  var S: string);
begin
  if Node.Text <> S then
    frmCommandConfig.Caption := S;
end;

// it can't be updated because Width for Autosize can't be evaluated when Form is not Visible
procedure TfrmConfig.UpdateLblVerLeftAndCaption;
  function _GetBuildInfo: string;
  var
    VerInfoSize, VerValueSize, Dummy: DWORD;
    VerInfo: Pointer;
    VerValue: PVSFixedFileInfo;
  begin
    VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
    if VerInfoSize > 0 then
    begin
        GetMem(VerInfo, VerInfoSize);
        try
          if GetFileVersionInfo(PChar(ParamStr(0)), 0, VerInfoSize, VerInfo) then
          begin
            VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
            with VerValue^ do
            begin
              Result := (dwFileVersionMS shr 16).ToString + '.' +
                (dwFileVersionMS and $FFFF).ToString + '.' +
                (dwFileVersionLS shr 16).ToString + '.' +
                (dwFileVersionLS and $FFFF).ToString;
            end;
          end;
        finally
          FreeMem(VerInfo, VerInfoSize);
        end;
    end;
  end;
begin
  Application.Title := TrayIcon.Hint + ' - ' + Caption;

  //var vPrevVerWidth := lblVer.Width;
  lblVer.Caption := '<a href="https://github.com/avmaksimov/StartFromTray">' +
    GetLangString(Name, 'Version') + ' ' + _GetBuildInfo + '</a>';
  //lblVer.Left := (lblVer.Left + vPrevVerWidth) - lblVer.Width;
end;

{procedure TfrmConfig.UpdateTreeNodeIcon(const ATreeNode: TTreeNode);
var
  vCommandData: TCommandData;
  vNewImageIndex: Integer;
  vIcon: THandle;
begin
  vCommandData := TCommandData(ATreeNode.Data);
  if vCommandData.isGroup then
    vNewImageIndex := 0
  else
  begin
    vIcon := MyExtractIcon(vCommandData.Command);
    if vIcon > 0 then
    begin
      if ATreeNode.ImageIndex <= 0 then
        vNewImageIndex := -1 // add
      else
        vNewImageIndex := ATreeNode.ImageIndex;
      vNewImageIndex := ImageList_ReplaceIcon(TTreeView(ATreeNode.TreeView)
        .Images.Handle, vNewImageIndex, vIcon)
    end
    else
      vNewImageIndex := -1;
  end;
  ATreeNode.ImageIndex := vNewImageIndex;
  ATreeNode.SelectedIndex := vNewImageIndex;
end;}

procedure TfrmConfig.WMClose(var Message: TMessage);
begin
  actCloseExecute(actClose);
end;

procedure TfrmConfig.WndProc(var Message: TMessage);
// var vWM_TASKBARCREATED: UINT;
begin
  if (WM_TASKBARCREATED > 0) and (Message.Msg = WM_TASKBARCREATED) then
  begin
    // возможно надо заново регистрировать (вроде не надо)
    // vWM_TASKBARCREATED := WM_TASKBARCREATED;
    WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');
    // ShowMessage('Debug: Begin. WM_TASKBARCREATED: Old = ' + IntToStr(vWM_TASKBARCREATED) + '; New = ' + IntToStr(WM_TASKBARCREATED));

    // Иногда оно True, но реально не отображается, поэтому False не прокатит.
    try
      TrayIcon.Visible := False;
      // если не будет работать, то смотреть в сторону Shell_NotifyIcon, NIM_ADD, node(типа NOTIFYICONDATA_
    except
      { ShowMessage('Debug: Begin. WM_TASKBARCREATED: Old = ' + IntToStr(vWM_TASKBARCREATED) + '; New = ' + IntToStr(WM_TASKBARCREATED) + #13#10 +
        'Except: GetLastError = ' + IntToStr(GetLastError)); }
    end;
    TrayIcon.Visible := True;
  end;
  inherited WndProc(Message);
end;

// запускается при старте и нажатии "Отмена"
procedure TfrmConfig.XMLToTree(TreeNodes: TTreeNodes);
var
  ImageListHandle: HIMAGELIST;

  procedure ProcessNode(Node: IXMLNode; TreeNode: TTreeNode);
  //var
    //aNode: IXMLNode;
    //vCommandData: TCommandData;
    //iImageListIndex: Integer;
    //vhIcon: HICON;
    // w: word;
    // NodeAttributes: OleVariant; vCommonData: TCommandData;
  begin
    // if aNode = nil then Exit; // выходим, если достигнут конец документа

    // NodeAttributes := Node.Attributes; // for cache only

    // добавляем узел в дерево
    TreeNode := TreeNodes.AddChild(TreeNode, GetPropertyFromNodeAttributes(Node,
      'Caption'));

    var vCommandData := TCommandData.Create;
    vCommandData.AssignFrom(Node);

    TreeNode.Data := vCommandData;

    // переходим к дочернему узлу
    var aNode := Node.ChildNodes.First;

    // проходим по всем дочерним узлам
    while aNode <> nil do
    begin
      ProcessNode(aNode, TreeNode);
      aNode := aNode.NextSibling;
    end;

    // fix potencial and prev. bug then isGroup = 1 for no children node
    //vCommandData.isGroup := vCommandData.isGroup; //TreeNode.HasChildren;

    {if vCommandData.isGroup then
    begin
      TreeNode.ImageIndex := 0;
      TreeNode.SelectedIndex := 0;
    end
    else
    begin
      {var vhIcon := vCommandData.ExtractHIcon();
      var iImageListIndex := ImageList_ReplaceIcon(ImageListHandle, -1, vhIcon);
      if vhIcon > 0 then
        DestroyIcon(vhIcon);}
      var iImageListIndex := vCommandData.GetImageIndex(ImageListHandle);
      TreeNode.ImageIndex := iImageListIndex;
      TreeNode.SelectedIndex := iImageListIndex;
    //end;
  end;

var
  XMLDoc: IXMLDocument;
  cNode: IXMLNode;
  w: word;

begin
  ImageListHandle := TreeImageList.Handle; // ImageList.Handle;

  // добавим иконку для папки, если не добавлено (всегда первая)
  w := 3;
  ImageList_ReplaceIcon(ImageListHandle, -1,
    ExtractAssociatedIcon(Application.Handle, PChar('SHELL32.dll'), w));

  if not FileExists(ExtractFilePath(ParamStr(0)) + cItemsFileName) then
    Exit;

  XMLDoc := TXMLDocument.Create(nil);

  XMLDoc.LoadFromFile(ExtractFilePath(ParamStr(0)) + cItemsFileName);

  cNode := XMLDoc.ChildNodes.FindNode('tree2xml').ChildNodes.First;
  while cNode <> nil do
  begin
    ProcessNode(cNode, nil); // Рекурсия
    cNode := cNode.NextSibling;
  end;

  TreeNodes.Owner.FullExpand;
end;

{function TfrmConfig.CopyTreeNode(TreeNode: TTreeNode; ParentTreeNode: TTreeNode = nil): TTreeNode;
begin
  var vCommandData := TCommandData.Create;
  TCommandData(TreeNode.Data).Assign(vCommandData);

  if ParentTreeNode = nil then
    Result := tvItems.Items.AddObject(TreeNode, TreeNode.Text, vCommandData)
  else
    Result := tvItems.Items.AddChildObject(ParentTreeNode, TreeNode.Text, vCommandData);

  var vImageIndex: Integer;
  // 0 for group, -1 for undef element
  if TreeNode.ImageIndex <= 0 then
    vImageIndex := TreeNode.ImageIndex
  else
    begin
    var vIcon := TIcon.Create;
    try
      TreeImageList.GetIcon(TreeNode.ImageIndex, vIcon);
      vImageIndex := TreeImageList.AddIcon(vIcon);
    finally
      vIcon.Free;
    end; //try..finaly
    end;
  Result.ImageIndex := vImageIndex;
  Result.SelectedIndex := vImageIndex;
  // child nodes
  var vChildTreeNode := TreeNode.GetFirstChild;
  while vChildTreeNode <> nil do
    begin
    CopyTreeNode(vChildTreeNode, Result);
    vChildTreeNode := vChildTreeNode.getNextSibling;
    end;

  Result.Expanded := TreeNode.Expanded;
end;}

procedure TfrmConfig.DisposeTreeViewData;
begin
  var tn := tvItems.TopItem;
  while tn <> nil do
  begin
    DisposeTreeNodeData(tn);
    tn := tn.GetNextSibling;
  end;
end;

procedure TfrmConfig.DisposeTreeNodeData(TreeNode: TTreeNode);
begin
  // if (TreeNode = nil) then Exit;
  if TreeNode.Data <> nil then
  begin
    var P := TCommandData(TreeNode.Data);
    FreeAndNil(P);
    TreeNode.Data := nil;
    frmConfig.ListDeletedImageIndexes.Add(TreeNode.ImageIndex);
    //TreeImageListRemoveIndexProperly(TreeNode.ImageIndex);
  end;

  // child nodes
  TreeNode := TreeNode.GetFirstChild;
  while TreeNode <> nil do
  begin
    DisposeTreeNodeData(TreeNode);
    TreeNode := TreeNode.GetNextSibling;
  end;
end;

procedure TfrmConfig.ppTrayMenuItemOnClick(Sender: TObject);
begin
  var AMenuItem := (Sender as TMenuItem);
  if AMenuItem.Count = 0 then
  begin
    var vCommandData := TCommandData(AMenuItem.Tag);
    if not MouseButtonSwapped then
      vCommandData.Run(crtNormalRun)
    else
      vCommandData.Edit;
  end;
end;

procedure TfrmConfig.ppTrayMenuItemMiddleClick(Item: TMenuItem);
begin
  if Item.Count = 0 then
  begin
    for var I := 0 to tvItems.Items.Count - 1 do
      if tvItems.Items[I].Data = Pointer(Item.Tag) then
        begin
          ppTrayMenu.CloseMenu;
          Show;
          tvItems.Selected := tvItems.Items[I];
          break;
        end;
  end;
end;

procedure TfrmConfig.ppTrayMenuItemRightClick(Item: TMenuItem);
begin
  if Item.Count = 0 then
  begin
    var vCommandData := TCommandData(Item.Tag);
    if not MouseButtonSwapped then
      vCommandData.Edit
    else
      vCommandData.Run(crtNormalRun);
  end;
end;

end.
