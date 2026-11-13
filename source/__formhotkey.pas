unit __formhotkey;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, StdCtrls, Buttons, Controls;

type
  TFormHotkey = class(TForm)
    ButtonClose: TButton;
    ButtonCopy: TButton;
    LabelOK: TLabel;
    LabelHotkey: TLabel;
    StaticText: TStaticText;
    procedure ButtonCopyClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

  protected type

    TThreadClearOK = class(TThread)
    protected
      FForm: TFormHotkey;
      procedure Execute; override;
    public
      constructor Create(AForm: TFormHotkey);
    end;

  end;

implementation

{$R *.lfm}

uses
  __main,
  LCLType, LCLProc, Clipbrd;



procedure TFormHotkey.TThreadClearOK.Execute;
begin
  Sleep(1000);
  FForm.LabelOK.Caption:='';
end;

constructor TFormHotkey.TThreadClearOK.Create(AForm: TFormHotkey);
begin
  FreeOnTerminate:=true;
  FForm:=AForm;
  inherited Create(false);
end;



procedure TFormHotkey.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then Close
  else begin
    LabelHotkey.Caption:=HotkeyNormalize(KeyAndShiftStateToKeyString(Key, Shift));
    ButtonCopy.Enabled:=true;
  end;
end;

procedure TFormHotkey.ButtonCopyClick(Sender: TObject);
begin
  Clipboard.AsText:=LabelHotkey.Caption;
  LabelOK.Caption:='OK';
  ButtonClose.SetFocus;
  TThreadClearOK.Create(self);
end;

procedure TFormHotkey.FormCreate(Sender: TObject);
begin
  inherited;
  Icon.Assign(Application.Icon);
end;


end.

