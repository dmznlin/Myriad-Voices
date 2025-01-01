{*******************************************************************************
  作者: dmzn@163.com 2024-12-22
  描述: 编辑语音模板
*******************************************************************************}
unit UFormModal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, cxListView, System.Classes,
  Vcl.Controls, Vcl.Forms, System.IniFiles, bass, UDataModule, UEqualizer,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  cxEdit, dxSkinsCore, dxSkinHighContrast, dxSkinMcSkin, dxSkinOffice2007Blue,
  dxSkinOffice2007Green, dxSkinOffice2019White, dxSkinSevenClassic, Vcl.Menus,
  Vcl.StdCtrls, cxButtons, cxTrackBar, cxCheckBox, cxTextEdit, cxSpinEdit,
  cxMaskEdit, cxDropDownEdit, cxImageComboBox, cxLabel, cxGroupBox;

type
  TfFormModal = class(TForm)
    Group1: TcxGroupBox;
    BtnOK: TcxButton;
    BtnExit: TcxButton;
    cxLabel1: TcxLabel;
    EditLang: TcxImageComboBox;
    cxLabel2: TcxLabel;
    EditVoice: TcxImageComboBox;
    EditLoop: TcxSpinEdit;
    cxLabel3: TcxLabel;
    cxLabel4: TcxLabel;
    EditInterval: TcxSpinEdit;
    cxLabel5: TcxLabel;
    EditHour: TcxTextEdit;
    EditHalf: TcxTextEdit;
    CheckHour: TcxCheckBox;
    CheckHalf: TcxCheckBox;
    cxLabel6: TcxLabel;
    cxLabel7: TcxLabel;
    cxLabel8: TcxLabel;
    TrackSpeed: TcxTrackBar;
    TrackPitch: TcxTrackBar;
    TrackVolume: TcxTrackBar;
    cxLabel9: TcxLabel;
    EditDemo: TcxTextEdit;
    BtnTest: TcxButton;
    CheckDefault: TcxCheckBox;
    EditID: TcxTextEdit;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure EditLangPropertiesChange(Sender: TObject);
    procedure BtnTestClick(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
  private
    { Private declarations }
    FModal: TEqualizerModal;
    {*模板数据*}
    function ApplyModal(const nLoad: Boolean): Boolean;
    {*接收数据*}
  public
    { Public declarations }
  end;

function AddModal(): Boolean;
//添加模板

function EditModal(const nID: string): Boolean;
//编辑模板

procedure LoadModals(const nList: TcxListView);
//载入模板

procedure LoadListViewConfig(const nIni: TIniFile; nID: string; nListView:
  TcxListView);
//读取列表配置

procedure SaveListViewConfig(const nIni: TIniFile; nID: string; nListView:
  TcxListView);
//保存列表配置

implementation

{$R *.dfm}

uses
  ULibFun, UManagerGroup, UServiceTTS, USysConst;

//Date: 2024-12-22
//Desc: 新增语音模板
function AddModal(): Boolean;
begin
  with TfFormModal.Create(Application) do
  begin
    Caption := '模板 - 新增';
    EditID.Text := gMG.FSerialIDManager.RandomID(6);
    Result := ShowModal = mrOk;

    if Result then
      gEqualizer.AddModal(@FModal);
    Free;
  end;
end;

//Date: 2024-12-25
//Parm: 模板标识
//Desc: 编辑模板
function EditModal(const nID: string): Boolean;
begin
  with TfFormModal.Create(Application) do
  begin
    Caption := '模板 - 编辑';
    FModal := gEqualizer.FindModal(nID);
    if FModal.FID = '' then
      FModal.FID := gMG.FSerialIDManager.RandomID(6);
    //xxxxx

    ApplyModal(True);
    Result := ShowModal = mrOk;
    if Result then
      gEqualizer.AddModal(@FModal);
    Free;
  end;
end;

//Date: 2024-12-25
//Parm: 列表
//Desc: 加载模板清单到nList
procedure LoadModals(const nList: TcxListView);
var
  nIdx: Integer;
  nModal: PEqualizerModal;
begin
  nList.Items.BeginUpdate;
  try
    nList.Items.Clear;
    for nIdx := 0 to gEqualizer.Modals.Count - 1 do
    begin
      nModal := gEqualizer.Modals[nIdx];
      if not nModal.FEnabled then
        Continue;
      //invalid

      with nList.Items.Add do
      begin
        ImageIndex := cImg_Modal;
        Caption := nModal.FID;
        SubItems.Add(nModal.FLang);
        SubItems.Add(nModal.FVoice);
        SubItems.Add(IntToStr(nModal.FLoopTime));
        SubItems.Add(IntToStr(nModal.FLoopInterval));
        SubItems.Add(TStringHelper.StrIF(['是', '否'], nModal.FOnHour));
        SubItems.Add(TStringHelper.StrIF(['是', '否'], nModal.FOnHalfHour));
      end;
    end;
  finally
    nList.Items.EndUpdate;
  end;
end;

//------------------------------------------------------------------------------
//Desc: 从nID指定的小节读取nList的配置信息
procedure LoadListViewConfig(const nIni: TIniFile; nID: string; nListView:
  TcxListView);
var
  nList: TStrings;
  i, nCount: integer;
begin
  nList := gMG.FObjectPool.Lock(TStrings) as TStrings;
  try
    nList.Text := StringReplace(nIni.ReadString(nID, nListView.Name + '_Cols',
        ''), ';', #13, [rfReplaceAll]);
    if nList.Count <> nListView.Columns.Count then
      Exit;

    nCount := nListView.Columns.Count - 1;
    for i := 0 to nCount do
      if TStringHelper.IsNumber(nList[i], False) then
        nListView.Columns[i].Width := StrToInt(nList[i]);
    //xxxxx
  finally
    gMG.FObjectPool.Release(nList);
  end;
end;

//Desc: 将nList的信息存入nID指定的小节
procedure SaveListViewConfig(const nIni: TIniFile; nID: string; nListView:
  TcxListView);
var
  nStr: string;
  i, nCount: integer;
begin
  nStr := '';
  nCount := nListView.Columns.Count - 1;

  for i := 0 to nCount do
  begin
    nStr := nStr + IntToStr(nListView.Columns[i].Width);
    if i <> nCount then
      nStr := nStr + ';';
  end;

  nIni.WriteString(nID, nListView.Name + '_Cols', nStr);
end;

//------------------------------------------------------------------------------
procedure TfFormModal.FormCreate(Sender: TObject);
var
  nIdx: Integer;
  nList: TStringList;
  nVoice: PVoiceItem;
begin
  EditLang.Properties.DefaultImageIndex := cImg_lang;
  EditVoice.Properties.DefaultImageIndex := cImg_male;
  TApplicationHelper.LoadFormConfig(Self);

  nList := TStringList.Create;
  try
    for nIdx := 0 to gVoiceManager.Voices.Count - 1 do
    begin
      nVoice := gVoiceManager.Voices[nIdx];
      if nList.IndexOf(nVoice.FDesc) < 0 then
        nList.Add(nVoice.FDesc);
      //xxxxx
    end;

    nList.Sorted := True;
    for nIdx := 0 to nList.Count - 1 do
      with EditLang.Properties.Items.Add do
      begin
        Description := nList[nIdx];
        ImageIndex := cImg_lang;
        Value := nList[nIdx];
      end;
  finally
    nList.Free;
  end;
end;

//Date: 2024-12-24
//Desc: 根据语种选择角色
procedure TfFormModal.EditLangPropertiesChange(Sender: TObject);
var
  nIdx: Integer;
  nVoice: PVoiceItem;
begin
  if EditLang.ItemIndex < 0 then
    Exit;
  //invalid

  EditVoice.Properties.Items.Clear;
  //init first

  for nIdx := 0 to gVoiceManager.Voices.Count - 1 do
  begin
    nVoice := gVoiceManager.Voices[nIdx];
    if nVoice.FDesc = EditLang.Text then
      with EditVoice.Properties.Items.Add do
      begin
        Description := nVoice.FName;
        if nVoice.FGender = 'female' then
          ImageIndex := cImg_female
        else
          ImageIndex := cImg_male;
        Value := nVoice.FID;
      end;
  end;
end;

procedure TfFormModal.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  gEqualizer.FreeChan(gEqualizer.FirstChan.FID, True);
  TApplicationHelper.SaveFormConfig(Self);
end;

//Date: 2024-12-24
//Parm: 是否加载
//Desc: 加载FModal到窗体,或窗体配置存入FModal
function TfFormModal.ApplyModal(const nLoad: Boolean): Boolean;
var
  nIdx: Integer;
begin
  if nLoad then
  begin
    for nIdx := 0 to EditLang.Properties.Items.Count - 1 do
      if EditLang.Properties.Items[nIdx].Value = FModal.FLang then
      begin
        EditLang.ItemIndex := nIdx;
        Break;
      end;
    //1.set lang

    EditVoice.ItemIndex := -1;

    for nIdx := 0 to EditVoice.Properties.Items.Count - 1 do
      if EditVoice.Properties.Items[nIdx].Value = FModal.FVoice then
      begin
        EditVoice.ItemIndex := nIdx;
        Break;
      end;
    //xxxxx

    with FModal do
    begin
      EditID.Text := FID;
      EditLoop.Value := FLoopTime;
      EditInterval.Value := FLoopInterval;
      CheckHour.Checked := FOnHour;
      EditHour.Text := FOnHourText;
      CheckHalf.Checked := FOnHalfHour;
      EditHalf.Text := FOnHalfText;

      TrackSpeed.Position := FSpeed;
      TrackPitch.Position := FPitch;
      TrackVolume.Position := FVolume;

      EditDemo.Text := FDemoText;
      CheckDefault.Checked := FDefault;
    end;

    Result := True;
    Exit;
  end;

  Result := False;
  with FModal do
  begin
    if EditLang.ItemIndex < 0 then
    begin
      TApplicationHelper.ShowMsg('请选择语言类别', sHint);
      EditLang.DroppedDown := True;
      Exit;
    end;

    FLang := EditLang.EditText;
    //set lang

    if EditVoice.ItemIndex < 0 then
    begin
      TApplicationHelper.ShowMsg('请选择朗读角色', sHint);
      EditVoice.DroppedDown := True;
      Exit;
    end;

    EditID.Text := Trim(EditID.Text);
    if EditID.Text = '' then
    begin
      TApplicationHelper.ShowMsg('请填写模板名称', sHint);
      ActiveControl := EditID;
      Exit;
    end;

    FVoice := EditVoice.Properties.Items[EditVoice.ItemIndex].Value;
    //set voicer
    FEnabled := True;
    FID := EditID.Text;

    FLoopTime := EditLoop.Value;
    FLoopInterval := EditInterval.Value;
    FOnHour := CheckHour.Checked;
    FOnHourText := Trim(EditHour.Text);
    FOnHalfHour := CheckHalf.Checked;
    FOnHalfText := Trim(EditHalf.Text);

    FSpeed := TrackSpeed.Position;
    FPitch := TrackPitch.Position;
    FVolume := TrackVolume.Position;

    FDemoText := Trim(EditDemo.Text);
    FDefault := CheckDefault.Checked;
    Result := True;
  end;
end;

//Date: 2024-12-24
//Desc: 测试模板
procedure TfFormModal.BtnTestClick(Sender: TObject);
begin
  if ApplyModal(False) then
  try
    BtnTest.Enabled := False;
    gVoiceManager.PlayVoice(gEqualizer.FirstChan, @FModal, FModal.FDemoText);
  finally
    BtnTest.Enabled := True;
  end;
end;

procedure TfFormModal.BtnOKClick(Sender: TObject);
begin
  if ApplyModal(False) then
    ModalResult := mrOk;
  //xxxxx
end;

end.

