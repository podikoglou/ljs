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

-- ============================================================================
-- #376: Destructuring default value TDZ
-- ============================================================================

test("destructuring object default self-reference errors (#376)", function()
  assert_transpile_error("let {x = x} = {};", "Cannot access 'x' before initialization")
end)

test("destructuring array default self-reference errors (#376)", function()
  assert_transpile_error("let [x = x] = [];", "Cannot access 'x' before initialization")
end)

test("destructuring cross-default TDZ errors (#376)", function()
  assert_transpile_error("let {a = b, b = 1} = {};", "Cannot access 'b' before initialization")
end)

test("destructuring literal default is fine (#376)", function()
  transpile_ok("let {x = 1} = {};")
end)

-- ============================================================================
-- #372: Block-level use-before-declaration TDZ
-- ============================================================================

test("use before let in expression errors (#372)", function()
  assert_transpile_error("console.log(x); let x = 5;", "Cannot access 'x' before initialization")
end)

test("bare identifier use before let errors (#372)", function()
  assert_transpile_error("x; let x = 5;", "Cannot access 'x' before initialization")
end)

test("typeof before let errors (#372)", function()
  assert_transpile_error("typeof x; let x = 5;", "Cannot access 'x' before initialization")
end)

test("use in if-condition before let errors (#372)", function()
  assert_transpile_error("if (x) {} let x = 5;", "Cannot access 'x' before initialization")
end)

test("use before const errors (#372)", function()
  assert_transpile_error("console.log(x); const x = 5;", "Cannot access 'x' before initialization")
end)

test("inner block shadow use before let errors (#372)", function()
  assert_transpile_error(
    "let x = 1; { console.log(x); let x = 2; }",
    "Cannot access 'x' before initialization"
  )
end)

-- #372: Valid code that must still work

test("declaration before use is fine (#372)", function()
  transpile_ok("let x = 5; console.log(x);")
end)

test("var has no TDZ (#372)", function()
  transpile_ok("console.log(x); var x = 5;")
end)

test("function hoisting is fine (#372)", function()
  transpile_ok("foo(); function foo() {}")
end)

test("inner block declared before use is fine (#372)", function()
  transpile_ok("let x = 1; { let x = 2; console.log(x); }")
end)

test("inner block no shadow is fine (#372)", function()
  transpile_ok("let x = 1; { console.log(x); }")
end)
