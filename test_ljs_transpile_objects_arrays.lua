local T = require("ljs_test")
local H = require("ljs_test_transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code = H.transpile_ok, H.expr_code

-- ============================================================================
-- Unit tests — objects and arrays
-- ============================================================================

test("empty object", function()
  local code = expr_code("({});")
  assert_eq(code, "{}")
end)

test("object with identifier keys", function()
  local code = expr_code("({a: 1, b: 2});")
  assert_eq(code, "{a = 1, b = 2}")
end)

test("object with string keys", function()
  local code = expr_code('({"key": 1});')
  assert_eq(code, '{["key"] = 1}')
end)

test("empty array", function()
  local code = expr_code("[]")
  assert_eq(code, "{}")
end)

test("array with elements", function()
  local code = expr_code("[1, 2, 3]")
  assert_eq(code, "{1, 2, 3}")
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

test("console.log uses helper", function()
  local code = transpile_ok("console.log(x);")
  assert(code:find("_ljs_log%(x%)"), "expected _ljs_log(x)")
  assert(code:find("local function _ljs_log"), "expected _ljs_log helper definition")
end)

test("console.log with multiple args", function()
  local code = transpile_ok('console.log("a", "b");')
  assert(code:find('_ljs_log%("a", "b"%)'), "expected _ljs_log with multiple args")
end)

T.summary()
