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

begin
  try
    RunPuzzle;
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
