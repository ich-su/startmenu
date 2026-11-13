unit __main;

{$mode objfpc}{$H+}

// {$DEFINE DEBUG}

interface

uses
  Forms, Graphics, Menus;

const
  ProjectName = 'Запускатель программ';

  PARAM_HIDE = 'hide';
  PARAM_NOTRAY = 'cheat';
  REPLACE_SELF = '%self%';
  REPLACE_TOTALCMD = '%totalcmd%';
  INI_NONE = 'none';
  INI_DOWN = 'down';

procedure Run;

function VerifyProjectName: string;
function VerifyRun: boolean;
function HotkeyNormalize(AStr: string): string;
function ExpandEnvStr(AStr: string): string;
function NormalPath(APath: string): string;
function FindParam(AParam: string): boolean;
function Windows10: boolean;
function Windows11: boolean;
function SystemLightTheme: boolean;
function ExeName: string;
function ExePath: string;
function WorkPath: string;
function DesktopWidthPrc(APrc: single): integer;
function DesktopHeightPrc(APrc: single): integer;
function FormWidthPrc(APrc: single): integer;
function FormHeightPrc(APrc: single): integer;
function kPPI(AValue: integer): integer;

type
  TTuning = class(TObject)
  protected type
    TSizeForm = record
      Left: single;
      Top: single;
      Width: single;
      Height: single;
    end;
    TPaddings = record
      Left: single;
      Top: single;
      Right: single;
      Bottom: single;
    end;

  protected
    FIconSizeSmall: integer;
    FIconSize: integer;

    FColorBack: tColor;
    FColorFont: tColor;
    FColorCurrentBack: tColor;
    FColorCurrentFont: tColor;
    FColorActiveBack: tColor;
    FColorActiveFont: tColor;

    FShiftMouseDownX: integer;
    FShiftMouseDownY: integer;

    FSizeForm: TSizeForm;
    FAlphaBlend: single;
    FPaddings: TPaddings;
    FPaddingIn: single;

    FHighMenuItems: boolean;
    FHideIconInTaskBar: boolean;
    FRoundCorners: boolean;
    FRoundCornersINI: integer;
    FAddPixelsH: integer;
    FAddPixelsV: integer;
    FAddPixelsSeparator: integer;

    FExplorer: string;
    FTotalCommander: string;
    FTotalCommanderParam: string;

    function LoadINI(APath: string): boolean;
    function VerifySize(ASize, ADefSize: single; ANeedDefined: boolean): single;

    function GetPadding(APadding: single): integer;
    function GetPaddingIn: integer;
    function GetAlphaBlend: integer;

  public
    function IconSize(ASmall: boolean = false): integer;
    procedure SetFormSize;
    procedure GetFormPaddings(var ALeft, ARight, ATop, ABottom: integer);
    function ExpandEnvStrEx(AStr: string): string;

    procedure SetHightMenuItems(AMenu: TMenu);
    procedure HideIconInTaskBar;

    constructor Create;

    property PaddingIn: integer read GetPaddingIn;
    property AlphaBlend: integer read GetAlphaBlend;

    property ColorBack: tColor read FColorBack;
    property ColorFont: tColor read FColorFont;
    property ColorCurrentBack: tColor read FColorCurrentBack;
    property ColorCurrentFont: tColor read FColorCurrentFont;
    property ColorActiveBack: tColor read FColorActiveBack;
    property ColorActiveFont: tColor read FColorActiveFont;

    property ShiftMouseDownX: integer read FShiftMouseDownX;
    property ShiftMouseDownY: integer read FShiftMouseDownY;

    property RoundCorners: boolean read FRoundCorners;
    property AddPixelsH: integer read FAddPixelsH;
    property AddPixelsV: integer read FAddPixelsV;
    property AddPixelsSeparator: integer read FAddPixelsSeparator;

    property Explorer: string read FExplorer;
    property TotalCommander: string read FTotalCommander;
    property TotalCommanderParam: string read FTotalCommanderParam;
  end;

var
  Tuning: TTuning;

implementation

uses
  __formmain, __formabout,
  Classes, FGL, SysUtils, Windows, INIFiles, Registry;


procedure Run;
// var rs: TResourceStream;
begin
  if VerifyRun then begin
    DefaultFormatSettings.DecimalSeparator:='.';

    Application.CreateForm(TFormMain, FormMain);
    Tuning:=TTuning.Create;

    if Windows10 and not SystemLightTheme then begin
      // rs:=TResourceStream.Create(HInstance, '2', RT_ICON); // х.з. почему не видит иконку в ресурсах
      // Application.Icon.LoadFromStream(rs);
      // rs.Free;

      with TFormAbout.Create(nil) do begin
        Application.Icon.Assign(Image.Picture);
        Free;
      end;
    end;

    FormMain.TrayIcon.Icon.Assign(Application.Icon);
    FormMain.Icon.Assign(Application.Icon);

    Application.Title:=ProjectName;
    Application.Hint:=ProjectName;
    FormMain.Caption:=VerifyProjectName;
    FormMain.TrayIcon.Hint:=ProjectName;

    FormMain.Initialize;
    Application.Run;

    Tuning.Free;
  end;
end;

function VerifyProjectName: string;
begin
  Result:=ProjectName + ' ' + WorkPath;
end;

function VerifyRun: boolean;
var h: integer;
begin
  h:=FindWindowW(nil, PWideChar(UTF8Decode(VerifyProjectName))); // PWideChar(UTF8Decode(... - это поддержка русского utf-8 при вызовах WinAPI
  Result:=h = 0;
  if not Result then
    if not FindParam(PARAM_HIDE) then PostMessage(h, WM_USER_SHOWMENU, 0, 0);
end;

function HotkeyNormalize(AStr: string): string;
const
  HOTKEY_SEP = '+';
  HOTKEY_DEL: TStringArray = ('word(');
  HOTKEY_SHIFTS: TStringArray = ('alt', 'ctrl', 'shift', 'meta', 'popup');
type
  TListString = specialize TFPGList<string>;
var
  a: TStringArray;
  l: TListString;
  i: integer;
  s: string;

  procedure _add; begin
    a[i]:=s.Substring(0, 1).ToUpper + s.Substring(1); // первая буква большая
    inc(i);
  end;

begin
  a:=AStr.ToLower.Split(HOTKEY_SEP);

  // эта хренатень далее оттого, что я так и не понял как в Lazarus использовать
  // TArrayHelper для сортировки массива (a.Sort), поэтому сортирую в списке
  l:=TListString.Create;
  for s in a do l.Add(s);
  l.Sort(@(s.Compare));

  // далее два цикла - отделение ctrl, alt, shift и пр. от остальных клавишь и удаление word(...
  i:=0;
  for s in l do
    if (s.IndexOfAny(HOTKEY_DEL) = -1) and (s.IndexOfAny(HOTKEY_SHIFTS) >= 0) then _add;
  for s in l do
    if (s.IndexOfAny(HOTKEY_DEL) = -1) and (s.IndexOfAny(HOTKEY_SHIFTS) = -1) then _add;
  SetLength(a, i);

  Result:=string.Join(HOTKEY_SEP, a);
end;

function ExpandEnvStr(AStr: string): string;
var
  i: integer;
  s: string;
begin
  AStr:=AStr.Trim;
  if AStr.IsEmpty then Result:=''
  else begin
    SetLength(Result, 2048);
    i:=ExpandEnvironmentStrings(PChar(AStr), PChar(Result), 2048);
    SetLength(Result, i);

    if string(ExtractFileDrive(Result)).IsEmpty then begin
      s:=Result.Substring(0, 1);
      if (s = '/') or (s = '\') then
        Result:={$IFDEF DEBUG}'d:'{$ELSE}ExtractFileDrive(WorkPath){$ENDIF} + Result
      else
        Result:=WorkPath + Result;
    end;
  end
end;

function NormalPath(APath: string): string;
begin
  Result:=APath;
  if not APath.IsEmpty and (APath.Substring(length(APath) -1, 1) <> '\') then Result:=Result + '\';
end;

function FindParam(AParam: string): boolean;
var
  i: integer;
  s: string;
begin
  Result:=false;
  AParam:=AParam.ToLower;
  i:=1;
  while (i <= ParamCount) and not Result do begin
    s:=ParamStr(i);
    Result:=
      (s.Compare(s, AParam, [coIgnoreCase]) = 0) or
      (s.Compare(s.Substring(1), AParam, [coIgnoreCase]) = 0);
    inc(i);
  end;
end;

function Windows10: boolean;
var ver: TOSVersionInfo;
begin
  ver.dwOSVersionInfoSize:=SizeOf(ver);
  Result:=GetVersionEx(ver) and (ver.dwMajorVersion >= 10);
end;

function Windows11: boolean;
var ver: TOSVersionInfo;
begin
  ver.dwOSVersionInfoSize:=SizeOf(ver);
  Result:=GetVersionEx(ver) and (ver.dwBuildNumber >= 22000);
end;

function SystemLightTheme: boolean;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  with reg do
    try
      RootKey:=HKEY_CURRENT_USER;
      Result:=
        OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize', false) and
        ReadBool('SystemUsesLightTheme')
    finally
      CloseKey;
      Free;
    end;
end;

function ExeName: string;
begin
  Result:=ParamStr(0);
end;

function ExePath: string;
begin
  Result:=NormalPath(ExtractFilePath(ExeName));
end;

function WorkPath: string;
begin
  Result:=NormalPath(GetCurrentDir);
end;

function DesktopWidthPrc(APrc: single): integer;
var r: TRect;
begin
  r:=FormMain.Monitor.WorkareaRect;
  Result:=round((r.Right - r.Left)*APrc);
end;

function DesktopHeightPrc(APrc: single): integer;
var r: TRect;
begin
  r:=FormMain.Monitor.WorkareaRect;
  Result:=round((r.Bottom - r.Top)*APrc);
end;

function FormWidthPrc(APrc: single): integer;
begin
  Result:=round(FormMain.Width*APrc);
end;

function FormHeightPrc(APrc: single): integer;
var r: TRect;
begin
  Result:=round(FormMain.Height*APrc);
end;

function kPPI(AValue: integer): integer;
begin
  Result:=round(AValue*FormMain.PixelsPerInch/96);
end;



constructor TTuning.Create;
begin
  inherited;

  FIconSize:=GetSystemMetrics(SM_CXICON);
  FIconSizeSmall:=GetSystemMetrics(SM_CXSMICON);

  FColorBack:=clBtnFace;
  FColorFont:=clBtnText;
  FColorCurrentBack:=clHighlight;
  FColorCurrentFont:=clHighlightText;
  FColorActiveBack:=clHotLight;
  FColorActiveFont:=clHighlightText;

  FShiftMouseDownX:=2;
  FShiftMouseDownY:=1;

  with FSizeForm do begin
    Left:=-1;
    Top:=-1;
    Width:=0.7;
    Height:=0.9;
  end;
  FAlphaBlend:=1;

  with FPaddings do begin
    Left:=-1;
    Right:=-1;
    Top:=-1;
    Bottom:=-1;
  end;
  FPaddingIn:=-1;

  FExplorer:='%SystemRoot%\explorer.exe';
  FTotalCommander:='%ProgramFiles(x86)%\Total Commander\TOTALCMD64.EXE';
  FTotalCommanderParam:='/O /P=L /L="%s"';

  FHighMenuItems:=false;
  FHideIconInTaskBar:=true;
  FRoundCorners:=false;
  FRoundCornersINI:=-1;
  FAddPixelsH:=0;
  FAddPixelsV:=0;
  FAddPixelsSeparator:=0;

  LoadINI(ExePath);
  LoadINI(WorkPath);

  SetHightMenuItems(FormMain.PopupMenuTray);
end;

procedure TTuning.SetHightMenuItems(AMenu: TMenu);
var mi: TMenuItem;
begin
  if FHighMenuItems then begin
    AMenu.Images:=FormMain.ImageList;
    AMenu.ImagesWidth:=kPPI(32);
    mi:=TMenuItem.Create(FormMain);
    mi.ImageIndex:=0;
    mi.Visible:=false;
    mi.Enabled:=false;
    AMenu.Items.Add(mi); // лялятополя, а как еще можно увеличить высоту меню?
  end;
end;

procedure TTuning.HideIconInTaskBar;
begin
  if FHideIconInTaskBar then ShowWindow(Application.Handle, SW_HIDE);
end;

function TTuning.IconSize(ASmall: boolean = false): integer;
begin
  if ASmall then Result:=FIconSizeSmall
  else Result:=FIconSize;
end;

function TTuning.VerifySize(ASize, ADefSize: single; ANeedDefined: boolean): single;
begin
  if ASize > 1 then Result:=1
  else
    if (ASize = -1) or (ANeedDefined and (ASize <= 0)) then Result:=ADefSize
    else Result:=ASize;
end;

function TTuning.LoadINI(APath: string): boolean;
var
  ini: TIniFile;
  section: string;
  w10, light: boolean;
begin
  Result:=false;
  APath:=APath + ChangeFileExt(ExtractFileName(ExeName), '.ini');

  if FileExists(APath) then begin
    ini:=TIniFile.Create(APath);

    try
      w10:=Windows10;
      light:=w10 and SystemLightTheme;

      if w10 then
        if light then section:='Light'
        else section:='Dark'
      else section:='Classic';

      section:='Colors' + section;
      FColorBack:=StringToColor(ini.ReadString(section, 'ColorBack', ColorToString(FColorBack)));
      FColorFont:=StringToColor(ini.ReadString(section, 'ColorFont', ColorToString(FColorFont)));
      FColorCurrentBack:=StringToColor(ini.ReadString(section, 'ColorCurrentBack', ColorToString(FColorCurrentBack)));
      FColorCurrentFont:=StringToColor(ini.ReadString(section, 'ColorCurrentFont', ColorToString(FColorCurrentFont)));
      FColorActiveBack:=StringToColor(ini.ReadString(section, 'ColorActiveBack', ColorToString(FColorActiveBack)));
      FColorActiveFont:=StringToColor(ini.ReadString(section, 'ColorActiveFont', ColorToString(FColorActiveFont)));

      section:='Form';
      with FSizeForm do begin
        Left:=VerifySize(ini.ReadFloat(section, 'Left', Left), Left, false);
        Top:=VerifySize(ini.ReadFloat(section, 'Top', Top), Top, false);
        Height:=VerifySize(ini.ReadFloat(section, 'Height', Height), Height, true);
        Width:=VerifySize(ini.ReadFloat(section, 'Width', Width), Width, true);
      end;
      FAlphaBlend:=VerifySize(ini.ReadFloat(section, 'AlphaBlend', FAlphaBlend), 1, true);

      section:='Paddings';
      FPaddingIn:=VerifySize(ini.ReadFloat(section, 'In', FPaddingIn), FPaddingIn, false);

      with FPaddings do begin
        Left:=VerifySize(ini.ReadFloat(section, 'Left', Left), Left, false);
        Right:=VerifySize(ini.ReadFloat(section, 'Right', Right), Right, false);
        Top:=VerifySize(ini.ReadFloat(section, 'Top', Top), Top, false);
        Bottom:=VerifySize(ini.ReadFloat(section, 'Bottom', Bottom), Bottom, false);
      end;

      FExplorer:=ExpandEnvStr(ini.ReadString('Explorer', 'Path', FExplorer));
      section:='TotalCommander';
      FTotalCommander:=ExpandEnvStr(ini.ReadString(section, 'Path', FTotalCommander));
      FTotalCommanderParam:=ini.ReadString(section, 'Parameters', FTotalCommanderParam);

      section:='Settings';
      FHighMenuItems:=ini.ReadBool(section, 'HighMenuItems', FHighMenuItems);
      FHideIconInTaskBar:=ini.ReadBool(section, 'HideIconInTaskBar', FHideIconInTaskBar);

      FRoundCornersINI:=ini.ReadInteger(section, 'RoundCorners', FRoundCornersINI);
      FRoundCorners:=(FRoundCornersINI = 1) or ((FRoundCornersINI = -1) and Windows11);

      FAddPixelsH:=ini.ReadInteger(section, 'AddPixelsH', FAddPixelsH);
      FAddPixelsV:=ini.ReadInteger(section, 'AddPixelsV', FAddPixelsV);
      FAddPixelsSeparator:=ini.ReadInteger(section, 'AddPixelsSeparator', FAddPixelsSeparator);

      Result:=true;

    finally
      ini.Free;
    end;
  end;
end;

function TTuning.ExpandEnvStrEx(AStr: string): string;
begin
  Result:=AStr.Replace(REPLACE_SELF, ExeName, [rfIgnoreCase]);
  Result:=Result.Replace(REPLACE_TOTALCMD, FTotalCommander, [rfIgnoreCase]);
  Result:=ExpandEnvStr(Result);
end;

function TTuning.GetPadding(APadding: single): integer;
begin
  if APadding = -1 then Result:=FIconSize
  else Result:=FormWidthPrc(APadding);
end;

function TTuning.GetPaddingIn: integer;
begin
  if FPaddingIn = -1 then Result:=FIconSize div 2
  else Result:=FormWidthPrc(FPaddingIn);
end;

function TTuning.GetAlphaBlend: integer;
begin
  Result:=round(FAlphaBlend*255);
end;

procedure TTuning.GetFormPaddings(var ALeft, ARight, ATop, ABottom: integer);
begin
  ALeft:=GetPadding(FPaddings.Left);
  ARight:=GetPadding(FPaddings.Right);
  ATop:=GetPadding(FPaddings.Top);
  ABottom:=GetPadding(FPaddings.Bottom);
end;

procedure TTuning.SetFormSize;
var r: TRect;
begin
  with FormMain do begin
    r:=Monitor.WorkareaRect;

    Width:=round((r.Right - r.Left)*FSizeForm.Width);
    Height:=round((r.Bottom - r.Top)*FSizeForm.Height);

    if (FSizeForm.Left = -1) then Left:=r.Left + (r.Right - r.Left - Width) div 2
    else Left:=r.Left + round((r.Right - r.Left)*FSizeForm.Left);

    if (FSizeForm.Top = -1) then Top:=r.Top + (r.Bottom - r.Top - Height) div 2
    else Top:=r.Top + round((r.Bottom - r.Top)*FSizeForm.Top);
  end;
end;

end.

