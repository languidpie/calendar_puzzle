unit CalendarPuzzleSolver;

{$IFDEF FPC}
{$mode delphi}
{$ENDIF}

interface

const
  BOARD_SIZE = 7;
  TOTAL_PIECES = 8;
  CELL_WALL   = -2;
  CELL_EMPTY  = -1;
  CELL_TARGET = 0;

  MONTH_NAMES: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

  PIECE_COLORS: array[1..8] of string = (
    #27'[31m',   // Red
    #27'[32m',   // Green
    #27'[33m',   // Yellow
    #27'[34m',   // Blue
    #27'[35m',   // Magenta
    #27'[36m',   // Cyan
    #27'[91m',   // Bright Red
    #27'[92m'    // Bright Green
  );
  DATE_HIGHLIGHT = #27'[97;41m';
  ANSI_RESET     = #27'[0m';

type
  TBoardPosition = record
    Row, Col: Integer;
  end;
  TPieceShape = array of TBoardPosition;
  TPieceOrientations = array of TPieceShape;

  TPlacement = record
    PieceNumber: Integer;
    CellCount: Integer;
    Cells: array[0..5] of TBoardPosition;  // absolute board positions (max 6 cells)
  end;

var
  PuzzleBoard: array[0..BOARD_SIZE-1, 0..BOARD_SIZE-1] of Integer;
  PieceOrientations: array[1..TOTAL_PIECES] of TPieceOrientations;
  PieceIsPlaced: array[1..TOTAL_PIECES] of Boolean;
  TodayMonth, TodayDay: Word;
  MonthTargetRow, MonthTargetCol, DayTargetRow, DayTargetCol: Integer;

  // For each board cell: list of placements whose first shape cell lands here
  CellPlacements: array[0..BOARD_SIZE-1, 0..BOARD_SIZE-1] of array of TPlacement;
  CellPlacementCount: array[0..BOARD_SIZE-1, 0..BOARD_SIZE-1] of Integer;

function NormalizeShape(const Shape: TPieceShape): TPieceShape;
function RotateClockwise(const Shape: TPieceShape): TPieceShape;
function MirrorHorizontally(const Shape: TPieceShape): TPieceShape;
function ShapesAreIdentical(const ShapeA, ShapeB: TPieceShape): Boolean;
procedure GenerateOrientations(PieceNumber: Integer; const BaseShape: TPieceShape);
procedure DefinePieceShapes;
procedure SetupBoard;
procedure SetupBoardForDate(Month, Day: Word);
procedure PrecomputePlacements;
function HasDeadSpace: Boolean;
function SolveByBacktracking: Boolean;
procedure RunPuzzle;

implementation

uses
  {$IFDEF FPC}
  SysUtils
    {$IFDEF MSWINDOWS}, Windows{$ENDIF}
  {$ELSE}
  System.SysUtils, Winapi.Windows
  {$ENDIF};

procedure SortPositionsRowMajor(var Positions: TPieceShape);
var
  Outer, Inner: Integer;
  Swap: TBoardPosition;
begin
  for Outer := 0 to High(Positions) - 1 do
    for Inner := Outer + 1 to High(Positions) do
      if (Positions[Inner].Row < Positions[Outer].Row) or
         ((Positions[Inner].Row = Positions[Outer].Row) and (Positions[Inner].Col < Positions[Outer].Col)) then
      begin
        Swap := Positions[Outer];
        Positions[Outer] := Positions[Inner];
        Positions[Inner] := Swap;
      end;
end;

function NormalizeShape(const Shape: TPieceShape): TPieceShape;
var
  Index, MinRow, MinCol: Integer;
begin
  SetLength(Result, Length(Shape));

  MinRow := Shape[0].Row;
  MinCol := Shape[0].Col;
  for Index := 1 to High(Shape) do
  begin
    if Shape[Index].Row < MinRow then MinRow := Shape[Index].Row;
    if Shape[Index].Col < MinCol then MinCol := Shape[Index].Col;
  end;

  for Index := 0 to High(Shape) do
  begin
    Result[Index].Row := Shape[Index].Row - MinRow;
    Result[Index].Col := Shape[Index].Col - MinCol;
  end;

  SortPositionsRowMajor(Result);
end;

// (r, c) -> (c, -r)
function RotateClockwise(const Shape: TPieceShape): TPieceShape;
var
  Index: Integer;
begin
  SetLength(Result, Length(Shape));
  for Index := 0 to High(Shape) do
  begin
    Result[Index].Row := Shape[Index].Col;
    Result[Index].Col := -Shape[Index].Row;
  end;
  Result := NormalizeShape(Result);
end;

// (r, c) -> (r, -c)
function MirrorHorizontally(const Shape: TPieceShape): TPieceShape;
var
  Index: Integer;
begin
  SetLength(Result, Length(Shape));
  for Index := 0 to High(Shape) do
  begin
    Result[Index].Row := Shape[Index].Row;
    Result[Index].Col := -Shape[Index].Col;
  end;
  Result := NormalizeShape(Result);
end;

function ShapesAreIdentical(const ShapeA, ShapeB: TPieceShape): Boolean;
var
  Index: Integer;
begin
  if Length(ShapeA) <> Length(ShapeB) then Exit(False);
  for Index := 0 to High(ShapeA) do
    if (ShapeA[Index].Row <> ShapeB[Index].Row) or (ShapeA[Index].Col <> ShapeB[Index].Col) then
      Exit(False);
  Result := True;
end;

// Up to 8 unique orientations: 4 rotations x 2 flip states.
procedure GenerateOrientations(PieceNumber: Integer; const BaseShape: TPieceShape);
var
  UniqueOrientations: TPieceOrientations;
  OrientationCount: Integer;
  RotatedShape, MirroredShape: TPieceShape;
  Rotation: Integer;

  procedure AddIfUnique(const Shape: TPieceShape);
  var
    Existing: Integer;
  begin
    for Existing := 0 to OrientationCount - 1 do
      if ShapesAreIdentical(UniqueOrientations[Existing], Shape) then Exit;
    UniqueOrientations[OrientationCount] := Shape;
    Inc(OrientationCount);
  end;

begin
  OrientationCount := 0;
  SetLength(UniqueOrientations, 8);

  RotatedShape := NormalizeShape(BaseShape);
  for Rotation := 0 to 3 do
  begin
    AddIfUnique(RotatedShape);
    MirroredShape := MirrorHorizontally(RotatedShape);
    AddIfUnique(MirroredShape);
    RotatedShape := RotateClockwise(RotatedShape);
  end;

  SetLength(UniqueOrientations, OrientationCount);
  PieceOrientations[PieceNumber] := UniqueOrientations;
end;

procedure AddPiece(PieceNumber: Integer; const Coords: array of Integer);
var
  Shape: TPieceShape;
  Index: Integer;
begin
  SetLength(Shape, Length(Coords) div 2);
  for Index := 0 to High(Shape) do
  begin
    Shape[Index].Row := Coords[Index * 2];
    Shape[Index].Col := Coords[Index * 2 + 1];
  end;
  GenerateOrientations(PieceNumber, Shape);
end;

procedure DefinePieceShapes;
begin
  AddPiece(1, [0,0, 0,1, 0,2, 1,0, 1,1, 1,2]);  // 2x3 rectangle
  AddPiece(2, [0,0, 0,1, 1,0, 1,1, 1,2]);         // P-pentomino
  AddPiece(3, [0,0, 0,1, 0,2, 0,3, 1,2]);         // L-shape variant
  AddPiece(4, [0,1, 0,2, 0,3, 1,0, 1,1]);         // S/Z-shape
  AddPiece(5, [0,0, 0,1, 1,0, 2,0, 3,0]);         // tall L
  AddPiece(6, [0,0, 0,1, 1,0, 2,0, 2,1]);         // C-shape
  AddPiece(7, [0,0, 0,1, 0,2, 1,0, 2,0]);         // L-shape
  AddPiece(8, [0,2, 1,0, 1,1, 1,2, 2,0]);         // S/Z variant
end;

procedure SetupBoardForDate(Month, Day: Word);
var
  Row, Col: Integer;
begin
  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
      PuzzleBoard[Row, Col] := CELL_EMPTY;

  // The physical puzzle board is not a perfect rectangle
  PuzzleBoard[0, 6] := CELL_WALL;
  PuzzleBoard[1, 6] := CELL_WALL;
  PuzzleBoard[6, 3] := CELL_WALL;
  PuzzleBoard[6, 4] := CELL_WALL;
  PuzzleBoard[6, 5] := CELL_WALL;
  PuzzleBoard[6, 6] := CELL_WALL;

  TodayMonth := Month;
  TodayDay := Day;

  // Jan-Jun in row 0, Jul-Dec in row 1
  MonthTargetRow := (Month - 1) div 6;
  MonthTargetCol := (Month - 1) mod 6;
  PuzzleBoard[MonthTargetRow, MonthTargetCol] := CELL_TARGET;

  // 7 days per row, starting at row 2
  DayTargetRow := 2 + (Day - 1) div 7;
  DayTargetCol := (Day - 1) mod 7;
  PuzzleBoard[DayTargetRow, DayTargetCol] := CELL_TARGET;
end;

procedure SetupBoard;
var
  Year: Word;
begin
  DecodeDate(Now, Year, TodayMonth, TodayDay);
  SetupBoardForDate(TodayMonth, TodayDay);
end;

procedure PrecomputePlacements;
var
  PieceNumber, OrientationIndex, AnchorRow, AnchorCol, CellIndex: Integer;
  CurrentShape: TPieceShape;
  PlaceRow, PlaceCol, FirstRow, FirstCol: Integer;
  Valid: Boolean;
  Placement: TPlacement;
  Count: Integer;
begin
  // Initialize counts to zero
  FillChar(CellPlacementCount, SizeOf(CellPlacementCount), 0);

  for PieceNumber := 1 to TOTAL_PIECES do
    for OrientationIndex := 0 to High(PieceOrientations[PieceNumber]) do
    begin
      CurrentShape := PieceOrientations[PieceNumber][OrientationIndex];

      for AnchorRow := 0 to BOARD_SIZE - 1 do
        for AnchorCol := 0 to BOARD_SIZE - 1 do
        begin
          // Check all cells are in bounds and not wall/target
          Valid := True;
          Placement.PieceNumber := PieceNumber;
          Placement.CellCount := Length(CurrentShape);

          for CellIndex := 0 to High(CurrentShape) do
          begin
            PlaceRow := AnchorRow + CurrentShape[CellIndex].Row;
            PlaceCol := AnchorCol + CurrentShape[CellIndex].Col;
            if (PlaceRow < 0) or (PlaceRow >= BOARD_SIZE) or
               (PlaceCol < 0) or (PlaceCol >= BOARD_SIZE) then
            begin
              Valid := False;
              Break;
            end;
            if (PuzzleBoard[PlaceRow, PlaceCol] = CELL_WALL) or
               (PuzzleBoard[PlaceRow, PlaceCol] = CELL_TARGET) then
            begin
              Valid := False;
              Break;
            end;
            Placement.Cells[CellIndex].Row := PlaceRow;
            Placement.Cells[CellIndex].Col := PlaceCol;
          end;

          if not Valid then Continue;

          // The first cell of the shape (in scan order) determines the index
          FirstRow := AnchorRow + CurrentShape[0].Row;
          FirstCol := AnchorCol + CurrentShape[0].Col;

          // Append to that cell's placement list
          Count := CellPlacementCount[FirstRow, FirstCol];
          if Count >= Length(CellPlacements[FirstRow, FirstCol]) then
            SetLength(CellPlacements[FirstRow, FirstCol], Count + 16);
          CellPlacements[FirstRow, FirstCol][Count] := Placement;
          Inc(CellPlacementCount[FirstRow, FirstCol]);
        end;
    end;
end;

function HasDeadSpace: Boolean;
var
  Visited: array[0..BOARD_SIZE-1, 0..BOARD_SIZE-1] of Boolean;

  function FloodFillCount(R, C: Integer): Integer;
  begin
    if (R < 0) or (R >= BOARD_SIZE) or (C < 0) or (C >= BOARD_SIZE) then Exit(0);
    if Visited[R, C] then Exit(0);
    if PuzzleBoard[R, C] <> CELL_EMPTY then Exit(0);
    Visited[R, C] := True;
    Result := 1 + FloodFillCount(R-1, C) + FloodFillCount(R+1, C)
                + FloodFillCount(R, C-1) + FloodFillCount(R, C+1);
  end;

var
  Row, Col: Integer;
begin
  FillChar(Visited, SizeOf(Visited), 0);
  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
      if (PuzzleBoard[Row, Col] = CELL_EMPTY) and not Visited[Row, Col] then
        if FloodFillCount(Row, Col) < 5 then
          Exit(True);
  Result := False;
end;

function SolveByBacktracking: Boolean;
var
  Row, Col, Index, CellIndex: Integer;
  P: TPlacement;
  CanPlace: Boolean;
begin
  // Find first empty cell (scan top-left to bottom-right)
  for Row := 0 to BOARD_SIZE - 1 do
    for Col := 0 to BOARD_SIZE - 1 do
    begin
      if PuzzleBoard[Row, Col] <> CELL_EMPTY then Continue;

      // Try each precomputed placement whose first cell covers (Row, Col)
      for Index := 0 to CellPlacementCount[Row, Col] - 1 do
      begin
        P := CellPlacements[Row, Col][Index];
        if PieceIsPlaced[P.PieceNumber] then Continue;

        // Check all cells are empty (bounds/walls already excluded at precompute time)
        CanPlace := True;
        for CellIndex := 0 to P.CellCount - 1 do
          if PuzzleBoard[P.Cells[CellIndex].Row, P.Cells[CellIndex].Col] <> CELL_EMPTY then
          begin
            CanPlace := False;
            Break;
          end;
        if not CanPlace then Continue;

        // Place piece
        for CellIndex := 0 to P.CellCount - 1 do
          PuzzleBoard[P.Cells[CellIndex].Row, P.Cells[CellIndex].Col] := P.PieceNumber;
        PieceIsPlaced[P.PieceNumber] := True;

        // Recurse (with dead-space pruning)
        if not HasDeadSpace then
          if SolveByBacktracking then Exit(True);

        // Unplace piece
        for CellIndex := 0 to P.CellCount - 1 do
          PuzzleBoard[P.Cells[CellIndex].Row, P.Cells[CellIndex].Col] := CELL_EMPTY;
        PieceIsPlaced[P.PieceNumber] := False;
      end;

      Exit(False);  // no placement worked — backtrack
    end;

  Result := True;  // all cells filled — solved
end;

procedure DisplaySolution;
var
  Row, Col, CellValue: Integer;
  OutputLine: string;
begin
  WriteLn;
  for Row := 0 to BOARD_SIZE - 1 do
  begin
    OutputLine := '';
    for Col := 0 to BOARD_SIZE - 1 do
    begin
      CellValue := PuzzleBoard[Row, Col];

      if CellValue = CELL_WALL then
        OutputLine := OutputLine + '     '
      else if CellValue = CELL_TARGET then
      begin
        if (Row = MonthTargetRow) and (Col = MonthTargetCol) then
          OutputLine := OutputLine + DATE_HIGHLIGHT + '[' + MONTH_NAMES[TodayMonth] + ']' + ANSI_RESET
        else
          OutputLine := OutputLine + DATE_HIGHLIGHT + Format('[%2d ]', [TodayDay]) + ANSI_RESET;
      end
      else if (CellValue >= 1) and (CellValue <= TOTAL_PIECES) then
        OutputLine := OutputLine + PIECE_COLORS[CellValue] + Format('  %d  ', [CellValue]) + ANSI_RESET
      else
        OutputLine := OutputLine + '  ?  ';
    end;
    WriteLn(OutputLine);
  end;
  WriteLn;
end;

{$IFDEF MSWINDOWS}
procedure EnableAnsiColors;
const
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
var
  ConsoleHandle: THandle;
  ConsoleMode: DWORD;
begin
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if ConsoleHandle <> INVALID_HANDLE_VALUE then
  begin
    GetConsoleMode(ConsoleHandle, ConsoleMode);
    SetConsoleMode(ConsoleHandle, ConsoleMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
end;
{$ENDIF}

procedure RunPuzzle;
var
  StartTime, ElapsedMilliseconds: Int64;
begin
  {$IFDEF MSWINDOWS}
  EnableAnsiColors;
  {$ENDIF}

  WriteLn('Calendar Puzzle Solver');
  WriteLn('=====================');

  DefinePieceShapes;
  SetupBoard;
  PrecomputePlacements;

  WriteLn(Format('Date: %s %d', [MONTH_NAMES[TodayMonth], TodayDay]));
  WriteLn('Solving...');

  FillChar(PieceIsPlaced, SizeOf(PieceIsPlaced), 0);

  StartTime := GetTickCount64;

  if SolveByBacktracking then
  begin
    ElapsedMilliseconds := GetTickCount64 - StartTime;
    WriteLn(Format('Solved in %d ms', [ElapsedMilliseconds]));
    DisplaySolution;
  end
  else
    WriteLn('No solution found!');
end;

end.
