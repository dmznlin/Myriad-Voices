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
    FStrickHour: Integer;
    FStrickHourHalf: Integer;
    FStrickChan: DWORD;
    {*整点报时*}
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
    procedure DoStruckHour();
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
    procedure PlayVoice(nMsg, nModal: string; nMulti: Boolean); overload;
    {*播放语音*}
    procedure StartService();
    procedure StopService();
    {*启停服务*}
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
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, IdURI,
  superobject, ULibFun, UManagerGroup;

const
  {*超时设置*}
  cTimeoutConn = 5 * 1000;
  cTimeoutRead = 3 * 1000;

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

  FStrickHour := -1;
  FStrickHourHalf := -1;
  FStrickChan := cChan_Invlid;
  //init variant

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
begin
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

//Date: 2024-12-30
//Parm: 内容;模板;多参数
//Desc: 播放nData文本
procedure TVoiceManager.PlayVoice(nMsg, nModal: string; nMulti: Boolean);
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
        nMsg := StringReplace(nMsg, nList.KeyNames[nIdx],
            TEncodeHelper.DecodeBase64(nList.ValueFromIndex[nIdx]),
            [rfReplaceAll, rfIgnoreCase]);
        //替换模板中的变量
      end;
    end
    else
    begin
      nMsg := TEncodeHelper.DecodeBase64(nMsg);
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

      FChan := 0;
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

//Date: 2024-12-31
//Parm: 配置;线程本体
//Desc: 在线程中执行合成任务
procedure TVoiceManager.DoPlay(const nCfg: PThreadWorkerConfig; const nThread:
  TThread);
var
  nIdx: Integer;
  nData, nTmp: PVoiceData;
begin
  DoStruckHour();
  //整点报时
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
          if gEqualizer.ChanIdle(nTmp.FChan) then  //通道空闲
          begin
            nTmp.FUsed := False;
            gEqualizer.FreeChan(nTmp.FChan.FID);
          end;

          Continue;
        end;

        if not gEqualizer.ChanIdle(nTmp.FChan) then
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
      nData.FChan := gEqualizer.NewChan('');
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
//Desc: 执行整点报时
procedure TVoiceManager.DoStruckHour;
var
  nMsg: string;
  nH, nM, nS, nMS: Word;
  nModal: TEqualizerModal;
begin
  nMsg := '';
  DecodeTime(Time(), nH, nM, nS, nMS);

  if (nM = 0) and (nH <> FStrickHour) then //整点
  begin
    FStrickHour := nH;
    //set tag

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

  if (nM = 30) and (nH <> FStrickHourHalf) then //半点
  begin
    FStrickHourHalf := nH;
    //set tag

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
    PlayVoice(gEqualizer.FindChan(gEqualizer.FirstChan), @nModal, nMsg);
  end;
end;

//Date: 2024-12-24
//Parm: 通道;模板;文本
//Desc: 在nChan通道使用nModal模板播放nText文本
function TVoiceManager.PlayVoice(nChan: PEqualizerChan; nModal: PEqualizerModal;
  nText: string): Boolean;
var
  nStr: string;
  nIdx: Integer;
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

  nBuf := nil;
  nClient := nil; //init object
  try
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

    //------------------------------------------------------------------------------
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

    nClient := gMG.FObjectPool.Lock(TIdHTTP) as TIdHTTP;
    nClient.ConnectTimeout := cTimeoutConn;
    try
      nBuf := TMemoryStream.Create;
      nClient.Get(nStr, nBuf);

      if nBuf.Size > 0 then
      try
        gEqualizer.SyncLock.Enter;
        gEqualizer.FreeChan(nChan.FID, True);
        //1.清理旧数据

        nChan.FHandle := BASS_StreamCreateFile(True, nBuf.Memory, 0, nBuf.Size,
            BASS_SAMPLE_FX{$IFDEF UNICODE} or BASS_UNICODE {$ENDIF});
        //2.加载新数据
        if nChan.FHandle = cChan_Invlid then
          raise Exception.Create('通道无法加载语音流.');
        //xxxxx

        if not gEqualizer.InitEqualizer(nChan.FID) then
          Exit;
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

finalization
  FreeAndNil(gVoiceManager);

end.

