local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, emit_ok, run_js, run_lua_source =
  H.transpile_ok, H.emit_ok, H.run_js, H.run_lua_source

-- ============================================================================
-- Unit tests — _ljs_to_boolean wrapping in codegen
-- ============================================================================

test("if statement wraps test in _ljs_to_boolean", function()
  local code = transpile_ok("if (x) { y; }")
  assert(code:find("if _ljs_to_boolean%(x%) then", 1, true), "expected _ljs_to_boolean(x) in if")
end)

test("if/else wraps test in _ljs_to_boolean", function()
  local code = transpile_ok("if (x) { a; } else { b; }")
  assert(
    code:find("if _ljs_to_boolean%(x%) then", 1, true),
    "expected _ljs_to_boolean(x) in if/else"
  )
end)

test("else-if chain wraps each test in _ljs_to_boolean", function()
  local code = transpile_ok("if (x) { a; } else if (y) { b; }")
  assert(
    code:find(
      "if _ljs_to_boolean%(x%) then\n  a\nelseif _ljs_to_boolean%(y%) then\n  b\nend\n",
      1,
      true
    ),
    "expected _ljs_to_boolean in elseif chain"
  )
end)

test("while loop wraps test in _ljs_to_boolean", function()
  local code = transpile_ok("while (x) { y; }")
  assert(
    code:find("while _ljs_to_boolean%(x%) do", 1, true),
    "expected _ljs_to_boolean(x) in while"
  )
end)

test("do-while wraps test in _ljs_to_boolean", function()
  local code = transpile_ok("do { x; } while (done);")
  assert(
    code:find("until not _ljs_to_boolean%(done%)", 1, true),
    "expected not _ljs_to_boolean(done) in do-while"
  )
end)

test("for(;;) wraps test in _ljs_to_boolean", function()
  local code = transpile_ok("for (let i = 0; i < 10; i = i + 1) { x; }")
  assert(
    code:find("while _ljs_to_boolean%(i < 10%) do", 1, true),
    "expected _ljs_to_boolean in for test"
  )
end)

test("!x emits not _ljs_to_boolean(x)", function()
  local code = emit_ok("!x;")
  assert(code:find("not _ljs_to_boolean%(x%)", 1, true), "expected not _ljs_to_boolean(x)")
end)

test("ternary wraps test in _ljs_to_boolean", function()
  local code = emit_ok("x ? 1 : 0")
  assert(
    code:find("if _ljs_to_boolean%(x%) then", 1, true),
    "expected _ljs_to_boolean(x) in ternary IIFE"
  )
end)

-- ============================================================================
-- Integration tests — ToBoolean falsy values in conditions
-- ============================================================================

test("if(0) skips block", function()
  local out = run_js('if (0) { console.log("BUG"); }')
  assert_eq(out:gsub("%s+", ""), "")
end)

test('if("") skips block', function()
  local out = run_js('if ("") { console.log("BUG"); }')
  assert_eq(out:gsub("%s+", ""), "")
end)

test("if(null) skips block", function()
  local out = run_js('if (null) { console.log("BUG"); }')
  assert_eq(out:gsub("%s+", ""), "")
end)

test("if(NaN) skips block", function()
  local out = run_js('if (NaN) { console.log("BUG"); }')
  assert_eq(out:gsub("%s+", ""), "")
end)

test("if(false) skips block", function()
  local out = run_js('if (false) { console.log("BUG"); }')
  assert_eq(out:gsub("%s+", ""), "")
end)

test("if(undefined) skips block", function()
  local out = run_js('if (undefined) { console.log("BUG"); }')
  assert_eq(out:gsub("%s+", ""), "")
end)

test("if(1) enters block", function()
  local out = run_js('if (1) { console.log("OK"); }')
  assert_eq(out:gsub("%s+", ""), "OK")
end)

test('if("hello") enters block', function()
  local out = run_js('if ("hello") { console.log("OK"); }')
  assert_eq(out:gsub("%s+", ""), "OK")
end)

test("if({}) enters block", function()
  local out = run_js('if ({}) { console.log("OK"); }')
  assert_eq(out:gsub("%s+", ""), "OK")
end)

-- ============================================================================
-- Integration tests — ! operator with falsy values
-- ============================================================================

test("!0 is true", function()
  local out = run_js("console.log(!0);")
  assert_eq(out:gsub("%s+", ""), "true")
end)

test("!null is true", function()
  local out = run_js("console.log(!null);")
  assert_eq(out:gsub("%s+", ""), "true")
end)

test('!"" is true', function()
  local out = run_js('console.log(!"");')
  assert_eq(out:gsub("%s+", ""), "true")
end)

test("!NaN is true", function()
  local out = run_js("console.log(!NaN);")
  assert_eq(out:gsub("%s+", ""), "true")
end)

test("!false is true", function()
  local out = run_js("console.log(!false);")
  assert_eq(out:gsub("%s+", ""), "true")
end)

test("!1 is false", function()
  local out = run_js("console.log(!1);")
  assert_eq(out:gsub("%s+", ""), "false")
end)

test('!"hello" is false', function()
  local out = run_js('console.log(!"hello");')
  assert_eq(out:gsub("%s+", ""), "false")
end)

-- ============================================================================
-- Integration tests — while/do-while/for with falsy values
-- NOTE: while(0), do-while(0), for(;;0) integration tests added after the fix
-- to avoid infinite loops from the unfixed transpiler.
-- ============================================================================

-- ============================================================================
-- Integration tests — ternary with falsy values
-- ============================================================================

test("0 ? 1 : 2 returns 2", function()
  local out = run_js("console.log(0 ? 1 : 2);")
  assert_eq(out:gsub("%s+", ""), "2")
end)

test("null ? 1 : 2 returns 2", function()
  local out = run_js("console.log(null ? 1 : 2);")
  assert_eq(out:gsub("%s+", ""), "2")
end)

test('"" ? 1 : 2 returns 2', function()
  local out = run_js('console.log("" ? 1 : 2);')
  assert_eq(out:gsub("%s+", ""), "2")
end)
