// Adapted from porffor bench/indirect.js
// Tests: arrow functions, higher-order functions, closures

const double = (x) => x * 2;
const add = (a, b) => a + b;

console.log("double(5):", double(5));
console.log("add(3, 4):", add(3, 4));

const apply = (fn, val) => fn(val);
console.log("apply(double, 7):", apply(double, 7));

const numbers = [1, 2, 3, 4, 5];
let total = 0;
for (let n of numbers) {
  total = add(total, n);
}
console.log("sum:", total);

const makeAdder = (x) => {
  return (y) => x + y;
};
const add5 = makeAdder(5);
console.log("add5(3):", add5(3));
console.log("add5(10):", add5(10));
