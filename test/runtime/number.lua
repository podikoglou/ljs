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
