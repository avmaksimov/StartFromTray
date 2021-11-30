object frmChooseExt: TfrmChooseExt
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Choose extension'
  ClientHeight = 396
  ClientWidth = 287
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnClose = FormClose
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object gbExtensions: TGroupBox
    Left = 4
    Top = 4
    Width = 279
    Height = 345
    TabOrder = 0
    object lblExtensions: TLabel
      Left = 10
      Top = 52
      Width = 102
      Height = 13
      Caption = 'Available extensions:'
      FocusControl = lbExtensions
    end
    object edtExt: TLabeledEdit
      Left = 8
      Top = 23
      Width = 264
      Height = 21
      EditLabel.Width = 51
      EditLabel.Height = 13
      EditLabel.Caption = 'Extension:'
      TabOrder = 0
      OnChange = edtExtChange
    end
    object lbExtensions: TListBox
      Left = 8
      Top = 66
      Width = 264
      Height = 271
      Style = lbOwnerDrawFixed
      DoubleBuffered = False
      ItemHeight = 18
      ParentDoubleBuffered = False
      TabOrder = 1
      OnClick = lbExtensionsClick
      OnDrawItem = lbExtensionsDrawItem
    end
  end
  object gbButtons: TGroupBox
    Left = 4
    Top = 353
    Width = 279
    Height = 39
    TabOrder = 1
    object btnOK: TButton
      Left = 56
      Top = 8
      Width = 105
      Height = 25
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 167
      Top = 8
      Width = 105
      Height = 25
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object ImageList: TImageList
    Left = 216
    Top = 6
  end
end
