local T = require("ljs_test")
local H = require("ljs_test_transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, transpile, read_file, run_js = H.transpile_ok, H.transpile, H.read_file, H.run_js

-- ============================================================================
-- Unit tests — helpers emission
-- ============================================================================

test("no helpers when unused", function()
  local code = transpile_ok("let x = 1;")
  assert(not code:find("_ljs_"), "expected no helpers")
end)

test("_ljs_add only when + used", function()
  local code = transpile_ok("let x = 1 * 2;")
  assert(not code:find("_ljs_add"), "expected no _ljs_add")
end)

test("transpile.HELPERS accessible", function()
  assert(type(transpile.HELPERS) == "table", "expected HELPERS table")
  assert(type(transpile.HELPERS._ljs_add) == "string", "expected _ljs_add helper")
  assert(type(transpile.HELPERS._ljs_log) == "string", "expected _ljs_log helper")
end)

-- ============================================================================
-- Unit tests — BUILTINS registry
-- ============================================================================

test("transpile.BUILTINS accessible", function()
  assert(type(transpile.BUILTINS) == "table", "expected BUILTINS table")
  assert(type(transpile.BUILTINS.console) == "table", "expected console entry")
  assert(type(transpile.BUILTINS.console.log) == "table", "expected console.log entry")
  assert_eq(transpile.BUILTINS.console.log.helper, "_ljs_log", "console.log helper name")
end)

test("shadowed console.log does not emit helper", function()
  local code = transpile_ok("let console = {}; console.log(x);")
  assert(not code:find("_ljs_log"), "shadowed console.log should not use helper")
  assert(code:find("console%.log"), "should emit plain member call")
end)

-- ============================================================================
-- Integration tests — example programs
-- ============================================================================

test("fibonacci produces correct output", function()
  local js = read_file("examples/01_fibonacci.js")
  local output = run_js(js)
  assert(output:find("fib%(0%) = 0"), "expected fib(0) = 0")
  assert(output:find("fib%(1%) = 1"), "expected fib(1) = 1")
  assert(output:find("fib%(10%) = 55"), "expected fib(10) = 55")
end)

test("fizzbuzz produces correct output", function()
  local js = read_file("examples/02_fizzbuzz.js")
  local output = run_js(js)
  assert(output:find("FizzBuzz"), "expected FizzBuzz")
  assert(output:find("Fizz"), "expected Fizz")
  assert(output:find("Buzz"), "expected Buzz")
end)

test("shapes produces correct output", function()
  local js = read_file("examples/03_shapes.js")
  local output = run_js(js)
  assert(output:find("Shape Areas"), "expected Shape Areas header")
  assert(output:find("Circle %(r=5%) = 78%.539"), "expected Circle area")
  assert(output:find("Rectangle %(3x4%) = 12"), "expected Rectangle area")
end)

test("caesar produces correct output", function()
  local js = read_file("examples/04_caesar.js")
  local output = run_js(js)
  assert(output:find("Original: hello world"), "expected Original line")
  assert(output:find("H shifted by 3 = k"), "expected H shifted")
end)

test("factorial produces correct output", function()
  local js = read_file("examples/05_factorial.js")
  local output = run_js(js)
  assert(output:find("5%! ="), "expected 5!")
  assert(output:find("120"), "expected 120")
  assert(output:find("3628800"), "expected 3628800")
end)

test("loops produces correct output", function()
  local js = read_file("examples/06_loops.js")
  local output = run_js(js)
  assert(output:find("for%.%.of sum:%s*150"), "expected for..of sum 150")
  assert(output:find("for%(;%;%) sum:%s*150"), "expected for(;;) sum 150")
  assert(output:find("while sum:%s*150"), "expected while sum 150")
end)

test("strcat produces correct output", function()
  local js = read_file("examples/07_strcat.js")
  local output = run_js(js)
  assert(output:find("alpha beta gamma"), "expected concatenated string")
  assert(output:find("alpha alpha alpha alpha alpha"), "expected repeated string")
  assert(output:find("x: 42, y: 7"), "expected mixed concatenation")
end)

test("trycatch produces correct output", function()
  local js = read_file("examples/08_trycatch.js")
  local output = run_js(js)
  assert(output:find("caught:%s*5"), "expected caught: 5")
  assert(output:find("error:%s*too big"), "expected error: too big")
  assert(output:find("10/2 ="), "expected 10/2 result")
  assert(output:find("caught:%s*division by zero"), "expected division by zero")
end)

test("arrows produces correct output", function()
  local js = read_file("examples/09_arrows.js")
  local output = run_js(js)
  assert(output:find("double%(5%):%s*10"), "expected double(5): 10")
  assert(output:find("add%(3, 4%):%s*7"), "expected add(3, 4): 7")
  assert(output:find("apply%(double, 7%):%s*14"), "expected apply(double, 7): 14")
  assert(output:find("sum:%s*15"), "expected sum: 15")
  assert(output:find("add5%(3%):%s*8"), "expected add5(3): 8")
  assert(output:find("add5%(10%):%s*15"), "expected add5(10): 15")
end)

T.summary()
