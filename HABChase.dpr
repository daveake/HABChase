program HABChase;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main in 'Main.pas' {frmMain},
  Sondehub in '..\HABRx\Sondehub.pas',
  Miscellaneous in '..\HABRx\Miscellaneous.pas',
  GPSSource in '..\HABRx\GPSSource.pas',
  Source in '..\HABRx\Source.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
