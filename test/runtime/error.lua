local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_js = R.test, R.assert_eq, R.assert_js
local eval_js, exec_js = R.eval_js, R.exec_js

-- ============================================================================
-- Error constructor
-- ============================================================================

test("new Error sets message", function()
  local err = eval_js('new Error("boom")')
  assert_eq(err.message, "boom")
end)

test("new Error sets name", function()
  local err = eval_js('new Error("boom")')
  assert_eq(err.name, "Error")
end)

test("new Error without message", function()
  local err = eval_js("new Error()")
  assert_eq(err.message, nil)
  assert_eq(err.name, "Error")
end)

-- ============================================================================
-- Error.prototype.toString
-- ============================================================================

test("Error toString with message", function()
  assert_js('new Error("boom").toString()', "Error: boom")
end)

test("Error toString without message", function()
  assert_js("new Error().toString()", "Error")
end)

-- ============================================================================
-- TypeError
-- ============================================================================

test("new TypeError sets message and name", function()
  local err = eval_js('new TypeError("bad type")')
  assert_eq(err.message, "bad type")
  assert_eq(err.name, "TypeError")
end)

test("TypeError toString", function()
  assert_js('new TypeError("bad type").toString()', "TypeError: bad type")
end)

-- ============================================================================
-- RangeError
-- ============================================================================

test("new RangeError sets message and name", function()
  local err = eval_js('new RangeError("out of range")')
  assert_eq(err.message, "out of range")
  assert_eq(err.name, "RangeError")
end)

test("RangeError toString", function()
  assert_js('new RangeError("out of range").toString()', "RangeError: out of range")
end)

-- ============================================================================
-- SyntaxError
-- ============================================================================

test("new SyntaxError sets message and name", function()
  local err = eval_js('new SyntaxError("bad syntax")')
  assert_eq(err.message, "bad syntax")
  assert_eq(err.name, "SyntaxError")
end)

test("SyntaxError toString", function()
  assert_js('new SyntaxError("bad syntax").toString()', "SyntaxError: bad syntax")
end)

-- ============================================================================
-- ReferenceError
-- ============================================================================

test("new ReferenceError sets message and name", function()
  local err = eval_js('new ReferenceError("not defined")')
  assert_eq(err.message, "not defined")
  assert_eq(err.name, "ReferenceError")
end)

test("ReferenceError toString", function()
  assert_js('new ReferenceError("not defined").toString()', "ReferenceError: not defined")
end)

-- ============================================================================
-- instanceof
-- ============================================================================

test("TypeError instanceof TypeError", function()
  assert_js("new TypeError('x') instanceof TypeError", true)
end)

test("TypeError instanceof Error", function()
  assert_js("new TypeError('x') instanceof Error", true)
end)

test("Error not instanceof TypeError", function()
  assert_js("new Error('x') instanceof TypeError", false)
end)

test("RangeError instanceof Error", function()
  assert_js("new RangeError('x') instanceof Error", true)
end)

test("SyntaxError instanceof Error", function()
  assert_js("new SyntaxError('x') instanceof Error", true)
end)

test("ReferenceError instanceof Error", function()
  assert_js("new ReferenceError('x') instanceof Error", true)
end)
