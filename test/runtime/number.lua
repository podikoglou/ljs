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
