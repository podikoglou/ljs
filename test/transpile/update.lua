local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js, emit_ok = H.transpile_ok, H.run_js, H.emit_ok

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
  local ecode = emit_ok("let x = ++i;")
  assert(not ecode:find("local _t"), "no temp for prefix")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected increment")
  assert(code:find("return i"), "expected return of new value")
end)

test("i-- expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = i--;")
  assert(code:find("local _t = i"), "expected save of old value")
  assert(code:find("i = _ljs_add%(i, %-1%)"), "expected decrement via _ljs_add")
  assert(code:find("return _t"), "expected return of old value")
end)

test("--i expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = --i;")
  local ecode = emit_ok("let x = --i;")
  assert(not ecode:find("local _t"), "no temp for prefix")
  assert(code:find("i = _ljs_add%(i, %-1%)"), "expected decrement via _ljs_add")
  assert(code:find("return i"), "expected return of new value")
end)

test("i++ as statement emits plain assignment", function()
  local code = transpile_ok("i++;")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected plain assignment")
end)

test("--i as statement emits plain assignment", function()
  local code = transpile_ok("--i;")
  assert(code:find("i = _ljs_add%(i, %-1%)"), "expected _ljs_add assignment")
end)

test("i++ emits _ljs_add helper", function()
  local code = transpile_ok("i++;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)

test("--i still has _ljs_add in preamble", function()
  local code = transpile_ok("--i;")
  assert(code:find("_ljs_add"), "_ljs_add always in preamble")
end)

test("for with i++ update emits _ljs_add helper", function()
  local code = transpile_ok("for (let i = 0; i < 10; i++) { x; }")
  assert(code:find("_ljs_add"), "expected _ljs_add helper")
  assert(code:find("while _ljs_to_boolean%(i < 10%) do"), "expected while condition")
end)

test("for with --i update still has _ljs_add in preamble", function()
  local code = transpile_ok("for (let i = 10; i > 0; --i) { x; }")
  assert(code:find("_ljs_add"), "_ljs_add always in preamble")
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

test("--i as statement emits _ljs_add (not raw subtraction)", function()
  local code = transpile_ok("--i;")
  assert(not code:find("i = i %- 1"), "should not use raw subtraction")
  assert(code:find("_ljs_add"), "should use _ljs_add for ToNumber coercion")
end)

test("--string operand coerces via ToNumber", function()
  local output = run_js([[
    let x = "5";
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "4")
end)

test("--null operand coerces to -1", function()
  local output = run_js([[
    let x = null;
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("--boolean true operand coerces to 0", function()
  local output = run_js([[
    let x = true;
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("--boolean false operand coerces to -1", function()
  local output = run_js([[
    let x = false;
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("--undefined operand produces NaN", function()
  local output = run_js([[
    let x = undefined;
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "NaN")
end)

test("prefix --x with string coerces via ToNumber", function()
  local output = run_js([[
    let x = "10";
    console.log(--x);
  ]])
  assert_eq(output:gsub("%s+", ""), "9")
end)

test("postfix x-- with null coerces via ToNumber", function()
  local output = run_js([[
    let x = null;
    console.log(x--);
  ]])
  assert_eq(output:gsub("%s+", ""), "null")
end)
