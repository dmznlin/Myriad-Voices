{*******************************************************************************
  ����: dmzn@163.com 2024-12-23
  ����: tts����
*******************************************************************************}
unit UServiceTTS;

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, System.SyncObjs, bass,
  UEqualizer, UThreadPool;

type
  PVoiceItem = ^TVoiceItem;

  TVoiceItem = record
    FID: string;     //��ɫ��ʶ
    FName: string;   //��ɫ����
    FGender: string; //��ɫ�Ա�
    FLocale: string; //�����ʶ
    FDesc: string;   //��������
  end;

  PVoiceData = ^TVoiceData;

  TVoiceData = record
    FUsed: Boolean;                //ʹ�ñ��
    FLock: Boolean;                //�������
    FLast: Cardinal;               //�ϴ�ִ��
    FRunTime: Integer;             //ִ�д���
    FChan: PEqualizerChan;         //ͨ��
    FModal: TEqualizerModal;       //ģ��
    FData: string;                 //����
  end;

  TVoiceManager = class(TObject)
  private
    FVoices: TList;
    {*��ɫ�б�*}
    FDataList: TList;
    {*����*}
    FRemoteURL: string;
    {*�����ַ*}
    FStrickNext: TDateTime;
    {*���㱨ʱ*}
    FTaskID: string;
    FTaskNext: TDateTime;
    {*���żƻ�*}
    FWorker: TThreadWorkerConfig;
    {*�����߳�*}
    FSyncLock: TCriticalSection;
    {*ͬ������*}
  protected
    procedure ClearVoice(const nFree: Boolean);
    procedure ClearData(const nFree: Boolean);
    {*�ͷ���Դ*}
    procedure SetRemoteURL(nURL: string);
    {*���ò���*}
    function NextTaskTime(const nNow: TDateTime; var nID: string): TDateTime;
    {*�ƻ�ʱ��*}
    function NextStrickTime(const nNow: TDateTime; nFromNow: Boolean): TDateTime;
    procedure DoStrickHour(const nNow: TDateTime);
    procedure DoTaskVoice(const nNow: TDateTime);
    procedure DoPlay(const nCfg: PThreadWorkerConfig; const nThread: TThread);
    {*�̲߳���*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    function LoadVoice(): Boolean;
    {*��ɫ���*}
    function PlayVoice(nChan: PEqualizerChan; nModal: PEqualizerModal; nText:
      string = ''): Boolean; overload;
    procedure PlayVoice(nMsg, nModal: string; nMulti: Boolean; nEncode: Boolean
      = True); overload;
    {*��������*}
    procedure StartService();
    procedure StopService();
    {*��ͣ����*}
    property Voices: TList read FVoices;
    property VoiceData: TList read FDataList;
    property SyncLock: TCriticalSection read FSyncLock;
    property RemoteURL: string read FRemoteURL write SetRemoteURL;
    {*�������*}
  end;

var
  gVoiceManager: TVoiceManager = nil;
  //ȫ��ʹ��

implementation

uses
  System.DateUtils, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdHTTP, IdURI, superobject, ULibFun, UManagerGroup;

const
  {*��ʱ����*}
  cTimeoutConn = 5 * 1000;
  cTimeoutRead = 3 * 1000;

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TVoiceManager, 'TTS-�����ϳ�', nEvent);
end;

constructor TVoiceManager.Create;
begin
  gMG.FObjectPool.NewClass(TIdHTTP,
    function(var nData: Pointer): TObject
    begin
      Result := TIdHTTP.Create;
    end,
    procedure(const nObject: TObject; const nData: Pointer)
    begin
      TIdHTTP(nObject).Free;
    end, nil, True);
  //xxxxx

  FVoices := TList.Create;
  FDataList := TList.Create;
  FSyncLock := TCriticalSection.Create;

  gMG.FThreadPool.WorkerInit(FWorker);
  with FWorker do
  begin
    FWorkerName := 'TVoiceManager.Worker';
    FParentObj := Self;
    FParentDesc := '�����ϳɵ���';
    FCallTimes := 0; //��ͣ
    FCallInterval := 500;
    FOnWork.WorkEvent := DoPlay;
  end;

  gMG.FThreadPool.WorkerAdd(@FWorker);
  //����߳���ҵ
end;

destructor TVoiceManager.Destroy;
begin
  StopService();
  ClearVoice(True);
  ClearData(True);

  FSyncLock.Free;
  inherited;
end;

//Date: 2024-12-23
//Parm: �Ƿ��ͷ��б�
//Desc: �����ɫ�б�
procedure TVoiceManager.ClearVoice(const nFree: Boolean);
var
  nIdx: Integer;
begin
  for nIdx := FVoices.Count - 1 downto 0 do
    Dispose(PVoiceItem(FVoices[nIdx]));
  //xxxxx

  if nFree then
    FreeAndNil(FVoices)
  else
    FVoices.Clear;
end;

//Date: 2024-12-30
//Parm: �Ƿ��ͷ�
//Desc: ������������
procedure TVoiceManager.ClearData(const nFree: Boolean);
var
  nIdx: Integer;
begin
  for nIdx := FDataList.Count - 1 downto 0 do
    Dispose(PVoiceData(FDataList[nIdx]));
  //xxxxx

  if nFree then
    FreeAndNil(FDataList)
  else
    FDataList.Clear;
end;

//Date: 2024-12-23
//Parm: tts�����ַ
//Desc: ���÷����ַΪnRUL
procedure TVoiceManager.SetRemoteURL(nURL: string);
begin
  nURL := LowerCase(nURL);
  if (Pos('http://', nURL) < 1) and (Pos('https://', nURL) < 1) then
    nURL := 'http://' + nURL;
  //protocol

  if TStringHelper.CopyRight(nURL, 1) <> '/' then
    nURL := nURL + '/';
  //path tag

  FRemoteURL := nURL;
end;

procedure TVoiceManager.StartService;
var
  nNow: TDateTime;
begin
  gEqualizer.UpdateDateBaseNow();
  //���µ�ǰʱ��

  nNow := Now();
  FStrickNext := NextStrickTime(nNow, True);
  //��ʱ��ʼ��
  FTaskNext := NextTaskTime(nNow, FTaskID);
  //�ƻ�����

  gMG.FThreadPool.WorkerStart(Self);
  FWorker.FCallTimes := INFINITE;
end;

procedure TVoiceManager.StopService;
begin
  gMG.FThreadPool.WorkerStop(Self);
  //stop thread
  FWorker.FCallTimes := 0;
end;

//Date: 2024-12-23
//Desc: �����ɫ�б�
function TVoiceManager.LoadVoice: Boolean;
var
  nStr: string;
  nIdx: Integer;
  nItem: PVoiceItem;
  nClient: TIdHTTP;
  nRoot: ISuperObject;
  nEnum: TSuperEnumerator;
  nArray: TSuperArray;
begin
  Result := False;
  nClient := nil;
  nEnum := nil;

  FSyncLock.Enter;
  try
    ClearVoice(False);
    //init first

    nClient := gMG.FObjectPool.Lock(TIdHTTP) as TIdHTTP;
    nClient.ConnectTimeout := cTimeoutConn;
    try
      nStr := nClient.Get(FRemoteURL + 'voices');
      nRoot := SO(nStr);

      if (nRoot.S['success'] <> 'true') or (nRoot.I['data.count'] < 1) then
        raise Exception.Create('δ�ҵ���ɫ�嵥.');
      //xxxxx

      nRoot := nRoot.O['data.catalog'];
      nEnum := nRoot.GetEnumerator();
      while nEnum.MoveNext() do
      begin
        nArray := nEnum.GetCurrent().AsArray;
        for nIdx := 0 to nArray.Length - 1 do
        begin
          New(nItem);
          FVoices.Add(nItem);

          with nItem^ do
          begin
            FID := nArray[nIdx].S['id'];
            FName := nArray[nIdx].S['name'];
            FGender := nArray[nIdx].S['gender'];
            FLocale := nArray[nIdx].S['locale'];
            FDesc := nArray[nIdx].S['desc'];
          end;
        end;
      end;
    except
      on nErr: Exception do
      begin
        WriteLog('LoadVoice: ' + nErr.Message);
        Exit;
      end;
    end;

    Result := True;
    //set flag
  finally
    FSyncLock.Leave;
    nEnum.Free;
    gMG.FObjectPool.Release(nClient);
  end;
end;

//------------------------------------------------------------------------------
//Date: 2024-12-31
//Parm: ����;�̱߳���
//Desc: ���߳���ִ�кϳ�����
procedure TVoiceManager.DoPlay(const nCfg: PThreadWorkerConfig; const nThread:
  TThread);
var
  nIdx: Integer;
  nNow: TDateTime;
  nData, nTmp: PVoiceData;
begin
  nNow := Now();
  if nNow >= FStrickNext then
    DoStrickHour(nNow);
  //���㱨ʱ

  if nNow >= FTaskNext then
    DoTaskVoice(nNow);
  //���żƻ�

  nData := nil;
  SyncLock.Enter;
  try
    for nIdx := FDataList.Count - 1 downto 0 do
    begin
      nTmp := FDataList[nIdx];
      if (not nTmp.FUsed) or nTmp.FLock then //���л�����
        Continue;
      //invalid

      if nTmp.FRunTime > 0 then //������
      begin
        if ((nTmp.FModal.FLoopTime < 1) or //��ѭ��
          (nTmp.FModal.FLoopTime <= nTmp.FRunTime)) then //��ѭ������
        begin
          if gEqualizer.ChanIdle(nTmp.FChan, False) then  //ͨ������
          begin
            nTmp.FUsed := False;
            gEqualizer.FreeChan(nTmp.FChan.FID);
          end;

          Continue;
        end;

        if not gEqualizer.ChanIdle(nTmp.FChan, False) then
          Continue;
        //�ϴβ���δ����
      end;

      if (nTmp.FModal.FLoopTime > 0) and
        (TDateTimeHelper.GetTickCountDiff(nTmp.FLast) < nTmp.FModal.FLoopInterval) then
        Continue;
      //ѭ��ʱ��δ��

      nData := nTmp;
      nData.FLock := True; //ѡ��
      Inc(nData.FRunTime);

      Break;
      //��ʼ����
    end;
  finally
    SyncLock.Leave;
  end;

  if Assigned(nData) then
  try
    if nData.FRunTime > 1 then //�ٴ�����
    begin
      if gEqualizer.ChanValid(nData.FChan) then
        gEqualizer.PlayChan(nData.FChan.FID)
      else
        PlayVoice(nData.FChan, @nData.FModal, nData.FData);
    end
    else
    begin
      nData.FChan := gEqualizer.NewChan();
      //�״�����
      PlayVoice(nData.FChan, @nData.FModal, nData.FData);
    end;

    nData.FLast := TDateTimeHelper.GetTickCount();
    //����ʱ���
  finally
    nData.FLock := False;
  end;
end;

//Date: 2024-12-31
//Parm: ��ǰʱ��
//Desc: ִ�����㱨ʱ
procedure TVoiceManager.DoStrickHour(const nNow: TDateTime);
var
  nMsg: string;
  nH, nM, nS, nMS: Word;
  nModal: TEqualizerModal;
begin
  FStrickNext := NextStrickTime(nNow, False);
  nMsg := '';
  DecodeTime(nNow, nH, nM, nS, nMS);

  if nM = 0 then //����
  begin
    nModal := gEqualizer.FindModal('');
    if not (nModal.FEnabled and nModal.FOnHour) then
      Exit;
    //ģ����Ч,���������㱨ʱ

    nMsg := nModal.FOnHourText;
    if nMsg = '' then
    begin
      WriteLog('δ�������㱨ʱ����.');
      Exit;
    end;
  end;

  if nM = 30 then //���
  begin
    nModal := gEqualizer.FindModal('');
    if not (nModal.FEnabled and nModal.FOnHalfHour) then
      Exit;
    //ģ����Ч,���������㱨ʱ

    nMsg := nModal.FOnHalfText;
    if nMsg = '' then
    begin
      WriteLog('δ���ð�㱨ʱ����.');
      Exit;
    end;
  end;

  if nMsg <> '' then
  begin
    nMsg := StringReplace(nMsg, '$hr', nH.ToString, [rfReplaceAll, rfIgnoreCase]);
    //�滻Сʱ����
    //PlayVoice(gEqualizer.FirstChan, @nModal, nMsg);
    PlayVoice(nMsg, nModal.FID, False, False);
  end;
end;

//Date: 2025-01-02
//Parm: ��ǰʱ��;�Ƿ������ǰʱ��
//Desc: ���ݵ�ǰʱ��,�����´α�ʱʱ��
function TVoiceManager.NextStrickTime(const nNow: TDateTime; nFromNow: Boolean):
  TDateTime;
var
  nH, nM, nS, nMS: Word;
begin
  DecodeTime(nNow, nH, nM, nS, nMS);
  if nFromNow and ((nM = 0) or (nM = 30)) then
  begin
    Result := DateOf(nNow) + EncodeTime(nH, nM, 0, 0);
    //��ǰʱ��:����,���
  end
  else if nM < 30 then
  begin
    Result := DateOf(nNow) + EncodeTime(nH, 30, 0, 0);
    //�´�Ϊ���
  end
  else
  begin
    Result := IncMinute(nNow, 30); //���ܿ���
    DecodeTime(Result, nH, nM, nS, nMS);
    Result := DateOf(Result) + EncodeTime(nH, 0, 0, 0); //����
  end;

  WriteLog('�´α�ʱ ' + TDateTimeHelper.Time2Str(Result));
end;

//------------------------------------------------------------------------------
//Date: 2025-01-08
//Parm: �ƻ�;��ǰʱ��;����ʱ��
//Desc: ���nTask.FDateNext �� nNew �Ƿ���Ч(δ��ʱ,δ��ʱ)
function TimeValid(const nTask: PEqualizerTask; const nNow: TDateTime; nNew:
  TDateTime = 0): Boolean;
begin
  if Assigned(nTask) then
  begin
    Result := (nTask.FDateLast = 0) or (nTask.FDateNext <> nTask.FDateLast);
    //�ƻ�δ����

    if not Result then
      Exit;
    nNew := nTask.FDateNext;
  end;

  Result := nNew >= nNow;
  //δ��ʱ

  if not Result then
    Result := (DateTimeToMilliseconds(nNow) - DateTimeToMilliseconds(nNew))
      div (MSecsPerSec * SecsPerMin) < 1;
  //����1������Ϊ��ʱ
end;

//Date: 2025-01-09
//Parm: ����
//Desc: ��ȡnDate��yyyy-MM-01
function Month1Day(const nDate: TDateTime): TDateTime;
var
  nY, nM, nD: Word;
begin
  DecodeDate(nDate, nY, nM, nD);
  Result := EncodeDate(nY, nM, 1);
end;

//Date: 2025-01-10
//Parm: ��ǰʱ��;��ȥʱ��
//Desc: ����nNow,nOld��ʱ���,�����
function SecondDiff(nNow, nOld: TDateTime): Int64;
begin
  nNow := IncMilliSecond(nNow, MilliSecondOf(nNow) * (-1));
  nOld := IncMilliSecond(nOld, MilliSecondOf(nOld) * (-1));
  //ɾ������

  if nNow <= nOld then
    Result := 0
  else
    Result := Round(MilliSecondsBetween(nNow, nOld) / MSecsPerSec);
end;

//Date: 2025-01-06
//Parm: ��ǰʱ��;�����ʶ
//Desc: ���ݵ�ǰʱ��,�����´μƻ�����ʱ��
function TVoiceManager.NextTaskTime(const nNow: TDateTime; var nID: string):
  TDateTime;
var
  nIdx: Integer;
  nTask: PEqualizerTask;
  nInt, nVal: Int64;
  nY, nM, nD, nH, nMM, nSS, nMS: Word;
  nY1, nM1, nD1, nH1, nMM1, nSS1, nMS1: Word;
begin
  Result := IncSecond(nNow, 10);
  //Ĭ��10���,����ɨ���ٶ�
  nID := '';
  nY := 0;

  gEqualizer.SyncLock.Enter;
  try
    for nIdx := gEqualizer.Tasks.Count - 1 downto 0 do
    begin
      nTask := gEqualizer.Tasks[nIdx];
      if (not nTask.FEnabled) or (nTask.FDateLast = cDate_Invalid) then
        Continue;
      //�ƻ�����Ч

      if (nTask.FDateNext > 0) and
        (nTask.FType = etSecond) and (not nTask.FDateFix) then
        nTask.FDateNext := 0;
      //ÿ��s���ʱ,ÿ��ɨ�趼��Ҫ���¼���

      if (nTask.FDateNext > 0) and (nTask.FDateNext = nTask.FDateLast) and
        (SecondDiff(nNow, nTask.FDateLast) > 1) then
        nTask.FDateNext := 0;
      //�Ѳ������,�ӳ�1������¼���

      if (nTask.FDateNext > 0) and TimeValid(nil, nNow, nTask.FDateNext) then
        Continue;
      //δ��ʱ,�������¼����´β���ʱ��

      if nY = 0 then //��ֵ�ǰʱ��
      begin
        DecodeDate(nNow, nY, nM, nD);
        DecodeTime(nNow, nH, nMM, nSS, nMS);
      end;

      DecodeDate(nTask.FDate, nY1, nM1, nD1);
      DecodeTime(nTask.FDate, nH1, nMM1, nSS1, nMS1);
      //����趨ʱ��

      case nTask.FType of
        etYear: //��ʱ
          if nTask.FDate < nNow then //�ѹ�ʱ
          begin
            if (nTask.FDateLast = 0) and TimeValid(nil, nNow, nTask.FDate) then
            begin
              nID := nTask.FID;
              Result := nTask.FDate;
              Break;
            end; //δ����δ��ʱ

            nTask.FDateLast := cDate_Invalid;
            gEqualizer.ForceChange();
            //��ʱ��¼
          end
          else
          begin
            nTask.FDateNext := nTask.FDate;
          end;
        etMonth:
          if nTask.FDateFix then //ÿ���M��d��h��m��s��
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM1, nD1, nH1, nMM1, nSS1, 0);
            //���괥��ʱ��

            if not TimeValid(nTask, nNow) then //ʱ����Ч
              nTask.FDateNext := IncYear(nTask.FDateNext);
            //��һ���
          end
          else
          begin //ÿ��M���µ�d��h��m��s��
            if nTask.FDateBase >= nNow then
              Continue;
            //δ��ʼ

            nTask.FDateNext := EncodeDate(nY, nM, nD1) +
              EncodeTime(nH1, nMM1, nSS1, 0);
            //��ǰ�·ݵ�d��h��m��s��

            nInt := MonthsBetween(Month1Day(nTask.FDateNext), Month1Day(nTask.FDateBase));
            //��ʼ�൱ǰ���·�

            if nM1 > 0 then //ÿ��nM1����
            begin
              nVal := nInt mod nM1; //���������༸����
              if nVal > 0 then
                nTask.FDateNext := IncMonth(nTask.FDateNext, nM1 - nVal);
              //���·ݲ��
            end;

            if not TimeValid(nTask, nNow) then //ʱ����Ч
              nTask.FDateNext := IncMonth(nTask.FDateNext, nM1);
            //����d���ѳ�ʱ,������M����d��
          end;
        etday:
          if nTask.FDateFix then //ÿ�µ�d��h��m��s��
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD1, nH1, nMM1, nSS1, 0);
            //���걾�´���ʱ��

            if not TimeValid(nTask, nNow) then //ʱ����Ч
              nTask.FDateNext := IncMonth(nTask.FDateNext);
            //��һ�·�
          end
          else
          begin //ÿ��d���h��m��s��
            if nTask.FDateBase >= nNow then
              Continue;
            //δ��ʼ

            nTask.FDateNext := DateOf(nNow) + EncodeTime(nH1, nMM1, nSS1, 0);
            //����h��m��s��

            nInt := DaysBetween(DateOf(nTask.FDateNext), DateOf(nTask.FDateBase));
            //��ʼ�൱ǰ������

            if nD1 > 0 then //ÿ��nD1��
            begin
              nVal := nInt mod nD1; //���������༸��
              if nVal > 0 then
                nTask.FDateNext := IncDay(nTask.FDateNext, nD1 - nVal);
              //���������
            end;

            if not TimeValid(nTask, nNow) then //ʱ����Ч
              nTask.FDateNext := IncDay(nTask.FDateNext, nD1);
            //�����ѳ�ʱ,������d��
          end;
        ethour:
          if nTask.FDateFix then //ÿ���h��m��s��
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD, nH1, nMM1, nSS1, 0);
            //���촥��ʱ��

            if not TimeValid(nTask, nNow) then //ʱ����Ч
              nTask.FDateNext := IncDay(nTask.FDateNext);
            //����
          end
          else
          begin //ÿ��hСʱm��s��
            nVal := nH1 * 3600 + nMM1 * 60 + nSS1;
            //�������

            if nVal < 1 then //���0��Ч
            begin
              nTask.FDateLast := cDate_Invalid;
              gEqualizer.ForceChange();
              Continue;
            end;

            nTask.FDateNext := 0;
            nInt := SecondDiff(nNow, nTask.FDateBase);
            //��ʼ�൱ǰ������

            if nInt < nVal then
            begin
              nTask.FDateNext := IncSecond(nTask.FDateBase, nVal);
              //����һ������
            end
            else
            begin
              nInt := nInt mod nVal; //���������༸��
              if nInt < 1 then
                nTask.FDateNext := nNow
              else
                nTask.FDateNext := IncSecond(nNow, nVal - nInt); //���������
            end;
          end;
        etmin:
          if nTask.FDateFix then //ÿСʱ��m��s��
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD, nH, nMM1, nSS1, 0);
            //��ǰСʱ��

            if not TimeValid(nTask, nNow) then //ʱ����Ч
              nTask.FDateNext := IncHour(nTask.FDateNext);
            //��һСʱ
          end
          else
          begin //ÿ��m��s��
            nVal := nMM1 * 60 + nSS1;
            //�������

            if nVal < 1 then //���0��Ч
            begin
              nTask.FDateLast := cDate_Invalid;
              gEqualizer.ForceChange();
              Continue;
            end;

            nTask.FDateNext := 0;
            nInt := SecondDiff(nNow, nTask.FDateBase);
            //��ʼ�൱ǰ������

            if nInt < nVal then
            begin
              nTask.FDateNext := IncSecond(nTask.FDateBase, nVal);
              //����һ������
            end
            else
            begin
              nInt := nInt mod nVal; //���������༸��
              if nInt < 1 then
                nTask.FDateNext := nNow
              else
                nTask.FDateNext := IncSecond(nNow, nVal - nInt); //���������
            end;
          end;
        etSecond:
          if nTask.FDateFix then //ÿ���ӵĵ�s��
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD, nH, nMM, nSS1, 0);
            //��ǰ������
          end
          else
          begin //ÿ��s��
            if nSS1 < 1 then //���0��Ч
            begin
              nTask.FDateLast := cDate_Invalid;
              gEqualizer.ForceChange();
              Continue;
            end;

            nTask.FDateNext := 0;
            nInt := SecondDiff(nNow, nTask.FDateBase);
            //��ʼ�൱ǰ������

            if nInt < nSS1 then
            begin
              nTask.FDateNext := IncSecond(nTask.FDateBase, nSS1);
              //����һ������
            end
            else
            begin
              nVal := nInt mod nSS1; //���������༸��
              if nVal < 1 then
                nTask.FDateNext := nNow
              else
                nTask.FDateNext := IncSecond(nNow, nSS1 - nVal); //���������
            end;
          end;
      end;

      if nTask.FDateNext > 0 then
      begin
        nTask.FDateNext := IncMilliSecond(nTask.FDateNext,
            MilliSecondOf(nTask.FDateNext) * (-1));
        //ɾ������

        {$IFDEF DEBUG}
        WriteLog(TStringHelper.Enum2Str<TTaskType>(nTask.FType) + ': ' +
            TDateTimeHelper.DateTime2Str(nTask.FDateNext));
        {$ENDIF}
      end;
    end;

    //--------------------------------------------------------------------------
    if nID = '' then
    begin
      for nIdx := gEqualizer.Tasks.Count - 1 downto 0 do
      begin
        nTask := gEqualizer.Tasks[nIdx];
        if (not nTask.FEnabled) or
          (nTask.FDateLast = cDate_Invalid) or (nTask.FDateNext < 1) then
          Continue;
        //�ƻ���Ч,��ִ��ʱ��

        if (nTask.FDateNext < Result) and //���ӽ���ǰʱ��
          (nTask.FDateNext <> nTask.FDateLast) then //�üƻ�ʱ��ûִ�й�
        begin
          nID := nTask.FID;
          Result := nTask.FDateNext;
          Break;
        end;
      end;
    end;
  finally
    gEqualizer.SyncLock.Leave;
  end;

  if nID <> '' then
    with TDateTimeHelper do
      WriteLog(Format('���żƻ�: %s ʱ��: %s', [nID, DateTime2Str(Result)]));
  //xxxxx
end;

//Date: 2025-01-06
//Parm: ��ǰʱ��
//Desc: ���żƻ�����
procedure TVoiceManager.DoTaskVoice(const nNow: TDateTime);
var
  nIdx: Integer;
  nList: TStrings;
  nTask: TEqualizerTask;
begin
  nList := nil;
  try
    if FTaskID = '' then
      Exit;
    //û�мƻ�

    nTask := gEqualizer.FindTask(FTaskID);
    if not nTask.FEnabled then
      Exit;
    //��Ч�ƻ�

    if (nTask.FType = etYear) and (nTask.FDate <= nNow) then
      gEqualizer.UpdateTask(@nTask, 2)
      //��ʱ�Ĺ̶�ʱ��
    else
      gEqualizer.UpdateTask(@nTask, 1);
      //����nTask.FDateLast

    if Pos('=', nTask.FText) > 1 then //��������
    begin
      nList := gMG.FObjectPool.Lock(TStrings) as TStrings;
      nList.Text := nTask.FText;

      for nIdx := nList.Count - 1 downto 0 do
      begin
        if (Trim(nList.Names[nIdx]) = '') or
          (Trim(nList.ValueFromIndex[nIdx]) = '') then
          nList.Delete(nIdx);
        //��Ч����
      end;
    end;

    PlayVoice(nTask.FText, nTask.FModal, Assigned(nList) and (nList.Count > 0),
        False);
    //��������
  finally
    gMG.FObjectPool.Release(nList);
    //xxxxx

    FTaskNext := NextTaskTime(nNow, FTaskID);
    //�´μƻ�ʱ���ͼƻ���ʶ
  end;
end;

//------------------------------------------------------------------------------
//Date: 2024-12-30
//Parm: ����;ģ��;�����;�ѱ���
//Desc: ����nData�ı�
procedure TVoiceManager.PlayVoice(nMsg, nModal: string; nMulti, nEncode: Boolean);
var
  nIdx: Integer;
  nList: TStrings;
  nData: PVoiceData;
  nMData: TEqualizerModal;
begin
  if FWorker.FCallTimes < 1 then
  begin
    WriteLog('PlayVoice: ����δ����.');
    Exit;
  end;

  nMData := gEqualizer.FindModal(nModal);
  if (not nMData.FEnabled) and (nModal <> '') then
    nMData := gEqualizer.FindModal('');
  //default modal

  if not nMData.FEnabled then
  begin
    WriteLog('PlayVoice: δ����Ĭ������ģ��.');
    Exit;
  end;

  nList := nil;
  FSyncLock.Enter;
  try
    if nMulti then
    begin
      nList := gMG.FObjectPool.Lock(TStrings) as TStrings;
      nList.Text := nMsg;
      nMsg := nMData.FDemoText;

      for nIdx := 0 to nList.Count - 1 do
      begin
        if nEncode then
          nMsg := StringReplace(nMsg, nList.KeyNames[nIdx],
              TEncodeHelper.DecodeBase64(nList.ValueFromIndex[nIdx]),
              [rfReplaceAll, rfIgnoreCase])
        else
          nMsg := StringReplace(nMsg, nList.KeyNames[nIdx],
              nList.ValueFromIndex[nIdx], [rfReplaceAll, rfIgnoreCase]);
        //�滻ģ���еı���
      end;
    end
    else
    begin
      if nEncode then
        nMsg := TEncodeHelper.DecodeBase64(nMsg);
      //xxxxx
    end;

    //--------------------------------------------------------------------------
    nData := nil;
    for nIdx := 0 to FDataList.Count - 1 do
      if not PVoiceData(FDataList[nIdx]).FUsed then
      begin
        nData := FDataList[nIdx];
        Break;
      end;

    if not Assigned(nData) then
    begin
      New(nData);
      FDataList.Add(nData);
    end;

    with nData^ do
    begin
      FUsed := True;
      FLock := False;
      FLast := 0;
      FRunTime := 0;

      FChan := nil;
      FData := nMsg;
      FModal := nMData;
    end;
  finally
    FSyncLock.Leave;
    gMG.FObjectPool.Release(nList);
  end;

  gMG.FThreadPool.WorkerWakeup(Self);
  //����ִ��
end;

//Date: 2024-12-24
//Parm: ͨ��;ģ��;�ı�
//Desc: ��nChanͨ��ʹ��nModalģ�岥��nText�ı�
function TVoiceManager.PlayVoice(nChan: PEqualizerChan; nModal: PEqualizerModal;
  nText: string): Boolean;
var
  nStr: string;
  nClient: TIdHTTP;
  nBuf: TMemoryStream;
begin
  Result := False;
  if not Assigned(nChan) then
  begin
    WriteLog('PlayVoice: ��Ч������ͨ��.');
    Exit;
  end;

  if not Assigned(nModal) then
  begin
    WriteLog('PlayVoice: ��Ч������ģ��.');
    Exit;
  end;

  nText := Trim(nText);
  if nText = '' then
  begin
    nText := nModal.FDemoText;
    //��ʾ�ı�

    if nText = '' then
    begin
      WriteLog('PlayVoice: ��Ч���ı�����.');
      Exit;
    end;
  end;

  WriteLog(nText);
  //logged

  nStr := FRemoteURL + 'forward?text=' + nText;
  if nModal.FSpeed > 0 then
    nStr := nStr + '&speed=' + IntToStr(nModal.FSpeed);
  //xxxxx

  if nModal.FVolume > 0 then
    nStr := nStr + '&volume=' + IntToStr(nModal.FVolume);
  //xxxxx

  if nModal.FPitch > 0 then
    nStr := nStr + '&pitch=' + IntToStr(nModal.FPitch);
  //xxxxx

  if nModal.FVoice <> '' then
    nStr := nStr + '&voice=' + nModal.FVoice;
  //xxxxx

  nStr := TIdURI.URLEncode(nStr);
  //request url

  //----------------------------------------------------------------------------
  nBuf := nil;
  nClient := nil; //init object
  try
    nBuf := TMemoryStream.Create;
    nClient := gMG.FObjectPool.Lock(TIdHTTP) as TIdHTTP;
    nClient.ConnectTimeout := cTimeoutConn;
    try
      nClient.Get(nStr, nBuf);
      //remote tts

      if nBuf.Size > 0 then
      try
        gEqualizer.SyncLock.Enter;
        gEqualizer.FreeChan(nChan.FID, True);
        //1.���������

        nChan.FHandle := BASS_StreamCreateFile(True, nBuf.Memory, 0, nBuf.Size,
            BASS_SAMPLE_FX{$IFDEF UNICODE} or BASS_UNICODE {$ENDIF});
        //2.����������
        if not gEqualizer.ChanValid(nChan) then
          raise Exception.Create('ͨ���޷�����������.');
        //xxxxx

        if not gEqualizer.InitEqualizer(nChan.FID) then
          raise Exception.Create('ͨ���޷����þ�����.');
        //xxxxx
        gEqualizer.SetEqualizer(nChan.FID, 0, cEqualizer_All);
        //3.���þ���

        nChan.FMemory := nBuf;
        nBuf := nil;
        //4.�ƽ��ڴ����
      finally
        gEqualizer.SyncLock.Leave;
      end;
    except
      on nErr: Exception do
      begin
        WriteLog('PlayVoice: ' + nErr.Message);
        Exit;
      end;
    end;
  finally
    nBuf.Free;
    gMG.FObjectPool.Release(nClient);
  end;

  gEqualizer.PlayChan(nChan.FID);
  //5.����
  Result := True;
end;

initialization
  gVoiceManager := TVoiceManager.Create;

finalization
  FreeAndNil(gVoiceManager);

end.

