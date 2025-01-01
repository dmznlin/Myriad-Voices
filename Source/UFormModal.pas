{*******************************************************************************
  ����: dmzn@163.com 2024-12-22
  ����: �༭����ģ��
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
    {*ģ������*}
    function ApplyModal(const nLoad: Boolean): Boolean;
    {*��������*}
  public
    { Public declarations }
  end;

function AddModal(): Boolean;
//���ģ��

function EditModal(const nID: string): Boolean;
//�༭ģ��

procedure LoadModals(const nList: TcxListView);
//����ģ��

procedure LoadListViewConfig(const nIni: TIniFile; nID: string; nListView:
  TcxListView);
//��ȡ�б�����

procedure SaveListViewConfig(const nIni: TIniFile; nID: string; nListView:
  TcxListView);
//�����б�����

implementation

{$R *.dfm}

uses
  ULibFun, UManagerGroup, UServiceTTS, USysConst;

//Date: 2024-12-22
//Desc: ��������ģ��
function AddModal(): Boolean;
begin
  with TfFormModal.Create(Application) do
  begin
    Caption := 'ģ�� - ����';
    EditID.Text := gMG.FSerialIDManager.RandomID(6);
    Result := ShowModal = mrOk;

    if Result then
      gEqualizer.AddModal(@FModal);
    Free;
  end;
end;

//Date: 2024-12-25
//Parm: ģ���ʶ
//Desc: �༭ģ��
function EditModal(const nID: string): Boolean;
begin
  with TfFormModal.Create(Application) do
  begin
    Caption := 'ģ�� - �༭';
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
//Parm: �б�
//Desc: ����ģ���嵥��nList
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
        SubItems.Add(TStringHelper.StrIF(['��', '��'], nModal.FOnHour));
        SubItems.Add(TStringHelper.StrIF(['��', '��'], nModal.FOnHalfHour));
      end;
    end;
  finally
    nList.Items.EndUpdate;
  end;
end;

//------------------------------------------------------------------------------
//Desc: ��nIDָ����С�ڶ�ȡnList��������Ϣ
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

//Desc: ��nList����Ϣ����nIDָ����С��
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
//Desc: ��������ѡ���ɫ
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
//Parm: �Ƿ����
//Desc: ����FModal������,�������ô���FModal
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
      TApplicationHelper.ShowMsg('��ѡ���������', sHint);
      EditLang.DroppedDown := True;
      Exit;
    end;

    FLang := EditLang.EditText;
    //set lang

    if EditVoice.ItemIndex < 0 then
    begin
      TApplicationHelper.ShowMsg('��ѡ���ʶ���ɫ', sHint);
      EditVoice.DroppedDown := True;
      Exit;
    end;

    EditID.Text := Trim(EditID.Text);
    if EditID.Text = '' then
    begin
      TApplicationHelper.ShowMsg('����дģ������', sHint);
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
//Desc: ����ģ��
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

