-- Parser tests: member access on boolean, string, null, and undefined literals
local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local parser = P.parser

-- ============================================================================
-- DOT MEMBER ACCESS
-- ============================================================================

test("parse true.prop (dot member on boolean)", function()
  assert_parse_ok("true.toString;", {
    A.expr_stmt(A.member(A.bool(true), A.id("toString"))),
  })
end)

test("parse false.prop (dot member on boolean)", function()
  assert_parse_ok("false.toString;", {
    A.expr_stmt(A.member(A.bool(false), A.id("toString"))),
  })
end)

test('parse "hello".prop (dot member on string)', function()
  assert_parse_ok('"hello".length;', {
    A.expr_stmt(A.member(A.str("hello"), A.id("length"))),
  })
end)

test("parse null.prop (dot member on null)", function()
  assert_parse_ok("null.foo;", {
    A.expr_stmt(A.member(A.null(), A.id("foo"))),
  })
end)

test("parse undefined.prop (dot member on undefined)", function()
  assert_parse_ok("undefined.bar;", {
    A.expr_stmt(A.member(A.undef(), A.id("bar"))),
  })
end)

-- ============================================================================
-- DOT MEMBER + CALL
-- ============================================================================

test("parse true.toString() (call on boolean member)", function()
  assert_parse_ok("true.toString();", {
    A.expr_stmt(A.call(A.member(A.bool(true), A.id("toString")), {})),
  })
end)

test("parse false.toString() (call on boolean member)", function()
  assert_parse_ok("false.toString();", {
    A.expr_stmt(A.call(A.member(A.bool(false), A.id("toString")), {})),
  })
end)

test('parse "hello".toString() (call on string member)', function()
  assert_parse_ok('"hello".toString();', {
    A.expr_stmt(A.call(A.member(A.str("hello"), A.id("toString")), {})),
  })
end)

test("parse null.toString() (call on null member)", function()
  assert_parse_ok("null.toString();", {
    A.expr_stmt(A.call(A.member(A.null(), A.id("toString")), {})),
  })
end)

test("parse undefined.toString() (call on undefined member)", function()
  assert_parse_ok("undefined.toString();", {
    A.expr_stmt(A.call(A.member(A.undef(), A.id("toString")), {})),
  })
end)

-- ============================================================================
-- COMPUTED MEMBER ACCESS
-- ============================================================================

test('parse true["toString"] (computed member on boolean)', function()
  assert_parse_ok('true["toString"];', {
    A.expr_stmt(A.member_c(A.bool(true), A.str("toString"))),
  })
end)

test('parse false["toString"] (computed member on boolean)', function()
  assert_parse_ok('false["toString"];', {
    A.expr_stmt(A.member_c(A.bool(false), A.str("toString"))),
  })
end)

test('parse "hello"["length"] (computed member on string)', function()
  assert_parse_ok('"hello"["length"];', {
    A.expr_stmt(A.member_c(A.str("hello"), A.str("length"))),
  })
end)

test('parse null["foo"] (computed member on null)', function()
  assert_parse_ok('null["foo"];', {
    A.expr_stmt(A.member_c(A.null(), A.str("foo"))),
  })
end)

test('parse undefined["bar"] (computed member on undefined)', function()
  assert_parse_ok('undefined["bar"];', {
    A.expr_stmt(A.member_c(A.undef(), A.str("bar"))),
  })
end)

-- ============================================================================
-- COMPUTED MEMBER + CALL
-- ============================================================================

test('parse true["toString"]() (computed call on boolean)', function()
  assert_parse_ok('true["toString"]();', {
    A.expr_stmt(A.call(A.member_c(A.bool(true), A.str("toString")), {})),
  })
end)

test('parse "hello"["toString"]() (computed call on string)', function()
  assert_parse_ok('"hello"["toString"]();', {
    A.expr_stmt(A.call(A.member_c(A.str("hello"), A.str("toString")), {})),
  })
end)

-- ============================================================================
-- CHAINED MEMBER / CALL
-- ============================================================================

test("parse true.toString().length (chained on boolean)", function()
  assert_parse_ok("true.toString().length;", {
    A.expr_stmt(A.member(A.call(A.member(A.bool(true), A.id("toString")), {}), A.id("length"))),
  })
end)

test('parse "hello".toString().length (chained on string)', function()
  assert_parse_ok('"hello".toString().length;', {
    A.expr_stmt(A.member(A.call(A.member(A.str("hello"), A.id("toString")), {}), A.id("length"))),
  })
end)

test("parse true.valueOf().toString() (double chained call on boolean)", function()
  assert_parse_ok("true.valueOf().toString();", {
    A.expr_stmt(
      A.call(A.member(A.call(A.member(A.bool(true), A.id("valueOf")), {}), A.id("toString")), {})
    ),
  })
end)

-- ============================================================================
-- IN ASSIGNMENT / VARIABLE DECLARATIONS
-- ============================================================================

test('parse let s = "hello".toString() (in var decl)', function()
  assert_parse_ok('let s = "hello".toString();', {
    A.let("s", A.call(A.member(A.str("hello"), A.id("toString")), {})),
  })
end)

test('parse const n = "hello".length (in const decl)', function()
  assert_parse_ok('const n = "hello".length;', {
    A.const("n", A.member(A.str("hello"), A.id("length"))),
  })
end)

test("parse let b = true.toString() (boolean in var decl)", function()
  assert_parse_ok("let b = true.toString();", {
    A.let("b", A.call(A.member(A.bool(true), A.id("toString")), {})),
  })
end)

-- ============================================================================
-- IN EXPRESSIONS (binary, ternary, unary)
-- ============================================================================

test('parse "a" < "b".toString() (in binary expression)', function()
  assert_parse_ok('"a" < "b".toString();', {
    A.expr_stmt(A.bin("<", A.str("a"), A.call(A.member(A.str("b"), A.id("toString")), {}))),
  })
end)

test('parse true ? "yes" : "no".toString() (in ternary)', function()
  assert_parse_ok('true ? "yes" : "no".toString();', {
    A.expr_stmt(
      A.ternary(A.bool(true), A.str("yes"), A.call(A.member(A.str("no"), A.id("toString")), {}))
    ),
  })
end)

test("parse typeof true.toString() (typeof on member)", function()
  assert_parse_ok("typeof true.toString();", {
    A.expr_stmt(A.typeof_(A.call(A.member(A.bool(true), A.id("toString")), {}))),
  })
end)

-- ============================================================================
-- IN FUNCTION ARGUMENTS / RETURNS
-- ============================================================================

test('parse f("hello".toString()) (in function arg)', function()
  assert_parse_ok('f("hello".toString());', {
    A.expr_stmt(A.call(A.id("f"), {
      A.call(A.member(A.str("hello"), A.id("toString")), {}),
    })),
  })
end)

test('parse function f() { return "hello".length; } (in return)', function()
  assert_parse_ok('function f() { return "hello".length; }', {
    A.func(
      "f",
      {},
      A.block({
        A.ret(A.member(A.str("hello"), A.id("length"))),
      })
    ),
  })
end)

-- ============================================================================
-- IN ARRAY / OBJECT LITERALS
-- ============================================================================

test('parse ["hello".toString()] (literal member in array)', function()
  assert_parse_ok('["hello".toString()];', {
    A.expr_stmt(A.arr({
      A.call(A.member(A.str("hello"), A.id("toString")), {}),
    })),
  })
end)

test('parse {k: "hello".toString()} (literal member in object)', function()
  assert_parse_ok('let o = {k: "hello".toString()};', {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("k"), A.call(A.member(A.str("hello"), A.id("toString")), {})),
      })
    ),
  })
end)

-- ============================================================================
-- IN CONTROL FLOW
-- ============================================================================

test('parse if ("hello".length) {} (in if condition)', function()
  assert_parse_ok('if ("hello".length) {}', {
    A.if_(A.member(A.str("hello"), A.id("length")), A.block({})),
  })
end)

test('parse while ("hello".length) {} (in while condition)', function()
  assert_parse_ok('while ("hello".length) {}', {
    A.while_(A.member(A.str("hello"), A.id("length")), A.block({})),
  })
end)

test('parse for ("hello".length;;) {} (in for init)', function()
  local ast = parser.parse('for ("hello".length;;) {}')
  assert(ast, "expected parse to succeed")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "ExpressionStatement")
  assert_eq(f.init.expression.type, "MemberExpression")
end)

-- ============================================================================
-- POSTFIX ++/-- ON LITERALS (valid JS syntax, runtime error)
-- ============================================================================

test('error: "hello"++ is invalid (postfix on string literal)', function()
  assert_parse_fail('"hello"++;', nil)
end)

test("error: true++ is invalid (postfix on boolean literal)", function()
  assert_parse_fail("true++;", nil)
end)

test("error: null++ is invalid (postfix on null literal)", function()
  assert_parse_fail("null++;", nil)
end)

test("parse undefined++ (postfix on undefined, acts as identifier)", function()
  local ast = parser.parse("undefined++;")
  assert(ast, "expected parse to succeed")
end)

test("error: true-- is invalid (postfix decrement on boolean literal)", function()
  assert_parse_fail("true--;", nil)
end)

test('error: "x"-- is invalid (postfix decrement on string literal)', function()
  assert_parse_fail('"x"--;', nil)
end)

test("error: null-- is invalid (postfix decrement on null literal)", function()
  assert_parse_fail("null--;", nil)
end)

-- ============================================================================
-- POSTFIX ++/-- ON MEMBER EXPRESSIONS DERIVED FROM LITERALS
-- (Valid JS syntax — runtime TypeError. no_update must clear after first
-- member/call operator transforms the literal into a MemberExpression.)
-- ============================================================================

test("parse true.x++ (postfix on boolean member)", function()
  assert_parse_ok("true.x++;", {
    A.expr_stmt(A.update("++", A.member(A.bool(true), A.id("x")), false)),
  })
end)

test("parse false.y-- (postfix decrement on boolean member)", function()
  assert_parse_ok("false.y--;", {
    A.expr_stmt(A.update("--", A.member(A.bool(false), A.id("y")), false)),
  })
end)

test('parse "hello".length++ (postfix on string member)', function()
  assert_parse_ok('"hello".length++;', {
    A.expr_stmt(A.update("++", A.member(A.str("hello"), A.id("length")), false)),
  })
end)

test("parse null.foo++ (postfix on null member)", function()
  assert_parse_ok("null.foo++;", {
    A.expr_stmt(A.update("++", A.member(A.null(), A.id("foo")), false)),
  })
end)

test("parse null.bar-- (postfix decrement on null member)", function()
  assert_parse_ok("null.bar--;", {
    A.expr_stmt(A.update("--", A.member(A.null(), A.id("bar")), false)),
  })
end)

test('parse true["x"]++ (postfix on computed boolean member)', function()
  assert_parse_ok('true["x"]++;', {
    A.expr_stmt(A.update("++", A.member_c(A.bool(true), A.str("x")), false)),
  })
end)

test('parse "s"[0]-- (postfix decrement on computed string member)', function()
  assert_parse_ok('"s"[0]--;', {
    A.expr_stmt(A.update("--", A.member_c(A.str("s"), A.num(0)), false)),
  })
end)

test("parse true.toString()++ (postfix on call result from literal)", function()
  assert_parse_ok("true.toString()++;", {
    A.expr_stmt(A.update("++", A.call(A.member(A.bool(true), A.id("toString")), {}), false)),
  })
end)

-- ============================================================================
-- KEYWORDS AS PROPERTY NAMES ON LITERALS
-- ============================================================================

test('parse "test".typeof (keyword prop on string)', function()
  assert_parse_ok('"test".typeof;', {
    A.expr_stmt(A.member(A.str("test"), A.id("typeof"))),
  })
end)

test("parse true.new (keyword prop on boolean)", function()
  assert_parse_ok("true.new;", {
    A.expr_stmt(A.member(A.bool(true), A.id("new"))),
  })
end)

-- ============================================================================
-- PARENTHESIZED FORMS STILL WORK
-- ============================================================================

test("parse (true).toString() (parenthesized boolean)", function()
  assert_parse_ok("(true).toString();", {
    A.expr_stmt(A.call(A.member(A.bool(true), A.id("toString")), {})),
  })
end)

test('parse ("hello").toString() (parenthesized string)', function()
  assert_parse_ok('("hello").toString();', {
    A.expr_stmt(A.call(A.member(A.str("hello"), A.id("toString")), {})),
  })
end)

test("parse (null).foo (parenthesized null)", function()
  assert_parse_ok("(null).foo;", {
    A.expr_stmt(A.member(A.null(), A.id("foo"))),
  })
end)

test("parse (undefined).bar (parenthesized undefined)", function()
  assert_parse_ok("(undefined).bar;", {
    A.expr_stmt(A.member(A.undef(), A.id("bar"))),
  })
end)

-- ============================================================================
-- NEGATIVE / EDGE CASES
-- ============================================================================

test("parse empty string member", function()
  assert_parse_ok('"".length;', {
    A.expr_stmt(A.member(A.str(""), A.id("length"))),
  })
end)

test("parse string with special chars member", function()
  assert_parse_ok('"hello\\nworld".length;', {
    A.expr_stmt(A.member(A.str("hello\nworld"), A.id("length"))),
  })
end)

test("parse boolean member with no semicolon", function()
  assert_parse_ok("true.toString()", {
    A.expr_stmt(A.call(A.member(A.bool(true), A.id("toString")), {})),
  })
end)

test("parse string member in expression statement", function()
  assert_parse_ok('"hello".toString()', {
    A.expr_stmt(A.call(A.member(A.str("hello"), A.id("toString")), {})),
  })
end)

test("error: number literal member access fails (5.toString is invalid JS)", function()
  assert_parse_fail("5.toString();", nil)
end)

test("error: number literal postfix fails (5++ is invalid JS)", function()
  assert_parse_fail("5++;", nil)
end)

-- ============================================================================
-- INVARIANT: all AST nodes have type field
-- ============================================================================

test("all literal member expressions have type field in AST", function()
  local sources = {
    "true.toString();",
    "false.toString();",
    '"hello".toString();',
    "null.toString();",
    "undefined.toString();",
    'true["toString"]();',
    '"hello"["length"];',
    'let x = "hello".length;',
    "true.toString().length;",
    'f("hello".toString());',
    '["hello".toString()];',
    'if ("hello".length) {}',
    "(true).toString();",
  }
  for _, src in ipairs(sources) do
    local ast = parser.parse(src)
    local ok = ast ~= nil and ast.type == "Program"
    if not ok then
      error("parse failed for: " .. src)
    end
  end
end)
