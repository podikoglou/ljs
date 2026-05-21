// Adapted from mquickjs test_language.js
// Tests: bitwise ops (& | ^ ~ << >>), exponentiation (**), unary (+), inc/dec on members

// arithmetic
console.log(1 + 2);
console.log(1 - 2);
console.log(-1);
console.log(+2);
console.log(2 * 3);
console.log(4 / 2);
console.log(4 % 3);

// bitwise
console.log(4 << 2);
console.log(1 << 29);
console.log(1 << 30);
console.log((1 << 31) < 0);
console.log(-4 >> 1);
console.log(1 & 1);
console.log(0 | 1);
console.log(1 ^ 1);
console.log(~1);

// logical / comparison
console.log(!1);
console.log(1 < 2);
console.log(2 > 1);

// exponentiation
console.log(2 ** 8);

// 31-bit overflow
var a = 0x3fffffff;
console.log(a + 1);
a = -0x40000000;
console.log(-a);

// increment/decrement on variables
a = 1;
console.log(a++);
console.log(a);
a = 1;
console.log(++a);
console.log(a);
a = 1;
console.log(a--);
console.log(a);
a = 1;
console.log(--a);
console.log(a);

// increment/decrement on member expressions
var obj = {x: 1};
obj.x++;
console.log(obj.x);
obj.x--;
console.log(obj.x);
var arr = [1];
arr[0]++;
console.log(arr[0]);
arr[0]--;
console.log(arr[0]);
