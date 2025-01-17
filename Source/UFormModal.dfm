object fFormModal: TfFormModal
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  ClientHeight = 442
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
    442)
  PixelsPerInch = 96
  TextHeight = 12
  object Group1: TcxGroupBox
    Left = 10
    Top = 8
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = #35821#38899#21512#25104
    TabOrder = 0
    Height = 394
    Width = 369
    object cxLabel1: TcxLabel
      Left = 12
      Top = 27
      Caption = #35821#35328#31867#21035':'
      Transparent = True
    end
    object EditLang: TcxImageComboBox
      Left = 72
      Top = 25
      Properties.DefaultDescription = '1.'#35831#36873#25321#35821#31181
      Properties.DefaultImageIndex = 11
      Properties.DropDownRows = 20
      Properties.Images = FDM.Images16
      Properties.Items = <>
      Properties.OnChange = EditLangPropertiesChange
      TabOrder = 0
      Width = 280
    end
    object cxLabel2: TcxLabel
      Left = 12
      Top = 62
      Caption = #26391#35835#35282#33394':'
      Transparent = True
    end
    object EditVoice: TcxImageComboBox
      Left = 72
      Top = 60
      Properties.DefaultDescription = '2.'#35831#36873#25321#35282#33394
      Properties.DefaultImageIndex = 9
      Properties.DropDownRows = 20
      Properties.Images = FDM.Images16
      Properties.Items = <>
      TabOrder = 2
      Width = 280
    end
    object EditLoop: TcxSpinEdit
      Left = 72
      Top = 95
      Properties.MaxValue = 65535.000000000000000000
      TabOrder = 4
      Width = 60
    end
    object cxLabel3: TcxLabel
      Left = 12
      Top = 97
      Caption = #24490#29615#27425#25968':'
      Transparent = True
    end
    object cxLabel4: TcxLabel
      Left = 175
      Top = 97
      Caption = #24490#29615#38388#38548':'
      Transparent = True
    end
    object EditInterval: TcxSpinEdit
      Left = 235
      Top = 95
      Properties.MaxValue = 86400000.000000000000000000
      Properties.MinValue = 1000.000000000000000000
      TabOrder = 5
      Value = 1000
      Width = 60
    end
    object cxLabel5: TcxLabel
      Left = 300
      Top = 97
      Caption = #27627#31186'(ms)'
      Transparent = True
    end
    object EditHour: TcxTextEdit
      Left = 22
      Top = 156
      Properties.MaxLength = 800
      TabOrder = 10
      Text = #29616#22312#26159#21271#20140#26102#38388' $hr:00'
      Width = 330
    end
    object EditHalf: TcxTextEdit
      Left = 22
      Top = 206
      Properties.MaxLength = 800
      TabOrder = 12
      Text = #29616#22312#26159#21271#20140#26102#38388' $hr:30'
      Width = 330
    end
    object CheckHour: TcxCheckBox
      Left = 12
      Top = 136
      Caption = #25972#28857#25253#26102
      Style.TransparentBorder = False
      TabOrder = 9
      Transparent = True
    end
    object CheckHalf: TcxCheckBox
      Left = 12
      Top = 186
      Caption = #21322#28857#25253#26102
      Style.TransparentBorder = False
      TabOrder = 11
      Transparent = True
    end
    object cxLabel6: TcxLabel
      Left = 12
      Top = 260
      Caption = #26391#35835#35821#36895':'
      Transparent = True
    end
    object cxLabel7: TcxLabel
      Left = 12
      Top = 287
      Caption = #26391#35835#35821#35843':'
      Transparent = True
    end
    object cxLabel8: TcxLabel
      Left = 12
      Top = 315
      Caption = #21512#25104#38899#37327':'
      Transparent = True
    end
    object TrackSpeed: TcxTrackBar
      Tag = 125
      Left = 67
      Top = 256
      Position = 15
      Properties.Frequency = 2
      Properties.Max = 100
      Properties.Min = 1
      Properties.ShowPositionHint = True
      TabOrder = 13
      Transparent = True
      Height = 25
      Width = 285
    end
    object TrackPitch: TcxTrackBar
      Tag = 1000
      Left = 67
      Top = 283
      Position = 50
      Properties.Frequency = 2
      Properties.Max = 100
      Properties.Min = 1
      Properties.ShowPositionHint = True
      TabOrder = 15
      Transparent = True
      Height = 25
      Width = 285
    end
    object TrackVolume: TcxTrackBar
      Tag = 8000
      Left = 67
      Top = 310
      Position = 50
      Properties.Frequency = 2
      Properties.Max = 100
      Properties.Min = 1
      Properties.ShowPositionHint = True
      TabOrder = 17
      Transparent = True
      Height = 25
      Width = 285
    end
    object cxLabel9: TcxLabel
      Left = 12
      Top = 353
      Caption = #27979#35797#20869#23481':'
      Transparent = True
    end
    object EditDemo: TcxTextEdit
      Left = 72
      Top = 351
      Properties.MaxLength = 800
      TabOrder = 20
      Text = #25105#26159#21315#38899#25991#26412#36716#35821#38899#21512#25104#31995#32479'.'
      Width = 215
    end
    object BtnTest: TcxButton
      Left = 294
      Top = 350
      Width = 55
      Height = 22
      Caption = #27979#35797
      OptionsImage.ImageIndex = 6
      OptionsImage.Images = FDM.Images16
      TabOrder = 19
      OnClick = BtnTestClick
    end
  end
  object BtnOK: TcxButton
    Left = 218
    Top = 407
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #30830#23450
    TabOrder = 1
    OnClick = BtnOKClick
  end
  object BtnExit: TcxButton
    Left = 304
    Top = 407
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #21462#28040
    ModalResult = 8
    TabOrder = 2
  end
  object CheckDefault: TcxCheckBox
    Left = 10
    Top = 411
    Caption = #40664#35748#27169#26495' ID:'
    Style.TransparentBorder = False
    TabOrder = 3
    Transparent = True
  end
  object EditID: TcxTextEdit
    Left = 102
    Top = 411
    Style.Edges = [bBottom]
    TabOrder = 4
    Width = 70
  end
end
