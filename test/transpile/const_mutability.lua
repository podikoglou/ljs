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

test("nested scope const reassignment errors", function()
  assert_transpile_error("const x = 1; { x = 2; }", "Assignment to constant variable")
end)

test("destructured const object reassignment errors", function()
  assert_transpile_error("const {a} = {a: 1}; a = 2;", "Assignment to constant variable")
end)

test("destructured const array reassignment errors", function()
  assert_transpile_error("const [a] = [1]; a = 2;", "Assignment to constant variable")
end)

-- ============================================================================
-- Valid code that must still work
-- ============================================================================

test("const declaration transpiles", function()
  local code = transpile_ok("const x = 1;")
  assert(code:find("local x = 1", 1, true), "expected local x = 1")
end)

test("reading const is fine", function()
  local code = transpile_ok("const x = 1; let y = x;")
  assert(code:find("local y = x", 1, true), "expected local y = x")
end)

test("const with arrow function", function()
  local code = transpile_ok("const f = () => 1;")
  assert(code:find("local f", 1, true), "expected local f")
end)

test("shadowing const in inner scope", function()
  local code = transpile_ok("const x = 1; { const x = 2; }")
  assert(code:find("local x = 1", 1, true), "expected outer local x = 1")
  assert(code:find("local x = 2", 1, true), "expected inner local x = 2")
end)

test("const in for-of transpiles", function()
  local code = transpile_ok("for (const x of [1, 2]) { let y = x; }")
  assert(code:find("local x", 1, true), "expected local x")
end)

test("const in for-in transpiles", function()
  local code = transpile_ok("for (const k in {a: 1}) { let y = k; }")
  assert(code:find("local k", 1, true), "expected local k")
end)

test("const in for-of reassignment errors", function()
  assert_transpile_error("for (const x of [1, 2]) { x = 3; }", "Assignment to constant variable")
end)

test("const in for-in reassignment errors", function()
  assert_transpile_error("for (const k in {a: 1}) { k = 'b'; }", "Assignment to constant variable")
end)

test("let reassignment still works", function()
  local code = transpile_ok("let x = 1; x = 2;")
  assert(code:find("x = 2", 1, true), "expected x = 2")
end)

test("let update still works", function()
  local code = transpile_ok("let x = 1; x++;")
  assert(code:find("x = ", 1, true), "expected x assignment")
end)

test("const modulo assignment errors", function()
  assert_transpile_error("const x = 10; x %= 3;", "Assignment to constant variable")
end)

test("const bitwise assignment errors", function()
  assert_transpile_error("const x = 1; x &= 2;", "Assignment to constant variable")
end)

test("duplicate let in same scope errors", function()
  assert_transpile_error("const x = 1; const x = 2;", "already been declared")
end)

test("const redeclaration in same scope errors", function()
  assert_transpile_error("let x = 1; const x = 2;", "already been declared")
end)

test("var redeclaration in same scope is allowed", function()
  local code = transpile_ok("var x = 1; var x = 2;")
  assert(code:find("local x = 1", 1, true), "expected local x = 1")
  assert(code:find("local x = 2", 1, true), "expected local x = 2")
end)

test("let redeclaration in same scope errors", function()
  assert_transpile_error("let x = 1; let x = 2;", "already been declared")
end)

test("var then let in same scope errors", function()
  assert_transpile_error("var x = 1; let x = 2;", "already been declared")
end)

test("let then var in same scope errors", function()
  assert_transpile_error("let x = 1; var x = 2;", "already been declared")
end)

test("var then const in same scope errors", function()
  assert_transpile_error("var x = 1; const x = 2;", "already been declared")
end)

test("const then var in same scope errors", function()
  assert_transpile_error("const x = 1; var x = 2;", "already been declared")
end)

test("const in C-style for update errors", function()
  assert_transpile_error("for (const x = 0; x < 5; x = x + 1) {}", "Assignment to constant variable")
end)

test("for-variable shadows outer let without duplicate error", function()
  local code = transpile_ok("let x = 1; for (let x = 0; x < 5; x = x + 1) {}")
  assert(code:find("local x = 1", 1, true), "expected outer local x = 1")
  assert(code:find("local x = 0", 1, true), "expected inner local x = 0")
end)

test("for-const shadows outer let and errors on reassignment", function()
  assert_transpile_error(
    "let x = 1; for (const x = 0; x < 5; x = x + 1) {}",
    "Assignment to constant variable"
  )
end)
