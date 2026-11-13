unit __formabout;

{$mode objfpc}{$H+}

interface

uses
  Forms, StdCtrls, ExtCtrls, Classes, Controls, Menus;

type
  TFormAbout = class(TForm)
    ButtonClose: TButton;
    Image: TImage;
    LabelLink: TLabel;
    LabelVersion: TLabel;
    LabelName: TLabel;
    LabelCoperight: TLabel;
    MenuItemCopy: TMenuItem;
    MenuItemOpen: TMenuItem;
    PopupMenuLink: TPopupMenu;

    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure LabelLinkMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure LabelLinkMouseEnter(Sender: TObject);
    procedure LabelLinkMouseLeave(Sender: TObject);
    procedure MenuItemCopyClick(Sender: TObject);
    procedure MenuItemOpenClick(Sender: TObject);

    protected
      procedure OpenLink;
      function Url: string;
  end;

implementation

{$R *.lfm}

uses
  LCLType, Graphics, Clipbrd, lclintf;

procedure TFormAbout.FormCreate(Sender: TObject);
var h: integer;
begin
  inherited;
  LabelName.Caption:=Application.Title;
  Icon.Assign(Application.Icon);
end;

procedure TFormAbout.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then Close;
end;

function TFormAbout.Url: string;
begin
  Result:='https://' + LabelLink.Caption + '/';
end;

procedure TFormAbout.OpenLink;
begin
  OpenURL(Url);
end;

procedure TFormAbout.LabelLinkMouseEnter(Sender: TObject);
begin
  TWinControl(Sender).Font.Color:=clHighlight;
end;

procedure TFormAbout.LabelLinkMouseLeave(Sender: TObject);
begin
  TWinControl(Sender).Font.Color:=clHotLight;
end;

procedure TFormAbout.LabelLinkMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then OpenLink;
end;

procedure TFormAbout.MenuItemOpenClick(Sender: TObject);
begin
  OpenLink;
end;

procedure TFormAbout.MenuItemCopyClick(Sender: TObject);
begin
  Clipboard.AsText:=Url;
end;

end.

