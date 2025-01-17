object fFormTask: TfFormTask
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  ClientHeight = 480
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
    480)
  PixelsPerInch = 96
  TextHeight = 12
  object GroupTime: TcxGroupBox
    Left = 12
    Top = 190
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = #25773#25918#26102#38388
    TabOrder = 1
    Height = 250
    Width = 369
    object dxBevel1: TdxBevel
      Left = 12
      Top = 160
      Width = 344
      Height = 8
      Shape = dxbsLineTop
    end
    object EditDate: TdxDateTimeWheelPicker
      Left = 12
      Top = 20
      Hint = #20351#29992#40736#26631#28378#36718#21487#20197#24555#36895#35843#25972
      ParentShowHint = False
      Properties.Wheels = [pwYear, pwMonth, pwDay, pwHour, pwMinute, pwSecond]
      Properties.LineCount = 5
      Properties.OnEditValueChanged = EditDatePropertiesEditValueChanged
      ShowHint = True
      TabOrder = 0
      Height = 115
      Width = 344
    end
    object TrackDetail: TcxTrackBar
      Left = 12
      Top = 136
      Hint = #35843#25972#26102#38388#31934#24230
      ParentShowHint = False
      Position = 1
      Properties.Max = 6
      Properties.Min = 1
      Properties.ShowPositionHint = True
      Properties.ShowTrack = False
      Properties.OnChange = TrackDetailPropertiesChange
      Properties.OnGetPositionHint = TrackDetailPropertiesGetPositionHint
      ShowHint = True
      TabOrder = 1
      Transparent = True
      Height = 22
      Width = 344
    end
    object CheckLoop: TcxCheckBox
      Left = 12
      Top = 170
      Caption = #25773#25918#26102#38388#37319#29992'"'#38388#38548'"'#35745#26102'.'
      Style.TransparentBorder = False
      TabOrder = 2
      Transparent = True
      OnClick = CheckLoopClick
    end
    object EditBase: TcxDateEdit
      Left = 76
      Top = 190
      Enabled = False
      Properties.DisplayFormat = 'yyyy-MM-dd hh:mm:ss'
      Properties.EditFormat = 'yyyy-MM-dd hh:mm:ss'
      Properties.Kind = ckDateTime
      Properties.WeekNumbers = True
      TabOrder = 3
      Width = 145
    end
    object cxLabel4: TcxLabel
      Left = 12
      Top = 192
      Caption = #24320#22987#26102#38388':'
      Transparent = True
    end
    object EditDelay: TcxTimeEdit
      Left = 76
      Top = 215
      Enabled = False
      TabOrder = 6
      Width = 145
    end
    object cxLabel5: TcxLabel
      Left = 12
      Top = 217
      Caption = #24310#21518#26102#38388':'
      Transparent = True
    end
    object cxLabel6: TcxLabel
      Left = 225
      Top = 192
      Caption = #31354#30333#20026#26381#21153#21551#21160#26102#38388'.'
      Transparent = True
    end
    object cxLabel7: TcxLabel
      Left = 225
      Top = 217
      Caption = #24320#22987#26102#38388#31354#30333#26102#26377#25928'.'
      Transparent = True
    end
  end
  object BtnOK: TcxButton
    Left = 220
    Top = 445
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #30830#23450
    TabOrder = 2
    OnClick = BtnOKClick
  end
  object BtnExit: TcxButton
    Left = 306
    Top = 445
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #21462#28040
    ModalResult = 8
    TabOrder = 3
  end
  object cxGroupBox1: TcxGroupBox
    Left = 12
    Top = 8
    Anchors = [akLeft, akTop, akRight]
    Caption = #22522#26412#21442#25968
    TabOrder = 0
    Height = 175
    Width = 369
    object EditText: TcxMemo
      Left = 11
      Top = 95
      Properties.MaxLength = 800
      Properties.ScrollBars = ssVertical
      TabOrder = 5
      Height = 62
      Width = 345
    end
    object cxLabel3: TcxLabel
      Left = 12
      Top = 75
      Caption = #35821#38899#20869#23481':'
      Transparent = True
    end
    object cxLabel1: TcxLabel
      Left = 12
      Top = 49
      Caption = #35821#38899#27169#26495':'
      Transparent = True
    end
    object cxLabel2: TcxLabel
      Left = 12
      Top = 22
      Caption = #35745#21010#26631#35782':'
      Transparent = True
    end
    object EditID: TcxTextEdit
      Left = 76
      Top = 20
      Style.Edges = [bBottom]
      TabOrder = 0
      Width = 280
    end
    object EditModal: TcxImageComboBox
      Left = 76
      Top = 47
      Properties.DefaultDescription = '1.'#35831#36873#25321#27169#26495
      Properties.DefaultImageIndex = 12
      Properties.DropDownRows = 20
      Properties.Images = FDM.Images16
      Properties.Items = <>
      TabOrder = 1
      Width = 280
    end
  end
end
