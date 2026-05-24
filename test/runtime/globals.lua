local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

-- ============================================================================
-- NaN global constant
-- ============================================================================

test("NaN is defined", function()
  local val = eval_js("NaN")
  assert(val ~= val, "expected NaN (self-inequality)")
end)

test("NaN !== NaN is true", function()
  assert_eq(eval_js("NaN !== NaN"), true)
end)

test("NaN === NaN is false", function()
  assert_eq(eval_js("NaN === NaN"), false)
end)

test("typeof NaN is 'number'", function()
  assert_eq(eval_js("typeof NaN"), "number")
end)

test("NaN + 1 is NaN", function()
  local r = eval_js("NaN + 1")
  assert(r ~= r, "NaN + 1 should be NaN")
end)

test("NaN * 0 is NaN", function()
  local r = eval_js("NaN * 0")
  assert(r ~= r, "NaN * 0 should be NaN")
end)

test("NaN comparisons all false", function()
  assert_eq(eval_js("NaN > 0"), false)
  assert_eq(eval_js("NaN < 0"), false)
  assert_eq(eval_js("NaN >= 0"), false)
  assert_eq(eval_js("NaN <= 0"), false)
end)

-- ============================================================================
-- Infinity global constant
-- ============================================================================

test("Infinity is defined", function()
  local val = eval_js("Infinity")
  assert_eq(val, math.huge)
end)

test("typeof Infinity is 'number'", function()
  assert_eq(eval_js("typeof Infinity"), "number")
end)

test("Infinity + 1 is Infinity", function()
  assert_eq(eval_js("Infinity + 1"), math.huge)
end)

test("Infinity * 2 is Infinity", function()
  assert_eq(eval_js("Infinity * 2"), math.huge)
end)

test("Infinity + Infinity is Infinity", function()
  assert_eq(eval_js("Infinity + Infinity"), math.huge)
end)

test("Infinity === Infinity is true", function()
  assert_eq(eval_js("Infinity === Infinity"), true)
end)

test("Infinity > large number", function()
  assert_eq(eval_js("Infinity > 999999999999"), true)
end)

test("-Infinity < large negative", function()
  assert_eq(eval_js("-Infinity < -999999999999"), true)
end)

test("1 / Infinity is 0", function()
  assert_eq(eval_js("1 / Infinity"), 0)
end)

-- ============================================================================
-- -Infinity
-- ============================================================================

test("-Infinity is negative infinity", function()
  assert_eq(eval_js("-Infinity"), -math.huge)
end)

test("typeof -Infinity is 'number'", function()
  assert_eq(eval_js("typeof -Infinity"), "number")
end)

test("-Infinity === -Infinity is true", function()
  assert_eq(eval_js("-Infinity === -Infinity"), true)
end)

test("Infinity === -Infinity is false", function()
  assert_eq(eval_js("Infinity === -Infinity"), false)
end)

test("-Infinity < large negative", function()
  assert_eq(eval_js("-Infinity < -999999999999"), true)
end)

test("Infinity - Infinity is NaN", function()
  local r = eval_js("Infinity - Infinity")
  assert(r ~= r, "Infinity - Infinity should be NaN")
end)

test("-Infinity + Infinity is NaN", function()
  local r = eval_js("-Infinity + Infinity")
  assert(r ~= r, "-Infinity + Infinity should be NaN")
end)

test("0 * Infinity is NaN", function()
  local r = eval_js("0 * Infinity")
  assert(r ~= r, "0 * Infinity should be NaN")
end)

-- ============================================================================
-- isNaN global function
-- ============================================================================

test("typeof isNaN is 'function'", function()
  assert_eq(eval_js("typeof isNaN"), "function")
end)

test("isNaN(NaN) is true", function()
  assert_eq(eval_js("isNaN(NaN)"), true)
end)

test("isNaN(0/0) is true", function()
  assert_eq(eval_js("isNaN(0/0)"), true)
end)

test("isNaN(42) is false", function()
  assert_eq(eval_js("isNaN(42)"), false)
end)

test("isNaN(0) is false", function()
  assert_eq(eval_js("isNaN(0)"), false)
end)

test("isNaN(Infinity) is false", function()
  assert_eq(eval_js("isNaN(Infinity)"), false)
end)

test("isNaN(-Infinity) is false", function()
  assert_eq(eval_js("isNaN(-Infinity)"), false)
end)

test("isNaN('hello') is true (coerces to NaN)", function()
  assert_eq(eval_js("isNaN('hello')"), true)
end)

test("isNaN('42') is false (coerces to 42)", function()
  assert_eq(eval_js("isNaN('42')"), false)
end)

test("isNaN('') is false (coerces to 0)", function()
  assert_eq(eval_js("isNaN('')"), false)
end)

test("isNaN(null) is false (coerces to 0)", function()
  assert_eq(eval_js("isNaN(null)"), false)
end)

test("isNaN(true) is false (coerces to 1)", function()
  assert_eq(eval_js("isNaN(true)"), false)
end)

test("isNaN(false) is false (coerces to 0)", function()
  assert_eq(eval_js("isNaN(false)"), false)
end)

test("isNaN(undefined) is true (coerces to NaN)", function()
  assert_eq(eval_js("isNaN(undefined)"), true)
end)

test("isNaN('Infinity') is false (StringToNumber → +∞)", function()
  assert_eq(eval_js("isNaN('Infinity')"), false)
end)

test("isNaN('+Infinity') is false (StringToNumber → +∞)", function()
  assert_eq(eval_js("isNaN('+Infinity')"), false)
end)

test("isNaN('-Infinity') is false (StringToNumber → -∞)", function()
  assert_eq(eval_js("isNaN('-Infinity')"), false)
end)

test("isNaN('NaN') is true (StringToNumber → NaN)", function()
  assert_eq(eval_js("isNaN('NaN')"), true)
end)

-- ============================================================================
-- isFinite global function
-- ============================================================================

test("typeof isFinite is 'function'", function()
  assert_eq(eval_js("typeof isFinite"), "function")
end)

test("isFinite(42) is true", function()
  assert_eq(eval_js("isFinite(42)"), true)
end)

test("isFinite(0) is true", function()
  assert_eq(eval_js("isFinite(0)"), true)
end)

test("isFinite(Infinity) is false", function()
  assert_eq(eval_js("isFinite(Infinity)"), false)
end)

test("isFinite(-Infinity) is false", function()
  assert_eq(eval_js("isFinite(-Infinity)"), false)
end)

test("isFinite(NaN) is false", function()
  assert_eq(eval_js("isFinite(NaN)"), false)
end)

test("isFinite('42') is true (coerces to 42)", function()
  assert_eq(eval_js("isFinite('42')"), true)
end)

test("isFinite('hello') is false (coerces to NaN)", function()
  assert_eq(eval_js("isFinite('hello')"), false)
end)

test("isFinite('') is true (coerces to 0)", function()
  assert_eq(eval_js("isFinite('')"), true)
end)

test("isFinite(null) is true (coerces to 0)", function()
  assert_eq(eval_js("isFinite(null)"), true)
end)

test("isFinite(true) is true (coerces to 1)", function()
  assert_eq(eval_js("isFinite(true)"), true)
end)

test("isFinite(false) is true (coerces to 0)", function()
  assert_eq(eval_js("isFinite(false)"), true)
end)

test("isFinite(undefined) is false (coerces to NaN)", function()
  assert_eq(eval_js("isFinite(undefined)"), false)
end)

test("isFinite('Infinity') is false (StringToNumber → +∞)", function()
  assert_eq(eval_js("isFinite('Infinity')"), false)
end)

test("isFinite('+Infinity') is false (StringToNumber → +∞)", function()
  assert_eq(eval_js("isFinite('+Infinity')"), false)
end)

test("isFinite('-Infinity') is false (StringToNumber → -∞)", function()
  assert_eq(eval_js("isFinite('-Infinity')"), false)
end)

test("isFinite('NaN') is false (StringToNumber → NaN)", function()
  assert_eq(eval_js("isFinite('NaN')"), false)
end)

-- ============================================================================
-- Shadowing (var/let in functions should shadow the globals)
-- ============================================================================

test("var NaN = 42 in function shadows global NaN", function()
  assert_eq(eval_js([[(function() { var NaN = 42; return NaN; })()]]), 42)
end)

test("global NaN is unchanged after function-local shadow", function()
  exec_js([[(function() { var NaN = 42; return NaN; })()]])
  local val = eval_js("NaN")
  assert(val ~= val, "global NaN should still be NaN after shadow")
end)

test("var Infinity = 42 in function shadows global Infinity", function()
  assert_eq(eval_js([[(function() { var Infinity = 42; return Infinity; })()]]), 42)
end)

test("global Infinity is unchanged after function-local shadow", function()
  exec_js([[(function() { var Infinity = 42; return Infinity; })()]])
  assert_eq(eval_js("Infinity"), math.huge)
end)

-- ============================================================================
-- NaN/Infinity as property names (should resolve to string keys)
-- ============================================================================

test("NaN as property name", function()
  assert_eq(exec_js([[var obj = {}; obj.NaN = 'got it'; return obj.NaN;]]), "got it")
end)

test("Infinity as property name", function()
  assert_eq(exec_js([[var obj = {}; obj.Infinity = 'val'; return obj.Infinity;]]), "val")
end)

-- ============================================================================
-- NaN/Infinity in expressions and return values
-- ============================================================================

test("NaN in array literal", function()
  local arr = eval_js("[NaN, 1, Infinity]")
  assert(arr[1] ~= arr[1], "arr[1] should be NaN")
  assert_eq(arr[2], 1)
  assert_eq(arr[3], math.huge)
end)

test("NaN as function return value", function()
  local val = eval_js([[(function() { return NaN; })()]])
  assert(val ~= val, "returned value should be NaN")
end)

test("Infinity as function return value", function()
  assert_eq(eval_js([[(function() { return Infinity; })()]]), math.huge)
end)

test("computed -Infinity via arithmetic", function()
  assert_eq(eval_js("-1 / 0"), -math.huge)
end)

test("computed Infinity via arithmetic", function()
  assert_eq(eval_js("1 / 0"), math.huge)
end)

-- ============================================================================
-- isNaN/isFinite edge cases with undefined
-- ============================================================================

test("isNaN() with no args is true (undefined → NaN)", function()
  assert_eq(eval_js("isNaN()"), true)
end)

test("isFinite() with no args is false (undefined → NaN)", function()
  assert_eq(eval_js("isFinite()"), false)
end)
