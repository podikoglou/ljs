local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

-- ============================================================================
-- Default parameters — transpile
-- ============================================================================

test("function with default parameter transpiles nil check", function()
  local code = transpile_ok("function f(x = 10) { return x; }")
  assert(code:find("if x == nil then", 1, true), "expected nil check for default param")
end)

test("function with default parameter — default value used", function()
  local out = run_js("function f(x = 42) { return x; }\nconsole.log(f());")
  assert_eq(out, "42\n")
end)

test("function with default parameter — provided value used", function()
  local out = run_js("function f(x = 42) { return x; }\nconsole.log(f(7));")
  assert_eq(out, "7\n")
end)

test("function with multiple default parameters", function()
  local out = run_js("function f(a = 1, b = 2) { return a + b; }\nconsole.log(f());")
  assert_eq(out, "3\n")
end)

test("function with mixed params and defaults", function()
  local out = run_js("function f(a, b = 5) { return a + b; }\nconsole.log(f(10));")
  assert_eq(out, "15\n")
end)

test("function with default string parameter", function()
  local out = run_js('function f(s = "hi") { return s; }\nconsole.log(f());')
  assert_eq(out, "hi\n")
end)

-- ============================================================================
-- Rest parameters — transpile
-- ============================================================================

test("function with rest parameter transpiles to array pack", function()
  local code = transpile_ok("function f(...args) { return args; }")
  assert(code:find("_ljs_new(Array, ...)", 1, true), "expected _ljs_new(Array, ...)")
end)

test("function with rest parameter collects arguments", function()
  local out = run_js("function f(...args) { return args.length; }\nconsole.log(f(1, 2, 3));")
  assert_eq(out, "3\n")
end)

test("function with rest parameter — access individual elements", function()
  local out = run_js("function f(...args) { return args[0]; }\nconsole.log(f(10, 20));")
  assert_eq(out, "10\n")
end)

test("function with regular and rest parameters", function()
  local out = run_js("function f(a, b, ...rest) { return rest.length; }\nconsole.log(f(1, 2, 3, 4));")
  assert_eq(out, "2\n")
end)

-- ============================================================================
-- Arrow functions with default/rest
-- ============================================================================

test("arrow function with default parameter", function()
  local out = run_js("let f = (x = 5) => x;\nconsole.log(f());")
  assert_eq(out, "5\n")
end)

test("arrow function with rest parameter", function()
  local out = run_js("let f = (...args) => args.length;\nconsole.log(f(1, 2, 3));")
  assert_eq(out, "3\n")
end)

-- ============================================================================
-- Function expressions with default/rest
-- ============================================================================

test("function expression with default parameter", function()
  local out = run_js("let f = function(x = 99) { return x; };\nconsole.log(f());")
  assert_eq(out, "99\n")
end)

test("function expression with rest parameter", function()
  local out = run_js("let f = function(...args) { return args.length; };\nconsole.log(f(1, 2));")
  assert_eq(out, "2\n")
end)
