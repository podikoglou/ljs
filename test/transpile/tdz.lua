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
-- TDZ self-reference errors
-- ============================================================================

test("let self-reference errors", function()
  assert_transpile_error("let x = x;", "Cannot access 'x' before initialization")
end)

test("let self-reference in expression errors", function()
  assert_transpile_error("let x = x + 1;", "Cannot access 'x' before initialization")
end)

test("const self-reference errors", function()
  assert_transpile_error("const x = x;", "Cannot access 'x' before initialization")
end)

test("cross-declarator TDZ errors (let y = x, x = 1)", function()
  assert_transpile_error("let y = x, x = 1;", "Cannot access 'x' before initialization")
end)

test("cross-declarator TDZ errors (let a = b, b = 2)", function()
  assert_transpile_error("let a = b, b = 2;", "Cannot access 'b' before initialization")
end)

test("destructured object self-reference errors", function()
  assert_transpile_error("let {x} = x;", "Cannot access 'x' before initialization")
end)

test("destructured array self-reference errors", function()
  assert_transpile_error("let [a] = a;", "Cannot access 'a' before initialization")
end)

test("typeof does not bypass TDZ", function()
  assert_transpile_error("let x = typeof x;", "Cannot access 'x' before initialization")
end)

-- ============================================================================
-- Valid code that must still work
-- ============================================================================

test("let x = 1 is fine", function()
  local code = transpile_ok("let x = 1;")
  assert(code:find("local x = 1", 1, true), "expected local x = 1")
end)

test("let x = 1, y = x is fine (forward reference OK)", function()
  local code = transpile_ok("let x = 1, y = x;")
  assert(code:find("local x = 1", 1, true), "expected local x = 1")
  assert(code:find("local y = x", 1, true), "expected local y = x")
end)

test("var x = x is fine (no TDZ for var)", function()
  local code = transpile_ok("var x = x;")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let x = arrow function referencing x is fine (lazy)", function()
  local code = transpile_ok("let x = () => x;")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let x = function expression referencing x is fine (lazy)", function()
  local code = transpile_ok("let x = function() { return x; };")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let x = obj.x is fine (property access, not variable ref)", function()
  local code = transpile_ok("let x = obj.x;")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let x = {x: 1} is fine (property key, not variable ref)", function()
  local code = transpile_ok("let x = {x: 1};")
  assert(code:find("x", 1, true), "expected x in output")
end)
