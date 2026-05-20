local T = require("ljs_test")
local P = require("ljs_test_parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs

-- DELETE EXPRESSION TESTS
-- ============================================================================

-- Tokenizer
test("tokenize delete", function()
  assert_tok("delete x", 1, "delete", "delete")
end)

test("tokenize delete in expression", function()
  assert_tok("delete obj.x;", 1, "delete", "delete")
  assert_tok("delete obj.x;", 2, "Identifier", "obj")
end)

-- Basic parsing
test("parse delete identifier", function()
  assert_parse_ok("delete x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse delete member expression dot", function()
  assert_parse_ok("delete obj.prop;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "prop"},
        computed = false}}}
  })
end)

test("parse delete member expression bracket", function()
  assert_parse_ok("delete obj[key];", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "key"},
        computed = true}}}
  })
end)

test("parse delete computed member with expression", function()
  assert_parse_ok("delete obj[i + 1];", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "BinaryExpression", operator = "+",
          left = {type = "Identifier", name = "i"},
          right = {type = "NumberLiteral", value = 1}},
        computed = true}}}
  })
end)

test("parse delete nested member a.b.c", function()
  assert_parse_ok("delete a.b.c;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "MemberExpression",
          object = {type = "Identifier", name = "a"},
          property = {type = "Identifier", name = "b"},
          computed = false},
        property = {type = "Identifier", name = "c"},
        computed = false}}}
  })
end)

test("parse delete call result member", function()
  assert_parse_ok("delete getObj().prop;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "CallExpression",
          callee = {type = "Identifier", name = "getObj"},
          arguments = {}},
        property = {type = "Identifier", name = "prop"},
        computed = false}}}
  })
end)

-- delete with various operand types (parser doesn't enforce JS semantic rules)
test("parse delete number literal", function()
  assert_parse_ok("delete 42;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "NumberLiteral", value = 42}}}
  })
end)

test("parse delete string literal", function()
  assert_parse_ok('delete "hello";', {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "StringLiteral", value = "hello"}}}
  })
end)

test("parse delete boolean", function()
  assert_parse_ok("delete true;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "BooleanLiteral", value = true}}}
  })
end)

test("parse delete null", function()
  assert_parse_ok("delete null;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "NullLiteral"}}}
  })
end)

test("parse delete undefined", function()
  assert_parse_ok("delete undefined;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "UndefinedLiteral"}}}
  })
end)

test("parse delete parenthesized expression", function()
  assert_parse_ok("delete (x);", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse delete array literal", function()
  assert_parse_ok("delete [1, 2];", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "ArrayExpression", elements = {
        {type = "NumberLiteral", value = 1},
        {type = "NumberLiteral", value = 2}
      }}}}
  })
end)

test("parse delete object literal", function()
  assert_parse_ok("delete {a: 1};", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "ObjectExpression", properties = {
        {type = "Property",
          key = {type = "Identifier", name = "a"},
          value = {type = "NumberLiteral", value = 1},
          computed = false}
      }}}}
  })
end)

-- delete with other unary operators
test("parse delete !x (delete of unary NOT)", function()
  assert_parse_ok("delete !x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "UnaryExpression", operator = "!",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse delete -x (delete of unary minus)", function()
  assert_parse_ok("delete -x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "UnaryExpression", operator = "-",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse delete ~x (delete of bitwise NOT)", function()
  assert_parse_ok("delete ~x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse !delete x (unary NOT of delete)", function()
  assert_parse_ok("!delete x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "!",
      argument = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse -delete x (unary minus of delete)", function()
  assert_parse_ok("-delete x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "-",
      argument = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse ~delete x (bitwise NOT of delete)", function()
  assert_parse_ok("~delete x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

-- delete with update expressions
test("parse delete x++ (delete of postfix update)", function()
  assert_parse_ok("delete x++;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false}}}
  })
end)

test("parse delete ++x (delete of prefix update)", function()
  assert_parse_ok("delete ++x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = true}}}
  })
end)

test("parse ++delete x (prefix increment of delete result)", function()
  assert_parse_ok("++delete x;", {
    {type = "ExpressionStatement", expression = {type = "UpdateExpression", operator = "++",
      argument = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      prefix = true}}
  })
end)

-- delete in binary expressions
test("parse delete x + 1 (delete in arithmetic)", function()
  assert_parse_ok("delete x + 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse delete x === true (delete in comparison)", function()
  assert_parse_ok("delete x === true;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "===",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "BooleanLiteral", value = true}}}
  })
end)

test("parse delete x && delete y (delete in logical AND)", function()
  assert_parse_ok("delete x && delete y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&&",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "y"}}}}
  })
end)

test("parse delete x || delete y (delete in logical OR)", function()
  assert_parse_ok("delete x || delete y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "||",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "y"}}}}
  })
end)

-- delete in ternary
test("parse delete x ? 1 : 0 (delete in ternary condition)", function()
  assert_parse_ok("delete x ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}}
  })
end)

test("parse flag ? delete x : delete y (delete in ternary branches)", function()
  assert_parse_ok("flag ? delete x : delete y;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "Identifier", name = "flag"},
      consequent = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      alternate = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "y"}}}}
  })
end)

-- delete in assignment
test("parse result = delete x (delete as assignment RHS)", function()
  assert_parse_ok("result = delete x;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "result"},
      right = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

-- delete in variable declaration
test("parse let r = delete obj.prop (delete in variable init)", function()
  assert_parse_ok("let r = delete obj.prop;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "r"},
        init = {type = "DeleteExpression",
          argument = {type = "MemberExpression",
            object = {type = "Identifier", name = "obj"},
            property = {type = "Identifier", name = "prop"},
            computed = false}}}
    }}
  })
end)

-- delete in control flow
test("parse delete in if condition", function()
  assert_parse_ok("if (delete x) { y; }", {
    {type = "IfStatement",
      test = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }},
      alternate = nil}
  })
end)

test("parse delete in while condition", function()
  assert_parse_ok("while (delete x) { y; }", {
    {type = "WhileStatement",
      test = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }}}
  })
end)

test("parse delete in for init", function()
  assert_parse_ok("for (delete x; y; z) {}", {
    {type = "ForStatement",
      init = {type = "ExpressionStatement", expression = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}},
      test = {type = "Identifier", name = "y"},
      update = {type = "Identifier", name = "z"},
      body = {type = "BlockStatement", body = {}}}
  })
end)

test("parse delete in return statement", function()
  assert_parse_ok("function f() { return delete x; }", {
    {type = "FunctionDeclaration", name = "f", params = {},
      body = {type = "BlockStatement", body = {
        {type = "ReturnStatement", argument = {type = "DeleteExpression",
          argument = {type = "Identifier", name = "x"}}}
      }}}
  })
end)

-- nested delete
test("parse delete delete x (double delete)", function()
  assert_parse_ok("delete delete x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse delete delete delete x (triple delete)", function()
  assert_parse_ok("delete delete delete x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "DeleteExpression",
        argument = {type = "DeleteExpression",
          argument = {type = "Identifier", name = "x"}}}}}
  })
end)

-- delete with function expression operand
test("parse delete function expression", function()
  assert_parse_ok("delete function() {};", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "FunctionExpression", name = nil, params = {},
        body = {type = "BlockStatement", body = {}}}}}
  })
end)

-- delete with arrow function operand (single-param arrow is parsed by parse_identifier_or_call)
test("parse delete arrow function", function()
  assert_parse_ok("delete x => x;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "ArrowFunctionExpression",
        params = {{type = "Identifier", name = "x"}},
        body = {type = "BlockStatement", body = {
          {type = "ReturnStatement", argument = {type = "Identifier", name = "x"}}
        }}}}}
  })
end)

-- delete in array element
test("parse delete as array element", function()
  assert_parse_ok("[delete x];", {
    {type = "ExpressionStatement", expression = {type = "ArrayExpression", elements = {
      {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}}
    }}}
  })
end)

-- delete in object value
test("parse delete as object property value", function()
  assert_parse_ok("({a: delete x});", {
    {type = "ExpressionStatement", expression = {type = "ObjectExpression", properties = {
      {type = "Property",
        key = {type = "Identifier", name = "a"},
        value = {type = "DeleteExpression",
          argument = {type = "Identifier", name = "x"}},
        computed = false}
    }}}
  })
end)

-- delete in switch case
test("parse delete in switch case", function()
  assert_parse_ok("switch (x) { case 1: delete y; }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {
            {type = "ExpressionStatement", expression = {type = "DeleteExpression",
              argument = {type = "Identifier", name = "y"}}}
          }}
      }}
  })
end)

-- delete with call expression operand
test("parse delete call expression", function()
  assert_parse_ok("delete f();", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "CallExpression",
        callee = {type = "Identifier", name = "f"},
        arguments = {}}}}
  })
end)

test("parse delete call with args", function()
  assert_parse_ok("delete f(a, b);", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "CallExpression",
        callee = {type = "Identifier", name = "f"},
        arguments = {
          {type = "Identifier", name = "a"},
          {type = "Identifier", name = "b"}
        }}}}
  })
end)

-- negative / error cases
test("error: delete with no operand", function()
  assert_parse_fail("delete", nil)
end)

test("error: delete at end of program", function()
  assert_parse_fail("delete;", nil)
end)

test("error: delete followed by semicolon", function()
  assert_parse_fail("delete ;", nil)
end)

test("error: delete followed by closing paren", function()
  assert_parse_fail("(delete)", nil)
end)

test("error: delete followed by closing bracket", function()
  assert_parse_fail("[delete]", nil)
end)

test("error: delete followed by operator", function()
  assert_parse_fail("delete +;", nil)
end)

test("error: delete followed by comma", function()
  assert_parse_fail("delete , x;", nil)
end)

-- for-in with delete expression left is syntactically valid in this parser
test("parse for-in with delete expression left (syntactically accepted)", function()
  assert_parse_ok("for (delete x in obj) {}", {
    {type = "ForInStatement",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "Identifier", name = "obj"},
      body = {type = "BlockStatement", body = {}}}
  })
end)

-- delete is not a valid identifier
test("delete is a keyword not an identifier", function()
  assert_tok("delete", 1, "delete", "delete")
  assert_tok("delete", 1, "delete") -- not "Identifier"
end)

test("delete is not banned (unlike typeof/this)", function()
  local ast, err = ljs.parse("delete x;")
  assert(ast ~= nil, "delete should parse successfully, got error: " .. tostring(err))
end)

-- delete in compound expression contexts
test("parse delete in compound assignment RHS", function()
  assert_parse_ok("x += delete y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "y"}}}}
  })
end)

test("parse delete in bitwise expression", function()
  assert_parse_ok("delete x & delete y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "y"}}}}
  })
end)

test("parse delete in comparison chain", function()
  assert_parse_ok("delete x < delete y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "y"}}}}
  })
end)

-- precedence: delete binds tighter than binary ops but same as unary
test("parse precedence: delete x * y (delete x then multiply)", function()
  assert_parse_ok("delete x * y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse precedence: delete x ** y (delete x then exponentiate)", function()
  assert_parse_ok("delete x ** y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "**",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "Identifier", name = "y"}}}
  })
end)

-- delete inside parentheses grouping
test("parse (delete x) + y", function()
  assert_parse_ok("(delete x) + y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "Identifier", name = "y"}}}
  })
end)

-- delete with this/typeof/async/await (banned keywords after delete)
-- Note: error messages from check_banned are swallowed by parse_unary_expression,
-- same as for all unary operators (e.g. !this also gives "parse error: nil")
test("error: delete this (this is banned)", function()
  assert_parse_fail("delete this;", nil)
end)

test("error: delete typeof x (typeof is banned)", function()
  assert_parse_fail("delete typeof x;", nil)
end)

-- delete as statement without semicolon (ASI)
test("parse delete x without semicolon (EOF)", function()
  assert_parse_ok("delete x", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse delete x followed by let (ASI)", function()
  assert_parse_ok("delete x\nlet y = 1;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "x"}}},
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "y"},
        init = {type = "NumberLiteral", value = 1}}
    }}
  })
end)

-- multiple deletes in sequence as statements
test("parse multiple delete statements", function()
  assert_parse_ok("delete x; delete y; delete z;", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "x"}}},
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "y"}}},
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "z"}}}
  })
end)

-- delete in do-while
test("parse delete in do-while body", function()
  assert_parse_ok("do { delete x; } while (y);", {
    {type = "DoWhileStatement",
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "DeleteExpression",
          argument = {type = "Identifier", name = "x"}}}
      }},
      test = {type = "Identifier", name = "y"}}
  })
end)

-- delete with string computed member
test("parse delete obj['key']", function()
  assert_parse_ok("delete obj['key'];", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "StringLiteral", value = "key"},
        computed = true}}}
  })
end)

-- delete with number computed member
test("parse delete arr[0]", function()
  assert_parse_ok("delete arr[0];", {
    {type = "ExpressionStatement", expression = {type = "DeleteExpression",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "NumberLiteral", value = 0},
        computed = true}}}
  })
end)

-- delete in throw
test("parse throw delete x is not valid (throw expects expression, delete is expr)", function()
  assert_parse_ok("throw delete x;", {
    {type = "ThrowStatement", argument = {type = "DeleteExpression",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

-- for-of with delete expression left is syntactically valid in this parser
test("parse for-of with delete expression left (syntactically accepted)", function()
  assert_parse_ok("for (delete x of arr) {}", {
    {type = "ForOfStatement",
      left = {type = "DeleteExpression",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "Identifier", name = "arr"},
      body = {type = "BlockStatement", body = {}}}
  })
end)

-- ============================================================================
-- SUMMARY
-- ============================================================================

T.summary()
T.summary()
