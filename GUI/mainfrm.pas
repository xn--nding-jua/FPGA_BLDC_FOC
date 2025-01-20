unit mainfrm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, XPMan, ExtCtrls, CPDrv, Math, uMultimediaTimer,
  SVATimer;

const
  fractionBits = 16;
  polepairs = 4;

type
  Tmainform = class(TForm)
    XPManifest1: TXPManifest;
    Timer1: TTimer;
    comport: TCommPortDriver;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel4: TPanel;
    GroupBox4: TGroupBox;
    Label34: TLabel;
    comport_dropdown: TComboBox;
    baudrate_dropdown: TComboBox;
    disconnectbtn: TButton;
    connectbtn: TButton;
    GroupBox3: TGroupBox;
    GroupBox1: TGroupBox;
    val1: TLabel;
    val2: TLabel;
    val3: TLabel;
    val4: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    GroupBox2: TGroupBox;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Edit6: TEdit;
    Button2: TButton;
    Edit8: TEdit;
    Edit7: TEdit;
    Edit9: TEdit;
    Edit10: TEdit;
    Button3: TButton;
    PaintBox1: TPaintBox;
    Panel3: TPanel;
    Label18: TLabel;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Label3: TLabel;
    Label17: TLabel;
    GroupBox5: TGroupBox;
    Label1: TLabel;
    Edit1: TEdit;
    Label2: TLabel;
    Edit2: TEdit;
    Button1: TButton;
    Label19: TLabel;
    triggersource: TEdit;
    Label20: TLabel;
    thresholdedit: TEdit;
    Label21: TLabel;
    Shape1: TShape;
    freeRunning: TRadioButton;
    RadioButton2: TRadioButton;
    scale_ch1: TEdit;
    scale_ch2: TEdit;
    scale_ch3: TEdit;
    scale_ch4: TEdit;
    Label22: TLabel;
    Label23: TLabel;
    Label24: TLabel;
    Label25: TLabel;
    Shape2: TShape;
    Label26: TLabel;
    MsgCounter: TTimer;
    Label27: TLabel;
    Shape3: TShape;
    DrawTimer: TSVATimer;
    procedure Timer1Timer(Sender: TObject);
    procedure connectbtnClick(Sender: TObject);
    procedure disconnectbtnClick(Sender: TObject);
    procedure comportReceiveData(Sender: TObject; DataPtr: Pointer;
      DataSize: Cardinal);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Edit2KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit1KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit4KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit3KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit5KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit6KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit7KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit8KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Button7MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure DrawTimerTimer(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure MsgCounterTimer(Sender: TObject);
  private
    { Private declarations }
    FirstStart:boolean;
    flag_StartComplete: boolean;
    controlBit_openLoop, controlBit_position, controlBit_reset: boolean;
    bitmap: TBitmap;
    waitForTrigger : boolean;
    lastValueForTrigger : single;
    MessageCounter, BadMessageCounter : integer;
    MsgPerSecond : integer;

    valueCounter: integer;
    values:array of single;
    valuesHistory: array of array of single;
    valuesMeanBuffer:array of array[0..99] of single;
    valuesMeanCounter:integer;
    valuesMean:array of single;

    procedure ProceedRS232Input_Integer(s:string);
    function minmax(value, min, max: single):single;
  public
    { Public declarations }
    ReceivedRS232Data:string;
    fs:TFormatSettings;

    procedure CollectRS232Data;
    procedure SendValuesToTarget_Integer(Command: Byte; Value:Integer);
    procedure SendControlBits;
  end;

var
  mainform: Tmainform;

implementation

{$R *.dfm}

procedure Tmainform.Timer1Timer(Sender: TObject);
var
  i:integer;
begin
  if not flag_StartComplete then
  begin
    comport_dropdown.itemindex := 0; {set to COM1}
    baudrate_dropdown.itemindex := 8; {set to 3000000}
    MsgPerSecond := 250;

    controlBit_openLoop := true;
    controlBit_position := false;
    controlBit_reset := false;

    bitmap.Width := paintbox1.Width;
    bitmap.Height := paintbox1.Height;
    setlength(values, 4);
    setlength(valuesHistory, length(values));
    setlength(valuesMeanBuffer, length(valuesHistory));
    setlength(valuesMean, length(valuesHistory));
    for i:=0 to length(values)-1 do
    begin
      setlength(valuesHistory[i], paintbox1.Width);
    end;
    valueCounter:=0;
    DrawTimer.Enabled := true;

    flag_StartComplete := true;
  end;

  // show values in GUI
  val1.Caption := floattostrf(valuesMean[0]*60 / (2*PI*polepairs), ffFixed, 15, 2) + ' rpm';
  val2.Caption := floattostrf(valuesMean[1]*60 / (2*PI*polepairs), ffFixed, 15, 2) + ' rpm';
  val3.Caption := floattostrf(valuesMean[2], ffFixed, 15, 2) ;
  val4.Caption := floattostrf(valuesMean[3], ffFixed, 15, 2) ;
end;

procedure Tmainform.connectbtnClick(Sender: TObject);
begin
  comport.port := pnCustom;
  comport.portname := 'COM' + inttostr(comport_dropdown.itemindex + 1);
  case baudrate_dropdown.itemindex of
    0: comport.baudrate := br9600;
    1: comport.baudrate := br19200;
    2: comport.baudrate := br38400;
    3: comport.baudrate := br57600;
    4: comport.baudrate := br115200; // is working with all USB-2-Serial-Adapters
    5: comport.baudrate := br256000; // official supported by TCommPort32 and working with FPGA
    6:
    begin
      comport.baudrate := brCustom;
      comport.BaudRateValue := 921600; // maximum Baudrate, Windows is aware of
    end;
    7:
    begin
      comport.BaudRate := brCustom;
      comport.BaudRateValue := 1500000;
    end;
    8:
    begin
      comport.BaudRate := brCustom;
      comport.BaudRateValue := 3000000; // maximum baudrate (3 MBit/s) an FTDI adapter can handle
    end;
  end;

  if comport.Connect then
  begin
    connectbtn.enabled:=false;
    disconnectbtn.enabled:=true;
    comport_dropdown.enabled:=false;
  end else
  begin
    connectbtn.enabled:=true;
    disconnectbtn.enabled:=false;
    comport_dropdown.enabled:=true;
  end;

  MsgCounter.Enabled:=comport.Connected;
end;

procedure Tmainform.disconnectbtnClick(Sender: TObject);
begin
  comport.disconnect;
  connectbtn.enabled:=true;
  disconnectbtn.enabled:=false;
  comport_dropdown.enabled:=true;
  MsgCounter.Enabled:=false;
  label27.Caption := '... MSG/s (0 Errors)';
end;

procedure Tmainform.comportReceiveData(Sender: TObject; DataPtr: Pointer;
  DataSize: Cardinal);
var
  s: string;
begin
  // Convert incoming data into a string
  try
    s := StringOfChar( ' ', DataSize );
    move( DataPtr^, pchar(s)^, DataSize );

    ReceivedRS232Data:=ReceivedRS232Data+s;
    CollectRS232Data;
  except
  end;

{
  // Remove line feeds from the string
  i := pos( #10, s );
  while i <> 0 do
  begin
    delete( s, i, 1 );
    i := pos( #10, s );
  end;
  // Remove carriage returns from the string (break lines)
  i := pos( #13, s );
  while i <> 0 do
  begin
    delete( s, i, 1 );
    i := pos( #13, s );
  end;
}
end;

procedure Tmainform.CollectRS232Data;
var
  NewCommand:string;
begin
  // we are receiving:
  // AbbbbbbbccE

  while ((length(ReceivedRS232Data)>=20) and (pos('A', ReceivedRS232Data)>0) and (pos('E', ReceivedRS232Data)>0)) do
  begin
    // Anfang suchen
    while ((length(ReceivedRS232Data)>=20) and (ReceivedRS232Data[1]<>'A')) do
    begin
      // remove unexpected first character
      ReceivedRS232Data:=copy(ReceivedRS232Data, 2, length(ReceivedRS232Data)-1);
      BadMessageCounter := BadMessageCounter + 1;
    end;

    if (length(ReceivedRS232Data)>=20) and (ReceivedRS232Data[1]='A') and (ReceivedRS232Data[20]<>'E') then
    begin
      // correct begin, but wrong end of message -> remove first character
      ReceivedRS232Data:=copy(ReceivedRS232Data, 2, length(ReceivedRS232Data)-1);
      BadMessageCounter := BadMessageCounter + 1;
    end;

    if (length(ReceivedRS232Data)>=20) and (ReceivedRS232Data[1]='A') and (ReceivedRS232Data[20]='E') then
    begin
      // found valid message structure
      NewCommand:=copy(ReceivedRS232Data, 1, 20);
      ReceivedRS232Data:=copy(ReceivedRS232Data, 21, length(ReceivedRS232Data)-20);

      ProceedRS232Input_Integer(NewCommand);
    end;
  end;
end;

procedure Tmainform.ProceedRS232Input_Integer(s:string);
var
  bytes: array[0..17] of byte;
  PayloadSum, PayloadSumReceived : Word;
  //si:SmallInt;
  i,j:integer;
  c:Cardinal;
  threshold:single;
begin
  try
    if (length(s)<20) or (s[1]<>'A') or (s[20]<>'E') then
    begin
      BadMessageCounter := BadMessageCounter + 1;
      exit;
    end;
    {
      1 = A
      2...5 = value1
      6...9 = value2
      10...13 = value3
      14...17 = value4
      18 = MSB Payload-Sum
      19 = LSB Payload-Sum
      20 = E
    }
    // Convert Chars to Byte-Array
    for i:=2 to 19 do // everything between A and E
    begin
      bytes[i-2]:=Integer(s[i]);
    end;

    // Typecast Byte-Array to 16-bit Word
    PayloadSumReceived := (bytes[16] shl 8) + bytes[17];
    //PayloadSum := bytes[0] + bytes[1] + bytes[2] + bytes[3] + bytes[4] + bytes[5] + bytes[6];
    PayloadSum := 0; // not used at the moment

    if (PayloadSumReceived = PayloadSum) then
    begin
      MessageCounter := MessageCounter + 1;

      // individual values

{
      // Receiving 16-bit value, so first we have to cast two bytes as SmallInt
      si := PSmallInt(@bytes[0])^;
      val1.Caption := 'Omega = ' + floattostrf(si/(power(2, 5) * 2 * PI), ffFixed, 15, 5) + ' Hz'; // convert Q10.5 into float
}

{
      // receiving 32-bit value
      c := (bytes[2] shl 24) + (bytes[3] shl 16) + (bytes[4] shl 8) + bytes[5];
      move(c, i, 4);
      val_int.Caption := floattostrf(i/(power(2, 16)), ffFixed, 15, 2) + ' | f = '+ floattostrf(i/(power(2, 16)*2*PI), ffFixed, 15, 2) + ' Hz';
      val7.Caption := 'v' + floattostrf(bytes[6]/100, ffFixed, 15, 2, fs); // version
}

      // copy values into temporary storage
      for i:=0 to length(valuesHistory)-1 do
      begin
        c := (bytes[i*4] shl 24) + (bytes[i*4+1] shl 16) + (bytes[i*4+2] shl 8) + bytes[i*4+3];
        move(c, j, 4);
        values[i] := j/power(2, fractionBits);
      end;

      // check if waiting for trigger
      if waitForTrigger then
      begin
        try
          i:=strtoint(triggersource.text)-1;
          threshold := strtofloat(thresholdedit.text);
        except
          i:=0;
          threshold:=0;
        end;

        if (values[i] >= threshold) and (lastValueForTrigger < threshold) then
        begin
          waitForTrigger := false;
          valueCounter := 0;
        end;

        // store current value in the last row
        lastValueForTrigger := values[i];
      end;

      // copy value into ringbuffer
      if valueCounter<length(valuesHistory[0]) then
      begin
        for i:=0 to length(valuesHistory)-1 do
        begin
            valuesHistory[i][valueCounter] := values[i];
        end;
      end;

      // increment ringbuffer-counter
      valueCounter := valueCounter + 1;
      if valueCounter >= paintbox1.Width then
      begin
        if freeRunning.Checked then
          valueCounter := 0
        else
          waitForTrigger := true;
      end;


      for i:=0 to length(valuesHistory)-1 do
      begin
        valuesMeanBuffer[i][valuesMeanCounter] := values[i];
      end;
      valuesMeanCounter := valuesMeanCounter + 1;
      if valuesMeanCounter > (length(valuesMeanBuffer[0])-1) then
      begin
        valuesMeanCounter := 0;
      end;

      for i:=0 to length(valuesHistory)-1 do
      begin
        valuesMean[i] := 0;
        for j:=0 to length(valuesMeanBuffer[i])-1 do
        begin
          valuesMean[i] := valuesMean[i] + valuesMeanBuffer[i][j];
        end;
        valuesMean[i] := valuesMean[i] / length(valuesMeanBuffer[i]);
      end;
    end else
    begin
      BadMessageCounter := BadMessageCounter + 1;
    end;

    // Typecast Byte-Array to Integer
    //Value:=bytes[0] + (bytes[1] shl 8) + (bytes[2] shl 16) + (bytes[3] shl 24);
    //Value:=PInteger(@bytes[0])^;

    // Convert byte Array to Longword
    //IntValue:=bytes[0] + (bytes[1] shl 8) + (bytes[2] shl 16) + (bytes[3] shl 24);
  except
    BadMessageCounter := BadMessageCounter + 1;

  end;
end;

function Tmainform.minmax(value, min, max: single):single;
begin
  if value > max then
    result := max
  else if value < min then
    result := min
  else
    result := value;
end;

procedure Tmainform.SendValuesToTarget_Integer(Command: Byte; Value: Integer);
var
  bytes:array[0..11] of byte;
  //Rs232Message:string;
  PayloadSum : Word;
begin
  // int32 in Byte-Array wandeln
  bytes[0] := 65; // A

  bytes[1] := Command;
  bytes[2] := (PCardinal(@value)^ shr 24) and $FF;
  bytes[3] := (PCardinal(@value)^ shr 16) and $FF;
  bytes[4] := (PCardinal(@value)^ shr 8) and $FF;
  bytes[5] := PCardinal(@value)^ and $FF;
  bytes[6] := 0;
  bytes[7] := 0;

  PayloadSum := bytes[2] + bytes[3] + bytes[4] + bytes[5] + bytes[6] + bytes[7];
  bytes[8] := (PayloadSum shr 8) and $FF; // MSB
  bytes[9] := PayloadSum and $FF; // LSB
  bytes[10] := 69; // E

  //Rs232Message:='A'+char(Command)+char(bytes[0])+char(bytes[1])+char(bytes[2])+char(bytes[3])+char(ErrorCheckByte)+'E';
  //comport.SendString(Rs232Message);
  comport.SendData(@bytes[0], 12);
end;

procedure Tmainform.SendControlBits;
var
  value: Cardinal;
begin
  value := 0;

  if controlBit_openLoop then
    value := value or $01;

  if controlBit_position then
    value := value or $02;
{
  if controlBit_xxx then
    value := value or $04;

  if controlBit_xxx then
    value := value or $08;

  if controlBit_xxx then
    value := value or $10;

  if controlBit_xxx then
    value := value or $20;

  if controlBit_xxx then
    value := value or $40;
}
  if controlBit_reset then
    value := value or $80;

  SendValuesToTarget_Integer(11, value);
end;

procedure Tmainform.FormCreate(Sender: TObject);
begin
  fs.DecimalSeparator:='.';
  firststart:=true;
  bitmap := TBitmap.Create;
end;

procedure Tmainform.FormShow(Sender: TObject);
begin
  if firststart then
  begin
    firststart:=false;
  end;
end;

procedure Tmainform.Button1Click(Sender: TObject);
begin
  // convert float-values to Q15.16 and send it to FPGA
  SendValuesToTarget_Integer(0, round(strtofloat(stringreplace(edit1.Text, ',', '.', []), fs) * power(2, fractionBits)));
  SendValuesToTarget_Integer(1, round(strtofloat(stringreplace(edit2.Text, ',', '.', []), fs) * power(2, fractionBits)));
end;

procedure Tmainform.Button2Click(Sender: TObject);
begin
  // convert float-values to Q15.16 and send it to FPGA
  SendValuesToTarget_Integer(3, round(strtofloat(stringreplace(edit3.Text, ',', '.', []), fs) * (2*PI/360) * power(2, fractionBits)));
  SendValuesToTarget_Integer(4, round(((strtofloat(stringreplace(edit4.Text, ',', '.', []), fs)/60)*2*PI*polepairs) * power(2, fractionBits))); // speed-controller takes values in omega. So convert rpm to Hz and then in omega
end;

procedure Tmainform.Edit2KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  value:single;
begin
  if Key = vk_return then
  begin
    Button1Click(nil);
  end;
  if Key = vk_up then
  begin
    value:=strtofloat(stringreplace(edit2.Text, ',', '.', []), fs);
    Edit2.text:=floattostrf(value + 1, ffFixed, 15, 1);
    Button1Click(nil);
  end;
  if Key = vk_down then
  begin
    value:=strtofloat(stringreplace(edit2.Text, ',', '.', []), fs);
    Edit2.text:=floattostrf(value - 1, ffFixed, 15, 1);
    Button1Click(nil);
  end;
end;

procedure Tmainform.Edit1KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button1Click(nil);
  end;
end;

procedure Tmainform.Edit4KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button2Click(nil);
  end;
end;

procedure Tmainform.Edit3KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button2Click(nil);
  end;
end;

procedure Tmainform.Edit5KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button3Click(nil);
  end;
end;

procedure Tmainform.Edit6KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button3Click(nil);
  end;
end;

procedure Tmainform.Edit7KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button3Click(nil);
  end;
end;

procedure Tmainform.Edit8KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = vk_return then
  begin
    Button3Click(nil);
  end;
end;

procedure Tmainform.Button5Click(Sender: TObject);
begin
  controlBit_openLoop := true;
  SendControlBits;
end;

procedure Tmainform.Button6Click(Sender: TObject);
begin
  controlBit_openLoop:=false;
  SendControlBits;
end;

procedure Tmainform.Button7MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  controlBit_reset:=true;
  SendControlBits;
end;

procedure Tmainform.Button7MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  controlBit_reset:=false;
  SendControlBits;
end;

procedure Tmainform.Button8Click(Sender: TObject);
begin
  controlBit_position := true;
  SendControlBits;
end;

procedure Tmainform.Button9Click(Sender: TObject);
begin
  controlBit_position := false;
  SendControlBits;
end;

procedure Tmainform.Button3Click(Sender: TObject);
begin
  // convert float-values to Q10.21 and send it to FPGA
  SendValuesToTarget_Integer(5, round(strtofloat(stringreplace(edit9.Text, ',', '.', []), fs) * power(2, 21))); // kp and ki are in Q10.21 format
  SendValuesToTarget_Integer(6, round(strtofloat(stringreplace(edit10.Text, ',', '.', []), fs) * power(2, 21))); // kp and ki are in Q10.21 format
  SendValuesToTarget_Integer(7, round(strtofloat(stringreplace(edit5.Text, ',', '.', []), fs) * power(2, 21))); // kp and ki are in Q10.21 format
  SendValuesToTarget_Integer(8, round(strtofloat(stringreplace(edit6.Text, ',', '.', []), fs) * power(2, 21))); // kp and ki are in Q10.21 format
  SendValuesToTarget_Integer(9, round(strtofloat(stringreplace(edit7.Text, ',', '.', []), fs) * power(2, 21))); // kp and ki are in Q10.21 format
  SendValuesToTarget_Integer(10, round(strtofloat(stringreplace(edit8.Text, ',', '.', []), fs) * power(2, 21))); // kp and ki are in Q10.21 format
end;

procedure Tmainform.DrawTimerTimer(Sender: TObject);
var
  i,j:integer;
  scaling:array[0..4] of single;
begin
  if bitmap.Width < 10 then
    exit;

  if DrawTimer.Interval < 50 then
    DrawTimer.Interval := 50;

  bitmap.Canvas.Brush.Color := clBlack;
  bitmap.Canvas.Brush.Style := bsSolid;
  bitmap.Canvas.Pen.Color := clBlack;

  bitmap.Canvas.Rectangle(0, 0, bitmap.Width, bitmap.Height);
  bitmap.Canvas.Pen.Color := clGray;

  // draw axis
  bitmap.Canvas.Pen.Width := 1;
  for i:=0 to 3 do
  begin
    bitmap.Canvas.MoveTo(0, round((paintbox1.Height/4) / 2 + (paintbox1.Height/4)*i));
    bitmap.Canvas.LineTo(paintbox1.Width, round((paintbox1.Height/4) / 2 + (paintbox1.Height/4)*i));
  end;

  bitmap.Canvas.Pen.Style := psDot;
  for i:=0 to 3 do
  begin
    bitmap.Canvas.MoveTo(0, round(((paintbox1.Height/4) / 4) + (paintbox1.Height/4)*i));
    bitmap.Canvas.LineTo(paintbox1.Width, round(((paintbox1.Height/4) / 4) + (paintbox1.Height/4)*i));
    bitmap.Canvas.MoveTo(0, round(((-paintbox1.Height/4) / 4) + (paintbox1.Height/4)*i));
    bitmap.Canvas.LineTo(paintbox1.Width, round(((-paintbox1.Height/4) / 4) + (paintbox1.Height/4)*i));
  end;
  bitmap.Canvas.Pen.Style := psSolid;

  // draw time information
  bitmap.Canvas.Font.Color := clGray;
  bitmap.Canvas.Font.Style := [fsBold];
  for i:=0 to paintbox1.Width div 100 do
  begin
    for j:=0 to 3 do
    begin
      // we are receiving with x MSG/s. So every 250 pixel is 1 Second
      if (MsgPerSecond<20) then
        bitmap.Canvas.TextOut(i*200, round((paintbox1.Height/4)*j + (paintbox1.Height/4)/2+3), inttostr(i)+'s')
      else
        bitmap.Canvas.TextOut(i*MsgPerSecond, round((paintbox1.Height/4)*j + (paintbox1.Height/4)/2+3), inttostr(i)+'s');
    end;
  end;

  // draw values
  bitmap.Canvas.Pen.Width := 2;
  for i:=0 to 3 do
  begin
    case i of
      0: bitmap.Canvas.Pen.Color := clLime;
      1: bitmap.Canvas.Pen.Color := clRed;
      2: bitmap.Canvas.Pen.Color := clAqua;
      3: bitmap.Canvas.Pen.Color := clYellow;
    end;

    try
      scaling[0] := strtofloat(scale_ch1.Text);
      scaling[1] := strtofloat(scale_ch2.Text);
      scaling[2] := strtofloat(scale_ch3.Text);
      scaling[3] := strtofloat(scale_ch4.Text);
    except
      scaling[0] := 1;
      scaling[1] := 1;
      scaling[2] := 1;
      scaling[3] := 1;
    end;

    bitmap.Canvas.MoveTo(0, round(((paintbox1.Height/4) / 2 + (paintbox1.Height/4)*i) + ((paintbox1.Height/4) / 2) * minmax(-valuesHistory[i][0] * scaling[i], -1, 1)));
    for j:=1 to paintbox1.Width-1 do
    begin
      bitmap.Canvas.LineTo(j, round(((paintbox1.Height/4) / 2 + (paintbox1.Height/4)*i) + ((paintbox1.Height/4) / 2) * minmax(-valuesHistory[i][j] * scaling[i], -1, 1)));
    end;
  end;

  bitmap.Canvas.Pen.Color := clGray;
  bitmap.Canvas.MoveTo(valueCounter, 0);
  bitmap.Canvas.LineTo(valueCounter, paintbox1.Height);

  BitBlt(Paintbox1.Canvas.Handle, 0, 0, Paintbox1.Width, Paintbox1.Height, bitmap.Canvas.Handle, 0, 0, SrcCopy);
end;

procedure Tmainform.FormResize(Sender: TObject);
var
  i:integer;
begin
  if (paintbox1.Width < bitmap.Width) and (valueCounter > (bitmap.Width-20)) then
    valueCounter:=0;

  bitmap.Width := paintbox1.Width;
  bitmap.Height := paintbox1.Height;
  for i:=0 to length(values)-1 do
  begin
    setlength(valuesHistory[i], paintbox1.Width);
  end;
end;

procedure Tmainform.PaintBox1Paint(Sender: TObject);
begin
  DrawTimer.Interval := 10;

  BitBlt(paintbox1.Canvas.Handle, 0, 0, paintbox1.Width, paintbox1.Height, bitmap.Canvas.Handle, 0, 0, SrcCopy);
end;

procedure Tmainform.MsgCounterTimer(Sender: TObject);
begin
  label27.Caption := floattostrf(MessageCounter/10, ffFixed, 15, 1) + ' MSG/s (' + inttostr(BadMessageCounter) + ' Errors)';
  MsgPerSecond := MessageCounter div 10;

  MessageCounter := 0;
  BadMessageCounter := 0;
end;

end.
