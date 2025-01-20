program BLDC_FOC;

uses
  Forms,
  mainfrm in 'mainfrm.pas' {mainform};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'FPGA BLDC FOC';
  Application.CreateForm(Tmainform, mainform);
  Application.Run;
end.
