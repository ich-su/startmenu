unit __formmain;

{$mode objfpc}{$H+}

interface

uses
  __programmenu,
  Classes, Forms, Controls, ExtCtrls, Menus, ActnList, Grids, StdCtrls, Windows;

const
  WM_USER_SHOWMENU = WM_USER + 700;

type
  TFormMain = class(TForm)
    ActionOpenFolderTC: TAction;
    ActionHotkey: TAction;
    ActionAbout: TAction;
    ActionOpenFolder: TAction;
    ActionRunAdmin: TAction;
    ActionRun: TAction;
    ActionShowMenu: TAction;
    ActionClose: TAction;
    ActionList: TActionList;
    ImageList: TImageList;
    MenuItemGridLine1: TMenuItem;
    MenuItemGridOpenFolderTC: TMenuItem;
    MenuItemHotkey: TMenuItem;
    MenuItemTrayLine1: TMenuItem;
    MenuItemGridOpenFolder: TMenuItem;
    MenuItemGridLine: TMenuItem;
    MenuItemGridRun: TMenuItem;
    MenuItemRunGridAdmin: TMenuItem;
    MenuItemTrayLine2: TMenuItem;
    MenuItemTrayAbout: TMenuItem;
    MenuItemTrayClose: TMenuItem;
    MenuItemTrayShowMenu: TMenuItem;
    PopupMenuDataDef: TPopupMenu;
    PopupMenuData: TPopupMenu;
    PopupMenuTray: TPopupMenu;
    TrayIcon: TTrayIcon;

    procedure ActionAboutExecute(Sender: TObject);
    procedure ActionCloseExecute(Sender: TObject);
    procedure ActionOpenFolderExecute(Sender: TObject);
    procedure ActionOpenFolderTCExecute(Sender: TObject);
    procedure ActionRunExecute(Sender: TObject);
    procedure ActionHotkeyExecute(Sender: TObject);
    procedure ActionShowMenuExecute(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormPaint(Sender: TObject);
    procedure FormResize(Sender: TObject);

  protected
    FListProgramMenu: TListProgramMenu;
    FCanExit: boolean;

    procedure _WM_USER_SHOWMENU(var AMessage: tMessage); message WM_USER_SHOWMENU;
    procedure _WM_ACTIVATE(var Mess: TMessage); message WM_ACTIVATE;

    procedure LoadMenus;
    procedure SetMenus;
    procedure ShowMenu(AClosePopupMenu: boolean = true);

    function GetActiveMenuIndex: integer;
    function GetActiveMenu: TProgramMenu;

    procedure HideMenu;

    // procedure SetFilter(AFilter: string); // поиск
    // procedure ClearFilter(AFilter: string);

  public
    procedure Initialize;
    procedure NextMenu;
    procedure PrevMenu;
    procedure FirstData;
    procedure LastData;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

uses
  __main, __formabout, __formhotkey,
  SysUtils, Graphics, FGL, LCLType, LCLProc, Buttons;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  inherited;

  FCanExit:=false;
  FListProgramMenu:=TListProgramMenu.Create(true);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FListProgramMenu.Free;
  inherited;
end;

procedure TFormMain.Initialize;
begin
  Color:=Tuning.ColorBack;
  ActionOpenFolder.Enabled:=FileExists(Tuning.Explorer);
  ActionOpenFolderTC.Enabled:=FileExists(Tuning.TotalCommander);

  FCanExit:=FindParam(PARAM_NOTRAY);
  TrayIcon.Visible:=not FCanExit;
  LoadMenus;
  FormResize(self);
end;

procedure TFormMain._WM_USER_SHOWMENU(var AMessage: tMessage);
begin
  ShowMenu;
end;

procedure TFormMain._WM_ACTIVATE(var Mess: TMessage);
begin
  if Mess.wParam = WA_INACTIVE then Close;
  inherited;
end;

procedure TFormMain.FormActivate(Sender: TObject);
begin
  if FindParam(PARAM_HIDE) then Close;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose:=FCanExit;
  if not FCanExit then HideMenu;
end;

procedure TFormMain.HideMenu;
var m: TProgramMenu;
begin
  m:=GetActiveMenu;
  if (m <> nil) then m.UnClick;

  Hide;
end;

procedure TFormMain.ShowMenu(AClosePopupMenu: boolean = true);
begin
  if AClosePopupMenu then begin
    // закрываю popupmenu в чужих приложениях :)
    // вроде ничего лишнего не закрывает, но надо проверять!
    keybd_event(VK_ESCAPE, MapVirtualKey(VK_ESCAPE, 0), 0, 0);
    keybd_event(VK_ESCAPE, MapVirtualKey(VK_ESCAPE, 0), KEYEVENTF_KEYUP,0);
  end;

  FormResize(self);

  Show;
  SetForegroundWindow(Handle);
end;

procedure TFormMain.LoadMenus;
var
  i: integer;
  fn: string;
  first: boolean;
begin
  first:=true;
  for i:=0 to 9 do begin // пока так
    fn:=WorkPath + Format('menu-%d.ini', [i]);
    if FileExists(fn) then begin
      FListProgramMenu.Add(TProgramMenu.Create(fn, first));
      first:=false;
    end;
  end;
end;

procedure TFormMain.SetMenus;
var i: integer;
begin
  for i:=0 to FListProgramMenu.Count - 1 do FListProgramMenu[i].SetMenu;
end;

procedure TFormMain.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  i: integer;
  b: boolean;
  Hotkey: string;
begin
  if Key = VK_ESCAPE then Close
  else
    if Key = VK_RETURN then exit
    else begin
      b:=false;
      i:=0;
      Hotkey:=HotkeyNormalize(KeyAndShiftStateToKeyString(Key, Shift));
      while not b and (i < FListProgramMenu.Count) do begin
        b:=FListProgramMenu[i].FormKeyDown(Hotkey);
        inc(i);
      end;
    end;
end;

procedure TFormMain.FormPaint(Sender: TObject);
begin
  Tuning.HideIconInTaskBar;
end;

procedure TFormMain.FormResize(Sender: TObject);
const
  saveWorkareaRect: TRect = (Left: 0; Top: 0; Right: 0; Bottom: 0);
var
  waRect: TRect;

  paddings, widths: array of integer;
  paddingLeft, paddingRight, paddingTop, paddingBottom: integer;
  i, w, w1: integer;
  k: single;
begin
  Tuning.SetFormSize; // до exit из-за проблем с приложениями в полноэкранном режиме (игры и пр.)

  waRect:=Monitor.WorkareaRect;
  if waRect = saveWorkareaRect then exit;
  saveWorkareaRect:=waRect;

  AlphaBlendValue:=round(Tuning.AlphaBlend);

  if FListProgramMenu.Count > 0 then begin
    SetLength(paddings, FListProgramMenu.Count);
    SetLength(widths, FListProgramMenu.Count);

    Tuning.GetFormPaddings(paddingLeft, paddingRight, paddingTop, paddingBottom);

    if (paddingTop + paddingBottom >= ClientHeight) then begin
      paddingTop:=0;
      paddingBottom:=0;
    end;

    w:=ClientWidth - paddingLeft - paddingRight;
    if w <= 0 then begin
      paddingLeft:=0;
      paddingRight:=0;
      w:=ClientWidth;
    end;

    w1:=w;

    for i:=0 to FListProgramMenu.Count - 1 do begin
      paddings[i]:=FListProgramMenu[i].PaddingLeft;
      dec(w, FListProgramMenu[i].PaddingLeft);
    end;

    if w <= 0 then begin
      w:=w1;
      for i:=0 to length(paddings) - 1 do begin
        dec(w, Tuning.PaddingIn);
        paddings[i]:=Tuning.PaddingIn;
      end;

      if w <= 0 then begin
        w:=w1;
        for i:=0 to length(paddings) - 1 do paddings[i]:=0;
      end;
    end;

    k:=0;
    for i:=0 to FListProgramMenu.Count - 1 do k:=k + FListProgramMenu[i].Width;
    for i:=0 to FListProgramMenu.Count - 1 do widths[i]:=round(FListProgramMenu[i].Width/k*w);

    w1:=paddingLeft;
    for i:=0 to FListProgramMenu.Count - 1 do
      with FListProgramMenu[i], DrawGrid do begin
        Top:=paddingTop;
        Height:=self.ClientHeight - paddingTop - paddingBottom;
        Left:=w1 + paddings[i];
        Width:=widths[i];
        w1:=Left + Width;
        ColWidths[0]:=Width;
      end;
  end;

  SetMenus;
end;

procedure TFormMain.ActionCloseExecute(Sender: TObject);
begin
  FCanExit:=true;
  Close;
end;

procedure TFormMain.ActionAboutExecute(Sender: TObject);
begin
  with TFormAbout.Create(Application) do begin
    Caption:=ActionAbout.Caption;
    ShowModal;
    Free;
  end;
end;

procedure TFormMain.ActionHotkeyExecute(Sender: TObject);
begin
  with TFormHotkey.Create(Application) do begin
    Caption:=ActionHotkey.Caption;
    ShowModal;
    Free;
  end;
end;

procedure TFormMain.ActionShowMenuExecute(Sender: TObject);
begin
  ShowMenu(false);
end;

function TFormMain.GetActiveMenuIndex: integer;
var
  ac: TWinControl;
  i : integer;
begin
  Result:=-1;
  ac:=ActiveControl;
  i:=0;
  while (Result = -1) and (i < FListProgramMenu.Count) do
    if FListProgramMenu[i].DrawGrid = ac then Result:=i
    else inc(i);
end;

function TFormMain.GetActiveMenu: TProgramMenu;
var i : integer;
begin
  i:=GetActiveMenuIndex;
  if i = -1 then Result:=nil
  else Result:=FListProgramMenu[i];
end;

procedure TFormMain.ActionRunExecute(Sender: TObject);
var m: TProgramMenu;
begin
  m:=GetActiveMenu;
  if m <> nil then m.Run(rCommand, TMenuItem(Sender).Tag = 1);
end;

procedure TFormMain.ActionOpenFolderExecute(Sender: TObject);
var m: TProgramMenu;
begin
  m:=GetActiveMenu;
  if m <> nil then m.Run(rFolder, false);
end;

procedure TFormMain.ActionOpenFolderTCExecute(Sender: TObject);
var m: TProgramMenu;
begin
  m:=GetActiveMenu;
  if m <> nil then m.Run(rFolderTC, false);
end;

procedure TFormMain.NextMenu;
var i: integer;
begin
  i:=GetActiveMenuIndex;
  if (i <> -1) and (i < FListProgramMenu.Count - 1) then
    FListProgramMenu[i + 1].Activate;
end;

procedure TFormMain.PrevMenu;
var i: integer;
begin
  i:=GetActiveMenuIndex;
  if i > 0 then FListProgramMenu[i - 1].Activate;
end;

procedure TFormMain.FirstData;
begin
  if FListProgramMenu.Count > 0 then FListProgramMenu[0].GotoFirst;
end;

procedure TFormMain.LastData;
begin
  if FListProgramMenu.Count > 0 then
    FListProgramMenu[FListProgramMenu.Count - 1].GotoLast;
end;

end.

