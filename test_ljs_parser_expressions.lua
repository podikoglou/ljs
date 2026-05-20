local T = require("ljs_test")
local P = require("ljs_test_parser")
local ljs = require("ljs_parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail

-- PARSER TESTS - EXPRESSIONS
-- ============================================================================

test("parse NumberLiteral", function()
  assert_parse_ok("42;", {
    {type = "ExpressionStatement", expression = {type = "NumberLiteral", value = 42}}
  })
end)

test("parse hex literal 0xFF", function()
  assert_parse_ok("0xFF;", {
    {type = "ExpressionStatement", expression = {type = "NumberLiteral", value = 255}}
  })
end)

test("parse hex literal 0x1a", function()
  assert_parse_ok("0x1a;", {
    {type = "ExpressionStatement", expression = {type = "NumberLiteral", value = 26}}
  })
end)

test("parse hex literal 0X0F uppercase prefix", function()
  assert_parse_ok("0X0F;", {
    {type = "ExpressionStatement", expression = {type = "NumberLiteral", value = 15}}
  })
end)

test("parse hex literal 0x0", function()
  assert_parse_ok("0x0;", {
    {type = "ExpressionStatement", expression = {type = "NumberLiteral", value = 0}}
  })
end)

test("parse error: hex literal with no digits after 0x", function()
  assert_parse_fail("0x;", "hex")
end)

test("parse hex in variable", function()
  assert_parse_ok("let x = 0xFF;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "x"}, init = {type = "NumberLiteral", value = 255}}
    }}
  })
end)

test("parse StringLiteral", function()
  assert_parse_ok('"hello";', {
    {type = "ExpressionStatement", expression = {type = "StringLiteral", value = "hello"}}
  })
end)

test("parse BooleanLiteral true", function()
  assert_parse_ok("true;", {
    {type = "ExpressionStatement", expression = {type = "BooleanLiteral", value = true}}
  })
end)

test("parse BooleanLiteral false", function()
  assert_parse_ok("false;", {
    {type = "ExpressionStatement", expression = {type = "BooleanLiteral", value = false}}
  })
end)

test("parse NullLiteral", function()
  assert_parse_ok("null;", {
    {type = "ExpressionStatement", expression = {type = "NullLiteral"}}
  })
end)

test("parse UndefinedLiteral", function()
  assert_parse_ok("undefined;", {
    {type = "ExpressionStatement", expression = {type = "UndefinedLiteral"}}
  })
end)

test("parse Identifier expression", function()
  assert_parse_ok("x;", {
    {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
  })
end)

test("parse BinaryExpression +", function()
  assert_parse_ok("1 + 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "NumberLiteral", value = 1},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse BinaryExpression all operators", function()
  local ops = {
    {"1 - 2;", "-"},
    {"3 * 4;", "*"},
    {"6 / 2;", "/"},
    {"5 % 2;", "%"},
    {"1 === 2;", "==="},
    {"1 !== 2;", "!=="},
    {"1 < 2;", "<"},
    {"1 > 2;", ">"},
    {"1 <= 2;", "<="},
    {"1 >= 2;", ">="},
    {"true && false;", "&&"},
    {"true || false;", "||"},
    {"2 ** 3;", "**"},
  }
  for _, tc in ipairs(ops) do
    local ast = ljs.parse(tc[1])
    assert_table_eq(ast.body[1].expression.operator, tc[2], "operator for " .. tc[1])
  end
end)

test("parse BinaryExpression **", function()
  assert_parse_ok("2 ** 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "NumberLiteral", value = 2},
      right = {type = "NumberLiteral", value = 3}}
    }
  })
end)

test("parse ** with variable operands", function()
  assert_parse_ok("x ** y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "Identifier", name = "x"},
      right = {type = "Identifier", name = "y"}}
    }
  })
end)

test("parse ** right-associative: 2 ** 3 ** 4", function()
  assert_parse_ok("2 ** 3 ** 4;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "NumberLiteral", value = 2},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 3},
        right = {type = "NumberLiteral", value = 4}}}
    }
  })
end)

test("parse ** right-associative three-deep", function()
  assert_parse_ok("a ** b ** c ** d;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "Identifier", name = "a"},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "Identifier", name = "b"},
        right = {type = "BinaryExpression", operator = "**",
          left = {type = "Identifier", name = "c"},
          right = {type = "Identifier", name = "d"}}}}
    }
  })
end)

test("parse compound **=", function()
  assert_parse_ok("x **= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse **= on member expression", function()
  assert_parse_ok("obj.x **= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "x"},
        computed = false},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse **= on computed member", function()
  assert_parse_ok("arr[i] **= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "Identifier", name = "i"},
        computed = true},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse **= right-associative: x **= y **= 2", function()
  assert_parse_ok("x **= y **= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "**=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 2}}}
    }
  })
end)

test("parse precedence: ** tighter than * (right)", function()
  assert_parse_ok("2 * 3 ** 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*",
      left = {type = "NumberLiteral", value = 2},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 3},
        right = {type = "NumberLiteral", value = 2}}}
    }
  })
end)

test("parse precedence: ** tighter than * (left)", function()
  assert_parse_ok("2 ** 3 * 4;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*",
      left = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}},
      right = {type = "NumberLiteral", value = 4}}
    }
  })
end)

test("parse precedence: ** tighter than /", function()
  assert_parse_ok("8 / 2 ** 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "/",
      left = {type = "NumberLiteral", value = 8},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

test("parse precedence: ** tighter than %", function()
  assert_parse_ok("10 % 3 ** 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "%",
      left = {type = "NumberLiteral", value = 10},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 3},
        right = {type = "NumberLiteral", value = 2}}}
    }
  })
end)

test("parse precedence: ** tighter than +", function()
  assert_parse_ok("1 + 2 ** 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "NumberLiteral", value = 1},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

test("parse precedence: ** tighter than comparison", function()
  assert_parse_ok("2 ** 3 > 5;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">",
      left = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}},
      right = {type = "NumberLiteral", value = 5}}
    }
  })
end)

test("parse precedence: ** tighter than &&", function()
  assert_parse_ok("a ** b && c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&&",
      left = {type = "BinaryExpression", operator = "**",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}
    }
  })
end)

test("parse precedence: ** tighter than ||", function()
  assert_parse_ok("a ** b || c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "||",
      left = {type = "BinaryExpression", operator = "**",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}
    }
  })
end)

test("parse -2 ** 3 (unary minus before **)", function()
  assert_parse_ok("-2 ** 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "UnaryExpression", operator = "-",
        argument = {type = "NumberLiteral", value = 2}},
      right = {type = "NumberLiteral", value = 3}}
    }
  })
end)

test("parse !a ** b (unary not before **)", function()
  assert_parse_ok("!a ** b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "UnaryExpression", operator = "!",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}
    }
  })
end)

test("parse +a ** b (unary plus before **)", function()
  assert_parse_ok("+a ** b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "UnaryExpression", operator = "+",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}
    }
  })
end)

test("parse ~a ** b (bitwise not before **)", function()
  assert_parse_ok("~a ** b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}
    }
  })
end)

test("parse -(2 ** 3) (parens override unary)", function()
  assert_parse_ok("-(2 ** 3);", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "-",
      argument = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

test("parse 2 ** -3 (unary in exponent)", function()
  assert_parse_ok("2 ** -3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "NumberLiteral", value = 2},
      right = {type = "UnaryExpression", operator = "-",
        argument = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

test("parse ++x ** 2 (prefix increment before **)", function()
  assert_parse_ok("++x ** 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = true},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse x++ ** 2 (postfix before **)", function()
  assert_parse_ok("x++ ** 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse 2 ** x++ (postfix in exponent)", function()
  assert_parse_ok("2 ** x++;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "NumberLiteral", value = 2},
      right = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false}}
    }
  })
end)

test("parse ** in assignment RHS", function()
  assert_parse_ok("x = 2 ** 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

test("parse ** in ternary test", function()
  assert_parse_ok("a ** b ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "**",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  })
end)

test("parse ** in ternary branch", function()
  assert_parse_ok("c ? 2 ** 3 : 4;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "c"},
      consequent = {type = "BinaryExpression", operator = "**",
        left = {type = "NumberLiteral", value = 2},
        right = {type = "NumberLiteral", value = 3}},
      alternate = {type = "NumberLiteral", value = 4}}
    }
  })
end)

test("parse **= with + on RHS", function()
  assert_parse_ok("x **= 1 + 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "+",
        left = {type = "NumberLiteral", value = 1},
        right = {type = "NumberLiteral", value = 2}}}
    }
  })
end)

test("parse (x + 1) ** 2 (complex base)", function()
  assert_parse_ok("(x + 1) ** 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 1}},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse 2 ** (x + 1) (complex exponent)", function()
  assert_parse_ok("2 ** (x + 1);", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "NumberLiteral", value = 2},
      right = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 1}}}
    }
  })
end)

test("parse UnaryExpression !", function()
  assert_parse_ok("!x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "!",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse UnaryExpression -", function()
  assert_parse_ok("-x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "-",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse UnaryExpression +", function()
  assert_parse_ok("+x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "+",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse unary + on literal", function()
  assert_parse_ok("+42;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "+",
      argument = {type = "NumberLiteral", value = 42}}}
  })
end)

test("parse unary + on string", function()
  assert_parse_ok('+"5";', {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "+",
      argument = {type = "StringLiteral", value = "5"}}}
  })
end)

test("parse nested unary +!x", function()
  assert_parse_ok("+!x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "+",
      argument = {type = "UnaryExpression", operator = "!",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse nested unary !+x", function()
  assert_parse_ok("!+x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "!",
      argument = {type = "UnaryExpression", operator = "+",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse + + x (space-separated double unary plus)", function()
  assert_parse_ok("+ + x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "+",
      argument = {type = "UnaryExpression", operator = "+",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse unary + in binary context", function()
  assert_parse_ok("1 + +x;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "NumberLiteral", value = 1},
      right = {type = "UnaryExpression", operator = "+",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse unary + in ternary", function()
  assert_parse_ok("a ? +b : -c;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "UnaryExpression", operator = "+",
        argument = {type = "Identifier", name = "b"}},
      alternate = {type = "UnaryExpression", operator = "-",
        argument = {type = "Identifier", name = "c"}}}}
  })
end)

test("parse ++x still parsed as UpdateExpression (not double unary +)", function()
  assert_parse_ok("++x;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "Identifier", name = "x"}, prefix = true}}
  })
end)

test("error: unary + with no operand", function()
  assert_parse_fail("let a = +;", nil)
end)

test("error: unary + at end of input", function()
  assert_parse_fail("+", nil)
end)

test("parse prefix ++x", function()
  assert_parse_ok("++x;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "Identifier", name = "x"}, prefix = true}}
  })
end)

test("parse prefix --x", function()
  assert_parse_ok("--x;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "--",
      argument = {type = "Identifier", name = "x"}, prefix = true}}
  })
end)

test("parse nested prefix ++ ++ x", function()
  assert_parse_ok("++ ++ x;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = true},
      prefix = true}}
  })
end)

test("parse prefix ++ on member expression", function()
  assert_parse_ok("++a.b;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "a"},
        property = {type = "Identifier", name = "b"},
        computed = false},
      prefix = true}}
  })
end)

test("parse prefix -- on computed member", function()
  assert_parse_ok("--a[b];", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "--",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "a"},
        property = {type = "Identifier", name = "b"},
        computed = true},
      prefix = true}}
  })
end)

test("parse prefix ++ on chained member a.b.c", function()
  assert_parse_ok("++a.b.c;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "MemberExpression",
        object = {type = "MemberExpression",
          object = {type = "Identifier", name = "a"},
          property = {type = "Identifier", name = "b"},
          computed = false},
        property = {type = "Identifier", name = "c"},
        computed = false},
      prefix = true}}
  })
end)

test("parse !++x (unary NOT then prefix)", function()
  assert_parse_ok("!++x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "!",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = true}}}
  })
end)

test("parse --x as return value", function()
  assert_parse_ok("function f() { return --x; }", {
    {type = "FunctionDeclaration", name = "f",
      params = {},
      body = {type = "BlockStatement", body = {
        {type = "ReturnStatement",
          argument = {type = "UpdateExpression", operator = "--",
            argument = {type = "Identifier", name = "x"}, prefix = true}}
      }}}
  })
end)

test("parse postfix x++", function()
  assert_parse_ok("x++;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "Identifier", name = "x"}, prefix = false}}
  })
end)

test("parse postfix x--", function()
  assert_parse_ok("x--;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "--",
      argument = {type = "Identifier", name = "x"}, prefix = false}}
  })
end)

test("parse postfix on member a.b++", function()
  assert_parse_ok("a.b++;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "a"},
        property = {type = "Identifier", name = "b"},
        computed = false},
      prefix = false}}
  })
end)

test("parse postfix on computed member a[b]--", function()
  assert_parse_ok("a[b]--;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "--",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "a"},
        property = {type = "Identifier", name = "b"},
        computed = true},
      prefix = false}}
  })
end)

test("parse postfix on call f()++", function()
  assert_parse_ok("f()++;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "CallExpression",
        callee = {type = "Identifier", name = "f"},
        arguments = {}},
      prefix = false}}
  })
end)

test("parse postfix on chained member a.b.c++", function()
  assert_parse_ok("a.b.c++;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "MemberExpression",
        object = {type = "MemberExpression",
          object = {type = "Identifier", name = "a"},
          property = {type = "Identifier", name = "b"},
          computed = false},
        property = {type = "Identifier", name = "c"},
        computed = false},
      prefix = false}}
  })
end)

test("parse postfix on chained call+member", function()
  assert_parse_ok("obj.method()++;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "CallExpression",
        callee = {type = "MemberExpression",
          object = {type = "Identifier", name = "obj"},
          property = {type = "Identifier", name = "method"},
          computed = false},
        arguments = {}},
      prefix = false}}
  })
end)

test("parse x++ + y (postfix in binary)", function()
  assert_parse_ok("x++ + y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse x + ++y (prefix in binary)", function()
  assert_parse_ok("x + ++y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "Identifier", name = "x"},
      right = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "y"}, prefix = true}}}
  })
end)

test("parse x++ + ++y (both sides)", function()
  assert_parse_ok("x++ + ++y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "y"}, prefix = true}}}
  })
end)

test("parse x+++y maximal munch: (x++) + y", function()
  assert_parse_ok("x+++y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse x---y maximal munch: (x--) - y", function()
  assert_parse_ok("x---y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "-",
      left = {type = "UpdateExpression", operator = "--",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse a + b++ * c (postfix binds tighter)", function()
  assert_parse_ok("a + b++ * c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "Identifier", name = "a"},
      right = {type = "BinaryExpression", operator = "*",
        left = {type = "UpdateExpression", operator = "++",
          argument = {type = "Identifier", name = "b"}, prefix = false},
        right = {type = "Identifier", name = "c"}}}}
  })
end)

test("parse -x++ (unary minus on postfix)", function()
  assert_parse_ok("-x++;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "-",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false}}}
  })
end)

T.summary()
