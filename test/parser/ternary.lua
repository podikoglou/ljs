local T = require("ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs

test("tokenize ?", function()
  assert_tok("x ? 1 : 0", 2, "?")
end)

test("parse basic ternary", function()
  assert_parse_ok("x ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.id("x"), A.num(1), A.num(0))),
  })
end)

test("parse nested ternary in consequent", function()
  assert_parse_ok("a ? b ? 1 : 2 : 3;", {
    A.expr_stmt(A.ternary(A.id("a"), A.ternary(A.id("b"), A.num(1), A.num(2)), A.num(3))),
  })
end)

test("parse nested ternary in alternate", function()
  assert_parse_ok("a ? 1 : b ? 2 : 3;", {
    A.expr_stmt(A.ternary(A.id("a"), A.num(1), A.ternary(A.id("b"), A.num(2), A.num(3)))),
  })
end)

test("parse ternary precedence: || binds tighter than ?", function()
  assert_parse_ok("a || b ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.bin("||", A.id("a"), A.id("b")), A.num(1), A.num(0))),
  })
end)

test("parse ternary precedence: && binds tighter than ?", function()
  assert_parse_ok("a && b ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.bin("&&", A.id("a"), A.id("b")), A.num(1), A.num(0))),
  })
end)

test("parse ternary precedence: || inside consequent", function()
  assert_parse_ok("a ? b || c : d;", {
    A.expr_stmt(A.ternary(A.id("a"), A.bin("||", A.id("b"), A.id("c")), A.id("d"))),
  })
end)

test("parse ternary precedence: assignment has lower precedence", function()
  assert_parse_ok("x = a ? 1 : 0;", {
    A.expr_stmt(A.bin("=", A.id("x"), A.ternary(A.id("a"), A.num(1), A.num(0)))),
  })
end)

test("parse ternary with assignment in consequent", function()
  assert_parse_ok("a ? x = 1 : 0;", {
    A.expr_stmt(A.ternary(A.id("a"), A.bin("=", A.id("x"), A.num(1)), A.num(0))),
  })
end)

test("parse ternary with assignment in alternate", function()
  assert_parse_ok("a ? 1 : x = 0;", {
    A.expr_stmt(A.ternary(A.id("a"), A.num(1), A.bin("=", A.id("x"), A.num(0)))),
  })
end)

test("parse ternary in variable init", function()
  assert_parse_ok("let x = a ? 1 : 0;", {
    A.let("x", A.ternary(A.id("a"), A.num(1), A.num(0))),
  })
end)

test("parse ternary in return", function()
  local ast = ljs.parse("function f(x) { return x ? 1 : 0; }")
  assert(ast)
  local ret = ast.body[1].body.body[1]
  assert_eq(ret.type, "ReturnStatement")
  assert_eq(ret.argument.type, "ConditionalExpression")
  assert_eq(ret.argument.test.name, "x")
  assert_eq(ret.argument.consequent.value, 1)
  assert_eq(ret.argument.alternate.value, 0)
end)

test("parse ternary in function args", function()
  assert_parse_ok("f(x ? 1 : 0);", {
    A.expr_stmt(A.call(A.id("f"), { A.ternary(A.id("x"), A.num(1), A.num(0)) })),
  })
end)

test("parse ternary in object value", function()
  assert_parse_ok("let obj = {a: x ? 1 : 0};", {
    A.let("obj", A.obj({ A.prop(A.id("a"), A.ternary(A.id("x"), A.num(1), A.num(0))) })),
  })
end)

test("parse ternary in array element", function()
  assert_parse_ok("let arr = [x ? 1 : 0];", {
    A.let("arr", A.arr({ A.ternary(A.id("x"), A.num(1), A.num(0)) })),
  })
end)

test("parse ternary in for-loop init", function()
  local ast = ljs.parse("for (let i = x ? 0 : 1; i < 10; i += 1) {}")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.init.declarations[1].init.type, "ConditionalExpression")
  assert_eq(f.init.declarations[1].init.test.name, "x")
end)

test("parse ternary as expression statement", function()
  assert_parse_ok("x ? f() : g();", {
    A.expr_stmt(A.ternary(A.id("x"), A.call(A.id("f"), {}), A.call(A.id("g"), {}))),
  })
end)

test("parse ternary with member expressions", function()
  assert_parse_ok("a ? obj.x : arr[0];", {
    A.expr_stmt(
      A.ternary(A.id("a"), A.member(A.id("obj"), A.id("x")), A.member_c(A.id("arr"), A.num(0)))
    ),
  })
end)

test("parse ternary with unary", function()
  assert_parse_ok("a ? !b : -c;", {
    A.expr_stmt(A.ternary(A.id("a"), A.una("!", A.id("b")), A.una("-", A.id("c")))),
  })
end)

test("parse ternary with compound assignment in branches", function()
  assert_parse_ok("a ? x += 1 : x -= 1;", {
    A.expr_stmt(
      A.ternary(A.id("a"), A.bin("+=", A.id("x"), A.num(1)), A.bin("-=", A.id("x"), A.num(1)))
    ),
  })
end)

test("parse ternary with arithmetic in branches", function()
  assert_parse_ok("a + b ? c * d : e / f;", {
    A.expr_stmt(
      A.ternary(
        A.bin("+", A.id("a"), A.id("b")),
        A.bin("*", A.id("c"), A.id("d")),
        A.bin("/", A.id("e"), A.id("f"))
      )
    ),
  })
end)

test("parse parenthesized ternary condition", function()
  assert_parse_ok("(a || b) ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.bin("||", A.id("a"), A.id("b")), A.num(1), A.num(0))),
  })
end)

test("parse ternary with string and boolean branches", function()
  assert_parse_ok("x ? 'yes' : false;", {
    A.expr_stmt(A.ternary(A.id("x"), A.str("yes"), A.bool(false))),
  })
end)

test("parse ternary with null alternate", function()
  assert_parse_ok("x ? y : null;", {
    A.expr_stmt(A.ternary(A.id("x"), A.id("y"), A.null())),
  })
end)

test("parse ternary with undefined alternate", function()
  assert_parse_ok("x ? y : undefined;", {
    A.expr_stmt(A.ternary(A.id("x"), A.id("y"), A.undef())),
  })
end)

test("parse error: missing colon", function()
  assert_parse_fail("a ? 1", "Expected :")
end)

test("parse error: missing consequent", function()
  assert_parse_fail("a ?: b", nil)
end)

test("parse error: standalone question mark", function()
  assert_parse_fail("?", nil)
end)

test("parse error: trailing colon after ternary", function()
  assert_parse_fail("a ? 1 : 0 : extra", nil)
end)

test("parse error: missing alternate", function()
  assert_parse_fail("a ? 1 :", nil)
end)

test("CallExpression no args", function()
  assert_parse_ok("f();", {
    A.expr_stmt(A.call(A.id("f"), {})),
  })
end)

test("parse CallExpression with args", function()
  assert_parse_ok("f(a, b);", {
    A.expr_stmt(A.call(A.id("f"), { A.id("a"), A.id("b") })),
  })
end)

test("parse MemberExpression dot", function()
  assert_parse_ok("obj.prop;", {
    A.expr_stmt(A.member(A.id("obj"), A.id("prop"))),
  })
end)

test("parse MemberExpression bracket", function()
  assert_parse_ok("obj[prop];", {
    A.expr_stmt(A.member_c(A.id("obj"), A.id("prop"))),
  })
end)

test("parse chained calls: obj.method().another()", function()
  assert_parse_ok("obj.method().another();", {
    A.expr_stmt(
      A.call(A.member(A.call(A.member(A.id("obj"), A.id("method")), {}), A.id("another")), {})
    ),
  })
end)

test("parse chained members: a.b.c.d", function()
  assert_parse_ok("a.b.c.d;", {
    A.expr_stmt(A.member(A.member(A.member(A.id("a"), A.id("b")), A.id("c")), A.id("d"))),
  })
end)

test("parse ArrayExpression non-empty", function()
  assert_parse_ok("[1, 2, 3];", {
    A.expr_stmt(A.arr({ A.num(1), A.num(2), A.num(3) })),
  })
end)

test("parse ArrayExpression empty", function()
  assert_parse_ok("[];", {
    A.expr_stmt(A.arr({})),
  })
end)

test("parse ObjectExpression non-empty", function()
  assert_parse_ok("let o = {a: 1, b: 2};", {
    A.let("o", A.obj({ A.prop(A.id("a"), A.num(1)), A.prop(A.id("b"), A.num(2)) })),
  })
end)

test("parse ObjectExpression empty", function()
  assert_parse_ok("let o = {};", {
    A.let("o", A.obj({})),
  })
end)

test("parse anonymous FunctionExpression", function()
  assert_parse_ok("let f = function(x) { return x; };", {
    A.let("f", A.func_expr({ A.id("x") }, A.block({ A.ret(A.id("x")) }))),
  })
end)

test("parse named FunctionExpression", function()
  assert_parse_ok("let f = function fact(n) { return n; };", {
    A.let("f", A.func_expr("fact", { A.id("n") }, A.block({ A.ret(A.id("n")) }))),
  })
end)

test("parse arrow function: single param expression body", function()
  assert_parse_ok("x => x + 1;", {
    A.expr_stmt(A.arrow({ A.id("x") }, A.block({ A.ret(A.bin("+", A.id("x"), A.num(1))) }))),
  })
end)

test("parse arrow function: multi param", function()
  assert_parse_ok("(a, b) => a + b;", {
    A.expr_stmt(
      A.arrow({ A.id("a"), A.id("b") }, A.block({ A.ret(A.bin("+", A.id("a"), A.id("b"))) }))
    ),
  })
end)

test("parse arrow function: block body", function()
  assert_parse_ok("(x) => { return x; };", {
    A.expr_stmt(A.arrow({ A.id("x") }, A.block({ A.ret(A.id("x")) }))),
  })
end)

test("parse parenthesized expression", function()
  assert_parse_ok("(1 + 2);", {
    A.expr_stmt(A.bin("+", A.num(1), A.num(2))),
  })
end)

test("parse console.log", function()
  assert_parse_ok('console.log("hello");', {
    A.expr_stmt(A.call(A.member(A.id("console"), A.id("log")), { A.str("hello") })),
  })
end)

T.summary()
