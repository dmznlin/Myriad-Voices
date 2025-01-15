object fFormMain: TfFormMain
  Left = 556
  Top = 462
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Key'
  ClientHeight = 98
  ClientWidth = 230
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 12
  object Label1: TLabel
    Left = 12
    Top = 14
    Width = 102
    Height = 12
    Caption = #36873#25321#31995#32479#30340#26377#25928#26399':'
  end
  object EditDate: TDateTimePicker
    Left = 14
    Top = 32
    Width = 201
    Height = 20
    Date = 42874.000000000000000000
    Format = 'yyyy-MM-dd'
    Time = 0.631509814811579400
    TabOrder = 0
  end
  object BtnOK: TButton
    Left = 82
    Top = 62
    Width = 75
    Height = 25
    Caption = #29983#25104
    TabOrder = 1
    OnClick = BtnOKClick
  end
end
