// Adapted from porffor bench/interp-dispatch.js
// Tests: function declarations, while, prefix --, compound assignment *= +=, return

function factorial(n) {
  let result = 1;
  while (n > 1) {
    result *= n;
    n -= 1;
  }
  return result;
}

console.log("5! =", factorial(5));
console.log("10! =", factorial(10));
console.log("0! =", factorial(0));
console.log("1! =", factorial(1));
