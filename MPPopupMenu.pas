unit MPPopupMenu;

{$mode delphi}{$H+}

interface

uses
  Classes, Controls, Menus, Graphics, Types, ImgList, LCLType;

type
  TMenuItemClickEvent = procedure(Item: TMenuItem) of object;
  TMenuItemMissingQueryEvent = function(Item: TMenuItem): Boolean of object;

  TMPPopupMenu = class(TPopupMenu)
  private
    FLastButton: TMouseButton;
    FSelectedItem: TMenuItem;
    FOnItemMiddleClick: TMenuItemClickEvent;
    FOnItemRightClick: TMenuItemClickEvent;
    FOnQueryItemMissing: TMenuItemMissingQueryEvent;
    FPopupGeneration: Cardinal;
    procedure DispatchAlternateClick(AItem: TMenuItem);
    procedure PrepareLevel(AParentItem: TMenuItem);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Popup(X, Y: Integer); override;
    property LastButton: TMouseButton read FLastButton;
    property OnQueryItemMissing: TMenuItemMissingQueryEvent
      read FOnQueryItemMissing write FOnQueryItemMissing;
  published
    property OnItemMiddleClick: TMenuItemClickEvent read FOnItemMiddleClick
      write FOnItemMiddleClick;
    property OnItemRightClick: TMenuItemClickEvent read FOnItemRightClick
      write FOnItemRightClick;
  end;

  TMPMenuItem = class(TMenuItem)
  private
    FData: Pointer;
    FMissingTarget: Boolean;
    FPreparedGeneration: Cardinal;
  protected
    function DoDrawItem(ACanvas: TCanvas; ARect: Types.TRect;
      AState: LCLType.TOwnerDrawState): Boolean; override;
  public
    procedure Click; override;
    procedure IntfDoSelect; override;
    property Data: Pointer read FData write FData;
    property MissingTarget: Boolean read FMissingTarget write FMissingTarget;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;
{$ENDIF}

var
  ActivePopupMenu: TMPPopupMenu;

{$IFDEF MSWINDOWS}
var
  MenuMessageHook: HHOOK;

function MenuMessageFilter(Code: Integer; HookWParam: WPARAM;
  HookLParam: LPARAM): LRESULT; stdcall;
var
  Msg: PMsg;

  function DispatchSelectedGroup(
    const AButton: TMouseButton): Boolean;
  var
    PopupMenu: TMPPopupMenu;
    SelectedItem: TMenuItem;
  begin
    Result := False;
    PopupMenu := ActivePopupMenu;

    if not Assigned(PopupMenu) then
      Exit;

    SelectedItem := PopupMenu.FSelectedItem;
    if not Assigned(SelectedItem) or (SelectedItem.Count = 0) then
      Exit;

    PopupMenu.FLastButton := AButton;
    try
      PopupMenu.DispatchAlternateClick(SelectedItem);
    finally
      PopupMenu.FLastButton := mbLeft;
    end;

    Result := True;
  end;
begin
  if Code < 0 then
    Exit(CallNextHookEx(MenuMessageHook, Code, HookWParam, HookLParam));

  if (Code = MSGF_MENU) and Assigned(ActivePopupMenu) then
  begin
    {$PUSH}
    {$WARN 4055 OFF}
    Msg := PMsg(PtrUInt(HookLParam));
    {$POP}
    case Msg^.message of
      WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK:
        ActivePopupMenu.FLastButton := mbLeft;

      WM_RBUTTONDOWN:
        begin
          ActivePopupMenu.FLastButton := mbRight;
          Msg^.message := WM_LBUTTONDOWN;
          Msg^.wParam := (Msg^.wParam and not WPARAM(MK_RBUTTON)) or
            WPARAM(MK_LBUTTON);
        end;
      WM_RBUTTONUP:
        begin
          if DispatchSelectedGroup(mbRight) then
          begin
            Msg^.message := WM_NULL;
            Exit(1);
          end;

          ActivePopupMenu.FLastButton := mbRight;
          Msg^.message := WM_LBUTTONUP;
          Msg^.wParam := Msg^.wParam and not WPARAM(MK_RBUTTON);
        end;
      WM_RBUTTONDBLCLK:
        begin
          ActivePopupMenu.FLastButton := mbRight;
          Msg^.message := WM_LBUTTONDBLCLK;
          Msg^.wParam := (Msg^.wParam and not WPARAM(MK_RBUTTON)) or
            WPARAM(MK_LBUTTON);
        end;

      WM_MBUTTONDOWN:
        begin
          ActivePopupMenu.FLastButton := mbMiddle;
          Msg^.message := WM_LBUTTONDOWN;
          Msg^.wParam := (Msg^.wParam and not WPARAM(MK_MBUTTON)) or
            WPARAM(MK_LBUTTON);
        end;
      WM_MBUTTONUP:
        begin
          if DispatchSelectedGroup(mbMiddle) then
          begin
            Msg^.message := WM_NULL;
            Exit(1);
          end;

          ActivePopupMenu.FLastButton := mbMiddle;
          Msg^.message := WM_LBUTTONUP;
          Msg^.wParam := Msg^.wParam and not WPARAM(MK_MBUTTON);
        end;
      WM_MBUTTONDBLCLK:
        begin
          ActivePopupMenu.FLastButton := mbMiddle;
          Msg^.message := WM_LBUTTONDBLCLK;
          Msg^.wParam := (Msg^.wParam and not WPARAM(MK_MBUTTON)) or
            WPARAM(MK_LBUTTON);
        end;

      WM_KEYDOWN:
        if (Msg^.wParam = VK_RETURN) or (Msg^.wParam = VK_SPACE) then
          ActivePopupMenu.FLastButton := mbLeft;
    end;
  end;

  Result := CallNextHookEx(MenuMessageHook, Code, HookWParam, HookLParam);
end;
{$ENDIF}

constructor TMPPopupMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLastButton := mbLeft;
  FSelectedItem := nil;
  FPopupGeneration := 0;
  OwnerDraw := True;
end;

procedure TMPPopupMenu.DispatchAlternateClick(AItem: TMenuItem);
var
  ClickButton: TMouseButton;
begin
  ClickButton := FLastButton;

  { У родительского пункта меню Windows самостоятельно меню не закрывает. }
  {$IFDEF MSWINDOWS}
  Windows.EndMenu;
  {$ELSE}
  Close;
  {$ENDIF}

  case ClickButton of
    mbMiddle:
      if Assigned(FOnItemMiddleClick) then
        FOnItemMiddleClick(AItem);
    mbRight:
      if Assigned(FOnItemRightClick) then
        FOnItemRightClick(AItem);
  end;
end;

procedure TMPPopupMenu.PrepareLevel(AParentItem: TMenuItem);
var
  I: Integer;
  Item: TMenuItem;
begin
  if not Assigned(AParentItem) then
    Exit;
  for I := 0 to AParentItem.Count - 1 do
  begin
    Item := AParentItem.Items[I];
    if Item is TMPMenuItem then
      if Assigned(FOnQueryItemMissing) then
        TMPMenuItem(Item).MissingTarget := FOnQueryItemMissing(Item)
      else
        TMPMenuItem(Item).MissingTarget := False;
  end;
end;

procedure TMPPopupMenu.Popup(X, Y: Integer);
begin
  FLastButton := mbLeft;
  FSelectedItem := nil;

  Inc(FPopupGeneration);
  if FPopupGeneration = 0 then
    Inc(FPopupGeneration);
  { Only the visible root level is checked now. Submenu children are checked
    by TMPMenuItem.IntfDoSelect when their parent is highlighted. }
  PrepareLevel(Items);
  ActivePopupMenu := Self;
  {$IFDEF MSWINDOWS}
  MenuMessageHook := SetWindowsHookEx(WH_MSGFILTER, @MenuMessageFilter, 0,
    GetCurrentThreadId);
  {$ENDIF}
  try
    inherited Popup(X, Y);
  finally
    {$IFDEF MSWINDOWS}
    if MenuMessageHook <> 0 then
    begin
      UnhookWindowsHookEx(MenuMessageHook);
      MenuMessageHook := 0;
    end;
    {$ENDIF}
    ActivePopupMenu := nil;
  end;
end;

function TMPMenuItem.DoDrawItem(ACanvas: TCanvas; ARect: Types.TRect;
  AState: LCLType.TOwnerDrawState): Boolean;
var
  MenuImages: TCustomImageList;
  OldBrushColor, OldFontColor: TColor;
  OldBrushStyle: TBrushStyle;
  OldFontStyle: TFontStyles;
  IconTop, TextLeft, TextTop: Integer;
begin
  if not FMissingTarget then
    Exit(inherited DoDrawItem(ACanvas, ARect, AState));

  Result := True;
  OldBrushColor := ACanvas.Brush.Color;
  OldBrushStyle := ACanvas.Brush.Style;
  OldFontColor := ACanvas.Font.Color;
  OldFontStyle := ACanvas.Font.Style;
  try
    ACanvas.Brush.Style := bsSolid;
    if LCLType.odSelected in AState then
    begin
      ACanvas.Brush.Color := clHighlight;
      ACanvas.Font.Color := clHighlightText;
    end
    else
    begin
      ACanvas.Brush.Color := clMenu;
      if (LCLType.odDisabled in AState) or
        (LCLType.odGrayed in AState) or (not Enabled) then
        ACanvas.Font.Color := clGrayText
      else
        ACanvas.Font.Color := clMenuText;
    end;
    ACanvas.FillRect(ARect);

    TextLeft := ARect.Left + 6;
    MenuImages := GetImageList;
    if Assigned(MenuImages) then
    begin
      if (ImageIndex >= 0) and (ImageIndex < MenuImages.Count) then
      begin
        IconTop := ARect.Top + (ARect.Height - MenuImages.Height) div 2;
        MenuImages.Draw(ACanvas, ARect.Left + 3, IconTop, ImageIndex,
          Enabled);
      end;
      TextLeft := ARect.Left + MenuImages.Width + 9;
    end;

    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Style := OldFontStyle + [fsStrikeOut];
    TextTop := ARect.Top + (ARect.Height -
      ACanvas.TextHeight(Caption)) div 2;
    ACanvas.TextOut(TextLeft, TextTop, Caption);
    if LCLType.odFocused in AState then
      ACanvas.DrawFocusRect(ARect);
  finally
    ACanvas.Brush.Color := OldBrushColor;
    ACanvas.Brush.Style := OldBrushStyle;
    ACanvas.Font.Color := OldFontColor;
    ACanvas.Font.Style := OldFontStyle;
  end;
end;

procedure TMPMenuItem.Click;
var
  PopupMenu: TMPPopupMenu;
begin
  if GetParentMenu is TMPPopupMenu then
    PopupMenu := TMPPopupMenu(GetParentMenu)
  else
    PopupMenu := nil;

  if Assigned(PopupMenu) and
    (PopupMenu.LastButton in [mbMiddle, mbRight]) then
  begin
    try
      PopupMenu.DispatchAlternateClick(Self);
    finally
      PopupMenu.FLastButton := mbLeft;
    end;
  end
  else
    inherited Click;
end;

procedure TMPMenuItem.IntfDoSelect;
begin
  if Assigned(ActivePopupMenu) then
  begin
    ActivePopupMenu.FSelectedItem := Self;
  { A submenu is prepared at most once for the current popup session. The
    rest of the tree remains untouched until the user actually enters it. }
    if (Count > 0) and
      (FPreparedGeneration <> ActivePopupMenu.FPopupGeneration) then
    begin
      FPreparedGeneration := ActivePopupMenu.FPopupGeneration;
      ActivePopupMenu.PrepareLevel(Self);
    end;
  end;
  inherited IntfDoSelect;
end;

initialization
  ActivePopupMenu := nil;
  {$IFDEF MSWINDOWS}
  MenuMessageHook := 0;
  {$ENDIF}

end.
