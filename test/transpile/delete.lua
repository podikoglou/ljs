local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code = H.transpile_ok, H.expr_code

-- ============================================================================
-- Unit tests — delete expression
-- ============================================================================

test("delete obj.prop (statement)", function()
  local code = transpile_ok("delete obj.prop;")
  assert_eq(code, 'rawset(obj, "prop", nil)\n')
end)

test("delete obj[key] (statement)", function()
  local code = transpile_ok("delete obj[key];")
  assert_eq(code, "rawset(obj, (key) + 1, nil)\n")
end)

test("delete obj['str'] (statement, string computed)", function()
  local code = transpile_ok('delete obj["str"];')
  assert_eq(code, 'rawset(obj, "str", nil)\n')
end)

test("delete arr[0] (statement, numeric index)", function()
  local code = transpile_ok("delete arr[0];")
  assert_eq(code, "rawset(arr, (0) + 1, nil)\n")
end)

test("delete a.b.c (nested member)", function()
  local code = transpile_ok("delete a.b.c;")
  assert_eq(code, 'rawset(a.b, "c", nil)\n')
end)

test("delete getObj().prop (call result member)", function()
  local code = transpile_ok("delete getObj().prop;")
  assert_eq(code, 'local function _ljs_call(fn, ...)\n  return fn(nil, ...)\nend\n\nrawset(_ljs_call(getObj), "prop", nil)\n')
end)

test("delete x (identifier, statement — emits nothing)", function()
  local code = transpile_ok("delete x;")
  assert_eq(code, "")
end)

test("delete 42 (literal, statement — emits nothing)", function()
  local code = transpile_ok("delete 42;")
  assert_eq(code, "")
end)

test("delete null (null, statement — emits nothing)", function()
  local code = transpile_ok("delete null;")
  assert_eq(code, "")
end)

test("delete f() (call, statement — emits nothing)", function()
  local code = transpile_ok("delete f();")
  assert_eq(code, "local function _ljs_call(fn, ...)\n  return fn(nil, ...)\nend\n\n")
end)

test("let r = delete obj.prop (expression context)", function()
  local code = expr_code("let r = delete obj.prop")
  assert_eq(code, 'local r = (rawset(obj, "prop", nil) and true)')
end)

test("let r = delete obj[key] (expression, computed)", function()
  local code = expr_code("let r = delete obj[key]")
  assert_eq(code, "local r = (rawset(obj, (key) + 1, nil) and true)")
end)

test("let r = delete arr[0] (expression, numeric)", function()
  local code = expr_code("let r = delete arr[0]")
  assert_eq(code, "local r = (rawset(arr, (0) + 1, nil) and true)")
end)

test("let r = delete x (expression, identifier — true)", function()
  local code = expr_code("let r = delete x")
  assert_eq(code, "local r = true")
end)

test("let r = delete 42 (expression, literal — true)", function()
  local code = expr_code("let r = delete 42")
  assert_eq(code, "local r = true")
end)

test("let r = delete null (expression, null — true)", function()
  local code = expr_code("let r = delete null")
  assert_eq(code, "local r = true")
end)

test("result = delete obj.prop (assignment RHS)", function()
  local code = expr_code("result = delete obj.prop")
  assert_eq(code, 'result = (rawset(obj, "prop", nil) and true)')
end)

test("x += delete y (compound assignment RHS)", function()
  local code = expr_code("x += delete y")
  assert_eq(code, "x = _ljs_add(x, true)")
end)

test("delete in binary: delete obj.prop + 1", function()
  local code = expr_code("delete obj.prop + 1")
  assert_eq(code, '_ljs_add((rawset(obj, "prop", nil) and true), 1)')
end)

test("delete in binary: delete obj.prop === true", function()
  local code = expr_code("delete obj.prop === true")
  assert_eq(code, '(rawset(obj, "prop", nil) and true) == true')
end)

test("delete in logical: delete x && delete y", function()
  local code = expr_code("delete x && delete y")
  assert_eq(code, "true and true")
end)

test("delete in logical: delete obj.prop || delete y", function()
  local code = expr_code("delete obj.prop || delete y")
  assert_eq(code, '(rawset(obj, "prop", nil) and true) or true')
end)

test("delete in ternary: delete obj.prop ? 1 : 0", function()
  local code = transpile_ok("let r = delete obj.prop ? 1 : 0;")
  assert_eq(
    code,
    'local r = (function() if (rawset(obj, "prop", nil) and true) then return 1 else return 0 end end)()\n'
  )
end)

test("delete in ternary: flag ? delete obj.prop : delete y", function()
  local code = transpile_ok("let r = flag ? delete obj.prop : delete y;")
  assert_eq(
    code,
    'local r = (function() if flag then return (rawset(obj, "prop", nil) and true) else return true end end)()\n'
  )
end)

test("delete in if condition", function()
  local code = transpile_ok("if (delete obj.prop) { x; }")
  assert_eq(code, 'if (rawset(obj, "prop", nil) and true) then\n  x\nend\n')
end)

test("delete in while condition", function()
  local code = transpile_ok("while (delete obj.prop) { x; }")
  assert_eq(code, 'while (rawset(obj, "prop", nil) and true) do\n  x\nend\n')
end)

test("delete in return statement", function()
  local code = transpile_ok("function f() { return delete obj.prop; }")
  assert_eq(code, 'local function f(_ljs_this)\n  return (rawset(obj, "prop", nil) and true)\nend\n')
end)

test("delete in throw statement", function()
  local code = transpile_ok("throw delete obj.prop;")
  assert_eq(code, 'error((rawset(obj, "prop", nil) and true), 0)\n')
end)

test("delete in array element", function()
  local code = expr_code("[delete obj.prop]")
  assert_eq(code, '{(rawset(obj, "prop", nil) and true)}')
end)

test("delete in object value", function()
  local code = expr_code("({a: delete obj.prop})")
  assert_eq(code, '_ljs_object({a = (rawset(obj, "prop", nil) and true)})')
end)

test("!delete x (unary NOT of delete)", function()
  local code = expr_code("!delete x")
  assert_eq(code, "not true")
end)

test("delete !x (delete of unary NOT)", function()
  local code = transpile_ok("delete !x;")
  assert_eq(code, "")
end)

test("delete --x (delete of prefix decrement — statement, emits nothing)", function()
  local code = transpile_ok("delete --x;")
  assert_eq(code, "")
end)

test("delete delete x (double delete, statement — emits nothing)", function()
  local code = transpile_ok("delete delete x;")
  assert_eq(code, "")
end)

test("let r = delete delete obj.prop (double delete, expression)", function()
  local code = expr_code("let r = delete delete obj.prop")
  assert_eq(code, "local r = true")
end)

test("multiple delete member statements", function()
  local code = transpile_ok("delete obj.a; delete obj.b;")
  assert_eq(code, 'rawset(obj, "a", nil)\nrawset(obj, "b", nil)\n')
end)

test("delete member in for loop init", function()
  local code = transpile_ok("for (delete obj.prop; x; y) {}")
  assert_eq(code, 'rawset(obj, "prop", nil)\nwhile x do\n  y\nend\n')
end)

test("delete member in do-while body", function()
  local code = transpile_ok("do { delete obj.prop; } while (x);")
  assert_eq(code, 'repeat\n  rawset(obj, "prop", nil)\nuntil not (x)\n')
end)

test("delete member in switch case", function()
  local code = transpile_ok("switch (x) { case 1: delete obj.prop; }")
  assert_eq(
    code,
    'local _ljs_sw = x\nlocal _ljs_matched = false\nfor _ = 1, 1 do\n  if _ljs_matched or _ljs_sw == 1 then\n    _ljs_matched = true\n    rawset(obj, "prop", nil)\n  end\nend\n'
  )
end)

T.summary()
