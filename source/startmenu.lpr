program startmenu;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, __main;

{$R *.res}

begin
  RequireDerivedFormResource:=true;
  Application.Scaled:=true;
  Application.Initialize;
  Run;
end.

