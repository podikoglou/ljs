local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

-- ============================================================================
-- && operator (JS ToBoolean short-circuit)
-- ============================================================================

test("&& returns left when ToBoolean(left) is false (0)", function()
  assert_eq(eval_js("0 && true"), 0)
end)

test("&& returns left when ToBoolean(left) is false (empty string)", function()
  assert_eq(eval_js('"" && true'), "")
end)

test("&& returns left when ToBoolean(left) is false (NaN)", function()
  local val = eval_js("NaN && true")
  assert(val ~= val, "expected NaN")
end)

test("&& returns left when ToBoolean(left) is false (null)", function()
  local val = eval_js("null && true")
  assert(type(val) == "table", "expected _ljs_null (table)")
end)

test("&& returns left when ToBoolean(left) is false (false)", function()
  assert_eq(eval_js("false && true"), false)
end)

test("&& returns right when ToBoolean(left) is true", function()
  assert_eq(eval_js("1 && 42"), 42)
end)

test("&& returns right when left is truthy (string)", function()
  assert_eq(eval_js('"hello" && 42'), 42)
end)

test("&& returns right when left is truthy and right is falsy (false)", function()
  assert_eq(eval_js("1 && false"), false)
end)

test("&& returns right when left is truthy and right is falsy (0)", function()
  assert_eq(eval_js("1 && 0"), 0)
end)

test("&& returns right when left is truthy and right is falsy (undefined)", function()
  assert_eq(exec_js("return (1 && undefined) === undefined;"), true)
end)

test("&& short-circuits: right not evaluated when left is falsy", function()
  local code = [[
    var called = false;
    function f() { called = true; return 1; }
    var r = 0 && f();
    return called;
  ]]
  assert_eq(exec_js(code), false)
end)

test("&& evaluates right when left is truthy", function()
  local code = [[
    var called = false;
    function f() { called = true; return 42; }
    var r = 1 && f();
    return r;
  ]]
  assert_eq(exec_js(code), 42)
end)

-- ============================================================================
-- || operator (JS ToBoolean short-circuit)
-- ============================================================================

test("|| returns left when ToBoolean(left) is true", function()
  assert_eq(eval_js("1 || 42"), 1)
end)

test("|| returns left when ToBoolean(left) is true (string)", function()
  assert_eq(eval_js('"hello" || 42'), "hello")
end)

test("|| returns left when left is truthy (non-zero number)", function()
  assert_eq(eval_js("42 || 0"), 42)
end)

test("|| returns right when ToBoolean(left) is false (0)", function()
  assert_eq(eval_js('0 || "default"'), "default")
end)

test("|| returns right when ToBoolean(left) is false (empty string)", function()
  assert_eq(eval_js('"" || "fallback"'), "fallback")
end)

test("|| returns right when ToBoolean(left) is false (NaN)", function()
  assert_eq(eval_js("NaN || 42"), 42)
end)

test("|| returns right when ToBoolean(left) is false (null)", function()
  assert_eq(eval_js("null || 42"), 42)
end)

test("|| returns right when ToBoolean(left) is false (false)", function()
  assert_eq(eval_js("false || 42"), 42)
end)

test("|| returns right when ToBoolean(left) is false (undefined)", function()
  assert_eq(eval_js("undefined || 42"), 42)
end)

test("|| short-circuits: right not evaluated when left is truthy", function()
  local code = [[
    var called = false;
    function f() { called = true; return 1; }
    var r = 1 || f();
    return called;
  ]]
  assert_eq(exec_js(code), false)
end)

test("|| evaluates right when left is falsy", function()
  local code = [[
    var called = false;
    function f() { called = true; return 42; }
    var r = 0 || f();
    return r;
  ]]
  assert_eq(exec_js(code), 42)
end)

-- ============================================================================
-- Chained logical operators
-- ============================================================================

test("chained ||: 0 || 0 || 'found'", function()
  assert_eq(eval_js('0 || 0 || "found"'), "found")
end)

test("chained &&: 1 && 2 && 3", function()
  assert_eq(eval_js("1 && 2 && 3"), 3)
end)

test("chained &&: 1 && 0 && 3", function()
  assert_eq(eval_js("1 && 0 && 3"), 0)
end)

test("mixed && and ||: 0 && true || 'yes'", function()
  assert_eq(eval_js('0 && true || "yes"'), "yes")
end)

test("mixed && and ||: 1 && 0 || 'fallback'", function()
  assert_eq(eval_js('1 && 0 || "fallback"'), "fallback")
end)
