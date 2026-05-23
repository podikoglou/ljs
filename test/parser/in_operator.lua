local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local parser = require("ljs.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

test("parse string in object", function()
  assert_parse_ok('"x" in obj;', {
    A.expr_stmt(A.bin("in", A.str("x"), A.id("obj"))),
  })
end)

test("parse variable in object", function()
  assert_parse_ok("key in obj;", {
    A.expr_stmt(A.bin("in", A.id("key"), A.id("obj"))),
  })
end)

test("parse number in array", function()
  assert_parse_ok("0 in arr;", {
    A.expr_stmt(A.bin("in", A.num(0), A.id("arr"))),
  })
end)

test("parse member expression as left operand", function()
  local ast = parser.parse("obj.key in obj2;")
  assert(ast)
  local expr = ast.body[1].expression
  assert_eq(expr.type, "BinaryExpression")
  assert_eq(expr.operator, "in")
  assert_eq(expr.left.type, "MemberExpression")
  assert_eq(expr.right.name, "obj2")
end)

test("parse member expression as right operand", function()
  local ast = parser.parse('"x" in obj.prop;')
  assert(ast)
  local expr = ast.body[1].expression
  assert_eq(expr.type, "BinaryExpression")
  assert_eq(expr.operator, "in")
  assert_eq(expr.right.type, "MemberExpression")
end)

test("parse object literal as right operand", function()
  local ast = parser.parse('"x" in {a: 1};')
  assert(ast)
  local expr = ast.body[1].expression
  assert_eq(expr.type, "BinaryExpression")
  assert_eq(expr.operator, "in")
  assert_eq(expr.right.type, "ObjectExpression")
end)

test("in at precedence 3 (same as ===), left-associative", function()
  assert_parse_ok('"x" in obj === true;', {
    A.expr_stmt(A.bin("===", A.bin("in", A.str("x"), A.id("obj")), A.bool(true))),
  })
end)

test("in + is left-associative: a in b in c", function()
  assert_parse_ok("a in b in c;", {
    A.expr_stmt(A.bin("in", A.bin("in", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("+ binds tighter than in", function()
  assert_parse_ok('1 + "x" in obj;', {
    A.expr_stmt(A.bin("in", A.bin("+", A.num(1), A.str("x")), A.id("obj"))),
  })
end)

test("in in && expression", function()
  assert_parse_ok('"x" in a && "y" in b;', {
    A.expr_stmt(
      A.bin("&&", A.bin("in", A.str("x"), A.id("a")), A.bin("in", A.str("y"), A.id("b")))
    ),
  })
end)

test("in in if condition", function()
  local ast = parser.parse('if ("x" in obj) { y; }')
  assert(ast)
  local if_stmt = ast.body[1]
  assert_eq(if_stmt.type, "IfStatement")
  assert_eq(if_stmt.test.type, "BinaryExpression")
  assert_eq(if_stmt.test.operator, "in")
end)

test("in in ternary", function()
  assert_parse_ok('"x" in obj ? 1 : 0;', {
    A.expr_stmt(A.ternary(A.bin("in", A.str("x"), A.id("obj")), A.num(1), A.num(0))),
  })
end)

test("in in variable init", function()
  assert_parse_ok('let has = "x" in obj;', {
    A.let("has", A.bin("in", A.str("x"), A.id("obj"))),
  })
end)

test("in negated", function()
  assert_parse_ok('!("x" in obj);', {
    A.expr_stmt(A.una("!", A.bin("in", A.str("x"), A.id("obj")))),
  })
end)

test("in in parenthesized expression", function()
  assert_parse_ok('("x" in obj);', {
    A.expr_stmt(A.bin("in", A.str("x"), A.id("obj"))),
  })
end)

test("in in while condition", function()
  local ast = parser.parse('while ("x" in obj) { break; }')
  assert(ast)
  assert_eq(ast.body[1].type, "WhileStatement")
  assert_eq(ast.body[1].test.operator, "in")
end)

test("in in return statement", function()
  local ast = parser.parse('function f() { return "x" in obj; }')
  assert(ast)
  local ret = ast.body[1].body.body[1]
  assert_eq(ret.type, "ReturnStatement")
  assert_eq(ret.argument.operator, "in")
end)

test("for (key in obj) is still ForInStatement", function()
  local ast = parser.parse("for (key in obj) { key; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "Identifier")
  assert_eq(f.left.name, "key")
  assert_eq(f.right.name, "obj")
end)

test("for (let key in obj) is still ForInStatement", function()
  local ast = parser.parse("for (let key in obj) { key; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "VariableDeclaration")
end)

test("for (const k in obj) is still ForInStatement", function()
  local ast = parser.parse("for (const k in obj) { k; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.kind, "const")
end)

test("for with in inside parens is C-style for", function()
  local ast = parser.parse('for (("x" in obj); ; ) { break; }')
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "ExpressionStatement")
  assert_eq(f.init.expression.operator, "in")
end)

test("for-in with multiple declarators still errors", function()
  assert_parse_fail("for (let x, y in obj) { }", "single variable")
end)

test("for-in with initializer still errors", function()
  assert_parse_fail("for (let x = 1 in obj) { }", "initializer")
end)

test("for-in with const and initializer still errors", function()
  assert_parse_fail("for (const x = 1 in obj) { }", "initializer")
end)

test("error: bare in keyword in expression position", function()
  assert_parse_fail("in;", nil)
end)

test("error: let in = 5 (in is keyword)", function()
  assert_parse_fail("let in = 5", nil)
end)

test("error: in without right operand", function()
  assert_parse_fail('"x" in;', nil)
end)
