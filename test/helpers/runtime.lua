local transpile = require("ljs_transpile")
local parser = require("ljs_parser")
local T = require("ljs_test")

local test, assert_eq = T.test, T.assert_eq

local function transpile_js(js)
  local ast, err = parser.parse(js)
  if not ast then
    error("parse failed: " .. tostring(err))
  end
  local code, err2 = transpile.transpile(ast)
  if not code then
    error("transpile failed: " .. tostring(err2))
  end
  return code
end

local function exec_js(js)
  local code = transpile_js(js)
  local fn, load_err = load(code)
  if not fn then
    error("load failed: " .. tostring(load_err) .. "\ncode:\n" .. code)
  end
  return fn()
end

local function eval_js(js_expr)
  return exec_js("return " .. js_expr .. ";")
end

local function assert_js(js_expr, expected, msg)
  assert_eq(eval_js(js_expr), expected, msg or js_expr)
end

return {
  test = test,
  assert_eq = assert_eq,
  transpile_js = transpile_js,
  exec_js = exec_js,
  eval_js = eval_js,
  assert_js = assert_js,
}
