// Adapted from porffor bench/loops.js
// Tests: for...of, for(;;), bracket access, compound assignment +=, ++

let data = [10, 20, 30, 40, 50];

let sum1 = 0;
for (let x of data) {
  sum1 += x;
}
console.log("for..of sum:", sum1);

let len = 5;
let sum2 = 0;
for (let i = 0; i < len; i++) {
  sum2 += data[i];
}
console.log("for(;;) sum:", sum2);

let sum3 = 0;
let j = 0;
while (j < len) {
  sum3 += data[j];
  j++;
}
console.log("while sum:", sum3);
