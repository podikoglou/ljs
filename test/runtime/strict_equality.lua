local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

-- ============================================================================
-- §7.2.14 IsStrictlyEqual — full spec coverage
-- ============================================================================

-- ============================================================================
-- Same value (identity)
-- ============================================================================

test("number === same number", function()
  assert_eq(eval_js("1 === 1"), true)
end)

test("string === same string", function()
  assert_eq(eval_js('("abc" === "abc")'), true)
end)

test("boolean === same boolean", function()
  assert_eq(eval_js("true === true"), true)
end)

test("object identity", function()
  assert_eq(eval_js("({}) === ({})"), false)
end)

test("same object is === itself", function()
  assert_eq(eval_js("(function(){ var o = {}; return o === o; })()"), true)
end)

-- ============================================================================
-- Different types → false (no coercion)
-- ============================================================================

test("number === string → false", function()
  assert_eq(eval_js("1 === '1'"), false)
end)

test("boolean === number → false", function()
  assert_eq(eval_js("true === 1"), false)
end)

test("null === undefined → false", function()
  assert_eq(eval_js("null === undefined"), false)
end)

-- ============================================================================
-- nil/_ljs_undefined cross-case (the Phase 2 fix)
-- ============================================================================

test("undefined === undefined (both sentinel)", function()
  assert_eq(eval_js("undefined === undefined"), true)
end)

test("undefined === undefined (one nil from missing arg)", function()
  assert_eq(eval_js("(function(a){ return a === undefined; })()"), true)
end)

test("null === null", function()
  assert_eq(eval_js("null === null"), true)
end)

-- ============================================================================
-- NaN and ±0
-- ============================================================================

test("NaN === NaN → false", function()
  assert_eq(eval_js("NaN === NaN"), false)
end)

test("+0 === -0 → true", function()
  assert_eq(eval_js("+0 === -0"), true)
end)

-- ============================================================================
-- !== (strict inequality)
-- ============================================================================

test("undefined !== undefined → false", function()
  assert_eq(eval_js("undefined !== undefined"), false)
end)

test("undefined !== null → true", function()
  assert_eq(eval_js("undefined !== null"), true)
end)

test("NaN !== NaN → true", function()
  assert_eq(eval_js("NaN !== NaN"), true)
end)

-- ============================================================================
-- Object.is (SameValue, not SameValueNonNumber/IsStrictlyEqual)
-- ============================================================================

test("Object.is(NaN, NaN) → true", function()
  assert_eq(eval_js("Object.is(NaN, NaN)"), true)
end)

test("Object.is(+0, -0) → false", function()
  assert_eq(eval_js("Object.is(+0, -0)"), false)
end)

test("Object.is(0, 0) → true", function()
  assert_eq(eval_js("Object.is(0, 0)"), true)
end)

test("Object.is(undefined, undefined) → true", function()
  assert_eq(eval_js("Object.is(undefined, undefined)"), true)
end)

test("Object.is with nil/sentinel cross-case", function()
  assert_eq(eval_js("(function(a){ return Object.is(a, undefined); })()"), true)
end)

test("Object.is(null, undefined) → false", function()
  assert_eq(eval_js("Object.is(null, undefined)"), false)
end)

-- ============================================================================
-- _ljs_same_value_zero (used by Array.prototype.includes)
-- ============================================================================

test("[1,,3].includes(undefined) treats holes as undefined", function()
  assert_eq(eval_js("[1,,3].includes(undefined)"), true)
end)

test("[undefined].includes(undefined)", function()
  assert_eq(eval_js("[undefined].includes(undefined)"), true)
end)
