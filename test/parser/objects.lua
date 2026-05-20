local T = require("ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test = T.test
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

-- ============================================================================
-- Method shorthand
-- ============================================================================

test("method shorthand: no params", function()
  assert_parse_ok("let o = { foo() {} };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("foo"), A.func_expr("foo", {}, A.block({}))),
      })
    ),
  })
end)

test("method shorthand: one param", function()
  assert_parse_ok("let o = { greet(name) { return name; } };", {
    A.let(
      "o",
      A.obj({
        A.prop(
          A.id("greet"),
          A.func_expr(
            "greet",
            A.ids("name"),
            A.block({
              A.ret(A.id("name")),
            })
          )
        ),
      })
    ),
  })
end)

test("method shorthand: multiple params", function()
  assert_parse_ok("let o = { add(a, b) { return a + b; } };", {
    A.let(
      "o",
      A.obj({
        A.prop(
          A.id("add"),
          A.func_expr(
            "add",
            A.ids("a", "b"),
            A.block({
              A.ret(A.bin("+", A.id("a"), A.id("b"))),
            })
          )
        ),
      })
    ),
  })
end)

test("method shorthand: complex body", function()
  assert_parse_ok("let o = { calc(n) { let x = n * 2; return x; } };", {
    A.let(
      "o",
      A.obj({
        A.prop(
          A.id("calc"),
          A.func_expr(
            "calc",
            A.ids("n"),
            A.block({
              A.let("x", A.bin("*", A.id("n"), A.num(2))),
              A.ret(A.id("x")),
            })
          )
        ),
      })
    ),
  })
end)

test("method shorthand: multiple methods", function()
  assert_parse_ok("let o = { a() {}, b(x) {} };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("a"), A.func_expr("a", {}, A.block({}))),
        A.prop(A.id("b"), A.func_expr("b", A.ids("x"), A.block({}))),
      })
    ),
  })
end)

test("method shorthand: mixed with regular properties", function()
  assert_parse_ok("let o = { x: 1, foo() { return 2; }, y: 3 };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("x"), A.num(1)),
        A.prop(
          A.id("foo"),
          A.func_expr(
            "foo",
            {},
            A.block({
              A.ret(A.num(2)),
            })
          )
        ),
        A.prop(A.id("y"), A.num(3)),
      })
    ),
  })
end)

test("method shorthand: trailing comma", function()
  assert_parse_ok("let o = { foo() {}, };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("foo"), A.func_expr("foo", {}, A.block({}))),
      })
    ),
  })
end)

test("method shorthand: method with arrow function value", function()
  assert_parse_ok("let o = { a: 1, go(x) { return x; } };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("a"), A.num(1)),
        A.prop(
          A.id("go"),
          A.func_expr(
            "go",
            A.ids("x"),
            A.block({
              A.ret(A.id("x")),
            })
          )
        ),
      })
    ),
  })
end)

-- ============================================================================
-- Shorthand properties: { x } means { x: x }
-- ============================================================================

test("shorthand property: single", function()
  assert_parse_ok("let o = { x };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("x"), A.id("x")),
      })
    ),
  })
end)

test("shorthand property: multiple", function()
  assert_parse_ok("let o = { x, y };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("x"), A.id("x")),
        A.prop(A.id("y"), A.id("y")),
      })
    ),
  })
end)

test("shorthand property: mixed with regular", function()
  assert_parse_ok("let o = { a: 1, b, c: 3 };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("a"), A.num(1)),
        A.prop(A.id("b"), A.id("b")),
        A.prop(A.id("c"), A.num(3)),
      })
    ),
  })
end)

test("shorthand property: trailing comma", function()
  assert_parse_ok("let o = { x, };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("x"), A.id("x")),
      })
    ),
  })
end)

test("shorthand property: mixed with method shorthand", function()
  assert_parse_ok("let o = { x, foo() {} };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("x"), A.id("x")),
        A.prop(A.id("foo"), A.func_expr("foo", {}, A.block({}))),
      })
    ),
  })
end)

test("shorthand property: all three forms combined", function()
  assert_parse_ok("let o = { a: 1, b, c() { return 3; } };", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("a"), A.num(1)),
        A.prop(A.id("b"), A.id("b")),
        A.prop(
          A.id("c"),
          A.func_expr(
            "c",
            {},
            A.block({
              A.ret(A.num(3)),
            })
          )
        ),
      })
    ),
  })
end)

-- ============================================================================
-- Negative cases — method shorthand
-- ============================================================================

test("method shorthand fails: string key with parens", function()
  assert_parse_fail('let o = {"foo"() {}};', nil)
end)

test("method shorthand fails: missing body", function()
  assert_parse_fail("let o = { foo() };", nil)
end)

test("method shorthand fails: missing closing paren", function()
  assert_parse_fail("let o = { foo( { };", nil)
end)

-- ============================================================================
-- Negative cases — shorthand properties
-- ============================================================================

test("shorthand property fails: string key without colon", function()
  assert_parse_fail('let o = {"x"};', nil)
end)

-- ============================================================================
-- Negative cases — existing regression
-- ============================================================================

test("regular key:value still works: identifier keys", function()
  assert_parse_ok("let o = {a: 1, b: 2};", {
    A.let(
      "o",
      A.obj({
        A.prop(A.id("a"), A.num(1)),
        A.prop(A.id("b"), A.num(2)),
      })
    ),
  })
end)

test("regular key:value still works: string keys", function()
  assert_parse_ok('let o = {"key": 1};', {
    A.let(
      "o",
      A.obj({
        A.prop(A.str("key"), A.num(1)),
      })
    ),
  })
end)

test("empty object still works", function()
  assert_parse_ok("let o = {};", {
    A.let("o", A.obj({})),
  })
end)

test("key:value with function expression still works", function()
  assert_parse_ok("let o = { a: function(x) { return x; } };", {
    A.let(
      "o",
      A.obj({
        A.prop(
          A.id("a"),
          A.func_expr(
            A.ids("x"),
            A.block({
              A.ret(A.id("x")),
            })
          )
        ),
      })
    ),
  })
end)

T.summary()
