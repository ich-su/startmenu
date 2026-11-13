unit __data;

{$mode objfpc}{$H+}

interface

uses
  Classes, Graphics, FGL, SysUtils, Windows;

type
  TIconType = (itLarge, itSmall);
  TData = class;
  TListData = specialize TFPGObjectList<TData>;
  TPopupMenuMode = (pmmNormal, pmmReplace, pmmNone);

const
  SEPARATOR_DOWN = -2;

type
  TData = class(TObject)
  protected
    FName: string;
    FHotkey: string;
    FCommand: string;
    FParams: string;
    FDirectory: string;
    FFileIcon: string;
    FGroup: integer;
    FSeparator: single;
    FIcon: TIcon;
    FIconType: TIconType;
    FListDataPopupMenu: TListData;
    FPopupMenuMode: TPopupMenuMode;

    function LoadIconA(AFileName: string): TIcon;
    function LoadIcon: TIcon;
    function GetLastName: string;
    function GetName: string;
    function GetEnabled: boolean; virtual;
    procedure RunCommand(ACommand, AParams, ADirectory: string);

  public
    procedure Exec(AAsAdmin: boolean);
    procedure OpenFolder;
    procedure OpenFolderTotalCommander;

    property Name: string read GetName;
    property Hotkey: string read FHotkey;
    property Command: string read FCommand;
    property Params: string read FParams;
    property Group: integer read FGroup;
    property Separator: single read FSeparator write FSeparator;
    property Icon: TIcon read FIcon;
    property Enabled: boolean read GetEnabled;
    property IconType: TIconType read FIconType;
    property ListDataPopupMenu: TListData read FListDataPopupMenu;
    property PopupMenuMode: TPopupMenuMode read FPopupMenuMode write FPopupMenuMode;

    constructor Create(AName, ACommand, AParams, ADirectory, AHotkey, AFileIcon: string; AGroup: integer; AIconType: TIconType; ASeparator: string);
    destructor Destroy; override;
  end;

  TDataEmpty = class(TData)
  protected
    function GetEnabled: boolean; override;
  public
    constructor Create; overload;
  end;

implementation

uses
  __main,
  Forms, LCLProc, ShellApi;

constructor TData.Create(AName, ACommand, AParams, ADirectory, AHotkey, AFileIcon: string; AGroup: integer; AIconType: TIconType; ASeparator: string);
begin
  inherited Create;

  FName:=AName.Trim;

  FCommand:=Tuning.ExpandEnvStrEx(ACommand);
  FDirectory:=Tuning.ExpandEnvStrEx(ADirectory);
  if not DirectoryExists(FDirectory) then FDirectory:=ExtractFilePath(FCommand);
  FParams:=AParams.Trim;

  AFileIcon:=AFileIcon.Trim;
  if AFileIcon.ToLower = INI_NONE then FFileIcon:=INI_NONE
  else FFileIcon:=Tuning.ExpandEnvStrEx(AFileIcon);

  FHotkey:=HotkeyNormalize(AHotkey.Trim);

  FGroup:=AGroup;
  FIconType:=AIconType;

  ASeparator:=ASeparator.Trim;
  if ASeparator.IsEmpty then FSeparator:=0
  else begin
    FSeparator:=1;
    if ASeparator.ToLower = INI_DOWN then FSeparator:=SEPARATOR_DOWN
    else
      try
        FSeparator:=string.ToSingle(ASeparator);
        if FSeparator < 0 then
          if FSeparator = -1 then FSeparator:=1
          else FSeparator:=1;
      except
      end;
  end;

  FPopupMenuMode:=pmmNormal;
  FListDataPopupMenu:=TListData.Create;
  FIcon:=LoadIcon;
end;

destructor TData.Destroy;
begin
  FListDataPopupMenu.Free;
  if FIcon <> nil then FIcon.Free;
  inherited Destroy;
end;

function TData.GetName: string;
begin
  if FName.IsEmpty then Result:=GetLastName
  else Result:=FName;
end;

function TData.GetLastName: string;
begin
  Result:=ChangeFileExt(ExtractFileName(FCommand), '');
end;

function TData.GetEnabled: boolean;
begin
  Result:=true;
end;

procedure TData.RunCommand(ACommand, AParams, ADirectory: string);
begin
  ShellExecute(
    0,
    nil,
    PWideChar(UTF8Decode(ACommand)),
    PWideChar(UTF8Decode(AParams)),
    PWideChar(UTF8Decode(ADirectory)),
    SW_SHOWNORMAL); // SW_SHOW ?
end;

procedure TData.Exec(AAsAdmin: boolean);
var sei: _SHELLEXECUTEINFOW;
begin
  if not FCommand.IsEmpty and FileExists(FCommand) then
    if not AAsAdmin then RunCommand(FCommand, FParams, FDirectory)
    else begin
       FillChar(sei, SizeOf(sei), 0);
       sei.cbSize:=SizeOf(sei);
       sei.Wnd:=0;
       sei.fMask:=0;
       sei.lpVerb:='runas';
       sei.lpFile:=PWideChar(UTF8Decode(FCommand));
       sei.lpParameters:=PWideChar(UTF8Decode(FParams));
       sei.lpDirectory:=PWideChar(UTF8Decode(FDirectory));
       sei.nShow:=SW_SHOWNORMAL; // SW_SHOW ?
       ShellExecuteExW(@sei);
     end
end;

procedure TData.OpenFolder;
begin
  RunCommand(Tuning.Explorer, '/select, "' + FCommand + '"', '');
end;

procedure TData.OpenFolderTotalCommander;
begin
  RunCommand(Tuning.TotalCommander, Tuning.TotalCommanderParam.Format([FCommand]), '');
end;

function TData.LoadIconA(AFileName: string): TIcon;

  function _ok(h: HICON): boolean;
  begin
    Result:=h <> null; // ???
  end;

var
  h, h2: HICON;
  ext: string;
  png: TPortableNetworkGraphic;
begin
  Result:=nil;
  if AFileName.IsEmpty or not FileExists(AFileName) then exit; //

  Result:=TIcon.Create;
  try
    ext:=ExtractFileExt(AFileName);

    if string.Compare(ext, '.ico', [coIgnoreCase]) = 0 then begin
      Result.LoadFromFile(AFileName);
      exit; //
    end;

    if string.Compare(ext, '.png', [coIgnoreCase]) = 0 then begin
      png:=TPortableNetworkGraphic.Create;
      png.LoadFromFile(AFileName);
      Result.Assign(png);
      png.Free;
      exit; //
    end;

    ExtractIconEx(PWideChar(UTF8Decode(AFileName)), 0, h, h2, 1);
    if (FIconType = itSmall) and _ok(h2) then h:=h2;
    if not _ok(h) then FreeAndNil(Result)
    else Result.Handle:=h;

  except
    FreeAndNil(Result);
  end;
end;

function TData.LoadIcon: TIcon;
begin
  if FFileIcon = INI_NONE then Result:=nil
  else begin
    Result:=LoadIconA(FFileIcon);
    if Result = nil then Result:=LoadIconA(FCommand);
  end
end;



constructor TDataEmpty.Create; begin
  inherited Create('', '', '', '', '', '', 0, itLarge, '');
end;

function TDataEmpty.GetEnabled: boolean;
begin
  Result:=false;
end;

end.

