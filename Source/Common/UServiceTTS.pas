{*******************************************************************************
  作者: dmzn@163.com 2024-12-23
  描述: tts服务
*******************************************************************************}
unit UServiceTTS;

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, System.SyncObjs, bass,
  UEqualizer, UThreadPool;

type
  PVoiceItem = ^TVoiceItem;

  TVoiceItem = record
    FID: string;     //角色标识
    FName: string;   //角色名称
    FGender: string; //角色性别
    FLocale: string; //区域标识
    FDesc: string;   //语种描述
  end;

  PVoiceData = ^TVoiceData;

  TVoiceData = record
    FUsed: Boolean;                //使用标记
    FLock: Boolean;                //锁定标记
    FLast: Cardinal;               //上次执行
    FRunTime: Integer;             //执行次数
    FChan: PEqualizerChan;         //通道
    FModal: TEqualizerModal;       //模板
    FData: string;                 //内容
  end;

  TVoiceManager = class(TObject)
  private
    FVoices: TList;
    {*角色列表*}
    FDataList: TList;
    {*语音*}
    FRemoteURL: string;
    {*服务地址*}
    FStrickNext: TDateTime;
    {*整点报时*}
    FTaskNext: TDateTime;
    {*播放计划*}
    FWorker: TThreadWorkerConfig;
    {*工作线程*}
    FSyncLock: TCriticalSection;
    {*同步锁定*}
  protected
    procedure ClearVoice(const nFree: Boolean);
    procedure ClearData(const nFree: Boolean);
    {*释放资源*}
    procedure SetRemoteURL(nURL: string);
    {*设置参数*}
    function TimeValid(const nDate, nNow: TDateTime): Boolean;
    function NextTaskTime(const nNow: TDateTime; var nID: string): TDateTime;
    function NextStrickTime(const nNow: TDateTime; nFromNow: Boolean): TDateTime;
    procedure DoStrickHour(const nNow: TDateTime);
    procedure DoTaskVoice(const nNow: TDateTime);
    procedure DoPlay(const nCfg: PThreadWorkerConfig; const nThread: TThread);
    {*线程播放*}
  public
    constructor Create;
    destructor Destroy; override;
    {*创建释放*}
    function LoadVoice(): Boolean;
    {*角色相关*}
    function PlayVoice(nChan: PEqualizerChan; nModal: PEqualizerModal; nText:
      string = ''): Boolean; overload;
    procedure PlayVoice(nMsg, nModal: string; nMulti: Boolean; nEncode: Boolean
      = True); overload;
    {*播放语音*}
    procedure StartService();
    procedure StopService();
    {*启停服务*}
    procedure ResetNextTime();
    {*重置计时*}
    property Voices: TList read FVoices;
    property SyncLock: TCriticalSection read FSyncLock;
    property RemoteURL: string read FRemoteURL write SetRemoteURL;
    {*属性相关*}
  end;

var
  gVoiceManager: TVoiceManager = nil;
  //全局使用

implementation

uses
  System.DateUtils, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdHTTP, IdURI, superobject, ULibFun, UManagerGroup;

const
  {*超时设置*}
  cTimeoutConn = 5 * 1000;
  cTimeoutRead = 3 * 1000;

var
  {*时间标签*}
  gDateInvalid: TDateTime;

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TVoiceManager, 'TTS-语音合成', nEvent);
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
    FParentDesc := '语音合成调度';
    FCallTimes := 0; //暂停
    FCallInterval := 500;
    FOnWork.WorkEvent := DoPlay;
  end;

  gMG.FThreadPool.WorkerAdd(@FWorker);
  //添加线程作业
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
//Parm: 是否释放列表
//Desc: 清理角色列表
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
//Parm: 是否释放
//Desc: 清理语音数据
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
//Parm: tts服务地址
//Desc: 设置服务地址为nRUL
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
  nStr: string;
  nNow: TDateTime;
begin
  nNow := Now();
  FStrickNext := NextStrickTime(nNow, True);
  //报时初始化
  FTaskNext := NextTaskTime(nNow, nStr);
  //计划播放

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
//Desc: 载入角色列表
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
        raise Exception.Create('未找到角色清单.');
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
//Date: 2025-01-07
//Desc: 重置计时
procedure TVoiceManager.ResetNextTime;
begin
  FTaskNext := 0;
  FStrickNext := 0;
end;

//Date: 2024-12-31
//Parm: 配置;线程本体
//Desc: 在线程中执行合成任务
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
  //整点报时

  if nNow >= FTaskNext then
    DoTaskVoice(nNow);
  //播放计划

  nData := nil;
  SyncLock.Enter;
  try
    for nIdx := FDataList.Count - 1 downto 0 do
    begin
      nTmp := FDataList[nIdx];
      if (not nTmp.FUsed) or nTmp.FLock then //空闲或处理中
        Continue;
      //invalid

      if nTmp.FRunTime > 0 then //已运行
      begin
        if ((nTmp.FModal.FLoopTime < 1) or //不循环
          (nTmp.FModal.FLoopTime <= nTmp.FRunTime)) then //已循环结束
        begin
          if gEqualizer.ChanIdle(nTmp.FChan, False) then  //通道空闲
          begin
            nTmp.FUsed := False;
            gEqualizer.FreeChan(nTmp.FChan.FID);
          end;

          Continue;
        end;

        if not gEqualizer.ChanIdle(nTmp.FChan, False) then
          Continue;
        //上次播放未结束
      end;

      if (nTmp.FModal.FLoopTime > 0) and
        (TDateTimeHelper.GetTickCountDiff(nTmp.FLast) < nTmp.FModal.FLoopInterval) then
        Continue;
      //循环时间未到

      nData := nTmp;
      nData.FLock := True; //选中
      Inc(nData.FRunTime);

      Break;
      //开始处理
    end;
  finally
    SyncLock.Leave;
  end;

  if Assigned(nData) then
  try
    if nData.FRunTime > 1 then //再次运行
    begin
      if gEqualizer.ChanValid(nData.FChan) then
        gEqualizer.PlayChan(nData.FChan.FID)
      else
        PlayVoice(nData.FChan, @nData.FModal, nData.FData);
    end
    else
    begin
      nData.FChan := gEqualizer.NewChan();
      //首次运行
      PlayVoice(nData.FChan, @nData.FModal, nData.FData);
    end;

    nData.FLast := TDateTimeHelper.GetTickCount();
    //运行时间戳
  finally
    nData.FLock := False;
  end;
end;

//Date: 2024-12-31
//Parm: 当前时间
//Desc: 执行整点报时
procedure TVoiceManager.DoStrickHour(const nNow: TDateTime);
var
  nMsg: string;
  nH, nM, nS, nMS: Word;
  nModal: TEqualizerModal;
begin
  FStrickNext := NextStrickTime(nNow, False);
  nMsg := '';
  DecodeTime(nNow, nH, nM, nS, nMS);

  if nM = 0 then //整点
  begin
    nModal := gEqualizer.FindModal('');
    if not (nModal.FEnabled and nModal.FOnHour) then
      Exit;
    //模板有效,且启用整点报时

    nMsg := nModal.FOnHourText;
    if nMsg = '' then
    begin
      WriteLog('未设置整点报时内容.');
      Exit;
    end;
  end;

  if nM = 30 then //半点
  begin
    nModal := gEqualizer.FindModal('');
    if not (nModal.FEnabled and nModal.FOnHalfHour) then
      Exit;
    //模板有效,且启用整点报时

    nMsg := nModal.FOnHalfText;
    if nMsg = '' then
    begin
      WriteLog('未设置半点报时内容.');
      Exit;
    end;
  end;

  if nMsg <> '' then
  begin
    nMsg := StringReplace(nMsg, '$hr', nH.ToString, [rfReplaceAll, rfIgnoreCase]);
    //替换小时变量
    PlayVoice(gEqualizer.FirstChan, @nModal, nMsg);
  end;
end;

//Date: 2025-01-02
//Parm: 当前时间;是否包含当前时间
//Desc: 依据当前时间,计算下次报时时间
function TVoiceManager.NextStrickTime(const nNow: TDateTime; nFromNow: Boolean):
  TDateTime;
var
  nH, nM, nS, nMS: Word;
begin
  DecodeTime(nNow, nH, nM, nS, nMS);
  if nFromNow and ((nM = 0) or (nM = 30)) then
  begin
    Result := DateOf(nNow) + EncodeTime(nH, nM, 0, 0);
    //当前时间:整点,半点
  end
  else if nM < 30 then
  begin
    Result := DateOf(nNow) + EncodeTime(nH, 30, 0, 0);
    //下次为半点
  end
  else
  begin
    Result := IncMinute(nNow, 30); //可能跨天
    DecodeTime(Result, nH, nM, nS, nMS);
    Result := DateOf(Result) + EncodeTime(nH, 0, 0, 0); //整点
  end;

  WriteLog('下次报时 ' + TDateTimeHelper.Time2Str(Result));
end;

//------------------------------------------------------------------------------
//Date: 2025-01-08
//Parm: 待检查时间;当前时间
//Desc: 检查nDate是否还有效(未过时,未超时)
function TVoiceManager.TimeValid(const nDate, nNow: TDateTime): Boolean;
begin
  Result := nDate >= nNow;
  //未过时

  if not Result then
    Result := (DateTimeToMilliseconds(nNow) - DateTimeToMilliseconds(nDate))
      div (MSecsPerSec * SecsPerMin) < 1;
   //超过1分钟视为超时
end;

//Date: 2025-01-06
//Parm: 当前时间;任务标识
//Desc: 依据当前时间,计算下次计划播放时间
function TVoiceManager.NextTaskTime(const nNow: TDateTime; var nID: string):
  TDateTime;
var
  nIdx: Integer;
  nTask: PEqualizerTask;
  nY, nM, nD, nH, nMM, nSS, nMS: Word;
  nY1, nM1, nD1, nH1, nMM1, nSS1, nMS1: Word;
begin
  Result := IncSecond(nNow, 10);
  //默认10秒后,控制扫描速度
  nID := '';
  nY := 0;

  gEqualizer.SyncLock.Enter;
  try
    for nIdx := gEqualizer.Tasks.Count - 1 downto 0 do
    begin
      nTask := gEqualizer.Tasks[nIdx];
      if (not nTask.FEnabled) or (nTask.FDateLast = gDateInvalid) then
        Continue;
      //计划已无效

      if (nTask.FDateNext > 0) and TimeValid(nTask.FDateNext, nNow) then
        Continue;
      //未超时,无需重新计算下次播放时间

      if nY = 0 then //拆分当前时间
      begin
        DecodeDate(nNow, nY, nM, nD);
        DecodeTime(nNow, nH, nMM, nSS, nMS);
      end;

      DecodeDate(nTask.FDate, nY1, nM1, nD1);
      DecodeTime(nTask.FDate, nH1, nMM1, nSS1, nMS1);
      //拆解设定时间

      case nTask.FType of
        etYear: //定时
          if nTask.FDate < nNow then //已过时
          begin
            if (nTask.FDateLast = 0) and TimeValid(nTask.FDate, nNow) then //未播放未超时
            begin
              nID := nTask.FID;
              Result := nTask.FDate;
            end;

            nTask.FDateLast := gDateInvalid;
            gEqualizer.ForceChange();
            //过时标记,并保存

            if nID <> '' then
              Break;
            //即刻播放
          end
          else
          begin
            nTask.FDateNext := nTask.FDate;
          end;
        etMonth:
          if nTask.FDateFix then //每年的M月d日h点m分s秒
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM1, nD1, nH1, nMM1, nSS1, 0);
            //今年触发时间

            if not TimeValid(nTask.FDateNext, nNow) then
              nTask.FDateNext := IncYear(nTask.FDateNext);
            //下一年份
          end
          else
          begin

          end;
        etday:
          if nTask.FDateFix then //每月的d日h点m分s秒
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD1, nH1, nMM1, nSS1, 0);
            //今年本月触发时间

            if not TimeValid(nTask.FDateNext, nNow) then
              nTask.FDateNext := IncMonth(nTask.FDateNext);
            //下一月份
          end
          else
          begin

          end;
        ethour:
          if nTask.FDateFix then //每天的h点m分s秒
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD, nH1, nMM1, nSS1, 0);
            //当天触发时间

            if not TimeValid(nTask.FDateNext, nNow) then
              nTask.FDateNext := IncDay(nTask.FDateNext);
            //明天
          end
          else
          begin

          end;
        etmin:
          if nTask.FDateFix then //每小时的m分s秒
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD, nH, nMM1, nSS1, 0);
            //当前时辰内触发时间

            if not TimeValid(nTask.FDateNext, nNow) then
              nTask.FDateNext := IncHour(nTask.FDateNext);
            //下一小时
          end
          else
          begin

          end;
        etSecond:
          if nTask.FDateFix then //每分钟的第s秒
          begin
            nTask.FDateNext := EncodeDateTime(nY, nM, nD, nH, nMM, nSS1, 0);
            //今年本月触发时间
          end
          else
          begin

          end;
      end;
    end;

    //--------------------------------------------------------------------------
    if nID = '' then
    begin
      for nIdx := gEqualizer.Tasks.Count - 1 downto 0 do
      begin
        nTask := gEqualizer.Tasks[nIdx];
        if (not nTask.FEnabled) or (nTask.FDateLast = gDateInvalid) then
          Continue;
        //计划已无效

        if (nTask.FDateNext > 0) and (nTask.FDateNext < Result) and //更接近当前时间
          (nTask.FDateNext <> nTask.FDateLast) then //该计划没执行过
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
    WriteLog(Format('播放计划: %s 时间: %s', [nID, TDateTimeHelper.DateTime2Str(Result)]));
  //xxxxx
end;

//Date: 2025-01-06
//Parm: 当前时间
//Desc: 播放计划语音
procedure TVoiceManager.DoTaskVoice(const nNow: TDateTime);
var
  nID: string;
  nTask: TEqualizerTask;
begin
  FTaskNext := NextTaskTime(nNow, nID);
  //计划时间点和本次计划标识

  if nID = '' then
    Exit;
  //没有计划

  nTask := gEqualizer.FindTask(nID);
  if not nTask.FEnabled then
    Exit;
  //无效计划

  PlayVoice(nTask.FText, nTask.FModal, False, False);
  //播放语音

  gEqualizer.UpdateTask(@nTask, 1);
  //更新nTask.FDateLast
end;

//------------------------------------------------------------------------------
//Date: 2024-12-30
//Parm: 内容;模板;多参数;已编码
//Desc: 播放nData文本
procedure TVoiceManager.PlayVoice(nMsg, nModal: string; nMulti, nEncode: Boolean);
var
  nIdx: Integer;
  nList: TStrings;
  nData: PVoiceData;
  nMData: TEqualizerModal;
begin
  if FWorker.FCallTimes < 1 then
  begin
    WriteLog('PlayVoice: 服务未启动.');
    Exit;
  end;

  nMData := gEqualizer.FindModal(nModal);
  if (not nMData.FEnabled) and (nModal <> '') then
    nMData := gEqualizer.FindModal('');
  //default modal

  if not nMData.FEnabled then
  begin
    WriteLog('PlayVoice: 未设置默认语音模板.');
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
        //替换模板中的变量
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
  //立即执行
end;

//Date: 2024-12-24
//Parm: 通道;模板;文本
//Desc: 在nChan通道使用nModal模板播放nText文本
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
    WriteLog('PlayVoice: 无效的语音通道.');
    Exit;
  end;

  if not Assigned(nModal) then
  begin
    WriteLog('PlayVoice: 无效的语音模板.');
    Exit;
  end;

  nText := Trim(nText);
  if nText = '' then
  begin
    nText := nModal.FDemoText;
    //演示文本

    if nText = '' then
    begin
      WriteLog('PlayVoice: 无效的文本内容.');
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
        //1.清理旧数据

        nChan.FHandle := BASS_StreamCreateFile(True, nBuf.Memory, 0, nBuf.Size,
            BASS_SAMPLE_FX{$IFDEF UNICODE} or BASS_UNICODE {$ENDIF});
        //2.加载新数据
        if not gEqualizer.ChanValid(nChan) then
          raise Exception.Create('通道无法加载语音流.');
        //xxxxx

        if not gEqualizer.InitEqualizer(nChan.FID) then
          raise Exception.Create('通道无法设置均衡器.');
        //xxxxx
        gEqualizer.SetEqualizer(nChan.FID, 0, cEqualizer_All);
        //3.设置均衡

        nChan.FMemory := nBuf;
        nBuf := nil;
        //4.移交内存对象
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
  //5.播放
  Result := True;
end;

initialization
  gVoiceManager := TVoiceManager.Create;
  gDateInvalid := EncodeDate(2001, 2, 3);

finalization
  FreeAndNil(gVoiceManager);

end.

