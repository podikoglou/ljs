local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, emit_ok, run_js = H.transpile_ok, H.emit_ok, H.run_js

test("semicolon before spread IIFE after function declaration", function()
  local code = emit_ok("function f(){}\nf(...args)")
  assert(code:find(";\n%(function%("), "expected semicolon before spread IIFE, got:\n" .. code)
end)

test("semicolon before spread IIFE after assignment ending in paren", function()
  local code = emit_ok("let x = foo()\nf(...args)")
  assert(code:find(";\n%(function%("), "expected semicolon before spread IIFE after call-ending assignment")
end)

test("no semicolon when not needed", function()
  local code = emit_ok("let x = 1; let y = 2;")
  assert(not code:find(";\n;"), "should not have double semicolons when not ambiguous")
end)

test("no semicolon before non-paren statement", function()
  local code = emit_ok("function f(){} f(1)")
  assert(not code:find(";\n_ljs_call"), "no semicolon needed before _ljs_call (not paren)")
end)

test("spread call after function declaration runs correctly", function()
  local output = run_js("function f(a){ console.log(a) }\nlet args = [1]\nf(...args)")
  assert_eq(output:match("^[^\n]*"), "1")
end)

test("semicolon in nested block", function()
  local code = emit_ok("if (true) { function f(){} f(...args) }")
  assert(code:find(";\n  %(function%("), "expected semicolon before IIFE in nested block")
end)

test("semicolon before ternary IIFE after function declaration", function()
  local code = emit_ok("function f(){}\ntrue ? 1 : 2")
  assert(code:find(";\n%(function%("), "expected semicolon before ternary IIFE, got:\n" .. code)
end)

test("no semicolon between non-ambiguous statements", function()
  local code = emit_ok("function f(){}\nfunction g(){}")
  assert(not code:find(";\nlocal"), "no semicolon between function declarations")
end)
