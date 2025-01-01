{*******************************************************************************
  ����: dmzn@ylsoft.com 2024-12-20
  ����: ͨ���;���
*******************************************************************************}
unit UEqualizer;

interface

uses
  Winapi.Windows, System.Classes, System.SyncObjs, System.SysUtils, superobject,
  bass, System.IOUtils, ULibFun, Vcl.Forms, UManagerGroup;

const
  {*�����ʶ*}
  cEqualizer_All = 27;
  cEqualizer_Rever = 100;
  cEqualizer_125 = 125;
  cEqualizer_1K = 1000;
  cEqualizer_8K = 8000;

  {*��������*}
  cChan_Invlid = 0;

type
  PEqualizerChan = ^TEqualizerChan;

  //����
  TEqualizerChan = record
    FUsed: Boolean;                                //�Ƿ�ʹ��
    FID: Cardinal;                                 //ͨ����ʶ
    FHandle: DWORD;                                //ͨ�����

    FMemory: TMemoryStream;                        //��������
    FValue: array[1..4] of integer;                //��������
    FInitVal: Boolean;                             //���ݳ�ʼ��
  end;

  PEqualizerModal = ^TEqualizerModal;

  //����ģ��
  TEqualizerModal = record
    FEnabled: Boolean;                             //�Ƿ���Ч
    FDefault: Boolean;                             //�Ƿ�Ĭ��
    FID: string;                                   //ģ���ʶ
    FLang: string;                                 //����
    FVoice: string;                                //��ɫ

    FLoopTime: Integer;                            //ѭ������
    FLoopInterval: Cardinal;                       //ѭ�����
    FOnHour: Boolean;                              //���㱨ʱ
    FOnHourText: string;                           //��ʱ����
    FOnHalfHour: Boolean;                          //��㱨ʱ
    FOnHalfText: string;                           //��ʱ����

    FSpeed: Integer;                               //����
    FVolume: Integer;                              //����
    FPitch: Integer;                               //����
    FDemoText: string;                             //�����ı�
  end;

  //��������
  TEqualizerData = record
    F125: Integer;
    F1K: Integer;
    F8K: Integer;
    FRever: Integer;
  end;

  TEqualizer = class(TObject)
  private
    FChanged: Boolean;
    {*��ʶ*}
    FChannels: TList;
    {*ͨ���б�*}
    FChanFirst: Cardinal;
    {*�׸�ͨ��*}
    FParam: BASS_DX8_PARAMEQ;
    FRever: BASS_DX8_REVERB;
    {*���������*}
    FData: TEqualizerData;
    {*��������*}
    FModals: TList;
    {*ģ���б�*}
    FSyncLock: TCriticalSection;
    {*ͬ������*}
  protected
    function GetChan(const id: Cardinal; const nFree: Boolean): Integer;
    function GetModal(const nID: string; const nDef: Boolean): PEqualizerModal;
    {*��������*}
    procedure DisposeChan(const nIdx: Integer; nFree, nClear: Boolean);
    procedure ClearModals(const nFree: Boolean);
    {*�ͷ���Դ*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    function LoadConfig(const nFile: string): Boolean;
    procedure SaveConfig(const nFile: string; nReset: Boolean = True);
    {*��д����*}
    class function InitBassLibrary: Boolean;
    class procedure FreeBassLibrary;
    {*bass��*}
    function NewChan(const nFile: string): PEqualizerChan;
    function FindChan(const id: Cardinal): PEqualizerChan;
    procedure PlayChan(const id: Cardinal);
    procedure FreeChan(const id: Cardinal; nClearOnly: Boolean = False);
    {*ͨ������*}
    function ChanValid(const chan: PEqualizerChan): Boolean;
    function ChanIdle(const chan: PEqualizerChan): Boolean;
    {*ͨ����B*}
    function InitEqualizer(const id: Cardinal): Boolean;
    {*��ʼ������*}
    procedure SetEqualizer(const id: Cardinal; nVal, nType: Integer);
    {*���þ���ֵ*}
    procedure AddModal(const nModal: PEqualizerModal);
    function FindModal(const nID: string): TEqualizerModal;
    procedure DeleteModal(const nID: string);
    {*����ģ��*}
    property Modals: TList read FModals;
    property Channels: TList read FChannels;
    property FirstChan: Cardinal read FChanFirst;
    property ConfigChanged: Boolean read FChanged;
    property EqualizerData: TEqualizerData read FData;
    property SyncLock: TCriticalSection read FSyncLock;
    {*�������*}
  end;

var
  gEqualizer: TEqualizer = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TEqualizer, 'TTS-ͨ������', nEvent);
end;

//Date: 2024-12-20
//Desc: ��ʼ��ͨ��
constructor TEqualizer.Create;
begin
  FChanged := False;
  with FData do
  begin
    F125 := 15;
    F1k := 15;
    F8K := 15;
    FRever := 20;
  end;

  FChannels := TList.Create;
  FModals := TList.Create;
  FSyncLock := TCriticalSection.Create;

  FChanFirst := NewChan('').FID;
  //default chan
end;

//Date: 2024-12-20
//Desc: �ͷ�ͨ��
destructor TEqualizer.Destroy;
var
  nIdx: Integer;
begin
  for nIdx := FChannels.Count - 1 downto 0 do
    DisposeChan(nIdx, True, False);
  FChannels.Free;

  ClearModals(True);
  FSyncLock.Free;
  inherited;
end;

//Date: 2024-12-18
//Desc: ��ʼ����ý��bass��
class function TEqualizer.InitBassLibrary: Boolean;
begin
  Result := False;
  // check the correct BASS was loaded
  if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
  begin
    WriteLog('��ý���"bass"�汾��ƥ��.');
    Exit;
  end;

	// Initialize audio - default device, 44100hz, stereo, 16 bits
  if not BASS_Init(-1, 44100, 0, Application.MainForm.Handle, nil) then
  begin
    WriteLog('��ʼ����Ƶ(base.audio)ʧ��.');
    Exit;
  end;

  //BASS_SetConfig(BASS_CONFIG_BUFFER, 1000);
  Result := True;
end;

//Date: 2024-12-18
//Desc: �ͷ�bass��
class procedure TEqualizer.FreeBassLibrary;
begin
	// Close BASS
  BASS_Free();
end;

//Date: 2024-12-20
//Parm: ��ʶ;δʹ�õ�
//Desc: ����chanͨ��������
function TEqualizer.GetChan(const id: Cardinal; const nFree: Boolean): Integer;
var
  nIdx: Integer;
  nChan: PEqualizerChan;
begin
  Result := -1;
  //init first

  for nIdx := 0 to FChannels.Count - 1 do
  begin
    nChan := FChannels[nIdx];
    if nFree then
    begin
      if not nChan.FUsed then
      begin
        Result := nIdx;
        Break;
      end;
    end
    else
    begin
      if nChan.FUsed and (nChan.FID = id) then
      begin
        Result := nIdx;
        Break;
      end;
    end;
  end;
end;

//Date: 2024-12-20
//Parm: ͨ������;�ͷ��ڴ�;ֻ����
//Desc: �ͷ�nIdxͨ��,������ͨ������
procedure TEqualizer.DisposeChan(const nIdx: Integer; nFree, nClear: Boolean);
var
  nChan: PEqualizerChan;
begin
  nChan := FChannels[nIdx];
  if nChan.FUsed and (nChan.FHandle <> cChan_Invlid) then
  begin
    BASS_MusicFree(nChan.FHandle);
    BASS_StreamFree(nChan.FHandle); //free resource
    nChan.FHandle := cChan_Invlid;

    if Assigned(nChan.FMemory) then
      FreeAndNil(nChan.FMemory);
    //xxxxx
  end;

  if nFree then
  begin
    Dispose(nChan);
  end
  else
  begin
    nChan.FInitVal := False;
    //reset flag

    if not nClear then //��ȫ�ͷ�
    begin
      nChan.FUsed := False;
    end;
  end;
end;

//Date: 2024-12-23
//Parm: �ͷŶ���
//Desc: ���ģ���б�
procedure TEqualizer.ClearModals(const nFree: Boolean);
var
  nIdx: Integer;
begin
  for nIdx := FModals.Count - 1 downto 0 do
    Dispose(PEqualizerModal(FModals[nIdx]));
  //xxxxx

  if nFree then
    FreeAndNil(FModals)
  else
    FModals.Clear;
end;

//Date: 2024-12-20
//Parm: ����
//Desc: ����ͨ������
function TEqualizer.FindChan(const id: Cardinal): PEqualizerChan;
var
  nIdx: Integer;
begin
  FSyncLock.Enter;
  try
    nIdx := GetChan(id, False);
    if nIdx < 0 then
      Result := nil
    else
      Result := FChannels[nIdx];
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2024-12-20
//Parm: ����;ֻ����
//Desc: �ͷ�chanͨ��,��nKeepLockֻ�����ͷ�
procedure TEqualizer.FreeChan(const id: Cardinal; nClearOnly: Boolean);
var
  nIdx: Integer;
begin
  FSyncLock.Enter;
  try
    nIdx := GetChan(id, False);
    if nIdx >= 0 then
      DisposeChan(nIdx, False, nClearOnly);
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2024-12-20
//Parm: wav�ļ�
//Desc: �½�ͨ��
function TEqualizer.NewChan(const nFile: string): PEqualizerChan;
var
  nStr: string;
  nIdx: Integer;
begin
  FSyncLock.Enter;
  try
    nIdx := GetChan(0, True);
    if nIdx < 0 then
    begin
      New(Result);
      FChannels.Add(Result);
    end
    else
    begin
      Result := FChannels[nIdx];
      //xxxxx
    end;

    FillChar(Result^, SizeOf(TEqualizerChan), #0); //reset all
    Result.FUsed := True;
    Result.FID := gMG.FSerialIDManager.GetID;
  finally
    FSyncLock.Leave;
  end;

  if nFile = '' then
    Exit;
  //invalid

  nStr := ExtractFileName(nFile);
  if not FileExists(nFile) then
  begin
    WriteLog(Format('�����ļ�"%s"������.', [nStr]));
    Exit;
  end;

  Result.FHandle := BASS_StreamCreateFile(FALSE, PChar(nFile), 0, 0, BASS_SAMPLE_FX
      {$IFDEF UNICODE} or BASS_UNICODE {$ENDIF});
  //xxxxx

  if Result.FHandle = cChan_Invlid then
  begin
    WriteLog(Format('���������ļ�"%s"ʧ��.', [nStr]));
    Exit;
  end;
end;

//Date: 2024-12-20
//Parm: ��ʶ
//Desc: ��ʼ��chan�ľ������
function TEqualizer.InitEqualizer(const id: Cardinal): Boolean;
var
  nChan: PEqualizerChan;
begin
  Result := False;
  nChan := FindChan(id);
  if not (Assigned(nChan) and (nChan.FHandle <> cChan_Invlid)) then
    Exit;
  //invalid chan

  Result := nChan.FInitVal;
  if not nChan.FInitVal then
  try
    // Set equalizer to flat and reverb off to start
    nChan.FValue[1] := BASS_ChannelSetFX(nChan.FHandle, BASS_FX_DX8_PARAMEQ, 1);
    nChan.FValue[2] := BASS_ChannelSetFX(nChan.FHandle, BASS_FX_DX8_PARAMEQ, 1);
    nChan.FValue[3] := BASS_ChannelSetFX(nChan.FHandle, BASS_FX_DX8_PARAMEQ, 1);
    nChan.FValue[4] := BASS_ChannelSetFX(nChan.FHandle, BASS_FX_DX8_REVERB, 1);

    FParam.fGain := 0;
    FParam.fBandwidth := 18;
    FParam.fCenter := 125;
    BASS_FXSetParameters(nChan.FValue[1], @FParam);

    FParam.fCenter := 1000;
    BASS_FXSetParameters(nChan.FValue[2], @FParam);
    FParam.fCenter := 8000;
    BASS_FXSetParameters(nChan.FValue[3], @FParam);

    BASS_FXGetParameters(nChan.FValue[4], @FRever);
    FRever.fReverbMix := -96;
    FRever.fReverbTime := 1200;
    FRever.fHighFreqRTRatio := 0.1;
    BASS_FXSetParameters(nChan.FValue[4], @FRever);

    nChan.FInitVal := True;
    Result := True;
  except
    on nErr: Exception do
    begin
      WriteLog('��ʼ��������ʧ��: ' + nErr.Message);
    end;
  end;
end;

//Date: 2024-12-24
//Parm: ��ʶ;ֵ;����
//Desc: Ϊidͨ�����þ���ֵ
procedure TEqualizer.SetEqualizer(const id: Cardinal; nVal, nType: Integer);
var
  nChan: PEqualizerChan;
  nAction: TProc<Integer, Integer>;
begin
  nChan := FindChan(id);
  if not (Assigned(nChan) and
    (nChan.FHandle <> cChan_Invlid) and nChan.FInitVal) then
    Exit;
  //invalid chan

  nAction :=
    procedure(nV, nT: Integer)
    begin
      case nT of
        cEqualizer_Rever:
          begin
            BASS_FXGetParameters(nChan.FValue[4], @FRever);
            // give exponential quality to trackbar as Bass more sensitive near 0
            FRever.fReverbMix := -0.012 * nV * nV * nV; // gives -96 when bar at 20
            BASS_FXSetParameters(nChan.FValue[4], @FRever);

            if nV <> FData.FRever then
            begin
              FData.FRever := nV;
              FChanged := True;
            end;
          end;
        cEqualizer_125:
          begin
            BASS_FXGetParameters(nChan.FValue[1], @FParam);
            FParam.fgain := 15 - nV;
            BASS_FXSetParameters(nChan.FValue[1], @FParam);

            if nV <> FData.F125 then
            begin
              FData.F125 := nV;
              FChanged := True;
            end;
          end;
        cEqualizer_1K:
          begin
            BASS_FXGetParameters(nChan.FValue[2], @FParam);
            FParam.fgain := 15 - nV;
            BASS_FXSetParameters(nChan.FValue[2], @FParam);

            if nV <> FData.F1K then
            begin
              FData.F1K := nV;
              FChanged := True;
            end;
          end;
        cEqualizer_8K:
          begin
            BASS_FXGetParameters(nChan.FValue[3], @FParam);
            FParam.fgain := 15 - nV;
            BASS_FXSetParameters(nChan.FValue[3], @FParam);

            if nV <> FData.F8K then
            begin
              FData.F8K := nV;
              FChanged := True;
            end;
          end;
      end;
    end;

  if nType = cEqualizer_All then //ʹ��ȫ�ֲ���
  begin
    nAction(FData.F125, cEqualizer_125);
    nAction(FData.F1k, cEqualizer_1K);
    nAction(FData.F8K, cEqualizer_8K);
    nAction(FData.FRever, cEqualizer_Rever);
  end
  else
  begin
    nAction(nVal, nType);
    //apply setting
  end;
end;

//Date: 2024-12-20
//Parm: ��ʶ
//Desc: ����chanͨ��
procedure TEqualizer.PlayChan(const id: Cardinal);
var
  nChan: PEqualizerChan;
begin
  nChan := FindChan(id);
  if ChanIdle(nChan) then
    BASS_ChannelPlay(nChan.FHandle, False);
  //xxxxx
end;

//Date: 2024-12-31
//Parm: ͨ��
//Desc: ͨ���Ƿ����
function TEqualizer.ChanIdle(const chan: PEqualizerChan): Boolean;
begin
  Result := False;
  if ChanValid(chan) then
    Result := BASS_ChannelIsActive(chan.FHandle) = BASS_ACTIVE_STOPPED;
  //xxxxx
end;

//Date: 2025-01-01
//Parm: ͨ��
//Desc: ͨ���Ƿ���Ч
function TEqualizer.ChanValid(const chan: PEqualizerChan): Boolean;
begin
  Result := Assigned(chan) and (chan.FHandle <> cChan_Invlid);
end;

//------------------------------------------------------------------------------
//Date: 2024-12-23
//Parm: �����ļ�
//Desc: ���������ļ�
function TEqualizer.LoadConfig(const nFile: string): Boolean;
var
  nIdx: Integer;
  nModal: PEqualizerModal;
  nRoot, nNode: ISuperObject;
  nArray: TSuperArray;
begin
  Result := False;
  if not FileExists(nFile) then
    Exit;
  //invalid file

  nRoot := nil;
  try
    nRoot := SO(TFile.ReadAllText(nFile, TEncoding.UTF8));
    //load

    nNode := nRoot.O['equalize'];
    if Assigned(nNode) then
    begin
      FData.F125 := nNode.I['125'];
      FData.F1k := nNode.I['1k'];
      FData.F8K := nNode.I['8k'];
      FData.FRever := nNode.I['rever'];
    end;

    ClearModals(False);
    //init first

    nArray := nRoot.A['modals'];
    if Assigned(nArray) then
    begin
      for nIdx := 0 to nArray.Length - 1 do
      begin
        New(nModal);
        FModals.Add(nModal);

        with nModal^ do
        begin
          FEnabled := True;
          FDefault := nArray[nIdx].B['default'];
          FID := nArray[nIdx].S['id'];
          FLang := nArray[nIdx].S['lang'];
          FVoice := nArray[nIdx].S['voice'];

          FLoopTime := nArray[nIdx].I['loop'];
          FLoopInterval := nArray[nIdx].I['loop-int'];
          FOnHour := nArray[nIdx].B['hour'];
          FOnHourText := nArray[nIdx].S['hour-text'];
          FOnHalfHour := nArray[nIdx].B['half'];
          FOnHalfText := nArray[nIdx].S['half-text'];

          FSpeed := nArray[nIdx].I['speed'];
          FVolume := nArray[nIdx].I['volume'];
          FPitch := nArray[nIdx].I['pitch'];
          FDemoText := nArray[nIdx].S['demo'];
        end;
      end;
    end;

    FChanged := False;
    //set flag
    Result := True;
  finally
    nRoot := nil;
  end;
end;

//Date: 2024-12-23
//Parm: �����ļ�;���ñ�ʶ
//Desc: �������õ�nFile��
procedure TEqualizer.SaveConfig(const nFile: string; nReset: Boolean);
var
  nIdx: Integer;
  nModal: PEqualizerModal;
  nRoot, nNode: ISuperObject;
  nArray: TSuperArray;
begin
  nRoot := nil;
  try
    nRoot := SO();
    nNode := SO();
    nRoot.O['equalize'] := nNode;

    with FData do
    begin
      nNode.I['125'] := F125;
      nNode.I['1k'] := F1K;
      nNode.I['8k'] := F8K;
      nNode.I['rever'] := FRever;
    end;

    nRoot.O['modals'] := SO('[]');
    nArray := nRoot.A['modals'];
    for nIdx := 0 to FModals.Count - 1 do
    begin
      nModal := FModals[nIdx];
      if not nModal.FEnabled then
        Continue;
      //invalid

      nNode := SO();
      with nModal^ do
      begin
        nNode.B['default'] := FDefault;
        nNode.S['id'] := FID;
        nNode.S['lang'] := FLang;
        nNode.S['voice'] := FVoice;

        nNode.I['loop'] := FLoopTime;
        nNode.I['loop-int'] := FLoopInterval;
        nNode.B['hour'] := FOnHour;
        nNode.S['hour-text'] := FOnHourText;
        nNode.B['half'] := FOnHalfHour;
        nNode.S['half-text'] := FOnHalfText;

        nNode.I['speed'] := FSpeed;
        nNode.I['volume'] := FVolume;
        nNode.I['pitch'] := FPitch;
        nNode.S['demo'] := FDemoText;
      end;

      nArray.Add(nNode);
      //add modal
    end;

    TFile.WriteAllText(nFile, nRoot.AsJSon(True), TEncoding.UTF8);
    //save

    if nReset then
      FChanged := False;
    //xxxxx
  finally
    nRoot := nil;
  end;
end;

//Date: 2024-12-23
//Parm: ģ���ʶ;Ĭ��
//Desc: ���ұ�ʶnID��ģ������
function TEqualizer.GetModal(const nID: string; const nDef: Boolean):
  PEqualizerModal;
var
  nIdx: Integer;
begin
  for nIdx := 0 to FModals.Count - 1 do
  begin
    Result := FModals[nIdx];
    if nDef then
    begin
      if Result.FDefault then
        Exit;
        //found default
    end
    else
    begin
      if CompareText(nID, Result.FID) = 0 then
        Exit;
      //has found
    end;
  end;

  Result := nil;
end;

//Date: 2024-12-23
//Parm: ģ���ʶ;�Ƿ�����
//Desc: ������ʶΪnID��ģ��
function TEqualizer.FindModal(const nID: string): TEqualizerModal;
var
  nModal: PEqualizerModal;
begin
  FSyncLock.Enter;
  //xxxxx
  try
    nModal := GetModal(nID, nID = '');
    if Assigned(nModal) then
    begin
      Result := nModal^;
      //��������
    end
    else
    begin
      Result.FID := '';
      Result.FEnabled := False;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2024-12-23
//Parm: ����ģ��
//Desc: ���nModal
procedure TEqualizer.AddModal(const nModal: PEqualizerModal);
var
  nIdx: Integer;
  nData: PEqualizerModal;
begin
  FSyncLock.Enter;
  try
    if nModal.FDefault then //ȡ������Ĭ��
    begin
      for nIdx := FModals.Count - 1 downto 0 do
      begin
        nData := FModals[nIdx];
        if nData.FDefault then
          nData.FDefault := False;
        //xxxxx
      end;
    end;

    nData := GetModal(nModal.FID, False);
    if not Assigned(nData) then
    begin
      New(nData);
      FModals.Add(nData);
    end;

    nData^ := nModal^;
    FChanged := True;
    //set flag
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2024-12-25
//Parm: ģ���ʶ
//Desc: ɾ��ģ��
procedure TEqualizer.DeleteModal(const nID: string);
var
  nModal: PEqualizerModal;
begin
  FSyncLock.Enter;
  //xxxxx
  try
    nModal := GetModal(nID, False);
    if Assigned(nModal) then
    begin
      nModal.FEnabled := False;
      FChanged := True;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

initialization
  gEqualizer := TEqualizer.Create;

finalization
  FreeAndNil(gEqualizer);

end.

