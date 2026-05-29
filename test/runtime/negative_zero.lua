local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

local function assert_minus_zero(val, msg)
  msg = msg or ""
  assert(val == 0, msg .. " expected ±0, got " .. tostring(val))
  assert(1 / val < 0, msg .. " expected -0, got +0")
end

local function assert_plus_zero(val, msg)
  msg = msg or ""
  assert(val == 0, msg .. " expected ±0, got " .. tostring(val))
  assert(1 / val > 0, msg .. " expected +0, got -0")
end

test("multiply: 0 * -1 produces -0", function()
  assert_minus_zero(eval_js("0 * -1"), "0 * -1")
end)

test("multiply: -1 * 0 produces -0", function()
  assert_minus_zero(eval_js("-1 * 0"), "-1 * 0")
end)

test("multiply: -0 * 1 produces -0", function()
  assert_minus_zero(eval_js("(-0) * 1"), "(-0) * 1")
end)

test("multiply: 0 * 0 produces +0", function()
  assert_plus_zero(eval_js("0 * 0"), "0 * 0")
end)

test("multiply: 2 * 3 = 6 (regression)", function()
  assert_eq(eval_js("2 * 3"), 6)
end)

test("subtract: -0 - 0 produces -0", function()
  assert_minus_zero(eval_js("(-0) - 0"), "(-0) - 0")
end)

test("subtract: 0 - 0 produces +0", function()
  assert_plus_zero(eval_js("0 - 0"), "0 - 0")
end)

test("subtract: 5 - 3 = 2 (regression)", function()
  assert_eq(eval_js("5 - 3"), 2)
end)

test("add: -0 + -0 produces -0", function()
  assert_minus_zero(eval_js("(-0) + (-0)"), "(-0) + (-0)")
end)

test("add: 0 + 0 produces +0", function()
  assert_plus_zero(eval_js("0 + 0"), "0 + 0")
end)

test("add: 2 + 3 = 5 (regression)", function()
  assert_eq(eval_js("2 + 3"), 5)
end)
