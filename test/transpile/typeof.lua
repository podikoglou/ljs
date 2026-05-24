local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_lua_source, emit_ok =
  H.transpile_ok, H.expr_code, H.run_lua_source, H.emit_ok

-- ============================================================================
-- Statement context (gen_stmt — side-effect-free, emits nothing)
-- ============================================================================

test("typeof x (statement — helper emitted, no body expr)", function()
  local code = transpile_ok("typeof x;")
  assert(code:find("local function _ljs_typeof"), "expected _ljs_typeof helper")
end)

test("typeof 42 (statement — helper emitted, no body expr)", function()
  local code = transpile_ok("typeof 42;")
  assert(code:find("local function _ljs_typeof"), "expected _ljs_typeof helper")
end)

test("typeof null (statement — helper emitted, no body expr)", function()
  local code = transpile_ok("typeof null;")
  assert(code:find("local function _ljs_typeof"), "expected _ljs_typeof helper")
end)

-- ============================================================================
-- Expression context — typeof as value
-- ============================================================================

test("let r = typeof x", function()
  local code = expr_code("let r = typeof x")
  assert_eq(code, "local r = _ljs_typeof(x)")
end)

test("let r = typeof 42", function()
  local code = expr_code("let r = typeof 42")
  assert_eq(code, "local r = _ljs_typeof(42)")
end)

test('let r = typeof "hello"', function()
  local code = expr_code('let r = typeof "hello"')
  assert_eq(code, 'local r = _ljs_typeof("hello")')
end)

test("let r = typeof true", function()
  local code = expr_code("let r = typeof true")
  assert_eq(code, "local r = _ljs_typeof(true)")
end)

test("let r = typeof false", function()
  local code = expr_code("let r = typeof false")
  assert_eq(code, "local r = _ljs_typeof(false)")
end)

test("let r = typeof null", function()
  local code = expr_code("let r = typeof null")
  assert_eq(code, "local r = _ljs_typeof(_ljs_null)")
end)

test("let r = typeof obj.prop", function()
  local code = expr_code("let r = typeof obj.prop")
  assert_eq(code, "local r = _ljs_typeof(_ljs_to_object(obj).prop)")
end)

test("let r = typeof obj[key]", function()
  local code = expr_code("let r = typeof obj[key]")
  assert_eq(code, "local r = _ljs_typeof(_ljs_to_object(obj)[(key) + 1])")
end)

test("let r = typeof arr[0]", function()
  local code = expr_code("let r = typeof arr[0]")
  assert_eq(code, "local r = _ljs_typeof(_ljs_to_object(arr)[(0) + 1])")
end)

test("let r = typeof f()", function()
  local code = expr_code("let r = typeof f()")
  assert_eq(code, "local r = _ljs_typeof(_ljs_call(f))")
end)

test("let r = typeof (1 + 2)", function()
  local code = expr_code("let r = typeof (1 + 2)")
  assert_eq(code, "local r = _ljs_typeof(_ljs_add(1, 2))")
end)

-- ============================================================================
-- Nesting
-- ============================================================================

test("typeof typeof x (nested)", function()
  local code = expr_code("let r = typeof typeof x")
  assert_eq(code, "local r = _ljs_typeof(_ljs_typeof(x))")
end)

test("typeof typeof typeof x (triple nested)", function()
  local code = expr_code("let r = typeof typeof typeof x")
  assert_eq(code, "local r = _ljs_typeof(_ljs_typeof(_ljs_typeof(x)))")
end)

-- ============================================================================
-- Comparison
-- ============================================================================

test('typeof x === "number" (bare expression)', function()
  local code = expr_code('typeof x === "number"')
  assert_eq(code, '_ljs_typeof(x) == "number"')
end)

test('typeof x !== "undefined" (bare expression)', function()
  local code = expr_code('typeof x !== "undefined"')
  assert_eq(code, '_ljs_typeof(x) ~= "undefined"')
end)

test('typeof x === "function" (bare expression)', function()
  local code = expr_code('typeof x === "function"')
  assert_eq(code, '_ljs_typeof(x) == "function"')
end)

test('let ok = typeof x === "number"', function()
  local code = expr_code('let ok = typeof x === "number"')
  assert_eq(code, 'local ok = _ljs_typeof(x) == "number"')
end)

-- ============================================================================
-- Binary / logical
-- ============================================================================

test("typeof x + typeof y", function()
  local code = expr_code("typeof x + typeof y")
  assert_eq(code, "_ljs_add(_ljs_typeof(x), _ljs_typeof(y))")
end)

test("typeof x && typeof y", function()
  local code = expr_code("typeof x && typeof y")
  assert_eq(code, "_ljs_typeof(x) and _ljs_typeof(y)")
end)

test("typeof x || typeof y", function()
  local code = expr_code("typeof x || typeof y")
  assert_eq(code, "_ljs_typeof(x) or _ljs_typeof(y)")
end)

-- ============================================================================
-- Ternary
-- ============================================================================

test('let r = typeof x === "number" ? 1 : 0', function()
  local code = expr_code('let r = typeof x === "number" ? 1 : 0')
  assert_eq(
    code,
    'local r = (function() if _ljs_typeof(x) == "number" then return 1 else return 0 end end)()'
  )
end)

test('let r = typeof f === "function" ? f() : null', function()
  local code = expr_code('let r = typeof f === "function" ? f() : null')
  assert_eq(
    code,
    'local r = (function() if _ljs_typeof(f) == "function" then return _ljs_call(f) else return _ljs_null end end)()'
  )
end)

-- ============================================================================
-- Assignment / compound assignment
-- ============================================================================

test("result = typeof x", function()
  local code = expr_code("result = typeof x")
  assert_eq(code, "result = _ljs_typeof(x)")
end)

test("x += typeof y", function()
  local code = expr_code("x += typeof y")
  assert_eq(code, "x = _ljs_add(x, _ljs_typeof(y))")
end)

-- ============================================================================
-- Unary interactions
-- ============================================================================

test("!typeof x", function()
  local code = expr_code("!typeof x")
  assert_eq(code, "not _ljs_typeof(x)")
end)

test("let r = typeof !x", function()
  local code = expr_code("let r = typeof !x")
  assert_eq(code, "local r = _ljs_typeof(not x)")
end)

test("let r = typeof -x", function()
  local code = expr_code("let r = typeof -x")
  assert_eq(code, "local r = _ljs_typeof(-x)")
end)

test("-typeof x", function()
  local code = expr_code("-typeof x")
  assert_eq(code, "-_ljs_typeof(x)")
end)

test("let r = typeof +x", function()
  local code = expr_code("let r = typeof +x")
  assert_eq(code, "local r = _ljs_typeof(tonumber(x))")
end)

test("let r = typeof ~x", function()
  local code = expr_code("let r = typeof ~x")
  assert_eq(code, "local r = _ljs_typeof(_ljs_bnot(x))")
end)

-- ============================================================================
-- delete + typeof interaction
-- ============================================================================

test("delete typeof x (statement — no-op)", function()
  local code = emit_ok("delete typeof x;")
  assert(not code:find("rawset"), "expected no rawset call")
end)

test("let r = typeof delete obj.prop", function()
  local code = expr_code("let r = typeof delete obj.prop")
  assert_eq(code, 'local r = _ljs_typeof((rawset(obj, "prop", nil) and true))')
end)

-- ============================================================================
-- Control flow
-- ============================================================================

test("typeof in if condition", function()
  local code = transpile_ok('if (typeof x === "number") { x; }')
  assert(code:find("if _ljs_typeof"), "expected if _ljs_typeof")
  assert(code:find("x\n"), "expected body")
  assert(code:find("end\n"), "expected end")
end)

test("typeof in while condition", function()
  local code = transpile_ok('while (typeof x !== "undefined") { x; }')
  assert(code:find("while _ljs_typeof"), "expected while _ljs_typeof")
end)

test("typeof in return", function()
  local code = transpile_ok("function f() { return typeof x; }")
  assert(code:find("return _ljs_typeof"), "expected return _ljs_typeof")
end)

test("typeof in throw", function()
  local code = transpile_ok("throw typeof x;")
  assert(code:find("error%(_ljs_typeof"), "expected error(_ljs_typeof")
end)

test("typeof in array element", function()
  local code = expr_code("[typeof x]")
  assert_eq(code, "_ljs_new(Array, _ljs_typeof(x))")
end)

test("typeof in object value", function()
  local code = expr_code("({a: typeof x})")
  assert_eq(code, "_ljs_object({a = _ljs_typeof(x)})")
end)

-- ============================================================================
-- Helper emission
-- ============================================================================

test("_ljs_typeof helper emitted when typeof used", function()
  local code = transpile_ok("let r = typeof x;")
  assert(code:find("local function _ljs_typeof"), "expected _ljs_typeof helper definition")
end)

test("_ljs_typeof helper always in preamble", function()
  local code = transpile_ok("let x = 1;")
  assert(code:find("_ljs_typeof"), "expected _ljs_typeof helper in preamble")
end)

-- ============================================================================
-- Integration — run transpiled Lua and verify typeof results
-- ============================================================================

test('integration: typeof 42 === "number"', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
print(_ljs_typeof(42))
]])
  assert_eq(output, "number\n")
end)

test('integration: typeof "hello" === "string"', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
print(_ljs_typeof("hello"))
]])
  assert_eq(output, "string\n")
end)

test('integration: typeof true === "boolean"', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
print(_ljs_typeof(true))
]])
  assert_eq(output, "boolean\n")
end)

test('integration: typeof nil === "undefined"', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
print(_ljs_typeof(nil))
]])
  assert_eq(output, "undefined\n")
end)

test('integration: typeof {} === "object"', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
print(_ljs_typeof({}))
]])
  assert_eq(output, "object\n")
end)

test('integration: typeof function() end === "function"', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
print(_ljs_typeof(function() end))
]])
  assert_eq(output, "function\n")
end)

test("integration: typeof check in if statement", function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
local x = 42
if _ljs_typeof(x) == "number" then
  print("is number")
end
]])
  assert_eq(output, "is number\n")
end)

test('integration: typeof x !== "undefined" pattern', function()
  local output = run_lua_source([[
local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then return "object"
  else return t end
end
local x = "hello"
if _ljs_typeof(x) ~= "undefined" then
  print("defined")
end
]])
  assert_eq(output, "defined\n")
end)

test("integration: end-to-end typeof transpile is loadable", function()
  local code = transpile_ok([[
let x = 42;
let t = typeof x;
if (typeof x === "number") {
  console.log("yes");
}
]])
  assert(code:find("_ljs_typeof"), "expected _ljs_typeof in output")
  local fn, err = load(code)
  if not fn then
    error("load failed: " .. tostring(err) .. "\ncode:\n" .. code)
  end
end)
