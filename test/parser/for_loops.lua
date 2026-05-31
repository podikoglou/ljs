local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local parser = require("ljs.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail

test("parse for...in with let", function()
  assert_parse_ok("for (let key in obj) { console.log(key); }", {
    A.for_in(
      A.let("key"),
      A.id("obj"),
      A.block({
        A.expr_stmt(A.call(A.member(A.id("console"), A.id("log")), { A.id("key") })),
      })
    ),
  })
end)

test("parse for...in with const", function()
  assert_parse_ok("for (const k in obj) { k; }", {
    A.for_in(
      A.const("k"),
      A.id("obj"),
      A.block({
        A.expr_stmt(A.id("k")),
      })
    ),
  })
end)

test("parse for...in with var (preserves kind)", function()
  local ast = parser.parse("for (var k in obj) { k; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "VariableDeclaration")
  assert_eq(f.left.kind, "var")
  assert_eq(f.left.declarations[1].name.name, "k")
  assert_eq(f.right.name, "obj")
end)

test("parse for...in with expression left (no declaration)", function()
  local ast = parser.parse("for (key in obj) { key; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "Identifier")
  assert_eq(f.left.name, "key")
  assert_eq(f.right.name, "obj")
end)

test("parse for...in without body braces", function()
  local ast = parser.parse("for (let k in obj) f(k);")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.body.type, "ExpressionStatement")
end)

test("parse for...in with object literal right", function()
  local ast = parser.parse("for (let k in {a: 1, b: 2}) { k; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.right.type, "ObjectExpression")
  assert_eq(#f.right.properties, 2)
end)

test("parse for...in with member expression right", function()
  local ast = parser.parse("for (let k in obj.prop) { k; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.right.type, "MemberExpression")
end)

test("parse for...in with computed member expression right", function()
  local ast = parser.parse("for (let k in obj[key]) { k; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.right.type, "MemberExpression")
  assert_eq(f.right.computed, true)
end)

test("parse nested for...in", function()
  local ast = parser.parse("for (let k in obj) { for (let j in arr) { x; } }")
  assert(ast)
  local outer = ast.body[1]
  assert_eq(outer.type, "ForInStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "ForInStatement")
end)

test("parse for...in body uses key with bracket access", function()
  local ast = parser.parse("for (let k in obj) { obj[k]; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  local expr = f.body.body[1].expression
  assert_eq(expr.type, "MemberExpression")
  assert_eq(expr.computed, true)
  assert_eq(expr.property.name, "k")
end)

test("error: for-in with multiple declarators", function()
  assert_parse_fail("for (let x, y in obj) { }", "single variable")
end)

test("error: for-in with initializer", function()
  assert_parse_fail("for (let x = 1 in obj) { }", "initializer")
end)

test("error: for-in with const and initializer", function()
  assert_parse_fail("for (const x = 1 in obj) { }", "initializer")
end)

test("error: for-in missing right expression", function()
  assert_parse_fail("for (let x in) { }", nil)
end)

test("error: for-in with in as variable name", function()
  assert_parse_fail("for (let in in obj) { }", nil)
end)

test("error: let in = 5 (in is keyword)", function()
  assert_parse_fail("let in = 5", nil)
end)

test("error: for-in missing body", function()
  assert_parse_fail("for (let x in obj) ", "Unexpected token")
end)

test("parse for(;;) infinite loop", function()
  local ast = parser.parse("for (;;) { x; }")
  assert(ast)
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].init, nil)
  assert_eq(ast.body[1].test, nil)
  assert_eq(ast.body[1].update, nil)
  assert_eq(ast.body[1].body.type, "BlockStatement")
end)

test("parse for with full clauses", function()
  local ast = parser.parse("for (let i = 0; i < 10; i = i + 1) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.init.kind, "let")
  assert_eq(f.init.declarations[1].name.name, "i")
  assert_eq(f.init.declarations[1].init.value, 0)
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.test.operator, "<")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "=")
end)

test("parse for with expression init", function()
  local ast = parser.parse("for (i = 0; i < 10; i = i + 1) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "ExpressionStatement")
  assert_eq(f.init.expression.type, "BinaryExpression")
  assert_eq(f.init.expression.operator, "=")
  assert_eq(f.init.expression.left.name, "i")
end)

test("parse for with only init + test", function()
  local ast = parser.parse("for (let x = 1; x < 5; ) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.update, nil)
end)

test("parse for with only test + update", function()
  local ast = parser.parse("for (; x < 10; x = x + 1) { y; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init, nil)
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.update.type, "BinaryExpression")
end)

test("parse for with only update", function()
  local ast = parser.parse("for (;; x = x + 1) { y; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init, nil)
  assert_eq(f.test, nil)
  assert_eq(f.update.type, "BinaryExpression")
end)

test("parse for with only init", function()
  local ast = parser.parse("for (let x = 1; ; ) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.test, nil)
  assert_eq(f.update, nil)
end)

test("parse for with only test (while-like)", function()
  local ast = parser.parse("for (; x < 10; ) { y; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init, nil)
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.update, nil)
end)

test("parse for without body braces", function()
  local ast = parser.parse("for (;;) x;")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.body.type, "ExpressionStatement")
end)

test("parse nested for loops", function()
  local ast = parser.parse("for (;;) { for (;;) { x; } }")
  assert(ast)
  local outer = ast.body[1]
  assert_eq(outer.type, "ForStatement")
  assert_eq(outer.body.type, "BlockStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "ForStatement")
end)

test("parse for with const init", function()
  local ast = parser.parse("for (const x = 1; x < 5; x = x + 1) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.init.kind, "const")
end)

test("parse for with logical test", function()
  local ast = parser.parse("for (; a > 0 && b < 10; ) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.test.operator, "&&")
end)

test("parse for with multiple declarators in init", function()
  local ast = parser.parse("for (let i = 0, j = 10; i < j; i = i + 1) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(#f.init.declarations, 2)
  assert_eq(f.init.declarations[1].name.name, "i")
  assert_eq(f.init.declarations[2].name.name, "j")
end)

test("parse for...of still works (regression)", function()
  assert_parse_ok("for (let x of arr) { x; }", {
    A.for_of(
      A.let("x"),
      A.id("arr"),
      A.block({
        A.expr_stmt(A.id("x")),
      })
    ),
  })
end)

test("for-of with const still works (regression)", function()
  assert_parse_ok("for (const x of arr) { x; }", {
    A.for_of(
      A.const("x"),
      A.id("arr"),
      A.block({
        A.expr_stmt(A.id("x")),
      })
    ),
  })
end)

test("error: for missing body", function()
  assert_parse_fail("for (;;) ", "Unexpected token")
end)

test("error: for missing closing paren", function()
  assert_parse_fail("for (; ; ", "Unexpected token")
end)

test("error: for missing open paren", function()
  assert_parse_fail("for ; ; ) { }", "(")
end)

test("error: for with let in test position", function()
  assert_parse_fail("for (; let x = 1; ) { }", nil)
end)

test("error: for with extra semicolons (four)", function()
  assert_parse_fail("for (;;;) { }", nil)
end)

test("error: for() with no contents", function()
  assert_parse_fail("for () { }", nil)
end)

test("error: for with expression but no semicolon or of", function()
  assert_parse_fail("for (x) { }", nil)
end)

test("parse for with var init (preserves kind)", function()
  local ast = parser.parse("for (var i = 0; i < 3; i = i + 1) { x; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.init.kind, "var")
  assert_eq(f.init.declarations[1].name.name, "i")
end)

test("parse for with i++ update", function()
  local ast = parser.parse("for (let i = 0; i < 10; i++) {}")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "UpdateExpression")
  assert_eq(f.update.operator, "++")
  assert_eq(f.update.prefix, false)
  assert_eq(f.update.argument.name, "i")
end)

test("parse for with --i update", function()
  local ast = parser.parse("for (let i = 10; i > 0; --i) {}")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "UpdateExpression")
  assert_eq(f.update.operator, "--")
  assert_eq(f.update.prefix, true)
  assert_eq(f.update.argument.name, "i")
end)

test("parse x++ as if condition", function()
  assert_parse_ok("if (x++) { y; }", {
    A.if_(
      A.update("++", A.id("x"), false),
      A.block({
        A.expr_stmt(A.id("y")),
      })
    ),
  })
end)

test("parse let x = y++ (as variable init)", function()
  assert_parse_ok("let x = y++;", {
    A.let("x", A.update("++", A.id("y"), false)),
  })
end)

test("parse f(x++) as call argument", function()
  assert_parse_ok("f(x++);", {
    A.expr_stmt(A.call(A.id("f"), {
      A.update("++", A.id("x"), false),
    })),
  })
end)

test("parse arr[x++] as computed property", function()
  assert_parse_ok("arr[x++];", {
    A.expr_stmt(A.member_c(A.id("arr"), A.update("++", A.id("x"), false))),
  })
end)

test("error: for with only one semicolon", function()
  assert_parse_fail("for (; ) { }", nil)
end)
