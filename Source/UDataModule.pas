{*******************************************************************************
  ����: dmzn@163.com 2024-12-21
  ����: ����ģ��
*******************************************************************************}
unit UDataModule;

interface

uses
  System.SysUtils, System.Classes, System.ImageList, Vcl.ImgList, Vcl.Controls,
  dxSkinsCore, dxSkinHighContrast, dxSkinMcSkin, dxSkinOffice2007Blue,
  dxSkinOffice2007Green, dxSkinOffice2019White, dxSkinSevenClassic, dxCore,
  IdContext, IdCustomHTTPServer, IdBaseComponent, IdComponent, IdCustomTCPServer,
  IdHTTPServer, cxClasses, cxLookAndFeels, dxSkinsForm, cxImageList, cxGraphics;

const
  {*ͼ������*}
  cImg_Skin = 8;
  cImg_male = 9;
  cImg_female = 10;
  cImg_lang = 11;
  cImg_Modal = 12;

type
  TFDM = class(TDataModule)
    Images16: TcxImageList;
    dxSkin1: TdxSkinController;
    cxLF1: TcxLookAndFeelController;
    Server1: TIdHTTPServer;
    procedure DataModuleCreate(Sender: TObject);
    procedure Server1CommandGet(AContext: TIdContext; nReq: TIdHTTPRequestInfo;
      nRes: TIdHTTPResponseInfo);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure LoadSkins(const nList: TStrings);
    procedure SetSkin(const nSkin: string);
    {*Ƥ�����*}
    function StartServer: Boolean;
    procedure StopServer;
  end;

var
  FDM: TFDM;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

uses
  cxLookAndFeelPainters, ULibFun, UManagerGroup, UServiceTTS, USysConst;

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TFDM, 'TTS-����ģ��', nEvent);
end;

procedure TFDM.DataModuleCreate(Sender: TObject);
begin
  //
end;

//Date: 2024-12-20
//Parm: �б�
//Desc: ��ȡƤ���б�nList
procedure TFDM.LoadSkins(const nList: TStrings);
var
  nIdx: Integer;
begin
  for nIdx := 0 to cxLookAndFeelPaintersManager.Count - 1 do
    with cxLookAndFeelPaintersManager[nIdx] do
      if (LookAndFeelStyle = lfsSkin) and (not IsInternalPainter) then
        nList.Add(LookAndFeelName);
  //xxxxx
end;

//Date: 2024-12-20
//Parm: Ƥ������
//Desc: ����nSkin
procedure TFDM.SetSkin(const nSkin: string);
var
  nList: TStrings;
begin
  nList := TStringList.Create;
  try
    LoadSkins(nList);
    if nList.IndexOf(nSkin) < 0 then
    begin
      cxLF1.NativeStyle := True;
      dxSkin1.NativeStyle := True;
    end
    else
    begin
      cxLF1.NativeStyle := False;
      dxSkin1.SkinName := nSkin;
      dxSkin1.NativeStyle := False;
    end;
  finally
    nList.Free;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2024-12-26
//Desc: ��������
function TFDM.StartServer: Boolean;
var
  nStr: string;
begin
  Result := False;
  try
    Server1.Active := False;
    nStr := gApp.FActive.GetParam('SrvPort');
    if (nStr <> '') and TStringHelper.IsNumber(nStr, False) then
      Server1.DefaultPort := StrToInt(nStr)
    else
      Server1.DefaultPort := gApp.FActive.FPort;

    Server1.Active := True;
    //start server
    nStr := Format('http://%s:%d/tts', [gApp.FLocalIP, Server1.DefaultPort]);
    WriteLog(nStr);

    gVoiceManager.StartService();
    Result := True;
  except
    on nErr: Exception do
    begin
      WriteLog('StartServer: ' + nErr.Message);
    end;
  end;
end;

//Date: 2024-12-26
//Desc: ֹͣ����
procedure TFDM.StopServer;
begin
  Server1.Active := False;
  gVoiceManager.StopService();
end;

//Date: 2024-12-26
//Desc: ����http����
procedure TFDM.Server1CommandGet(AContext: TIdContext; nReq: TIdHTTPRequestInfo;
  nRes: TIdHTTPResponseInfo);
var
  nData, nModal: string;
  nIdx: Integer;
  nMulti: Boolean;
begin
  if (nReq.CommandType = hcGET) and (LowerCase(nReq.URI) = '/tts') then
  begin
    {����3�в���:
     1.data: �ı�����
     2.modal: ģ������
     3.key=value: �������ƺ�ֵ,���ж��

     Ex:
     http://ip:8000/tts?data=base64_text&modal=modal_name
     http://ip:8000/tts?key1=base64_value1&key2=base64_value2&modal=modal_name
    }

    nModal := Trim(nReq.Params.Values['modal']);
    nData := Trim(nReq.Params.Values['data']);
    nMulti := nData = '';

    if nMulti then
    begin
      nIdx := nReq.Params.IndexOfName('data');
      if nIdx >= 0 then
        nReq.Params.Delete(nIdx);
      //xxxxx

      nIdx := nReq.Params.IndexOfName('modal');
      if nIdx >= 0 then
        nReq.Params.Delete(nIdx);
      //xxxxx

      nData := Trim(nReq.Params.Text);
      //key=value
    end;

    if nData <> '' then
    try
      gVoiceManager.PlayVoice(nData, nModal, nMulti);
      //play
      nRes.ResponseNo := 200;
      nRes.ResponseText := 'ok';
    except
      on nErr: Exception do
      begin
        nRes.ResponseNo := 500;
        nRes.ResponseText := nErr.Message;
      end;
    end;
  end;
end;

end.

