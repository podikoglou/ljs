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
-- For-of TDZ self-reference errors (#370)
-- ============================================================================

test("for-of const self-reference errors", function()
  assert_transpile_error("for (const a of a) {}", "Cannot access 'a' before initialization")
end)

test("for-of let self-reference errors", function()
  assert_transpile_error("for (let a of a) {}", "Cannot access 'a' before initialization")
end)

test("for-of const self-reference shadows outer", function()
  assert_transpile_error(
    "const a = [1]; for (const a of a) {}",
    "Cannot access 'a' before initialization"
  )
end)

test("for-of let self-reference shadows outer", function()
  assert_transpile_error(
    "let a = [1]; for (let a of a) {}",
    "Cannot access 'a' before initialization"
  )
end)

test("for-of nested self-reference errors", function()
  assert_transpile_error(
    "for (let i of [1]) { for (let i of i) {} }",
    "Cannot access 'i' before initialization"
  )
end)

-- ============================================================================
-- For-in TDZ self-reference errors (#371)
-- ============================================================================

test("for-in const self-reference errors", function()
  assert_transpile_error("for (const a in a) {}", "Cannot access 'a' before initialization")
end)

test("for-in let self-reference errors", function()
  assert_transpile_error("for (let a in a) {}", "Cannot access 'a' before initialization")
end)

test("for-in const self-reference shadows outer", function()
  assert_transpile_error(
    "const a = {x:1}; for (const a in a) {}",
    "Cannot access 'a' before initialization"
  )
end)

test("for-in let self-reference shadows outer", function()
  assert_transpile_error(
    "let a = {x:1}; for (let a in a) {}",
    "Cannot access 'a' before initialization"
  )
end)

-- ============================================================================
-- For-loop init TDZ self-reference errors (#373)
-- ============================================================================

test("for-loop let init self-reference errors", function()
  assert_transpile_error(
    "for (let i = i; i < 3; i = i + 1) {}",
    "Cannot access 'i' before initialization"
  )
end)

test("for-loop let init self-reference in expression errors", function()
  assert_transpile_error(
    "for (let i = i + 1; i < 3; i = i + 1) {}",
    "Cannot access 'i' before initialization"
  )
end)

test("for-loop const init self-reference errors", function()
  assert_transpile_error("for (const i = i; i < 3;) {}", "Cannot access 'i' before initialization")
end)

-- ============================================================================
-- Valid loops that must still work
-- ============================================================================

test("for-of different names is fine", function()
  local code = transpile_ok("const a = [1]; for (const x of a) {}")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("for-of literal iterable is fine", function()
  local code = transpile_ok("for (const x of [1, 2, 3]) {}")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("for-in different names is fine", function()
  local code = transpile_ok("const obj = {a:1}; for (const k in obj) {}")
  assert(code:find("k", 1, true), "expected k in output")
end)

test("for-in literal object is fine", function()
  local code = transpile_ok("for (const k in {a: 1, b: 2}) {}")
  assert(code:find("k", 1, true), "expected k in output")
end)

test("for-loop normal init is fine", function()
  local code = transpile_ok("for (let i = 0; i < 3; i = i + 1) {}")
  assert(code:find("i", 1, true), "expected i in output")
end)

test("for-loop i referenced after init is fine", function()
  local code = transpile_ok("for (let i = 0; i < i + 3; i = i + 1) {}")
  assert(code:find("i", 1, true), "expected i in output")
end)

test("for-loop var init self-reference is fine (no TDZ)", function()
  local code = transpile_ok("for (var i = i; i < 3; i = i + 1) {}")
  assert(code:find("i", 1, true), "expected i in output")
end)
