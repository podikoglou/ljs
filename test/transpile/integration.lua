local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, transpile, read_file, run_js =
  H.transpile_ok, H.transpile, H.read_file, H.run_js

-- ============================================================================
-- Unit tests — helpers emission
-- ============================================================================

test("all helpers always emitted", function()
  local code = transpile_ok("let x = 1;")
  assert(code:find("_ljs_add"), "expected _ljs_add in preamble")
  assert(code:find("_ljs_call"), "expected _ljs_call in preamble")
  assert(code:find("_ljs_object"), "expected _ljs_object in preamble")
end)

test("_ljs_add present even when + unused", function()
  local code = transpile_ok("let x = 1 * 2;")
  assert(code:find("_ljs_add"), "expected _ljs_add in preamble")
end)

test("transpile.HELPERS accessible", function()
  assert(type(transpile.HELPERS) == "table", "expected HELPERS table")
  assert(type(transpile.HELPERS._ljs_add) == "string", "expected _ljs_add helper")
  assert(
    type(transpile.HELPERS._ljs_object_create) == "string",
    "expected _ljs_object_create helper"
  )
end)

test("shadowed console.log routes through _ljs_call_member", function()
  local code = transpile_ok("let console = {}; console.log(x);")
  assert(code:find("_ljs_call_member"), "should emit _ljs_call_member for shadowed member call")
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

-- ============================================================================
-- INVARIANT: transpile_source produces loadable Lua for all valid JS
-- Contract: the transpiler's output must always be valid Lua source code.
-- If load() fails on the output, every downstream consumer breaks silently.
-- This tests a representative sample of JS constructs end-to-end.

test("invariant: transpile output is always loadable Lua", function()
  local sources = {
    "let x = 1;",
    "let x = 1; let y = 2; let z = x + y;",
    "function f(n) { return n * 2; }",
    "if (x) { f(); } else { g(); }",
    "while (x > 0) { x = x - 1; }",
    "for (let i = 0; i < 10; i = i + 1) { x = x + i; }",
    "let arr = [1, 2, 3];",
    "let obj = {a: 1, b: 2};",
    "let x = a ? 1 : 0;",
    "let x = a && b || c;",
    "try { x(); } catch (e) { y(e); }",
    "switch (x) { case 1: break; default: z(); }",
    "let f = (a, b) => { return a + b; };",
    "let x = 5 & 3;",
    "let x = 5 | 3;",
    "let x = 5 ^ 3;",
    "let x = 1 << 4;",
    "let x = 16 >> 2;",
    "let x = ~5;",
    "delete obj.x;",
    "let t = typeof x;",
    "typeof x;",
    "do { x = x - 1; } while (x > 0);",
    "for (let k in obj) { x = k; }",
    "for (let v of arr) { x = v; }",
    "throw 'error';",
  }
  for _, src in ipairs(sources) do
    local code = transpile_ok(src)
    local fn, err = load(code)
    if not fn then
      error(
        "load() failed for: " .. src .. "\n  output: " .. code .. "\n  error: " .. tostring(err)
      )
    end
  end
end)

-- ============================================================================
-- INVARIANT: transpile_source returns nil, err for invalid JS
-- Contract: same error convention as the parser.

test("invariant: transpile_source returns nil, err for invalid JS", function()
  local cases = {
    "async function f() {}",
  }
  for _, src in ipairs(cases) do
    local code, err = transpile.transpile_source(src)
    assert(code == nil, "expected nil for: " .. src)
    assert(err ~= nil, "expected error message for: " .. src)
  end
end)

test("this keyword is now supported", function()
  local code = transpile_ok("this;")
  assert(code:find("_ljs_arrow_this"), "expected _ljs_arrow_this in output")
end)
