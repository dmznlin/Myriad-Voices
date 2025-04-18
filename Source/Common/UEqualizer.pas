{*******************************************************************************
  作者: dmzn@163.com 2024-12-20
  描述: 通道和均衡
*******************************************************************************}
unit UEqualizer;

interface

uses
  Winapi.Windows, System.Classes, System.SyncObjs, System.SysUtils, superobject,
  System.DateUtils, bass, System.IOUtils, ULibFun, Vcl.Forms, UManagerGroup;

const
  {*均衡标识*}
  cEqualizer_All = 27;
  cEqualizer_Rever = 100;
  cEqualizer_125 = 125;
  cEqualizer_1K = 1000;
  cEqualizer_8K = 8000;

  {*常量定义*}
  cChan_Invlid = 0;
  cDate_Invalid = 36925; //2001-02-03

type
  PEqualizerChan = ^TEqualizerChan;

  //均衡
  TEqualizerChan = record
    FUsed: Boolean;                                //是否使用
    FID: Cardinal;                                 //通道标识
    FHandle: DWORD;                                //通道句柄

    FMemory: TMemoryStream;                        //语音数据
    FValue: array[1..4] of integer;                //均衡数据
    FInitVal: Boolean;                             //数据初始化
  end;

  PEqualizerModal = ^TEqualizerModal;

  //语音模板
  TEqualizerModal = record
    FEnabled: Boolean;                             //是否有效
    FDefault: Boolean;                             //是否默认
    FID: string;                                   //模板标识
    FLang: string;                                 //语种
    FVoice: string;                                //角色

    FLoopTime: Integer;                            //循环次数
    FLoopInterval: Cardinal;                       //循环间隔
    FOnHour: Boolean;                              //整点报时
    FOnHourText: string;                           //报时内容
    FOnHalfHour: Boolean;                          //半点报时
    FOnHalfText: string;                           //报时内容

    FSpeed: Integer;                               //语速
    FVolume: Integer;                              //音量
    FPitch: Integer;                               //音调
    FDemoText: string;                             //测试文本
  end;

  //均衡数据
  TEqualizerData = record
    F125: Integer;
    F1K: Integer;
    F8K: Integer;
    FRever: Integer;
  end;

  TTaskType = (etYear, etMonth, etDay, etHour, etMin, etSecond);
  //计划类型

  PEqualizerTask = ^TEqualizerTask;
  //语音播放计划

  TEqualizerTask = record
    FEnabled: Boolean;                             //是否有效
    FType: TTaskType;                              //计划类型
    FID: string;                                   //计划标识
    FModal: string;                                //语音模板
    FText: string;                                 //文本内容

    FDateFix: Boolean;                             //固定时间
    FDate: TDateTime;                              //播放时间
    FDateBase: TDateTime;                          //基准时间
    FBaseNow: Boolean;                             //基准为当前时间
    FBaseNowDelay: TDateTime;                      //当前时间延迟
    FDateLast: TDateTime;                          //上次播放
    FDateNext: TDateTime;                          //下次播放
  end;

  TEqualizer = class(TObject)
  private
    FChanged: Boolean;
    {*标识*}
    FChannels: TList;
    {*通道列表*}
    FChanFirst: PEqualizerChan;
    {*首个通道*}
    FParam: BASS_DX8_PARAMEQ;
    FRever: BASS_DX8_REVERB;
    {*均衡与混响*}
    FData: TEqualizerData;
    {*均衡数据*}
    FModals: TList;
    {*模板列表*}
    FTasks: TList;
    {*计划任务*}
    FSyncLock: TCriticalSection;
    {*同步锁定*}
  protected
    function GetChan(const id: Cardinal; nNoUsed: Boolean): Integer;
    function GetModal(const nID: string; const nDef: Boolean): PEqualizerModal;
    function GetTask(const nID: string): PEqualizerTask;
    {*检索数据*}
    procedure DisposeChan(const nIdx: Integer; nFree, nClear: Boolean);
    procedure ClearModals(const nFree: Boolean);
    procedure ClearTasks(const nFree: Boolean);
    {*释放资源*}
  public
    constructor Create;
    destructor Destroy; override;
    {*创建释放*}
    function LoadConfig(const nFile: string): Boolean;
    procedure SaveConfig(const nFile: string; nReset: Boolean = True);
    procedure ForceChange();
    {*读写配置*}
    class function InitBassLibrary: Boolean;
    class procedure FreeBassLibrary;
    {*bass库*}
    function NewChan(): PEqualizerChan;
    function FindChan(const id: Cardinal): PEqualizerChan;
    procedure PlayChan(const id: Cardinal);
    procedure FreeChan(const id: Cardinal; nClearOnly: Boolean = False);
    {*通道管理*}
    function ChanFile(chan: PEqualizerChan; nFile: string; id: Cardinal = 0):
      Boolean;
    function ChanValid(const chan: PEqualizerChan): Boolean;
    function ChanIdle(const chan: PEqualizerChan; nMustValid: Boolean): Boolean;
    {*通道狀態*}
    function InitEqualizer(const id: Cardinal): Boolean;
    {*初始化均衡*}
    procedure SetEqualizer(const id: Cardinal; nVal, nType: Integer);
    {*设置均衡值*}
    procedure AddModal(const nModal: PEqualizerModal);
    function FindModal(const nID: string): TEqualizerModal;
    procedure DeleteModal(const nID: string);
    {*语音模板*}
    procedure AddTask(const nTask: PEqualizerTask);
    function FindTask(const nID: string): TEqualizerTask;
    procedure DeleteTask(const nID: string);
    procedure UpdateTask(const nNew: PEqualizerTask; nAction: Byte);
    procedure UpdateDateBaseNow(const nTask: PEqualizerTask = nil);
    function TaskDate2Desc(const nTask: PEqualizerTask): string;
    {*播放计划*}
    property Tasks: TList read FTasks;
    property Modals: TList read FModals;
    property Channels: TList read FChannels;
    property FirstChan: PEqualizerChan read FChanFirst;
    property ConfigChanged: Boolean read FChanged;
    property EqualizerData: TEqualizerData read FData;
    property SyncLock: TCriticalSection read FSyncLock;
    {*属性相关*}
  end;

var
  gEqualizer: TEqualizer = nil;
  //全局使用

implementation

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TEqualizer, 'TTS-通道均衡', nEvent);
end;

//Date: 2024-12-20
//Desc: 初始化通道
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
  FTasks := TList.Create;
  FSyncLock := TCriticalSection.Create;

  FChanFirst := NewChan();
  //default chan
end;

//Date: 2024-12-20
//Desc: 释放通道
destructor TEqualizer.Destroy;
var
  nIdx: Integer;
begin
  for nIdx := FChannels.Count - 1 downto 0 do
    DisposeChan(nIdx, True, False);
  FChannels.Free;

  ClearModals(True);
  ClearTasks(True);
  FSyncLock.Free;
  inherited;
end;

//Date: 2024-12-18
//Desc: 初始化多媒体bass库
class function TEqualizer.InitBassLibrary: Boolean;
begin
  Result := False;
  // check the correct BASS was loaded
  if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
  begin
    WriteLog('多媒体库"bass"版本不匹配.');
    Exit;
  end;

	// Initialize audio - default device, 44100hz, stereo, 16 bits
  if not BASS_Init(-1, 44100, 0, Application.MainForm.Handle, nil) then
  begin
    WriteLog('初始化音频(base.audio)失败.');
    Exit;
  end;

  //BASS_SetConfig(BASS_CONFIG_BUFFER, 1000);
  Result := True;
end;

//Date: 2024-12-18
//Desc: 释放bass库
class procedure TEqualizer.FreeBassLibrary;
begin
	// Close BASS
  BASS_Free();
end;

//Date: 2024-12-20
//Parm: 标识;未使用的
//Desc: 检索chan通道的索引
function TEqualizer.GetChan(const id: Cardinal; nNoUsed: Boolean): Integer;
var
  nIdx: Integer;
  nChan: PEqualizerChan;
begin
  Result := -1;
  //init first

  for nIdx := 0 to FChannels.Count - 1 do
  begin
    nChan := FChannels[nIdx];
    if nNoUsed then
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
//Parm: 通道索引;释放内存;只清理
//Desc: 释放nIdx通道,或清理通道数据
procedure TEqualizer.DisposeChan(const nIdx: Integer; nFree, nClear: Boolean);
var
  nChan: PEqualizerChan;
begin
  nChan := FChannels[nIdx];
  if ChanValid(nChan) then
  begin
    BASS_MusicFree(nChan.FHandle);
    BASS_StreamFree(nChan.FHandle); //free resource
    nChan.FHandle := cChan_Invlid;
  end;

  if Assigned(nChan.FMemory) then
    FreeAndNil(nChan.FMemory);
  //xxxxx

  if nFree then
  begin
    Dispose(nChan);
  end
  else
  begin
    nChan.FInitVal := False;
    //reset flag

    if not nClear then //完全释放
    begin
      nChan.FUsed := False;
    end;
  end;
end;

//Date: 2024-12-23
//Parm: 释放对象
//Desc: 清空模板列表
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

//Date: 2025-01-05
//Parm: 释放对象
//Desc: 清空计划列表
procedure TEqualizer.ClearTasks(const nFree: Boolean);
var
  nIdx: Integer;
begin
  for nIdx := FTasks.Count - 1 downto 0 do
    Dispose(PEqualizerTask(FTasks[nIdx]));
  //xxxxx

  if nFree then
    FreeAndNil(FTasks)
  else
    FTasks.Clear;
end;

//Date: 2024-12-20
//Parm: 索引
//Desc: 检索通道对象
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
//Parm: 索引;只清理
//Desc: 释放chan通道,若nKeepLock只清理不释放
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
//Parm: wav文件
//Desc: 新建通道
function TEqualizer.NewChan(): PEqualizerChan;
var
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
end;

//Date: 2024-12-20
//Parm: 标识
//Desc: 初始化chan的均衡参数
function TEqualizer.InitEqualizer(const id: Cardinal): Boolean;
var
  nChan: PEqualizerChan;
begin
  Result := False;
  nChan := FindChan(id);
  if not ChanValid(nChan) then
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
      WriteLog('初始化均衡器失败: ' + nErr.Message);
    end;
  end;
end;

//Date: 2024-12-24
//Parm: 标识;值;类型
//Desc: 为id通道设置均衡值
procedure TEqualizer.SetEqualizer(const id: Cardinal; nVal, nType: Integer);
var
  nChan: PEqualizerChan;
  nAction: TProc<Integer, Integer>;
begin
  nChan := FindChan(id);
  if not (ChanValid(nChan) and nChan.FInitVal) then
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

  if nType = cEqualizer_All then //使用全局参数
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
//Parm: 标识
//Desc: 播放chan通道
procedure TEqualizer.PlayChan(const id: Cardinal);
var
  nChan: PEqualizerChan;
begin
  nChan := FindChan(id);
  if ChanIdle(nChan, True) then
    BASS_ChannelPlay(nChan.FHandle, False);
  //xxxxx
end;

//Date: 2024-12-31
//Parm: 通道;通道必须有效
//Desc: 通道是否空闲
function TEqualizer.ChanIdle(const chan: PEqualizerChan; nMustValid: Boolean):
  Boolean;
begin
  Result := not nMustValid;
  if ChanValid(chan) then
    Result := BASS_ChannelIsActive(chan.FHandle) = BASS_ACTIVE_STOPPED;
  //xxxxx
end;

//Date: 2025-01-01
//Parm: 通道
//Desc: 通道是否有效
function TEqualizer.ChanValid(const chan: PEqualizerChan): Boolean;
begin
  Result := Assigned(chan) and (chan.FHandle <> cChan_Invlid);
end;

//Date: 2025-01-01
//Parm: 通道;文件;标识
//Desc: 使用chan通道加载nFile文件
function TEqualizer.ChanFile(chan: PEqualizerChan; nFile: string; id: Cardinal):
  Boolean;
var
  nStr: string;
begin
  Result := False;
  nStr := ExtractFileName(nFile);

  if not FileExists(nFile) then
  begin
    WriteLog(Format('声音文件"%s"不存在.', [nStr]));
    Exit;
  end;

  if not Assigned(chan) then
  begin
    chan := FindChan(id);
    if not Assigned(chan) then
    begin
      WriteLog(Format('ChanFile: 通道[ %d ]不存在.', [id]));
      Exit;
    end;
  end;

  if ChanValid(chan) then
    FreeChan(chan.FID, True);
  //clear first

  chan.FHandle := BASS_StreamCreateFile(FALSE, PChar(nFile), 0, 0, BASS_SAMPLE_FX
      {$IFDEF UNICODE} or BASS_UNICODE {$ENDIF});
  //xxxxx

  Result := ChanValid(chan);
  if not Result then
  begin
    WriteLog(Format('加载声音文件"%s"失败.', [nStr]));
    Exit;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2025-01-06
//Desc: 强制保存数据
procedure TEqualizer.ForceChange;
begin
  FChanged := True;
end;

//Date: 2024-12-23
//Parm: 配置文件
//Desc: 载入配置文件
function TEqualizer.LoadConfig(const nFile: string): Boolean;
var
  nIdx: Integer;
  nModal: PEqualizerModal;
  nTask: PEqualizerTask;
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

    //--------------------------------------------------------------------------
    ClearTasks(False);
    //init task list

    nArray := nRoot.A['tasks'];
    if Assigned(nArray) then
    begin
      for nIdx := 0 to nArray.Length - 1 do
      begin
        New(nTask);
        FTasks.Add(nTask);

        with nTask^, TDateTimeHelper do
        begin
          FEnabled := True;
          FID := nArray[nIdx].S['id'];
          FType := TTaskType(nArray[nIdx].I['type']);
          FModal := nArray[nIdx].S['modal'];
          FText := nArray[nIdx].S['text'];

          FDate := Str2DateTime(nArray[nIdx].S['date']);
          FDateFix := nArray[nIdx].B['datefix'];
          FBaseNow := nArray[nIdx].B['basenow'];

          FBaseNowDelay := Str2DateTime(nArray[nIdx].S['basedelay']);
          FDateBase := Str2DateTime(nArray[nIdx].S['datebase']);
          //开始时间基准
          FDateLast := Str2DateTime(nArray[nIdx].S['datelast']);
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
//Parm: 配置文件;重置标识
//Desc: 保存配置到nFile中
procedure TEqualizer.SaveConfig(const nFile: string; nReset: Boolean);
var
  nIdx: Integer;
  nModal: PEqualizerModal;
  nTask: PEqualizerTask;
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

    //--------------------------------------------------------------------------
    nRoot.O['tasks'] := SO('[]');
    nArray := nRoot.A['tasks'];
    for nIdx := 0 to FTasks.Count - 1 do
    begin
      nTask := FTasks[nIdx];
      if not nTask.FEnabled then
        Continue;
      //invalid

      nNode := SO();
      with nTask^, TDateTimeHelper do
      begin
        nNode.S['id'] := FID;
        nNode.I['type'] := Ord(FType);
        nNode.S['modal'] := FModal;

        nNode.S['date'] := DateTime2Str(FDate);
        nNode.B['datefix'] := FDateFix;
        nNode.B['basenow'] := FBaseNow;
        nNode.S['datebase'] := DateTime2Str(FDateBase);
        nNode.S['datelast'] := DateTime2Str(FDateLast);
        nNode.S['basedelay'] := DateTime2Str(FBaseNowDelay);
        nNode.S['text'] := FText;
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

//------------------------------------------------------------------------------
//Date: 2024-12-23
//Parm: 模板标识;默认
//Desc: 查找标识nID的模板索引
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
//Parm: 模板标识;是否锁定
//Desc: 检索标识为nID的模板
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
      //复制数据
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
//Parm: 语音模板
//Desc: 添加nModal
procedure TEqualizer.AddModal(const nModal: PEqualizerModal);
var
  nIdx: Integer;
  nData: PEqualizerModal;
begin
  FSyncLock.Enter;
  try
    if nModal.FDefault then //取消其它默认
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
//Parm: 模板标识
//Desc: 删除模板
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

//------------------------------------------------------------------------------
//Date: 2025-01-05
//Parm: 计划
//Desc: 描述nTask的时间
function TEqualizer.TaskDate2Desc(const nTask: PEqualizerTask): string;
var
  nY, nM, nD, nH, nMM, nSS, nMS: Word;
begin
  case nTask.FType of
    etYear:
      begin
        Result := TDateTimeHelper.DateTime2Str(nTask.FDate);
        Exit;
      end;
    etMonth:
      if nTask.FDateFix then
        Result := '每年的M月d日h点m分s秒'
      else
        Result := '每隔M个月的d日h点m分s秒';
    etDay:
      if nTask.FDateFix then
        Result := '每月的d日h点m分s秒'
      else
        Result := '每隔d天的h点m分s秒';
    etHour:
      if nTask.FDateFix then
        Result := '每天的h点m分s秒'
      else
        Result := '每隔h小时m分s秒';
    etMin:
      if nTask.FDateFix then
        Result := '每个小时的第m分s秒'
      else
        Result := '每隔m分s秒';
    etSecond:
      if nTask.FDateFix then
        Result := '每分钟的第s秒'
      else
        Result := '每隔s秒';
  else
    begin
      Result := '';
      Exit;
    end;
  end;

  DecodeDate(nTask.FDate, nY, nM, nD);
  DecodeTime(nTask.FDate, nH, nMM, nSS, nMS);

  Result := StringReplace(Result, 'y', nY.toString, []);
  Result := StringReplace(Result, 'M', nM.toString, []);
  Result := StringReplace(Result, 'd', nD.toString, []);
  Result := StringReplace(Result, 'h', nH.toString, []);
  Result := StringReplace(Result, 'm', nMM.toString, []);

  if nSS = 0 then
    Result := Copy(Result, 1, Pos('s', Result) - 1)
  else
    Result := StringReplace(Result, 's', nSS.toString, []);
end;

//Date: 2025-01-05
//Parm: 标识
//Desc: 检索nID计划
function TEqualizer.GetTask(const nID: string): PEqualizerTask;
var
  nIdx: Integer;
begin
  for nIdx := 0 to FTasks.Count - 1 do
  begin
    Result := FTasks[nIdx];
    if CompareText(nID, Result.FID) = 0 then
      Exit;
    //has found
  end;

  Result := nil;
end;

//Date: 2025-01-05
//Parm: 标识
//Desc: 检索nID计划
function TEqualizer.FindTask(const nID: string): TEqualizerTask;
var
  nTask: PEqualizerTask;
begin
  FSyncLock.Enter;
  //xxxxx
  try
    nTask := GetTask(nID);
    if Assigned(nTask) then
    begin
      Result := nTask^;
      //复制数据
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

//Date: 2025-01-05
//Parm: 计划
//Desc: 新增计划
procedure TEqualizer.AddTask(const nTask: PEqualizerTask);
var
  nData: PEqualizerTask;
begin
  FSyncLock.Enter;
  try
    nData := GetTask(nTask.FID);
    if not Assigned(nData) then
    begin
      New(nData);
      FTasks.Add(nData);
    end;

    nData^ := nTask^;
    UpdateDateBaseNow(nData);
    FChanged := True;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2025-01-05
//Parm: 标识
//Desc: 删除nID计划
procedure TEqualizer.DeleteTask(const nID: string);
var
  nTask: PEqualizerTask;
begin
  FSyncLock.Enter;
  //xxxxx
  try
    nTask := GetTask(nID);
    if Assigned(nTask) then
    begin
      nTask.FEnabled := False;
      FChanged := True;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2025-01-08
//Parm: 新数据;操作
//Desc: 使用nNew更新nNew.FID
procedure TEqualizer.UpdateTask(const nNew: PEqualizerTask; nAction: Byte);
var
  nTask: PEqualizerTask;
begin
  FSyncLock.Enter;
  //xxxxx
  try
    nTask := GetTask(nNew.FID);
    if Assigned(nTask) then
    begin
      case nAction of
        1: //同步播放时间
          nTask.FDateLast := nTask.FDateNext;
        2: //计划已失效
          nTask.FDateLast := cDate_Invalid;
      else
        Exit;
      end;

      FChanged := True;
      //set tag
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2025-01-11
//Desc: 更新database为当前时间
procedure TEqualizer.UpdateDateBaseNow(const nTask: PEqualizerTask);
var
  nIdx: Integer;
  nNow: TDateTime;
  nH, nM, nS, nMS: Word;

  procedure DoUpdate(const nT: PEqualizerTask);
  begin
    nT.FDateLast := 0;
    nT.FDateNext := 0;
    //reset time tag

    if nT.FBaseNow then
    begin
      DecodeTime(nT.FBaseNowDelay, nH, nM, nS, nMS);
      nT.FDateBase := IncSecond(nNow, nH * 3600 + nM * 60 + nS);
      //当前时间 + 延迟
    end;
  end;

begin
  nNow := Now();
  nNow := IncMilliSecond(nNow, MilliSecondOf(nNow) * (-1));
  //删除毫秒

  if Assigned(nTask) then
  begin
    DoUpdate(nTask);
    Exit;
  end;

  FSyncLock.Enter;
  try
    for nIdx := FTasks.Count - 1 downto 0 do
      DoUpdate(FTasks[nIdx]);
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

initialization
  gEqualizer := TEqualizer.Create;

finalization
  FreeAndNil(gEqualizer);

end.

