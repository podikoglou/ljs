local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local ljs = require("ljs.parser")
local A = require("test.helpers.ast")
local test, assert_table_eq = T.test, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

test("parse NumberLiteral", function()
  assert_parse_ok("42;", { A.expr_stmt(A.num(42)) })
end)

test("parse hex literal 0xFF", function()
  assert_parse_ok("0xFF;", { A.expr_stmt(A.num(255)) })
end)

test("parse hex literal 0x1a", function()
  assert_parse_ok("0x1a;", { A.expr_stmt(A.num(26)) })
end)

test("parse hex literal 0X0F uppercase prefix", function()
  assert_parse_ok("0X0F;", { A.expr_stmt(A.num(15)) })
end)

test("parse hex literal 0x0", function()
  assert_parse_ok("0x0;", { A.expr_stmt(A.num(0)) })
end)

test("parse error: hex literal with no digits after 0x", function()
  assert_parse_fail("0x;", "hex")
end)

test("parse hex in variable", function()
  assert_parse_ok("let x = 0xFF;", { A.let("x", A.num(255)) })
end)

test("parse StringLiteral", function()
  assert_parse_ok('"hello";', { A.expr_stmt(A.str("hello")) })
end)

test("parse BooleanLiteral true", function()
  assert_parse_ok("true;", { A.expr_stmt(A.bool(true)) })
end)

test("parse BooleanLiteral false", function()
  assert_parse_ok("false;", { A.expr_stmt(A.bool(false)) })
end)

test("parse NullLiteral", function()
  assert_parse_ok("null;", { A.expr_stmt(A.null()) })
end)

test("parse UndefinedLiteral", function()
  assert_parse_ok("undefined;", { A.expr_stmt(A.undef()) })
end)

test("parse Identifier expression", function()
  assert_parse_ok("x;", { A.expr_stmt(A.id("x")) })
end)

test("parse BinaryExpression +", function()
  assert_parse_ok("1 + 2;", { A.expr_stmt(A.bin("+", A.num(1), A.num(2))) })
end)

test("parse BinaryExpression all operators", function()
  local ops = {
    { "1 - 2;", "-" },
    { "3 * 4;", "*" },
    { "6 / 2;", "/" },
    { "5 % 2;", "%" },
    { "1 === 2;", "===" },
    { "1 !== 2;", "!==" },
    { "1 < 2;", "<" },
    { "1 > 2;", ">" },
    { "1 <= 2;", "<=" },
    { "1 >= 2;", ">=" },
    { "true && false;", "&&" },
    { "true || false;", "||" },
    { "2 ** 3;", "**" },
  }
  for _, tc in ipairs(ops) do
    local ast = ljs.parse(tc[1])
    assert(ast)
    assert_table_eq(ast.body[1].expression.operator, tc[2], "operator for " .. tc[1])
  end
end)

test("parse BinaryExpression **", function()
  assert_parse_ok("2 ** 3;", { A.expr_stmt(A.bin("**", A.num(2), A.num(3))) })
end)

test("parse ** with variable operands", function()
  assert_parse_ok("x ** y;", { A.expr_stmt(A.bin("**", A.id("x"), A.id("y"))) })
end)

test("parse ** right-associative: 2 ** 3 ** 4", function()
  assert_parse_ok("2 ** 3 ** 4;", {
    A.expr_stmt(A.bin("**", A.num(2), A.bin("**", A.num(3), A.num(4)))),
  })
end)

test("parse ** right-associative three-deep", function()
  assert_parse_ok("a ** b ** c ** d;", {
    A.expr_stmt(A.bin("**", A.id("a"), A.bin("**", A.id("b"), A.bin("**", A.id("c"), A.id("d"))))),
  })
end)

test("parse compound **=", function()
  assert_parse_ok("x **= 2;", { A.expr_stmt(A.bin("**=", A.id("x"), A.num(2))) })
end)

test("parse **= on member expression", function()
  assert_parse_ok("obj.x **= 2;", {
    A.expr_stmt(A.bin("**=", A.member(A.id("obj"), A.id("x")), A.num(2))),
  })
end)

test("parse **= on computed member", function()
  assert_parse_ok("arr[i] **= 2;", {
    A.expr_stmt(A.bin("**=", A.member_c(A.id("arr"), A.id("i")), A.num(2))),
  })
end)

test("parse **= right-associative: x **= y **= 2", function()
  assert_parse_ok("x **= y **= 2;", {
    A.expr_stmt(A.bin("**=", A.id("x"), A.bin("**=", A.id("y"), A.num(2)))),
  })
end)

-- INVARIANT: ** binds tighter than all lower-precedence binary operators.
-- Contract: exponentiation (precedence 5.5) is higher than *, /, %, +, -,
-- <<, >>, >>>, ===, !==, <, >, <=, >=, &, ^, |, &&, ||.
-- Tests both nesting directions for each operator:
--   a OP b ** c  →  a OP (b ** c)   (** absorbs right operand first)
--   a ** b OP c  →  (a ** b) OP c   (** absorbs left operand first)
-- Catches: any regression in PRECEDENCE table that would lower ** below other ops.
-- Replaces 8 individual example-based tests that each verified only one operator
-- in one direction, covering only 7 of 17 operators.
test("precedence: ** binds tighter than all binary operators (both directions)", function()
  local ops = {
    "*",
    "/",
    "%",
    "+",
    "-",
    "<<",
    ">>",
    ">>>",
    "===",
    "!==",
    "<",
    ">",
    "<=",
    ">=",
    "&",
    "^",
    "|",
    "&&",
    "||",
  }
  for _, op in ipairs(ops) do
    local src_r = string.format("a %s b ** c;", op)
    local ast_r = ljs.parse(src_r)
    assert(ast_r, "expected parse for: " .. src_r)
    local expr_r = ast_r.body[1].expression
    assert_table_eq(expr_r.operator, op, "outer op for: " .. src_r)
    assert_table_eq(expr_r.right.type, "BinaryExpression", "right child type for: " .. src_r)
    assert_table_eq(expr_r.right.operator, "**", "right child op for: " .. src_r)

    local src_l = string.format("a ** b %s c;", op)
    local ast_l = ljs.parse(src_l)
    assert(ast_l, "expected parse for: " .. src_l)
    local expr_l = ast_l.body[1].expression
    assert_table_eq(expr_l.operator, op, "outer op for: " .. src_l)
    assert_table_eq(expr_l.left.type, "BinaryExpression", "left child type for: " .. src_l)
    assert_table_eq(expr_l.left.operator, "**", "left child op for: " .. src_l)
  end
end)

test("parse -2 ** 3 (unary minus before **)", function()
  assert_parse_ok("-2 ** 3;", {
    A.expr_stmt(A.bin("**", A.una("-", A.num(2)), A.num(3))),
  })
end)

test("parse !a ** b (unary not before **)", function()
  assert_parse_ok("!a ** b;", {
    A.expr_stmt(A.bin("**", A.una("!", A.id("a")), A.id("b"))),
  })
end)

test("parse +a ** b (unary plus before **)", function()
  assert_parse_ok("+a ** b;", {
    A.expr_stmt(A.bin("**", A.una("+", A.id("a")), A.id("b"))),
  })
end)

test("parse ~a ** b (bitwise not before **)", function()
  assert_parse_ok("~a ** b;", {
    A.expr_stmt(A.bin("**", A.una("~", A.id("a")), A.id("b"))),
  })
end)

test("parse -(2 ** 3) (parens override unary)", function()
  assert_parse_ok("-(2 ** 3);", {
    A.expr_stmt(A.una("-", A.bin("**", A.num(2), A.num(3)))),
  })
end)

test("parse 2 ** -3 (unary in exponent)", function()
  assert_parse_ok("2 ** -3;", {
    A.expr_stmt(A.bin("**", A.num(2), A.una("-", A.num(3)))),
  })
end)

test("parse ++x ** 2 (prefix increment before **)", function()
  assert_parse_ok("++x ** 2;", {
    A.expr_stmt(A.bin("**", A.update("++", A.id("x"), true), A.num(2))),
  })
end)

test("parse x++ ** 2 (postfix before **)", function()
  assert_parse_ok("x++ ** 2;", {
    A.expr_stmt(A.bin("**", A.update("++", A.id("x"), false), A.num(2))),
  })
end)

test("parse 2 ** x++ (postfix in exponent)", function()
  assert_parse_ok("2 ** x++;", {
    A.expr_stmt(A.bin("**", A.num(2), A.update("++", A.id("x"), false))),
  })
end)

test("parse ** in assignment RHS", function()
  assert_parse_ok("x = 2 ** 3;", {
    A.expr_stmt(A.bin("=", A.id("x"), A.bin("**", A.num(2), A.num(3)))),
  })
end)

test("parse ** in ternary test", function()
  assert_parse_ok("a ** b ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.bin("**", A.id("a"), A.id("b")), A.num(1), A.num(0))),
  })
end)

test("parse ** in ternary branch", function()
  assert_parse_ok("c ? 2 ** 3 : 4;", {
    A.expr_stmt(A.ternary(A.id("c"), A.bin("**", A.num(2), A.num(3)), A.num(4))),
  })
end)

test("parse **= with + on RHS", function()
  assert_parse_ok("x **= 1 + 2;", {
    A.expr_stmt(A.bin("**=", A.id("x"), A.bin("+", A.num(1), A.num(2)))),
  })
end)

test("parse (x + 1) ** 2 (complex base)", function()
  assert_parse_ok("(x + 1) ** 2;", {
    A.expr_stmt(A.bin("**", A.bin("+", A.id("x"), A.num(1)), A.num(2))),
  })
end)

test("parse 2 ** (x + 1) (complex exponent)", function()
  assert_parse_ok("2 ** (x + 1);", {
    A.expr_stmt(A.bin("**", A.num(2), A.bin("+", A.id("x"), A.num(1)))),
  })
end)

test("parse UnaryExpression !", function()
  assert_parse_ok("!x;", { A.expr_stmt(A.una("!", A.id("x"))) })
end)

test("parse UnaryExpression -", function()
  assert_parse_ok("-x;", { A.expr_stmt(A.una("-", A.id("x"))) })
end)

test("parse UnaryExpression +", function()
  assert_parse_ok("+x;", { A.expr_stmt(A.una("+", A.id("x"))) })
end)

test("parse unary + on literal", function()
  assert_parse_ok("+42;", { A.expr_stmt(A.una("+", A.num(42))) })
end)

test("parse unary + on string", function()
  assert_parse_ok('+"5";', { A.expr_stmt(A.una("+", A.str("5"))) })
end)

test("parse nested unary +!x", function()
  assert_parse_ok("+!x;", { A.expr_stmt(A.una("+", A.una("!", A.id("x")))) })
end)

test("parse nested unary !+x", function()
  assert_parse_ok("!+x;", { A.expr_stmt(A.una("!", A.una("+", A.id("x")))) })
end)

test("parse + + x (space-separated double unary plus)", function()
  assert_parse_ok("+ + x;", { A.expr_stmt(A.una("+", A.una("+", A.id("x")))) })
end)

test("parse unary + in binary context", function()
  assert_parse_ok("1 + +x;", {
    A.expr_stmt(A.bin("+", A.num(1), A.una("+", A.id("x")))),
  })
end)

test("parse unary + in ternary", function()
  assert_parse_ok("a ? +b : -c;", {
    A.expr_stmt(A.ternary(A.id("a"), A.una("+", A.id("b")), A.una("-", A.id("c")))),
  })
end)

test("parse ++x still parsed as UpdateExpression (not double unary +)", function()
  assert_parse_ok("++x;", { A.expr_stmt(A.update("++", A.id("x"), true)) })
end)

test("error: unary + with no operand", function()
  assert_parse_fail("let a = +;", nil)
end)

test("error: unary + at end of input", function()
  assert_parse_fail("+", nil)
end)

test("parse prefix ++x", function()
  assert_parse_ok("++x;", { A.expr_stmt(A.update("++", A.id("x"), true)) })
end)

test("parse prefix --x", function()
  assert_parse_ok("--x;", { A.expr_stmt(A.update("--", A.id("x"), true)) })
end)

test("parse nested prefix ++ ++ x", function()
  assert_parse_ok("++ ++ x;", {
    A.expr_stmt(A.update("++", A.update("++", A.id("x"), true), true)),
  })
end)

test("parse prefix ++ on member expression", function()
  assert_parse_ok("++a.b;", {
    A.expr_stmt(A.update("++", A.member(A.id("a"), A.id("b")), true)),
  })
end)

test("parse prefix -- on computed member", function()
  assert_parse_ok("--a[b];", {
    A.expr_stmt(A.update("--", A.member_c(A.id("a"), A.id("b")), true)),
  })
end)

test("parse prefix ++ on chained member a.b.c", function()
  assert_parse_ok("++a.b.c;", {
    A.expr_stmt(A.update("++", A.member(A.member(A.id("a"), A.id("b")), A.id("c")), true)),
  })
end)

test("parse !++x (unary NOT then prefix)", function()
  assert_parse_ok("!++x;", {
    A.expr_stmt(A.una("!", A.update("++", A.id("x"), true))),
  })
end)

test("parse --x as return value", function()
  assert_parse_ok("function f() { return --x; }", {
    A.func("f", {}, A.block({ A.ret(A.update("--", A.id("x"), true)) })),
  })
end)

test("parse postfix x++", function()
  assert_parse_ok("x++;", { A.expr_stmt(A.update("++", A.id("x"), false)) })
end)

test("parse postfix x--", function()
  assert_parse_ok("x--;", { A.expr_stmt(A.update("--", A.id("x"), false)) })
end)

test("parse postfix on member a.b++", function()
  assert_parse_ok("a.b++;", {
    A.expr_stmt(A.update("++", A.member(A.id("a"), A.id("b")), false)),
  })
end)

test("parse postfix on computed member a[b]--", function()
  assert_parse_ok("a[b]--;", {
    A.expr_stmt(A.update("--", A.member_c(A.id("a"), A.id("b")), false)),
  })
end)

test("parse postfix on call f()++", function()
  assert_parse_ok("f()++;", {
    A.expr_stmt(A.update("++", A.call(A.id("f"), {}), false)),
  })
end)

test("parse postfix on chained member a.b.c++", function()
  assert_parse_ok("a.b.c++;", {
    A.expr_stmt(A.update("++", A.member(A.member(A.id("a"), A.id("b")), A.id("c")), false)),
  })
end)

test("parse postfix on chained call+member", function()
  assert_parse_ok("obj.method()++;", {
    A.expr_stmt(A.update("++", A.call(A.member(A.id("obj"), A.id("method")), {}), false)),
  })
end)

test("parse x++ + y (postfix in binary)", function()
  assert_parse_ok("x++ + y;", {
    A.expr_stmt(A.bin("+", A.update("++", A.id("x"), false), A.id("y"))),
  })
end)

test("parse x + ++y (prefix in binary)", function()
  assert_parse_ok("x + ++y;", {
    A.expr_stmt(A.bin("+", A.id("x"), A.update("++", A.id("y"), true))),
  })
end)

test("parse x++ + ++y (both sides)", function()
  assert_parse_ok("x++ + ++y;", {
    A.expr_stmt(A.bin("+", A.update("++", A.id("x"), false), A.update("++", A.id("y"), true))),
  })
end)

test("parse x+++y maximal munch: (x++) + y", function()
  assert_parse_ok("x+++y;", {
    A.expr_stmt(A.bin("+", A.update("++", A.id("x"), false), A.id("y"))),
  })
end)

test("parse x---y maximal munch: (x--) - y", function()
  assert_parse_ok("x---y;", {
    A.expr_stmt(A.bin("-", A.update("--", A.id("x"), false), A.id("y"))),
  })
end)

test("parse a + b++ * c (postfix binds tighter)", function()
  assert_parse_ok("a + b++ * c;", {
    A.expr_stmt(A.bin("+", A.id("a"), A.bin("*", A.update("++", A.id("b"), false), A.id("c")))),
  })
end)

test("parse -x++ (unary minus on postfix)", function()
  assert_parse_ok("-x++;", {
    A.expr_stmt(A.una("-", A.update("++", A.id("x"), false))),
  })
end)
