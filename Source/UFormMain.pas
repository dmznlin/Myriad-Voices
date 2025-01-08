{*******************************************************************************
  作者: dmzn@163.com 2024-12-16
  描述: 千音TTS主单元
*******************************************************************************}
unit UFormMain;

{$I Link.Inc}
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  UDataModule, cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters,
  cxContainer, cxEdit, dxSkinsCore, dxSkinHighContrast, dxSkinMcSkin,
  dxSkinOffice2007Blue, dxSkinOffice2007Green, dxSkinOffice2019White,
  dxSkinSevenClassic, dxBarBuiltInMenu, cxGeometry, dxFramedControl, Vcl.Menus,
  Vcl.ComCtrls, Vcl.ExtCtrls, dxStatusBar, cxTrackBar, cxListView, cxTreeView,
  cxMaskEdit, cxDropDownEdit, cxImageComboBox, cxGroupBox, cxTextEdit, cxMemo,
  cxCheckBox, Vcl.StdCtrls, cxButtons, dxPanel, cxPC, cxLabel;

type
  TfFormMain = class(TForm)
    PanelTitle: TPanel;
    ImgLeft: TImage;
    ImgClient: TImage;
    LabelHint: TcxLabel;
    wPage1: TcxPageControl;
    SheetLogs: TcxTabSheet;
    SheetSet: TcxTabSheet;
    SheetModal: TcxTabSheet;
    dxPanel1: TdxPanel;
    BtnCopy: TcxButton;
    BtnClear: TcxButton;
    MemoLog: TcxMemo;
    TimerNow: TTimer;
    CheckSrv: TcxCheckBox;
    CheckSyncUI: TcxCheckBox;
    SBar1: TdxStatusBar;
    TrayIcon1: TTrayIcon;
    PMenu1: TPopupMenu;
    N1: TMenuItem;
    Group1: TcxGroupBox;
    CheckAutoStart: TcxCheckBox;
    CheckAutoRun: TcxCheckBox;
    CheckAutoMin: TcxCheckBox;
    Group2: TcxGroupBox;
    TreeDevices: TcxTreeView;
    BevelTop: TBevel;
    dxPanel2: TdxPanel;
    BtnDevices: TcxButton;
    TimerDelay: TTimer;
    cxGroupBox3: TcxGroupBox;
    dxPanel3: TdxPanel;
    BtnDelModal: TcxButton;
    cxGroupBox4: TcxGroupBox;
    Track125: TcxTrackBar;
    cxLabel1: TcxLabel;
    Track1K: TcxTrackBar;
    cxLabel2: TcxLabel;
    Track8K: TcxTrackBar;
    cxLabel3: TcxLabel;
    cxLabel4: TcxLabel;
    TrackRever: TcxTrackBar;
    ListModals: TcxListView;
    BtnAddModal: TcxButton;
    cxLabel5: TcxLabel;
    EditThemes: TcxImageComboBox;
    BtnStatus: TcxButton;
    SheetTask: TcxTabSheet;
    cxGroupBox1: TcxGroupBox;
    dxPanel4: TdxPanel;
    BtnDelTask: TcxButton;
    BtnAddTask: TcxButton;
    ListTasks: TcxListView;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TimerNowTimer(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure CheckSyncUIClick(Sender: TObject);
    procedure BtnCopyClick(Sender: TObject);
    procedure BtnClearClick(Sender: TObject);
    procedure BtnDevicesClick(Sender: TObject);
    procedure TimerDelayTimer(Sender: TObject);
    procedure Track125PropertiesChange(Sender: TObject);
    procedure wPage1PageChanging(Sender: TObject; NewPage: TcxTabSheet; var
      AllowChange: Boolean);
    procedure EditThemesPropertiesChange(Sender: TObject);
    procedure BtnAddModalClick(Sender: TObject);
    procedure BtnDelModalClick(Sender: TObject);
    procedure BtnStatusClick(Sender: TObject);
    procedure ListModalsDblClick(Sender: TObject);
    procedure CheckAutoStartPropertiesChange(Sender: TObject);
    procedure CheckSrvClick(Sender: TObject);
    procedure BtnAddTaskClick(Sender: TObject);
    procedure BtnDelTaskClick(Sender: TObject);
    procedure ListTasksDblClick(Sender: TObject);
  private
    { Private declarations }
    FCanExit: Boolean;
    {*可退出*}
    FSample: Cardinal;
    {*声音样本*}
    FSkinName: string;
    {*皮肤名称*}
    procedure ShowLog(const nStr: string);
    //显示日志
    procedure LoadFormConfig;
    //界面配置
    procedure ApplyTheme;
    //应用主题
    function LoadVoiceList: Boolean;
    //角色列表
  public
    { Public declarations }
  end;

var
  fFormMain: TfFormMain;

implementation

{$R *.dfm}

uses
  System.IniFiles, System.Win.Registry, System.SyncObjs, cxPCPainters, ULibFun,
  UManagerGroup, UWaitIndicator, UBaseObject, UFormModal, UFormTask, UEqualizer,
  UServiceTTS, bass, USysConst;

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TfFormMain, 'TTS-主模块', nEvent);
end;

//Desc: 初始化
procedure TfFormMain.FormCreate(Sender: TObject);
begin
  //global
  gPath := TApplicationHelper.gPath;

  //variant
  FSample := 0;
  FCanExit := False;

  //ui config
  CheckSyncUI.Checked := True;
  wPage1.ActivePage := SheetLogs;
  EditThemes.Properties.Items.Clear;

  Track125.Tag := cEqualizer_125;
  Track1K.Tag := cEqualizer_1K;
  Track8K.Tag := cEqualizer_8K;
  TrackRever.Tag := cEqualizer_Rever;

  //log service
  gMG.FLogManager.SyncMainUI := True;
  gMG.FLogManager.SyncSimple := ShowLog;
  gMG.FLogManager.StartService();

  //form config
  LoadFormConfig();

  //delay service
  TimerDelay.Enabled := True;
end;

//Date: 2024-12-17
//Desc: 载入窗体配置数据
procedure TfFormMain.LoadFormConfig;
var
  nStr: string;
  nIni: TIniFile;
  nReg: TRegistry;
begin
  nIni := TIniFile.Create(TApplicationHelper.gFormConfig);
  try
    //form config
    TApplicationHelper.LoadFormConfig(Self, nIni);
    LoadListViewConfig(nIni, Self.Name, ListModals);
    LoadListViewConfig(nIni, Self.Name, ListTasks);

    FSkinName := nIni.ReadString('Config', 'SkinName', '');
    CheckAutoRun.Checked := nIni.ReadBool('Config', 'AutoRun', False);
    CheckAutoMin.Checked := nIni.ReadBool('Config', 'AutoMin', False);
  finally
    nIni.Free;
  end;

  nReg := TRegistry.Create;
  try
    nReg.RootKey := HKEY_CURRENT_USER;
    nReg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True);
    //registry
    CheckAutoStart.Checked := nReg.ValueExists('MyriadTTS');
  finally
    nReg.Free;
  end;

  if FSkinName <> '' then
    ApplyTheme();
  //enable skin

  try
    //verify&load config
    TApplicationHelper.LoadParameters(gApp, nil, True);
  except
    on nErr: Exception do
    begin
      WriteLog(nErr.Message);
      CheckSrv.Enabled := False;
    end;
  end;

  with gApp.FActive do
  begin
    Application.Title := FTitleApp;
    LabelHint.Caption := FTitleMain;
    LabelHint.Left := PanelTitle.Width - LabelHint.Width - 10;

    SBar1.Panels[0].Text := FCopyRight;
    SBar1.Panels[0].Width := SBar1.Canvas.TextWidth(FCopyRight) + 30;
  end;

  //verify date
  nStr := gPath + 'Config.key';
  if TApplicationHelper.IsSystemExpire(nStr) then
  begin
    if gApp.FActive.GetParam('AutoRenewal') = sFlag_Yes then//自动续约
    begin
      TApplicationHelper.AddExpireDate(nStr, TDateTimeHelper.Date2Str(Now() +
          365), True);
      //xxxxx
    end
    else
    begin
      WriteLog('system has expired.');
      CheckSrv.Enabled := False;
    end;
  end;

  nStr := Trim(gApp.FActive.GetParam('SrvTTS'));
  if nStr = '' then
  begin
    WriteLog('请先配置"SrvTTS"参数.');
    CheckSrv.Enabled := False;
  end
  else
  begin
    gVoiceManager.RemoteURL := nStr;
    //tts service
  end;

  //equalize and modals
  gEqualizer.LoadConfig(gPath + sFileModal);

  with gEqualizer.EqualizerData do
  begin
    Track125.Position := F125;
    Track1K.Position := F1K;
    Track8K.Position := F8K;
    TrackRever.Position := FRever;
  end;
end;

//Date: 2024-12-20
//Desc: 延迟启动
procedure TfFormMain.TimerDelayTimer(Sender: TObject);
begin
  TimerDelay.Enabled := False;
  //run once

  if not TEqualizer.InitBassLibrary then //init bass
  begin
    CheckSrv.Enabled := False;
  end;

  //所有管理器进入工作状态
  gMG.RunAfterApplicationStart;

  if CheckAutoRun.Checked and CheckSrv.Enabled then
    CheckSrv.Checked := True;
  //准备启动服务
end;

procedure TfFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
var
  nIni: TIniFile;
  nReg: TRegistry;
begin
  {$IFNDEF debug}
  if not FCanExit then
  begin
    Action := caNone;
    Visible := False;
    Exit;
  end;
  {$ENDIF}

  nIni := TIniFile.Create(TApplicationHelper.gFormConfig);
  try
    //ui
    TApplicationHelper.SaveFormConfig(Self, nIni);

    if EditThemes.Tag = cTag_Ok then
      nIni.WriteString('Config', 'SkinName', FSkinName);
    //xxxxx

    if CheckAutoRun.Tag = cTag_Ok then
      nIni.WriteBool('Config', 'AutoRun', CheckAutoRun.Checked);
    //xxxxx

    if CheckAutoMin.Tag = cTag_Ok then
      nIni.WriteBool('Config', 'AutoMin', CheckAutoMin.Checked);
    //xxxxx

    if ListModals.Tag = cTag_Ok then
      SaveListViewConfig(nIni, Self.Name, ListModals);
    //xxxxx

    if ListTasks.Tag = cTag_Ok then
      SaveListViewConfig(nIni, Self.Name, ListTasks);
    //xxxxx
  finally
    nIni.Free;
  end;

  nReg := nil;
  if CheckAutoStart.Tag = cTag_Ok then
  try
    nReg := TRegistry.Create;
    nReg.RootKey := HKEY_CURRENT_USER;
    nReg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True);
    //registry

    if CheckAutoStart.Checked then
      nReg.WriteString('MyriadTTS', Application.ExeName)
    else if nReg.ValueExists('MyriadTTS') then
      nReg.DeleteValue('MyriadTTS');
    //xxxxx
  finally
    nReg.Free;
  end;

  CheckSrv.Checked := False;
  //停止服务

  //equalize and modals
  if gEqualizer.ConfigChanged then
    gEqualizer.SaveConfig(gPath + sFileModal);
  FreeAndNil(gEqualizer);

  //释放bass资源
  TEqualizer.FreeBassLibrary;

  //准备退出所有管理器
  gMG.RunBeforApplicationHalt;
end;

//------------------------------------------------------------------------------
procedure TfFormMain.N1Click(Sender: TObject);
begin
  FCanExit := True;
  Close();
end;

procedure TfFormMain.TrayIcon1DblClick(Sender: TObject);
begin
  if not Visible then
    Visible := True;
  //xxxxx
end;

//Desc: 显示日志
procedure TfFormMain.ShowLog(const nStr: string);
var
  nIdx: Integer;
begin
  MemoLog.Lines.BeginUpdate;
  try
    MemoLog.Lines.Insert(0, nStr);
    if MemoLog.Lines.Count > 100 then
      for nIdx := MemoLog.Lines.Count - 1 downto 50 do
        MemoLog.Lines.Delete(nIdx);
  finally
    MemoLog.Lines.EndUpdate;
  end;
end;

procedure TfFormMain.TimerNowTimer(Sender: TObject);
begin
  with TDateTimeHelper do
    SBar1.Panels[1].Text := '※.' + DateTime2Str(Now()) + ' ' + Date2Week();
  //xxxxx
end;

//Date: 2024-12-26
//Desc: 启停服务
procedure TfFormMain.CheckSrvClick(Sender: TObject);
begin
  if CheckSrv.Checked then
  begin
    if FDM.StartServer() then
    begin
      if CheckAutoMin.Checked and (not CheckSrv.Focused) then
        Visible := False;
     //xxxxx
    end
    else
    begin
      CheckSrv.Checked := False;
    end;
  end
  else
  begin
    FDM.StopServer();
  end;
end;

procedure TfFormMain.CheckSyncUIClick(Sender: TObject);
var
  nStr: string;
begin
  gMG.FLogManager.SyncMainUI := CheckSyncUI.Checked;
  //xxxxx

  if CheckSyncUI.Focused then
  begin
    with TStringHelper do
      nStr := '实时日志已' + StrIF(['打开', '关闭'], CheckSyncUI.Checked);
    TApplicationHelper.ShowMsg(nStr, sHint);
  end;
end;

procedure TfFormMain.BtnStatusClick(Sender: TObject);
var
  nIdx, nNum: Integer;
begin
  MemoLog.Clear;
  with TObjectStatusHelper do
  try
    gEqualizer.SyncLock.Enter;
    AddTitle(MemoLog.Lines, TVoiceManager.ClassName);
    nNum := 0;

    for nIdx := gEqualizer.Channels.Count - 1 downto 0 do
      if PEqualizerChan(gEqualizer.Channels[nIdx]).FUsed then
        Inc(nNum);
    //xxxxx

    MemoLog.Lines.Add(FixData('模板:', gEqualizer.Modals.Count));
    MemoLog.Lines.Add(FixData('通道:', nNum.ToString + '/' +
        gEqualizer.Channels.Count.ToString));
    //xxxxx
  finally
    gEqualizer.SyncLock.Leave;
  end;

  gMG.GetManagersStatus(MemoLog.Lines);
  //manager status
end;

procedure TfFormMain.BtnCopyClick(Sender: TObject);
begin
  MemoLog.SelectAll;
  if MemoLog.SelLength > 0 then
  begin
    MemoLog.CopyToClipboard;
    TApplicationHelper.ShowMsg('日志已复制到剪切板', sHint);
  end;
end;

procedure TfFormMain.BtnClearClick(Sender: TObject);
begin
  MemoLog.Clear;
end;

//Desc: 刷新设备列表
procedure TfFormMain.BtnDevicesClick(Sender: TObject);
type
  TAddDevice = reference to procedure(const nParent: TTreeNode; nType: Integer);
  //add sub node
const
  cIdx_Root = 3;
  cIdx_Dev = 4;
  cIdx_Output = 5;
  cIdx_Input = 6;
  cIdx_Item = 7;
var
  nIdx: Cardinal;
  nNode, nRoot: TTreeNode;
  nAdd: TAddDevice;
  nDI: BASS_DEVICEINFO;
begin
  //Date: 2024-12-18
  //Parm: 父节点;in/out
  //Desc: 在nPNode上添加nID信息的节点
  nAdd :=
    procedure(const nPNode: TTreeNode; nType: Integer)
    var
      nST: string;
      nSub: TTreeNode;
    begin
      nSub := TreeDevices.Items.AddChild(nPNode, nDI.Name);
      with nSub do
      begin
        ImageIndex := nType;
        SelectedIndex := ImageIndex;
      end;

      if (nDI.flags and BASS_DEVICE_ENABLED) = BASS_DEVICE_ENABLED then
        nST := '启用'
      else
        nST := '禁用';

      with TreeDevices.Items.AddChild(nSub, '状态: ' + nST) do
      begin
        ImageIndex := cIdx_Item;
        SelectedIndex := ImageIndex;
      end;

      if (nDI.flags and BASS_DEVICE_DEFAULT) = BASS_DEVICE_DEFAULT then
        nST := '是'
      else
        nST := '否';

      with TreeDevices.Items.AddChild(nSub, '默认: ' + nST) do
      begin
        ImageIndex := cIdx_Item;
        SelectedIndex := ImageIndex;
      end;

      case (nDI.flags and BASS_DEVICE_TYPE_MASK) of
        BASS_DEVICE_TYPE_NETWORK:
          nST := 'Remote Network';
        BASS_DEVICE_TYPE_SPEAKERS:
          nST := 'Speakers';
        BASS_DEVICE_TYPE_LINE:
          nST := 'Line';
        BASS_DEVICE_TYPE_HEADPHONES:
          nST := 'Headphones';
        BASS_DEVICE_TYPE_MICROPHONE:
          nST := 'Microphone';
        BASS_DEVICE_TYPE_HEADSET:
          nST := 'Headset';
        BASS_DEVICE_TYPE_HANDSET:
          nST := 'Handset';
        BASS_DEVICE_TYPE_DIGITAL:
          nST := 'Digital';
        BASS_DEVICE_TYPE_SPDIF:
          nST := 'SPDIF';
        BASS_DEVICE_TYPE_HDMI:
          nST := 'HDMI';
        BASS_DEVICE_TYPE_DISPLAYPORT:
          nST := 'DisplayPort';
      else
        nST := 'Unknown';
      end;

      with TreeDevices.Items.AddChild(nSub, '类型: ' + nST) do
      begin
        ImageIndex := cIdx_Item;
        SelectedIndex := ImageIndex;
      end;

      with TreeDevices.Items.AddChild(nSub, '标识: ' + nDI.driver) do
      begin
        ImageIndex := cIdx_Item;
        SelectedIndex := ImageIndex;
      end;
    end;

  with TreeDevices.Items do
  try
    BeginUpdate;
    Clear;

    nRoot := AddChild(nil, '音频设备');
    with nRoot do
    begin
      ImageIndex := cIdx_Root;
      SelectedIndex := ImageIndex;
    end;

    nNode := AddChild(nRoot, '音频输出');
    with nNode do
    begin
      ImageIndex := cIdx_Dev;
      SelectedIndex := ImageIndex;
    end;

    nIdx := 1;
    while BASS_GetDeviceInfo(nIdx, nDI) do
    begin
      nAdd(nNode, cIdx_Output);
      Inc(nIdx);
    end;

    nNode := AddChild(nRoot, '音频输入');
    with nNode do
    begin
      ImageIndex := cIdx_Dev;
      SelectedIndex := ImageIndex;
    end;

    nIdx := 0;
    while BASS_RecordGetDeviceInfo(nIdx, nDI) do
    begin
      nAdd(nNode, cIdx_Input);
      Inc(nIdx);
    end;
  finally
    EndUpdate;
    TreeDevices.FullExpand;

    if TreeDevices.Items.Count > 0 then
      TreeDevices.Items[0].MakeVisible;
    //xxxxx
  end;
end;

//Date: 2024-12-20
//Desc: 均衡调节
procedure TfFormMain.Track125PropertiesChange(Sender: TObject);
var
  nTrack: TcxTrackBar;
begin
  nTrack := TcxTrackBar(Sender);
  if not nTrack.Focused then
    Exit;
  //xxxxx

  if FSample = 0 then
  begin
    FSample := gEqualizer.NewChan().FID;
    gEqualizer.ChanFile(nil, gPath + 'sample.wav', FSample);
    gEqualizer.InitEqualizer(FSample);
  end;

  gEqualizer.PlayChan(FSample);
  gEqualizer.SetEqualizer(FSample, nTrack.Position, nTrack.Tag);
end;

procedure TfFormMain.CheckAutoStartPropertiesChange(Sender: TObject);
var
  nCtl: TWinControl;
begin
  nCtl := TWinControl(Sender);
  if nCtl.Focused then
    nCtl.Tag := cTag_Ok;
  //xxxxx
end;

//Date: 2024-12-20
//Desc: 工作页面切换
procedure TfFormMain.wPage1PageChanging(Sender: TObject; NewPage: TcxTabSheet;
  var AllowChange: Boolean);
var
  nIdx: Integer;
  nList: TStrings;
begin
  if (NewPage <> SheetModal) and (FSample <> 0) then //释放声音样本
  begin
    gEqualizer.FreeChan(FSample);
    FSample := 0;
  end;

  nList := nil;
  if (NewPage = SheetSet) and (EditThemes.Tag <> cTag_Ok) then
  try
    EditThemes.Tag := cTag_Ok;
    nList := gMG.FObjectPool.Lock(TStrings) as TStrings;
    nList.Add('Default Skin');

    FDM.LoadSkins(nList);
    for nIdx := 0 to nList.Count - 1 do
    begin
      with EditThemes.Properties.Items.Add do
      begin
        Description := nList[nIdx];
        ImageIndex := EditThemes.Properties.DefaultImageIndex;
        Value := nList[nIdx];
      end;

      if (FSkinName <> '') and (nList[nIdx] = FSkinName) then
        EditThemes.ItemIndex := nIdx;
      //xxxxx
    end; //skins

    BtnDevices.Click();
    //load devices
  finally
    gMG.FObjectPool.Release(nList);
  end;

  if (NewPage = SheetModal) and (ListModals.Tag <> cTag_Ok) then
  begin
    ListModals.Tag := cTag_Ok;
    LoadModals(ListModals);
  end;

  if (NewPage = SheetTask) and (ListTasks.Tag <> cTag_Ok) then
  begin
    ListTasks.Tag := cTag_Ok;
    LoadTasks(ListTasks);
  end;
end;

//Date: 2024-12-20
//Desc: 切换皮肤
procedure TfFormMain.EditThemesPropertiesChange(Sender: TObject);
begin
  if EditThemes.Focused and (EditThemes.ItemIndex >= 0) then
  begin
    EditThemes.Tag := cTag_Ok;
    if EditThemes.ItemIndex < 1 then
      FSkinName := ''
    else
      FSkinName := EditThemes.EditText;

    ApplyTheme;
  end;
end;

//Date: 2024-12-25
//Desc: 应用当前选中的主题
procedure TfFormMain.ApplyTheme;
begin
  FDM.SetSkin(FSkinName); //apply skin
  if FSkinName = '' then
  begin
    wPage1.Properties.Style := cxPCSlantedStyle;
  end
  else
  begin
    wPage1.Properties.Style := cxPCSkinStyle;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2024-12-30
//Desc: 加载角色列表
function TfFormMain.LoadVoiceList: Boolean;
begin
  Result := gVoiceManager.Voices.Count > 0;
  if not Result then
  try
    ShowWaitForm(Self, '读取角色清单', True);
    Result := gVoiceManager.LoadVoice();
  finally
    CloseWaitForm();
  end;

  if not Result then
    TApplicationHelper.ShowMsg('请查看运行日志', '读取失败');
  //xxxxx
end;

//Date: 2024-12-22
//Desc: 新增模板
procedure TfFormMain.BtnAddModalClick(Sender: TObject);
begin
  if LoadVoiceList() and AddModal() then
    LoadModals(ListModals);
  //xxxxx
end;

//Date: 2024-12-25
//Desc: 编辑模板
procedure TfFormMain.ListModalsDblClick(Sender: TObject);
var
  nStr: string;
  nIdx: Integer;
begin
  nIdx := ListModals.ItemIndex;
  if nIdx < 0 then
    Exit;
  //invalid

  nStr := ListModals.Items[nIdx].Caption;
  if LoadVoiceList() and EditModal(nStr) then
  begin
    LoadModals(ListModals);
    ListModals.ItemIndex := nIdx;
  end;
end;

//Date: 2024-12-25
//Desc: 删除模板
procedure TfFormMain.BtnDelModalClick(Sender: TObject);
var
  nStr, nID: string;
  nIdx: Integer;
begin
  nIdx := ListModals.ItemIndex;
  if nIdx < 0 then
    Exit;
  //invalid

  nID := ListModals.Items[nIdx].Caption;
  nStr := Format('确定要删除名称为 %s 的模板吗?', [nID]);
  if TApplicationHelper.QueryDlg(nStr, '询问', Handle) then
  begin
    gEqualizer.DeleteModal(nID);
    LoadModals(ListModals);

    if ListModals.Items.Count > nIdx then
      ListModals.ItemIndex := nIdx
    else
      ListModals.ItemIndex := nIdx - 1;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2025-01-03
//Desc: 新增计划
procedure TfFormMain.BtnAddTaskClick(Sender: TObject);
begin
  if AddTask() then
  begin
    gVoiceManager.ResetNextTime();
    LoadTasks(ListTasks);
  end;
end;

//Date: 2025-01-03
//Desc: 编辑计划
procedure TfFormMain.ListTasksDblClick(Sender: TObject);
var
  nStr: string;
  nIdx: Integer;
begin
  nIdx := ListTasks.ItemIndex;
  if nIdx < 0 then
    Exit;
  //invalid

  nStr := ListTasks.Items[nIdx].Caption;
  if EditTask(nStr) then
  begin
    gVoiceManager.ResetNextTime();
    LoadTasks(ListTasks);
    ListTasks.ItemIndex := nIdx;
  end;
end;

//Date: 2025-01-03
//Desc: 删除计划
procedure TfFormMain.BtnDelTaskClick(Sender: TObject);
var
  nStr, nID: string;
  nIdx: Integer;
begin
  nIdx := ListTasks.ItemIndex;
  if nIdx < 0 then
    Exit;
  //invalid

  nID := ListTasks.Items[nIdx].Caption;
  nStr := Format('确定要删除名称为 %s 的计划吗?', [nID]);
  if TApplicationHelper.QueryDlg(nStr, '询问', Handle) then
  begin
    gEqualizer.DeleteModal(nID);
    LoadTasks(ListTasks);

    if ListTasks.Items.Count > nIdx then
      ListTasks.ItemIndex := nIdx
    else
      ListTasks.ItemIndex := nIdx - 1;
  end;
end;

end.

