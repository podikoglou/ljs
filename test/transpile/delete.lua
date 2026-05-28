local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, emit_ok = H.transpile_ok, H.expr_code, H.emit_ok

-- ============================================================================
-- Unit tests — delete expression
-- ============================================================================

test("delete obj.prop (statement)", function()
  local code = transpile_ok("delete obj.prop;")
  assert(code:find('rawset(obj, "prop", nil)', 1, true), "expected rawset call")
end)

test("delete obj[key] (statement)", function()
  local code = transpile_ok("delete obj[key];")
  assert(code:find("rawset(obj, (key) + 1, nil)", 1, true), "expected rawset call")
end)

test("delete obj['str'] (statement, string computed)", function()
  local code = transpile_ok('delete obj["str"];')
  assert(code:find('rawset(obj, "str", nil)', 1, true), "expected rawset call")
end)

test("delete arr[0] (statement, numeric index)", function()
  local code = transpile_ok("delete arr[0];")
  assert(code:find("rawset(arr, (0) + 1, nil)", 1, true), "expected rawset call")
end)

test("delete a.b.c (nested member)", function()
  local code = transpile_ok("delete a.b.c;")
  assert(code:find('rawset(_ljs_to_object(a).b, "c", nil)', 1, true), "expected rawset call")
end)

test("delete getObj().prop (call result member)", function()
  local code = transpile_ok("delete getObj().prop;")
  assert(
    code:find('rawset(_ljs_call(getObj), "prop", nil)', 1, true),
    "expected rawset with _ljs_call"
  )
  assert(code:find("local function _ljs_call"), "expected _ljs_call helper")
end)

test("delete x (identifier, statement — emits nothing)", function()
  local code = emit_ok("delete x;")
  assert(not code:find("rawset"), "expected no rawset for identifier delete")
end)

test("delete 42 (literal, statement — emits nothing)", function()
  local code = emit_ok("delete 42;")
  assert(not code:find("rawset"), "expected no rawset for literal delete")
end)

test("delete null (null, statement — emits nothing)", function()
  local code = emit_ok("delete null;")
  assert(not code:find("rawset"), "expected no rawset for null delete")
end)

test("delete f() (call, statement — emits nothing)", function()
  local code = transpile_ok("delete f();")
  assert(code:find("local function _ljs_call"), "expected _ljs_call helper")
  local ecode = emit_ok("delete f();")
  assert(not ecode:find("rawset"), "expected no rawset for call delete")
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
  assert_eq(code, 'local _ = _ljs_strict_eq((rawset(obj, "prop", nil) and true), true)')
end)

test("delete in logical: delete x && delete y", function()
  local code = expr_code("delete x && delete y")
  assert_eq(
    code,
    "(function() local _ljs_v = true; if _ljs_to_boolean(_ljs_v) then return true else return _ljs_v end end)()"
  )
end)

test("delete in logical: delete obj.prop || delete y", function()
  local code = expr_code("delete obj.prop || delete y")
  assert_eq(
    code,
    '(function() local _ljs_v = (rawset(obj, "prop", nil) and true); if _ljs_to_boolean(_ljs_v) then return _ljs_v else return true end end)()'
  )
end)

test("delete in ternary: delete obj.prop ? 1 : 0", function()
  assert_eq(
    expr_code("let r = delete obj.prop ? 1 : 0;"),
    'local r = (function() if _ljs_to_boolean((rawset(obj, "prop", nil) and true)) then return 1 else return 0 end end)()'
  )
end)

test("delete in ternary: flag ? delete obj.prop : delete y", function()
  assert_eq(
    expr_code("let r = flag ? delete obj.prop : delete y;"),
    'local r = (function() if _ljs_to_boolean(flag) then return (rawset(obj, "prop", nil) and true) else return true end end)()'
  )
end)

test("delete in if condition", function()
  local code = transpile_ok("if (delete obj.prop) { x; }")
  assert(
    code:find('if _ljs_to_boolean((rawset(obj, "prop", nil) and true)) then', 1, true),
    "expected if with rawset"
  )
end)

test("delete in while condition", function()
  local code = transpile_ok("while (delete obj.prop) { x; }")
  assert(
    code:find('while _ljs_to_boolean((rawset(obj, "prop", nil) and true)) do', 1, true),
    "expected while with rawset"
  )
end)

test("delete in return statement", function()
  local code = transpile_ok("function f() { return delete obj.prop; }")
  assert(
    code:find('return (rawset(obj, "prop", nil) and true)', 1, true),
    "expected return with rawset"
  )
end)

test("delete in throw statement", function()
  local code = transpile_ok("throw delete obj.prop;")
  assert(
    code:find('error((rawset(obj, "prop", nil) and true), 0)', 1, true),
    "expected error with rawset"
  )
end)

test("delete in array element", function()
  local code = expr_code("[delete obj.prop]")
  assert_eq(code, '_ljs_new(Array, (rawset(obj, "prop", nil) and true))')
end)

test("delete in object value", function()
  local code = expr_code("({a: delete obj.prop})")
  assert_eq(code, '_ljs_object({a = (rawset(obj, "prop", nil) and true)})')
end)

test("!delete x (unary NOT of delete)", function()
  local code = expr_code("!delete x")
  assert_eq(code, "local _ = not _ljs_to_boolean(true)")
end)

test("delete !x (delete of unary NOT)", function()
  local code = emit_ok("delete !x;")
  assert(not code:find("rawset"), "expected no rawset for unary NOT delete")
end)

test("delete --x (delete of prefix decrement — statement, emits nothing)", function()
  local code = emit_ok("delete --x;")
  assert(not code:find("rawset"), "expected no rawset for prefix decrement delete")
end)

test("delete delete x (double delete, statement — emits nothing)", function()
  local code = emit_ok("delete delete x;")
  assert(not code:find("rawset"), "expected no rawset for double delete")
end)

test("let r = delete delete obj.prop (double delete, expression)", function()
  local code = expr_code("let r = delete delete obj.prop")
  assert_eq(code, "local r = true")
end)

test("multiple delete member statements", function()
  local code = transpile_ok("delete obj.a; delete obj.b;")
  assert(code:find('rawset(obj, "a", nil)', 1, true), "expected rawset obj.a")
  assert(code:find('rawset(obj, "b", nil)', 1, true), "expected rawset obj.b")
end)

test("delete member in for loop init", function()
  local code = transpile_ok("for (delete obj.prop; x; y) {}")
  assert(code:find('rawset(obj, "prop", nil)', 1, true), "expected rawset in init")
  assert(code:find("while _ljs_to_boolean(x) do", 1, true), "expected while")
end)

test("delete member in do-while body", function()
  local code = transpile_ok("do { delete obj.prop; } while (x);")
  assert(code:find('rawset(obj, "prop", nil)', 1, true), "expected rawset in body")
  assert(code:find("until not _ljs_to_boolean(x)", 1, true), "expected until")
end)

test("delete member in switch case", function()
  local code = transpile_ok("switch (x) { case 1: delete obj.prop; }")
  assert(code:find('rawset(obj, "prop", nil)', 1, true), "expected rawset in case")
  assert(code:find("_ljs_sw == 1", 1, true), "expected case comparison")
end)
