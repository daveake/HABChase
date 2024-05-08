unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Controls.Presentation, FMX.StdCtrls, System.IOUtils, System.DateUtils,
  System.Math, System.Sensors, System.Sensors.Components,
{$IFDEF ANDROID}
  Androidapi.JNIBridge, AndroidApi.JNI.Media,
  Androidapi.JNI.JavaTypes, Androidapi.JNI.GraphicsContentViewText, Androidapi.Helpers, Androidapi.JNI.Net,
//  FMX.Helpers.Android, FMX.Platform.Android, AndroidApi.Jni.App,
  AndroidAPI.jni.OS,
  System.Permissions,
{$ENDIF}
  Miscellaneous, Sondehub, GPSSource, FMX.Edit;

type
  TfrmMain = class(TForm)
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
    Rectangle3: TRectangle;
    lblTimeSinceUpload: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    lblResult: TLabel;
    tmrUpdate: TTimer;
    Rectangle4: TRectangle;
    Label1: TLabel;
    Label2: TLabel;
    Switch2: TSwitch;
    Rectangle5: TRectangle;
    Label3: TLabel;
    Label6: TLabel;
    Switch1: TSwitch;
    Label8: TLabel;
    pnlNewCallsign: TPanel;
    Button1: TButton;
    Edit1: TEdit;
    Button2: TButton;
    Label11: TLabel;
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrGPSTimer(Sender: TObject);
    procedure Switch1Click(Sender: TObject);
    procedure tmrUpdateTimer(Sender: TObject);
    procedure Switch2Click(Sender: TObject);
    procedure lblCallsignClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
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
    procedure EnableGPS;
  procedure EditMode(Mode: Boolean);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

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

procedure TfrmMain.Button1Click(Sender: TObject);
begin
    SetSettingString('CHASE', 'Callsign', Edit1.Text);

    lblCallsign.Text := GetSettingString('CHASE', 'Callsign', '');
    if lblCallsign.Text = '' then lblCallsign.Text := '(Not Set)';

    UpdateCarUploadSettings;
    EditMode(False);
end;

procedure TfrmMain.Button2Click(Sender: TObject);
begin
    EditMode(False);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
    INIFileName := TPath.Combine(DataFolder, 'HABChase.ini');

    InitialiseSettings;

    lblCallsign.Text := GetSettingString('CHASE', 'Callsign', '');
    if lblCallsign.Text = '' then lblCallsign.Text := '(Not Set)';

    Switch1.IsChecked := GetSettingBoolean('CHASE', 'Upload', False);
    Switch2.IsChecked := GetSettingBoolean('CHASE', 'Pro', False);
    EditMode(False);

    SondehubUploader := TSondehubThread.Create(SondehubStatusCallback);

    UpdateCarUploadSettings;

{$IFDEF MSWINDOWS}
    GPS := TGPSSource.Create(GPS_SOURCE, 'GPS', GPSCallback);
{$ENDIF}
{$IFDEF ANDROID}
    PermissionsService.RequestPermissions([JStringToString(TJManifest_permission.JavaClass.ACCESS_FINE_LOCATION)],
        procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray) begin
            if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then begin
                // activate or deactivate the location sensor }
                    EnableGPS;
                end else begin
                    // frmSources.SetGPSStatus('No GPS Permission');
                end;
            end);

{$ENDIF}
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
    CloseThread(GPS);
    CloseThread(SondehubUploader);

    WaitForThread(GPS);
    WaitForThread(SondehubUploader);

    GPS.Free;
    SondehubUploader.Free;

    CloseSettings;
end;

procedure TfrmMain.FormResize(Sender: TObject);
var
    i: Integer;
begin
    for i := 0 to ComponentCount-1 do begin
        if Components[i] is TLabel then begin
            TLabel(Components[i]).Font.Size := Min(Width,Height/2) * Max(1, TLabel(Components[i]).Tag) / 24;
        end;
    end;
end;

procedure TfrmMain.UpdateCarUploadSettings;
begin
    SondehubUploader.SetListener('HAB Chase', 'V1.0.0',
                                 GetSettingString('CHASE', 'Callsign', ''),
                                 True,
                                 GetSettingInteger('CHASE', 'Period', 15),
                                 GetSettingBoolean('CHASE', 'Upload', Switch1.IsChecked),
                                 GetSettingBoolean('CHASE', 'Pro', Switch2.IsChecked));
end;

procedure TfrmMain.SondehubStatusCallback(SourceID: Integer; Active, OK: Boolean; Status: String);
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

procedure TfrmMain.Switch1Click(Sender: TObject);
begin
    SetSettingBoolean('CHASE', 'Upload', Switch1.IsChecked);
    UpdateCarUploadSettings;
end;

procedure TfrmMain.Switch2Click(Sender: TObject);
begin
    SetSettingBoolean('CHASE', 'Pro', Switch2.IsChecked);
    UpdateCarUploadSettings;
end;

procedure TfrmMain.EnableGPS;
begin
    LocationSensor.Active := True;
    tmrGPS.Enabled := True;
end;

procedure TfrmMain.tmrGPSTimer(Sender: TObject);
var
    UTC: TDateTime;
begin
    UTC := TTimeZone.Local.ToUniversalTime(Now);

    NewGPSPosition(UTC, LocationSensor.Sensor.Latitude, LocationSensor.Sensor.Longitude, LocationSensor.Sensor.Altitude);
end;

procedure TfrmMain.tmrUpdateTimer(Sender: TObject);
begin
    if LastUploadAt > 0 then begin
        lblTimeSinceUpload.Text := FormatDateTime('nn:ss', Now-LastUploadAt);
    end else begin
        lblTimeSinceUpload.Text := '-';
    end;
end;

procedure TfrmMain.NewGPSPosition(Timestamp: TDateTime; Latitude, Longitude, Altitude: Double);
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

procedure TfrmMain.lblCallsignClick(Sender: TObject);
begin
    Edit1.Text := GetSettingString('CHASE', 'Callsign', lblCallsign.Text);

    EditMode(True);

    Edit1.SetFocus;
end;

procedure TfrmMain.EditMode(Mode: Boolean);
begin
    pnlNewCallsign.Visible := Mode;
end;

{$IFDEF MSWINDOWS}
procedure TfrmMain.GPSCallback(ID: Integer; Connected: Boolean; Line: String; Position: THABPosition);
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
