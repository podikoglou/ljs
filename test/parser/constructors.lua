local T = require("ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test = T.test
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

-- ============================================================================
-- new expression
-- ============================================================================

test("new Foo() — simple constructor call", function()
  assert_parse_ok("new Foo();", {
    A.expr_stmt(A.new_expr(A.id("Foo"), {})),
  })
end)

test("new Foo — no parens", function()
  assert_parse_ok("new Foo;", {
    A.expr_stmt(A.new_expr(A.id("Foo"), {})),
  })
end)

test("new Foo(a, b) — constructor with args", function()
  assert_parse_ok("new Foo(a, b);", {
    A.expr_stmt(A.new_expr(A.id("Foo"), { A.id("a"), A.id("b") })),
  })
end)

test("new Foo.bar() — member expression callee", function()
  assert_parse_ok("new Foo.bar();", {
    A.expr_stmt(A.new_expr(A.member(A.id("Foo"), A.id("bar")), {})),
  })
end)

test("new Foo.bar — member expression callee, no parens", function()
  assert_parse_ok("new Foo.bar;", {
    A.expr_stmt(A.new_expr(A.member(A.id("Foo"), A.id("bar")), {})),
  })
end)

test("new Foo().bar — postfix after new", function()
  assert_parse_ok("new Foo().bar;", {
    A.expr_stmt(A.member(A.new_expr(A.id("Foo"), {}), A.id("bar"))),
  })
end)

test("new Foo()() — call on new result", function()
  assert_parse_ok("new Foo()();", {
    A.expr_stmt(A.call(A.new_expr(A.id("Foo"), {}), {})),
  })
end)

test("new Foo.bar.baz() — chained member callee", function()
  assert_parse_ok("new Foo.bar.baz();", {
    A.expr_stmt(A.new_expr(A.member(A.member(A.id("Foo"), A.id("bar")), A.id("baz")), {})),
  })
end)

test("new Foo[0]() — computed member callee", function()
  assert_parse_ok("new Foo[0]();", {
    A.expr_stmt(A.new_expr(A.member_c(A.id("Foo"), A.num(0)), {})),
  })
end)

test("new Foo.bar(a).baz — member after new with args", function()
  assert_parse_ok("new Foo.bar(a).baz;", {
    A.expr_stmt(
      A.member(A.new_expr(A.member(A.id("Foo"), A.id("bar")), { A.id("a") }), A.id("baz"))
    ),
  })
end)

-- ============================================================================
-- instanceof
-- ============================================================================

test("x instanceof Foo — binary expression", function()
  assert_parse_ok("x instanceof Foo;", {
    A.expr_stmt(A.bin("instanceof", A.id("x"), A.id("Foo"))),
  })
end)

test("x instanceof Foo && y — precedence", function()
  assert_parse_ok("x instanceof Foo && y;", {
    A.expr_stmt(A.bin("&&", A.bin("instanceof", A.id("x"), A.id("Foo")), A.id("y"))),
  })
end)

test("x instanceof Foo === true — precedence with ===", function()
  assert_parse_ok("x instanceof Foo === true;", {
    A.expr_stmt(A.bin("===", A.bin("instanceof", A.id("x"), A.id("Foo")), A.bool(true))),
  })
end)

test("instanceof in for-loop init is allowed (not suppressed like 'in')", function()
  assert_parse_ok("for (let i = x instanceof Foo; i; i) { break; }", {
    A.for_(
      A.let("i", A.bin("instanceof", A.id("x"), A.id("Foo"))),
      A.id("i"),
      A.id("i"),
      A.block({ A.break_() })
    ),
  })
end)

-- ============================================================================
-- combination: new + instanceof
-- ============================================================================

test("new Foo() instanceof Bar", function()
  assert_parse_ok("new Foo() instanceof Bar;", {
    A.expr_stmt(A.bin("instanceof", A.new_expr(A.id("Foo"), {}), A.id("Bar"))),
  })
end)

-- ============================================================================
-- parse errors
-- ============================================================================

test("new without identifier — error", function()
  assert_parse_fail("new 42;", "Expected Identifier")
end)

T.summary()
