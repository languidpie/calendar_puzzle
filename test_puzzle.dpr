program test_puzzle;

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

var
  PassCount, FailCount: Integer;

procedure Check(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('  PASS: ', TestName);
    Inc(PassCount);
  end
  else
  begin
    WriteLn('  FAIL: ', TestName);
    Inc(FailCount);
  end;
end;

function MakeShape(const Coords: array of Integer): TPieceShape;
var
  I: Integer;
begin
  SetLength(Result, Length(Coords) div 2);
  for I := 0 to High(Result) do
  begin
    Result[I].Row := Coords[I * 2];
    Result[I].Col := Coords[I * 2 + 1];
  end;
end;

// ===== Test groups =====

procedure TestNormalizeShape;
var
  S, N: TPieceShape;
begin
  WriteLn('--- NormalizeShape ---');

  // Already normalized: origin-based sorted shape unchanged
  S := MakeShape([0,0, 0,1, 1,0]);
  N := NormalizeShape(S);
  Check((N[0].Row = 0) and (N[0].Col = 0) and
        (N[1].Row = 0) and (N[1].Col = 1) and
        (N[2].Row = 1) and (N[2].Col = 0),
    'Already-normalized shape unchanged');

  // Off-origin: translated to origin
  S := MakeShape([3,5, 3,6, 4,5]);
  N := NormalizeShape(S);
  Check((N[0].Row = 0) and (N[0].Col = 0) and
        (N[1].Row = 0) and (N[1].Col = 1) and
        (N[2].Row = 1) and (N[2].Col = 0),
    'Off-origin shape translated to origin');

  // Negative coords normalized
  S := MakeShape([-2,-3, -2,-2, -1,-3]);
  N := NormalizeShape(S);
  Check((N[0].Row = 0) and (N[0].Col = 0) and
        (N[1].Row = 0) and (N[1].Col = 1) and
        (N[2].Row = 1) and (N[2].Col = 0),
    'Negative coords translated to origin');

  // Unsorted input gets sorted row-major
  S := MakeShape([1,0, 0,1, 0,0]);
  N := NormalizeShape(S);
  Check((N[0].Row = 0) and (N[0].Col = 0) and
        (N[1].Row = 0) and (N[1].Col = 1) and
        (N[2].Row = 1) and (N[2].Col = 0),
    'Unsorted input sorted row-major');

  // Single cell
  S := MakeShape([5,7]);
  N := NormalizeShape(S);
  Check((Length(N) = 1) and (N[0].Row = 0) and (N[0].Col = 0),
    'Single cell normalizes to (0,0)');
end;

procedure TestRotateClockwise;
var
  S, R: TPieceShape;
  I: Integer;
begin
  WriteLn('--- RotateClockwise ---');

  // Horizontal domino (0,0)(0,1) -> vertical (0,0)(1,0)
  S := MakeShape([0,0, 0,1]);
  R := RotateClockwise(S);
  Check((R[0].Row = 0) and (R[0].Col = 0) and
        (R[1].Row = 1) and (R[1].Col = 0),
    'Horizontal domino -> vertical');

  // L-tromino rotation: (0,0)(1,0)(1,1) -> check it changes
  S := MakeShape([0,0, 1,0, 1,1]);
  R := RotateClockwise(S);
  Check(not ShapesAreIdentical(S, R),
    'L-tromino rotation produces different shape');

  // 4 rotations = identity
  S := MakeShape([0,0, 0,1, 0,2, 1,0, 1,1]);
  R := NormalizeShape(S);
  for I := 1 to 4 do
    R := RotateClockwise(R);
  S := NormalizeShape(S);
  Check(ShapesAreIdentical(R, S),
    '4 rotations = identity');
end;

procedure TestMirrorHorizontally;
var
  S, M: TPieceShape;
begin
  WriteLn('--- MirrorHorizontally ---');

  // Symmetric shape unchanged: vertical domino
  S := MakeShape([0,0, 1,0]);
  M := MirrorHorizontally(S);
  Check(ShapesAreIdentical(NormalizeShape(S), M),
    'Symmetric shape (vertical domino) unchanged');

  // L-tromino mirror produces different shape
  S := MakeShape([0,0, 1,0, 1,1]);
  M := MirrorHorizontally(S);
  Check(not ShapesAreIdentical(NormalizeShape(S), M),
    'L-tromino mirror produces different shape');

  // Double mirror = identity
  S := MakeShape([0,0, 0,1, 1,0, 2,0, 2,1]);
  M := MirrorHorizontally(MirrorHorizontally(S));
  Check(ShapesAreIdentical(NormalizeShape(S), M),
    'Double mirror = identity');
end;

procedure TestShapesAreIdentical;
var
  A, B: TPieceShape;
begin
  WriteLn('--- ShapesAreIdentical ---');

  A := MakeShape([0,0, 0,1, 1,0]);
  B := MakeShape([0,0, 0,1, 1,0]);
  Check(ShapesAreIdentical(A, B), 'Same shapes -> True');

  B := MakeShape([0,0, 0,1, 1,1]);
  Check(not ShapesAreIdentical(A, B), 'Different shapes -> False');

  B := MakeShape([0,0, 0,1]);
  Check(not ShapesAreIdentical(A, B), 'Different lengths -> False');
end;

procedure TestOrientationCounts;
var
  I, J, MinR, MinC: Integer;
  Expected: array[1..TOTAL_PIECES] of Integer;
  S: TPieceShape;
begin
  WriteLn('--- OrientationCounts ---');

  DefinePieceShapes;

  Expected[1] := 2;
  Expected[2] := 8;
  Expected[3] := 8;
  Expected[4] := 8;
  Expected[5] := 8;
  Expected[6] := 4;
  Expected[7] := 4;
  Expected[8] := 4;

  for I := 1 to TOTAL_PIECES do
    Check(Length(PieceOrientations[I]) = Expected[I],
      Format('Piece %d has %d orientations (got %d)',
        [I, Expected[I], Length(PieceOrientations[I])]));

  // Each piece's first orientation is normalized (min row=0, min col=0)
  for I := 1 to TOTAL_PIECES do
  begin
    S := PieceOrientations[I][0];
    MinR := S[0].Row;
    MinC := S[0].Col;
    for J := 1 to High(S) do
    begin
      if S[J].Row < MinR then MinR := S[J].Row;
      if S[J].Col < MinC then MinC := S[J].Col;
    end;
    Check((MinR = 0) and (MinC = 0),
      Format('Piece %d first orientation is normalized (minR=%d, minC=%d)', [I, MinR, MinC]));
  end;
end;

procedure TestSetupBoardForDate;
begin
  WriteLn('--- SetupBoardForDate ---');

  // Jan 1: month at (0,0), day at (2,0)
  SetupBoardForDate(1, 1);
  Check((MonthTargetRow = 0) and (MonthTargetCol = 0),
    'Jan target at row 0, col 0');
  Check((DayTargetRow = 2) and (DayTargetCol = 0),
    'Day 1 target at row 2, col 0');
  Check(PuzzleBoard[0, 0] = CELL_TARGET, 'Jan cell is TARGET');
  Check(PuzzleBoard[2, 0] = CELL_TARGET, 'Day 1 cell is TARGET');

  // Dec 31: month at (1,5), day at (6,2)
  SetupBoardForDate(12, 31);
  Check((MonthTargetRow = 1) and (MonthTargetCol = 5),
    'Dec target at row 1, col 5');
  Check((DayTargetRow = 6) and (DayTargetCol = 2),
    'Day 31 target at row 6, col 2');

  // Wall cells present
  Check(PuzzleBoard[0, 6] = CELL_WALL, 'Cell (0,6) is WALL');
  Check(PuzzleBoard[1, 6] = CELL_WALL, 'Cell (1,6) is WALL');
  Check(PuzzleBoard[6, 6] = CELL_WALL, 'Cell (6,6) is WALL');

  // Jun at row 0, col 5
  SetupBoardForDate(6, 15);
  Check((MonthTargetRow = 0) and (MonthTargetCol = 5),
    'Jun target at row 0, col 5');

  // Jul at row 1, col 0
  SetupBoardForDate(7, 15);
  Check((MonthTargetRow = 1) and (MonthTargetCol = 0),
    'Jul target at row 1, col 0');
end;

procedure TestPrecomputePlacements;
var
  Row, Col, EmptyCount, TotalPlacements: Integer;
begin
  WriteLn('--- PrecomputePlacements ---');

  DefinePieceShapes;
  SetupBoardForDate(3, 2);
  PrecomputePlacements;

  // Count empty cells: 7x7=49 - 6 walls - 2 targets = 41
  EmptyCount := 0;
  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
      if PuzzleBoard[Row, Col] = CELL_EMPTY then
        Inc(EmptyCount);
  Check(EmptyCount = 41, Format('41 empty cells for Mar 2 (got %d)', [EmptyCount]));

  // Wall cells have 0 placements
  Check(CellPlacementCount[0, 6] = 0, 'Wall cell (0,6) has 0 placements');

  // Target cells have 0 placements
  Check(CellPlacementCount[MonthTargetRow, MonthTargetCol] = 0,
    'Month target cell has 0 placements');

  // Total placements > 100
  TotalPlacements := 0;
  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
      TotalPlacements := TotalPlacements + CellPlacementCount[Row, Col];
  Check(TotalPlacements > 100,
    Format('Total placements > 100 (got %d)', [TotalPlacements]));
end;

procedure TestHasDeadSpace;
var
  Row, Col: Integer;
begin
  WriteLn('--- HasDeadSpace ---');

  // Clean board (no pieces placed) -> no dead space
  DefinePieceShapes;
  SetupBoardForDate(3, 2);
  Check(not HasDeadSpace, 'Clean board has no dead space');

  // Isolated 1-cell pocket -> detected
  // Create a pocket by walling off a single cell with pieces
  SetupBoardForDate(1, 8);  // fresh board
  // Place walls around cell (3,3) to isolate it
  // (3,3) is empty; surround it
  PuzzleBoard[2, 3] := 1;
  PuzzleBoard[4, 3] := 1;
  PuzzleBoard[3, 2] := 1;
  PuzzleBoard[3, 4] := 1;
  Check(HasDeadSpace, 'Isolated 1-cell pocket detected');

  // Large connected region -> not dead space
  SetupBoardForDate(3, 2);
  Check(not HasDeadSpace, '5+ cell region is not dead space');

  // 4-cell region -> dead space
  SetupBoardForDate(1, 1);
  // Fill the entire board except a 4-cell pocket
  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
      if PuzzleBoard[Row, Col] = CELL_EMPTY then
        PuzzleBoard[Row, Col] := 1;  // fill with piece 1
  // Clear a 2x2 block to create a 4-cell region
  PuzzleBoard[3, 3] := CELL_EMPTY;
  PuzzleBoard[3, 4] := CELL_EMPTY;
  PuzzleBoard[4, 3] := CELL_EMPTY;
  PuzzleBoard[4, 4] := CELL_EMPTY;
  Check(HasDeadSpace, '4-cell isolated region is dead space');
end;

procedure SolveAndVerifyDate(Month, Day: Word; const DateLabel: string);
var
  Row, Col, CellValue, I: Integer;
  PieceCellCounts: array[1..TOTAL_PIECES] of Integer;
  HasEmpty, HasInvalid: Boolean;
  Solved: Boolean;
begin
  DefinePieceShapes;
  SetupBoardForDate(Month, Day);
  PrecomputePlacements;
  FillChar(PieceIsPlaced, SizeOf(PieceIsPlaced), 0);

  Solved := SolveByBacktracking;
  Check(Solved, DateLabel + ': solution found');
  if not Solved then Exit;

  // No empty cells remain
  HasEmpty := False;
  HasInvalid := False;
  for I := 1 to TOTAL_PIECES do
    PieceCellCounts[I] := 0;

  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
    begin
      CellValue := PuzzleBoard[Row, Col];
      if CellValue = CELL_EMPTY then
        HasEmpty := True
      else if (CellValue <> CELL_WALL) and (CellValue <> CELL_TARGET) then
      begin
        if (CellValue < 1) or (CellValue > TOTAL_PIECES) then
          HasInvalid := True
        else
          Inc(PieceCellCounts[CellValue]);
      end;
    end;

  Check(not HasEmpty, DateLabel + ': no empty cells remain');
  Check(not HasInvalid, DateLabel + ': no invalid cell values');

  // Piece 1 covers 6 cells, pieces 2-8 cover 5 cells each
  Check(PieceCellCounts[1] = 6,
    Format('%s: piece 1 covers 6 cells (got %d)', [DateLabel, PieceCellCounts[1]]));

  for I := 2 to TOTAL_PIECES do
    Check(PieceCellCounts[I] = 5,
      Format('%s: piece %d covers 5 cells (got %d)', [DateLabel, I, PieceCellCounts[I]]));
end;

procedure TestFullSolve;
begin
  WriteLn('--- Full Solve ---');
  SolveAndVerifyDate(1, 1, 'Jan 1');
  SolveAndVerifyDate(6, 30, 'Jun 30');
  SolveAndVerifyDate(12, 31, 'Dec 31');
  SolveAndVerifyDate(7, 4, 'Jul 4');
  SolveAndVerifyDate(3, 2, 'Mar 2');
end;

begin
  PassCount := 0;
  FailCount := 0;

  TestNormalizeShape;
  TestRotateClockwise;
  TestMirrorHorizontally;
  TestShapesAreIdentical;
  TestOrientationCounts;
  TestSetupBoardForDate;
  TestPrecomputePlacements;
  TestHasDeadSpace;
  TestFullSolve;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [PassCount, FailCount, PassCount + FailCount]));

  if FailCount > 0 then
    Halt(1);
end.
