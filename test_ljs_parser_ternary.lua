local T = require("ljs_test")
local P = require("ljs_test_parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs

-- TERNARY OPERATOR TESTS
-- ============================================================================

test("tokenize ?", function()
  assert_tok("x ? 1 : 0", 2, "?")
end)

test("parse basic ternary", function()
  assert_parse_ok("x ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  })
end)

test("parse nested ternary in consequent", function()
  assert_parse_ok("a ? b ? 1 : 2 : 3;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "ConditionalExpression",
        test = {type = "Identifier", name = "b"},
        consequent = {type = "NumberLiteral", value = 1},
        alternate = {type = "NumberLiteral", value = 2}},
      alternate = {type = "NumberLiteral", value = 3}}
    }
  })
end)

test("parse nested ternary in alternate", function()
  assert_parse_ok("a ? 1 : b ? 2 : 3;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "ConditionalExpression",
        test = {type = "Identifier", name = "b"},
        consequent = {type = "NumberLiteral", value = 2},
        alternate = {type = "NumberLiteral", value = 3}}}
    }
  })
end)

test("parse ternary precedence: || binds tighter than ?", function()
  assert_parse_ok("a || b ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "||",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  })
end)

test("parse ternary precedence: && binds tighter than ?", function()
  assert_parse_ok("a && b ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "&&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  })
end)

test("parse ternary precedence: || inside consequent", function()
  assert_parse_ok("a ? b || c : d;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "BinaryExpression", operator = "||",
        left = {type = "Identifier", name = "b"},
        right = {type = "Identifier", name = "c"}},
      alternate = {type = "Identifier", name = "d"}}
    }
  })
end)

test("parse ternary precedence: assignment has lower precedence", function()
  assert_parse_ok("x = a ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "ConditionalExpression",
        test = {type = "Identifier", name = "a"},
        consequent = {type = "NumberLiteral", value = 1},
        alternate = {type = "NumberLiteral", value = 0}}}
    }
  })
end)

test("parse ternary with assignment in consequent", function()
  assert_parse_ok("a ? x = 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "BinaryExpression", operator = "=",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 1}},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  })
end)

test("parse ternary with assignment in alternate", function()
  assert_parse_ok("a ? 1 : x = 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "BinaryExpression", operator = "=",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 0}}}
    }
  })
end)

test("parse ternary in variable init", function()
  assert_parse_ok("let x = a ? 1 : 0;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "x"},
        init = {type = "ConditionalExpression",
          test = {type = "Identifier", name = "a"},
          consequent = {type = "NumberLiteral", value = 1},
          alternate = {type = "NumberLiteral", value = 0}}}
    }}
  })
end)

test("parse ternary in return", function()
  local ast = ljs.parse("function f(x) { return x ? 1 : 0; }")
  local ret = ast.body[1].body.body[1]
  assert_eq(ret.type, "ReturnStatement")
  assert_eq(ret.argument.type, "ConditionalExpression")
  assert_eq(ret.argument.test.name, "x")
  assert_eq(ret.argument.consequent.value, 1)
  assert_eq(ret.argument.alternate.value, 0)
end)

test("parse ternary in function args", function()
  assert_parse_ok("f(x ? 1 : 0);", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {
        {type = "ConditionalExpression",
          test = {type = "Identifier", name = "x"},
          consequent = {type = "NumberLiteral", value = 1},
          alternate = {type = "NumberLiteral", value = 0}}
      }}
    }
  })
end)

test("parse ternary in object value", function()
  assert_parse_ok("let obj = {a: x ? 1 : 0};", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "obj"},
        init = {type = "ObjectExpression", properties = {
          {type = "Property",
            key = {type = "Identifier", name = "a"},
            value = {type = "ConditionalExpression",
              test = {type = "Identifier", name = "x"},
              consequent = {type = "NumberLiteral", value = 1},
              alternate = {type = "NumberLiteral", value = 0}},
            computed = false}
        }}
      }
    }}
  })
end)

test("parse ternary in array element", function()
  assert_parse_ok("let arr = [x ? 1 : 0];", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "arr"},
        init = {type = "ArrayExpression", elements = {
          {type = "ConditionalExpression",
            test = {type = "Identifier", name = "x"},
            consequent = {type = "NumberLiteral", value = 1},
            alternate = {type = "NumberLiteral", value = 0}}
        }}
      }
    }}
  })
end)

test("parse ternary in for-loop init", function()
  local ast = ljs.parse("for (let i = x ? 0 : 1; i < 10; i += 1) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.init.declarations[1].init.type, "ConditionalExpression")
  assert_eq(f.init.declarations[1].init.test.name, "x")
end)

test("parse ternary as expression statement", function()
  assert_parse_ok("x ? f() : g();", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "CallExpression",
        callee = {type = "Identifier", name = "f"},
        arguments = {}},
      alternate = {type = "CallExpression",
        callee = {type = "Identifier", name = "g"},
        arguments = {}}}
    }
  })
end)

test("parse ternary with member expressions", function()
  assert_parse_ok("a ? obj.x : arr[0];", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "x"},
        computed = false},
      alternate = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "NumberLiteral", value = 0},
        computed = true}}
    }
  })
end)

test("parse ternary with unary", function()
  assert_parse_ok("a ? !b : -c;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "UnaryExpression", operator = "!",
        argument = {type = "Identifier", name = "b"}},
      alternate = {type = "UnaryExpression", operator = "-",
        argument = {type = "Identifier", name = "c"}}}
    }
  })
end)

test("parse ternary with compound assignment in branches", function()
  assert_parse_ok("a ? x += 1 : x -= 1;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "a"},
      consequent = {type = "BinaryExpression", operator = "+=",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 1}},
      alternate = {type = "BinaryExpression", operator = "-=",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 1}}}
    }
  })
end)

test("parse ternary with arithmetic in branches", function()
  assert_parse_ok("a + b ? c * d : e / f;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "BinaryExpression", operator = "*",
        left = {type = "Identifier", name = "c"},
        right = {type = "Identifier", name = "d"}},
      alternate = {type = "BinaryExpression", operator = "/",
        left = {type = "Identifier", name = "e"},
        right = {type = "Identifier", name = "f"}}}
    }
  })
end)

test("parse parenthesized ternary condition", function()
  assert_parse_ok("(a || b) ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "||",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}
    }
  })
end)

test("parse ternary with string and boolean branches", function()
  assert_parse_ok("x ? 'yes' : false;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "StringLiteral", value = "yes"},
      alternate = {type = "BooleanLiteral", value = false}}
    }
  })
end)

test("parse ternary with null alternate", function()
  assert_parse_ok("x ? y : null;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "Identifier", name = "y"},
      alternate = {type = "NullLiteral"}}
    }
  })
end)

test("parse ternary with undefined alternate", function()
  assert_parse_ok("x ? y : undefined;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "x"},
      consequent = {type = "Identifier", name = "y"},
      alternate = {type = "UndefinedLiteral"}}
    }
  })
end)

-- Negative tests

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
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {}}
    }
  })
end)

test("parse CallExpression with args", function()
  assert_parse_ok("f(a, b);", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {
        {type = "Identifier", name = "a"},
        {type = "Identifier", name = "b"}
      }}
    }
  })
end)

test("parse MemberExpression dot", function()
  assert_parse_ok("obj.prop;", {
    {type = "ExpressionStatement", expression = {type = "MemberExpression",
      object = {type = "Identifier", name = "obj"},
      property = {type = "Identifier", name = "prop"},
      computed = false}
    }
  })
end)

test("parse MemberExpression bracket", function()
  assert_parse_ok("obj[prop];", {
    {type = "ExpressionStatement", expression = {type = "MemberExpression",
      object = {type = "Identifier", name = "obj"},
      property = {type = "Identifier", name = "prop"},
      computed = true}
    }
  })
end)

test("parse chained calls: obj.method().another()", function()
  assert_parse_ok("obj.method().another();", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "MemberExpression",
        object = {type = "CallExpression",
          callee = {type = "MemberExpression",
            object = {type = "Identifier", name = "obj"},
            property = {type = "Identifier", name = "method"},
            computed = false},
          arguments = {}},
        property = {type = "Identifier", name = "another"},
        computed = false},
      arguments = {}}
    }
  })
end)

test("parse chained members: a.b.c.d", function()
  assert_parse_ok("a.b.c.d;", {
    {type = "ExpressionStatement", expression = {type = "MemberExpression",
      object = {type = "MemberExpression",
        object = {type = "MemberExpression",
          object = {type = "Identifier", name = "a"},
          property = {type = "Identifier", name = "b"},
          computed = false},
        property = {type = "Identifier", name = "c"},
        computed = false},
      property = {type = "Identifier", name = "d"},
      computed = false}
    }
  })
end)

test("parse ArrayExpression non-empty", function()
  assert_parse_ok("[1, 2, 3];", {
    {type = "ExpressionStatement", expression = {type = "ArrayExpression", elements = {
      {type = "NumberLiteral", value = 1},
      {type = "NumberLiteral", value = 2},
      {type = "NumberLiteral", value = 3}
    }}}
  })
end)

test("parse ArrayExpression empty", function()
  assert_parse_ok("[];", {
    {type = "ExpressionStatement", expression = {type = "ArrayExpression", elements = {}}}
  })
end)

test("parse ObjectExpression non-empty", function()
  assert_parse_ok("let o = {a: 1, b: 2};", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "o"},
        init = {type = "ObjectExpression", properties = {
          {type = "Property", key = {type = "Identifier", name = "a"},
            value = {type = "NumberLiteral", value = 1}, computed = false},
          {type = "Property", key = {type = "Identifier", name = "b"},
            value = {type = "NumberLiteral", value = 2}, computed = false}
        }}
      }
    }}
  })
end)

test("parse ObjectExpression empty", function()
  assert_parse_ok("let o = {};", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "o"},
        init = {type = "ObjectExpression", properties = {}}}
    }}
  })
end)

test("parse anonymous FunctionExpression", function()
  assert_parse_ok("let f = function(x) { return x; };", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "f"},
        init = {type = "FunctionExpression", params = {
          {type = "Identifier", name = "x"}
        }, body = {type = "BlockStatement", body = {
          {type = "ReturnStatement", argument = {type = "Identifier", name = "x"}}
        }}}
      }
    }}
  })
end)

test("parse named FunctionExpression", function()
  assert_parse_ok("let f = function fact(n) { return n; };", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator", name = {type = "Identifier", name = "f"},
        init = {type = "FunctionExpression", name = "fact", params = {
          {type = "Identifier", name = "n"}
        }, body = {type = "BlockStatement", body = {
          {type = "ReturnStatement", argument = {type = "Identifier", name = "n"}}
        }}}
      }
    }}
  })
end)

test("parse arrow function: single param expression body", function()
  assert_parse_ok("x => x + 1;", {
    {type = "ExpressionStatement", expression = {type = "ArrowFunctionExpression",
      params = {{type = "Identifier", name = "x"}},
      body = {type = "BlockStatement", body = {
        {type = "ReturnStatement", argument = {type = "BinaryExpression", operator = "+",
          left = {type = "Identifier", name = "x"},
          right = {type = "NumberLiteral", value = 1}}
        }
      }}}
    }
  })
end)

test("parse arrow function: multi param", function()
  assert_parse_ok("(a, b) => a + b;", {
    {type = "ExpressionStatement", expression = {type = "ArrowFunctionExpression",
      params = {
        {type = "Identifier", name = "a"},
        {type = "Identifier", name = "b"}
      },
      body = {type = "BlockStatement", body = {
        {type = "ReturnStatement", argument = {type = "BinaryExpression", operator = "+",
          left = {type = "Identifier", name = "a"},
          right = {type = "Identifier", name = "b"}}
        }
      }}}
    }
  })
end)

test("parse arrow function: block body", function()
  assert_parse_ok("(x) => { return x; };", {
    {type = "ExpressionStatement", expression = {type = "ArrowFunctionExpression",
      params = {{type = "Identifier", name = "x"}},
      body = {type = "BlockStatement", body = {
        {type = "ReturnStatement", argument = {type = "Identifier", name = "x"}}
      }}}
    }
  })
end)

test("parse parenthesized expression", function()
  assert_parse_ok("(1 + 2);", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "NumberLiteral", value = 1},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse console.log", function()
  assert_parse_ok('console.log("hello");', {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "MemberExpression",
        object = {type = "Identifier", name = "console"},
        property = {type = "Identifier", name = "log"},
        computed = false},
      arguments = {{type = "StringLiteral", value = "hello"}}}
    }
  })
end)

T.summary()
