program MyriadTTS;

uses
  FastMM4,
  Winapi.Windows,
  Vcl.Forms,
  UFormMain in 'UFormMain.pas' {fFormMain},
  UDataModule in 'UDataModule.pas' {FDM: TDataModule},
  UEqualizer in 'Common\UEqualizer.pas',
  UServiceTTS in 'Common\UServiceTTS.pas',
  USysConst in 'Common\USysConst.pas',
  UFormModal in 'UFormModal.pas' {fFormModal};

{$R *.res}
var
  gMutexHwnd: Hwnd;
  //互斥句柄

begin
  //singleton
  gMutexHwnd := CreateMutex(nil, True, 'RunSoft_Myriad_Voices');
  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    ReleaseMutex(gMutexHwnd);
    CloseHandle(gMutexHwnd); Exit;
  end; //已有一个实例

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFDM, FDM);
  Application.CreateForm(TfFormMain, fFormMain);
  Application.Run;

  ReleaseMutex(gMutexHwnd);
  CloseHandle(gMutexHwnd);
end.
