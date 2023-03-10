import 'dart:convert';

bool debug_print = !true;

class Cell {
  final int _row;
  final int _col;
  int get row => _row;
  int get col => _col;

  String _entry;
  set entry(entry) {
    _entry = entry;
  }

  String get entry => _entry;
  void set([String entry = 'X']) {
    _entry = entry;
  }

  void disallow() {
    _entry = 'O';
  }

  bool get isNotSet => !isSet;
  bool get isSet => entry != 'x' && entry != '.' && !isDisallowed;
  bool get isRequired => entry == 'x';
  bool get isDisallowed => entry == 'O';

  Cell(this._row, this._col, this._entry);

  @override
  String toString() {
    return 'R${_row}C$_col=$_entry';
  }

  Cell.fromJson(Map<String, dynamic> json)
      : _row = json['_row'],
        _col = json['_col'],
        _entry = json['_entry'];

  Map<String, dynamic> toJson() => {
        '_row': _row,
        '_col': _col,
        '_entry': _entry,
      };
}

class Grid {
  late List<List<Cell>> _grid = [];
  late int dimension;
  Cell? start;
  Cell? end;

  late List<List<Cell>> _solution = [];
  late List<int> _rowCount;
  late List<int> _colCount;

  String? _error;
  String? get error => _error;

  Grid(List<String> puzzle, List<int> rowCount, List<int> colCount) {
    dimension = puzzle.length;
    _grid = getSolution(puzzle);
    getStartEnd();
    if (_error != null) return;
    _rowCount = rowCount;
    _colCount = colCount;
  }

  Grid.solution(List<String> solution, List<String> puzzle) {
    dimension = puzzle.length;
    if (solution.length != dimension) {
      _error = 'Puzzle and Solution have different dimensions';
      return;
    }

    _grid = getSolution(puzzle);
    getStartEnd();
    if (_error != null) return;

    _solution = getSolution(solution);
    _rowCount = List.filled(dimension, 0);
    _colCount = List.filled(dimension, 0);
    for (var r = 0; r < dimension; r++) {
      var row = _solution[r];
      for (var c = 0; c < dimension; c++) {
        var cell = row[c];
        if (cell.isRequired) {
          _rowCount[r]++;
          _colCount[c]++;
        }
      }
    }
  }

  void getStartEnd() {
    for (var r = 0; r < dimension; r++) {
      var row = _grid[r];
      for (var c = 0; c < dimension; c++) {
        var cell = row[c];
        if (cell.isRequired &&
            (r == 0 || r == dimension - 1 || c == 0 || c == dimension - 1)) {
          if (start == null) {
            start = cell;
          } else if (end == null) {
            end = cell;
          } else {
            _error = 'More than two potential start/end cells';
            return;
          }
        }
      }
    }
    if (start == null || end == null) {
      _error = 'No start/end cell';
      return;
    }
  }

  List<List<Cell>> getSolution(List<String> rows) {
    if (rows.length != dimension ||
        rows.any((element) => element.length != dimension)) {
      _error = 'Require $dimension rows of $dimension cells';
      return [];
    }
    var grid = <List<Cell>>[];
    for (var r = 0; r < dimension; r++) {
      var row = rows[r];
      var cells = <Cell>[];
      grid.add(cells);
      for (var c = 0; c < dimension; c++) {
        var entry = row[c];
        cells.add(Cell(r, c, entry));
      }
    }
    return grid;
  }

  @override
  String toString() {
    var text = ' ' + _colCount.join('') + '\n';
    for (var r = 0; r < dimension; r++) {
      text += _rowCount[r].toString() +
          _grid[r].fold(
              '',
              (p, c) =>
                  p +
                  (c == start
                      ? 'S'
                      : c == end
                          ? 'E'
                          : c.entry)) +
          '\n';
    }
    return text;
  }

  String solutionString(List<List<Cell>> solution) {
    var text = '';
    for (var r = 0; r < dimension; r++) {
      text += ' ' + solution[r].fold('', (p, c) => p + (c.entry)) + '\n';
      ;
    }
    return text;
  }

  Iterable<String> solutions() sync* {
    var l = json.decode(json.encode(_grid));
    var solution = List<List<Cell>>.from(
        l.map((r) => List<Cell>.from(r.map((e) => Cell.fromJson(e)))));
    var cell = solution[start!.row][start!.col];
    cell.set();
    yield* backtrack(solution, cell, cell);
    return;
  }

  Iterable<Cell> neighbours(List<List<Cell>> solution, Cell cell) {
    var cells = <Cell>[];
    if (cell.row > 0) cells.add(solution[cell.row - 1][cell.col]);
    if (cell.row < dimension - 1) cells.add(solution[cell.row + 1][cell.col]);
    if (cell.col > 0) cells.add(solution[cell.row][cell.col - 1]);
    if (cell.col < dimension - 1) cells.add(solution[cell.row][cell.col + 1]);
    return cells;
  }

  var iterations = 0;
  Iterable<String> backtrack(
      List<List<Cell>> solution, Cell currentCell, Cell priorCell) sync* {
    var nextCells = neighbours(solution, currentCell)
        .where((cell) => cell.isNotSet && !cell.isDisallowed)
        .toList();
    for (var nextCell in nextCells) {
      setCell(nextCell); // Placeholder until next cell processed
      currentCell.entry = getEntry(priorCell.row, priorCell.col,
          currentCell.row, currentCell.col, nextCell.row, nextCell.col);
      if (cellOK(solution, nextCell.row, nextCell.col)) {
        iterations++;
        if (nextCell.row != end!.row || nextCell.col != end!.col) {
          yield* backtrack(solution, nextCell, currentCell);
        } else {
          // Complete if no unset grid cells
          if (gridOK(solution) &&
              !solution.any((row) => row.any((cell) => cell.isRequired))) {
            yield solutionString(solution);
          }
        }
      }

      undoSetCell();
    }
    return;
  }

  List<Cell> undoCells = [];
  List<String> undoEntries = [];
  List<int> undoIndexes = [];
  void rememberCell(Cell cell, [bool combine = false]) {
    if (!combine) {
      // New undo stack item
      undoIndexes.add(undoCells.length);
    }
    undoCells.add(cell);
    undoEntries.add(cell.entry);
  }

  void setCell(Cell cell, [bool combine = false, String entry = 'X']) {
    rememberCell(cell, combine);
    cell.set(entry);
  }

  void disallowCell(Cell cell, [bool combine = false]) {
    rememberCell(cell, combine);
    cell.disallow();
  }

  void undoSetCell() {
    assert(undoIndexes.isNotEmpty);
    while (undoCells.length > undoIndexes.last) {
      var cell = undoCells.removeLast();
      cell.entry = undoEntries.removeLast();
    }
    undoIndexes.removeLast();
  }

  bool cellOK(List<List<Cell>> solution, int row, int col,
      [bool exact = false]) {
    var rowCells = solution[row];
    var rowSetCells = rowCells.where((cell) => cell.isSet || cell.isRequired);
    var rowEntries = rowSetCells.length;
    if (rowEntries > _rowCount[row]) return false;
    if (exact && rowEntries != _rowCount[row]) return false;

    var colCells = solution.expand((row) => [row[col]]);
    var colSetCells = colCells.where((cell) => cell.isSet || cell.isRequired);
    var colEntries = colSetCells.length;
    if (colEntries > _colCount[col]) return false;
    if (exact && colEntries != _colCount[col]) return false;

    // Optimisation to disallow cells that are known not to be posible
    // and then preset cells that must then be set
    // Can reduce number of iterations by half but runs slower

    var rowUpdate = updateRow(solution, row);
    var colUpdate = updateCol(solution, col);
    while (rowUpdate || colUpdate) {
      var rowUpdateOld = rowUpdate;
      var colUpdateOld = colUpdate;
      rowUpdate = false;
      colUpdate = false;

      if (colUpdateOld) {
        for (var row = 0; row < dimension; row++) {
          rowUpdate = updateRow(solution, row);
        }
      }
      if (rowUpdateOld) {
        for (var col = 0; col < dimension; col++) {
          colUpdate = updateCol(solution, col);
        }
      }
    }

    return true;
  }

  bool updateCol(List<List<Cell>> solution, int col) {
    var colUpdate = false;
    var colCells = solution.expand((row) => [row[col]]);
    var colSetCells = colCells.where((cell) => cell.isSet || cell.isRequired);
    var colEntries = colSetCells.length;
    var colUnsetCells = colCells
        .where((cell) => !(cell.isSet || cell.isRequired || cell.isDisallowed));
    if (colEntries == _colCount[col]) {
      for (var cell in colUnsetCells) {
        disallowCell(cell, true);
        colUpdate = true;
      }
    }
    var colDisallowed = colCells.where((cell) => cell.isDisallowed).length;
    if (_colCount[col] + colDisallowed == dimension) {
      for (var cell in colUnsetCells.where((cell) => !cell.isDisallowed)) {
        setCell(cell, true, 'x');
        colUpdate = true;
      }
    }
    return colUpdate;
  }

  bool updateRow(List<List<Cell>> solution, int row) {
    var rowUpdate = false;
    var rowCells = solution[row];
    var rowSetCells = rowCells.where((cell) => cell.isSet || cell.isRequired);
    var rowEntries = rowSetCells.length;
    var rowUnsetCells = rowCells
        .where((cell) => !(cell.isSet || cell.isRequired || cell.isDisallowed));
    if (rowEntries == _rowCount[row]) {
      for (var cell in rowUnsetCells) {
        disallowCell(cell, true);
        rowUpdate = true;
      }
    }
    var rowDisallowed = rowCells.where((cell) => cell.isDisallowed).length;
    if (_rowCount[row] + rowDisallowed == dimension) {
      for (var cell in rowUnsetCells.where((cell) => !cell.isDisallowed)) {
        setCell(cell, true, 'x');
        rowUpdate = true;
      }
    }
    return rowUpdate;
  }

  bool gridOK(List<List<Cell>> solution) {
    for (var i = 0; i < dimension; i++) {
      if (!cellOK(solution, i, i, true)) return false;
    }
    return true;
  }

  String getEntry(int r1, int c1, int r2, int c2, int r3, int c3) {
    if (r1 < r2) {
      if (c2 == c3) return '???';
      if (c2 < c3) return '???';
      if (c2 > c3) return '???';
      assert(false, 'Should not happen!');
    } else if (r1 > r2) {
      if (c2 == c3) return '???';
      if (c2 < c3) return '???';
      if (c2 > c3) return '???';
      assert(false, 'Should not happen!');
    } else if (c1 < c2) {
      if (r2 == r3) return '???';
      if (r2 < r3) return '???';
      if (r2 > r3) return '???';
      assert(false, 'Should not happen!');
    } else if (c1 > c2) {
      if (r2 == r3) return '???';
      if (r2 < r3) return '???';
      if (r2 > r3) return '???';
      assert(false, 'Should not happen!');
    } else {
      if (c2 == c3) return '???';
      if (r2 == r3) return '???';
      assert(false, 'Should not happen!');
    }
    return 'X';
  }
}

class TrainTracks {
  late final Grid _grid;
  String? _error;
  String? get error => _error;

  TrainTracks(List<String> puzzle, List<int> rowCount, List<int> colCount) {
    _grid = Grid(puzzle, rowCount, colCount);
    _error = _grid.error;
  }

  TrainTracks.solution(List<String> solution, List<String> puzzle) {
    _grid = Grid.solution(solution, puzzle);
    _error = _grid.error;
  }

  @override
  String toString() {
    return '$_grid';
  }

  var _solutionCount = 0;
  void solve() {
    if (error != null) {
      print(error);
      return;
    }

    print(this);
    for (var solution in _grid.solutions()) {
      print(solution);
      _solutionCount++;
    }
    print('Solutions: $_solutionCount, ${_grid.iterations} iterations\n');
  }
}

void printDebug(String msg) {
  if (debug_print) print(msg);
}
