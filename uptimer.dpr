{APPTYPE CONSOLE}
program uptimer;

uses windows, messages, sysutils {, windwer};

const
 uStart = $0DE0;
 uwPrev = $0000;
 uwPlay = $0001;
 uwPause = $0002;
 uwStop = $0003;
 uwNext = $0004;
 uwVUp = $0005;
 uwVDw = $0006;
 uw5Lef = $0007;
 uw5rgt = $0008;
 uwLast = $0009;
 
var hwndHook,
 hWinamp: HWND;
 mMsg: Tmsg;
 hThread: Cardinal;
 tmp,
  OSVer: string;

function FormatSec(Sec: Cardinal; Uptime: Boolean): string;
var day,
 hour,
  min: Cardinal;
 
 function LZ(What: Cardinal): string;
 var tmp: string;
 begin
  tmp := IntToStr(What);
  if Length(tmp) = 1 then
   Result := '0' + tmp
  else
   Result := tmp;
 end;
 
begin
 // Day
 Day := Sec div 86400;
 Sec := Sec - Day * 86400;
 // Hour
 Hour := Sec div 3600;
 Sec := Sec - Hour * 3600;
 // Min
 Min := Sec div 60;
 Sec := Sec - Min * 60;
 // Sec
 if day > 0 then
  begin
   if Uptime then
    Result := Format('%dd %dh %sm %ss', [day, hour, LZ(Min), LZ(Sec)])
   else
    Result := Format('%s:%s:%s:%s', [LZ(day), LZ(hour), LZ(Min), LZ(Sec)])
  end
 else if hour > 0 then
  begin
   if Uptime then
    Result := Format('%dh %sm %ss', [hour, LZ(Min), LZ(Sec)])
   else
    Result := Format('%s:%s:%s', [LZ(hour), LZ(Min), LZ(Sec)])
  end
 else
  begin
   if Uptime then
    Result := Format('%sm %ss', [LZ(Min), LZ(Sec)])
   else
    Result := Format('%s:%s', [LZ(Min), LZ(Sec)]);
  end;
// Result :=
end;

function GetAmpTime(AmpHandle: HWND): string;
begin
 Result := FormatSec(SendMessage(AmpHandle, WM_USER, 0, 105) div 1000, False) + '/' + FormatSec(SendMessage(AmpHandle, WM_USER, 1, 105), False);
end;

function GetAmpHandle: HWND;
begin
 Result := FindWindow('Winamp v1.x', nil);
end;

function GetAmpKbs(AmpHandle: HWND): Cardinal;
begin
 Result := SendMessage(AmpHandle, WM_USER, 1, 126);
end;

function GetAmpKhz(AmpHandle: HWND): Cardinal;
begin
 Result := SendMessage(AmpHandle, WM_USER, 0, 126);
end;

function GetAmpStatus(AmpHandle: HWND): Cardinal;
begin
 Result := SendMessage(AmpHandle, WM_USER, 0, 104);
end;

function GetAmpTitle(AmpHandle: HWND): string;

 function DelBSpace(const S: string): string;
 var
  I, L: Integer;
 begin
  L := Length(S);
  I := 1;
  while (I <= L) and (S[I] = ' ') do
   Inc(I);
  Result := Copy(S, I, MaxInt);
 end;
 
 function DelESpace(const S: string): string;
 var
  I: Integer;
 begin
  I := Length(S);
  while (I > 0) and (S[I] = ' ') do
   Dec(I);
  Result := Copy(S, 1, I);
 end;
 
var Tmp: string;
 Fnd: Integer;
begin
 Result := '';
 if AmpHandle <> invalid_handle_value then
  begin
   SetLength(Result, 254);
   GetWindowText(AmpHandle, pChar(Result), 254);
   if Result <> '' then
    begin
     Fnd := Pos('.', Result);
     if Fnd <> 0 then Delete(Result, 1, Fnd + 1);
     Fnd := Pos('- Winamp', Result);
     if Fnd <> 0 then Delete(Result, Fnd, Length(Result));
     Tmp := Result;
     if Length(Tmp) > 0 then
      AnsiToOem(PChar(Tmp), PChar(Result));
     Delete(Result, Length(Result), 1);
    end;
  end;
end;

function MyWndProc(hw: hwnd; Mess: TMessage): LResult; stdcall;

 procedure AmpCmd(cmd: Integer);
 begin
  SendMessage(hWinamp, $111, cmd, 0);
 end;
 
begin
 case Mess.Msg of
  WM_HOTKEY: if Mess.wParam - uStart in [uwPrev..uwLast] then
    begin
     hWinamp := GetAmpHandle;
     case Mess.wParam - uStart of
      uwPrev: AmpCmd(40044);
      uwPlay: case GetAmpStatus(hWinamp) of
        1, 3: AmpCmd(40046);
       else
        AmpCmd(40045);
       end;
      uwStop: AmpCmd(40047);
      uwNext: AmpCmd(40048);
      uwVUp: AmpCmd(40059);
      uwVDw: AmpCmd(40058);
      uw5Lef: AmpCmd(40048);
      uw5rgt: AmpCmd(40044);
     end;
    end;
  WM_QUERYENDSESSION:
   begin
    halt(0);
   end;
 end;
 Result := 0;
end;

function AllocateHWnd(Method: pointer): HWND;
begin
 Result := CreateWindowEx(WS_EX_TOOLWINDOW, 'afxUptimerWnd',
  'AfxUptimerWnd', WS_POPUP {!0}, 0, 0, 0, 0, 0, 0, HInstance, nil);
 
 if Assigned(Method) then
  SetWindowLong(Result, GWL_WNDPROC, Longint(Method));
end;

procedure ThreadProc;
var f: TextFile;
 lpFrequency,
  lpPerformanceCount: Int64;
begin
 repeat
  AssignFile(f, ParamStr(1));
  Rewrite(f);
  hWinamp := GetAmpHandle;
  tmp := GetAmpTitle(hWinamp);
  case GetAmpStatus(hWinamp) of
   1, 3: writeln(f, tmp + ' [', GetAmpKbs(hWinamp), 'Kbs ', GetAmpKhz(hWinamp), 'Khz] [' + GetAmpTime(hWinamp) + ']');
  else
   begin
    QueryPerformanceFrequency(lpFrequency);
    QueryPerformanceCounter(lpPerformanceCount);
    writeln(f, OSVer + ' uptime: ' + FormatSec(Round(1000 * lpPerformanceCount / lpFrequency) div 1000, True));
   end
  end;
  CloseFile(f);
  Sleep(2000);
 until False;
end;

procedure ErrorRegHK(Key: string);
begin
 MessageBox(0, PChar('Unable to register "' + Key + '" hotkey'), PChar('Uptimer/np'), 0);
end;

begin
 if Length(ParamStr(1)) > 0 then
  begin

   OSVer := 'Win32';

   hwndHook := AllocateHwnd(@MyWndProc);

   if not RegisterHotKey(hwndHook, uStart + uwPrev, 0, 177) then ErrorRegHK('Prev');
   if not RegisterHotKey(hwndHook, uStart + uwPlay, 0, 179) then ErrorRegHK('Play/Pause');
   if not RegisterHotKey(hwndHook, uStart + uwVUp, MOD_ALT, 174) then ErrorRegHK('Vol +');
   if not RegisterHotKey(hwndHook, uStart + uwVDw, MOD_ALT, 175) then ErrorRegHK('Vol -');
   if not RegisterHotKey(hwndHook, uStart + uwStop, 0, 178) then ErrorRegHK('Stop');
   if not RegisterHotKey(hwndHook, uStart + uwNext, 0, 176) then ErrorRegHK('Next');

   hThread := CreateThread(nil, 0, @ThreadProc, nil, 0, hThread);

   repeat
    GetMessage(mmsg, hwndHook, 0, $FFFF);
    TranslateMessage(mmsg);
    DispatchMessage(mmsg);
   until False;
  end
 else

  CloseHandle(hThread);
 
 MessageBox(0, 'Try: uptimer.exe "filename"', 'uptimer/np by Dmitriy Stepanov', 0);
end.
d.

