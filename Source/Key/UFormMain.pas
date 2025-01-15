{*******************************************************************************
  作者: dmzn@163.com 2025-01-15
  描述: 有效期授权
*******************************************************************************}
unit UFormMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

type
  TfFormMain = class(TForm)
    EditDate: TDateTimePicker;
    Label1: TLabel;
    BtnOK: TButton;
    procedure BtnOKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fFormMain: TfFormMain;

implementation

{$R *.dfm}

uses
  ULibFun, USysConst;

procedure TfFormMain.FormCreate(Sender: TObject);
begin
  EditDate.Date := Now() + 365;
end;

procedure TfFormMain.BtnOKClick(Sender: TObject);
var
  nStr: string;
begin
  with TApplicationHelper, TDateTimeHelper do
  begin
    nStr := gPath + sFileKey;
    AddExpireDate(nStr, Date2Str(EditDate.Date), True);
    ShowMsg('授权完毕', sHint);
  end;
end;

end.

