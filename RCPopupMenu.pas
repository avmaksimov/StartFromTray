unit RCPopupMenu;

interface

uses
  Windows, Messages, SysUtils, Classes, VCL.Graphics, VCL.Controls, VCL.Forms,
  VCL.Dialogs,
  VCL.Menus;

type
  TMenuRightClickEvent = procedure(Sender: TObject; Item: TMenuItem) of object;

  TRCPopupList = class(TPopupList)
  protected
    procedure WndProc(var Message: TMessage); override;
  end;

  TRCPopupMenu = class(TPopupMenu)
  private
    FOnMenuRightClick: TMenuRightClickEvent;
  protected
    function DispatchRC(aHandle: HMENU; aPosition: Integer): Boolean;
    procedure RClick(aItem: TMenuItem);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Popup(X, Y: Integer); override;
  published
    property OnMenuRightClick: TMenuRightClickEvent read FOnMenuRightClick
      write FOnMenuRightClick;
  end;

  TMyMenuItem = class(TMenuItem)
  protected
    procedure AdvancedDrawItem(ACanvas: TCanvas; ARect: TRect;
      State: TOwnerDrawState; TopLevel: Boolean); override;
  end;

  // type TMenuItem = class(TMyMenuItem);

var
  RCPopupList: TRCPopupList;

implementation

uses CommonU, CommandsClass_U;

{ TRCPopupList }

procedure TRCPopupList.WndProc(var Message: TMessage);
var
  i: Integer;
  pm: TPopupMenu;
begin
  if Message.Msg = WM_MENURBUTTONUP then
  begin
    for i := 0 to Count - 1 do
    begin
      pm := TPopupMenu(Items[i]);
      if pm is TRCPopupMenu then
        if TRCPopupMenu(Items[i]).DispatchRC(Message.lParam, Message.wParam)
        then
          Exit;
    end;
  end;
  inherited WndProc(Message);
end;

{ TRCPopupMenu }

constructor TRCPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  PopupList.Remove(Self);
  RCPopupList.Add(Self);
end;

destructor TRCPopupMenu.Destroy;
begin
  RCPopupList.Remove(Self);
  PopupList.Add(Self);
  inherited;
end;

function TRCPopupMenu.DispatchRC(aHandle: HMENU; aPosition: Integer): Boolean;
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

procedure TRCPopupMenu.Popup(X, Y: Integer);
const
  Flags: array [Boolean, TPopupAlignment] of Word =
    ((TPM_LEFTALIGN, TPM_RIGHTALIGN, TPM_CENTERALIGN),
    (TPM_RIGHTALIGN, TPM_LEFTALIGN, TPM_CENTERALIGN));
  Buttons: array [TTrackButton] of Word = (TPM_RIGHTBUTTON, TPM_LEFTBUTTON);
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
  TrackPopupMenuEx(Items.Handle, AFlags, X, Y, RCPopupList.Window, nil);
end;

procedure TRCPopupMenu.RClick(aItem: TMenuItem);
begin
  if Assigned(FOnMenuRightClick) then
    FOnMenuRightClick(Self, aItem);
end;

{ var
  oldPL: TPopupList; }

{ TMyMenuItem }

procedure TMyMenuItem.AdvancedDrawItem(ACanvas: TCanvas; ARect: TRect;
  State: TOwnerDrawState; TopLevel: Boolean);
begin
  if (Tag <> 0) and (Count = 0) and
    (MyExtendFileNameToFull(TCommandData(Tag).Command) = '') then
    ACanvas.Font.Style := [fsStrikeOut];
  // ACanvas.Font.Color := clRed;
  // ACanvas.Font.Style := [fsBold];
  inherited AdvancedDrawItem(ACanvas, ARect, State, TopLevel);
end;

initialization

RCPopupList := TRCPopupList.Create;

finalization

RCPopupList.Free;

end.
