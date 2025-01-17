{*******************************************************************************
  ����: dmzn@163.com 2025-01-05
  ����: �༭���żƻ�
*******************************************************************************}
unit UFormTask;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, cxListView, System.Classes,
  Vcl.Controls, Vcl.Forms, System.IniFiles, bass, UDataModule, UEqualizer,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  cxEdit, dxSkinsCore, dxSkinHighContrast, dxSkinMcSkin, dxSkinOffice2007Blue,
  dxSkinOffice2007Green, dxSkinOffice2019White, dxSkinSevenClassic, Vcl.Menus,
  cxCheckBox, Vcl.StdCtrls, cxButtons, cxMemo, cxTrackBar, dxWheelPicker,
  dxNumericWheelPicker, dxDateTimeWheelPicker, cxTextEdit, cxMaskEdit,
  cxDropDownEdit, cxImageComboBox, cxLabel, cxGroupBox, Vcl.ComCtrls, dxCore,
  cxDateUtils, cxCalendar, cxSpinEdit, cxTimeEdit, dxBevel;

type
  TfFormTask = class(TForm)
    GroupTime: TcxGroupBox;
    BtnOK: TcxButton;
    BtnExit: TcxButton;
    EditDate: TdxDateTimeWheelPicker;
    TrackDetail: TcxTrackBar;
    CheckLoop: TcxCheckBox;
    EditBase: TcxDateEdit;
    cxLabel4: TcxLabel;
    EditDelay: TcxTimeEdit;
    cxLabel5: TcxLabel;
    cxLabel6: TcxLabel;
    cxLabel7: TcxLabel;
    cxGroupBox1: TcxGroupBox;
    EditText: TcxMemo;
    cxLabel3: TcxLabel;
    cxLabel1: TcxLabel;
    cxLabel2: TcxLabel;
    EditID: TcxTextEdit;
    EditModal: TcxImageComboBox;
    dxBevel1: TdxBevel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TrackDetailPropertiesGetPositionHint(Sender: TObject; const
      APosition: Integer; var AHintText: string; var ACanShow, AIsHintMultiLine:
      Boolean);
    procedure BtnOKClick(Sender: TObject);
    procedure CheckLoopClick(Sender: TObject);
    procedure EditDatePropertiesEditValueChanged(Sender: TObject);
    procedure TrackDetailPropertiesChange(Sender: TObject);
  private
    { Private declarations }
    FTask: TEqualizerTask;
    {*�ƻ�����*}
    function ShowDateDesc(): string;
    {*��������*}
    function ApplyTask(const nLoad: Boolean): Boolean;
    {*��������*}
  public
    { Public declarations }
  end;

function AddTask(): Boolean;
//���ģ��

function EditTask(const nID: string): Boolean;
//�༭ģ��

procedure LoadTasks(const nList: TcxListView);
//����ģ��

implementation

{$R *.dfm}

uses
  ULibFun, UManagerGroup, UServiceTTS, USysConst;

//Date: 2025-01-03
//Desc: �������żƻ�
function AddTask(): Boolean;
begin
  with TfFormTask.Create(Application) do
  begin
    Caption := '�ƻ� - ����';
    FillChar(FTask, SizeOf(FTask), #0);
    FTask.FID := gMG.FSerialIDManager.RandomID(6);

    FTask.FDateFix := True;
    FTask.FDate := Now();
    FTask.FDateBase := FTask.FDate;
    FTask.FBaseNowDelay := EncodeTime(0, 0, 0, 0);
    ApplyTask(True);

    Result := ShowModal = mrOk;
    if Result then
      gEqualizer.AddTask(@FTask);
    Free;
  end;
end;

//Date: 2025-01-03
//Parm: �ƻ���ʶ
//Desc: �༭���żƻ�
function EditTask(const nID: string): Boolean;
begin
  with TfFormTask.Create(Application) do
  begin
    Caption := '�ƻ� - �༭';
    FTask := gEqualizer.FindTask(nID);
    if FTask.FID = '' then
      FTask.FID := gMG.FSerialIDManager.RandomID(6);
    //xxxxx

    ApplyTask(True);
    Result := ShowModal = mrOk;
    if Result then
      gEqualizer.AddTask(@FTask);
    Free;
  end;
end;

//Date: 2025-01-03
//Parm: �б�
//Desc: ���ؼƻ��嵥��nList
procedure LoadTasks(const nList: TcxListView);
var
  nIdx: Integer;
  nTask: PEqualizerTask;
begin
  nList.Items.BeginUpdate;
  try
    nList.Items.Clear;
    for nIdx := 0 to gEqualizer.Tasks.Count - 1 do
    begin
      nTask := gEqualizer.Tasks[nIdx];
      if not nTask.FEnabled then
        Continue;
      //invalid

      with nList.Items.Add do
      begin
        ImageIndex := cImg_Task;
        Caption := nTask.FID;
        SubItems.Add(gEqualizer.TaskDate2Desc(nTask));
        SubItems.Add(TStringHelper.StrIF(['����', 'ѭ��'], nTask.FType = etYear));
        SubItems.Add(nTask.FModal);
        SubItems.Add(nTask.FText);
      end;
    end;
  finally
    nList.Items.EndUpdate;
  end;
end;

//------------------------------------------------------------------------------
procedure TfFormTask.FormCreate(Sender: TObject);
var
  nIdx: Integer;
  nModal: PEqualizerModal;
begin
  EditModal.Properties.Items.Clear;
  for nIdx := 0 to gEqualizer.Modals.Count - 1 do
  begin
    nModal := gEqualizer.Modals[nIdx];
    with EditModal.Properties.Items.Add do
    begin
      Description := nModal.FID;
      ImageIndex := cImg_Modal;
      Value := nModal.FID;
    end;
  end;

  TApplicationHelper.LoadFormConfig(Self);
  //load ui
end;

procedure TfFormTask.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  TApplicationHelper.SaveFormConfig(Self);
end;

//Date: 2025-01-06
//Desc: ��ʾ��ǰ���õ�����
function TfFormTask.ShowDateDesc(): string;
begin
  Result := gEqualizer.TaskDate2Desc(@FTask);
  GroupTime.Caption := '����ʱ��: ' + Result;
end;

procedure TfFormTask.CheckLoopClick(Sender: TObject);
begin
  EditDelay.Enabled := CheckLoop.Checked;
  EditBase.Enabled := CheckLoop.Checked;
  FTask.FDateFix := not CheckLoop.Checked;

  if EditBase.Enabled and (EditBase.Text = '') and (not FTask.FBaseNow) then
    EditBase.Date := Now();
  ShowDateDesc();
end;

procedure TfFormTask.EditDatePropertiesEditValueChanged(Sender: TObject);
begin
  FTask.FDate := EditDate.DateTime;
  ShowDateDesc();
end;

procedure TfFormTask.TrackDetailPropertiesChange(Sender: TObject);
begin
  case TrackDetail.Position of
    1:
      EditDate.Properties.Wheels := [pwYear, pwMonth, pwDay, pwHour, pwMinute,
        pwSecond];
    2:
      EditDate.Properties.Wheels := [pwMonth, pwDay, pwHour, pwMinute, pwSecond];
    3:
      EditDate.Properties.Wheels := [pwDay, pwHour, pwMinute, pwSecond];
    4:
      EditDate.Properties.Wheels := [pwHour, pwMinute, pwSecond];
    5:
      EditDate.Properties.Wheels := [pwMinute, pwSecond];
    6:
      EditDate.Properties.Wheels := [pwSecond];
  end;

  FTask.FType := TTaskType(TrackDetail.Position - 1);
end;

procedure TfFormTask.TrackDetailPropertiesGetPositionHint(Sender: TObject; const
  APosition: Integer; var AHintText: string; var ACanShow, AIsHintMultiLine:
  Boolean);
begin
  AHintText := ShowDateDesc();
  ACanShow := AHintText <> '';
end;

//Date: 2025-01-06
//Parm: �Ƿ����
//Desc: ����FTask������,�������ô���FTask
function TfFormTask.ApplyTask(const nLoad: Boolean): Boolean;
var
  nIdx: Integer;
begin
  if nLoad then
  begin
    for nIdx := 0 to EditModal.Properties.Items.Count - 1 do
      if EditModal.Properties.Items[nIdx].Value = FTask.FModal then
      begin
        EditModal.ItemIndex := nIdx;
        Break;
      end;
    //set modal

    with FTask do
    begin
      EditID.Text := FID;
      EditText.Text := FText;
      EditDate.DateTime := FDate;

      EditBase.Date := FDateBase;
      EditDelay.Time := FBaseNowDelay;
      if FBaseNow then
        EditBase.Text := '';
      //ʹ�õ�ǰʱ��

      CheckLoop.Checked := not FDateFix;
      TrackDetail.Position := Ord(FType) + 1;
    end;

    Result := True;
    Exit;
  end;

  Result := False;
  with FTask do
  begin
    if EditModal.ItemIndex < 0 then
    begin
      TApplicationHelper.ShowMsg('��ѡ������ģ��', sHint);
      EditModal.DroppedDown := True;
      Exit;
    end;

    if CheckLoop.Checked and
      (EditBase.Text <> '') and (EditBase.Date < cDate_Invalid) then
    begin
      TApplicationHelper.ShowMsg('��С����: ' + TDateTimeHelper.Date2Str(cDate_Invalid),
          sHint);
      ActiveControl := EditBase;
      Exit;
    end;

    FEnabled := True;
    FID := EditID.Text;
    FText := EditText.Text;
    FModal := EditModal.EditText;

    FDate := EditDate.DateTime;
    FDateFix := not CheckLoop.Checked;
    FBaseNowDelay := EditDelay.Time;
    FBaseNow := EditBase.Text = '';

    if FBaseNow then
      FDateBase := Now()
    else
      FDateBase := EditBase.Date;
    Result := True;
  end;
end;

procedure TfFormTask.BtnOKClick(Sender: TObject);
begin
  if ApplyTask(False) then
    ModalResult := mrOk;
  //xxxxx
end;

end.

