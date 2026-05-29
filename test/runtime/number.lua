local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

test("Number.prototype.toLocaleString: has own property toLocaleString", function()
  assert_eq(eval_js("Number.prototype.hasOwnProperty('toLocaleString')"), true)
end)

test("Number.prototype.toLocaleString: (42).toLocaleString() returns '42'", function()
  assert_eq(exec_js("return (42).toLocaleString();"), "42")
end)

test("Number.prototype.toLocaleString: new Number(3.14).toLocaleString() returns '3.14'", function()
  assert_eq(exec_js("return new Number(3.14).toLocaleString();"), "3.14")
end)

test("Number.prototype.toLocaleString: NaN/Infinity", function()
  assert_eq(exec_js("return NaN.toLocaleString();"), "NaN")
  assert_eq(exec_js("return Infinity.toLocaleString();"), "Infinity")
  assert_eq(exec_js("return (-Infinity).toLocaleString();"), "-Infinity")
end)

test("Number.prototype.toLocaleString: negative and zero", function()
  assert_eq(exec_js("return (-42).toLocaleString();"), "-42")
  assert_eq(exec_js("return (0).toLocaleString();"), "0")
end)

test("Number.prototype.toExponential: auto precision", function()
  assert_eq(exec_js("return (42).toExponential();"), "4.2e+1")
  assert_eq(exec_js("return (0).toExponential();"), "0e+0")
  assert_eq(exec_js("return (100).toExponential();"), "1e+2")
  assert_eq(exec_js("return (0.0000001).toExponential();"), "1e-7")
  assert_eq(exec_js("return (0.1 + 0.2).toExponential();"), "3.0000000000000004e-1")
end)

test("Number.prototype.toExponential: with fractionDigits", function()
  assert_eq(exec_js("return (42).toExponential(2);"), "4.20e+1")
  assert_eq(exec_js("return (42).toExponential(0);"), "4e+1")
  assert_eq(exec_js("return (0).toExponential(2);"), "0.00e+0")
  assert_eq(exec_js("return (0.00123).toExponential(2);"), "1.23e-3")
  assert_eq(exec_js("return (123456).toExponential(2);"), "1.23e+5")
  assert_eq(exec_js("return (1).toExponential(0);"), "1e+0")
  assert_eq(exec_js("return (1).toExponential(100);"), "1." .. string.rep("0", 100) .. "e+0")
end)

test("Number.prototype.toExponential: NaN, Infinity, negatives", function()
  assert_eq(exec_js("return NaN.toExponential();"), "NaN")
  assert_eq(exec_js("return Infinity.toExponential();"), "Infinity")
  assert_eq(exec_js("return (-Infinity).toExponential();"), "-Infinity")
  assert_eq(exec_js("return (-42).toExponential(2);"), "-4.20e+1")
  assert_eq(exec_js("return (-0).toExponential();"), "0e+0")
  assert_eq(exec_js("return (-0).toExponential(3);"), "0.000e+0")
end)

test("Number.prototype.toExponential: RangeError", function()
  local _, err = pcall(exec_js, "return (42).toExponential(-1);")
  assert_eq(err:match("RangeError") ~= nil, true)
  local _, err2 = pcall(exec_js, "return (42).toExponential(101);")
  assert_eq(err2:match("RangeError") ~= nil, true)
end)

test("Number.prototype.toExponential: argument coercion", function()
  assert_eq(exec_js("return (42).toExponential(undefined);"), "4.2e+1")
  assert_eq(exec_js("return (42).toExponential(NaN);"), "4e+1")
  assert_eq(exec_js("return (42).toExponential(0.7);"), "4e+1")
  assert_eq(exec_js("return (42).toExponential(true);"), "4.2e+1")
  assert_eq(exec_js("return (42).toExponential(false);"), "4e+1")
  local _, err = pcall(exec_js, "return Number.prototype.toExponential.call({});")
  assert_eq(err:match("TypeError") ~= nil, true)
end)

test("Number.prototype.toPrecision: fixed form", function()
  assert_eq(exec_js("return (42).toPrecision(3);"), "42.0")
  assert_eq(exec_js("return (42).toPrecision(5);"), "42.000")
  assert_eq(exec_js("return (0).toPrecision(1);"), "0")
  assert_eq(exec_js("return (0).toPrecision(5);"), "0.0000")
  assert_eq(exec_js("return (-42).toPrecision(3);"), "-42.0")
  assert_eq(exec_js("return (1234.5).toPrecision(7);"), "1234.500")
  assert_eq(exec_js("return (100).toPrecision(3);"), "100")
  assert_eq(exec_js("return (0.001).toPrecision(3);"), "0.00100")
end)

test("Number.prototype.toPrecision: exponential form", function()
  assert_eq(exec_js("return (42).toPrecision(1);"), "4e+1")
  assert_eq(exec_js("return (100).toPrecision(1);"), "1e+2")
  assert_eq(exec_js("return (10).toPrecision(1);"), "1e+1")
  assert_eq(exec_js("return (0.0000001).toPrecision(3);"), "1.00e-7")
  assert_eq(exec_js("return (0.0000001).toPrecision(1);"), "1e-7")
  assert_eq(exec_js("return (0.000001).toPrecision(3);"), "0.00000100")
  assert_eq(exec_js("return (0.000001).toPrecision(1);"), "0.000001")
  assert_eq(exec_js("return (0.0000005).toPrecision(1);"), "5e-7")
end)

test("Number.prototype.toPrecision: undefined precision returns ToString", function()
  assert_eq(exec_js("return (42).toPrecision();"), "42")
  assert_eq(exec_js("return (42).toPrecision(undefined);"), "42")
  assert_eq(exec_js("return (42).toPrecision(true);"), "4e+1")
  assert_eq(exec_js("return NaN.toPrecision(1);"), "NaN")
  assert_eq(exec_js("return Infinity.toPrecision(1);"), "Infinity")
  assert_eq(exec_js("return (-Infinity).toPrecision(1);"), "-Infinity")
  assert_eq(exec_js("return (-0).toPrecision(1);"), "0")
  assert_eq(exec_js("return (-0).toPrecision(3);"), "0.00")
end)

test("Number.prototype.toPrecision: RangeError and TypeError", function()
  local _, err = pcall(exec_js, "return (42).toPrecision(0);")
  assert_eq(err:match("RangeError") ~= nil, true)
  local _, err2 = pcall(exec_js, "return (42).toPrecision(101);")
  assert_eq(err2:match("RangeError") ~= nil, true)
  local _, err3 = pcall(exec_js, "return (42).toPrecision(-1);")
  assert_eq(err3:match("RangeError") ~= nil, true)
  local _, err4 = pcall(exec_js, "return Number.prototype.toPrecision.call({});")
  assert_eq(err4:match("TypeError") ~= nil, true)
end)

-- ============================================================================
-- Number.isNaN (ECMA-262 §21.1.2.4)
-- ============================================================================

test("Number.isNaN(NaN) is true", function()
  assert_eq(eval_js("Number.isNaN(NaN)"), true)
end)

test("Number.isNaN(0/0) is true", function()
  assert_eq(eval_js("Number.isNaN(0/0)"), true)
end)

test("Number.isNaN(42) is false", function()
  assert_eq(eval_js("Number.isNaN(42)"), false)
end)

test("Number.isNaN(Infinity) is false", function()
  assert_eq(eval_js("Number.isNaN(Infinity)"), false)
end)

test("Number.isNaN(-Infinity) is false", function()
  assert_eq(eval_js("Number.isNaN(-Infinity)"), false)
end)

test("Number.isNaN('NaN') is false (no coercion)", function()
  assert_eq(eval_js("Number.isNaN('NaN')"), false)
end)

test("Number.isNaN(undefined) is false (no coercion)", function()
  assert_eq(eval_js("Number.isNaN(undefined)"), false)
end)

test("Number.isNaN('hello') is false (no coercion)", function()
  assert_eq(eval_js("Number.isNaN('hello')"), false)
end)

test("Number.isNaN(true) is false (no coercion)", function()
  assert_eq(eval_js("Number.isNaN(true)"), false)
end)

test("Number.isNaN(null) is false (no coercion)", function()
  assert_eq(eval_js("Number.isNaN(null)"), false)
end)

-- ============================================================================
-- Number.isFinite (ECMA-262 §21.1.2.2)
-- ============================================================================

test("Number.isFinite(42) is true", function()
  assert_eq(eval_js("Number.isFinite(42)"), true)
end)

test("Number.isFinite(0) is true", function()
  assert_eq(eval_js("Number.isFinite(0)"), true)
end)

test("Number.isFinite(Infinity) is false", function()
  assert_eq(eval_js("Number.isFinite(Infinity)"), false)
end)

test("Number.isFinite(-Infinity) is false", function()
  assert_eq(eval_js("Number.isFinite(-Infinity)"), false)
end)

test("Number.isFinite(NaN) is false", function()
  assert_eq(eval_js("Number.isFinite(NaN)"), false)
end)

test("Number.isFinite('42') is false (no coercion)", function()
  assert_eq(eval_js("Number.isFinite('42')"), false)
end)

test("Number.isFinite(null) is false (no coercion)", function()
  assert_eq(eval_js("Number.isFinite(null)"), false)
end)

test("Number.isFinite(undefined) is false (no coercion)", function()
  assert_eq(eval_js("Number.isFinite(undefined)"), false)
end)

-- ============================================================================
-- Number.parseInt (ECMA-262 §21.1.2.13)
-- ============================================================================

test("Number.parseInt('42') is 42", function()
  assert_eq(eval_js("Number.parseInt('42')"), 42)
end)

test("Number.parseInt('FF', 16) is 255", function()
  assert_eq(eval_js("Number.parseInt('FF', 16)"), 255)
end)

test("typeof Number.parseInt is 'function'", function()
  assert_eq(eval_js("typeof Number.parseInt"), "function")
end)
