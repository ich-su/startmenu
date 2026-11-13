unit __programmenu;

{$mode objfpc}{$H+}

interface

uses
  __data,
  Classes, Controls, Menus, Grids, FGL, IniFiles;

type
  TListInteger = specialize TFPGList<integer>;
  TListIndex = TListInteger;

  TLoadMenuWhen = (lmwSettings, lmwData, lmwAfter);
  TLoadMenuCallBackRecord = record
    When: TLoadMenuWhen;
    Ini: TIniFile;
    Section: string;
  end;
  TLoadMenuCallBack = procedure(ARecord: TLoadMenuCallBackRecord; AData: TData) of object;

  TProgramMenu = class;
  TListProgramMenu = specialize TFPGObjectList<TProgramMenu>;

  TRun = (rCommand, rFolder, rFolderTC);

  TProgramMenu = class(TObject)
  protected const
    MENUINI_SPEC = '#';
    MENUINI_SETTINGS = MENUINI_SPEC + 'Settings';

  protected
    FDrawGrid: TDrawGrid;
    FGroup: integer;
    FFirstMenu: boolean;
    FListData: TListData;
    FListIndex: TListIndex; // для поиска (фильтра)
    FMouseDownRow: integer;
    FIconType: TIconType;
    FPaddingLeft: single;
    FWidth: single;

    function Y2Row(Y: integer): integer;

    function GoodRow(ARow: integer): boolean;
    function GetDataRow(ARow: integer): TData;
    function GetDataCurrent: TData;
    procedure GotoRow(ARow: integer);

    function GetIconHeight: integer;
    function GetPaddingLeft: integer;
    function GetSeparatorHeight(ARow: integer): integer;
    function DefaultSeparatorHeight: single;
    function GetAddPixelsH: integer;
    function GetAddPixelsV: integer;

    procedure DrawGridDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);
    procedure DrawGridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DrawGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DrawGridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure DrawGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DrawGridExit(Sender: TObject);

    function LoadMenu(AFileName: string; AGroup: integer; AProc: TLoadMenuCallBack): boolean;
    procedure LoadMenuCallBackMain(ARecord: TLoadMenuCallBackRecord; AData: TData);
    procedure LoadMenuCallBackPopupMenu(ARecord: TLoadMenuCallBackRecord; AData: TData);

    function ActivatePopupMenu: TPopupMenu;
    procedure PopupMenuDataOnClick(Sender: TObject);

    // procedure SetFilter(AFilter: string); // поиск
    // procedure ClearFilter(AFilter: string);

    property DataRow[ARow: integer]: TData read GetDataRow;
    property IconHeight: integer read GetIconHeight;
    property SeparatorHeights[ARow: integer]: integer read GetSeparatorHeight;
    property AddPixelsH: integer read GetAddPixelsH;
    property AddPixelsV: integer read GetAddPixelsV;

  public
    constructor Create(AFileName: string; AFirstMenu: boolean);
    destructor Destroy; override;

    procedure GotoFirst;
    procedure GotoLast;
    procedure Activate;
    procedure Run(ARun: TRun = rCommand; AAsAdmin: boolean = false; AData: TData = nil);
    procedure UnClick;
    procedure SetMenu;
    function FormKeyDown(AHotkey: string): boolean;

    property PaddingLeft: integer read GetPaddingLeft;
    property Width: single read FWidth;

    property DrawGrid: TDrawGrid read FDrawGrid;
    property DataCurrent: TData read GetDataCurrent;
  end;

implementation

uses
  __main, __formmain,
  StdCtrls, Graphics, SysUtils, Forms, Windows, LCLProc;

constructor TProgramMenu.Create(AFileName: string; AFirstMenu: boolean);
begin
  inherited Create;

  FFirstMenu:=AFirstMenu;
  FDrawGrid:=TDrawGrid.Create(FormMain);
  FMouseDownRow:=-1;
  FListData:=TListData.Create(true);
  FListData.Add(TDataEmpty.Create);
  FListIndex:=TListIndex.Create;
  FGroup:=1;
  FPaddingLeft:=-1;
  FWidth:=1;

  with FDrawGrid do begin
    Align:=alNone;
    ScrollBars:=ssNone;
    BorderStyle:=bsNone;
    FixedRows:=0;
    FixedCols:=0;
    ColCount:=1;
    RowCount:=1;
    DefaultDrawing:=false;
    ExtendedSelect:=false;
    Options:=[];
    Options2:=[];
    Color:=Tuning.ColorBack;
    Parent:=FormMain;

    OnDrawCell:=@DrawGridDrawCell;
    OnKeyDown:=@DrawGridKeyDown;
    OnMouseDown:=@DrawGridMouseDown;
    OnMouseMove:=@DrawGridMouseMove;
    OnMouseUp:=@DrawGridMouseUp;
    OnExit:=@DrawGridExit;
  end;

  LoadMenu(AFileName, FGroup, @LoadMenuCallBackMain);
//  SetMenu;
end;

destructor TProgramMenu.Destroy;
begin
  FListIndex.Free;
  FListData.Free;

  inherited;
end;

function TProgramMenu.GoodRow(ARow: integer): boolean;
begin
  Result:=ARow < FListIndex.Count;
end;

function TProgramMenu.GetDataRow(ARow: integer): TData;
begin
  Result:=FListData[FListIndex[ARow]];
end;

function TProgramMenu.GetDataCurrent: TData;
var data: TData;
begin
  if GoodRow(FDrawGrid.Row) then Result:=DataRow[FDrawGrid.Row]
  else Result:=nil;
end;

function TProgramMenu.GetIconHeight: integer;
begin
  Result:=Tuning.IconSize(FIconType <> itLarge);
end;

function TProgramMenu.DefaultSeparatorHeight: single;
begin
  Result:=FDrawGrid.DefaultRowHeight*2/3;
end;

function TProgramMenu.GetSeparatorHeight(ARow: integer): integer;
begin
  with DataRow[ARow] do
    if (Separator = 0) or (Separator = SEPARATOR_DOWN) then Result:=0
    else
      if Separator < 0 then Result:=round(-Separator) // down
      else begin
        Result:=round(DefaultSeparatorHeight*Separator);
        if abs(Tuning.AddPixelsSeparator) <= Result then inc(Result, Tuning.AddPixelsSeparator);
      end;
end;

function TProgramMenu.GetAddPixelsH: integer;
begin
  if abs(Tuning.AddPixelsH) <= FDrawGrid.DefaultRowHeight then Result:=Tuning.AddPixelsH
  else Result:=0;
end;

function TProgramMenu.GetAddPixelsV: integer;
begin
  if abs(Tuning.AddPixelsV) <= FDrawGrid.DefaultRowHeight div 2 then Result:=Tuning.AddPixelsV
  else Result:=0;
end;

function TProgramMenu.GetPaddingLeft: integer; begin
  if FPaddingLeft = 0 then Result:=0
  else
    if FPaddingLeft > 0 then Result:=FormWidthPrc(FPaddingLeft)
    else
      if FFirstMenu then Result:=0
      else Result:=Tuning.PaddingIn;
end;

function TProgramMenu.Y2Row(Y: integer): integer;
var
  r, t, dt: integer;
  p: TPoint;
begin
  Result:=-1;

  if PtInRect(FDrawGrid.ClientRect, FDrawGrid.ScreenToClient(Mouse.CursorPos)) then
    with FDrawGrid do begin
      r:=TopRow;
      t:=0;
      while (Result = -1) and (r < RowCount) do begin
        dt:=t + RowHeights[r];
        if (Y >= t) and (Y < dt) then begin
          if (SeparatorHeights[r] > 0) and (Y < t + SeparatorHeights[r]) then break
          else Result:=r;
        end
        else begin
          t:=dt;
          inc(r);
        end;
      end
    end;
end;

procedure TProgramMenu.DrawGridDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);
var
  rSeparator, rText, rIcon: TRect;
  spaceIconH, spaceIconV, spaceText, i: integer;
  data: TData;
  current: boolean;
begin
  if not GoodRow(aRow) then exit;

  data:=DataRow[aRow];
  spaceIconH:=Tuning.IconSize div 8 + 1;
  spaceIconV:=spaceIconH + AddPixelsV;
  inc(spaceIconH, AddPixelsH);
  spaceText:=Tuning.IconSize div 2;

  with FDrawGrid, Canvas do begin
    Brush.Color:=Tuning.ColorBack;
    Font.Color:=Tuning.ColorFont;

    if Tuning.RoundCorners then FillRect(aRect);

    if SeparatorHeights[aRow] > 0 then begin
      rSeparator:=aRect;
      rSeparator.Bottom:=aRect.Top + SeparatorHeights[aRow];
      if not Tuning.RoundCorners then FillRect(rSeparator);
      aRect.Top:=rSeparator.Bottom;
    end;

    rIcon:=aRect;

    current:=FDrawGrid.Focused and data.Enabled and (aRow = Row);
    if current then
      if aRow = FMouseDownRow then begin
        Brush.Color:=Tuning.ColorActiveBack;
        Font.Color:=Tuning.ColorActiveFont;
        rIcon.Left:=rIcon.Left + Tuning.ShiftMouseDownX;
        rIcon.Top:=rIcon.Top + Tuning.ShiftMouseDownY;
        rIcon.Right:=rIcon.Right + Tuning.ShiftMouseDownX;
        rIcon.Bottom:=rIcon.Bottom + Tuning.ShiftMouseDownY;
      end
      else begin
        Brush.Color:=Tuning.ColorCurrentBack;
        Font.Color:=Tuning.ColorCurrentFont;
      end;

    if not Tuning.RoundCorners then FillRect(aRect)
    else
      if current then begin
        Pen.Color:=Brush.Color;
        RoundRect(aRect, 8, 8);
      end;

    rIcon.Left:=rIcon.Left + spaceIconH;
    rIcon.Right:=rIcon.Right - spaceIconH;
    rIcon.Top:= rIcon.Top + spaceIconV;
    rIcon.Bottom:= rIcon.Bottom - spaceIconV;

    rText:=rIcon;

    rText.Left:=rText.Left + spaceText;
    rText.Left:=rText.Left + Tuning.IconSize(not (data.IconType <> itSmall));

    if data.Icon <> nil then begin
      rIcon.Right:=rIcon.Left + IconHeight;
      rIcon.Bottom:=rIcon.Top + IconHeight;
      StretchDraw(rIcon, data.Icon);
    end;

    with TextStyle do begin // TextStyle.поля не дает изменять, а с with дает !!
      EndEllipsis:=true;
      Alignment:=taRightJustify;
      Layout:=tlCenter;
    end;

    if current and not data.Hotkey.IsEmpty then begin
      TextRect(rText, rText.Left, rText.Top, data.Hotkey);
      i:=Min(TextWidth(data.Hotkey), (rText.Right - rText.Left) div 2);
      rText.Right:=rText.Right - i - spaceIconH;
    end;

    with TextStyle do Alignment:=taLeftJustify; // !!
    TextRect(rText, rText.Left, rText.Top, data.Name);
  end;
end;

procedure TProgramMenu.GotoRow(ARow: integer); begin
  FDrawGrid.Row:=ARow;
  Activate;
end;

procedure TProgramMenu.DrawGridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN: Run;
    VK_LEFT: FormMain.PrevMenu;
    VK_RIGHT: FormMain.NextMenu;
    VK_HOME:
      if ssCtrl in Shift then FormMain.FirstData
      else GotoFirst;
    VK_END:
      if ssCtrl in Shift then FormMain.LastData
      else GotoLast;
  end;
end;

function TProgramMenu.FormKeyDown(AHotkey: string): boolean;
var i, j: integer;
begin
  Result:=false;

  // сначала основные Data
  i:=0;
  while not Result and (i < FListIndex.Count) do begin
    Result:=DataRow[i].Enabled and (DataRow[i].Hotkey = AHotkey);
    if Result then begin
      GotoRow(i);
      Run
    end
    else inc(i);
  end;

  // потом все PopupMenu
  i:=0;
  while not Result and (i < FListIndex.Count) do begin
    with DataRow[i] do begin
      j:=0;
      while not Result and (j < ListDataPopupMenu.Count) do begin
        Result:=ListDataPopupMenu[j].Enabled and (ListDataPopupMenu[j].Hotkey = AHotkey);
        if Result then begin
          GotoRow(i);
          Run(rCommand, false, ListDataPopupMenu[j]);
        end
        else inc(j);
      end;
    end;
    inc(i);
  end;
end;

procedure TProgramMenu.DrawGridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var r: integer;
begin
  r:=Y2Row(Y);
  if (r >= 0) then GotoRow(r);
end;

procedure TProgramMenu.DrawGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FMouseDownRow:=Y2Row(Y);
  if FMouseDownRow >= 0 then FDrawGrid.InvalidateCell(0, FMouseDownRow);
end;

procedure TProgramMenu.DrawGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var r: integer;
begin
  r:=Y2Row(Y);

  if (Button = mbLeft) and (r = FMouseDownRow) and (FMouseDownRow <> -1) then Run
  else
    if (Button = mbRight) then
      if (r >= 0) then FDrawGrid.PopupMenu:=ActivatePopupMenu
      else FDrawGrid.PopupMenu:=nil;

  UnClick;
end;

procedure TProgramMenu.DrawGridExit(Sender: TObject);
begin
  UnClick;
end;

procedure TProgramMenu.UnClick;
begin
  FMouseDownRow:=-1;
end;

procedure TProgramMenu.PopupMenuDataOnClick(Sender: TObject);
var d: TData;
begin
  if DataCurrent <> nil then begin
    d:=DataCurrent.ListDataPopupMenu[TMenuItem(Sender).Tag];
    if d.Enabled then Run(rCommand, false, d);
  end;
end;

function TProgramMenu.ActivatePopupMenu: TPopupMenu;
var
  i: integer;
  mi: TMenuItem;
begin
  Result:=nil;

  if DataCurrent <> nil then
    with DataCurrent do
      if Enabled then begin
        Result:=FormMain.PopupMenuData;

        Result.Items.Clear;
        if PopupMenuMode = pmmNormal then Result.Items.Assign(FormMain.PopupMenuDataDef.Items);
        Tuning.SetHightMenuItems(Result);

        if (PopupMenuMode <> pmmNone) and (ListDataPopupMenu.Count > 0) then begin
          if PopupMenuMode = pmmNormal then Result.Items.AddSeparator;

          for i:=0 to ListDataPopupMenu.Count - 1 do begin
            mi:=TMenuItem.Create(FormMain);
            mi.Caption:=ListDataPopupMenu[i].Name;
            mi.Tag:=i;
            mi.ShortCut:=TextToShortCut(ListDataPopupMenu[i].HotKey);
            mi.OnClick:=@PopupMenuDataOnClick;
            if ListDataPopupMenu[i].Separator <> 0 then Result.Items.AddSeparator;
            Result.Items.Add(mi);
          end;
        end;
      end;
end;

procedure TProgramMenu.GotoFirst;
begin
  GotoRow(0);
end;

procedure TProgramMenu.GotoLast;
begin
  GotoRow(FDrawGrid.RowCount - 1);
end;

procedure TProgramMenu.Activate;
begin
  FDrawGrid.SetFocus;
end;

procedure TProgramMenu.Run(ARun: TRun = rCommand; AAsAdmin: boolean = false; AData: TData = nil);
begin
  if AData = nil then AData:=DataCurrent;
  if (AData <> nil) and AData.Enabled then
    case ARun of
      rCommand: AData.Exec(AAsAdmin);
      rFolder: AData.OpenFolder;
      rFolderTC: AData.OpenFolderTotalCommander;
    end;

  FormMain.Close;
end;

procedure TProgramMenu.SetMenu;
var
  i, idxDown, h, hDown: integer;
begin
  with FDrawGrid do begin
    RowCount:=FListIndex.Count;
    DefaultRowHeight:=round(Tuning.IconSize/4 + IconHeight);
    DefaultRowHeight:=DefaultRowHeight + 2*AddPixelsV;

    idxDown:=-1;
    hDown:=0;
    h:=0;
    for i:=0 to RowCount - 1 do
      with DataRow[i] do begin
        if Separator { = SEPARATOR_DOWN } < 0 then //
          if idxDown = -1 then idxDown:=i
          else Separator:=1;

        if i = idxDown then RowHeights[i]:=DefaultRowHeight
        else RowHeights[i]:=DefaultRowHeight + SeparatorHeights[i];

        inc(h, RowHeights[i]);
        if i >= idxDown then inc(hDown, RowHeights[i]);
      end;

    if idxDown >= 0 then
      if h >= FDrawGrid.ClientHeight then DataRow[idxDown].Separator:=SEPARATOR_DOWN
      else begin
        DataRow[idxDown].Separator:=-(FDrawGrid.ClientHeight - h); // отрицательное значение = -реальный размер Separator`а
        RowHeights[idxDown]:=RowHeights[idxDown] + SeparatorHeights[idxDown];
      end;
  end;
end;

function TProgramMenu.LoadMenu(AFileName: string; AGroup: integer; AProc: TLoadMenuCallBack): boolean;
var
  sections: TStringList;
  cbRecord: TLoadMenuCallBackRecord;
begin
  Result:=false;

  cbRecord.Ini:=TIniFile.Create(AFileName);
  sections:=TStringList.Create;

  cbRecord.When:=lmwSettings;
  AProc(cbRecord, nil);

  try
    cbRecord.When:=lmwData;
    cbRecord.Ini.ReadSections(sections);

    for cbRecord.Section in sections do
      if cbRecord.Section.Trim.Substring(0, 1) <> MENUINI_SPEC then
        AProc(
          cbRecord,
          TData.Create(
            cbRecord.Section,
            cbRecord.Ini.ReadString(cbRecord.Section, 'File', ''),
            cbRecord.Ini.ReadString(cbRecord.Section, 'Parameters', ''),
            cbRecord.Ini.ReadString(cbRecord.Section, 'Directory', ''),
            cbRecord.Ini.ReadString(cbRecord.Section, 'Hotkey', ''),
            cbRecord.Ini.ReadString(cbRecord.Section, 'Icon', ''),
            AGroup,
            FIconType,
            cbRecord.Ini.ReadString(cbRecord.Section, 'Separator', '')));

    cbRecord.When:=lmwAfter;
    AProc(cbRecord, nil);

  finally
    cbRecord.Ini.Free;
    sections.Free;

    Result:=true;
  end;
end;

procedure TProgramMenu.LoadMenuCallBackMain(ARecord: TLoadMenuCallBackRecord; AData: TData);
var
  popupMenu: string;
  i: integer;
  s: string;
begin
  case ARecord.When of
    lmwSettings: begin
      if ARecord.Ini.ReadInteger(MENUINI_SETTINGS, 'SmallIcons', -1) = 1 then FIconType:=itSmall
      else FIconType:=itLarge;

      FPaddingLeft:=ARecord.Ini.ReadFloat(MENUINI_SETTINGS, 'PaddingLeft', FPaddingLeft);
      if FPaddingLeft > 1 then FPaddingLeft:=1;

      FWidth:=ARecord.Ini.ReadFloat(MENUINI_SETTINGS, 'Width', FWidth);
      if FWidth <= 0 then FWidth:=1;
    end;

    lmwData: begin
      FListIndex.Add(FListData.Add(AData));

      for i:=-1 to 9 do begin // пока так
        if i = -1 then s:=''
        else s:='-' + i.ToString;

        popupMenu:=ARecord.Ini.ReadString(ARecord.Section, 'PopupMenu' + s, '');

        if (i = -1) and (popupMenu.Trim.ToLower = INI_NONE) then begin
          AData.PopupMenuMode:=pmmNone;
          break;
        end;

        if (not popupMenu.IsEmpty) and FileExists(popupMenu) then
          LoadMenu(popupMenu, -1, @LoadMenuCallBackPopupMenu);
      end;
    end;

    lmwAfter:
      if FListIndex.Count = 0 then FListIndex.Add(0);
  end;
end;

procedure TProgramMenu.LoadMenuCallBackPopupMenu(ARecord: TLoadMenuCallBackRecord; AData: TData);
const LocalNeedSeparator: boolean = false;
begin
  if FListData.Count > 0 then
    with FListData[FListData.Count - 1] do
      case ARecord.When of
        lmwSettings: begin
          if ListDataPopupMenu.Count > 0 then LocalNeedSeparator:=true;
          if (PopupMenuMode <> pmmNone) and (ARecord.Ini.ReadInteger(MENUINI_SETTINGS, 'Replace', -1) = 1) then
            PopupMenuMode:=pmmReplace;
        end;

        lmwData: begin
          if LocalNeedSeparator then AData.Separator:=1;
          LocalNeedSeparator:=false;
          ListDataPopupMenu.Add(AData);
        end;
      end;
end;

end.

