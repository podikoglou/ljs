local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js, expr_code = H.run_js, H.expr_code

-- ============================================================================
-- Unit tests — preamble structure
-- ============================================================================

test("_ljs_number_prototype declared before helpers", function()
  local code = H.transpile_ok("let x = 1;")
  local proto_pos = code:find("local _ljs_number_prototype", 1, true)
  local fn_pos = code:find("local function _ljs_fn", 1, true)
  assert(proto_pos, "expected _ljs_number_prototype declaration")
  assert(fn_pos, "expected _ljs_fn definition")
  assert(proto_pos < fn_pos, "_ljs_number_prototype must come before _ljs_fn")
end)

test("_ljs_string_prototype declared before helpers", function()
  local code = H.transpile_ok("let x = 1;")
  local proto_pos = code:find("local _ljs_string_prototype", 1, true)
  local fn_pos = code:find("local function _ljs_fn", 1, true)
  assert(proto_pos, "expected _ljs_string_prototype declaration")
  assert(fn_pos, "expected _ljs_fn definition")
  assert(proto_pos < fn_pos, "_ljs_string_prototype must come before _ljs_fn")
end)

test("_ljs_boolean_prototype declared before helpers", function()
  local code = H.transpile_ok("let x = 1;")
  local proto_pos = code:find("local _ljs_boolean_prototype", 1, true)
  local fn_pos = code:find("local function _ljs_fn", 1, true)
  assert(proto_pos, "expected _ljs_boolean_prototype declaration")
  assert(fn_pos, "expected _ljs_fn definition")
  assert(proto_pos < fn_pos, "_ljs_boolean_prototype must come before _ljs_fn")
end)

test("_ljs_to_object emitted before _ljs_call_member", function()
  local code = H.transpile_ok("let x = 1;")
  local to_obj_pos = code:find("local function _ljs_to_object", 1, true)
  local call_mem_pos = code:find("local function _ljs_call_member", 1, true)
  assert(to_obj_pos, "expected _ljs_to_object helper")
  assert(call_mem_pos, "expected _ljs_call_member helper")
  assert(to_obj_pos < call_mem_pos, "_ljs_to_object must come before _ljs_call_member")
end)

test("_ljs_number_prototype.toString emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("_ljs_number_prototype.toString", 1, true), "expected number toString method")
end)

test("_ljs_string_prototype.toString emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("_ljs_string_prototype.toString", 1, true), "expected string toString method")
end)

test("_ljs_boolean_prototype.toString emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("_ljs_boolean_prototype.toString", 1, true), "expected boolean toString method")
end)

test("Number.prototype = _ljs_number_prototype", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Number.prototype = _ljs_number_prototype", 1, true),
    "expected Number.prototype assignment"
  )
end)

test("String.prototype = _ljs_string_prototype", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("String.prototype = _ljs_string_prototype", 1, true),
    "expected String.prototype assignment"
  )
end)

test("Boolean.prototype = _ljs_boolean_prototype", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Boolean.prototype = _ljs_boolean_prototype", 1, true),
    "expected Boolean.prototype assignment"
  )
end)

-- ============================================================================
-- Integration tests — Number.prototype.toString
-- ============================================================================

test("(42).toString() returns '42'", function()
  local out = run_js([[
    console.log((42).toString());
  ]])
  assert_eq(out, "42\n")
end)

test("(0).toString() returns '0'", function()
  local out = run_js([[
    console.log((0).toString());
  ]])
  assert_eq(out, "0\n")
end)

test("(-1).toString() returns '-1'", function()
  local out = run_js([[
    console.log((-1).toString());
  ]])
  assert_eq(out, "-1\n")
end)

test("(NaN).toString() returns 'NaN'", function()
  local out = run_js([[
    console.log((NaN).toString());
  ]])
  assert_eq(out, "NaN\n")
end)

test("Number(42).toString() via explicit constructor call", function()
  local out = run_js([[
    console.log(Number(42).toString());
  ]])
  assert_eq(out, "42\n")
end)

-- ============================================================================
-- Integration tests — String.prototype.toString
-- ============================================================================

test("'hello'.toString() returns 'hello'", function()
  local out = run_js([[
    console.log(("hello").toString());
  ]])
  assert_eq(out, "hello\n")
end)

test("empty string toString returns empty string", function()
  local out = run_js([[
    console.log(("").toString() === "");
  ]])
  assert_eq(out, "true\n")
end)

test("String('abc').toString() via explicit constructor call", function()
  local out = run_js([[
    console.log(String("abc").toString());
  ]])
  assert_eq(out, "abc\n")
end)

-- ============================================================================
-- Integration tests — Boolean.prototype.toString
-- ============================================================================

test("true.toString() returns 'true'", function()
  local out = run_js([[
    console.log((true).toString());
  ]])
  assert_eq(out, "true\n")
end)

test("false.toString() returns 'false'", function()
  local out = run_js([[
    console.log((false).toString());
  ]])
  assert_eq(out, "false\n")
end)

test("Boolean(true).toString() via explicit constructor call", function()
  local out = run_js([[
    console.log(Boolean(true).toString());
  ]])
  assert_eq(out, "true\n")
end)

-- ============================================================================
-- Integration tests — valueOf
-- ============================================================================

test("(42).valueOf() returns 42", function()
  local out = run_js([[
    console.log((42).valueOf());
  ]])
  assert_eq(out, "42\n")
end)

test("'hello'.valueOf() returns 'hello'", function()
  local out = run_js([[
    console.log(("hello").valueOf());
  ]])
  assert_eq(out, "hello\n")
end)

test("true.valueOf() returns true", function()
  local out = run_js([[
    console.log((true).valueOf());
  ]])
  assert_eq(out, "true\n")
end)

-- ============================================================================
-- Integration tests — constructor call vs new (typeof)
-- ============================================================================

test("typeof Number(42) is 'number'", function()
  local out = run_js([[
    console.log(typeof Number(42));
  ]])
  assert_eq(out, "number\n")
end)

test("typeof new Number(42) is 'object'", function()
  local out = run_js([[
    console.log(typeof new Number(42));
  ]])
  assert_eq(out, "object\n")
end)

test("new Number(42).valueOf() returns 42", function()
  local out = run_js([[
    console.log(new Number(42).valueOf());
  ]])
  assert_eq(out, "42\n")
end)

test("new Number(42).toString() returns '42'", function()
  local out = run_js([[
    console.log(new Number(42).toString());
  ]])
  assert_eq(out, "42\n")
end)

test("typeof String('a') is 'string'", function()
  local out = run_js([[
    console.log(typeof String("a"));
  ]])
  assert_eq(out, "string\n")
end)

test("typeof new String('a') is 'object'", function()
  local out = run_js([[
    console.log(typeof new String("a"));
  ]])
  assert_eq(out, "object\n")
end)

test("new String('a').valueOf() returns 'a'", function()
  local out = run_js([[
    console.log(new String("a").valueOf());
  ]])
  assert_eq(out, "a\n")
end)

test("new String('a').toString() returns 'a'", function()
  local out = run_js([[
    console.log(new String("a").toString());
  ]])
  assert_eq(out, "a\n")
end)

test("typeof Boolean(true) is 'boolean'", function()
  local out = run_js([[
    console.log(typeof Boolean(true));
  ]])
  assert_eq(out, "boolean\n")
end)

test("typeof new Boolean(true) is 'object'", function()
  local out = run_js([[
    console.log(typeof new Boolean(true));
  ]])
  assert_eq(out, "object\n")
end)

test("new Boolean(true).valueOf() returns true", function()
  local out = run_js([[
    console.log(new Boolean(true).valueOf());
  ]])
  assert_eq(out, "true\n")
end)

test("new Boolean(false).valueOf() returns false", function()
  local out = run_js([[
    console.log(new Boolean(false).valueOf());
  ]])
  assert_eq(out, "false\n")
end)

-- ============================================================================
-- Integration tests — no regression on objects
-- ============================================================================

test("object toString still returns [object Object]", function()
  local out = run_js([[
    let o = {};
    console.log(o.toString());
  ]])
  assert_eq(out, "[object Object]\n")
end)

test("object hasOwnProperty still works", function()
  local out = run_js([[
    let o = { x: 1 };
    console.log(o.hasOwnProperty("x"));
    console.log(o.hasOwnProperty("y"));
  ]])
  assert_eq(out, "true\nfalse\n")
end)

-- ============================================================================
-- Integration tests — prototype chain
-- ============================================================================

test("boxed number inherits Object.prototype.hasOwnProperty", function()
  local out = run_js([[
    console.log((42).hasOwnProperty("toString"));
  ]])
  assert_eq(out, "false\n")
end)

test("boxed string inherits Object.prototype.hasOwnProperty", function()
  local out = run_js([[
    console.log(("hello").hasOwnProperty("toString"));
  ]])
  assert_eq(out, "false\n")
end)

test("boxed boolean inherits Object.prototype.hasOwnProperty", function()
  local out = run_js([[
    console.log((true).hasOwnProperty("toString"));
  ]])
  assert_eq(out, "false\n")
end)

test("Number.prototype.constructor === Number", function()
  local out = run_js([[
    console.log(Number.prototype.constructor === Number);
  ]])
  assert_eq(out, "true\n")
end)

test("String.prototype.constructor === String", function()
  local out = run_js([[
    console.log(String.prototype.constructor === String);
  ]])
  assert_eq(out, "true\n")
end)

test("Boolean.prototype.constructor === Boolean", function()
  local out = run_js([[
    console.log(Boolean.prototype.constructor === Boolean);
  ]])
  assert_eq(out, "true\n")
end)
