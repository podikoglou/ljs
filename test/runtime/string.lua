local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_js = R.test, R.assert_eq, R.assert_js
local eval_js, exec_js = R.eval_js, R.exec_js

test("string .length returns correct length", function()
  assert_js('"hello".length', 5)
end)

test("empty string .length is 0", function()
  assert_js('"".length', 0)
end)

test("string bracket indexing returns character", function()
  assert_js('"hello"[0]', "h")
end)

test("string bracket indexing last character", function()
  assert_js('"hello"[4]', "o")
end)

test("string bracket indexing OOB returns nil", function()
  assert_eq(exec_js('return "hello"[5];'), nil)
end)

test("string bracket indexing negative returns nil", function()
  assert_eq(exec_js('return "hello"[-1];'), nil)
end)

test("string toString still works", function()
  assert_js('"hello".toString()', "hello")
end)

test("string valueOf still works", function()
  assert_js('"hello".valueOf()', "hello")
end)

test("string length via variable", function()
  assert_eq(exec_js('var s = "hello"; return s.length;'), 5)
end)

test("string bracket access via variable", function()
  assert_eq(exec_js('var s = "hello"; return s[0];'), "h")
end)

test("string .length via bracket notation", function()
  assert_js('"hello"["length"]', 5)
end)

test("string charCodeAt returns code at index", function()
  assert_js('"A".charCodeAt(0)', 65)
end)

test("string charCodeAt mid-string", function()
  assert_js('"ABC".charCodeAt(2)', 67)
end)

test("string charCodeAt last char", function()
  assert_js('"hello".charCodeAt(4)', 111)
end)

test("string charCodeAt out of range returns NaN", function()
  local result = exec_js('return "hello".charCodeAt(10);')
  assert_eq(result ~= result, true)
end)

test("string charCodeAt negative index returns NaN", function()
  local result = exec_js('return "hello".charCodeAt(-1);')
  assert_eq(result ~= result, true)
end)
