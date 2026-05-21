local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

-- ============================================================================
-- Unit tests — update expressions (++/--)
-- ============================================================================

test("i++ expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = i++;")
  assert(code:find("local _t = i"), "expected save of old value")
  assert(code:find("return _t"), "expected return of old value")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected increment")
end)

test("++i expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = ++i;")
  assert(not code:find("local _t"), "no temp for prefix")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected increment")
  assert(code:find("return i"), "expected return of new value")
end)

test("i-- expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = i--;")
  assert(code:find("local _t = i"), "expected save of old value")
  assert(code:find("i = i %- 1"), "expected decrement")
  assert(code:find("return _t"), "expected return of old value")
end)

test("--i expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = --i;")
  assert(not code:find("local _t"), "no temp for prefix")
  assert(code:find("i = i %- 1"), "expected decrement")
  assert(code:find("return i"), "expected return of new value")
end)

test("i++ as statement emits plain assignment", function()
  local code = transpile_ok("i++;")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected plain assignment")
end)

test("--i as statement emits plain assignment", function()
  local code = transpile_ok("--i;")
  assert(code:find("i = i %- 1"), "expected plain assignment")
end)

test("i++ emits _ljs_add helper", function()
  local code = transpile_ok("i++;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)

test("--i does not emit _ljs_add helper", function()
  local code = transpile_ok("--i;")
  assert(not code:find("_ljs_add"), "no _ljs_add helper needed for --")
end)

test("for with i++ update emits _ljs_add helper", function()
  local code = transpile_ok("for (let i = 0; i < 10; i++) { x; }")
  assert(code:find("_ljs_add"), "expected _ljs_add helper")
  assert(code:find("while i < 10 do"), "expected while condition")
end)

test("for with --i update does not emit _ljs_add", function()
  local code = transpile_ok("for (let i = 10; i > 0; --i) { x; }")
  assert(not code:find("_ljs_add"), "no _ljs_add for --i")
end)

-- ============================================================================
-- Integration tests — update expressions (++/--)
-- ============================================================================

test("i++ in for loop produces correct count", function()
  local output = run_js([[
    let result = "";
    for (let i = 0; i < 3; i++) {
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "012")
end)

test("i-- decrements correctly", function()
  local output = run_js([[
    let x = 5;
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "4")
end)

test("postfix i++ returns old value", function()
  local output = run_js([[
    let x = 5;
    console.log(x++);
  ]])
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("prefix ++i returns new value", function()
  local output = run_js([[
    let x = 5;
    console.log(++x);
  ]])
  assert_eq(output:gsub("%s+", ""), "6")
end)

T.summary()
