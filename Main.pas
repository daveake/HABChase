unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Controls.Presentation, FMX.StdCtrls, System.IOUtils, System.DateUtils,
  System.Math, System.Sensors, System.Sensors.Components,
  Miscellaneous, Sondehub, GPSSource;

type
  TForm1 = class(TForm)
    lblTitle: TLabel;
    Image1: TImage;
    tmrGPS: TTimer;
    LocationSensor: TLocationSensor;
    Rectangle1: TRectangle;
    lblLatitude: TLabel;
    lblAltitude: TLabel;
    lblLongitude: TLabel;
    Rectangle2: TRectangle;
    lblCallsign: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label7: TLabel;
    Switch1: TSwitch;
    Rectangle3: TRectangle;
    lblTimeSinceUpload: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    lblResult: TLabel;
    tmrUpdate: TTimer;
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrGPSTimer(Sender: TObject);
    procedure Switch1Click(Sender: TObject);
    procedure tmrUpdateTimer(Sender: TObject);
  private
    { Private declarations }
    LastUploadAt: TDateTime;
    SondehubUploader: TSondehubThread;
    GPS: TGPSSource;
{$IFDEF MSWINDOWS}
    procedure GPSCallback(ID: Integer; Connected: Boolean; Line: String; Position: THABPosition);
{$ENDIF}
    procedure SondehubStatusCallback(SourceID: Integer; Active, OK: Boolean; Status: String);
    procedure UpdateCarUploadSettings;
    procedure NewGPSPosition(Timestamp: TDateTime; Latitude, Longitude, Altitude: Double);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure CloseThread(Thread: TThread);
begin
    if Thread <> nil then begin
        Thread.Terminate;
    end;
end;


procedure WaitForThread(Thread: TThread);
begin
    if Thread <> nil then begin
        Thread.WaitFor;
    end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
    INIFileName := TPath.Combine(DataFolder, 'HABChase.ini');

    InitialiseSettings;

    Switch1.IsChecked := GetSettingBoolean('CHASE', 'Upload', False);

    SondehubUploader := TSondehubThread.Create(SondehubStatusCallback);

    UpdateCarUploadSettings;

{$IFDEF MSWINDOWS}
    GPS := TGPSSource.Create(GPS_SOURCE, 'GPS', GPSCallback);
{$ENDIF}
{$IFDEF ANDROID}
    frmSources.SetGPSStatus('Requesting GPS Permission');

    PermissionsService.RequestPermissions([JStringToString(TJManifest_permission.JavaClass.ACCESS_FINE_LOCATION)],
        procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray) begin
            if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then begin
                // activate or deactivate the location sensor }
                    frmSources.EnableGPS;
                end else begin
                    frmSources.SetGPSStatus('No GPS Permission');
                end;
            end);

{$ENDIF}
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
    CloseThread(GPS);
    CloseThread(SondehubUploader);

    WaitForThread(GPS);
    WaitForThread(SondehubUploader);

    GPS.Free;
    SondehubUploader.Free;

    CloseSettings;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
    lblTitle.Font.Size := Width / 12;
end;

procedure TForm1.UpdateCarUploadSettings;
begin
    SondehubUploader.SetListener('HAB Chase', 'V1.0.0',
                                 GetSettingString('CHASE', 'Callsign', lblCallsign.Text),
                                 True,
                                 GetSettingInteger('CHASE', 'Period', 15),
                                 GetSettingBoolean('CHASE', 'Upload', Switch1.IsChecked));
end;

procedure TForm1.SondehubStatusCallback(SourceID: Integer; Active, OK: Boolean; Status: String);
begin
    if OK then begin
        LastUploadAt := Now;
        tmrUpdateTimer(nil);
        lblResult.Text := 'OK';
    end else begin
        lblResult.Text := 'FAILED';
    end;

//    frmMain.SondehubUploadStatus(Active, OK);
//    frmUploaders.WriteSondehubStatus(Status);
end;

procedure TForm1.Switch1Click(Sender: TObject);
begin
    SetSettingBoolean('CHASE', 'Upload', Switch1.IsChecked);
    UpdateCarUploadSettings;
end;

procedure TForm1.tmrGPSTimer(Sender: TObject);
var
    UTC: TDateTime;
begin
    UTC := TTimeZone.Local.ToUniversalTime(Now);

    NewGPSPosition(UTC, LocationSensor.Sensor.Latitude, LocationSensor.Sensor.Longitude, LocationSensor.Sensor.Altitude);
end;

procedure TForm1.tmrUpdateTimer(Sender: TObject);
begin
    if LastUploadAt > 0 then begin
        lblTimeSinceUpload.Text := FormatDateTime('nn:ss', Now-LastUploadAt);
    end else begin
        lblTimeSinceUpload.Text := '-';
    end;
end;

procedure TForm1.NewGPSPosition(Timestamp: TDateTime; Latitude, Longitude, Altitude: Double);
begin
    if not IsNan(Latitude) then begin
        lblLatitude.Text := MyFormatFloat('0.00000', Latitude);
        lblLongitude.Text := MyFormatFloat('0.00000', Longitude);
        lblAltitude.Text := MyFormatFloat('0', Altitude) + ' m';

        if SondehubUploader <> nil then begin
            SondehubUploader.SetListenerPosition(Latitude, Longitude, Altitude);
        end;
    end;
end;

{$IFDEF MSWINDOWS}
procedure TForm1.GPSCallback(ID: Integer; Connected: Boolean; Line: String; Position: THABPosition);
const
    Offset: Double = 0;
begin
    if Position.InUse then begin
        NewGPSPosition(Position.TimeStamp, Position.Latitude, Position.Longitude, Position.Altitude);
    end else begin
        // Sources[GPS_SOURCE].Form.lblValue.Text := Line;
    end;
end;
{$ENDIF}

end.
