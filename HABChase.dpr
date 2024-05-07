program HABChase;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main in 'Main.pas' {Form1},
  Sondehub in '..\HABRx\Sondehub.pas',
  Miscellaneous in '..\HABRx\Miscellaneous.pas',
  GPSSource in '..\HABRx\GPSSource.pas',
  Source in '..\HABRx\Source.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
