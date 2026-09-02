# Porting notes

## Required fixes to preserve

- In `CommonU.pas`, keep the fully qualified `Graphics.TBitmap` type and
  `Graphics.TBitmap.Create` constructor. The `Windows` unit also declares a
  `TBitmap`, and the unqualified name causes `identifier idents no member
  "Create"` with FPC 3.2.2.
- In `MPPopupMenu.pas`, keep `LCLType.TOwnerDrawState` and the qualified
  `LCLType.od...` values. The `Windows` unit declares another
  `TOwnerDrawState`, which is not assignment-compatible with the LCL type.
- Do not restore Delphi-only properties in LFM files; they previously caused
  `Unknown property` exceptions while loading forms.
- Do not add icons to a `TImageList` from `OnDrawItem`: changing an image list
  while painting causes nested repaints and visible pauses.
- Check an image-list count before reading an image; an empty list previously
  caused `EListError: List index (0) out of bounds`.
- Sort extensions in a separate `TStringList`; `TListBox.Items` must not be
  cast to `TStringList` for `CustomSort`.
- Browse buttons use Windows Shell file/folder icons at run time with an
  application-drawn magnifier overlay. The code-drawn file/folder images are
  retained as the portable fallback and must not be removed.

- Target: Lazarus 4.8 / FPC 3.2.2 / Windows.
- Delphi inline variable declarations and string helpers were removed.
- Delphi XML interfaces were replaced by FPC `DOM`, `XMLRead`, and a compatible
  writer which retains the existing `Items.xml` layout.
- RTTI serialization recognizes FPC string kinds and `tkBool`.
- `TFileOpenDialog` was replaced by LCL `TOpenDialog` and `SelectDirectory`.
- Delphi `TButtonedEdit` controls with one button were replaced by the
  standard LCL `TEditButton`. The command editor, which needs both file and
  folder selectors, uses `TEdit` plus two adjacent `TSpeedButton` controls
  with distinct images.
- `TLinkLabel` was replaced by a clickable `TLabel`.
- The custom VCL title-bar panel was replaced by a standard dialog title bar.
- Pointer values stored in `Tag` use `PtrInt`, so Win64 builds are not truncated.
- The tray command menu remains a native `TPopupMenu`; a Windows
  `WH_MSGFILTER` hook maps middle/right menu clicks to native selection while
  preserving the actual mouse button for dispatch.
- Windows API calls which receive user paths or translated text use explicit
  wide-character entry points.
- `PickIconDlg` is imported explicitly from `Shell32.dll`, because the FPC
  3.2.2 Windows headers do not declare that exported Shell function.
- Icons obtained as Windows `HICON` values are added through LCL
  `TCustomImageList.AddIcon`; direct Win32 access to `TImageList.Handle` is not
  used because LCL image lists manage their own resolution collection.
- Registry extensions are sorted in a real `TStringList` and then assigned to
  the list box. Casting `TListBox.Items` to `TStringList` is invalid in LCL.
- Dialog layouts reserve the actual scaled height of their bottom buttons, so
  controls remain visible with Windows DPI scaling.

The original `.dpr`, `.dproj`, `.dfm`, and `.bak` files are reference material
only and are not part of the Lazarus project listed in `StartFromTray.lpi`.
