local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_table_eq = R.test, R.assert_eq, T.assert_table_eq
local eval_js, exec_js, transpile_js = R.eval_js, R.exec_js, R.transpile_js

-- Ported from rxi/json.lua test/test.lua. Adapted to exercise JSON.parse
-- and JSON.stringify through the JS→Lua transpiler instead of calling the
-- library directly. Some rxi tests that exercise raw-library error paths
-- (sparse arrays, mixed keys) are still included but go through
-- JSON.stringify which has its own handling.

-- ============================================================================
-- JSON.parse — numbers (ported: rxi "numbers")
-- ============================================================================

test("parse number: 123.456", function()
  assert_eq(exec_js("return JSON.parse('123.456');"), 123.456)
end)

test("parse number: -123", function()
  assert_eq(exec_js("return JSON.parse('-123');"), -123)
end)

test("parse number: -567.765", function()
  assert_eq(exec_js("return JSON.parse('-567.765');"), -567.765)
end)

test("parse number: 0", function()
  assert_eq(exec_js("return JSON.parse('0');"), 0)
end)

test("parse number: 12.3", function()
  assert_eq(exec_js("return JSON.parse('12.3');"), 12.3)
end)

test("parse number: scientific notation 13e2", function()
  assert_eq(exec_js("return JSON.parse('13e2');"), 13e2)
end)

test("parse number: scientific notation 13E+2", function()
  assert_eq(exec_js("return JSON.parse('13E+2');"), 13e2)
end)

test("parse number: scientific notation 13e-2", function()
  assert_eq(exec_js("return JSON.parse('13e-2');"), 13e-2)
end)

-- ============================================================================
-- JSON.parse — literals (ported: rxi "literals")
-- ============================================================================

test("parse literal: true", function()
  assert_eq(exec_js("return JSON.parse('true');"), true)
end)

test("parse literal: false", function()
  assert_eq(exec_js("return JSON.parse('false');"), false)
end)

test("parse literal: null → JSON.null", function()
  assert_eq(exec_js("return JSON.parse('null') === JSON['null'];"), true)
end)

-- ============================================================================
-- JSON.stringify — literals (ported: rxi "literals")
-- ============================================================================

test("stringify true", function()
  assert_eq(exec_js("return JSON.stringify(true);"), "true")
end)

test("stringify false", function()
  assert_eq(exec_js("return JSON.stringify(false);"), "false")
end)

test("stringify null", function()
  assert_eq(exec_js("return JSON.stringify(null);"), "null")
end)

-- ============================================================================
-- JSON.parse + JSON.stringify — string round-trips (ported: rxi "strings")
-- ============================================================================

test("string round-trip: empty string", function()
  assert_eq(exec_js("return JSON.stringify(JSON.parse('\"\"'));"), '""')
end)

test("string round-trip: backslash", function()
  assert_eq(exec_js([[return JSON.stringify(JSON.parse('"\\\\"'));]]), [["\\"]])
end)

test("string round-trip: Hello world", function()
  assert_eq(exec_js([[return JSON.stringify(JSON.parse('"Hello world"'));]]), '"Hello world"')
end)

-- ============================================================================
-- JSON.parse — unicode (ported: rxi "unicode")
-- ============================================================================

test("parse unicode: Japanese", function()
  assert_eq(
    exec_js([[return JSON.parse('"\\u3053\\u3093\\u306b\\u3061\\u306f\\u4e16\\u754c"');]]),
    "こんにちは世界"
  )
end)

-- ============================================================================
-- JSON.parse — escape sequences (ported: rxi "decode escape")
-- ============================================================================

test("parse escape: unicode smiley ☺", function()
  assert_eq(exec_js([[return JSON.parse('"\\u263a"');]]), "☺")
end)

test("parse escape: surrogate pair 😂", function()
  assert_eq(exec_js([[return JSON.parse('"\\ud83d\\ude02"');]]), "😂")
end)

test('parse escape: \\r\\n\\t\\\\\\"', function()
  assert_eq(exec_js([[return JSON.parse('"\\r\\n\\t\\\\\\""');]]), '\r\n\t\\"')
end)

test("parse escape: forward slash", function()
  assert_eq(exec_js([[return JSON.parse('"\\/"');]]), "/")
end)

-- ============================================================================
-- JSON.stringify — escape sequences (ported: rxi "encode escape")
-- ============================================================================

test("stringify escape: quotes", function()
  assert_eq(exec_js([[return JSON.stringify("\"x\"");]]), [["\"x\""]])
end)

test("stringify escape: newline", function()
  assert_eq(exec_js("return JSON.stringify('x\\ny');"), [["x\ny"]])
end)

test("stringify escape: control characters", function()
  assert_eq(exec_js([[return JSON.stringify(JSON.parse('"x\\u0000y"'))]]), [["x\u0000y"]])
end)

test('stringify escape: \\r\\n\\t\\\\\\"', function()
  assert_eq(exec_js("return JSON.stringify('\\r\\n\\t\\\\\\\"');"), [["\r\n\t\\\""]])
end)

-- ============================================================================
-- JSON.parse — arrays (ported: rxi "arrays")
-- ============================================================================

test("parse array: simple", function()
  local arr = exec_js('return JSON.parse(\'["cat","dog","owl"]\');')
  assert_eq(arr[1], "cat")
  assert_eq(arr[2], "dog")
  assert_eq(arr[3], "owl")
  assert_eq(arr.length, 3)
end)

test("parse array: numbers", function()
  local arr = exec_js("return JSON.parse('[1, 2, 3, 4, 5, 6]');")
  assert_eq(arr.length, 6)
  for i = 1, 6 do
    assert_eq(arr[i], i)
  end
end)

test("parse array: mixed", function()
  local arr = exec_js([[return JSON.parse('[1, 2, 3, "hello"]');]])
  assert_eq(arr.length, 4)
  assert_eq(arr[4], "hello")
end)

-- ============================================================================
-- JSON.parse — objects (ported: rxi "objects")
-- ============================================================================

test("parse object: simple", function()
  local obj = exec_js([[return JSON.parse('{ "name": "test", "id": 231 }');]])
  assert_eq(obj.name, "test")
  assert_eq(obj.id, 231)
end)

test("parse object: nested", function()
  local obj = exec_js([[return JSON.parse('{"x":1,"y":2,"z":[1,2,3]}');]])
  assert_eq(obj.x, 1)
  assert_eq(obj.y, 2)
  assert_eq(obj.z.length, 3)
  assert_eq(obj.z[1], 1)
  assert_eq(obj.z[2], 2)
  assert_eq(obj.z[3], 3)
end)

-- ============================================================================
-- JSON.parse — empty values (ported: rxi "decode empty")
-- ============================================================================

test("parse empty array", function()
  local arr = exec_js("return JSON.parse('[]');")
  assert_eq(arr.length, 0)
end)

test("parse empty object", function()
  local obj = exec_js("return JSON.parse('{}');")
  assert_eq(next(obj), nil)
end)

test("parse empty string", function()
  assert_eq(exec_js([[return JSON.parse('""');]]), "")
end)

-- ============================================================================
-- JSON.parse — invalid input (ported: rxi "decode invalid")
-- ============================================================================

local invalid_inputs = {
  "",
  " ",
  "{",
  "[",
  '{"x" : ',
  '{"x" : 1',
  '{"x" : z }',
  '{"x" : 123z }',
  "{x : 123 }",
  "{10 : 123 }",
  "{]",
  "[}",
  '"a',
  "10 xx",
  "{}123",
}

for _, input in ipairs(invalid_inputs) do
  test("parse invalid: " .. ("%q"):format(input), function()
    local ok = pcall(exec_js, ("return JSON.parse(%q);"):format(input))
    assert(not ok, "expected parse error for: " .. input)
  end)
end

-- ============================================================================
-- JSON.parse — invalid strings (ported: rxi "decode invalid string")
-- ============================================================================

local invalid_strings = {
  [["\z"]],
  [["\1"]],
  [["\u000z"]],
  [["\ud83d\ude0q"]],
}

for _, input in ipairs(invalid_strings) do
  test("parse invalid string: " .. input, function()
    local ok = pcall(exec_js, ("return JSON.parse('%s');"):format(input))
    assert(not ok, "expected parse error for: " .. input)
  end)
end

-- ============================================================================
-- JSON.stringify — arrays (ported: rxi "arrays")
-- ============================================================================

test("stringify array", function()
  assert_eq(exec_js("return JSON.stringify([1, 2, 3]);"), "[1,2,3]")
end)

test("stringify empty array", function()
  assert_eq(exec_js("return JSON.stringify([]);"), "[]")
end)

-- ============================================================================
-- JSON.stringify — objects (ported: rxi "objects")
-- ============================================================================

test("stringify object", function()
  local result = exec_js([[return JSON.stringify({a:1, b:2});]])
  assert(result:find('"a":1'), "expected a:1 in " .. result)
  assert(result:find('"b":2'), "expected b:2 in " .. result)
end)

test("stringify empty object", function()
  assert_eq(exec_js("return JSON.stringify({});"), "{}")
end)

test("stringify nested", function()
  assert_eq(exec_js("return JSON.stringify({x:[1]});"), '{"x":[1]}')
end)

test("stringify object with numeric .length is serialized as object", function()
  local result = exec_js([[return JSON.stringify({a:1, length:2});]])
  assert(result:find('"a":1'), "expected a:1 in " .. result)
  assert(result:find('"length":2'), "expected length:2 in " .. result)
  assert(not result:find("^%["), "should not start with [ got: " .. result)
end)

-- ============================================================================
-- JSON.stringify — numbers (ported: rxi "numbers")
-- ============================================================================

test("stringify number: 123.456", function()
  assert_eq(exec_js("return JSON.stringify(123.456);"), "123.456")
end)

test("stringify number: 0", function()
  assert_eq(exec_js("return JSON.stringify(0);"), "0")
end)

-- ============================================================================
-- JSON.stringify — NaN/Infinity → null
--
-- JS spec: JSON.stringify(NaN) → "null", JSON.stringify(Infinity) → "null".
-- Unlike the raw rxi library which errors, our stringify silently returns
-- "null" to match JS behaviour.
-- ============================================================================

test("stringify NaN → null", function()
  assert_eq(exec_js("return JSON.stringify(0/0);"), "null")
end)

test("stringify Infinity → null", function()
  assert_eq(exec_js("return JSON.stringify(1/0);"), "null")
end)

test("stringify -Infinity → null", function()
  assert_eq(exec_js("return JSON.stringify(-1/0);"), "null")
end)

-- ============================================================================
-- Round-trip (ported: rxi round-trip patterns)
-- ============================================================================

test("round-trip array", function()
  assert_eq(exec_js("return JSON.stringify(JSON.parse('[10,20]'));"), "[10,20]")
end)

test("round-trip object", function()
  assert_eq(exec_js([[return JSON.stringify(JSON.parse('{"k":"v"}'));]]), '{"k":"v"}')
end)

-- ============================================================================
-- ljs-specific: JSON.parse wraps arrays with .length
--
-- The _ljs_arr marker set by our modified parse_array in json_lib.lua lets
-- _ljs_json_wrap distinguish parsed arrays from parsed objects.  After
-- wrapping, arrays get a .length property matching JS Array semantics.
-- ============================================================================

test("parse array gets .length", function()
  local arr = exec_js("return JSON.parse('[10, 20, 30]');")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 10)
  assert_eq(arr[3], 30)
end)

test("parse empty array gets .length = 0", function()
  local arr = exec_js("return JSON.parse('[]');")
  assert_eq(arr.length, 0)
end)

test("parse nested arrays get .length", function()
  local obj = exec_js("return JSON.parse('{\"a\":[[1]]}');")
  assert_eq(obj.a.length, 1)
  assert_eq(obj.a[1].length, 1)
  assert_eq(obj.a[1][1], 1)
end)

test("parse array has Array.prototype methods", function()
  local arr = exec_js([[var a = JSON.parse('[1,2]'); a.push(3); return a;]])
  assert_eq(arr.length, 3)
  assert_eq(arr[3], 3)
end)

-- ============================================================================
-- ljs-specific: JSON.parse wraps objects as _ljs_object instances
--
-- Parsed objects are wrapped with _ljs_object so they support JS-style
-- property access (including prototype methods like hasOwnProperty).
-- ============================================================================

test("parse object is _ljs_object (has prototype methods)", function()
  assert_eq(exec_js([[return JSON.parse('{"a":1}').hasOwnProperty('a');]]), true)
  assert_eq(exec_js([[return JSON.parse('{"a":1}').hasOwnProperty('b');]]), false)
end)

test("parse nested object values are wrapped", function()
  assert_eq(exec_js([[return JSON.parse('{"inner":{"x":42}}').inner.hasOwnProperty('x');]]), true)
  assert_eq(exec_js([[return JSON.parse('{"inner":{"x":42}}').inner.x;]]), 42)
end)

-- ============================================================================
-- ljs-specific: JSON.stringify with JS arrays
--
-- JS arrays created via literals have .length.  Our stringify detects
-- arrays by checking for a numeric .length property and serialises
-- elements 1..length.
-- ============================================================================

test("stringify JS array literal", function()
  assert_eq(exec_js("return JSON.stringify([10, 20, 30]);"), "[10,20,30]")
end)

test("stringify JS array with null element → null", function()
  assert_eq(exec_js("return JSON.stringify([null]);"), "[null]")
end)

-- ============================================================================
-- ljs-specific: JSON.stringify with null values
--
-- JSON null is represented as JSON.null (a sentinel value) so that null-valued
-- object keys are preserved in Lua tables.  This fixes round-trip fidelity:
-- JSON.stringify(JSON.parse('{"a":null}')) → '{"a":null}'.
--
-- Note: undefined values (Lua nil) are still skipped, which matches JS:
-- JSON.stringify({a: undefined}) → "{}".
-- ============================================================================

test("stringify skips nil/undefined values in objects", function()
  assert_eq(exec_js("return JSON.stringify({a: undefined});"), "{}")
end)

test("parse object with null value preserves key", function()
  assert_eq(exec_js([[return JSON.parse('{"a":null}').hasOwnProperty('a');]]), true)
end)

test("parse object with null value round-trips", function()
  assert_eq(exec_js([[return JSON.stringify(JSON.parse('{"a":null}'));]]), '{"a":null}')
end)

test("parse array with null element round-trips", function()
  assert_eq(exec_js("return JSON.stringify(JSON.parse('[1,null,3]'));"), "[1,null,3]")
end)

test("parse nested object with null round-trips", function()
  assert_eq(
    exec_js([[return JSON.stringify(JSON.parse('{"a":{"b":null},"c":null}'));]]),
    '{"a":{"b":null},"c":null}'
  )
end)

test("JSON.null round-trips through stringify", function()
  assert_eq(exec_js("return JSON.stringify(JSON['null']);"), "null")
end)

-- ============================================================================
-- ljs-specific: JSON.stringify ignores functions
--
-- JS spec: JSON.stringify(function(){}) → undefined.  In ljs, functions
-- are tables with __call metamethods.  Our stringify detects them and
-- returns nil, which means they're omitted from object properties.
-- ============================================================================

test("stringify skips function values in objects", function()
  assert_eq(exec_js("return JSON.stringify({a: function(){}});"), "{}")
end)

-- ============================================================================
-- Code generation checks
-- ============================================================================

test("JSON.parse emits _ljs_call_member", function()
  local code = transpile_js("JSON.parse('1');")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member in output")
end)

test("JSON.stringify emits _ljs_call_member", function()
  local code = transpile_js("JSON.stringify(1);")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member in output")
end)
