// Fibonacci sequence - first 20 numbers

const fib = (n) => {
  if (n <= 1) {
    return n;
  }
  return fib(n - 1) + fib(n - 2);
};

for (const i of [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]) {
  console.log("fib(" + i + ") = " + fib(i));
}
