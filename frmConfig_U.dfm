object frmConfig: TfrmConfig
  AlignWithMargins = True
  Left = 322
  Top = 137
  Caption = 'Run options'
  ClientHeight = 486
  ClientWidth = 792
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  StyleElements = [seFont, seClient]
  OnClose = FormClose
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
    Left = 6
    Top = 1
    Width = 373
    Height = 404
    Anchors = [akLeft, akTop, akBottom]
    Caption = 'Elements to run'
    TabOrder = 0
    DesignSize = (
      373
      404)
    object tvItems: TTreeView
      Left = 8
      Top = 15
      Width = 357
      Height = 380
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
    Left = 386
    Top = 1
    Width = 400
    Height = 404
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = 'Properties'
    TabOrder = 1
    inline frmCommandConfig: TfrmCommandConfig
      Left = 2
      Top = 15
      Width = 396
      Height = 387
      Align = alClient
      TabOrder = 0
      ExplicitLeft = 2
      ExplicitTop = 15
      ExplicitHeight = 395
      inherited Bevel1: TBevel
        Width = 380
      end
      inherited edtCaption: TLabeledEdit
        Width = 380
      end
      inherited cbIsVisible: TCheckBox
        Width = 129
      end
      inherited btnEdit: TButton
        Left = 232
      end
      inherited btnRun: TButton
        Left = 313
      end
      inherited edtCommand: TButtonedEdit
        Width = 380
      end
      inherited edtCommandParameters: TLabeledEdit
        Width = 380
      end
      inherited btnChangeIcon: TButton
        Left = 234
      end
    end
  end
  object gbButtons: TGroupBox
    Left = 6
    Top = 411
    Width = 373
    Height = 69
    Anchors = [akLeft, akBottom]
    TabOrder = 2
    object btnAddGroup: TButton
      Left = 6
      Top = 37
      Width = 117
      Height = 25
      Action = actAddGroup
      TabOrder = 3
    end
    object btnAddElement: TButton
      Left = 128
      Top = 37
      Width = 117
      Height = 25
      Action = actAddElement
      TabOrder = 4
      WordWrap = True
    end
    object btnDel: TButton
      Left = 250
      Top = 7
      Width = 117
      Height = 25
      Action = actDel
      TabOrder = 2
    end
    object btnCopy: TButton
      Left = 250
      Top = 37
      Width = 117
      Height = 25
      Action = actCopy
      TabOrder = 5
    end
    object btnUp: TButton
      Left = 6
      Top = 7
      Width = 117
      Height = 25
      Action = actItemUp
      TabOrder = 0
    end
    object btnDown: TButton
      Left = 128
      Top = 7
      Width = 117
      Height = 25
      Action = actItemDown
      TabOrder = 1
    end
  end
  object gbMainButtons: TGroupBox
    Left = 386
    Top = 411
    Width = 400
    Height = 69
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 3
    DesignSize = (
      400
      69)
    object lblVer: TLinkLabel
      Left = 10
      Top = 14
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
      TabOrder = 0
      TabStop = True
      OnLinkClick = lblVerLinkClick
    end
    object btnApply: TButton
      Left = 319
      Top = 37
      Width = 75
      Height = 25
      Action = actApply
      Anchors = [akRight, akBottom]
      TabOrder = 3
    end
    object btnClose: TButton
      Left = 236
      Top = 37
      Width = 75
      Height = 25
      Action = actClose
      Anchors = [akRight, akBottom]
      Cancel = True
      TabOrder = 2
    end
    object btnOK: TButton
      Left = 153
      Top = 37
      Width = 75
      Height = 25
      Action = actOK
      Anchors = [akRight, akBottom]
      TabOrder = 1
    end
    object btnOptions: TButton
      Left = 10
      Top = 37
      Width = 107
      Height = 25
      Caption = 'Options'
      PopupMenu = ppOptionsMenu
      TabOrder = 4
      OnClick = btnOptionsClick
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
      Default = True
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
    ColorDepth = cd32Bit
    Left = 212
    Top = 192
  end
  object ppOptionsMenu: TPopupMenu
    Left = 506
    Top = 423
    object miOptionsLang: TMenuItem
      Caption = 'Interface language'
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object miOptionsRunAtStart: TMenuItem
      AutoCheck = True
      Caption = 'Run at Windows start'
      OnClick = miOptionsRunAtStartClick
    end
    object N2: TMenuItem
      Caption = '-'
    end
    object miOptionsExtensions: TMenuItem
      Caption = 'Extensions...'
      OnClick = miOptionsExtensionsClick
    end
    object N3: TMenuItem
      Caption = '-'
    end
    object miOptionsExitProgram: TMenuItem
      Caption = 'Exit the program'
      OnClick = miOptionsExitProgramClick
    end
  end
end
