local T = require("ljs_test")
local P = require("test.helpers.parser")
local ljs = require("ljs_parser")
local A = require("test.helpers.ast")
local test, assert_eq = T.test, T.assert_eq
local assert_tok, assert_parse_ok, assert_parse_fail =
  P.assert_tok, P.assert_parse_ok, P.assert_parse_fail

test("tokenize: 'do' not confused with identifier prefix", function()
  assert_tok("doSomething", 1, "Identifier", "doSomething")
end)

test("parse do...while basic with braces", function()
  assert_parse_ok("do { y; } while (x);", {
    A.do_while(A.block({ A.expr_stmt(A.id("y")) }), A.id("x")),
  })
end)

test("parse do...while without braces", function()
  assert_parse_ok("do y = y + 1; while (x < 10);", {
    A.do_while(
      A.expr_stmt(A.bin("=", A.id("y"), A.bin("+", A.id("y"), A.num(1)))),
      A.bin("<", A.id("x"), A.num(10))
    ),
  })
end)

test("parse do...while without trailing semicolon", function()
  local ast = ljs.parse("do { y; } while (x)")
  assert(ast)
  assert_eq(ast.body[1].type, "DoWhileStatement")
  assert_eq(ast.body[1].test.name, "x")
end)

test("parse do...while with trailing semicolon", function()
  local ast = ljs.parse("do { y; } while (x);")
  assert(ast)
  assert_eq(ast.body[1].type, "DoWhileStatement")
  assert_eq(#ast.body, 1)
end)

test("parse do...while with complex binary test", function()
  local ast = ljs.parse("do { y; } while (a + b > 0);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.test.operator, ">")
  assert_eq(dw.test.left.operator, "+")
end)

test("parse do...while with logical test", function()
  local ast = ljs.parse("do { y; } while (a && b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.test.operator, "&&")
end)

test("parse do...while with unary negation test", function()
  assert_parse_ok("do { y; } while (!done);", {
    A.do_while(A.block({ A.expr_stmt(A.id("y")) }), A.una("!", A.id("done"))),
  })
end)

test("parse do...while with strict inequality test", function()
  local ast = ljs.parse("do { y; } while (x !== 0);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.operator, "!==")
end)

test("parse do...while with call expression as test", function()
  local ast = ljs.parse("do { y; } while (shouldContinue());")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.type, "CallExpression")
  assert_eq(dw.test.callee.name, "shouldContinue")
end)

test("parse do...while with member expression as test", function()
  local ast = ljs.parse("do { y; } while (obj.active);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.type, "MemberExpression")
  assert_eq(dw.test.object.name, "obj")
  assert_eq(dw.test.property.name, "active")
end)

test("parse do...while with ternary as test", function()
  local ast = ljs.parse("do { y; } while (flag ? true : false);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.type, "ConditionalExpression")
  assert_eq(dw.test.test.name, "flag")
  assert_eq(dw.test.consequent.value, true)
  assert_eq(dw.test.alternate.value, false)
end)

test("parse do...while with number literal as test", function()
  local ast = ljs.parse("do { y; } while (1);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.type, "NumberLiteral")
  assert_eq(dw.test.value, 1)
end)

test("parse do...while body with multiple statements", function()
  local ast = ljs.parse("do { x = x + 1; y = y + 1; } while (x < 10);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.body.type, "BlockStatement")
  assert_eq(#dw.body.body, 2)
end)

test("parse do...while body is if statement", function()
  local ast = ljs.parse("do if (a) { x; } while (b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "IfStatement")
  assert_eq(dw.body.test.name, "a")
end)

test("parse do...while body is while loop", function()
  local ast = ljs.parse("do while (a) { x; } while (b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "WhileStatement")
  assert_eq(dw.body.test.name, "a")
end)

test("parse do...while body is another do...while", function()
  local ast = ljs.parse("do do { x; } while (a); while (b);")
  assert(ast)
  local outer = ast.body[1]
  assert_eq(outer.type, "DoWhileStatement")
  assert_eq(outer.test.name, "b")
  assert_eq(outer.body.type, "DoWhileStatement")
  assert_eq(outer.body.test.name, "a")
end)

test("parse do...while body is for loop", function()
  local ast = ljs.parse("do for (let i = 0; i < 5; i = i + 1) { x; } while (b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "ForStatement")
end)

test("parse do...while body is throw", function()
  local ast = ljs.parse("do throw e; while (false);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "ThrowStatement")
end)

test("parse do...while body is try/catch", function()
  local ast = ljs.parse("do try { x; } catch (e) { y; } while (b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "TryStatement")
end)

test("parse do...while body is variable declaration", function()
  local ast = ljs.parse("do let x = 1; while (b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "VariableDeclaration")
end)

test("parse do...while body is return", function()
  local ast = ljs.parse("do return x; while (b);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "ReturnStatement")
end)

test("parse do...while body is update expression", function()
  assert_parse_ok("do x++; while (y < 10);", {
    A.do_while(A.expr_stmt(A.update("++", A.id("x"), false)), A.bin("<", A.id("y"), A.num(10))),
  })
end)

test("parse do...while inside while", function()
  local ast = ljs.parse("while (a) { do { x; } while (b); }")
  assert(ast)
  local outer = ast.body[1]
  assert_eq(outer.type, "WhileStatement")
  assert_eq(outer.body.type, "BlockStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "DoWhileStatement")
  assert_eq(inner.test.name, "b")
end)

test("parse do...while inside if", function()
  local ast = ljs.parse("if (a) { do { x; } while (b); }")
  assert(ast)
  local ifs = ast.body[1]
  assert_eq(ifs.type, "IfStatement")
  local inner = ifs.consequent.body[1]
  assert_eq(inner.type, "DoWhileStatement")
end)

test("parse do...while inside for", function()
  local ast = ljs.parse("for (;;) { do { x; } while (b); }")
  assert(ast)
  local outer = ast.body[1]
  assert_eq(outer.type, "ForStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "DoWhileStatement")
end)

test("parse do...while inside function", function()
  local ast = ljs.parse("function f() { do { x; } while (b); }")
  assert(ast)
  local fn = ast.body[1]
  assert_eq(fn.type, "FunctionDeclaration")
  local inner = fn.body.body[1]
  assert_eq(inner.type, "DoWhileStatement")
end)

test("parse multiple do...while in sequence", function()
  local ast = ljs.parse("do { a; } while (x); do { b; } while (y);")
  assert(ast)
  assert_eq(#ast.body, 2)
  assert_eq(ast.body[1].type, "DoWhileStatement")
  assert_eq(ast.body[1].test.name, "x")
  assert_eq(ast.body[2].type, "DoWhileStatement")
  assert_eq(ast.body[2].test.name, "y")
end)

test("parse do...while with compound expression in body", function()
  local ast = ljs.parse("do { let x = 1; x; } while (true);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "BlockStatement")
  assert_eq(#dw.body.body, 2)
  assert_eq(dw.body.body[1].type, "VariableDeclaration")
  assert_eq(dw.test.value, true)
end)

test("parse do...while with assignment expression test", function()
  local ast = ljs.parse("do { x; } while (n = n - 1);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.type, "BinaryExpression")
  assert_eq(dw.test.operator, "=")
end)

test("parse do...while with compound assignment test", function()
  local ast = ljs.parse("do { x; } while (n -= 1);")
  assert(ast)
  local dw = ast.body[1]
  assert_eq(dw.test.operator, "-=")
end)

test("parse error: do...while missing while keyword", function()
  assert_parse_fail("do { x; }", "while")
end)

test("parse error: do...while missing parens around test", function()
  assert_parse_fail("do { x; } while x;", "Expected (")
end)

test("parse error: do...while missing test expression", function()
  assert_parse_fail("do { x; } while ();", "Unexpected token")
end)

test("parse error: do...while missing closing paren", function()
  assert_parse_fail("do { x; } while (y", ")")
end)

test("parse error: do...while missing body", function()
  assert_parse_fail("do while (y);", nil)
end)

test("parse error: do at EOF", function()
  assert_parse_fail("do", nil)
end)

test("parse error: do { at EOF", function()
  assert_parse_fail("do {", nil)
end)

test("parse error: do with closing brace without opening", function()
  assert_parse_fail("do } while (x);", nil)
end)

test("parse error: while without parens after do body", function()
  assert_parse_fail("do { x; } while;", "Expected (")
end)

test("parse error: do body block then while at EOF", function()
  assert_parse_fail("do { x; } while", nil)
end)

test("parse error: do inside object literal", function()
  assert_parse_fail("let o = { a: do { } while (x) };", nil)
end)

test("parse for...of", function()
  assert_parse_ok("for (let x of arr) { console.log(x); }", {
    A.for_of(
      A.var_decl("let", { A.declarator(A.id("x")) }),
      A.id("arr"),
      A.block({
        A.expr_stmt(A.call(A.member(A.id("console"), A.id("log")), { A.id("x") })),
      })
    ),
  })
end)
