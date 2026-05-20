local T = require("ljs_test")
local P = require("test.helpers.parser")
local ljs = require("ljs_parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

-- ============================================================================
-- Basic 'in' operator parsing
-- ============================================================================

test("parse string in object", function()
  assert_parse_ok('"x" in obj;', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "in",
        left = { type = "StringLiteral", value = "x" },
        right = { type = "Identifier", name = "obj" },
      },
    },
  })
end)

test("parse variable in object", function()
  assert_parse_ok("key in obj;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "in",
        left = { type = "Identifier", name = "key" },
        right = { type = "Identifier", name = "obj" },
      },
    },
  })
end)

test("parse number in array", function()
  assert_parse_ok("0 in arr;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "in",
        left = { type = "NumberLiteral", value = 0 },
        right = { type = "Identifier", name = "arr" },
      },
    },
  })
end)

test("parse member expression as left operand", function()
  local ast = ljs.parse("obj.key in obj2;")
  assert(ast)
  local expr = ast.body[1].expression
  assert_eq(expr.type, "BinaryExpression")
  assert_eq(expr.operator, "in")
  assert_eq(expr.left.type, "MemberExpression")
  assert_eq(expr.right.name, "obj2")
end)

test("parse member expression as right operand", function()
  local ast = ljs.parse('"x" in obj.prop;')
  assert(ast)
  local expr = ast.body[1].expression
  assert_eq(expr.type, "BinaryExpression")
  assert_eq(expr.operator, "in")
  assert_eq(expr.right.type, "MemberExpression")
end)

test("parse object literal as right operand", function()
  local ast = ljs.parse('"x" in {a: 1};')
  assert(ast)
  local expr = ast.body[1].expression
  assert_eq(expr.type, "BinaryExpression")
  assert_eq(expr.operator, "in")
  assert_eq(expr.right.type, "ObjectExpression")
end)

-- ============================================================================
-- Precedence and associativity
-- ============================================================================

test("in at precedence 3 (same as ===), left-associative", function()
  assert_parse_ok('"x" in obj === true;', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "===",
        left = {
          type = "BinaryExpression",
          operator = "in",
          left = { type = "StringLiteral", value = "x" },
          right = { type = "Identifier", name = "obj" },
        },
        right = { type = "BooleanLiteral", value = true },
      },
    },
  })
end)

test("in + is left-associative: a in b in c", function()
  assert_parse_ok("a in b in c;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "in",
        left = {
          type = "BinaryExpression",
          operator = "in",
          left = { type = "Identifier", name = "a" },
          right = { type = "Identifier", name = "b" },
        },
        right = { type = "Identifier", name = "c" },
      },
    },
  })
end)

test("+ binds tighter than in", function()
  assert_parse_ok('1 + "x" in obj;', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "in",
        left = {
          type = "BinaryExpression",
          operator = "+",
          left = { type = "NumberLiteral", value = 1 },
          right = { type = "StringLiteral", value = "x" },
        },
        right = { type = "Identifier", name = "obj" },
      },
    },
  })
end)

test("in in && expression", function()
  assert_parse_ok('"x" in a && "y" in b;', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "&&",
        left = {
          type = "BinaryExpression",
          operator = "in",
          left = { type = "StringLiteral", value = "x" },
          right = { type = "Identifier", name = "a" },
        },
        right = {
          type = "BinaryExpression",
          operator = "in",
          left = { type = "StringLiteral", value = "y" },
          right = { type = "Identifier", name = "b" },
        },
      },
    },
  })
end)

-- ============================================================================
-- in operator in various expression contexts
-- ============================================================================

test("in in if condition", function()
  local ast = ljs.parse('if ("x" in obj) { y; }')
  assert(ast)
  local if_stmt = ast.body[1]
  assert_eq(if_stmt.type, "IfStatement")
  assert_eq(if_stmt.test.type, "BinaryExpression")
  assert_eq(if_stmt.test.operator, "in")
end)

test("in in ternary", function()
  assert_parse_ok('"x" in obj ? 1 : 0;', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "ConditionalExpression",
        test = {
          type = "BinaryExpression",
          operator = "in",
          left = { type = "StringLiteral", value = "x" },
          right = { type = "Identifier", name = "obj" },
        },
        consequent = { type = "NumberLiteral", value = 1 },
        alternate = { type = "NumberLiteral", value = 0 },
      },
    },
  })
end)

test("in in variable init", function()
  assert_parse_ok('let has = "x" in obj;', {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "has" },
          init = {
            type = "BinaryExpression",
            operator = "in",
            left = { type = "StringLiteral", value = "x" },
            right = { type = "Identifier", name = "obj" },
          },
        },
      },
    },
  })
end)

test("in negated", function()
  assert_parse_ok('!("x" in obj);', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UnaryExpression",
        operator = "!",
        argument = {
          type = "BinaryExpression",
          operator = "in",
          left = { type = "StringLiteral", value = "x" },
          right = { type = "Identifier", name = "obj" },
        },
      },
    },
  })
end)

test("in in parenthesized expression", function()
  assert_parse_ok('("x" in obj);', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "in",
        left = { type = "StringLiteral", value = "x" },
        right = { type = "Identifier", name = "obj" },
      },
    },
  })
end)

test("in in while condition", function()
  local ast = ljs.parse('while ("x" in obj) { break; }')
  assert(ast)
  assert_eq(ast.body[1].type, "WhileStatement")
  assert_eq(ast.body[1].test.operator, "in")
end)

test("in in return statement", function()
  local ast = ljs.parse('function f() { return "x" in obj; }')
  assert(ast)
  local ret = ast.body[1].body.body[1]
  assert_eq(ret.type, "ReturnStatement")
  assert_eq(ret.argument.operator, "in")
end)

-- ============================================================================
-- for...in disambiguation (regression)
-- ============================================================================

test("for (key in obj) is still ForInStatement", function()
  local ast = ljs.parse("for (key in obj) { key; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "Identifier")
  assert_eq(f.left.name, "key")
  assert_eq(f.right.name, "obj")
end)

test("for (let key in obj) is still ForInStatement", function()
  local ast = ljs.parse("for (let key in obj) { key; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "VariableDeclaration")
end)

test("for (const k in obj) is still ForInStatement", function()
  local ast = ljs.parse("for (const k in obj) { k; }")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.kind, "const")
end)

test("for with in inside parens is C-style for", function()
  local ast = ljs.parse('for (("x" in obj); ; ) { break; }')
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

-- ============================================================================
-- Error cases
-- ============================================================================

test("error: bare in keyword in expression position", function()
  assert_parse_fail("in;", nil)
end)

test("error: let in = 5 (in is keyword)", function()
  assert_parse_fail("let in = 5", nil)
end)

test("error: in without right operand", function()
  assert_parse_fail('"x" in;', nil)
end)

T.summary()
