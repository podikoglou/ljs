local ljs = require("ljs_parser")
local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. " - " .. tostring(err))
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "assertion failed", tostring(expected), tostring(actual)))
  end
end

local function assert_table_eq(actual, expected, path)
  path = path or "root"
  if type(actual) ~= type(expected) then
    error(string.format("%s: type mismatch, expected %s got %s", path, type(expected), type(actual)))
  end
  if type(expected) == "table" then
    for k, v in pairs(expected) do
      assert_table_eq(actual[k], v, path .. "." .. tostring(k))
    end
    for k, _ in pairs(actual) do
      if expected[k] == nil then
        error(string.format("%s: unexpected key %s", path, tostring(k)))
      end
    end
  else
    if actual ~= expected then
      error(string.format("%s: expected %s, got %s", path, tostring(expected), tostring(actual)))
    end
  end
end

local function assert_parse_ok(source, expected_body, msg)
  local ast, err = ljs.parse(source)
  if not ast then
    error(string.format("%s: parse failed: %s", msg or source, tostring(err)))
  end
  assert_table_eq(ast, {type = "Program", body = expected_body}, msg or source)
end

local function assert_parse_fail(source, substr, msg)
  local ast, err = ljs.parse(source)
  if ast then
    error(string.format("%s: expected failure but got result", msg or source))
  end
  if substr and not string.find(tostring(err), substr, 1, true) then
    error(string.format("%s: expected error containing '%s', got '%s'", msg or source, substr, tostring(err)))
  end
end

local function tok(source, idx)
  local tokens, err = ljs.tokenize(source)
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  return tokens[idx]
end

local function assert_tok(source, idx, ttype, tvalue, msg)
  local t = tok(source, idx)
  assert_eq(t.type, ttype, msg or ("token " .. idx .. " type"))
  if tvalue ~= nil then
    assert_eq(t.value, tvalue, msg or ("token " .. idx .. " value"))
  end
end

local function assert_tokenize_fail(source, substr, msg)
  local tokens, err = ljs.tokenize(source)
  if tokens then
    error(string.format("%s: expected failure but got tokens", msg or source))
  end
  if substr and not string.find(tostring(err), substr, 1, true) then
    error(string.format("%s: expected error containing '%s', got '%s'", msg or source, substr, tostring(err)))
  end
end

-- ============================================================================
-- TOKENIZER TESTS
-- ============================================================================

test("tokenize integer", function()
  assert_tok("42", 1, "Number", 42)
end)

test("tokenize float", function()
  assert_tok("3.14", 1, "Number", 3.14)
end)

test("tokenize zero", function()
  assert_tok("0", 1, "Number", 0)
end)

test("tokenize double-quoted string", function()
  assert_tok('"hello"', 1, "String", "hello")
end)

test("tokenize single-quoted string", function()
  assert_tok("'world'", 1, "String", "world")
end)

test("tokenize escape \\n", function()
  assert_tok('"a\\nb"', 1, "String", "a\nb")
end)

test("tokenize escape \\t", function()
  assert_tok('"a\\tb"', 1, "String", "a\tb")
end)

test("tokenize escape \\\\", function()
  assert_tok('"a\\\\b"', 1, "String", "a\\b")
end)

test("tokenize escape \\\"", function()
  assert_tok('"a\\"b"', 1, "String", 'a"b')
end)

test("tokenize escape \\'", function()
  assert_tok("'a\\'b'", 1, "String", "a'b")
end)

test("tokenize true", function()
  assert_tok("true", 1, "Boolean", true)
end)

test("tokenize false", function()
  assert_tok("false", 1, "Boolean", false)
end)

test("tokenize null", function()
  local t = tok("null", 1)
  assert_eq(t.type, "Null")
end)

test("tokenize simple identifier", function()
  assert_tok("x", 1, "Identifier", "x")
end)

test("tokenize identifier with underscore", function()
  assert_tok("my_var", 1, "Identifier", "my_var")
end)

test("tokenize identifier with numbers", function()
  assert_tok("x1", 1, "Identifier", "x1")
end)

test("tokenize keywords", function()
  local src = "let const function if else while for of throw try catch return"
  assert_tok(src, 1, "let", "let")
  assert_tok(src, 2, "const", "const")
  assert_tok(src, 3, "function", "function")
  assert_tok(src, 4, "if", "if")
  assert_tok(src, 5, "else", "else")
  assert_tok(src, 6, "while", "while")
  assert_tok(src, 7, "for", "for")
  assert_tok(src, 8, "of", "of")
  assert_tok(src, 9, "throw", "throw")
  assert_tok(src, 10, "try", "try")
  assert_tok(src, 11, "catch", "catch")
  assert_tok(src, 12, "return", "return")
end)

test("tokenize operators", function()
  local src = "+ - * / % === !== < > <= >= && || = !"
  assert_tok(src, 1, "+")
  assert_tok(src, 2, "-")
  assert_tok(src, 3, "*")
  assert_tok(src, 4, "/")
  assert_tok(src, 5, "%")
  assert_tok(src, 6, "===")
  assert_tok(src, 7, "!==")
  assert_tok(src, 8, "<")
  assert_tok(src, 9, ">")
  assert_tok(src, 10, "<=")
  assert_tok(src, 11, ">=")
  assert_tok(src, 12, "&&")
  assert_tok(src, 13, "||")
  assert_tok(src, 14, "=")
  assert_tok(src, 15, "!")
end)

test("tokenize punctuation", function()
  local src = "( ) { } [ ] , ; : ."
  assert_tok(src, 1, "(")
  assert_tok(src, 2, ")")
  assert_tok(src, 3, "{")
  assert_tok(src, 4, "}")
  assert_tok(src, 5, "[")
  assert_tok(src, 6, "]")
  assert_tok(src, 7, ",")
  assert_tok(src, 8, ";")
  assert_tok(src, 9, ":")
  assert_tok(src, 10, ".")
end)

test("tokenize arrow operator", function()
  assert_tok("=>", 1, "=>")
end)

test("tokenize single-line comment", function()
  local t = tok("1 // comment\n2", 1)
  assert_eq(t.type, "Number")
  assert_eq(t.value, 1)
  local t2 = tok("1 // comment\n2", 2)
  assert_eq(t2.type, "Number")
  assert_eq(t2.value, 2)
end)

test("tokenize multi-line comment", function()
  local t = tok("1 /* comment */ 2", 1)
  assert_eq(t.type, "Number")
  assert_eq(t.value, 1)
  local t2 = tok("1 /* comment */ 2", 2)
  assert_eq(t2.type, "Number")
  assert_eq(t2.value, 2)
end)

test("tokenize error: unterminated string", function()
  assert_tokenize_fail('"hello', "Unterminated")
end)

test("tokenize error: == rejected", function()
  assert_tokenize_fail("1 == 2", "Use ===")
end)

test("tokenize error: unexpected character", function()
  assert_tokenize_fail("@", "Unexpected character")
end)

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

test("parse for...of", function()
  assert_parse_ok("for (let x of arr) { console.log(x); }", {
    {type = "ForOfStatement",
      left = {type = "VariableDeclaration", kind = "let", declarations = {
        {type = "VariableDeclarator", name = {type = "Identifier", name = "x"}}
      }},
      right = {type = "Identifier", name = "arr"},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "CallExpression",
          callee = {type = "MemberExpression", object = {type = "Identifier", name = "console"},
            property = {type = "Identifier", name = "log"}, computed = false},
          arguments = {{type = "Identifier", name = "x"}}
        }}
      }}
    }
  })
end)

test("parse throw", function()
  assert_parse_ok('throw "error";', {
    {type = "ThrowStatement", argument = {type = "StringLiteral", value = "error"}}
  })
end)

test("parse try/catch", function()
  assert_parse_ok("try { x; } catch (e) { y; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
        }}
      }
    }
  })
end)

test("parse return with value", function()
  assert_parse_ok("return x;", {
    {type = "ReturnStatement", argument = {type = "Identifier", name = "x"}}
  })
end)

test("parse return void", function()
  local ast = ljs.parse("return;")
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ReturnStatement"}
  }})
end)

test("parse block statement", function()
  assert_parse_ok("{ x; y; }", {
    {type = "BlockStatement", body = {
      {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}},
      {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
    }}
  })
end)

-- ============================================================================
-- PARSER TESTS - EXPRESSIONS
-- ============================================================================

test("parse NumberLiteral", function()
  assert_parse_ok("42;", {
    {type = "ExpressionStatement", expression = {type = "NumberLiteral", value = 42}}
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
  }
  for _, tc in ipairs(ops) do
    local ast = ljs.parse(tc[1])
    assert_table_eq(ast.body[1].expression.operator, tc[2], "operator for " .. tc[1])
  end
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

test("parse assignment", function()
  assert_parse_ok("x = 5;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 5}}
    }
  })
end)

test("parse CallExpression no args", function()
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
        {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
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
        {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
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

-- ============================================================================
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
                  {type = "ExpressionStatement", expression = {type = "BinaryExpression",
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
              {type = "ExpressionStatement", expression = {type = "BinaryExpression",
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

local T = ljs.TOKEN

local function tok(type, value, line, col)
  return { type = type, value = value, line = line or 1, col = col or 1 }
end

test("parse_tokens: let declaration", function()
  local tokens = {
    tok(T.LET, "let"), tok(T.IDENTIFIER, "x"), tok(T.ASSIGN),
    tok(T.NUMBER, 42), tok(T.SEMICOLON), tok(T.EOF),
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
    tok(T.IF, "if"), tok(T.LPAREN), tok(T.IDENTIFIER, "x"), tok(T.RPAREN),
    tok(T.LBRACE), tok(T.IDENTIFIER, "y"), tok(T.SEMICOLON), tok(T.RBRACE),
    tok(T.ELSE, "else"),
    tok(T.LBRACE), tok(T.IDENTIFIER, "z"), tok(T.SEMICOLON), tok(T.RBRACE),
    tok(T.EOF),
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
    tok(T.NUMBER, 1), tok(T.PLUS), tok(T.NUMBER, 2), tok(T.STAR),
    tok(T.NUMBER, 3), tok(T.SEMICOLON), tok(T.EOF),
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
    tok(T.RPAREN), tok(T.EOF),
  }
  local ast, err = ljs.parse_tokens(tokens)
  assert_eq(ast, nil, "expected nil ast")
  assert(err ~= nil, "expected error message")
end)

test("parse_tokens: empty program", function()
  local ast = ljs.parse_tokens({tok(T.EOF)})
  assert_table_eq(ast, {type = "Program", body = {}})
end)

-- ============================================================================
-- SUMMARY
-- ============================================================================

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
