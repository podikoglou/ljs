// Conway's Game of Life
// Prints 15 generations of a 30x30 grid with a Gosper Glider Gun and a lightweight spaceship.

var ROWS = 30;
var COLS = 30;
var GENERATIONS = 15;

function createGrid(rows, cols) {
  var grid = [];
  for (var r = 0; r < rows; r++) {
    grid[r] = [];
    for (var c = 0; c < cols; c++) {
      grid[r][c] = 0;
    }
  }
  return grid;
}

function copyGrid(grid) {
  var rows = grid.length;
  var cols = grid[0].length;
  var next = createGrid(rows, cols);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      next[r][c] = grid[r][c];
    }
  }
  return next;
}

function setCell(grid, row, col) {
  if (row >= 0 && row < grid.length && col >= 0 && col < grid[0].length) {
    grid[row][col] = 1;
  }
}

function countNeighbors(grid, row, col) {
  var count = 0;
  var rows = grid.length;
  var cols = grid[0].length;
  for (var dr = -1; dr <= 1; dr++) {
    for (var dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      var r = (row + dr + rows) % rows;
      var c = (col + dc + cols) % cols;
      count += grid[r][c];
    }
  }
  return count;
}

function step(grid) {
  var rows = grid.length;
  var cols = grid[0].length;
  var next = createGrid(rows, cols);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      var n = countNeighbors(grid, r, c);
      if (grid[r][c] === 1) {
        next[r][c] = (n === 2 || n === 3) ? 1 : 0;
      } else {
        next[r][c] = (n === 3) ? 1 : 0;
      }
    }
  }
  return next;
}

function render(grid, generation) {
  console.log("=== Generation " + generation + " ===");
  var lines = [];
  for (var r = 0; r < grid.length; r++) {
    var line = "";
    for (var c = 0; c < grid[r].length; c++) {
      line += grid[r][c] ? "#" : ".";
    }
    lines.push(line);
  }
  console.log(lines.join("\n"));
  console.log("");
}

function placeGliderGun(grid, startRow, startCol) {
  var cells = [
    [0,24],[1,22],[1,24],[2,12],[2,13],[2,20],[2,21],[2,34],[2,35],
    [3,11],[3,15],[3,20],[3,21],[3,34],[3,35],[4,0],[4,1],[4,10],
    [4,16],[4,20],[4,21],[5,0],[5,1],[5,10],[5,14],[5,16],[5,17],
    [5,22],[5,24],[6,10],[6,16],[6,24],[7,11],[7,15],[8,12],[8,13]
  ];
  for (var i = 0; i < cells.length; i++) {
    setCell(grid, startRow + cells[i][0], startCol + cells[i][1]);
  }
}

function placeLWSS(grid, startRow, startCol) {
  var cells = [
    [0,1],[0,4],[1,0],[2,0],[2,4],[3,0],[3,1],[3,2],[3,3]
  ];
  for (var i = 0; i < cells.length; i++) {
    setCell(grid, startRow + cells[i][0], startCol + cells[i][1]);
  }
}

var grid = createGrid(ROWS, COLS);

placeGliderGun(grid, 1, 0);
placeLWSS(grid, 20, 10);

for (var g = 0; g <= GENERATIONS; g++) {
  render(grid, g);
  grid = step(grid);
}
