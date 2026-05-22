local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js = H.transpile_ok, H.expr_code, H.run_js

-- ============================================================================
-- Unit tests — objects and arrays
-- ============================================================================

test("empty object", function()
  local code = expr_code("({});")
  assert_eq(code, "_ljs_object({})")
end)

test("object with identifier keys", function()
  local code = expr_code("({a: 1, b: 2});")
  assert_eq(code, "_ljs_object({a = 1, b = 2})")
end)

test("object with string keys", function()
  local code = expr_code('({"key": 1});')
  assert_eq(code, '_ljs_object({["key"] = 1})')
end)

test("empty array", function()
  local code = expr_code("[]")
  assert_eq(code, "_ljs_new(Array)")
end)

test("array with elements", function()
  local code = expr_code("[1, 2, 3]")
  assert_eq(code, "_ljs_new(Array, 1, 2, 3)")
end)

test("dot access", function()
  local code = expr_code("obj.prop")
  assert_eq(code, "obj.prop")
end)

test("computed string key no offset", function()
  local code = expr_code('obj["key"]')
  assert_eq(code, 'obj["key"]')
end)

test("computed expression key adds offset", function()
  local code = expr_code("arr[i]")
  assert_eq(code, "arr[(i) + 1]")
end)

-- ============================================================================
-- Unit tests — console.log
-- ============================================================================

test("console.log routes through _ljs_call_member", function()
  local code = transpile_ok("console.log(x);")
  assert(
    code:find('_ljs_call_member(console, "log", x)', 1, true),
    'expected _ljs_call_member(console, "log", x)'
  )
  assert(
    code:find("local function _ljs_call_member"),
    "expected _ljs_call_member helper definition"
  )
end)

test("console.log with multiple args routes through _ljs_call_member", function()
  local code = transpile_ok('console.log("a", "b");')
  assert(
    code:find('_ljs_call_member(console, "log", "a", "b")', 1, true),
    "expected _ljs_call_member with multiple args"
  )
end)

-- ============================================================================
-- Method shorthand transpile
-- ============================================================================

test("method shorthand transpiles to function value", function()
  local code = transpile_ok("let o = { foo() { return 1; } };")
  assert(code:find("foo = _ljs_fn(function", 1, true), "expected foo = _ljs_fn(function")
  assert(code:find("return 1"), "expected return 1")
end)

test("method shorthand with params transpiles correctly", function()
  local code = transpile_ok("let o = { add(a, b) { return a + b; } };")
  assert(
    code:find("add = _ljs_fn(function(_ljs_this, a, b)", 1, true),
    "expected add = _ljs_fn(function(_ljs_this, a, b)"
  )
end)

test("shorthand property transpiles to key = key", function()
  local code = expr_code("({x});")
  assert_eq(code, "_ljs_object({x = x})")
end)

test("multiple shorthand properties", function()
  local code = expr_code("({x, y});")
  assert_eq(code, "_ljs_object({x = x, y = y})")
end)

test("mixed regular, shorthand, and method", function()
  local code = transpile_ok("let o = { a: 1, b, c() { return 3; } };")
  assert(code:find("a = 1"), "expected a = 1")
  assert(code:find("b = b"), "expected b = b")
  assert(code:find("c = _ljs_fn(function", 1, true), "expected c = _ljs_fn(function")
end)

-- ============================================================================
-- Integration — run_js for method shorthand
-- ============================================================================

test("method shorthand is callable", function()
  local output = run_js("let o = { double(x) { return x * 2; } }; console.log(o.double(5));")
  assert_eq(output:gsub("%s+", ""), "10")
end)

test("method shorthand with no params", function()
  local output = run_js("let o = { answer() { return 42; } }; console.log(o.answer());")
  assert_eq(output:gsub("%s+", ""), "42")
end)

test("shorthand property uses variable value", function()
  local output = run_js("let x = 99; let o = { x }; console.log(o.x);")
  assert_eq(output:gsub("%s+", ""), "99")
end)

test("method shorthand mixed with shorthand property", function()
  local output = run_js([[
    let name = "world";
    let o = {
      name,
      greet() { return "hello " + name; }
    };
    console.log(o.name);
    console.log(o.greet());
  ]])
  local cleaned = output:gsub("%s+", "")
  assert_eq(cleaned, "worldhelloworld")
end)

T.summary()
