/**
 * Brainfuck Interpreter
 *
 * Brainfuck operates on a tape of 30,000 cells, each initialized to 0.
 * A data pointer starts at cell 0. Commands:
 *
 *   >  Move data pointer right
 *   <  Move data pointer left
 *   +  Increment current cell
 *   -  Decrement current cell
 *   .  Output current cell as ASCII character
 *   ,  Read one character of input, store ASCII value in current cell
 *   [  Jump past matching ] if current cell is 0
 *   ]  Jump back to matching [ if current cell is nonzero
 */

function brainfuck(program, input) {
  var TAPE_SIZE = 30000;
  var tape = [];
  for (var i = 0; i < TAPE_SIZE; i++) tape[i] = 0;

  var dp = 0;
  var ip = 0;
  var inputPos = 0;
  var output = "";

  // Precompute bracket matching for fast jumps
  var bracketMap = {};
  var stack = [];
  for (var i = 0; i < program.length; i++) {
    if (program[i] === "[") {
      stack.push(i);
    } else if (program[i] === "]") {
      var open = stack.pop();
      bracketMap[open] = i;
      bracketMap[i] = open;
    }
  }

  while (ip < program.length) {
    var cmd = program[ip];

    switch (cmd) {
      case ">":
        dp++;
        break;
      case "<":
        dp--;
        break;
      case "+":
        tape[dp] = (tape[dp] + 1) & 0xff;
        break;
      case "-":
        tape[dp] = (tape[dp] - 1) & 0xff;
        break;
      case ".":
        output += String.fromCharCode(tape[dp]);
        break;
      case ",":
        if (input && inputPos < input.length) {
          tape[dp] = input.charCodeAt(inputPos++);
        } else {
          tape[dp] = 0;
        }
        break;
      case "[":
        if (tape[dp] === 0) ip = bracketMap[ip];
        break;
      case "]":
        if (tape[dp] !== 0) ip = bracketMap[ip];
        break;
    }

    ip++;
  }

  return output;
}

// --- Examples ---

// Classic "Hello World!"
var helloWorld =
  "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>." +
  ">---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.";

console.log("Hello World:");
console.log(brainfuck(helloWorld));

// Simple: prints "Hi" (H=72, i=105)
var hi =
  "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++." +
  "+++++++++++++++++++++++++++++++++.";
console.log("Hi:");
console.log(brainfuck(hi));

// Cat program: echoes input back (reads and writes one character)
var cat = ",.";
console.log("Cat (input 'A'):");
console.log(brainfuck(cat, "A"));

// Add two single-digit numbers (e.g. '2' + '3' = 'e' (101) = char '5' offset)
// This takes two ASCII digits and outputs their sum as a character
var adder = ",>,.<.>";
console.log("Adder (input '23'):");
console.log(brainfuck(adder, "23"));
