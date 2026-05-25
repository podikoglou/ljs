-- Direct tests for preamble helpers _ljs_to_number and _ljs_to_boolean.
-- Tests spec compliance for:
--   _ljs_to_number  → ECMA-262 §7.1.4 ToNumber
--   _ljs_to_boolean → ECMA-262 §7.1.2 ToBoolean
--
-- Helpers are tested through their natural JS consumers:
--   _ljs_to_number  via Number(x), isNaN(x), isFinite(x)
--   _ljs_to_boolean via Boolean(x)
--
-- All assertions reflect correct JS behavior per the spec.
-- Tests are NOT shaped around the current implementation — if something fails,
-- it's a bug in the helper, not a bug in the test.

local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

local function is_nan(x)
  return type(x) == "number" and x ~= x
end

local function assert_nan(js_expr, msg)
  local val = eval_js(js_expr)
  assert(is_nan(val), msg or (js_expr .. " should be NaN, got " .. tostring(val)))
end

-- ============================================================================
-- _ljs_to_number — ToNumber (§7.1.4)
-- ============================================================================

-- Step 1: Number → Number (identity)
test("ToNumber: number identity — 42, 0, -1, 3.14, 1e10", function()
  assert_eq(eval_js("Number(42)"), 42)
  assert_eq(eval_js("Number(0)"), 0)
  assert_eq(eval_js("Number(-1)"), -1)
  assert_eq(eval_js("Number(3.14)"), 3.14)
  assert_eq(eval_js("Number(1e10)"), 1e10)
end)

-- Step 1: NaN → NaN (identity, per spec)
test("ToNumber: NaN returns NaN", function()
  assert_nan("Number(NaN)")
end)

-- Step 1: Infinity → Infinity (identity)
test("ToNumber: Infinity returns Infinity", function()
  assert_eq(eval_js("Number(Infinity)"), math.huge)
  assert_eq(eval_js("Number(-Infinity)"), -math.huge)
end)

-- Step 1: -0 → -0 (identity)
test("ToNumber: -0 returns -0", function()
  local val = eval_js("Number(-0)")
  assert_eq(val, 0)
  assert(1 / val == -math.huge, "-0 should give -Infinity on division, got " .. tostring(1 / val))
end)

-- Step 3: undefined → NaN
test("ToNumber: undefined returns NaN", function()
  assert_nan("Number(undefined)")
end)

-- Step 4: null → +0
test("ToNumber: null returns +0", function()
  assert_eq(eval_js("Number(null)"), 0)
end)

-- Step 4: false → +0
test("ToNumber: false returns +0", function()
  assert_eq(eval_js("Number(false)"), 0)
end)

-- Step 5: true → 1
test("ToNumber: true returns 1", function()
  assert_eq(eval_js("Number(true)"), 1)
end)

-- Step 6 / §7.1.4.1: StringToNumber — empty and whitespace-only strings → +0
test("ToNumber: empty string returns +0", function()
  assert_eq(eval_js('Number("")'), 0)
end)

test("ToNumber: single space returns +0", function()
  assert_eq(eval_js("Number(' ')"), 0)
end)

test("ToNumber: tab+newline returns +0 (whitespace-only)", function()
  assert_eq(eval_js('Number("\\t\\n")'), 0)
end)

test("ToNumber: multiple spaces returns +0", function()
  assert_eq(eval_js("Number('   ')"), 0)
end)

-- §7.1.4.1: basic decimal numeric strings
test("ToNumber: '42' returns 42", function()
  assert_eq(eval_js("Number('42')"), 42)
end)

test("ToNumber: '0' returns 0", function()
  assert_eq(eval_js("Number('0')"), 0)
end)

test("ToNumber: '3.14' returns 3.14", function()
  assert_eq(eval_js("Number('3.14')"), 3.14)
end)

test("ToNumber: '.5' returns 0.5", function()
  assert_eq(eval_js("Number('.5')"), 0.5)
end)

test("ToNumber: '0.0' returns 0", function()
  assert_eq(eval_js("Number('0.0')"), 0)
end)

-- §7.1.4.1: signed strings (+/- prefix)
test("ToNumber: '+42' returns 42", function()
  assert_eq(eval_js("Number('+42')"), 42)
end)

test("ToNumber: '-42' returns -42", function()
  assert_eq(eval_js("Number('-42')"), -42)
end)

test("ToNumber: '+0' returns +0", function()
  assert_eq(eval_js("Number('+0')"), 0)
end)

test("ToNumber: '-0' returns -0", function()
  local val = eval_js("Number('-0')")
  assert_eq(val, 0)
  assert(1 / val == -math.huge, "'-0' should give -Infinity on division")
end)

-- §7.1.4.1: exponents
test("ToNumber: '1e3' returns 1000", function()
  assert_eq(eval_js("Number('1e3')"), 1000)
end)

test("ToNumber: '1E3' returns 1000 (uppercase E)", function()
  assert_eq(eval_js("Number('1E3')"), 1000)
end)

test("ToNumber: '1.5e-2' returns 0.015", function()
  assert_eq(eval_js("Number('1.5e-2')"), 0.015)
end)

test("ToNumber: '2E+4' returns 20000", function()
  assert_eq(eval_js("Number('2E+4')"), 20000)
end)

test("ToNumber: '.1e1' returns 1", function()
  assert_eq(eval_js("Number('.1e1')"), 1)
end)

-- §7.1.4.1: leading zeros (valid per spec — not treated as octal in StringNumericLiteral)
test("ToNumber: '007' returns 7 (leading zeros are decimal)", function()
  assert_eq(eval_js("Number('007')"), 7)
end)

test("ToNumber: '00.5' returns 0.5 (leading zeros decimal)", function()
  assert_eq(eval_js("Number('00.5')"), 0.5)
end)

-- §7.1.4.1: Infinity strings
test("ToNumber: 'Infinity' returns +Infinity", function()
  assert_eq(eval_js("Number('Infinity')"), math.huge)
end)

test("ToNumber: '+Infinity' returns +Infinity", function()
  assert_eq(eval_js("Number('+Infinity')"), math.huge)
end)

test("ToNumber: '-Infinity' returns -Infinity", function()
  assert_eq(eval_js("Number('-Infinity')"), -math.huge)
end)

-- §7.1.4.1: NonDecimalIntegerLiteral — hex, octal, binary
test("ToNumber: '0x1F' returns 31 (hex)", function()
  assert_eq(eval_js("Number('0x1F')"), 31)
end)

test("ToNumber: '0xFF' returns 255 (hex)", function()
  assert_eq(eval_js("Number('0xFF')"), 255)
end)

test("ToNumber: '0XAB' returns 171 (uppercase hex)", function()
  assert_eq(eval_js("Number('0XAB')"), 171)
end)

test("ToNumber: '0o17' returns 15 (octal)", function()
  assert_eq(eval_js("Number('0o17')"), 15)
end)

test("ToNumber: '0O77' returns 63 (uppercase octal)", function()
  assert_eq(eval_js("Number('0O77')"), 63)
end)

test("ToNumber: '0b1010' returns 10 (binary)", function()
  assert_eq(eval_js("Number('0b1010')"), 10)
end)

test("ToNumber: '0B110' returns 6 (uppercase binary)", function()
  assert_eq(eval_js("Number('0B110')"), 6)
end)

-- §7.1.4.1: whitespace-padded numeric strings (spec: trim before parse)
test("ToNumber: '  42  ' returns 42 (whitespace-padded)", function()
  assert_eq(eval_js("Number('  42  ')"), 42)
end)

test("ToNumber: '  3.14  ' returns 3.14 (whitespace-padded float)", function()
  assert_eq(eval_js("Number('  3.14  ')"), 3.14)
end)

test("ToNumber: '  Infinity  ' returns Infinity (whitespace-padded)", function()
  assert_eq(eval_js("Number('  Infinity  ')"), math.huge)
end)

test("ToNumber: '  -Infinity  ' returns -Infinity (whitespace-padded)", function()
  assert_eq(eval_js("Number('  -Infinity  ')"), -math.huge)
end)

test("ToNumber: '\\n42\\t' returns 42 (line terminator whitespace)", function()
  assert_eq(eval_js('Number("\\n42\\t")'), 42)
end)

test("ToNumber: '  0x1F  ' returns 31 (whitespace-padded hex)", function()
  assert_eq(eval_js("Number('  0x1F  ')"), 31)
end)

-- §7.1.4.1: strings that MUST produce NaN
test("ToNumber: 'hello' returns NaN", function()
  assert_nan("Number('hello')")
end)

test("ToNumber: 'NaN' returns NaN (not a StringNumericLiteral)", function()
  assert_nan("Number('NaN')")
end)

test("ToNumber: '123abc' returns NaN (trailing junk)", function()
  assert_nan("Number('123abc')")
end)

test("ToNumber: 'abc123' returns NaN (leading alpha)", function()
  assert_nan("Number('abc123')")
end)

test("ToNumber: 'undefined' returns NaN", function()
  assert_nan("Number('undefined')")
end)

test("ToNumber: 'null' returns NaN", function()
  assert_nan("Number('null')")
end)

test("ToNumber: 'true' returns NaN", function()
  assert_nan("Number('true')")
end)

test("ToNumber: 'false' returns NaN", function()
  assert_nan("Number('false')")
end)

test("ToNumber: '{}' returns NaN", function()
  assert_nan("Number('{}')")
end)

test("ToNumber: '[object Object]' returns NaN", function()
  assert_nan("Number('[object Object]')")
end)

test("ToNumber: '10 20' returns NaN (embedded space)", function()
  assert_nan("Number('10 20')")
end)

test("ToNumber: '--42' returns NaN (double minus)", function()
  assert_nan("Number('--42')")
end)

test("ToNumber: '++42' returns NaN (double plus)", function()
  assert_nan("Number('++42')")
end)

test("ToNumber: '42f' returns NaN (trailing letter)", function()
  assert_nan("Number('42f')")
end)

-- Steps 7–9: Object → ToPrimitive → recurse
test("ToNumber: plain object {} returns NaN", function()
  assert_nan("Number({})")
end)

test("ToNumber: object with valueOf returning 42 returns 42", function()
  assert_eq(eval_js("Number({valueOf: function() { return 42 }})"), 42)
end)

test("ToNumber: object with toString returning '7' returns 7", function()
  assert_eq(eval_js("Number({toString: function() { return '7' }})"), 7)
end)

test("ToNumber: object with valueOf returning string '3' returns 3", function()
  assert_eq(eval_js("Number({valueOf: function() { return '3' }})"), 3)
end)

-- Cross-check via isNaN and isFinite (both call _ljs_to_number internally)
test("ToNumber: isNaN('') returns false (empty string → +0)", function()
  assert_eq(eval_js("isNaN('')"), false)
end)

test("ToNumber: isNaN(' ') returns false (whitespace → +0)", function()
  assert_eq(eval_js("isNaN(' ')"), false)
end)

test("ToNumber: isNaN('hello') returns true", function()
  assert_eq(eval_js("isNaN('hello')"), true)
end)

test("ToNumber: isFinite('42') returns true", function()
  assert_eq(eval_js("isFinite('42')"), true)
end)

test("ToNumber: isFinite('Infinity') returns false", function()
  assert_eq(eval_js("isFinite('Infinity')"), false)
end)

test("ToNumber: isFinite('hello') returns false", function()
  assert_eq(eval_js("isFinite('hello')"), false)
end)

test("ToNumber: isFinite(null) returns true (null → +0)", function()
  assert_eq(eval_js("isFinite(null)"), true)
end)

test("ToNumber: isFinite(undefined) returns false (undefined → NaN)", function()
  assert_eq(eval_js("isFinite(undefined)"), false)
end)

test("ToNumber: isFinite('') returns true (empty string → +0)", function()
  assert_eq(eval_js("isFinite('')"), true)
end)

-- ============================================================================
-- _ljs_to_boolean — ToBoolean (§7.1.2)
-- ============================================================================

-- Step 2: falsy values
test("ToBoolean: undefined returns false", function()
  assert_eq(eval_js("Boolean(undefined)"), false)
end)

test("ToBoolean: null returns false", function()
  assert_eq(eval_js("Boolean(null)"), false)
end)

test("ToBoolean: +0 returns false", function()
  assert_eq(eval_js("Boolean(0)"), false)
end)

test("ToBoolean: -0 returns false", function()
  assert_eq(eval_js("Boolean(-0)"), false)
end)

test("ToBoolean: NaN returns false", function()
  assert_eq(eval_js("Boolean(NaN)"), false)
end)

test("ToBoolean: empty string returns false", function()
  assert_eq(eval_js('Boolean("")'), false)
end)

-- Step 1: boolean identity
test("ToBoolean: true returns true", function()
  assert_eq(eval_js("Boolean(true)"), true)
end)

test("ToBoolean: false returns false (identity)", function()
  assert_eq(eval_js("Boolean(false)"), false)
end)

-- Step 4: truthy numbers
test("ToBoolean: 1 returns true", function()
  assert_eq(eval_js("Boolean(1)"), true)
end)

test("ToBoolean: -1 returns true", function()
  assert_eq(eval_js("Boolean(-1)"), true)
end)

test("ToBoolean: 42 returns true", function()
  assert_eq(eval_js("Boolean(42)"), true)
end)

test("ToBoolean: 0.5 returns true", function()
  assert_eq(eval_js("Boolean(0.5)"), true)
end)

test("ToBoolean: Infinity returns true", function()
  assert_eq(eval_js("Boolean(Infinity)"), true)
end)

test("ToBoolean: -Infinity returns true", function()
  assert_eq(eval_js("Boolean(-Infinity)"), true)
end)

test("ToBoolean: 1e-308 returns true (very small nonzero)", function()
  assert_eq(eval_js("Boolean(1e-308)"), true)
end)

-- Step 4: truthy strings (anything non-empty)
test("ToBoolean: 'hello' returns true", function()
  assert_eq(eval_js("Boolean('hello')"), true)
end)

test("ToBoolean: '0' returns true (non-empty string!)", function()
  assert_eq(eval_js("Boolean('0')"), true)
end)

test("ToBoolean: 'false' returns true (non-empty string!)", function()
  assert_eq(eval_js("Boolean('false')"), true)
end)

test("ToBoolean: ' ' returns true (whitespace string)", function()
  assert_eq(eval_js("Boolean(' ')"), true)
end)

test("ToBoolean: '\\n' returns true (newline string)", function()
  assert_eq(eval_js('Boolean("\\n")'), true)
end)

test("ToBoolean: 'NaN' returns true (non-empty string!)", function()
  assert_eq(eval_js("Boolean('NaN')"), true)
end)

test("ToBoolean: 'null' returns true (non-empty string!)", function()
  assert_eq(eval_js("Boolean('null')"), true)
end)

test("ToBoolean: 'undefined' returns true (non-empty string!)", function()
  assert_eq(eval_js("Boolean('undefined')"), true)
end)

-- Step 4: truthy objects
test("ToBoolean: {} returns true (empty object)", function()
  assert_eq(eval_js("Boolean({})"), true)
end)

test("ToBoolean: [] returns true (empty array)", function()
  assert_eq(eval_js("Boolean([])"), true)
end)

test("ToBoolean: function(){} returns true", function()
  assert_eq(eval_js("Boolean(function(){})"), true)
end)
