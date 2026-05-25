local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local R = require("test.helpers.runtime")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js = H.transpile_ok, H.expr_code, H.run_js
local eval_js = R.eval_js

local function assert_nan(val, msg)
  assert(val ~= val, (msg or "") .. " expected NaN, got " .. tostring(val))
end

local function assert_minus_zero(val, msg)
  msg = msg or ""
  assert(val == 0, msg .. " expected ±0, got " .. tostring(val))
  assert(1 / val < 0, msg .. " expected -0, got +0")
end

-- ============================================================================
-- Unit tests — code generation (% operator)
-- ============================================================================

test("% emits _ljs_mod call", function()
  local code = expr_code("a % b")
  assert_eq(code, "_ljs_mod(a, b)")
end)

test("%= emits _ljs_mod assignment", function()
  local code = expr_code("a %= b")
  assert_eq(code, "a = _ljs_mod(a, b)")
end)

test("_ljs_mod helper in preamble when % used", function()
  local code = transpile_ok("let x = a % b;")
  assert(code:find("local function _ljs_mod"), "expected _ljs_mod helper in output")
end)

test("transpile.HELPERS._ljs_mod accessible", function()
  assert(type(H.transpile.HELPERS._ljs_mod) == "string", "expected _ljs_mod helper string")
end)

-- ============================================================================
-- Integration tests — JS modulo semantics (ECMA-262 §6.1.6.1.6)
-- ============================================================================

-- Positive operands — both Lua and JS agree
test("7 % 3 = 1", function()
  assert_eq(eval_js("7 % 3"), 1)
end)

test("10 % 4 = 2", function()
  assert_eq(eval_js("10 % 4"), 2)
end)

-- Negative dividend — JS sign follows dividend (truncated division)
test("-7 % 3 = -1", function()
  assert_eq(eval_js("-7 % 3"), -1)
end)

test("-10 % 3 = -1", function()
  assert_eq(eval_js("-10 % 3"), -1)
end)

-- Negative divisor — JS sign follows dividend
test("7 % -3 = 1", function()
  assert_eq(eval_js("7 % -3"), 1)
end)

test("10 % -3 = 1", function()
  assert_eq(eval_js("10 % -3"), 1)
end)

-- Both negative
test("-7 % -3 = -1", function()
  assert_eq(eval_js("-7 % -3"), -1)
end)

test("-10 % -3 = -1", function()
  assert_eq(eval_js("-10 % -3"), -1)
end)

-- Float operands
test("5.5 % 2.5 = 0.5", function()
  assert_eq(eval_js("5.5 % 2.5"), 0.5)
end)

test("-5.5 % 2.5 = -0.5", function()
  assert_eq(eval_js("-5.5 % 2.5"), -0.5)
end)

test("5.5 % -2.5 = 0.5", function()
  assert_eq(eval_js("5.5 % -2.5"), 0.5)
end)

-- Division by zero → NaN (Lua would crash)
test("1 % 0 = NaN", function()
  assert_nan(eval_js("1 % 0"))
end)

test("0 % 0 = NaN", function()
  assert_nan(eval_js("0 % 0"))
end)

test("-1 % 0 = NaN", function()
  assert_nan(eval_js("-1 % 0"))
end)

-- NaN input → NaN
test("NaN % 1 = NaN", function()
  assert_nan(eval_js("(0/0) % 1"))
end)

test("1 % NaN = NaN", function()
  assert_nan(eval_js("1 % (0/0)"))
end)

-- Infinity dividend → NaN
test("Infinity % 1 = NaN", function()
  assert_nan(eval_js("(1/0) % 1"))
end)

test("-Infinity % 1 = NaN", function()
  assert_nan(eval_js("(-1/0) % 1"))
end)

-- Infinity divisor → dividend
test("1 % Infinity = 1", function()
  assert_eq(eval_js("1 % (1/0)"), 1)
end)

test("5 % Infinity = 5", function()
  assert_eq(eval_js("5 % (1/0)"), 5)
end)

test("-5 % Infinity = -5", function()
  assert_eq(eval_js("-5 % (1/0)"), -5)
end)

test("1 % -Infinity = 1", function()
  assert_eq(eval_js("1 % (-1/0)"), 1)
end)

test("-5 % -Infinity = -5", function()
  assert_eq(eval_js("-5 % (-1/0)"), -5)
end)

-- Infinity % Infinity → NaN
test("Infinity % Infinity = NaN", function()
  assert_nan(eval_js("(1/0) % (1/0)"))
end)

-- -0 dividend → -0
test("-0 % 5 = -0", function()
  assert_minus_zero(eval_js("(-0) % 5"))
end)

test("-0 % -5 = -0", function()
  assert_minus_zero(eval_js("(-0) % (-5)"))
end)

-- +0 dividend → +0
test("0 % 5 = 0", function()
  local r = eval_js("0 % 5")
  assert_eq(r, 0)
  assert(1 / r > 0, "expected +0")
end)

-- -0 % 0 → NaN (divisor is 0)
test("-0 % 0 = NaN", function()
  assert_nan(eval_js("(-0) % 0"))
end)

-- %= compound assignment
test("x %= 3 uses _ljs_mod", function()
  local code = expr_code("x %= 3")
  assert_eq(code, "x = _ljs_mod(x, 3)")
end)

test("%= compound assignment runtime", function()
  local output = run_js("let x = -7; x %= 3; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

-- Full end-to-end
test("% in expression context", function()
  local output = run_js("console.log(-7 % 3);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("% in variable assignment", function()
  local output = run_js("let r = 7 % -3; console.log(r);")
  assert_eq(output:gsub("%s+", ""), "1")
end)
