local ljs = require("ljs_parser")
local T = require("ljs_test")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq

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
  local src = "+ - * / % === !== < > <= >= && || = ! ++ -- += -= *= /= %="
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
  assert_tok(src, 16, "++")
  assert_tok(src, 17, "--")
  assert_tok(src, 18, "+=")
  assert_tok(src, 19, "-=")
  assert_tok(src, 20, "*=")
  assert_tok(src, 21, "/=")
  assert_tok(src, 22, "%=")
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

test("tokenize +++ maximal munch", function()
  local tokens = ljs.tokenize("+++")
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "+")
end)

test("tokenize --- maximal munch", function()
  local tokens = ljs.tokenize("---")
  assert_eq(tokens[1].type, "--")
  assert_eq(tokens[2].type, "-")
end)

test("tokenize + + with space is not ++", function()
  local tokens = ljs.tokenize("+ +")
  assert_eq(tokens[1].type, "+")
  assert_eq(tokens[2].type, "+")
end)

test("tokenize - - with space is not --", function()
  local tokens = ljs.tokenize("- -")
  assert_eq(tokens[1].type, "-")
  assert_eq(tokens[2].type, "-")
end)

test("tokenize ++++ (two increments)", function()
  local tokens = ljs.tokenize("++++")
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "++")
end)

test("tokenize ++ in context: x++ + y", function()
  assert_tok("x++ + y", 1, "Identifier")
  assert_tok("x++ + y", 2, "++")
  assert_tok("x++ + y", 3, "+")
  assert_tok("x++ + y", 4, "Identifier")
end)

test("tokenize += in context: x += 1", function()
  assert_tok("x += 1", 1, "Identifier")
  assert_tok("x += 1", 2, "+=")
  assert_tok("x += 1", 3, "Number")
end)

test("tokenize + = with space is not +=", function()
  local tokens = ljs.tokenize("+ =")
  assert_eq(tokens[1].type, "+")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize * = with space is not *=", function()
  local tokens = ljs.tokenize("* =")
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize +++= maximal munch: ++ +=", function()
  local tokens = ljs.tokenize("+++=")
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "+=")
end)

test("tokenize ---= maximal munch: -- -=", function()
  local tokens = ljs.tokenize("---=")
  assert_eq(tokens[1].type, "--")
  assert_eq(tokens[2].type, "-=")
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

-- ============================================================================
-- C-style for(;;) tests
-- ============================================================================

test("parse for(;;) infinite loop", function()
  local ast = ljs.parse("for (;;) { x; }")
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].init, nil)
  assert_eq(ast.body[1].test, nil)
  assert_eq(ast.body[1].update, nil)
  assert_eq(ast.body[1].body.type, "BlockStatement")
end)

test("parse for with full clauses", function()
  local ast = ljs.parse("for (let i = 0; i < 10; i = i + 1) { x; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.init.kind, "let")
  assert_eq(f.init.declarations[1].name.name, "i")
  assert_eq(f.init.declarations[1].init.value, 0)
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.test.operator, "<")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "=")
end)

test("parse for with expression init", function()
  local ast = ljs.parse("for (i = 0; i < 10; i = i + 1) { x; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "ExpressionStatement")
  assert_eq(f.init.expression.type, "BinaryExpression")
  assert_eq(f.init.expression.operator, "=")
  assert_eq(f.init.expression.left.name, "i")
end)

test("parse for with only init + test", function()
  local ast = ljs.parse("for (let x = 1; x < 5; ) { x; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.update, nil)
end)

test("parse for with only test + update", function()
  local ast = ljs.parse("for (; x < 10; x = x + 1) { y; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init, nil)
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.update.type, "BinaryExpression")
end)

test("parse for with only update", function()
  local ast = ljs.parse("for (;; x = x + 1) { y; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init, nil)
  assert_eq(f.test, nil)
  assert_eq(f.update.type, "BinaryExpression")
end)

test("parse for with only init", function()
  local ast = ljs.parse("for (let x = 1; ; ) { x; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.test, nil)
  assert_eq(f.update, nil)
end)

test("parse for with only test (while-like)", function()
  local ast = ljs.parse("for (; x < 10; ) { y; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init, nil)
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.update, nil)
end)

test("parse for without body braces", function()
  local ast = ljs.parse("for (;;) x;")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.body.type, "ExpressionStatement")
end)

test("parse nested for loops", function()
  local ast = ljs.parse("for (;;) { for (;;) { x; } }")
  local outer = ast.body[1]
  assert_eq(outer.type, "ForStatement")
  assert_eq(outer.body.type, "BlockStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "ForStatement")
end)

test("parse for with const init", function()
  local ast = ljs.parse("for (const x = 1; x < 5; x = x + 1) { x; }")
  local f = ast.body[1]
  assert_eq(f.init.kind, "const")
end)

test("parse for with logical test", function()
  local ast = ljs.parse("for (; a > 0 && b < 10; ) { x; }")
  local f = ast.body[1]
  assert_eq(f.test.type, "BinaryExpression")
  assert_eq(f.test.operator, "&&")
end)

test("parse for with multiple declarators in init", function()
  local ast = ljs.parse("for (let i = 0, j = 10; i < j; i = i + 1) { x; }")
  local f = ast.body[1]
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(#f.init.declarations, 2)
  assert_eq(f.init.declarations[1].name.name, "i")
  assert_eq(f.init.declarations[2].name.name, "j")
end)

test("parse for...of still works (regression)", function()
  assert_parse_ok("for (let x of arr) { x; }", {
    {type = "ForOfStatement",
      left = {type = "VariableDeclaration", kind = "let", declarations = {
        {type = "VariableDeclarator", name = {type = "Identifier", name = "x"}}
      }},
      right = {type = "Identifier", name = "arr"},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }}
    }
  })
end)

test("for-of with const still works (regression)", function()
  assert_parse_ok("for (const x of arr) { x; }", {
    {type = "ForOfStatement",
      left = {type = "VariableDeclaration", kind = "const", declarations = {
        {type = "VariableDeclarator", name = {type = "Identifier", name = "x"}}
      }},
      right = {type = "Identifier", name = "arr"},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }}
    }
  })
end)

-- ============================================================================
-- C-style for error cases
-- ============================================================================

test("error: for missing body", function()
  local ast = ljs.parse("for (;;) ")
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].body, nil)
end)

test("error: for missing closing paren", function()
  assert_parse_fail("for (; ; ", "Expected")
end)

test("error: for missing open paren", function()
  assert_parse_fail("for ; ; ) { }", "(")
end)

test("error: for with let in test position", function()
  assert_parse_fail("for (; let x = 1; ) { }", nil)
end)

test("error: for with extra semicolons (four)", function()
  assert_parse_fail("for (;;;) { }", nil)
end)

test("error: for() with no contents", function()
  assert_parse_fail("for () { }", nil)
end)

test("error: for with expression but no semicolon or of", function()
  assert_parse_fail("for (x) { }", nil)
end)

test("parse for with var init (normalized to let)", function()
  local ast = ljs.parse("for (var i = 0; i < 3; i = i + 1) { x; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.init.type, "VariableDeclaration")
  assert_eq(f.init.kind, "let")
  assert_eq(f.init.declarations[1].name.name, "i")
end)

test("parse for with i++ update", function()
  local ast = ljs.parse("for (let i = 0; i < 10; i++) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "UpdateExpression")
  assert_eq(f.update.operator, "++")
  assert_eq(f.update.prefix, false)
  assert_eq(f.update.argument.name, "i")
end)

test("parse for with --i update", function()
  local ast = ljs.parse("for (let i = 10; i > 0; --i) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "UpdateExpression")
  assert_eq(f.update.operator, "--")
  assert_eq(f.update.prefix, true)
  assert_eq(f.update.argument.name, "i")
end)

test("parse x++ as if condition", function()
  assert_parse_ok("if (x++) { y; }", {
    {type = "IfStatement",
      test = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }}}
  })
end)

test("parse let x = y++ (as variable init)", function()
  assert_parse_ok("let x = y++;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "x"},
        init = {type = "UpdateExpression", operator = "++",
          argument = {type = "Identifier", name = "y"}, prefix = false}}
    }}
  })
end)

test("parse f(x++) as call argument", function()
  assert_parse_ok("f(x++);", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {
        {type = "UpdateExpression", operator = "++",
          argument = {type = "Identifier", name = "x"}, prefix = false}
      }}}
  })
end)

test("parse arr[x++] as computed property", function()
  assert_parse_ok("arr[x++];", {
    {type = "ExpressionStatement", expression = {type = "MemberExpression",
      object = {type = "Identifier", name = "arr"},
      property = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      computed = true}}
  })
end)

test("error: for with only one semicolon", function()
  assert_parse_fail("for (; ) { }", nil)
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

test("parse assignment", function()
  assert_parse_ok("x = 5;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 5}}
    }
  })
end)

test("parse compound += ", function()
  assert_parse_ok("x += 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}
    }
  })
end)

test("parse compound -=", function()
  assert_parse_ok("x -= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "-=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse compound *=", function()
  assert_parse_ok("x *= 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 3}}
    }
  })
end)

test("parse compound /=", function()
  assert_parse_ok("x /= 4;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "/=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 4}}
    }
  })
end)

test("parse compound %=", function()
  assert_parse_ok("x %= 5;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "%=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 5}}
    }
  })
end)

test("parse compound += on member expression", function()
  assert_parse_ok("obj.x += 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "x"},
        computed = false},
      right = {type = "NumberLiteral", value = 1}}
    }
  })
end)

test("parse compound *= on computed member", function()
  assert_parse_ok("arr[i] *= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "Identifier", name = "i"},
        computed = true},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse compound += precedence: x += 1 + 2 means x += (1 + 2)", function()
  assert_parse_ok("x += 1 + 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "+",
        left = {type = "NumberLiteral", value = 1},
        right = {type = "NumberLiteral", value = 2}}}
    }
  })
end)

test("parse compound += right-associative: x += y += 1", function()
  assert_parse_ok("x += y += 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "+=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 1}}}
    }
  })
end)

test("parse for with i += 1 update", function()
  local ast = ljs.parse("for (let i = 0; i < 10; i += 1) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "+=")
  assert_eq(f.update.left.name, "i")
  assert_eq(f.update.right.value, 1)
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

-- ============================================================================
-- SUMMARY
-- ============================================================================

T.summary()
