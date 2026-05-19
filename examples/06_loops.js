// Adapted from porffor bench/loops.js
// Tests: for...of, for(;;) with .length, bracket access, compound assignment +=

let data = [10, 20, 30, 40, 50];

let sum1 = 0;
for (let x of data) {
  sum1 += x;
}
console.log("for..of sum:", sum1);

let sum2 = 0;
for (let i = 0; i < data.length; i = i + 1) {
  sum2 += data[i];
}
console.log("for(;;) sum:", sum2);

let sum3 = 0;
let len = data.length;
for (let i = 0; i < len; i = i + 1) {
  sum3 += data[i];
}
console.log("cached length sum:", sum3);
