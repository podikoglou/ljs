local T = require("ljs_test")
local P = require("test.helpers.parser")
local test = T.test
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

T.summary()
