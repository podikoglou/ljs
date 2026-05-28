local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js
local parser = require("ljs.parser")
local transpile = require("ljs.transpile")

local function assert_transpile_error(src, expected_msg)
  local ast, perr = parser.parse(src)
  if not ast then
    error("parse failed: " .. tostring(perr))
  end
  local ok, err = pcall(transpile.transpile, ast)
  if ok then
    error("expected transpile error for: " .. src .. ", but transpile succeeded")
  end
  local msg = tostring(err)
  assert(
    msg:find(expected_msg, 1, true),
    "expected error containing '" .. expected_msg .. "', got: " .. msg
  )
end

-- ============================================================================
-- Compile-time errors
-- ============================================================================

test("const reassignment errors", function()
  assert_transpile_error("const x = 1; x = 2;", "Assignment to constant variable")
end)

test("compound assignment to const errors", function()
  assert_transpile_error("const x = 1; x += 1;", "Assignment to constant variable")
end)

test("update expression on const errors (postfix)", function()
  assert_transpile_error("const x = 1; x++;", "Assignment to constant variable")
end)

test("update expression on const errors (prefix)", function()
  assert_transpile_error("const x = 1; ++x;", "Assignment to constant variable")
end)

test("const without initializer errors", function()
  assert_transpile_error("const x;", "Missing initializer in const declaration")
end)
