local T = require("ljs_test")
local H = require("ljs_test_transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js, run_lua_source = H.transpile_ok, H.expr_code, H.run_js, H.run_lua_source

-- ============================================================================
-- Unit tests — ternary operator
-- ============================================================================

test("ternary basic", function()
  assert_eq(expr_code("x ? 1 : 0"), "(function() if x then return 1 else return 0 end end)()")
end)

test("ternary falsy consequent correctness", function()
  assert_eq(expr_code("true ? false : 0"), "(function() if true then return false else return 0 end end)()")
end)

test("ternary in variable init", function()
  local code = transpile_ok("let x = a ? 1 : 0;")
  assert_eq(code, "local x = (function() if a then return 1 else return 0 end end)()\n")
end)

test("ternary nested", function()
  local code = expr_code("a ? b ? 1 : 2 : 3")
  assert(code:find("function%("), "expected IIFE in nested ternary")
end)

test("ternary in function return", function()
  local code = transpile_ok("function f(x) { return x ? 1 : 0; }")
  assert(code:find("return %(function%("), "expected IIFE in return")
end)

test("ternary integration: truthy branch", function()
  local output = run_lua_source("local a = true\nlocal x = (function() if a then return 1 else return 0 end end)()\nprint(x)\n")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("ternary integration: falsy branch", function()
  local output = run_lua_source("local a = false\nlocal x = (function() if a then return 1 else return 0 end end)()\nprint(x)\n")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("ternary integration: falsy consequent is not or'd away", function()
  local output = run_lua_source("local x = (function() if true then return false else return 0 end end)()\nprint(tostring(x))\n")
  assert_eq(output:gsub("%s+", ""), "false")
end)

test("ternary integration: end-to-end via transpile", function()
  local output = run_js("let a = true; let x = a ? 42 : 0; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "42")
end)

test("ternary integration: end-to-end falsy", function()
  local output = run_js("let a = false; let x = a ? 42 : 99; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "99")
end)

test("ternary integration: side effects in untaken branch don't execute", function()
  local output = run_js(
    "let count = 0;" ..
    "function inc() { count = count + 1; return count; }" ..
    "let result = true ? 42 : inc();" ..
    "console.log(count);"
  )
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("ternary integration: side effects in taken branch do execute", function()
  local output = run_js(
    "let count = 0;" ..
    "function inc() { count = count + 1; return count; }" ..
    "let result = false ? 42 : inc();" ..
    "console.log(count);"
  )
  assert_eq(output:gsub("%s+", ""), "1")
end)

T.summary()
