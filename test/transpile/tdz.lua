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
-- #376: Destructuring default values TDZ
-- ============================================================================

test("let {x = x} = {} errors (object default self-ref)", function()
  assert_transpile_error("let {x = x} = {};", "Cannot access 'x' before initialization")
end)

test("let [x = x] = [] errors (array default self-ref)", function()
  assert_transpile_error("let [x = x] = [];", "Cannot access 'x' before initialization")
end)

test("let {x = x} = {x: 1} errors (static, conservative)", function()
  assert_transpile_error("let {x = x} = {x: 1};", "Cannot access 'x' before initialization")
end)

test("let {x: {y = y}} = {x: {}} errors (nested default self-ref)", function()
  assert_transpile_error("let {x: {y = y}} = {x: {}};", "Cannot access 'y' before initialization")
end)

test("let {x = 1} = {} is fine (literal default)", function()
  local code = transpile_ok("let {x = 1} = {};")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let {x = y} = {} is fine (default refs unrelated name)", function()
  local code = transpile_ok("let {x = y} = {};")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let {x = y} = {x: 1} is fine (default refs unrelated name)", function()
  local code = transpile_ok("let {x = y} = {x: 1};")
  assert(code:find("x", 1, true), "expected x in output")
end)

-- ============================================================================
-- #372: Block-level use-before-declaration TDZ
-- ============================================================================

test("console.log(x); let x = 5; errors (use before decl)", function()
  assert_transpile_error("console.log(x); let x = 5;", "Cannot access 'x' before initialization")
end)

test("x; let x = 5; errors (bare ref before decl)", function()
  assert_transpile_error("x; let x = 5;", "Cannot access 'x' before initialization")
end)

test("typeof x; let x; errors (typeof does not bypass TDZ)", function()
  assert_transpile_error("typeof x; let x;", "Cannot access 'x' before initialization")
end)

test("f(x); let x; errors (arg before decl)", function()
  assert_transpile_error("f(x); let x;", "Cannot access 'x' before initialization")
end)

test("if (x) {} let x; errors (condition before decl)", function()
  assert_transpile_error("if (x) {} let x;", "Cannot access 'x' before initialization")
end)

test("x = 3; let x; errors (assignment before decl)", function()
  assert_transpile_error("x = 3; let x;", "Cannot access 'x' before initialization")
end)

test("console.log(x); const x = 5; errors (const TDZ)", function()
  assert_transpile_error("console.log(x); const x = 5;", "Cannot access 'x' before initialization")
end)

test("inner block TDZ: { console.log(x); let x = 2; } errors", function()
  assert_transpile_error("{ console.log(x); let x = 2; }", "Cannot access 'x' before initialization")
end)

test("let x = 5; console.log(x); is fine (decl before use)", function()
  local code = transpile_ok("let x = 5; console.log(x);")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("console.log(x); var x = 5; is fine (var, no TDZ)", function()
  local code = transpile_ok("console.log(x); var x = 5;")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("foo(); function foo() {} is fine (function hoisting)", function()
  local code = transpile_ok("foo(); function foo() {}")
  assert(code:find("foo", 1, true), "expected foo in output")
end)

test("inner shadows outer: { let x = 2; console.log(x); } let x = 1; OK", function()
  local code = transpile_ok("{ let x = 2; console.log(x); } let x = 1;")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let x = 1; { let x = 2; console.log(x); } OK (inner shadows)", function()
  local code = transpile_ok("let x = 1; { let x = 2; console.log(x); }")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("function boundary: function foo() { console.log(x); } let x = 1; OK", function()
  local code = transpile_ok("function foo() { console.log(x); } let x = 1;")
  assert(code:find("x", 1, true), "expected x in output")
end)

test("let x = 1; { console.log(x); } OK (inner refs outer, no inner let)", function()
  local code = transpile_ok("let x = 1; { console.log(x); }")
  assert(code:find("x", 1, true), "expected x in output")
end)
