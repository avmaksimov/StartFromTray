object frmConfig: TfrmConfig
  Left = 322
  Top = 137
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsDialog
  Caption = 'Run options'
  ClientHeight = 483
  ClientWidth = 793
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object gbItems: TGroupBox
    Left = 4
    Top = 0
    Width = 373
    Height = 412
    Caption = 'Elements to run'
    TabOrder = 0
    object tvItems: TTreeView
      Left = 6
      Top = 16
      Width = 361
      Height = 390
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
    Top = 0
    Width = 408
    Height = 382
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
    Left = 4
    Top = 416
    Width = 373
    Height = 65
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
    Top = 388
    Width = 408
    Height = 93
    TabOrder = 3
    object lbLangs: TLabel
      Left = 7
      Top = 13
      Width = 96
      Height = 13
      Caption = 'Interface language:'
    end
    object lblVer: TLinkLabel
      Left = 353
      Top = 35
      Width = 48
      Height = 19
      Cursor = crHandPoint
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
      UseVisualStyle = True
      OnMouseEnter = lblVerMouseEnter
      OnMouseLeave = lblVerMouseLeave
      OnLinkClick = lblVerLinkClick
    end
    object btnApply: TButton
      Left = 328
      Top = 61
      Width = 75
      Height = 25
      Action = actApply
      TabOrder = 6
    end
    object btnClose: TButton
      Left = 245
      Top = 61
      Width = 75
      Height = 25
      Action = actClose
      Cancel = True
      TabOrder = 5
    end
    object btnOK: TButton
      Left = 162
      Top = 61
      Width = 75
      Height = 25
      Action = actOK
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
      Width = 239
      Height = 21
      AutoCloseUp = True
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbLangsChange
    end
  end
  object ActionList: TActionList
    Left = 36
    Top = 34
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
    Visible = True
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
