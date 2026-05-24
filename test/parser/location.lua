local T = require("test.ljs_test")
local parser = require("ljs.parser")
local test, assert_eq = T.test, T.assert_eq

local function parse_ok(source)
  local ast, err = parser.parse(source)
  if not ast then
    error("parse failed: " .. tostring(err))
  end
  return ast
end

local function has_loc(node, msg)
  msg = msg or node.type
  assert_eq(type(node.line), "number", msg .. " .line type")
  assert_eq(type(node.col), "number", msg .. " .col type")
  assert(node.line >= 1, msg .. " line >= 1")
  assert(node.col >= 1, msg .. " col >= 1")
end

local function walk_check_loc(node, path)
  path = path or "root"
  if type(node) ~= "table" then
    return
  end
  if node.type then
    has_loc(node, path .. "(" .. node.type .. ")")
  end
  for k, v in pairs(node) do
    if type(v) == "table" then
      if type(k) == "number" then
        walk_check_loc(v, path .. "[" .. k .. "]")
      elseif k ~= "type" and k ~= "line" and k ~= "col" then
        walk_check_loc(v, path .. "." .. k)
      end
    end
  end
end

test("Program has line/col", function()
  local ast = parse_ok("let x = 1;")
  has_loc(ast, "Program")
  assert_eq(ast.line, 1)
  assert_eq(ast.col, 1)
end)

test("Identifier has line/col", function()
  local ast = parse_ok("x;")
  has_loc(ast.body[1].expression, "Identifier")
  assert_eq(ast.body[1].expression.line, 1)
  assert_eq(ast.body[1].expression.col, 1)
end)

test("NumberLiteral has line/col", function()
  local ast = parse_ok("42;")
  has_loc(ast.body[1].expression, "NumberLiteral")
  assert_eq(ast.body[1].expression.line, 1)
  assert_eq(ast.body[1].expression.col, 1)
end)

test("StringLiteral has line/col", function()
  local ast = parse_ok('"hello";')
  has_loc(ast.body[1].expression, "StringLiteral")
end)

test("BooleanLiteral has line/col", function()
  local ast = parse_ok("true;")
  has_loc(ast.body[1].expression, "BooleanLiteral")
end)

test("NullLiteral has line/col", function()
  local ast = parse_ok("null;")
  has_loc(ast.body[1].expression, "NullLiteral")
end)

test("BinaryExpression has line/col", function()
  local ast = parse_ok("1 + 2;")
  has_loc(ast.body[1].expression, "BinaryExpression")
  assert_eq(ast.body[1].expression.line, 1)
  assert_eq(ast.body[1].expression.col, 3)
end)

test("ExpressionStatement has line/col", function()
  local ast = parse_ok("x;")
  has_loc(ast.body[1], "ExpressionStatement")
end)

test("VariableDeclaration has line/col", function()
  local ast = parse_ok("let x = 1;")
  has_loc(ast.body[1], "VariableDeclaration")
  assert_eq(ast.body[1].line, 1)
  assert_eq(ast.body[1].col, 1)
end)

test("VariableDeclarator has line/col", function()
  local ast = parse_ok("let x = 1;")
  has_loc(ast.body[1].declarations[1], "VariableDeclarator")
end)

test("BlockStatement has line/col", function()
  local ast = parse_ok("{ x; }")
  has_loc(ast.body[1], "BlockStatement")
end)

test("IfStatement has line/col", function()
  local ast = parse_ok("if (true) x;")
  has_loc(ast.body[1], "IfStatement")
  assert_eq(ast.body[1].line, 1)
  assert_eq(ast.body[1].col, 1)
end)

test("WhileStatement has line/col", function()
  local ast = parse_ok("while (true) x;")
  has_loc(ast.body[1], "WhileStatement")
  assert_eq(ast.body[1].line, 1)
  assert_eq(ast.body[1].col, 1)
end)

test("DoWhileStatement has line/col", function()
  local ast = parse_ok("do x; while (true);")
  has_loc(ast.body[1], "DoWhileStatement")
  assert_eq(ast.body[1].line, 1)
  assert_eq(ast.body[1].col, 1)
end)

test("ForStatement has line/col", function()
  local ast = parse_ok("for (let i = 0; i < 10; i++) x;")
  has_loc(ast.body[1], "ForStatement")
  assert_eq(ast.body[1].line, 1)
  assert_eq(ast.body[1].col, 1)
end)

test("ForOfStatement has line/col", function()
  local ast = parse_ok("for (let x of y) x;")
  has_loc(ast.body[1], "ForOfStatement")
end)

test("ForInStatement has line/col", function()
  local ast = parse_ok("for (let x in y) x;")
  has_loc(ast.body[1], "ForInStatement")
end)

test("FunctionDeclaration has line/col", function()
  local ast = parse_ok("function foo() {}")
  has_loc(ast.body[1], "FunctionDeclaration")
  assert_eq(ast.body[1].line, 1)
  assert_eq(ast.body[1].col, 1)
end)

test("ReturnStatement has line/col", function()
  local ast = parse_ok("function f() { return 1; }")
  local fn = ast.body[1]
  has_loc(fn.body.body[1], "ReturnStatement")
end)

test("BreakStatement has line/col", function()
  local ast = parse_ok("while (true) { break; }")
  local block = ast.body[1].body
  has_loc(block.body[1], "BreakStatement")
end)

test("ContinueStatement has line/col", function()
  local ast = parse_ok("while (true) { continue; }")
  local block = ast.body[1].body
  has_loc(block.body[1], "ContinueStatement")
end)

test("SwitchStatement has line/col", function()
  local ast = parse_ok("switch (x) { case 1: break; }")
  has_loc(ast.body[1], "SwitchStatement")
end)

test("SwitchCase has line/col", function()
  local ast = parse_ok("switch (x) { case 1: break; }")
  has_loc(ast.body[1].cases[1], "SwitchCase")
end)

test("UnaryExpression has line/col", function()
  local ast = parse_ok("!x;")
  has_loc(ast.body[1].expression, "UnaryExpression")
end)

test("UpdateExpression prefix has line/col", function()
  local ast = parse_ok("++x;")
  has_loc(ast.body[1].expression, "UpdateExpression")
end)

test("UpdateExpression postfix has line/col", function()
  local ast = parse_ok("x++;")
  has_loc(ast.body[1].expression, "UpdateExpression")
end)

test("ConditionalExpression has line/col", function()
  local ast = parse_ok("x ? 1 : 2;")
  has_loc(ast.body[1].expression, "ConditionalExpression")
end)

test("CallExpression has line/col", function()
  local ast = parse_ok("foo();")
  has_loc(ast.body[1].expression, "CallExpression")
end)

test("MemberExpression dot has line/col", function()
  local ast = parse_ok("a.b;")
  has_loc(ast.body[1].expression, "MemberExpression")
end)

test("MemberExpression bracket has line/col", function()
  local ast = parse_ok("a[0];")
  has_loc(ast.body[1].expression, "MemberExpression")
end)

test("ObjectExpression has line/col", function()
  local ast = parse_ok("({ x: 1 });")
  has_loc(ast.body[1].expression, "ObjectExpression")
end)

test("Property has line/col", function()
  local ast = parse_ok("({ x: 1 });")
  has_loc(ast.body[1].expression.properties[1], "Property")
end)

test("ArrayExpression has line/col", function()
  local ast = parse_ok("[1, 2];")
  has_loc(ast.body[1].expression, "ArrayExpression")
end)

test("ArrowFunctionExpression has line/col", function()
  local ast = parse_ok("(x) => x;")
  has_loc(ast.body[1].expression, "ArrowFunctionExpression")
end)

test("FunctionExpression has line/col", function()
  local ast = parse_ok("(function() {});")
  has_loc(ast.body[1].expression, "FunctionExpression")
end)

test("ThisExpression has line/col", function()
  local ast = parse_ok("this.x;")
  has_loc(ast.body[1].expression.object, "ThisExpression")
end)

test("NewExpression has line/col", function()
  local ast = parse_ok("new Foo();")
  has_loc(ast.body[1].expression, "NewExpression")
end)

test("ThrowStatement has line/col", function()
  local ast = parse_ok("throw 1;")
  has_loc(ast.body[1], "ThrowStatement")
end)

test("TryStatement has line/col", function()
  local ast = parse_ok("try {} catch(e) {}")
  has_loc(ast.body[1], "TryStatement")
end)

test("CatchClause has line/col", function()
  local ast = parse_ok("try {} catch(e) {}")
  has_loc(ast.body[1].handler, "CatchClause")
end)

test("ClassDeclaration has line/col", function()
  local ast = parse_ok("class Foo {}")
  has_loc(ast.body[1], "ClassDeclaration")
end)

test("MethodDefinition has line/col", function()
  local ast = parse_ok("class Foo { method() {} }")
  has_loc(ast.body[1].body[1], "MethodDefinition")
end)

test("DeleteExpression has line/col", function()
  local ast = parse_ok("delete a.b;")
  has_loc(ast.body[1].expression, "DeleteExpression")
end)

test("TypeofExpression has line/col", function()
  local ast = parse_ok("typeof x;")
  has_loc(ast.body[1].expression, "TypeofExpression")
end)

test("multi-line source has correct line numbers", function()
  local ast = parse_ok("let x = 1;\nlet y = 2;")
  assert_eq(ast.body[1].line, 1, "first decl line")
  assert_eq(ast.body[2].line, 2, "second decl line")
end)

test("multi-line source: identifiers on correct lines", function()
  local ast = parse_ok("x;\ny;")
  assert_eq(ast.body[1].expression.line, 1, "first identifier line")
  assert_eq(ast.body[2].expression.line, 2, "second identifier line")
end)

test("parse_tokens produces nodes with line/col", function()
  local tokens = {
    { type = "Number", value = 42, line = 3, col = 5 },
    { type = ";", line = 3, col = 7 },
    { type = "EOF", line = 3, col = 8 },
  }
  local ast = parser.parse_tokens(tokens)
  assert(ast, "parse_tokens should succeed")
  has_loc(ast, "Program")
  has_loc(ast.body[1], "ExpressionStatement")
  has_loc(ast.body[1].expression, "NumberLiteral")
  assert_eq(ast.body[1].expression.line, 3)
  assert_eq(ast.body[1].expression.col, 5)
end)

test("property: all nodes in diverse programs have line >= 1 and col >= 1", function()
  local programs = {
    "let x = 1; x;",
    "function foo(a, b) { return a + b; } foo(1, 2);",
    "if (true) { x; } else { y; }",
    "while (true) { break; }",
    "for (let i = 0; i < 10; i++) { x; }",
    "for (let x of [1, 2]) x;",
    "switch (x) { case 1: break; default: y; }",
    "try { x; } catch(e) { y; } finally { z; }",
    "let obj = { x: 1, y: 2 };",
    "let arr = [1, 2, 3];",
    "class Foo extends Bar { constructor() {} method() {} static fn() {} }",
    "(x) => x + 1;",
    "x ? 1 : 2;",
    "!x;",
    "typeof x;",
    "delete a.b;",
    "new Foo(1);",
    "throw new Error();",
    "a.b.c[0](1);",
    "do { x; } while (true);",
    "for (let x in obj) x;",
  }
  for _, source in ipairs(programs) do
    local ast = parse_ok(source)
    walk_check_loc(ast, source)
  end
end)
