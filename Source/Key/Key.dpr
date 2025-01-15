program Key;

uses
  Forms,
  UFormMain in 'UFormMain.pas' {fFormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfFormMain, fFormMain);
  Application.Run;
end.
