# Calendar Puzzle Solver

A backtracking solver for the "A-Puzzle-A-Day" calendar puzzle.
The puzzle has a 7x7 board with month and day cells; the goal is to place
eight pieces so that exactly the current date's month and day remain uncovered.
The solver finds a valid placement and displays it with colour-coded ANSI output.

## Building

**Free Pascal (Linux/macOS/Windows):**

```
fpc calendar_puzzle.dpr
```

**Delphi:**

Open `calendar_puzzle.dproj` in the IDE and build normally.

## Running

```
./calendar_puzzle              # solve for today's date
./calendar_puzzle 20260306     # solve for March 6, 2026
```

Solves for the given date (or today if omitted) and prints the board:

```
Calendar Puzzle Solver
=====================
Date: Mar 3
Solving...
Solved in 1 ms

  1    1  [Mar]  2    2    2
  1    1    6    6    2    2
  1    1  [ 3 ]  6    7    7    7
  3    5    6    6    8    8    7
  3    5    5    5    5    8    7
  3    3    4    4    4    8    8
  3    4    4
```

(actual output includes ANSI colours)

## Tests

```
fpc test_puzzle.dpr && ./test_puzzle
```

Runs 105 tests covering shape normalisation, rotation, mirroring,
board setup for various dates, placement precomputation, dead-space
detection, and full solves for five representative dates.