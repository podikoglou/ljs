// Adapted from mquickjs test_closure.js
// Tests: nested closures, private state via closures, recursive named function expressions

// nested closures capturing outer variables
var log = "";
function f(a, b, c) {
  var x = 10;
  function g(d) {
    function h() {
      log += "d=" + d + ",";
      log += "x=" + x + ",";
    }
    log += "b=" + b + ",";
    log += "c=" + c + ",";
    h();
  }
  g(4);
  return g;
}

var g1 = f(1, 2, 3);
g1(5);
console.log(log);

// private state via closures
function makeCounter() {
  var val = 0;
  function get() {
    return val;
  }
  function set(n) {
    val = n;
  }
  return { get: get, set: set };
}

var counter = makeCounter();
console.log(counter.get());
counter.set(10);
console.log(counter.get());
counter.set(42);
console.log(counter.get());

// function expression with inner helper (closures capture outer scope)
var expr_func = function(n) {
  function helper(n) {
    return expr_func(n - 1);
  }
  if (n === 0) return 0;
  else return helper(n);
};
console.log(expr_func(1));
console.log(expr_func(5));

// recursive fibonacci via function declaration
function fib(n) {
  if (n <= 0) return 0;
  else if (n === 1) return 1;
  else return fib(n - 1) + fib(n - 2);
}
console.log(fib(6));
console.log(fib(10));
