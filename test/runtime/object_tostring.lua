local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local exec_js = R.exec_js

test("Object.prototype.toString on plain object", function()
  assert_eq(exec_js("return ({}).toString();"), "[object Object]")
end)

test("Object.prototype.toString on object with properties", function()
  assert_eq(exec_js("return ({a: 1}).toString();"), "[object Object]")
end)

test("Object.prototype.toString on array", function()
  assert_eq(exec_js("return [1, 2, 3].toString();"), "[object Array]")
end)

test("Object.prototype.toString on empty array", function()
  assert_eq(exec_js("return [].toString();"), "[object Array]")
end)

test("Object.prototype.toString on function", function()
  assert_eq(exec_js("return (function() {}).toString();"), "[object Function]")
end)

test("Object.prototype.toString on arrow function", function()
  assert_eq(exec_js("return (() => {}).toString();"), "[object Function]")
end)

test("Object.prototype.toString on error", function()
  assert_eq(exec_js("return new Error('test').toString();"), "[object Error]")
end)

test("Object.prototype.toString on TypeError", function()
  assert_eq(exec_js("return new TypeError('test').toString();"), "[object Error]")
end)

test("Object.prototype.toString on number primitive", function()
  assert_eq(exec_js("return (42).toString();"), "[object Number]")
end)

test("Object.prototype.toString on string primitive", function()
  assert_eq(exec_js("return 'hello'.toString();"), "[object String]")
end)

test("Object.prototype.toString on boolean primitive", function()
  assert_eq(exec_js("return true.toString();"), "[object Boolean]")
end)

test("Object.prototype.toString on null", function()
  assert_eq(exec_js("return Object.prototype.toString.call(null);"), "[object Null]")
end)

test("Object.prototype.toString on undefined", function()
  assert_eq(exec_js("return Object.prototype.toString.call(undefined);"), "[object Undefined]")
end)

test("Object.prototype.toString via call on array", function()
  assert_eq(exec_js("return Object.prototype.toString.call([1]);"), "[object Array]")
end)

test("Object.prototype.toString via call on function", function()
  assert_eq(exec_js("return Object.prototype.toString.call(function() {});"), "[object Function]")
end)

test("Object.prototype.toString via call on number", function()
  assert_eq(exec_js("return Object.prototype.toString.call(42);"), "[object Number]")
end)

test("Object.prototype.toString via call on string", function()
  assert_eq(exec_js("return Object.prototype.toString.call('hi');"), "[object String]")
end)

test("Object.prototype.toString via call on boolean", function()
  assert_eq(exec_js("return Object.prototype.toString.call(true);"), "[object Boolean]")
end)

test("Object.prototype.toString via call on error", function()
  assert_eq(exec_js("return Object.prototype.toString.call(new Error());"), "[object Error]")
end)

test("Array.prototype.toString uses join when join is null", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = null; return arr.toString();"), "[object Array]")
end)

test("Array.prototype.toString uses join when join is a number", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = 42; return arr.toString();"), "[object Array]")
end)

test("Array.prototype.toString uses join when join is a string", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = 'hello'; return arr.toString();"), "[object Array]")
end)
