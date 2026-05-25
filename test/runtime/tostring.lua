-- Direct tests for _ljs_tostring number formatting (ECMA-262 §7.1.17 Number::toString).
-- Tests exercise the helper through its natural JS consumers:
--   _ljs_tostring via string concatenation ("" + expr)
--   String() via String(expr)            — issue #95
--   Number.prototype.toString()          — issue #96
--   console.log output                   — uses _ljs_tostring internally
--
-- All assertions reflect correct JS behavior per the spec.
-- Tests are NOT shaped around the current implementation — if something fails,
-- it is a bug in the helper, not a bug in the test.

local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

-- ============================================================================
-- _ljs_tostring via string concatenation ("" + expr) — issue #65
-- ============================================================================

-- integer-valued floats from arithmetic
test('tostring: "" + (6/2) → "3" (division yields integer-valued float)', function()
  assert_eq(eval_js('"" + (6/2)'), "3")
end)

test('tostring: "" + (2**3) → "8" (exponentiation yields integer-valued float)', function()
  assert_eq(eval_js('"" + (2**3)'), "8")
end)

test('tostring: "" + (1.5+2.5) → "4" (addition yields integer-valued float)', function()
  assert_eq(eval_js('"" + (1.5+2.5)'), "4")
end)

test('tostring: "" + (10-6) → "4" (subtraction yields integer-valued float)', function()
  assert_eq(eval_js('"" + (10-6)'), "4")
end)

test('tostring: "" + (12/4) → "3" (division yields integer-valued float)', function()
  assert_eq(eval_js('"" + (12/4)'), "3")
end)

-- true floats stay with decimal
test('tostring: "" + 0.5 → "0.5" (true float keeps decimal)', function()
  assert_eq(eval_js('"" + 0.5'), "0.5")
end)

test('tostring: "" + 3.14 → "3.14" (true float keeps decimal)', function()
  assert_eq(eval_js('"" + 3.14'), "3.14")
end)

test('tostring: "" + 1.1 → "1.1" (true float keeps decimal)', function()
  assert_eq(eval_js('"" + 1.1'), "1.1")
end)

-- integer literals (Lua integer type on 5.3+)
test('tostring: "" + 4 → "4" (integer literal)', function()
  assert_eq(eval_js('"" + 4'), "4")
end)

test('tostring: "" + 0 → "0" (zero literal)', function()
  assert_eq(eval_js('"" + 0'), "0")
end)

test('tostring: "" + (-7) → "-7" (negative integer literal)', function()
  assert_eq(eval_js('"" + (-7)'), "-7")
end)

test('tostring: "" + (-6/2) → "-3" (negative integer-valued float from division)', function()
  assert_eq(eval_js('"" + (-6/2)'), "-3")
end)

test(
  'tostring: "" + (-2**3) → "-8" (negative integer-valued float from exponentiation)',
  function()
    assert_eq(eval_js('"" + (-2**3)'), "-8")
  end
)

test(
  'tostring: "" + (1.5-4.5) → "-3" (negative integer-valued float from subtraction)',
  function()
    assert_eq(eval_js('"" + (1.5-4.5)'), "-3")
  end
)

-- NaN / Infinity via string concatenation
test('tostring: "" + NaN → "NaN"', function()
  assert_eq(eval_js('"" + NaN'), "NaN")
end)

test('tostring: "" + Infinity → "Infinity"', function()
  assert_eq(eval_js('"" + Infinity'), "Infinity")
end)

test('tostring: "" + (-Infinity) → "-Infinity"', function()
  assert_eq(eval_js('"" + (-Infinity)'), "-Infinity")
end)

-- string + number from both sides
test('tostring: "x" + (6/2) → "x3"', function()
  assert_eq(eval_js('"x" + (6/2)'), "x3")
end)

test('tostring: (6/2) + "x" → "3x"', function()
  assert_eq(eval_js('(6/2) + "x"'), "3x")
end)

-- null / undefined
test('tostring: "" + null → "null"', function()
  assert_eq(eval_js('"" + null'), "null")
end)

test('tostring: "" + undefined → "undefined"', function()
  assert_eq(eval_js('"" + undefined'), "undefined")
end)

-- booleans
test('tostring: "" + true → "true"', function()
  assert_eq(eval_js('"" + true'), "true")
end)

test('tostring: "" + false → "false"', function()
  assert_eq(eval_js('"" + false'), "false")
end)

-- ============================================================================
-- String() global — issue #95
-- ============================================================================

test('String(6/2) → "3" (integer-valued float)', function()
  assert_eq(eval_js("String(6/2)"), "3")
end)

test('String(2**3) → "8" (exponentiation yields integer-valued float)', function()
  assert_eq(eval_js("String(2**3)"), "8")
end)

test('String(1.5+2.5) → "4" (addition yields integer-valued float)', function()
  assert_eq(eval_js("String(1.5+2.5)"), "4")
end)

test('String(-6/2) → "-3" (negative integer-valued float from division)', function()
  assert_eq(eval_js("String(-6/2)"), "-3")
end)

test('String(-2**3) → "-8" (negative integer-valued float from exponentiation)', function()
  assert_eq(eval_js("String(-2**3)"), "-8")
end)

test('String(0.5) → "0.5" (true float)', function()
  assert_eq(eval_js("String(0.5)"), "0.5")
end)

test('String(3.14) → "3.14" (true float)', function()
  assert_eq(eval_js("String(3.14)"), "3.14")
end)

test('String(4) → "4" (integer)', function()
  assert_eq(eval_js("String(4)"), "4")
end)

test('String(0) → "0" (zero)', function()
  assert_eq(eval_js("String(0)"), "0")
end)

test('String(NaN) → "NaN"', function()
  assert_eq(eval_js("String(NaN)"), "NaN")
end)

test('String(Infinity) → "Infinity"', function()
  assert_eq(eval_js("String(Infinity)"), "Infinity")
end)

test('String(-Infinity) → "-Infinity"', function()
  assert_eq(eval_js("String(-Infinity)"), "-Infinity")
end)

test('String(null) → "null"', function()
  assert_eq(eval_js("String(null)"), "null")
end)

test('String(undefined) → "undefined"', function()
  assert_eq(eval_js("String(undefined)"), "undefined")
end)

test('String(true) → "true"', function()
  assert_eq(eval_js("String(true)"), "true")
end)

test('String(false) → "false"', function()
  assert_eq(eval_js("String(false)"), "false")
end)

test('String() → "" (no args)', function()
  assert_eq(eval_js("String()"), "")
end)

-- ============================================================================
-- Number.prototype.toString() — issue #96
-- ============================================================================

test('(6/2).toString() → "3" (integer-valued float)', function()
  assert_eq(eval_js("(6/2).toString()"), "3")
end)

test('(2**3).toString() → "8" (exponentiation yields integer-valued float)', function()
  assert_eq(eval_js("(2**3).toString()"), "8")
end)

test('(1.5+2.5).toString() → "4" (addition yields integer-valued float)', function()
  assert_eq(eval_js("(1.5+2.5).toString()"), "4")
end)

test('(-6/2).toString() → "-3" (negative integer-valued float from division)', function()
  assert_eq(eval_js("(-6/2).toString()"), "-3")
end)

test('(-2**3).toString() → "-8" (negative integer-valued float from exponentiation)', function()
  assert_eq(eval_js("(-2**3).toString()"), "-8")
end)

test('(0.5).toString() → "0.5" (true float)', function()
  assert_eq(eval_js("(0.5).toString()"), "0.5")
end)

test('(3.14).toString() → "3.14" (true float)', function()
  assert_eq(eval_js("(3.14).toString()"), "3.14")
end)

test('(4).toString() → "4" (integer)', function()
  assert_eq(eval_js("(4).toString()"), "4")
end)

test('(NaN).toString() → "NaN"', function()
  assert_eq(eval_js("(NaN).toString()"), "NaN")
end)

test('(Infinity).toString() → "Infinity"', function()
  assert_eq(eval_js("(Infinity).toString()"), "Infinity")
end)

test('(-Infinity).toString() → "-Infinity"', function()
  assert_eq(eval_js("(-Infinity).toString()"), "-Infinity")
end)

-- ============================================================================
-- console.log output uses _ljs_tostring — issue #65
-- ============================================================================

local function capture_stdout(fn)
  local old = io.stdout
  local tmp = io.tmpfile()
  io.stdout = tmp
  fn()
  tmp:seek("set")
  local out = tmp:read("*a")
  tmp:close()
  io.stdout = old
  return out
end

test('console.log(6/2) outputs "3\\n" (integer-valued float)', function()
  local out = capture_stdout(function()
    exec_js("console.log(6/2);")
  end)
  assert_eq(out, "3\n")
end)

test('console.log(2**3) outputs "8\\n" (integer-valued float)', function()
  local out = capture_stdout(function()
    exec_js("console.log(2**3);")
  end)
  assert_eq(out, "8\n")
end)

test('console.log(NaN) outputs "NaN\\n"', function()
  local out = capture_stdout(function()
    exec_js("console.log(NaN);")
  end)
  assert_eq(out, "NaN\n")
end)

test('console.log(Infinity) outputs "Infinity\\n"', function()
  local out = capture_stdout(function()
    exec_js("console.log(Infinity);")
  end)
  assert_eq(out, "Infinity\n")
end)

test('console.log(-Infinity) outputs "-Infinity\\n"', function()
  local out = capture_stdout(function()
    exec_js("console.log(-Infinity);")
  end)
  assert_eq(out, "-Infinity\n")
end)

test('console.log(0.5) outputs "0.5\\n" (true float)', function()
  local out = capture_stdout(function()
    exec_js("console.log(0.5);")
  end)
  assert_eq(out, "0.5\n")
end)

-- ============================================================================
-- Edge cases
-- ============================================================================

test('tostring: "" + (0/1) → "0" (zero from division)', function()
  assert_eq(eval_js('"" + (0/1)'), "0")
end)

test('tostring: "" + (0.0) → "0" (float zero literal)', function()
  assert_eq(eval_js('"" + (0.0)'), "0")
end)

test('tostring: "" + (100/10) → "10" (larger integer-valued float)', function()
  assert_eq(eval_js('"" + (100/10)'), "10")
end)

test('String(-0) → "0" (negative zero formats as "0")', function()
  assert_eq(eval_js("String(-0)"), "0")
end)
