local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

test("array with spread [...a] transpiles using _ljs_spread", function()
  local code = transpile_ok("[...a]")
  assert(code:find("_ljs_spread_build", 1, true), "expected _ljs_spread_build helper")
end)

test("array with spread [...a] produces flattened array", function()
  local out = run_js("let a = [1, 2, 3]; let b = [...a]; console.log(b.length);")
  assert_eq(out, "3\n")
end)

test("array with spread elements [...a] has correct values", function()
  local out = run_js("let a = [10, 20]; let b = [...a]; console.log(b[0], b[1]);")
  assert_eq(out, "10\t20\n")
end)

test("array with spread and literal [1, ...a]", function()
  local out = run_js("let a = [2, 3]; let b = [1, ...a]; console.log(b.length);")
  assert_eq(out, "3\n")
end)

test("array with spread in middle [1, ...a, 4]", function()
  local out = run_js("let a = [2, 3]; let b = [1, ...a, 4]; console.log(b.length);")
  assert_eq(out, "4\n")
end)

test("array with multiple spreads [...a, ...b]", function()
  local out = run_js("let a = [1, 2]; let b = [3, 4]; let c = [...a, ...b]; console.log(c.length);")
  assert_eq(out, "4\n")
end)

test("call with spread fn(...a)", function()
  local out = run_js("function sum(a, b) { return a + b; }\nlet args = [3, 4]; console.log(sum(...args));")
  assert_eq(out, "7\n")
end)

test("call with mixed args fn(1, ...a, 2)", function()
  local out = run_js("function f(a, b, c) { return a + b + c; }\nlet args = [10]; console.log(f(1, ...args, 2));")
  assert_eq(out, "13\n")
end)

test("new with spread new Fn(...a)", function()
  local out = run_js("function Pair(x, y) { this.x = x; this.y = y; }\nlet args = [10, 20]; let p = new Pair(...args); console.log(p.x, p.y);")
  assert_eq(out, "10\t20\n")
end)

test("method call with spread obj.fn(...a)", function()
  local out = run_js("let obj = { add: function(a, b) { return a + b; } };\nlet args = [5, 3]; console.log(obj.add(...args));")
  assert_eq(out, "8\n")
end)

test("spread string in array [...\"abc\"] produces chars", function()
  local out = run_js([[let r = [..."abc"]; console.log(r.length, r[0], r[1], r[2]);]])
  assert_eq(out, "3\ta\tb\tc\n")
end)
