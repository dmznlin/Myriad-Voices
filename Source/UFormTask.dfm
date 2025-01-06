object fFormTask: TfFormTask
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  ClientHeight = 420
  ClientWidth = 390
  Color = clBtnFace
  Font.Charset = GB2312_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poDefault
  OnClose = FormClose
  OnCreate = FormCreate
  DesignSize = (
    390
    420)
  PixelsPerInch = 96
  TextHeight = 12
  object Group1: TcxGroupBox
    Left = 12
    Top = 8
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = #21442#25968
    TabOrder = 0
    Height = 372
    Width = 369
    object cxLabel1: TcxLabel
      Left = 12
      Top = 57
      Caption = #35821#38899#27169#26495':'
      Transparent = True
    end
    object EditModal: TcxImageComboBox
      Left = 76
      Top = 55
      Properties.DefaultDescription = '1.'#35831#36873#25321#27169#26495
      Properties.DefaultImageIndex = 12
      Properties.DropDownRows = 20
      Properties.Images = FDM.Images16
      Properties.Items = <>
      TabOrder = 1
      Width = 280
    end
    object cxLabel2: TcxLabel
      Left = 12
      Top = 27
      Caption = #35745#21010#26631#35782':'
      Transparent = True
    end
    object EditID: TcxTextEdit
      Left = 76
      Top = 25
      Style.Edges = [bBottom]
      TabOrder = 3
      Width = 280
    end
    object EditDate: TdxDateTimeWheelPicker
      Left = 12
      Top = 205
      Hint = #20351#29992#40736#26631#28378#36718#21487#20197#24555#36895#35843#25972
      ParentShowHint = False
      Properties.Wheels = [pwYear, pwMonth, pwDay, pwHour, pwMinute, pwSecond]
      Properties.LineCount = 5
      Properties.OnEditValueChanged = EditDatePropertiesEditValueChanged
      ShowHint = True
      TabOrder = 4
      Height = 125
      Width = 344
    end
    object TrackDetail: TcxTrackBar
      Left = 12
      Top = 335
      Hint = #35843#25972#26102#38388#31934#24230
      ParentShowHint = False
      Position = 1
      Properties.Max = 6
      Properties.Min = 1
      Properties.ShowPositionHint = True
      Properties.OnChange = TrackDetailPropertiesChange
      Properties.OnGetPositionHint = TrackDetailPropertiesGetPositionHint
      ShowHint = True
      TabOrder = 5
      Transparent = True
      Height = 22
      Width = 344
    end
    object cxLabel3: TcxLabel
      Left = 12
      Top = 85
      Caption = #35821#38899#20869#23481':'
      Transparent = True
    end
    object LabelDate: TcxLabel
      Left = 12
      Top = 185
      Caption = #25773#25918#26102#38388':'
      Transparent = True
    end
    object EditText: TcxMemo
      Left = 12
      Top = 105
      Properties.MaxLength = 800
      Properties.ScrollBars = ssVertical
      TabOrder = 8
      Height = 75
      Width = 345
    end
  end
  object BtnOK: TcxButton
    Left = 220
    Top = 385
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #30830#23450
    TabOrder = 1
    OnClick = BtnOKClick
  end
  object BtnExit: TcxButton
    Left = 306
    Top = 385
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #21462#28040
    ModalResult = 8
    TabOrder = 2
  end
  object CheckLoop: TcxCheckBox
    Left = 12
    Top = 389
    Caption = #25773#25918#26102#38388#37319#29992'"'#38388#38548'"'#35745#26102'.'
    Style.TransparentBorder = False
    TabOrder = 3
    Transparent = True
    OnClick = CheckLoopClick
  end
end
