local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_table_eq = R.test, R.assert_eq, T.assert_table_eq
local eval_js, exec_js, transpile_js = R.eval_js, R.exec_js, R.transpile_js

-- ============================================================================
-- typeof and identity
-- ============================================================================

test("typeof Math is 'object'", function()
  assert_eq(eval_js("typeof Math"), "object")
end)

test("Math is not a constructor", function()
  local ok, _ = pcall(exec_js, "Math();")
  assert(not ok, "Math() should throw")
end)

-- ============================================================================
-- Constants
-- ============================================================================

test("Math.PI", function()
  assert_eq(eval_js("Math.PI"), math.pi)
end)

test("Math.E", function()
  assert_eq(eval_js("Math.E"), 2.718281828459045)
end)

test("Math.LN2", function()
  assert_eq(eval_js("Math.LN2"), 0.6931471805599453)
end)

test("Math.LN10", function()
  assert_eq(eval_js("Math.LN10"), 2.302585092994046)
end)

test("Math.SQRT2", function()
  assert_eq(eval_js("Math.SQRT2"), 1.4142135623730951)
end)

-- ============================================================================
-- Math.abs
-- ============================================================================

test("abs: positive", function()
  assert_eq(eval_js("Math.abs(5)"), 5)
end)

test("abs: negative", function()
  assert_eq(eval_js("Math.abs(-5)"), 5)
end)

test("abs: zero", function()
  assert_eq(eval_js("Math.abs(0)"), 0)
end)

test("abs: NaN", function()
  local r = eval_js("Math.abs(0/0)")
  assert(r ~= r, "expected NaN")
end)

test("abs: Infinity", function()
  assert_eq(eval_js("Math.abs(1/0)"), math.huge)
end)

-- ============================================================================
-- Math.floor
-- ============================================================================

test("floor: positive", function()
  assert_eq(eval_js("Math.floor(3.7)"), 3)
end)

test("floor: negative", function()
  assert_eq(eval_js("Math.floor(-3.7)"), -4)
end)

test("floor: zero", function()
  assert_eq(eval_js("Math.floor(0)"), 0)
end)

test("floor: NaN", function()
  local r = eval_js("Math.floor(0/0)")
  assert(r ~= r, "expected NaN")
end)

test("floor: Infinity", function()
  assert_eq(eval_js("Math.floor(1/0)"), math.huge)
end)

-- ============================================================================
-- Math.ceil
-- ============================================================================

test("ceil: positive", function()
  assert_eq(eval_js("Math.ceil(3.2)"), 4)
end)

test("ceil: negative", function()
  assert_eq(eval_js("Math.ceil(-3.2)"), -3)
end)

test("ceil: zero", function()
  assert_eq(eval_js("Math.ceil(0)"), 0)
end)

test("ceil: NaN", function()
  local r = eval_js("Math.ceil(0/0)")
  assert(r ~= r, "expected NaN")
end)

test("ceil: Infinity", function()
  assert_eq(eval_js("Math.ceil(1/0)"), math.huge)
end)

-- ============================================================================
-- Math.round
-- ============================================================================

test("round: positive .5 up", function()
  assert_eq(eval_js("Math.round(2.5)"), 3)
end)

test("round: positive .4 down", function()
  assert_eq(eval_js("Math.round(2.4)"), 2)
end)

test("round: negative .5 toward +Inf", function()
  assert_eq(eval_js("Math.round(-2.5)"), -2)
end)

test("round: negative .4", function()
  assert_eq(eval_js("Math.round(-2.4)"), -2)
end)

test("round: 0.5", function()
  assert_eq(eval_js("Math.round(0.5)"), 1)
end)

test("round: -0.5", function()
  assert_eq(eval_js("Math.round(-0.5)"), 0)
end)

test("round: NaN", function()
  local r = eval_js("Math.round(0/0)")
  assert(r ~= r, "expected NaN")
end)

test("round: Infinity", function()
  assert_eq(eval_js("Math.round(1/0)"), math.huge)
end)

-- ============================================================================
-- Math.trunc
-- ============================================================================

test("trunc: positive", function()
  assert_eq(eval_js("Math.trunc(3.7)"), 3)
end)

test("trunc: negative", function()
  assert_eq(eval_js("Math.trunc(-3.7)"), -3)
end)

test("trunc: zero", function()
  assert_eq(eval_js("Math.trunc(0)"), 0)
end)

test("trunc: NaN", function()
  local r = eval_js("Math.trunc(0/0)")
  assert(r ~= r, "expected NaN")
end)

test("trunc: Infinity", function()
  assert_eq(eval_js("Math.trunc(1/0)"), math.huge)
end)

-- ============================================================================
-- Math.sign
-- ============================================================================

test("sign: positive", function()
  assert_eq(eval_js("Math.sign(5)"), 1)
end)

test("sign: negative", function()
  assert_eq(eval_js("Math.sign(-5)"), -1)
end)

test("sign: zero", function()
  local r = eval_js("Math.sign(0)")
  assert_eq(r, 0)
end)

test("sign: NaN", function()
  local r = eval_js("Math.sign(0/0)")
  assert(r ~= r, "expected NaN")
end)

test("sign: Infinity", function()
  assert_eq(eval_js("Math.sign(1/0)"), 1)
end)

-- ============================================================================
-- Math.min
-- ============================================================================

test("min: two numbers", function()
  assert_eq(eval_js("Math.min(3, 7)"), 3)
end)

test("min: negative and positive", function()
  assert_eq(eval_js("Math.min(-5, 5)"), -5)
end)

test("min: three numbers", function()
  assert_eq(eval_js("Math.min(3, 7, 1)"), 1)
end)

test("min: no args → +Infinity", function()
  assert_eq(eval_js("Math.min()"), math.huge)
end)

-- ============================================================================
-- Math.max
-- ============================================================================

test("max: two numbers", function()
  assert_eq(eval_js("Math.max(3, 7)"), 7)
end)

test("max: negative and positive", function()
  assert_eq(eval_js("Math.max(-5, 5)"), 5)
end)

test("max: three numbers", function()
  assert_eq(eval_js("Math.max(3, 7, 1)"), 7)
end)

test("max: no args → -Infinity", function()
  assert_eq(eval_js("Math.max()"), -math.huge)
end)

-- ============================================================================
-- Math.random
-- ============================================================================

test("random returns number in [0, 1)", function()
  local r = eval_js("Math.random()")
  assert(type(r) == "number", "expected number")
  assert(r >= 0, "expected >= 0")
  assert(r < 1, "expected < 1")
end)

-- ============================================================================
-- Math.pow
-- ============================================================================

test("pow: 2^3", function()
  assert_eq(eval_js("Math.pow(2, 3)"), 8)
end)

test("pow: negative exponent", function()
  assert_eq(eval_js("Math.pow(2, -1)"), 0.5)
end)

test("pow: 0^0", function()
  assert_eq(eval_js("Math.pow(0, 0)"), 1)
end)

-- ============================================================================
-- Math.sqrt
-- ============================================================================

test("sqrt: 9", function()
  assert_eq(eval_js("Math.sqrt(9)"), 3)
end)

test("sqrt: 2", function()
  assert_eq(eval_js("Math.sqrt(2)"), math.sqrt(2))
end)

test("sqrt: negative → NaN", function()
  local r = eval_js("Math.sqrt(-1)")
  assert(r ~= r, "expected NaN")
end)

-- ============================================================================
-- Math.log
-- ============================================================================

test("log: e → 1", function()
  assert_eq(eval_js("Math.log(Math.E)"), 1)
end)

test("log: 1 → 0", function()
  assert_eq(eval_js("Math.log(1)"), 0)
end)

test("log: negative → NaN", function()
  local r = eval_js("Math.log(-1)")
  assert(r ~= r, "expected NaN")
end)

-- ============================================================================
-- Math.exp
-- ============================================================================

test("exp: 0 → 1", function()
  assert_eq(eval_js("Math.exp(0)"), 1)
end)

test("exp: 1 → ~e", function()
  assert_eq(eval_js("Math.exp(1)"), math.exp(1))
end)

-- ============================================================================
-- Math.sin / Math.cos / Math.tan
-- ============================================================================

test("sin: 0", function()
  assert_eq(eval_js("Math.sin(0)"), 0)
end)

test("cos: 0", function()
  assert_eq(eval_js("Math.cos(0)"), 1)
end)

test("tan: 0", function()
  assert_eq(eval_js("Math.tan(0)"), 0)
end)

test("sin(π/2)", function()
  assert_eq(eval_js("Math.sin(Math.PI / 2)"), 1)
end)

-- ============================================================================
-- Math.asin / Math.acos / Math.atan / Math.atan2
-- ============================================================================

test("asin: 0", function()
  assert_eq(eval_js("Math.asin(0)"), 0)
end)

test("asin: 1 → π/2", function()
  assert_eq(eval_js("Math.asin(1)"), math.pi / 2)
end)

test("acos: 1", function()
  assert_eq(eval_js("Math.acos(1)"), 0)
end)

test("atan: 0", function()
  assert_eq(eval_js("Math.atan(0)"), 0)
end)

test("atan: 1 → π/4", function()
  assert_eq(eval_js("Math.atan(1)"), math.pi / 4)
end)

test("atan2: (1, 1) → π/4", function()
  assert_eq(eval_js("Math.atan2(1, 1)"), math.pi / 4)
end)

test("atan2: (0, -1) → π", function()
  assert_eq(eval_js("Math.atan2(0, -1)"), math.pi)
end)

-- ============================================================================
-- Code generation checks
-- ============================================================================

test("Math.abs emits _ljs_call_member", function()
  local code = transpile_js("Math.abs(1);")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member in output")
end)

test("Math.floor emits _ljs_call_member", function()
  local code = transpile_js("Math.floor(1);")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member in output")
end)
