local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local expr_code, run_js = H.expr_code, H.run_js

test("simple template literal transpiles to string", function()
  assert_eq(expr_code("`hello`;"), 'local _ = "hello"')
end)

test("template literal with interpolation", function()
  assert_eq(expr_code("`hello ${name}`;"), 'local _ = "hello " .. _ljs_tostring(name)')
end)

test("template literal with multiple interpolations", function()
  assert_eq(expr_code("`${a} and ${b}`;"), 'local _ = _ljs_tostring(a) .. " and " .. _ljs_tostring(b)')
end)

test("template with number expression", function()
  assert_eq(expr_code("`val: ${42}`;"), 'local _ = "val: " .. _ljs_tostring(42)')
end)

test("run simple template literal", function()
  local output = run_js("let x = `hello`; console.log(x);")
  assert_eq(output, "hello\n")
end)

test("run template with variable interpolation", function()
  local output = run_js("let name = 'world'; console.log(`hello ${name}`);")
  assert_eq(output, "hello world\n")
end)

test("run template with number interpolation", function()
  local output = run_js("let x = 42; console.log(`value: ${x}`);")
  assert_eq(output, "value: 42\n")
end)

test("multi-line template literal", function()
  local output = run_js("let s = `line1\nline2`; console.log(s);")
  assert_eq(output, "line1\nline2\n")
end)

test("template in variable assignment", function()
  assert_eq(expr_code("let s = `hello`;"), 'local s = "hello"')
end)

test("template concatenated with +", function()
  local output = run_js("let a = 'hello'; let b = `${a} world`; console.log(b);")
  assert_eq(output, "hello world\n")
end)

test("template with complex expression", function()
  local output = run_js("let x = 3; let y = 4; console.log(`${x} + ${y} = ${x + y}`);")
  assert_eq(output, "3 + 4 = 7\n")
end)

test("empty template literal", function()
  assert_eq(expr_code("``;"), 'local _ = ""')
end)

test("template with only interpolation", function()
  assert_eq(expr_code("`${x}`;"), "local _ = _ljs_tostring(x)")
end)

test("template with adjacent interpolations", function()
  assert_eq(expr_code("`${a}${b}`;"), "local _ = _ljs_tostring(a) .. _ljs_tostring(b)")
end)
