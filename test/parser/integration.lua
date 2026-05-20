local T = require("ljs_test")
local P = require("test.helpers.parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok_from_source, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs
local TK = ljs.TOKEN

-- PARSER TESTS - ERROR CASES
-- ============================================================================

test("error: this is not supported", function()
  assert_parse_fail("this.x", "'this'")
end)

test("error: async is not supported", function()
  assert_parse_fail("async function f() {}", "'async'")
end)

test("error: typeof is not supported", function()
  assert_parse_fail("typeof x", "'typeof'")
end)

test("error: instanceof is not supported", function()
  assert_parse_fail("instanceof x", "'instanceof'")
end)

test("error: == rejected by tokenizer", function()
  assert_parse_fail("1 == 2", "Use ===")
end)

test("error: ++ with no operand", function()
  assert_parse_fail("++;", nil)
end)

test("error: -- with no operand", function()
  assert_parse_fail("--;", nil)
end)

test("error: ++ at end of input", function()
  assert_parse_fail("let x = ++", nil)
end)

test("error: postfix on number literal", function()
  assert_parse_fail("5++;", nil)
end)

test("error: postfix on string literal", function()
  assert_parse_fail('"hello"++;', nil)
end)

test("error: postfix on boolean literal", function()
  assert_parse_fail("true++;", nil)
end)

test("error: postfix on null literal", function()
  assert_parse_fail("null++;", nil)
end)

test("error: postfix on undefined literal", function()
  assert_parse_fail("undefined++;", nil)
end)

test("error: postfix on parenthesized expression", function()
  assert_parse_fail("(x)++;", nil)
end)

test("error: postfix on array literal", function()
  assert_parse_fail("[1, 2]++;", nil)
end)

test("error: double postfix x++ ++", function()
  assert_parse_fail("x++ ++;", nil)
end)

test("error: postfix followed by member access x++.y", function()
  assert_parse_fail("x++.y;", nil)
end)

test("error: += without right operand", function()
  assert_parse_fail("x += ;", nil)
end)

test("error: += without left operand", function()
  assert_parse_fail("+= 1;", nil)
end)

test("error: += at end of input", function()
  assert_parse_fail("x +=", nil)
end)

test("error: ** without left operand", function()
  assert_parse_fail("** 3;", nil)
end)

test("error: ** without right operand", function()
  assert_parse_fail("2 **;", nil)
end)

test("error: ** at end of input", function()
  assert_parse_fail("2 **", nil)
end)

test("error: **= without left operand", function()
  assert_parse_fail("**= 2;", nil)
end)

test("error: **= without right operand", function()
  assert_parse_fail("x **= ;", nil)
end)

test("error: **= at end of input", function()
  assert_parse_fail("x **=", nil)
end)

test("error: * * 3 (two separate stars is not **)", function()
  assert_parse_fail("2 * * 3;", nil)
end)

test("operator precedence: 1 + 2 * 3", function()
  assert_parse_ok("1 + 2 * 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "NumberLiteral", value = 1},
      right = {type = "BinaryExpression", operator = "*",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

-- ============================================================================
-- INTEGRATION TESTS
-- ============================================================================

test("integration: full program with multiple statements", function()
  assert_parse_ok('let x = 10;\nlet y = 20;\nconsole.log(x + y);', {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "x"},
        init = {type = "NumberLiteral", value = 10}}
    }},
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "y"},
        init = {type = "NumberLiteral", value = 20}}
    }},
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "MemberExpression",
        object = {type = "Identifier", name = "console"},
        property = {type = "Identifier", name = "log"},
        computed = false},
      arguments = {{type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "x"},
        right = {type = "Identifier", name = "y"}}}
    }}
  })
end)

test("integration: function with control flow", function()
  assert_parse_ok("function abs(n) { if (n < 0) { return -n; } else { return n; } }", {
    {type = "FunctionDeclaration", name = "abs",
      params = {{type = "Identifier", name = "n"}},
      body = {type = "BlockStatement", body = {
        {type = "IfStatement",
          test = {type = "BinaryExpression", operator = "<",
            left = {type = "Identifier", name = "n"},
            right = {type = "NumberLiteral", value = 0}},
          consequent = {type = "BlockStatement", body = {
            {type = "ReturnStatement", argument = {type = "UnaryExpression", operator = "-",
              argument = {type = "Identifier", name = "n"}}}
          }},
          alternate = {type = "BlockStatement", body = {
            {type = "ReturnStatement", argument = {type = "Identifier", name = "n"}}
          }}
        }
      }}
    }
  })
end)

test("integration: object methods and calls", function()
  assert_parse_ok("let obj = {a: 1}; obj.a;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "obj"},
        init = {type = "ObjectExpression", properties = {
          {type = "Property", key = {type = "Identifier", name = "a"},
            value = {type = "NumberLiteral", value = 1}, computed = false}
        }}
      }
    }},
    {type = "ExpressionStatement", expression = {type = "MemberExpression",
      object = {type = "Identifier", name = "obj"},
      property = {type = "Identifier", name = "a"},
      computed = false}
    }
  })
end)

test("integration: complex chained expression with arrow functions", function()
  assert_parse_ok("let result = arr.filter(x => x > 0).map(x => x * 2);", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "result"},
        init = {type = "CallExpression",
          callee = {type = "MemberExpression",
            object = {type = "CallExpression",
              callee = {type = "MemberExpression",
                object = {type = "Identifier", name = "arr"},
                property = {type = "Identifier", name = "filter"},
                computed = false},
              arguments = {{type = "ArrowFunctionExpression",
                params = {{type = "Identifier", name = "x"}},
                body = {type = "BlockStatement", body = {
                  {type = "ReturnStatement", argument = {type = "BinaryExpression",
                    operator = ">",
                    left = {type = "Identifier", name = "x"},
                    right = {type = "NumberLiteral", value = 0}}
                  }
                }}
              }}
            },
            property = {type = "Identifier", name = "map"},
            computed = false},
          arguments = {{type = "ArrowFunctionExpression",
            params = {{type = "Identifier", name = "x"}},
            body = {type = "BlockStatement", body = {
              {type = "ReturnStatement", argument = {type = "BinaryExpression",
                operator = "*",
                left = {type = "Identifier", name = "x"},
                right = {type = "NumberLiteral", value = 2}}
              }
            }}
          }}
        }
      }
    }}
  })
end)

-- ============================================================================
-- PARSER ISOLATION TESTS (via parse_tokens)
-- ============================================================================
-- These tests construct token arrays by hand and call ljs.parse_tokens()
-- directly. If one of these fails, it is unambiguously a parser bug —
-- the tokenizer is not involved.

local TK = ljs.TOKEN

local function tok(type, value, line, col)
  return { type = type, value = value, line = line or 1, col = col or 1 }
end

test("parse_tokens: let declaration", function()
  local tokens = {
    tok(TK.LET, "let"), tok(TK.IDENTIFIER, "x"), tok(TK.ASSIGN),
    tok(TK.NUMBER, 42), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "x"},
        init = {type = "NumberLiteral", value = 42}}
    }}
  }})
end)

test("parse_tokens: if/else", function()
  local tokens = {
    tok(TK.IF, "if"), tok(TK.LPAREN), tok(TK.IDENTIFIER, "x"), tok(TK.RPAREN),
    tok(TK.LBRACE), tok(TK.IDENTIFIER, "y"), tok(TK.SEMICOLON), tok(TK.RBRACE),
    tok(TK.ELSE, "else"),
    tok(TK.LBRACE), tok(TK.IDENTIFIER, "z"), tok(TK.SEMICOLON), tok(TK.RBRACE),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "IfStatement",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }},
      alternate = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "z"}}
      }}
    }
  }})
end)

test("parse_tokens: binary expression with precedence", function()
  local tokens = {
    tok(TK.NUMBER, 1), tok(TK.PLUS), tok(TK.NUMBER, 2), tok(TK.STAR),
    tok(TK.NUMBER, 3), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "NumberLiteral", value = 1},
      right = {type = "BinaryExpression", operator = "*",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}}}
    }
  }})
end)

test("parse_tokens: error on unexpected token", function()
  local tokens = {
    tok(TK.RPAREN), tok(TK.EOF),
  }
  local ast, err = ljs.parse_tokens(tokens)
  assert_eq(ast, nil, "expected nil ast")
  assert(err ~= nil, "expected error message")
end)

test("parse_tokens: empty program", function()
  local ast = ljs.parse_tokens({tok(TK.EOF)})
  assert_table_eq(ast, {type = "Program", body = {}})
end)

test("parse_tokens: compound assignment x += 1", function()
  local tokens = {
    tok(TK.IDENTIFIER, "x"), tok(TK.PLUS_ASSIGN),
    tok(TK.NUMBER, 1), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}
    }
  }})
end)

test("parse_tokens: ternary x ? 1 : 0", function()
  local tokens = {
    tok(TK.IDENTIFIER, "x"), tok(TK.QUESTION),
    tok(TK.NUMBER, 1), tok(TK.COLON),
    tok(TK.NUMBER, 0), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  }})
end)

test("parse_tokens: do...while with braces", function()
  local tokens = {
    tok(TK.DO, "do"),
    tok(TK.LBRACE), tok(TK.IDENTIFIER, "x"), tok(TK.SEMICOLON), tok(TK.RBRACE),
    tok(TK.WHILE, "while"), tok(TK.LPAREN), tok(TK.IDENTIFIER, "y"), tok(TK.RPAREN),
    tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "DoWhileStatement",
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      test = {type = "Identifier", name = "y"}
    }
  }})
end)

test("parse_tokens: do...while without braces", function()
  local tokens = {
    tok(TK.DO, "do"),
    tok(TK.IDENTIFIER, "x"), tok(TK.SEMICOLON),
    tok(TK.WHILE, "while"), tok(TK.LPAREN), tok(TK.IDENTIFIER, "y"), tok(TK.RPAREN),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "DoWhileStatement",
      body = {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}},
      test = {type = "Identifier", name = "y"}
    }
  }})
end)

-- ============================================================================
T.summary()
