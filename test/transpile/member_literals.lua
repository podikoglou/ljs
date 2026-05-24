-- Transpile tests: member access on boolean, string, null, and undefined literals
local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js = H.transpile_ok, H.expr_code, H.run_js

-- ============================================================================
-- Generated code verification
-- ============================================================================

test("bool: true.toString transpiles", function()
  local code = transpile_ok("true.toString();")
  assert(type(code) == "string", "expected string code")
end)

test("bool: true.toString() (call) transpiles", function()
  local code = transpile_ok("true.toString();")
  assert(type(code) == "string", "expected string code")
end)

test("bool: false.toString() transpiles", function()
  local code = transpile_ok("false.toString();")
  assert(type(code) == "string", "expected string code")
end)

test('bool: true["toString"] transpiles', function()
  local code = transpile_ok('true["toString"];')
  assert(type(code) == "string", "expected string code")
end)

test('bool: true["toString"]() transpiles', function()
  local code = transpile_ok('true["toString"]();')
  assert(type(code) == "string", "expected string code")
end)

test('string: "hello".length transpiles', function()
  local code = transpile_ok('"hello".length;')
  assert(type(code) == "string", "expected string code")
end)

test('string: "hello".toString() transpiles', function()
  local code = transpile_ok('"hello".toString();')
  assert(type(code) == "string", "expected string code")
end)

test('string: "hello"["length"] transpiles', function()
  local code = transpile_ok('"hello"["length"];')
  assert(type(code) == "string", "expected string code")
end)

test("null: null.foo transpiles", function()
  local code = transpile_ok("null.foo;")
  assert(type(code) == "string", "expected string code")
end)

test("null: null.toString() transpiles", function()
  local code = transpile_ok("null.toString();")
  assert(type(code) == "string", "expected string code")
end)

test("undefined: undefined.bar transpiles", function()
  local code = transpile_ok("undefined.bar;")
  assert(type(code) == "string", "expected string code")
end)

test("undefined: undefined.foo() transpiles", function()
  local code = transpile_ok("undefined.foo();")
  assert(type(code) == "string", "expected string code")
end)

-- ============================================================================
-- Chained
-- ============================================================================

test("chained: true.toString().length transpiles", function()
  local code = transpile_ok("true.toString().length;")
  assert(type(code) == "string", "expected string code")
end)

test('chained: "hello".toString().length transpiles', function()
  local code = transpile_ok('"hello".toString().length;')
  assert(type(code) == "string", "expected string code")
end)

-- ============================================================================
-- In expressions/declarations
-- ============================================================================

test('var decl: let s = "hello".toString() transpiles', function()
  local code = transpile_ok('let s = "hello".toString();')
  assert(type(code) == "string", "expected string code")
end)

test('arg: f("hello".toString()) transpiles', function()
  local code = transpile_ok('f("hello".toString());')
  assert(type(code) == "string", "expected string code")
end)

test('binary: "a" < "b".toString() transpiles', function()
  local code = transpile_ok('"a" < "b".toString();')
  assert(type(code) == "string", "expected string code")
end)

test('return: function f() { return "hello".length; } transpiles', function()
  local code = transpile_ok('function f() { return "hello".length; }')
  assert(type(code) == "string", "expected string code")
end)

-- ============================================================================
-- Parenthesized forms still work
-- ============================================================================

test("parens: (true).toString() transpiles", function()
  local code = transpile_ok("(true).toString();")
  assert(type(code) == "string", "expected string code")
end)

test('parens: ("hello").toString() transpiles', function()
  local code = transpile_ok('("hello").toString();')
  assert(type(code) == "string", "expected string code")
end)

test("parens: (null).foo transpiles", function()
  local code = transpile_ok("(null).foo;")
  assert(type(code) == "string", "expected string code")
end)

test("parens: (undefined).bar transpiles", function()
  local code = transpile_ok("(undefined).bar;")
  assert(type(code) == "string", "expected string code")
end)

-- ============================================================================
-- Negative cases: number literals should not transpile
-- ============================================================================

test("error: 5.toString() should fail parse", function()
  local ast, err = require("ljs.parser").parse("5.toString();")
  assert(ast == nil, "expected parse failure")
end)
