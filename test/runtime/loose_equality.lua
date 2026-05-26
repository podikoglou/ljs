local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local H = require("test.helpers.transpile")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js
local expr_code = H.expr_code

-- ============================================================================
-- §7.2.13 IsLooselyEqual — full spec coverage
-- All tests assert correct JS behavior per ECMA-262.
-- Some tests may be blocked by missing features (see individual comments).
-- ============================================================================

-- ============================================================================
-- Step 1: Same type → IsStrictlyEqual (§7.2.14)
-- ============================================================================

test("number == same number → true", function()
  assert_eq(eval_js("1 == 1"), true)
end)

test("number == different number → false", function()
  assert_eq(eval_js("1 == 2"), false)
end)

test("string == same string → true", function()
  assert_eq(eval_js('("a" == "a")'), true)
end)

test("string == different string → false", function()
  assert_eq(eval_js('("a" == "b")'), false)
end)

test("boolean == same boolean → true", function()
  assert_eq(eval_js("true == true"), true)
end)

test("boolean == different boolean → false", function()
  assert_eq(eval_js("true == false"), false)
end)

test("null == null → true", function()
  assert_eq(eval_js("null == null"), true)
end)

test("undefined == undefined → true", function()
  assert_eq(eval_js("undefined == undefined"), true)
end)

test("NaN == NaN → false (NaN never equals anything, even itself)", function()
  assert_eq(eval_js("NaN == NaN"), false)
end)

test("Infinity == Infinity → true", function()
  assert_eq(eval_js("Infinity == Infinity"), true)
end)

test("-0 == 0 → true", function()
  assert_eq(eval_js("-0 == 0"), true)
end)

test("-1 == -1 → true", function()
  assert_eq(eval_js("-1 == -1"), true)
end)

test("{} == {} → false (different references)", function()
  assert_eq(eval_js("({}) == ({})"), false)
end)

test("same object reference == itself → true", function()
  assert_eq(exec_js("let o = {}; return o == o;"), true)
end)

-- ============================================================================
-- Step 2-3: null == undefined → true (and vice versa)
-- ============================================================================

test("null == undefined → true", function()
  assert_eq(eval_js("null == undefined"), true)
end)

test("undefined == null → true", function()
  assert_eq(eval_js("undefined == null"), true)
end)

-- ============================================================================
-- null/undefined vs everything else → false
-- null only equals null and undefined (per §7.2.13 steps 2-3 and 14).
-- This is a key difference from === where null/undefined don't coerce to 0.
-- ============================================================================

test("null == 0 → false", function()
  assert_eq(eval_js("null == 0"), false)
end)

test('null == "" → false', function()
  assert_eq(eval_js('null == ""'), false)
end)

test("null == false → false", function()
  assert_eq(eval_js("null == false"), false)
end)

test("undefined == 0 → false", function()
  assert_eq(eval_js("undefined == 0"), false)
end)

test('undefined == "" → false', function()
  assert_eq(eval_js('undefined == ""'), false)
end)

test("undefined == false → false", function()
  assert_eq(eval_js("undefined == false"), false)
end)

test("null == {} → false", function()
  assert_eq(eval_js("null == {}"), false)
end)

test("undefined == {} → false", function()
  assert_eq(eval_js("undefined == {}"), false)
end)

-- ============================================================================
-- Step 5-6: Number == String → Number == ToNumber(String)
-- StringToNumber per §7.1.4.1: "" → +0, "0xff" → 255, "abc" → NaN
-- ============================================================================

test('1 == "1" → true', function()
  assert_eq(eval_js('1 == "1"'), true)
end)

test('"1" == 1 → true (symmetric)', function()
  assert_eq(eval_js('"1" == 1'), true)
end)

test('0 == "" → true (empty string coerces to +0)', function()
  assert_eq(eval_js('0 == ""'), true)
end)

test('0 == "0" → true', function()
  assert_eq(eval_js('0 == "0"'), true)
end)

test('1 == "abc" → false ("abc" coerces to NaN)', function()
  assert_eq(eval_js('1 == "abc"'), false)
end)

test('"abc" == 1 → false (symmetric)', function()
  assert_eq(eval_js('"abc" == 1'), false)
end)

test('255 == "0xff" → true (hex string coerces to number)', function()
  assert_eq(eval_js('255 == "0xff"'), true)
end)

test('255 == "255" → true', function()
  assert_eq(eval_js('255 == "255"'), true)
end)

test('Infinity == "Infinity" → true', function()
  assert_eq(eval_js('Infinity == "Infinity"'), true)
end)

test('NaN == "NaN" → false (NaN never equals anything)', function()
  assert_eq(eval_js('NaN == "NaN"'), false)
end)

test('0 == " \\n " → true (whitespace-only string coerces to +0)', function()
  assert_eq(eval_js('0 == " \\n "'), true)
end)

-- ============================================================================
-- Step 9-10: Boolean == X → ToNumber(Boolean) == X
-- ToNumber(false) → +0, ToNumber(true) → 1 (§7.1.4)
-- ============================================================================

test("false == 0 → true (false coerces to +0)", function()
  assert_eq(eval_js("false == 0"), true)
end)

test("true == 1 → true (true coerces to 1)", function()
  assert_eq(eval_js("true == 1"), true)
end)

test("true == 2 → false", function()
  assert_eq(eval_js("true == 2"), false)
end)

test("0 == false → true (symmetric)", function()
  assert_eq(eval_js("0 == false"), true)
end)

test("1 == true → true (symmetric)", function()
  assert_eq(eval_js("1 == true"), true)
end)

test('false == "" → true (false→0, ""→0)', function()
  assert_eq(eval_js('false == ""'), true)
end)

test('true == "1" → true (true→1, "1"→1)', function()
  assert_eq(eval_js('true == "1"'), true)
end)

test('false == "0" → true (false→0, "0"→0)', function()
  assert_eq(eval_js('false == "0"'), true)
end)

test('true == "true" → false (true→1, "true"→NaN)', function()
  assert_eq(eval_js('true == "true"'), false)
end)

test('false == "false" → false (false→0, "false"→NaN)', function()
  assert_eq(eval_js('false == "false"'), false)
end)

-- ============================================================================
-- Step 11-12: Object == primitive → ToPrimitive(Object) == primitive
-- OrdinaryToPrimitive (§7.1.1.1) with hint=number: valueOf first, then toString.
-- ============================================================================

test('({}) == "[object Object]" → true (ToPrimitive uses toString)', function()
  assert_eq(eval_js('({}) == "[object Object]"'), true)
end)

test("object with custom valueOf == number", function()
  assert_eq(exec_js("let o = {valueOf: function() { return 42; }}; return o == 42;"), true)
end)

test("object with custom toString == string", function()
  assert_eq(exec_js('let o = {toString: function() { return "hi"; }}; return o == "hi";'), true)
end)

test(
  "object with custom valueOf == string (valueOf returns number, then Number==String)",
  function()
    assert_eq(exec_js('let o = {valueOf: function() { return 42; }}; return o == "42";'), true)
  end
)

-- §7.1.1.1: Non-callable valueOf must be skipped (IsCallable check)
test("non-callable valueOf is skipped, falls through to toString", function()
  assert_eq(
    exec_js('let o = {valueOf: 42, toString: function() { return "hello"; }}; return o == "hello";'),
    true
  )
end)

test("non-callable valueOf and toString both skipped → TypeError", function()
  local ok, err = pcall(exec_js, "let o = {valueOf: 42, toString: 99}; return o == 1;")
  assert(not ok, "expected TypeError")
  assert(string.find(err, "TypeError"), "expected TypeError message, got: " .. tostring(err))
end)

test("non-callable toString is skipped, valueOf is used", function()
  assert_eq(
    exec_js("let o = {valueOf: function() { return 7; }, toString: 'notfunc'}; return o == 7;"),
    true
  )
end)

-- Arrays: Array.prototype.toString calls join(","), producing a string
test('[] == "" → true (array toString → join → "")', function()
  assert_eq(eval_js('[] == ""'), true)
end)

test('[1,2] == "1,2" → true (array toString → join → "1,2")', function()
  assert_eq(eval_js('[1,2] == "1,2"'), true)
end)

test('[] == 0 → true ([]→""→0, 0==0)', function()
  assert_eq(eval_js("[] == 0"), true)
end)

test('[0] == 0 → true ([0]→"0"→0, 0==0)', function()
  assert_eq(eval_js("[0] == 0"), true)
end)

test('[0] == false → true ([0]→"0"→0, false→0, 0==0)', function()
  assert_eq(eval_js("[0] == false"), true)
end)

test('[1] == true → true ([1]→"1"→1, true→1, 1==1)', function()
  assert_eq(eval_js("[1] == true"), true)
end)

-- Blocked by #14: String constructor
test('new String("a") == "a" → true', function()
  assert_eq(eval_js('new String("a") == "a"'), true)
end)

-- Blocked by #13: Number constructor
test("new Number(1) == 1 → true", function()
  assert_eq(eval_js("new Number(1) == 1"), true)
end)

-- Blocked by #71: Boolean constructor
test("new Boolean(false) == false → true", function()
  assert_eq(eval_js("new Boolean(false) == false"), true)
end)

test("new Boolean(true) == true → true", function()
  assert_eq(eval_js("new Boolean(true) == true"), true)
end)

test("new Number(NaN) == NaN → false", function()
  assert_eq(eval_js("new Number(NaN) == NaN"), false)
end)

-- ============================================================================
-- != operator — logical negation of == (§13.11.1)
-- ============================================================================

test("1 != 2 → true", function()
  assert_eq(eval_js("1 != 2"), true)
end)

test("1 != 1 → false", function()
  assert_eq(eval_js("1 != 1"), false)
end)

test("null != undefined → false", function()
  assert_eq(eval_js("null != undefined"), false)
end)

test("null != 0 → true", function()
  assert_eq(eval_js("null != 0"), true)
end)

test("NaN != NaN → true", function()
  assert_eq(eval_js("NaN != NaN"), true)
end)

test('"" != false → false', function()
  assert_eq(eval_js('"" != false'), false)
end)

-- ============================================================================
-- Chained and compound expressions
-- ============================================================================

test("(1 == 1) === true → true", function()
  assert_eq(eval_js("(1 == 1) === true"), true)
end)

test("(null == undefined) === true → true", function()
  assert_eq(eval_js("(null == undefined) === true"), true)
end)

test('typeof (1 == 1) === "boolean" → true', function()
  assert_eq(eval_js('typeof (1 == 1) === "boolean"'), true)
end)

test("1 == 2 == false → true (left-to-right: (1==2)==false → false==false)", function()
  assert_eq(eval_js("1 == 2 == false"), true)
end)

test("== in if condition", function()
  assert_eq(exec_js("if (null == undefined) { return 'yes'; } return 'no';"), "yes")
end)

test("!= in if condition", function()
  assert_eq(exec_js("if (null != 0) { return 'yes'; } return 'no';"), "yes")
end)

test("== in ternary", function()
  assert_eq(eval_js("1 == '1' ? 'yes' : 'no'"), "yes")
end)

-- ============================================================================
-- Transpiler unit tests
-- ============================================================================

test("transpiler: a == b emits _ljs_eq(a, b)", function()
  assert_eq(expr_code("a == b"), "_ljs_eq(a, b)")
end)

test("transpiler: a != b emits not _ljs_eq(a, b)", function()
  assert_eq(expr_code("a != b"), "local _ = not _ljs_eq(a, b)")
end)

-- ============================================================================
-- NaN edge cases
-- ============================================================================

test("NaN == 0 → false", function()
  assert_eq(eval_js("NaN == 0"), false)
end)

test("NaN == undefined → false", function()
  assert_eq(eval_js("NaN == undefined"), false)
end)

test("NaN == null → false", function()
  assert_eq(eval_js("NaN == null"), false)
end)

test("NaN == false → false", function()
  assert_eq(eval_js("NaN == false"), false)
end)

test('NaN == "" → false', function()
  assert_eq(eval_js('NaN == ""'), false)
end)

-- ============================================================================
-- String coercion edge cases
-- ============================================================================

test('"1.0" == 1 → true (StringToNumber("1.0") === 1)', function()
  assert_eq(eval_js('"1.0" == 1'), true)
end)

test('"0e0" == 0 → true', function()
  assert_eq(eval_js('"0e0" == 0'), true)
end)
