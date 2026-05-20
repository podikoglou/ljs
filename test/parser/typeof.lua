local T = require("ljs_test")
local P = require("test.helpers.parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs

-- TYPEOF EXPRESSION TESTS
-- ============================================================================

-- Tokenizer
test("tokenize typeof", function()
  assert_tok("typeof x", 1, "typeof", "typeof")
end)

test("tokenize typeof in expression", function()
  assert_tok("typeof obj.x;", 1, "typeof", "typeof")
  assert_tok("typeof obj.x;", 2, "Identifier", "obj")
end)

-- Basic parsing
test("parse typeof identifier", function()
  assert_parse_ok("typeof x;", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
    },
  })
end)

test("parse typeof member expression dot", function()
  assert_parse_ok("typeof obj.prop;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "obj" },
          property = { type = "Identifier", name = "prop" },
          computed = false,
        },
      },
    },
  })
end)

test("parse typeof member expression bracket", function()
  assert_parse_ok("typeof obj[key];", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "obj" },
          property = { type = "Identifier", name = "key" },
          computed = true,
        },
      },
    },
  })
end)

test("parse typeof computed member with expression", function()
  assert_parse_ok("typeof obj[i + 1];", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "obj" },
          property = {
            type = "BinaryExpression",
            operator = "+",
            left = { type = "Identifier", name = "i" },
            right = { type = "NumberLiteral", value = 1 },
          },
          computed = true,
        },
      },
    },
  })
end)

test("parse typeof nested member a.b.c", function()
  assert_parse_ok("typeof a.b.c;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = {
            type = "MemberExpression",
            object = { type = "Identifier", name = "a" },
            property = { type = "Identifier", name = "b" },
            computed = false,
          },
          property = { type = "Identifier", name = "c" },
          computed = false,
        },
      },
    },
  })
end)

test("parse typeof call result member", function()
  assert_parse_ok("typeof getObj().prop;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = {
            type = "CallExpression",
            callee = { type = "Identifier", name = "getObj" },
            arguments = {},
          },
          property = { type = "Identifier", name = "prop" },
          computed = false,
        },
      },
    },
  })
end)

-- typeof with various operand types
test("parse typeof number literal", function()
  assert_parse_ok("typeof 42;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = { type = "NumberLiteral", value = 42 },
      },
    },
  })
end)

test("parse typeof string literal", function()
  assert_parse_ok('typeof "hello";', {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = { type = "StringLiteral", value = "hello" },
      },
    },
  })
end)

test("parse typeof boolean", function()
  assert_parse_ok("typeof true;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = { type = "BooleanLiteral", value = true },
      },
    },
  })
end)

test("parse typeof null", function()
  assert_parse_ok("typeof null;", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "NullLiteral" } },
    },
  })
end)

test("parse typeof undefined", function()
  assert_parse_ok("typeof undefined;", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "UndefinedLiteral" } },
    },
  })
end)

test("parse typeof parenthesized expression", function()
  assert_parse_ok("typeof (x);", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
    },
  })
end)

test("parse typeof array literal", function()
  assert_parse_ok("typeof [1, 2];", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "ArrayExpression",
          elements = {
            { type = "NumberLiteral", value = 1 },
            { type = "NumberLiteral", value = 2 },
          },
        },
      },
    },
  })
end)

test("parse typeof object literal", function()
  assert_parse_ok("typeof {a: 1};", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "ObjectExpression",
          properties = {
            {
              type = "Property",
              key = { type = "Identifier", name = "a" },
              value = { type = "NumberLiteral", value = 1 },
              computed = false,
            },
          },
        },
      },
    },
  })
end)

-- typeof with other unary operators
test("parse typeof !x (typeof of unary NOT)", function()
  assert_parse_ok("typeof !x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "UnaryExpression",
          operator = "!",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse typeof -x (typeof of unary minus)", function()
  assert_parse_ok("typeof -x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "UnaryExpression",
          operator = "-",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse typeof ~x (typeof of bitwise NOT)", function()
  assert_parse_ok("typeof ~x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "UnaryExpression",
          operator = "~",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse !typeof x (unary NOT of typeof)", function()
  assert_parse_ok("!typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UnaryExpression",
        operator = "!",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse -typeof x (unary minus of typeof)", function()
  assert_parse_ok("-typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UnaryExpression",
        operator = "-",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse ~typeof x (bitwise NOT of typeof)", function()
  assert_parse_ok("~typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UnaryExpression",
        operator = "~",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

-- typeof with update expressions
test("parse typeof x++ (typeof of postfix update)", function()
  assert_parse_ok("typeof x++;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "UpdateExpression",
          operator = "++",
          argument = { type = "Identifier", name = "x" },
          prefix = false,
        },
      },
    },
  })
end)

test("parse typeof ++x (typeof of prefix update)", function()
  assert_parse_ok("typeof ++x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "UpdateExpression",
          operator = "++",
          argument = { type = "Identifier", name = "x" },
          prefix = true,
        },
      },
    },
  })
end)

test("parse ++typeof x (prefix increment of typeof result)", function()
  assert_parse_ok("++typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UpdateExpression",
        operator = "++",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
        prefix = true,
      },
    },
  })
end)

-- typeof in binary expressions
test("parse typeof x + 1 (typeof in arithmetic)", function()
  assert_parse_ok("typeof x + 1;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "+",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "NumberLiteral", value = 1 },
      },
    },
  })
end)

test("parse typeof x === 'number' (typeof in comparison)", function()
  assert_parse_ok("typeof x === 'number';", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "===",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "StringLiteral", value = "number" },
      },
    },
  })
end)

test("parse typeof x && typeof y (typeof in logical AND)", function()
  assert_parse_ok("typeof x && typeof y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "&&",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
      },
    },
  })
end)

test("parse typeof x || typeof y (typeof in logical OR)", function()
  assert_parse_ok("typeof x || typeof y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "||",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
      },
    },
  })
end)

-- typeof in ternary
test("parse typeof x ? 1 : 0 (typeof in ternary condition)", function()
  assert_parse_ok("typeof x ? 1 : 0;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "ConditionalExpression",
        test = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        consequent = { type = "NumberLiteral", value = 1 },
        alternate = { type = "NumberLiteral", value = 0 },
      },
    },
  })
end)

test("parse flag ? typeof x : typeof y (typeof in ternary branches)", function()
  assert_parse_ok("flag ? typeof x : typeof y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "ConditionalExpression",
        test = { type = "Identifier", name = "flag" },
        consequent = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
        alternate = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "y" },
        },
      },
    },
  })
end)

-- typeof in assignment
test("parse result = typeof x (typeof as assignment RHS)", function()
  assert_parse_ok("result = typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "=",
        left = { type = "Identifier", name = "result" },
        right = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
      },
    },
  })
end)

-- typeof in variable declaration
test("parse let t = typeof obj.prop (typeof in variable init)", function()
  assert_parse_ok("let t = typeof obj.prop;", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "t" },
          init = {
            type = "TypeofExpression",
            argument = {
              type = "MemberExpression",
              object = { type = "Identifier", name = "obj" },
              property = { type = "Identifier", name = "prop" },
              computed = false,
            },
          },
        },
      },
    },
  })
end)

-- typeof in control flow
test("parse typeof in if condition", function()
  assert_parse_ok("if (typeof x) { y; }", {
    {
      type = "IfStatement",
      test = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
      consequent = {
        type = "BlockStatement",
        body = {
          { type = "ExpressionStatement", expression = { type = "Identifier", name = "y" } },
        },
      },
      alternate = nil,
    },
  })
end)

test("parse typeof in while condition", function()
  assert_parse_ok("while (typeof x) { y; }", {
    {
      type = "WhileStatement",
      test = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
      body = {
        type = "BlockStatement",
        body = {
          { type = "ExpressionStatement", expression = { type = "Identifier", name = "y" } },
        },
      },
    },
  })
end)

test("parse typeof in for init", function()
  assert_parse_ok("for (typeof x; y; z) {}", {
    {
      type = "ForStatement",
      init = {
        type = "ExpressionStatement",
        expression = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
      test = { type = "Identifier", name = "y" },
      update = { type = "Identifier", name = "z" },
      body = { type = "BlockStatement", body = {} },
    },
  })
end)

test("parse typeof in return statement", function()
  assert_parse_ok("function f() { return typeof x; }", {
    {
      type = "FunctionDeclaration",
      name = "f",
      params = {},
      body = {
        type = "BlockStatement",
        body = {
          {
            type = "ReturnStatement",
            argument = {
              type = "TypeofExpression",
              argument = { type = "Identifier", name = "x" },
            },
          },
        },
      },
    },
  })
end)

-- nested typeof
test("parse typeof typeof x (double typeof)", function()
  assert_parse_ok("typeof typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse typeof typeof typeof x (triple typeof)", function()
  assert_parse_ok("typeof typeof typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "TypeofExpression",
          argument = {
            type = "TypeofExpression",
            argument = { type = "Identifier", name = "x" },
          },
        },
      },
    },
  })
end)

-- typeof with function expression operand
test("parse typeof function expression", function()
  assert_parse_ok("typeof function() {};", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "FunctionExpression",
          name = nil,
          params = {},
          body = { type = "BlockStatement", body = {} },
        },
      },
    },
  })
end)

-- typeof with arrow function operand
test("parse typeof arrow function", function()
  assert_parse_ok("typeof x => x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "ArrowFunctionExpression",
          params = { { type = "Identifier", name = "x" } },
          body = {
            type = "BlockStatement",
            body = {
              { type = "ReturnStatement", argument = { type = "Identifier", name = "x" } },
            },
          },
        },
      },
    },
  })
end)

-- typeof in array element
test("parse typeof as array element", function()
  assert_parse_ok("[typeof x];", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "ArrayExpression",
        elements = {
          { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        },
      },
    },
  })
end)

-- typeof in object value
test("parse typeof as object property value", function()
  assert_parse_ok("({a: typeof x});", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "ObjectExpression",
        properties = {
          {
            type = "Property",
            key = { type = "Identifier", name = "a" },
            value = {
              type = "TypeofExpression",
              argument = { type = "Identifier", name = "x" },
            },
            computed = false,
          },
        },
      },
    },
  })
end)

-- typeof in switch case
test("parse typeof in switch case", function()
  assert_parse_ok("switch (x) { case 1: typeof y; }", {
    {
      type = "SwitchStatement",
      discriminant = { type = "Identifier", name = "x" },
      cases = {
        {
          type = "SwitchCase",
          test = { type = "NumberLiteral", value = 1 },
          consequent = {
            {
              type = "ExpressionStatement",
              expression = {
                type = "TypeofExpression",
                argument = { type = "Identifier", name = "y" },
              },
            },
          },
        },
      },
    },
  })
end)

-- typeof with call expression operand
test("parse typeof call expression", function()
  assert_parse_ok("typeof f();", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "CallExpression",
          callee = { type = "Identifier", name = "f" },
          arguments = {},
        },
      },
    },
  })
end)

test("parse typeof call with args", function()
  assert_parse_ok("typeof f(a, b);", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "CallExpression",
          callee = { type = "Identifier", name = "f" },
          arguments = {
            { type = "Identifier", name = "a" },
            { type = "Identifier", name = "b" },
          },
        },
      },
    },
  })
end)

-- typeof with delete interaction
test("parse typeof delete x (typeof of delete)", function()
  assert_parse_ok("typeof delete x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "DeleteExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

test("parse delete typeof x (delete of typeof)", function()
  assert_parse_ok("delete typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "DeleteExpression",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

-- typeof in compound assignment RHS
test("parse typeof in compound assignment RHS", function()
  assert_parse_ok("x += typeof y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "+=",
        left = { type = "Identifier", name = "x" },
        right = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
      },
    },
  })
end)

-- typeof in bitwise expression
test("parse typeof in bitwise expression", function()
  assert_parse_ok("typeof x & typeof y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "&",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
      },
    },
  })
end)

-- typeof in comparison chain
test("parse typeof in comparison chain", function()
  assert_parse_ok("typeof x < typeof y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "<",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
      },
    },
  })
end)

-- precedence: typeof binds tighter than binary ops
test("parse precedence: typeof x * y (typeof x then multiply)", function()
  assert_parse_ok("typeof x * y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "*",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "Identifier", name = "y" },
      },
    },
  })
end)

test("parse precedence: typeof x ** y (typeof x then exponentiate)", function()
  assert_parse_ok("typeof x ** y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "**",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "Identifier", name = "y" },
      },
    },
  })
end)

-- typeof inside parentheses grouping
test("parse (typeof x) + y", function()
  assert_parse_ok("(typeof x) + y;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "+",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "Identifier", name = "y" },
      },
    },
  })
end)

-- typeof is a keyword not an identifier
test("typeof is a keyword not an identifier", function()
  assert_tok("typeof", 1, "typeof", "typeof")
  assert_tok("typeof", 1, "typeof")
end)

-- typeof as statement without semicolon (ASI)
test("parse typeof x without semicolon (EOF)", function()
  assert_parse_ok("typeof x", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
    },
  })
end)

test("parse typeof x followed by let (ASI)", function()
  assert_parse_ok("typeof x\nlet y = 1;", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
    },
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "y" },
          init = { type = "NumberLiteral", value = 1 },
        },
      },
    },
  })
end)

-- multiple typeof in sequence as statements
test("parse multiple typeof statements", function()
  assert_parse_ok("typeof x; typeof y; typeof z;", {
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
    },
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
    },
    {
      type = "ExpressionStatement",
      expression = { type = "TypeofExpression", argument = { type = "Identifier", name = "z" } },
    },
  })
end)

-- typeof in do-while
test("parse typeof in do-while body", function()
  assert_parse_ok("do { typeof x; } while (y);", {
    {
      type = "DoWhileStatement",
      body = {
        type = "BlockStatement",
        body = {
          {
            type = "ExpressionStatement",
            expression = {
              type = "TypeofExpression",
              argument = { type = "Identifier", name = "x" },
            },
          },
        },
      },
      test = { type = "Identifier", name = "y" },
    },
  })
end)

-- typeof with string computed member
test("parse typeof obj['key']", function()
  assert_parse_ok("typeof obj['key'];", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "obj" },
          property = { type = "StringLiteral", value = "key" },
          computed = true,
        },
      },
    },
  })
end)

-- typeof with number computed member
test("parse typeof arr[0]", function()
  assert_parse_ok("typeof arr[0];", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "arr" },
          property = { type = "NumberLiteral", value = 0 },
          computed = true,
        },
      },
    },
  })
end)

-- typeof in throw
test("parse throw typeof x", function()
  assert_parse_ok("throw typeof x;", {
    {
      type = "ThrowStatement",
      argument = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
    },
  })
end)

-- typeof with parenthesized multi-param arrow function
test("parse typeof parenthesized arrow function", function()
  assert_parse_ok("typeof (a, b) => a;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "ArrowFunctionExpression",
          params = {
            { type = "Identifier", name = "a" },
            { type = "Identifier", name = "b" },
          },
          body = {
            type = "BlockStatement",
            body = {
              { type = "ReturnStatement", argument = { type = "Identifier", name = "a" } },
            },
          },
        },
      },
    },
  })
end)

-- typeof with named function expression
test("parse typeof named function expression", function()
  assert_parse_ok("typeof function foo() {};", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "FunctionExpression",
          name = "foo",
          params = {},
          body = { type = "BlockStatement", body = {} },
        },
      },
    },
  })
end)

-- typeof in for-of expression left
test("parse for-of with typeof expression left (syntactically accepted)", function()
  assert_parse_ok("for (typeof x of arr) {}", {
    {
      type = "ForOfStatement",
      left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
      right = { type = "Identifier", name = "arr" },
      body = { type = "BlockStatement", body = {} },
    },
  })
end)

-- typeof in for-in expression left
test("parse for-in with typeof expression left (syntactically accepted)", function()
  assert_parse_ok("for (typeof x in obj) {}", {
    {
      type = "ForInStatement",
      left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
      right = { type = "Identifier", name = "obj" },
      body = { type = "BlockStatement", body = {} },
    },
  })
end)

-- common JS pattern: typeof x !== "undefined"
test("parse typeof x !== 'undefined' (common guard pattern)", function()
  assert_parse_ok("typeof x !== 'undefined';", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "!==",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "StringLiteral", value = "undefined" },
      },
    },
  })
end)

-- typeof in if with typeof guard
test("parse if typeof guard pattern", function()
  assert_parse_ok("if (typeof x === 'number') { x; }", {
    {
      type = "IfStatement",
      test = {
        type = "BinaryExpression",
        operator = "===",
        left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        right = { type = "StringLiteral", value = "number" },
      },
      consequent = {
        type = "BlockStatement",
        body = {
          { type = "ExpressionStatement", expression = { type = "Identifier", name = "x" } },
        },
      },
      alternate = nil,
    },
  })
end)

-- typeof in ternary with string comparison
test("parse typeof x === 'string' ? x : '' (common pattern)", function()
  assert_parse_ok("typeof x === 'string' ? x : '';", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "ConditionalExpression",
        test = {
          type = "BinaryExpression",
          operator = "===",
          left = {
            type = "TypeofExpression",
            argument = { type = "Identifier", name = "x" },
          },
          right = { type = "StringLiteral", value = "string" },
        },
        consequent = { type = "Identifier", name = "x" },
        alternate = { type = "StringLiteral", value = "" },
      },
    },
  })
end)

-- typeof with + prefix (valid but weird)
test("parse +typeof x (unary plus of typeof)", function()
  assert_parse_ok("+typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UnaryExpression",
        operator = "+",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
      },
    },
  })
end)

-- typeof result in postfix update
test("parse typeof x-- (typeof of postfix decrement)", function()
  assert_parse_ok("typeof x--;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "UpdateExpression",
          operator = "--",
          argument = { type = "Identifier", name = "x" },
          prefix = false,
        },
      },
    },
  })
end)

-- typeof result in prefix decrement
test("parse --typeof x (prefix decrement of typeof)", function()
  assert_parse_ok("--typeof x;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "UpdateExpression",
        operator = "--",
        argument = {
          type = "TypeofExpression",
          argument = { type = "Identifier", name = "x" },
        },
        prefix = true,
      },
    },
  })
end)

-- typeof in complex expression
test("parse typeof x + typeof y === 'numbernumber'", function()
  assert_parse_ok("typeof x + typeof y === 'numbernumber';", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "BinaryExpression",
        operator = "===",
        left = {
          type = "BinaryExpression",
          operator = "+",
          left = { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
          right = { type = "TypeofExpression", argument = { type = "Identifier", name = "y" } },
        },
        right = { type = "StringLiteral", value = "numbernumber" },
      },
    },
  })
end)

-- typeof in call arguments
test("parse typeof in call argument", function()
  assert_parse_ok("f(typeof x);", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "CallExpression",
        callee = { type = "Identifier", name = "f" },
        arguments = {
          { type = "TypeofExpression", argument = { type = "Identifier", name = "x" } },
        },
      },
    },
  })
end)

-- typeof in member expression object
test("parse typeof x.length (typeof then member access)", function()
  assert_parse_ok("typeof x.length;", {
    {
      type = "ExpressionStatement",
      expression = {
        type = "TypeofExpression",
        argument = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "x" },
          property = { type = "Identifier", name = "length" },
          computed = false,
        },
      },
    },
  })
end)

-- typeof in try-catch
test("parse typeof in try-catch", function()
  assert_parse_ok("try { typeof x; } catch (e) { y; }", {
    {
      type = "TryStatement",
      block = {
        type = "BlockStatement",
        body = {
          {
            type = "ExpressionStatement",
            expression = {
              type = "TypeofExpression",
              argument = { type = "Identifier", name = "x" },
            },
          },
        },
      },
      handler = {
        type = "CatchClause",
        param = { type = "Identifier", name = "e" },
        body = {
          type = "BlockStatement",
          body = {
            { type = "ExpressionStatement", expression = { type = "Identifier", name = "y" } },
          },
        },
      },
      finalizer = nil,
    },
  })
end)

-- typeof in switch discriminant
test("parse typeof in switch discriminant", function()
  assert_parse_ok("switch (typeof x) { case 'number': break; }", {
    {
      type = "SwitchStatement",
      discriminant = {
        type = "TypeofExpression",
        argument = { type = "Identifier", name = "x" },
      },
      cases = {
        {
          type = "SwitchCase",
          test = { type = "StringLiteral", value = "number" },
          consequent = {
            { type = "BreakStatement" },
          },
        },
      },
    },
  })
end)

-- ============================================================================
-- NEGATIVE / ERROR TESTS
-- ============================================================================

test("error: typeof with no operand", function()
  assert_parse_fail("typeof", nil)
end)

test("error: typeof at end of program", function()
  assert_parse_fail("typeof;", nil)
end)

test("error: typeof followed by semicolon", function()
  assert_parse_fail("typeof ;", nil)
end)

test("error: typeof followed by closing paren", function()
  assert_parse_fail("(typeof)", nil)
end)

test("error: typeof followed by closing bracket", function()
  assert_parse_fail("[typeof]", nil)
end)

test("error: typeof followed by operator", function()
  assert_parse_fail("typeof +;", nil)
end)

test("error: typeof followed by comma", function()
  assert_parse_fail("typeof , x;", nil)
end)

-- typeof this is still banned (this is banned keyword)
test("error: typeof this (this is banned)", function()
  assert_parse_fail("typeof this;", nil)
end)

-- typeof async is still banned
test("error: typeof async x (async is banned)", function()
  assert_parse_fail("typeof async x;", nil)
end)

-- typeof await is still banned
test("error: typeof await x (await is banned)", function()
  assert_parse_fail("typeof await x;", nil)
end)

-- typeof instanceof is still banned
test("error: typeof instanceof x (instanceof is banned)", function()
  assert_parse_fail("typeof instanceof x;", nil)
end)

-- ============================================================================
-- SUMMARY
-- ============================================================================

T.summary()
