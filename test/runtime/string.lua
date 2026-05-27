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

test("String.fromCharCode single char", function()
  assert_js('String.fromCharCode(65)', "A")
end)

test("String.fromCharCode multiple chars", function()
  assert_js('String.fromCharCode(72, 101, 108, 108, 111)', "Hello")
end)

test("String.fromCharCode no args returns empty string", function()
  assert_js('String.fromCharCode()', "")
end)

test("string charCodeAt NaN returns first char", function()
  assert_js('"hello".charCodeAt(NaN)', 104)
end)

test("string charCodeAt negative fraction truncates toward zero", function()
  assert_js('"hello".charCodeAt(-0.5)', 104)
end)

test("string charCodeAt positive fraction truncates toward zero", function()
  assert_js('"hello".charCodeAt(0.9)', 104)
end)

test("String.fromCharCode NaN returns null char", function()
  assert_js('String.fromCharCode(NaN)', "\0")
end)

test("String.fromCharCode negative fraction truncates toward zero", function()
  assert_js('String.fromCharCode(-0.5)', "\0")
end)

test("String.fromCharCode(128) produces UTF-8 two-byte encoding", function()
  assert_js('String.fromCharCode(128)', "\xc2\x80")
end)

test("String.fromCharCode(256) produces correct UTF-8", function()
  assert_js('String.fromCharCode(256)', "\xc4\x80")
end)

test("String.fromCharCode(0x4E16) produces three-byte UTF-8", function()
  assert_js('String.fromCharCode(0x4E16)', "\xe4\xb8\x96")
end)

test("String.fromCharCode(65535) produces correct UTF-8", function()
  assert_js('String.fromCharCode(65535)', "\xef\xbf\xbf")
end)

test("String.fromCharCode(-1) wraps via modulo 65536", function()
  assert_js('String.fromCharCode(-1)', "\xef\xbf\xbf")
end)

test("String.fromCharCode(65536) wraps to 0", function()
  assert_js('String.fromCharCode(65536)', "\0")
end)

test("String.fromCharCode(Infinity) returns null char", function()
  assert_js('String.fromCharCode(Infinity)', "\0")
end)

test("String.fromCharCode(-Infinity) returns null char", function()
  assert_js('String.fromCharCode(-Infinity)', "\0")
end)
