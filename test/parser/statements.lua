local T = require("ljs_test")
local P = require("test.helpers.parser")
local test, assert_table_eq = T.test, T.assert_table_eq
local assert_parse_ok = P.assert_parse_ok

-- ============================================================================
-- PARSER TESTS - STATEMENTS
-- ============================================================================

test("parse let declaration", function()
  assert_parse_ok("let x = 1;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "x"}, init = {type = "NumberLiteral", value = 1}}
    }}
  })
end)

test("parse const declaration", function()
  assert_parse_ok("const y = 2;", {
    {type = "VariableDeclaration", kind = "const", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "y"}, init = {type = "NumberLiteral", value = 2}}
    }}
  })
end)

test("parse var declaration (treated as let)", function()
  assert_parse_ok("var z = 3;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "z"}, init = {type = "NumberLiteral", value = 3}}
    }}
  })
end)

test("parse multiple declarators", function()
  assert_parse_ok("let a = 1, b = 2;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "a"}, init = {type = "NumberLiteral", value = 1}},
      {type = "VariableDeclarator", name = {type = "Identifier", name = "b"}, init = {type = "NumberLiteral", value = 2}},
    }}
  })
end)

test("parse variable without initializer", function()
  assert_parse_ok("let x;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "x"}}
    }}
  })
end)

test("parse function declaration", function()
  assert_parse_ok("function add(a, b) { return a + b; }", {
    {type = "FunctionDeclaration", name = "add", params = {
      {type = "Identifier", name = "a"},
      {type = "Identifier", name = "b"}
    }, body = {type = "BlockStatement", body = {
      {type = "ReturnStatement", argument = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}}}
    }}}
  })
end)

test("parse if/else", function()
  assert_parse_ok("if (x) { y; } else { z; }", {
    {type = "IfStatement",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }},
      alternate = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "z"}}
      }}
    }
  })
end)

test("parse while", function()
  assert_parse_ok("while (x) { y; }", {
    {type = "WhileStatement",
      test = {type = "Identifier", name = "x"},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }}
    }
  })
end)

-- ============================================================================
-- INVARIANT: parse("") and parse(whitespace) produce empty Program
-- Contract: the parser must handle empty/whitespace-only input gracefully.
-- If this breaks, any tool that passes user input directly to parse() will crash.

test("parse empty source produces empty Program", function()
  local ast = P.ljs.parse("")
  assert_table_eq(ast, {type = "Program", body = {}})
end)

test("parse whitespace-only source produces empty Program", function()
  local ast = P.ljs.parse("   \n  \t  \n  ")
  assert_table_eq(ast, {type = "Program", body = {}})
end)

-- ============================================================================
-- INVARIANT: var always normalizes to kind="let"
-- Already tested once above, but this confirms it holds for multi-declarator
-- and uninitialized forms where a different code path might be taken.

test("parse var multi-declarator normalizes to let", function()
  assert_parse_ok("var a, b = 2;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "a"}},
      {type = "VariableDeclarator", name = {type = "Identifier", name = "b"}, init = {type = "NumberLiteral", value = 2}},
    }}
  })
end)

T.summary()
