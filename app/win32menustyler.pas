{
Copyright (C) Alexey Torgashin, uvviewsoft.com
License: MPL 2.0 or LGPL
}
unit win32menustyler;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Classes, Graphics, Menus, Forms,
  Types, LCLType, LCLProc,
  ImgList;

type
  TWin32MenuStylerTheme = record
    ColorBk: TColor;
    ColorBkSelected: TColor;
    ColorFont: TColor;
    ColorFontDisabled: TColor;
    ColorFontShortcut: TColor;
    CharCheckmark: WideChar;
    CharRadiomark: WideChar;
    CharSubmenu: WideChar;
    FontName: string;
    FontSize: integer;
    IndentMinPercents: integer;
    IndentBigPercents: integer;
    IndentIconPercents: integer;
    IndentRightPercents: integer;
    IndentSubmenuArrowPercents: integer;
  end;

type
  { TWin32MenuStyler }

  TWin32MenuStyler = class
  private
    procedure ApplyBackColor(h: HMENU; AReset: boolean);
    procedure HandleMenuDrawItem(Sender: TObject; ACanvas: TCanvas;
      ARect: TRect; AState: TOwnerDrawState);
    procedure HandleMenuPopup(Sender: TObject);
  public
    procedure ApplyToMenu(AMenu: TMenu);
    procedure ApplyToForm(AForm: TForm; ARepaintEntireForm: boolean);
    procedure ResetMenu(AMenu: TMenu);
    procedure ResetForm(AForm: TForm; ARepaintEntireForm: boolean);
  end;

var
  MenuStylerTheme: TWin32MenuStylerTheme;
  MenuStyler: TWin32MenuStyler = nil;


implementation

procedure TWin32MenuStyler.ApplyBackColor(h: HMENU; AReset: boolean);
var
  mi: TMENUINFO;
begin
  FillChar(mi{%H-}, sizeof(mi), 0);
  mi.cbSize:= sizeof(mi);
  mi.fMask:= MIM_BACKGROUND or MIM_APPLYTOSUBMENUS;
  if AReset then
    mi.hbrBack:= 0
  else
    mi.hbrBack:= CreateSolidBrush(MenuStylerTheme.ColorBk);
  SetMenuInfo(h, @mi);
end;

procedure TWin32MenuStyler.ApplyToMenu(AMenu: TMenu);
begin
  AMenu.OwnerDraw:= true;
  AMenu.OnDrawItem:= @HandleMenuDrawItem;

  //it don't work!
  {
  if AMenu is TPopupMenu then
    with (AMenu as TPopupMenu) do
      if not Assigned(OnPopup) then
        OnPopup:= @HandleMenuPopup;
        }

  //it dont work!
  //ApplyBackColor(AMenu.Handle, false);
end;

procedure TWin32MenuStyler.ApplyToForm(AForm: TForm; ARepaintEntireForm: boolean);
var
  menu: TMainMenu;
begin
  menu:= AForm.Menu;
  if menu=nil then exit;

  ApplyToMenu(menu);

  //theme 2-3 pixel frame around menu
  ApplyBackColor(GetMenu(AForm.Handle), false);

  //repaint the menu bar
  if ARepaintEntireForm then
    with AForm do
    begin
      Width:= Width+1;
      Width:= Width-1;
    end;
end;

procedure TWin32MenuStyler.ResetMenu(AMenu: TMenu);
begin
  AMenu.OwnerDraw:= false;
  AMenu.OnDrawItem:= nil;
end;

procedure TWin32MenuStyler.ResetForm(AForm: TForm; ARepaintEntireForm: boolean);
var
  menu: TMenu;
begin
  menu:= AForm.Menu;
  if menu=nil then exit;

  ResetMenu(menu);
  ApplyBackColor(GetMenu(AForm.Handle), true);

  //repaint the menu bar
  if ARepaintEntireForm then
    with AForm do
    begin
      Width:= Width+1;
      Width:= Width-1;
    end;
end;

procedure TWin32MenuStyler.HandleMenuDrawItem(Sender: TObject; ACanvas: TCanvas;
  ARect: TRect; AState: TOwnerDrawState);
const
  cSampleShort = '0';
  cSampleTall = 'Wj';
var
  mi: TMenuItem;
  Images: TCustomImageList;
  dx, dxCell, dxMin, dxBig, Y: integer;
  ExtCell, ExtTall, Ext2: Types.TSize;
  NDrawFlags: UINT;
  bDisabled, bInBar, bHasSubmenu: boolean;
  BufW: UnicodeString;
  mark: WideChar;
  R: TRect;
begin
  mi:= Sender as TMenuItem;
  bDisabled:= odDisabled in AState;
  bInBar:= mi.IsInMenuBar;
  bHasSubmenu:= (not bInBar) and (mi.Count>0);

  if odSelected in AState then
    ACanvas.Brush.Color:= MenuStylerTheme.ColorBkSelected
  else
    ACanvas.Brush.Color:= MenuStylerTheme.ColorBk;
  ACanvas.FillRect(ARect);

  Windows.GetTextExtentPoint(ACanvas.Handle, PChar(cSampleShort), Length(cSampleShort), ExtCell);
  dxCell:= ExtCell.cx;
  dxMin:= dxCell * MenuStylerTheme.IndentMinPercents div 100;
  dxBig:= dxCell * MenuStylerTheme.IndentBigPercents div 100;

  Images:= mi.GetParentMenu.Images;
  if Assigned(Images) then
    dxBig:= Max(dxBig, Images.Width + dxCell * MenuStylerTheme.IndentIconPercents * 2 div 100);

  if mi.IsLine then
  begin
    ACanvas.Pen.Color:= MenuStylerTheme.ColorFontDisabled;
    Y:= (ARect.Top+ARect.Bottom) div 2;
    ACanvas.Line(ARect.Left+dxMin, Y, ARect.Right-dxMin, Y);
    exit;
  end;

  if bDisabled then
    ACanvas.Font.Color:= MenuStylerTheme.ColorFontDisabled
  else
    ACanvas.Font.Color:= MenuStylerTheme.ColorFont;

  ACanvas.Font.Name:= MenuStylerTheme.FontName;
  ACanvas.Font.Size:= MenuStylerTheme.FontSize;
  ACanvas.Font.Style:= [];

  Windows.GetTextExtentPoint(ACanvas.Handle, PChar(cSampleTall), Length(cSampleTall), ExtTall);

  if bInBar then
    dx:= dxCell
  else
    dx:= dxBig;

  Y:= (ARect.Top+ARect.Bottom-ExtTall.cy) div 2;

  if odNoAccel in AState then
    NDrawFlags:= DT_HIDEPREFIX
  else
    NDrawFlags:= 0;

  BufW:= UTF8Decode(mi.Caption);
  R.Left:= ARect.Left+dx;
  R.Top:= Y;
  R.Right:= ARect.Right;
  R.Bottom:= ARect.Bottom;
  Windows.DrawTextW(ACanvas.Handle, PWideChar(BufW), Length(BufW), R, NDrawFlags);

  if (not bInBar) and Assigned(Images) and (mi.ImageIndex>=0) then
  begin
    Images.Draw(ACanvas,
      dxCell * MenuStylerTheme.IndentIconPercents div 100,
      (ARect.Top+ARect.Bottom-Images.Height) div 2,
      mi.ImageIndex, not bDisabled);
  end
  else
  if mi.Checked then
  begin
    if mi.RadioItem then
      mark:= MenuStylerTheme.CharRadiomark
    else
      mark:= MenuStylerTheme.CharCheckmark;
    Windows.TextOutW(ACanvas.Handle,
      ARect.Left+ (dx-dxCell) div 2,
      Y, @mark, 1);
  end;

  if mi.ShortCut<>0 then
  begin
    if bDisabled then
      ACanvas.Font.Color:= MenuStylerTheme.ColorFontDisabled
    else
      ACanvas.Font.Color:= MenuStylerTheme.ColorFontShortcut;
    BufW:= UTF8Decode(ShortCutToText(mi.Shortcut));
    Windows.GetTextExtentPointW(ACanvas.Handle, PWideChar(BufW), Length(BufW), Ext2);
    Windows.TextOutW(ACanvas.Handle,
      ARect.Right - Ext2.cx - dxCell*MenuStylerTheme.IndentRightPercents div 100,
      Y, PWideChar(BufW), Length(BufW));
  end;

  if bHasSubmenu then
  begin
    if bDisabled then
      ACanvas.Font.Color:= MenuStylerTheme.ColorFontDisabled
    else
      ACanvas.Font.Color:= MenuStylerTheme.ColorFont;

    Windows.TextOutW(ACanvas.Handle,
      ARect.Right - dxCell*MenuStylerTheme.IndentSubmenuArrowPercents div 100,
      Y,
      @MenuStylerTheme.CharSubmenu,
      1);

    //block OS drawing of submenu arrow
    Windows.ExcludeClipRect(ACanvas.Handle,
      ARect.Right - dxCell*MenuStylerTheme.IndentRightPercents div 100,
      ARect.Top,
      ARect.Right,
      ARect.Bottom);
  end;
end;

procedure TWin32MenuStyler.HandleMenuPopup(Sender: TObject);
begin
  //it dont work!
  {
  if Sender is TPopupMenu then
    with (Sender as TPopupMenu) do
      ApplyBackColor(Handle, false);
  }
end;

initialization

  MenuStyler:= TWin32MenuStyler.Create;

  with MenuStylerTheme do
  begin
    ColorBk:= clDkGray;
    ColorBkSelected:= clNavy;
    ColorFont:= clWhite;
    ColorFontDisabled:= clMedGray;
    ColorFontShortcut:= clYellow;
    CharCheckmark:= #$2713;
    CharRadiomark:= #$25CF;
    CharSubmenu:= #$2BC8;
    FontName:= 'default';
    FontSize:= 9;
    IndentMinPercents:= 50;
    IndentBigPercents:= 300;
    IndentIconPercents:= 40;
    IndentRightPercents:= 250;
    IndentSubmenuArrowPercents:= 150;
  end;

finalization

  FreeAndNil(MenuStyler);

end.
