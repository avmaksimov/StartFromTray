unit MPPopupMenu;

interface

uses
  Windows, Messages, SysUtils, Classes, VCL.Graphics, VCL.Controls, VCL.Forms,
  VCL.Dialogs,
  VCL.Menus;

type
  TMenuItemClickEvent = procedure(Item: TMenuItem) of object;

  TMPPopupList = class(TPopupList)
  private
    FActiveMenuItem: TMenuItem;
  protected
    constructor Create; //override;
    procedure WndProc(var Message: TMessage); override;
  end;

  TMPPopupMenu = class(TPopupMenu)
  private
    FOnItemMiddleClick, FOnItemRightClick: TMenuItemClickEvent;
  protected
    function DispatchRC(aHandle: HMENU; aPosition: Integer): Boolean;
    procedure MClick(AItem: TMenuItem);
    procedure RClick(AItem: TMenuItem);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Popup(X, Y: Integer); override;
  published
    property OnItemMiddleClick: TMenuItemClickEvent read FOnItemMiddleClick
      write FOnItemMiddleClick;
    property OnItemRightClick: TMenuItemClickEvent read FOnItemRightClick
      write FOnItemRightClick;
  end;

  TMPMenuItem = class(TMenuItem)
  protected
    procedure AdvancedDrawItem(ACanvas: TCanvas; ARect: TRect;
      State: TOwnerDrawState; TopLevel: Boolean); override;
  end;

var
  MPPopupList: TMPPopupList;

implementation

uses CommonU, CommandsClass_U;

{ TMPPopupList }

constructor TMPPopupList.Create;
begin
  inherited;
  FActiveMenuItem := nil;
end;

procedure TMPPopupList.WndProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_MENURBUTTONUP:
      begin
        for var i := 0 to Count - 1 do
        begin
		    var pm := TPopupMenu(Items[i]);
        if (pm is TMPPopupMenu) and
          (TMPPopupMenu(Items[i]).DispatchRC(Message.lParam, Message.wParam)) then
              Exit;
        end;
      end;
    WM_MENUSELECT:
      begin
      FActiveMenuItem := nil;
      with TWMMenuSelect(Message) do
        begin
        // Check if popup menu is open: https://www.swissdelphicenter.ch/en/showcode.php?id=958
		if not ((MenuFlag and $FFFF > 0) and (Menu = 0)) then
          begin
          var FindKind := fkCommand;
          if MenuFlag and MF_POPUP <> 0 then
            FindKind := fkHandle;
          for var I := 0 to Count - 1 do
            begin
              var Item: HMenu;
              if FindKind = fkHandle then
                begin
                if Menu <> 0 then
                  Item := GetSubMenu(Menu, IDItem)
                else
                  begin
                  break; //avmaksimov
                  end;

                end
              else
                Item := IDItem;
              var FMenuItem := TPopupMenu(Items[I]).FindItem(Item, FindKind);
              if FMenuItem <> nil then
                begin
                FActiveMenuItem := FMenuItem;
                  //inherited;
                  //Exit;
                end;
            end; // for
          end; // Check if popup menu is open
          //FActiveMenuItem := nil;
        end; // TWMMenuSelect(Message)
	  inherited;
      end; // WM_MENUSELECT
    WM_MBUTTONDOWN:
      if Assigned(FActiveMenuItem) then
        begin
        for var i := 0 to Count - 1 do
          begin
		      var pm := TPopupMenu(Items[i]);
          if pm is TMPPopupMenu then
            TMPPopupMenu(Items[i]).MClick(FActiveMenuItem);
          end;
        end;
  end;
  inherited WndProc(Message);
end;

{ TRCPopupMenu }

constructor TMPPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  PopupList.Remove(Self);
  MPPopupList.Add(Self);
end;

destructor TMPPopupMenu.Destroy;
begin
  MPPopupList.Remove(Self);
  PopupList.Add(Self);
  inherited;
end;

function TMPPopupMenu.DispatchRC(aHandle: HMENU; aPosition: Integer): Boolean;
var
  FParentItem: TMenuItem;
begin
  Result := False;
  if Handle = aHandle then
    FParentItem := Items
  else
    FParentItem := FindItem(aHandle, fkHandle);
  if FParentItem <> nil then
  begin
    RClick(FParentItem.Items[aPosition]);
    Result := True;
  end;
  { if Handle = aHandle then
    begin
    RClick(Items[aPosition]);
    Result := True;
    end; }
end;

procedure TMPPopupMenu.Popup(X, Y: Integer);
const
  Flags: array [Boolean, TPopupAlignment] of Word =
    ((TPM_LEFTALIGN, TPM_RIGHTALIGN, TPM_CENTERALIGN),
    (TPM_RIGHTALIGN, TPM_LEFTALIGN, TPM_CENTERALIGN));
  //Buttons: array [TTrackButton] of Word = (TPM_RIGHTBUTTON, TPM_LEFTBUTTON);
var
  AFlags: Integer;
begin
  DoPopup(Self);
  AFlags := Flags[UseRightToLeftAlignment, Alignment]
  { or Buttons[TrackButton] };
  if (Win32MajorVersion > 4) or
    ((Win32MajorVersion = 4) and (Win32MinorVersion > 0)) then
  begin
    AFlags := AFlags or (Byte(MenuAnimation) shl 10);
    AFlags := AFlags or TPM_RECURSE;
  end;
  TrackPopupMenuEx(Items.Handle, AFlags, X, Y, MPPopupList.Window, nil);
end;

procedure TMPPopupMenu.MClick(AItem: TMenuItem);
begin
  if Assigned(FOnItemMiddleClick) then
    FOnItemMiddleClick(AItem);
end;

procedure TMPPopupMenu.RClick(AItem: TMenuItem);
begin
  if Assigned(FOnItemRightClick) then
    FOnItemRightClick(AItem);
end;

{ var
  oldPL: TPopupList; }

{ TMyMenuItem }

procedure TMPMenuItem.AdvancedDrawItem(ACanvas: TCanvas; ARect: TRect;
  State: TOwnerDrawState; TopLevel: Boolean);
begin
  if (Tag <> 0) and (Count = 0) and
    (TCommandData(Tag).ExtendCommandToFullName = '') then
    ACanvas.Font.Style := [fsStrikeOut];
  // ACanvas.Font.Color := clRed;
  // ACanvas.Font.Style := [fsBold];
  inherited AdvancedDrawItem(ACanvas, ARect, State, TopLevel);
end;

initialization

MPPopupList := TMPPopupList.Create;

finalization

MPPopupList.Free;

end.
