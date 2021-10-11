program FTP_Lister;

uses
  Forms,
  Fenetre_Principale in 'Fenetre_Principale.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
