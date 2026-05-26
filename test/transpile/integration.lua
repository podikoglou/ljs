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

test("brainfuck produces correct output", function()
  local js = read_file("examples/brainfuck.js")
  local output = run_js(js)
  assert(output:find("Hello World:"), "expected Hello World header")
  assert(output:find("Hello World%!"), "expected Hello World! output")
  assert(output:find("Hi:"), "expected Hi header")
  assert(output:find("Cat %(input 'A'%):"), "expected Cat header")
  assert(output:find("Adder %(input '23'%):"), "expected Adder header")
end)

test("game_of_life produces correct output", function()
  local js = read_file("examples/game_of_life.js")
  local output = run_js(js)
  assert(output:find("=== Generation 0 ==="), "expected Generation 0 header")
  assert(output:find("=== Generation 15 ==="), "expected Generation 15 header")
end)

test("rot13 produces correct output", function()
  local js = read_file("examples/rot13.js")
  local output = run_js(js)
  assert(output:find("PASS: roundtrip"), "expected PASS roundtrip")
  assert(output:find("PASS: decode known ciphertext"), "expected PASS decode known ciphertext")
  assert(output:find("PASS: double application is identity"), "expected PASS double application")
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
