program calendar_puzzle;

{$IFDEF FPC}
{$mode delphi}
{$ENDIF}
{$APPTYPE CONSOLE}

uses
  {$IFDEF FPC}
  SysUtils,
  {$ELSE}
  System.SysUtils,
  {$ENDIF}
  CalendarPuzzleSolver;

procedure PrintUsageAndHalt;
begin
  WriteLn('Usage: calendar_puzzle [yyyymmdd]');
  WriteLn('  No argument: solve for today''s date');
  WriteLn('  yyyymmdd:    solve for the given date (e.g. 20260306)');
  Halt(1);
end;

function IsAllDigits(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if (S[I] < '0') or (S[I] > '9') then
      Exit(False);
  Result := True;
end;

var
  Arg: string;
  Month, Day: Word;
begin
  try
    if ParamCount >= 1 then
    begin
      Arg := ParamStr(1);
      if (Length(Arg) <> 8) or not IsAllDigits(Arg) then
        PrintUsageAndHalt;
      Month := StrToInt(Copy(Arg, 5, 2));
      Day := StrToInt(Copy(Arg, 7, 2));
      RunPuzzleForDate(Month, Day);
    end
    else
      RunPuzzle;
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
