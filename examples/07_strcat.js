// Adapted from porffor bench/strcat.js
// Tests: string concatenation with +, _ljs_add helper

const a = "alpha";
const b = "beta";
const c = "gamma";

let result = a + " " + b + " " + c;
console.log(result);

let repeated = "";
for (let i = 0; i < 5; i = i + 1) {
  repeated = repeated + a + " ";
}
console.log(repeated);

let mixed = "x: " + 42 + ", y: " + 7;
console.log(mixed);
