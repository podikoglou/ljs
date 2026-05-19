// Adapted from porffor bench/exceptions.js
// Tests: try/catch, throw, for(;;), error propagation, ++

let caught = 0;
for (let i = 0; i < 5; i++) {
  try {
    throw i;
  } catch (e) {
    caught++;
  }
}
console.log("caught:", caught);

try {
  let x = 10;
  if (x > 5) {
    throw "too big";
  }
  console.log("should not reach");
} catch (e) {
  console.log("error:", e);
}

function safeDivide(a, b) {
  if (b === 0) {
    throw "division by zero";
  }
  return a / b;
}

try {
  console.log("10/2 =", safeDivide(10, 2));
  console.log("10/0 =", safeDivide(10, 0));
} catch (e) {
  console.log("caught:", e);
}
