object frmConfig: TfrmConfig
  AlignWithMargins = True
  Left = 322
  Top = 137
  Caption = 'Run options'
  ClientHeight = 486
  ClientWidth = 792
  Color = clBtnFace
  CustomTitleBar.BackgroundColor = 7158279
  CustomTitleBar.ForegroundColor = clWhite
  CustomTitleBar.InactiveBackgroundColor = clWhite
  CustomTitleBar.InactiveForegroundColor = 10066329
  CustomTitleBar.ButtonForegroundColor = clWhite
  CustomTitleBar.ButtonBackgroundColor = 7158279
  CustomTitleBar.ButtonHoverForegroundColor = clWhite
  CustomTitleBar.ButtonHoverBackgroundColor = 9851146
  CustomTitleBar.ButtonPressedForegroundColor = clWhite
  CustomTitleBar.ButtonPressedBackgroundColor = 13857037
  CustomTitleBar.ButtonInactiveForegroundColor = 10066329
  CustomTitleBar.ButtonInactiveBackgroundColor = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  StyleElements = [seFont, seClient]
  OnConstrainedResize = FormConstrainedResize
  OnCreate = FormCreate
  OnHide = FormHide
  OnShow = FormShow
  DesignSize = (
    792
    486)
  PixelsPerInch = 96
  TextHeight = 13
  object gbItems: TGroupBox
    Left = 2
    Top = 1
    Width = 373
    Height = 412
    Anchors = [akLeft, akTop, akBottom]
    Caption = 'Elements to run'
    TabOrder = 0
    DesignSize = (
      373
      412)
    object tvItems: TTreeView
      Left = 6
      Top = 15
      Width = 361
      Height = 390
      Anchors = [akLeft, akTop, akBottom]
      DoubleBuffered = True
      DragMode = dmAutomatic
      HideSelection = False
      Images = TreeImageList
      Indent = 19
      ParentDoubleBuffered = False
      TabOrder = 0
      OnChange = tvItemsChange
      OnChanging = tvItemsChanging
      OnCustomDrawItem = tvItemsCustomDrawItem
      OnDragDrop = tvItemsDragDrop
      OnDragOver = tvItemsDragOver
      OnEdited = tvItemsEdited
    end
  end
  object gbProperties: TGroupBox
    Left = 381
    Top = 1
    Width = 408
    Height = 382
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = 'Properties'
    TabOrder = 1
    inline frmCommandConfig: TfrmCommandConfig
      Left = 2
      Top = 15
      Width = 404
      Height = 365
      Align = alClient
      TabOrder = 0
      ExplicitLeft = 2
      ExplicitTop = 15
      ExplicitHeight = 365
    end
  end
  object gbButtons: TGroupBox
    Left = 2
    Top = 419
    Width = 373
    Height = 65
    Anchors = [akLeft, akBottom]
    TabOrder = 2
    object btnAddGroup: TButton
      Left = 6
      Top = 33
      Width = 117
      Height = 25
      Action = actAddGroup
      TabOrder = 3
    end
    object btnAddElement: TButton
      Left = 128
      Top = 33
      Width = 117
      Height = 25
      Action = actAddElement
      TabOrder = 4
      WordWrap = True
    end
    object btnDel: TButton
      Left = 250
      Top = 5
      Width = 117
      Height = 25
      Action = actDel
      TabOrder = 2
    end
    object btnCopy: TButton
      Left = 250
      Top = 33
      Width = 117
      Height = 25
      Action = actCopy
      TabOrder = 5
    end
    object btnUp: TButton
      Left = 6
      Top = 5
      Width = 117
      Height = 25
      Action = actItemUp
      TabOrder = 0
    end
    object btnDown: TButton
      Left = 128
      Top = 5
      Width = 117
      Height = 25
      Action = actItemDown
      TabOrder = 1
    end
  end
  object gbMainButtons: TGroupBox
    Left = 381
    Top = 389
    Width = 408
    Height = 95
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 3
    DesignSize = (
      408
      95)
    object lbLangs: TLabel
      Left = 7
      Top = 13
      Width = 96
      Height = 13
      Caption = 'Interface language:'
    end
    object lblVer: TLinkLabel
      Left = 352
      Top = 37
      Width = 46
      Height = 17
      Cursor = crHandPoint
      Align = alCustom
      Alignment = taRightJustify
      Caption = 'Version: '
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      TabStop = True
      OnLinkClick = lblVerLinkClick
    end
    object btnApply: TButton
      Left = 328
      Top = 61
      Width = 75
      Height = 25
      Action = actApply
      Anchors = [akRight, akBottom]
      TabOrder = 6
    end
    object btnClose: TButton
      Left = 245
      Top = 61
      Width = 75
      Height = 25
      Action = actClose
      Anchors = [akRight, akBottom]
      Cancel = True
      TabOrder = 5
    end
    object btnOK: TButton
      Left = 162
      Top = 61
      Width = 75
      Height = 25
      Action = actOK
      Anchors = [akRight, akBottom]
      TabOrder = 4
    end
    object cbRunOnWindowsStart: TCheckBox
      Left = 7
      Top = 35
      Width = 167
      Height = 19
      Caption = 'Run at Windows start'
      ParentShowHint = False
      ShowHint = False
      TabOrder = 1
      OnClick = cbRunOnWindowsStartChange
    end
    object btnExtensions: TButton
      Left = 6
      Top = 61
      Width = 107
      Height = 25
      Caption = 'Extensions...'
      TabOrder = 3
      OnClick = btnExtensionsClick
    end
    object cbLangs: TComboBox
      Left = 162
      Top = 10
      Width = 241
      Height = 21
      AutoCloseUp = True
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbLangsChange
    end
  end
  object ActionList: TActionList
    Left = 44
    Top = 58
    object actAddElement: TAction
      Tag = -1
      Category = 'Elements'
      Caption = 'Add element'
      OnExecute = actAddElementExecute
    end
    object actAddGroup: TAction
      Category = 'Elements'
      Caption = 'Add group'
      OnExecute = actAddElementExecute
    end
    object actCopy: TAction
      Category = 'Elements'
      Caption = 'Copy'
      OnExecute = actCopyExecute
      OnUpdate = actCopyUpdate
    end
    object actDel: TAction
      Category = 'Elements'
      Caption = 'Delete'
      OnExecute = actDelExecute
      OnUpdate = actCopyUpdate
    end
    object actOK: TAction
      Category = 'Main'
      Caption = 'OK'
      Hint = 'Save and close options'
      OnExecute = actOKExecute
      OnUpdate = actApplyUpdate
    end
    object actClose: TAction
      Category = 'Main'
      Caption = 'Close'
      Hint = 'Cancel and close options'
      OnExecute = actCloseExecute
      OnUpdate = actCloseUpdate
    end
    object actApply: TAction
      Category = 'Main'
      Caption = 'Apply'
      Hint = 'Apply options without closing window'
      OnExecute = actApplyExecute
      OnUpdate = actApplyUpdate
    end
    object actItemUp: TAction
      Category = 'Elements'
      Caption = 'Up'
      OnExecute = actItemUpExecute
      OnUpdate = actItemUpUpdate
    end
    object actItemDown: TAction
      Category = 'Elements'
      Caption = 'Down'
      OnExecute = actItemDownExecute
      OnUpdate = actItemDownUpdate
    end
  end
  object TrayIcon: TTrayIcon
    Hint = 'Quick run from Tray'
    PopupMenu = ppConfigMenu
    OnMouseUp = TrayIconMouseUp
    Left = 228
    Top = 47
  end
  object ppConfigMenu: TPopupMenu
    Left = 148
    Top = 117
    object ppCMConfig: TMenuItem
      Caption = 'Options...'
      OnClick = ppCMConfigClick
    end
    object MenuItem1: TMenuItem
      Caption = '-'
    end
    object ppCMExit: TMenuItem
      Caption = 'Exit'
      OnClick = ppCMExitClick
    end
  end
  object TreeImageList: TImageList
    BkColor = 15790320
    Left = 212
    Top = 192
  end
end
