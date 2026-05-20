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

test("tokenize undefined", function()
  local t = tok("undefined", 1)
  assert_eq(t.type, "Undefined")
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
  local src = "let const function if else while do for of throw try catch finally return"
  assert_tok(src, 1, "let", "let")
  assert_tok(src, 2, "const", "const")
  assert_tok(src, 3, "function", "function")
  assert_tok(src, 4, "if", "if")
  assert_tok(src, 5, "else", "else")
  assert_tok(src, 6, "while", "while")
  assert_tok(src, 7, "do", "do")
  assert_tok(src, 8, "for", "for")
  assert_tok(src, 9, "of", "of")
  assert_tok(src, 10, "throw", "throw")
  assert_tok(src, 11, "try", "try")
  assert_tok(src, 12, "catch", "catch")
  assert_tok(src, 13, "finally", "finally")
  assert_tok(src, 14, "return", "return")
end)

test("tokenize operators", function()
  local src = "+ - * / % === !== < > <= >= && || = ! ~ ++ -- += -= *= /= %= ** **="
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
  assert_tok(src, 16, "~")
  assert_tok(src, 17, "++")
  assert_tok(src, 18, "--")
  assert_tok(src, 19, "+=")
  assert_tok(src, 20, "-=")
  assert_tok(src, 21, "*=")
  assert_tok(src, 22, "/=")
  assert_tok(src, 23, "%=")
  assert_tok(src, 24, "**")
  assert_tok(src, 25, "**=")
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

test("tokenize ** (exponentiation)", function()
  local tokens = ljs.tokenize("**")
  assert_eq(tokens[1].type, "**")
end)

test("tokenize **= (exponentiation assignment)", function()
  local tokens = ljs.tokenize("**=")
  assert_eq(tokens[1].type, "**=")
end)

test("tokenize *** maximal munch: ** *", function()
  local tokens = ljs.tokenize("***")
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "*")
end)

test("tokenize **** maximal munch: ** **", function()
  local tokens = ljs.tokenize("****")
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "**")
end)

test("tokenize ***= maximal munch: ** *=", function()
  local tokens = ljs.tokenize("***=")
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "*=")
end)

test("tokenize * * with space is not **", function()
  local tokens = ljs.tokenize("* *")
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "*")
end)

test("tokenize ** = with space is not **=", function()
  local tokens = ljs.tokenize("** =")
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize * *= maximal munch: * *=", function()
  local tokens = ljs.tokenize("* *=")
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "*=")
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

-- ============================================================================
-- DO...WHILE TESTS
-- ============================================================================

test("tokenize: 'do' not confused with identifier prefix", function()
  assert_tok("doSomething", 1, "Identifier", "doSomething")
end)

test("parse do...while basic with braces", function()
  assert_parse_ok("do { y; } while (x);", {
    {type = "DoWhileStatement",
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }},
      test = {type = "Identifier", name = "x"}
    }
  })
end)

test("parse do...while without braces", function()
  assert_parse_ok("do y = y + 1; while (x < 10);", {
    {type = "DoWhileStatement",
      body = {type = "ExpressionStatement", expression = {type = "BinaryExpression",
        operator = "=",
        left = {type = "Identifier", name = "y"},
        right = {type = "BinaryExpression", operator = "+",
          left = {type = "Identifier", name = "y"},
          right = {type = "NumberLiteral", value = 1}}}},
      test = {type = "BinaryExpression", operator = "<",
        left = {type = "Identifier", name = "x"},
        right = {type = "NumberLiteral", value = 10}}
    }
  })
end)

test("parse do...while without trailing semicolon", function()
  local ast = ljs.parse("do { y; } while (x)")
  assert_eq(ast.body[1].type, "DoWhileStatement")
  assert_eq(ast.body[1].test.name, "x")
end)

test("parse do...while with trailing semicolon", function()
  local ast = ljs.parse("do { y; } while (x);")
  assert_eq(ast.body[1].type, "DoWhileStatement")
  assert_eq(#ast.body, 1)
end)

test("parse do...while with complex binary test", function()
  local ast = ljs.parse("do { y; } while (a + b > 0);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.test.operator, ">")
  assert_eq(dw.test.left.operator, "+")
end)

test("parse do...while with logical test", function()
  local ast = ljs.parse("do { y; } while (a && b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.test.operator, "&&")
end)

test("parse do...while with unary negation test", function()
  assert_parse_ok("do { y; } while (!done);", {
    {type = "DoWhileStatement",
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }},
      test = {type = "UnaryExpression", operator = "!",
        argument = {type = "Identifier", name = "done"}}
    }
  })
end)

test("parse do...while with strict inequality test", function()
  local ast = ljs.parse("do { y; } while (x !== 0);")
  local dw = ast.body[1]
  assert_eq(dw.test.operator, "!==")
end)

test("parse do...while with call expression as test", function()
  local ast = ljs.parse("do { y; } while (shouldContinue());")
  local dw = ast.body[1]
  assert_eq(dw.test.type, "CallExpression")
  assert_eq(dw.test.callee.name, "shouldContinue")
end)

test("parse do...while with member expression as test", function()
  local ast = ljs.parse("do { y; } while (obj.active);")
  local dw = ast.body[1]
  assert_eq(dw.test.type, "MemberExpression")
  assert_eq(dw.test.object.name, "obj")
  assert_eq(dw.test.property.name, "active")
end)

test("parse do...while with ternary as test", function()
  local ast = ljs.parse("do { y; } while (flag ? true : false);")
  local dw = ast.body[1]
  assert_eq(dw.test.type, "ConditionalExpression")
  assert_eq(dw.test.test.name, "flag")
  assert_eq(dw.test.consequent.value, true)
  assert_eq(dw.test.alternate.value, false)
end)

test("parse do...while with number literal as test", function()
  local ast = ljs.parse("do { y; } while (1);")
  local dw = ast.body[1]
  assert_eq(dw.test.type, "NumberLiteral")
  assert_eq(dw.test.value, 1)
end)

test("parse do...while body with multiple statements", function()
  local ast = ljs.parse("do { x = x + 1; y = y + 1; } while (x < 10);")
  local dw = ast.body[1]
  assert_eq(dw.body.type, "BlockStatement")
  assert_eq(#dw.body.body, 2)
end)

test("parse do...while body is if statement", function()
  local ast = ljs.parse("do if (a) { x; } while (b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "IfStatement")
  assert_eq(dw.body.test.name, "a")
end)

test("parse do...while body is while loop", function()
  local ast = ljs.parse("do while (a) { x; } while (b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "WhileStatement")
  assert_eq(dw.body.test.name, "a")
end)

test("parse do...while body is another do...while", function()
  local ast = ljs.parse("do do { x; } while (a); while (b);")
  local outer = ast.body[1]
  assert_eq(outer.type, "DoWhileStatement")
  assert_eq(outer.test.name, "b")
  assert_eq(outer.body.type, "DoWhileStatement")
  assert_eq(outer.body.test.name, "a")
end)

test("parse do...while body is for loop", function()
  local ast = ljs.parse("do for (let i = 0; i < 5; i = i + 1) { x; } while (b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "ForStatement")
end)

test("parse do...while body is throw", function()
  local ast = ljs.parse("do throw e; while (false);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "ThrowStatement")
end)

test("parse do...while body is try/catch", function()
  local ast = ljs.parse("do try { x; } catch (e) { y; } while (b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "TryStatement")
end)

test("parse do...while body is variable declaration", function()
  local ast = ljs.parse("do let x = 1; while (b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "VariableDeclaration")
end)

test("parse do...while body is return", function()
  local ast = ljs.parse("do return x; while (b);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "ReturnStatement")
end)

test("parse do...while body is update expression", function()
  assert_parse_ok("do x++; while (y < 10);", {
    {type = "DoWhileStatement",
      body = {type = "ExpressionStatement", expression = {type = "UpdateExpression",
        operator = "++", prefix = false,
        argument = {type = "Identifier", name = "x"}}},
      test = {type = "BinaryExpression", operator = "<",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 10}}
    }
  })
end)

test("parse do...while inside while", function()
  local ast = ljs.parse("while (a) { do { x; } while (b); }")
  local outer = ast.body[1]
  assert_eq(outer.type, "WhileStatement")
  assert_eq(outer.body.type, "BlockStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "DoWhileStatement")
  assert_eq(inner.test.name, "b")
end)

test("parse do...while inside if", function()
  local ast = ljs.parse("if (a) { do { x; } while (b); }")
  local ifs = ast.body[1]
  assert_eq(ifs.type, "IfStatement")
  local inner = ifs.consequent.body[1]
  assert_eq(inner.type, "DoWhileStatement")
end)

test("parse do...while inside for", function()
  local ast = ljs.parse("for (;;) { do { x; } while (b); }")
  local outer = ast.body[1]
  assert_eq(outer.type, "ForStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "DoWhileStatement")
end)

test("parse do...while inside function", function()
  local ast = ljs.parse("function f() { do { x; } while (b); }")
  local fn = ast.body[1]
  assert_eq(fn.type, "FunctionDeclaration")
  local inner = fn.body.body[1]
  assert_eq(inner.type, "DoWhileStatement")
end)

test("parse multiple do...while in sequence", function()
  local ast = ljs.parse("do { a; } while (x); do { b; } while (y);")
  assert_eq(#ast.body, 2)
  assert_eq(ast.body[1].type, "DoWhileStatement")
  assert_eq(ast.body[1].test.name, "x")
  assert_eq(ast.body[2].type, "DoWhileStatement")
  assert_eq(ast.body[2].test.name, "y")
end)

test("parse do...while with compound expression in body", function()
  local ast = ljs.parse("do { let x = 1; x; } while (true);")
  local dw = ast.body[1]
  assert_eq(dw.type, "DoWhileStatement")
  assert_eq(dw.body.type, "BlockStatement")
  assert_eq(#dw.body.body, 2)
  assert_eq(dw.body.body[1].type, "VariableDeclaration")
  assert_eq(dw.test.value, true)
end)

test("parse do...while with assignment expression test", function()
  local ast = ljs.parse("do { x; } while (n = n - 1);")
  local dw = ast.body[1]
  assert_eq(dw.test.type, "BinaryExpression")
  assert_eq(dw.test.operator, "=")
end)

test("parse do...while with compound assignment test", function()
  local ast = ljs.parse("do { x; } while (n -= 1);")
  local dw = ast.body[1]
  assert_eq(dw.test.operator, "-=")
end)

-- do...while negative tests

test("parse error: do...while missing while keyword", function()
  assert_parse_fail("do { x; }", "while")
end)

test("parse error: do...while missing parens around test", function()
  assert_parse_fail("do { x; } while x;", "Expected (")
end)

test("parse error: do...while missing test expression", function()
  assert_parse_fail("do { x; } while ();", "Expected expression")
end)

test("parse error: do...while missing closing paren", function()
  assert_parse_fail("do { x; } while (y", ")")
end)

test("parse error: do...while missing body", function()
  assert_parse_fail("do while (y);", nil)
end)

test("parse error: do at EOF", function()
  assert_parse_fail("do", nil)
end)

test("parse error: do { at EOF", function()
  assert_parse_fail("do {", nil)
end)

test("parse error: do with closing brace without opening", function()
  assert_parse_fail("do } while (x);", nil)
end)

test("parse error: while without parens after do body", function()
  assert_parse_fail("do { x; } while;", "Expected (")
end)

test("parse error: do body block then while at EOF", function()
  assert_parse_fail("do { x; } while", nil)
end)

test("parse error: do inside object literal", function()
  assert_parse_fail("let o = { a: do { } while (x) };", nil)
end)

-- do...while parse_tokens isolation tests moved to bottom of file
-- (TK is not yet in scope here)

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
-- for...in tests
-- ============================================================================

test("parse for...in with let", function()
  assert_parse_ok("for (let key in obj) { console.log(key); }", {
    {type = "ForInStatement",
      left = {type = "VariableDeclaration", kind = "let", declarations = {
        {type = "VariableDeclarator", name = {type = "Identifier", name = "key"}}
      }},
      right = {type = "Identifier", name = "obj"},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "CallExpression",
          callee = {type = "MemberExpression", object = {type = "Identifier", name = "console"},
            property = {type = "Identifier", name = "log"}, computed = false},
          arguments = {{type = "Identifier", name = "key"}}
        }}
      }}
    }
  })
end)

test("parse for...in with const", function()
  assert_parse_ok("for (const k in obj) { k; }", {
    {type = "ForInStatement",
      left = {type = "VariableDeclaration", kind = "const", declarations = {
        {type = "VariableDeclarator", name = {type = "Identifier", name = "k"}}
      }},
      right = {type = "Identifier", name = "obj"},
      body = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "k"}}
      }}
    }
  })
end)

test("parse for...in with var (normalized to let)", function()
  local ast = ljs.parse("for (var k in obj) { k; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "VariableDeclaration")
  assert_eq(f.left.kind, "let")
  assert_eq(f.left.declarations[1].name.name, "k")
  assert_eq(f.right.name, "obj")
end)

test("parse for...in with expression left (no declaration)", function()
  local ast = ljs.parse("for (key in obj) { key; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.left.type, "Identifier")
  assert_eq(f.left.name, "key")
  assert_eq(f.right.name, "obj")
end)

test("parse for...in without body braces", function()
  local ast = ljs.parse("for (let k in obj) f(k);")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.body.type, "ExpressionStatement")
end)

test("parse for...in with object literal right", function()
  local ast = ljs.parse("for (let k in {a: 1, b: 2}) { k; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.right.type, "ObjectExpression")
  assert_eq(#f.right.properties, 2)
end)

test("parse for...in with member expression right", function()
  local ast = ljs.parse("for (let k in obj.prop) { k; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.right.type, "MemberExpression")
end)

test("parse for...in with computed member expression right", function()
  local ast = ljs.parse("for (let k in obj[key]) { k; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  assert_eq(f.right.type, "MemberExpression")
  assert_eq(f.right.computed, true)
end)

test("parse nested for...in", function()
  local ast = ljs.parse("for (let k in obj) { for (let j in arr) { x; } }")
  local outer = ast.body[1]
  assert_eq(outer.type, "ForInStatement")
  local inner = outer.body.body[1]
  assert_eq(inner.type, "ForInStatement")
end)

test("parse for...in body uses key with bracket access", function()
  local ast = ljs.parse("for (let k in obj) { obj[k]; }")
  local f = ast.body[1]
  assert_eq(f.type, "ForInStatement")
  local expr = f.body.body[1].expression
  assert_eq(expr.type, "MemberExpression")
  assert_eq(expr.computed, true)
  assert_eq(expr.property.name, "k")
end)

-- for...in error cases

test("error: for-in with multiple declarators", function()
  assert_parse_fail("for (let x, y in obj) { }", "single variable")
end)

test("error: for-in with initializer", function()
  assert_parse_fail("for (let x = 1 in obj) { }", "initializer")
end)

test("error: for-in with const and initializer", function()
  assert_parse_fail("for (const x = 1 in obj) { }", "initializer")
end)

test("error: for-in missing right expression", function()
  assert_parse_fail("for (let x in) { }", nil)
end)

test("error: for-in with in as variable name", function()
  assert_parse_fail("for (let in in obj) { }", nil)
end)

test("error: let in = 5 (in is keyword)", function()
  assert_parse_fail("let in = 5", nil)
end)

test("error: for-in missing body", function()
  local ast = ljs.parse("for (let x in obj) ")
  assert_eq(ast.body[1].type, "ForInStatement")
  assert_eq(ast.body[1].body, nil)
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
      },
      finalizer = nil
    }
  })
end)

test("parse try/catch/finally", function()
  assert_parse_ok("try { x; } catch (e) { y; } finally { z; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
        }}
      },
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "z"}}
      }}
    }
  })
end)

test("parse try/finally (no catch)", function()
  assert_parse_ok("try { x; } finally { cleanup; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = nil,
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "cleanup"}}
      }}
    }
  })
end)

test("parse try/finally with empty finally block", function()
  assert_parse_ok("try { x; } catch (e) { y; } finally { }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
        }}
      },
      finalizer = {type = "BlockStatement", body = {}}
    }
  })
end)

test("parse try/finally with empty try block", function()
  assert_parse_ok("try { } finally { x; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {}},
      handler = nil,
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }}
    }
  })
end)

test("parse try/catch/finally with multiple statements in finally", function()
  assert_parse_ok("try { x; } catch (e) { y; } finally { a; b; c; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
        }}
      },
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "a"}},
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "b"}},
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "c"}}
      }}
    }
  })
end)

test("parse try/catch/finally inside function", function()
  assert_parse_ok("function f() { try { x; } catch (e) { y; } finally { z; } }", {
    {type = "FunctionDeclaration", name = "f",
      params = {},
      body = {type = "BlockStatement", body = {
        {type = "TryStatement",
          block = {type = "BlockStatement", body = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
          }},
          handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
            body = {type = "BlockStatement", body = {
              {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
            }}
          },
          finalizer = {type = "BlockStatement", body = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "z"}}
          }}
        }
      }}
    }
  })
end)

test("parse nested try/catch/finally", function()
  assert_parse_ok("try { try { a; } catch (e1) { b; } finally { c; } } catch (e2) { d; } finally { e; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "TryStatement",
          block = {type = "BlockStatement", body = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "a"}}
          }},
          handler = {type = "CatchClause", param = {type = "Identifier", name = "e1"},
            body = {type = "BlockStatement", body = {
              {type = "ExpressionStatement", expression = {type = "Identifier", name = "b"}}
            }}
          },
          finalizer = {type = "BlockStatement", body = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "c"}}
          }}
        }
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e2"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "d"}}
        }}
      },
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "e"}}
      }}
    }
  })
end)

test("parse try/catch/finally with throw in finally", function()
  assert_parse_ok("try { x; } catch (e) { y; } finally { throw z; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
        }}
      },
      finalizer = {type = "BlockStatement", body = {
        {type = "ThrowStatement", argument = {type = "Identifier", name = "z"}}
      }}
    }
  })
end)

test("parse try/finally with return in finally", function()
  assert_parse_ok("try { x; } finally { return 1; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = nil,
      finalizer = {type = "BlockStatement", body = {
        {type = "ReturnStatement", argument = {type = "NumberLiteral", value = 1}}
      }}
    }
  })
end)

test("parse try/catch/finally in while loop", function()
  assert_parse_ok("while (cond) { try { x; } finally { y; } }", {
    {type = "WhileStatement",
      test = {type = "Identifier", name = "cond"},
      body = {type = "BlockStatement", body = {
        {type = "TryStatement",
          block = {type = "BlockStatement", body = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
          }},
          handler = nil,
          finalizer = {type = "BlockStatement", body = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
          }}
        }
      }}
    }
  })
end)

test("parse try/finally with complex expression in try body", function()
  assert_parse_ok('try { f(a + b); } finally { g(); }', {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "CallExpression",
          callee = {type = "Identifier", name = "f"},
          arguments = {{type = "BinaryExpression", operator = "+",
            left = {type = "Identifier", name = "a"},
            right = {type = "Identifier", name = "b"}}}
        }}
      }},
      handler = nil,
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "CallExpression",
          callee = {type = "Identifier", name = "g"},
          arguments = {}
        }}
      }}
    }
  })
end)

test("parse try/catch/finally with if in catch", function()
  assert_parse_ok("try { x; } catch (e) { if (e) { y; } } finally { z; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "IfStatement",
            test = {type = "Identifier", name = "e"},
            consequent = {type = "BlockStatement", body = {
              {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
            }},
            alternate = nil
          }
        }}
      },
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "z"}}
      }}
    }
  })
end)

test("parse try/catch/finally followed by another statement", function()
  assert_parse_ok("try { x; } catch (e) { y; } finally { z; } w;", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "x"}}
      }},
      handler = {type = "CatchClause", param = {type = "Identifier", name = "e"},
        body = {type = "BlockStatement", body = {
          {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
        }}
      },
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "z"}}
      }}
    },
    {type = "ExpressionStatement", expression = {type = "Identifier", name = "w"}}
  })
end)

test("parse multiple try/catch/finally in sequence", function()
  assert_parse_ok("try { a; } finally { b; } try { c; } finally { d; }", {
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "a"}}
      }},
      handler = nil,
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "b"}}
      }}
    },
    {type = "TryStatement",
      block = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "c"}}
      }},
      handler = nil,
      finalizer = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "d"}}
      }}
    }
  })
end)

-- error cases

test("error: try without catch or finally", function()
  assert_parse_fail("try { x; }", "catch or finally")
end)

test("error: try without catch or finally at EOF", function()
  assert_parse_fail("try { }", "catch or finally")
end)

test("error: finally without braces", function()
  assert_parse_fail("try { x; } finally x;", nil)
end)

test("error: finally without block body", function()
  assert_parse_fail("try { x; } catch (e) { y; } finally", nil)
end)

test("error: try without block after try keyword", function()
  assert_parse_fail("try x; catch (e) { y; }", nil)
end)

test("error: finally used as identifier", function()
  assert_parse_fail("let finally = 1;", nil)
end)

test("error: catch after finally", function()
  assert_parse_fail("try { x; } finally { y; } catch (e) { z; }", nil)
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

-- ============================================================================
-- Bitwise NOT (~) tests
-- ============================================================================

test("tokenize tilde", function()
  assert_tok("~", 1, "~")
end)

test("tokenize double tilde", function()
  local tokens = ljs.tokenize("~~")
  assert_eq(tokens[1].type, "~")
  assert_eq(tokens[2].type, "~")
end)

test("tokenize ~= as two tokens", function()
  local tokens = ljs.tokenize("~=")
  assert_eq(tokens[1].type, "~")
  assert_eq(tokens[2].type, "=")
end)

test("parse bitwise NOT ~x", function()
  assert_parse_ok("~x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse bitwise NOT ~0", function()
  assert_parse_ok("~0;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "NumberLiteral", value = 0}}}
  })
end)

test("parse double bitwise NOT ~~x", function()
  assert_parse_ok("~~x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse triple bitwise NOT ~~~x", function()
  local ast = ljs.parse("~~~x;")
  local expr = ast.body[1].expression
  assert_eq(expr.type, "UnaryExpression")
  assert_eq(expr.operator, "~")
  assert_eq(expr.argument.type, "UnaryExpression")
  assert_eq(expr.argument.operator, "~")
  assert_eq(expr.argument.argument.type, "UnaryExpression")
  assert_eq(expr.argument.argument.operator, "~")
  assert_eq(expr.argument.argument.argument.name, "x")
end)

test("parse ~(a + b) grouped", function()
  assert_parse_ok("~(a + b);", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}}}}
  })
end)

test("parse ~!x (bitwise NOT of logical NOT)", function()
  assert_parse_ok("~!x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "UnaryExpression", operator = "!",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse !~x (logical NOT of bitwise NOT)", function()
  assert_parse_ok("!~x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "!",
      argument = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse -~x (unary minus of bitwise NOT)", function()
  assert_parse_ok("-~x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "-",
      argument = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse ~+x (bitwise NOT of unary plus)", function()
  assert_parse_ok("~+x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "UnaryExpression", operator = "+",
        argument = {type = "Identifier", name = "x"}}}}
  })
end)

test("parse ~x + y (precedence over binary +)", function()
  assert_parse_ok("~x + y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse ~a === b (precedence over ===)", function()
  assert_parse_ok("~a === b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "===",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse ~a && b (precedence over &&)", function()
  assert_parse_ok("~a && b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&&",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse ~x ? 1 : 0 (in ternary)", function()
  assert_parse_ok("~x ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}}
  })
end)

test("parse let x = ~y (in variable init)", function()
  assert_parse_ok("let x = ~y;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "x"},
        init = {type = "UnaryExpression", operator = "~",
          argument = {type = "Identifier", name = "y"}}}
    }}
  })
end)

test("parse return ~x (in return)", function()
  assert_parse_ok("return ~x;", {
    {type = "ReturnStatement",
      argument = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}}}
  })
end)

test("parse if (~x) (in condition)", function()
  assert_parse_ok("if (~x) { y; }", {
    {type = "IfStatement",
      test = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "x"}},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }}}
  })
end)

test("parse while (~x) (in condition)", function()
  local ast = ljs.parse("while (~x) { y; }")
  assert_eq(ast.body[1].type, "WhileStatement")
  assert_eq(ast.body[1].test.type, "UnaryExpression")
  assert_eq(ast.body[1].test.operator, "~")
end)

test("parse for (;~x;) (in for test)", function()
  local ast = ljs.parse("for (;~x;) { y; }")
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].test.type, "UnaryExpression")
  assert_eq(ast.body[1].test.operator, "~")
end)

test("parse f(~x) (as call argument)", function()
  assert_parse_ok("f(~x);", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {
        {type = "UnaryExpression", operator = "~",
          argument = {type = "Identifier", name = "x"}}
      }}}
  })
end)

test("parse arr[~i] (in computed member)", function()
  assert_parse_ok("arr[~i];", {
    {type = "ExpressionStatement", expression = {type = "MemberExpression",
      object = {type = "Identifier", name = "arr"},
      property = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "i"}},
      computed = true}}
  })
end)

test("parse ~f() (on call result)", function()
  assert_parse_ok("~f();", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "CallExpression",
        callee = {type = "Identifier", name = "f"},
        arguments = {}}}}
  })
end)

test("parse ~obj.prop (on member expression)", function()
  assert_parse_ok("~obj.prop;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "prop"},
        computed = false}}}
  })
end)

test("parse ~null (on null)", function()
  assert_parse_ok("~null;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "NullLiteral"}}}
  })
end)

test("parse ~true (on boolean)", function()
  assert_parse_ok("~true;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "BooleanLiteral", value = true}}}
  })
end)

test("parse ~++x (bitwise NOT of prefix increment)", function()
  assert_parse_ok("~++x;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = true}}}
  })
end)

test("parse ~x++ (bitwise NOT of postfix increment)", function()
  assert_parse_ok("~x++;", {
    {type = "ExpressionStatement", expression = {type = "UnaryExpression", operator = "~",
      argument = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false}}}
  })
end)

test("error: bare tilde at EOF", function()
  assert_parse_fail("~", nil)
end)

test("error: tilde then semicolon", function()
  assert_parse_fail("let x = ~;", nil)
end)

test("error: double tilde at EOF", function()
  assert_parse_fail("~~", nil)
end)

test("error: tilde then close paren", function()
  assert_parse_fail("~)", nil)
end)

test("error: tilde then comma in call", function()
  assert_parse_fail("f(~, x)", nil)
end)

-- ============================================================================
-- BITWISE BINARY OPERATOR TESTS
-- ============================================================================

-- Tokenizer: basic operators

test("tokenize & (bitwise AND)", function()
  assert_tok("a & b", 2, "&")
end)

test("tokenize | (bitwise OR)", function()
  assert_tok("a | b", 2, "|")
end)

test("tokenize ^ (bitwise XOR)", function()
  assert_tok("a ^ b", 2, "^")
end)

test("tokenize << (left shift)", function()
  assert_tok("a << b", 2, "<<")
end)

test("tokenize >> (right shift)", function()
  assert_tok("a >> b", 2, ">>")
end)

test("tokenize >>> (unsigned right shift)", function()
  assert_tok("a >>> b", 2, ">>>")
end)

-- Tokenizer: compound assignment operators

test("tokenize &= (bitwise AND assign)", function()
  assert_tok("a &= b", 2, "&=")
end)

test("tokenize |= (bitwise OR assign)", function()
  assert_tok("a |= b", 2, "|=")
end)

test("tokenize ^= (bitwise XOR assign)", function()
  assert_tok("a ^= b", 2, "^=")
end)

test("tokenize <<= (left shift assign)", function()
  assert_tok("a <<= b", 2, "<<=")
end)

test("tokenize >>= (right shift assign)", function()
  assert_tok("a >>= b", 2, ">>=")
end)

test("tokenize >>>= (unsigned right shift assign)", function()
  assert_tok("a >>>= b", 2, ">>>=")
end)

-- Tokenizer: maximal munch

test("tokenize &&& maximal munch: && &", function()
  local tokens = ljs.tokenize("&&&")
  assert_eq(tokens[1].type, "&&")
  assert_eq(tokens[2].type, "&")
end)

test("tokenize ||| maximal munch: || |", function()
  local tokens = ljs.tokenize("|||")
  assert_eq(tokens[1].type, "||")
  assert_eq(tokens[2].type, "|")
end)

test("tokenize <<< maximal munch: << <", function()
  local tokens = ljs.tokenize("<<<")
  assert_eq(tokens[1].type, "<<")
  assert_eq(tokens[2].type, "<")
end)

test("tokenize >>>> maximal munch: >>> >", function()
  local tokens = ljs.tokenize(">>>>")
  assert_eq(tokens[1].type, ">>>")
  assert_eq(tokens[2].type, ">")
end)

test("tokenize <<<= maximal munch: << <=", function()
  local tokens = ljs.tokenize("<<<=")
  assert_eq(tokens[1].type, "<<")
  assert_eq(tokens[2].type, "<=")
end)

test("tokenize >>=> maximal munch: >>= >", function()
  local tokens = ljs.tokenize(">>=>")
  assert_eq(tokens[1].type, ">>=")
  assert_eq(tokens[2].type, ">")
end)

test("tokenize & & with space is two tokens", function()
  local tokens = ljs.tokenize("& &")
  assert_eq(tokens[1].type, "&")
  assert_eq(tokens[2].type, "&")
end)

test("tokenize | | with space is two tokens", function()
  local tokens = ljs.tokenize("| |")
  assert_eq(tokens[1].type, "|")
  assert_eq(tokens[2].type, "|")
end)

test("tokenize ^ ^ with space is two tokens", function()
  local tokens = ljs.tokenize("^ ^")
  assert_eq(tokens[1].type, "^")
  assert_eq(tokens[2].type, "^")
end)

test("tokenize < < with space is two tokens", function()
  local tokens = ljs.tokenize("< <")
  assert_eq(tokens[1].type, "<")
  assert_eq(tokens[2].type, "<")
end)

test("tokenize > > > with spaces is three tokens", function()
  local tokens = ljs.tokenize("> > >")
  assert_eq(tokens[1].type, ">")
  assert_eq(tokens[2].type, ">")
  assert_eq(tokens[3].type, ">")
end)

test("tokenize: && still tokenizes as logical AND (regression)", function()
  assert_tok("a && b", 2, "&&")
end)

test("tokenize: || still tokenizes as logical OR (regression)", function()
  assert_tok("a || b", 2, "||")
end)

test("tokenize: <= still tokenizes as LTE (regression)", function()
  assert_tok("a <= b", 2, "<=")
end)

test("tokenize: >= still tokenizes as GTE (regression)", function()
  assert_tok("a >= b", 2, ">=")
end)

test("tokenize all bitwise operators", function()
  local src = "& | ^ << >> >>> &= |= ^= <<= >>= >>>="
  assert_tok(src, 1, "&")
  assert_tok(src, 2, "|")
  assert_tok(src, 3, "^")
  assert_tok(src, 4, "<<")
  assert_tok(src, 5, ">>")
  assert_tok(src, 6, ">>>")
  assert_tok(src, 7, "&=")
  assert_tok(src, 8, "|=")
  assert_tok(src, 9, "^=")
  assert_tok(src, 10, "<<=")
  assert_tok(src, 11, ">>=")
  assert_tok(src, 12, ">>>=")
end)

-- Parser: basic binary expressions

test("parse bitwise AND: a & b", function()
  assert_parse_ok("a & b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse bitwise OR: a | b", function()
  assert_parse_ok("a | b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse bitwise XOR: a ^ b", function()
  assert_parse_ok("a ^ b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "^",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse left shift: a << 1", function()
  assert_parse_ok("a << 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<",
      left = {type = "Identifier", name = "a"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse right shift: a >> 1", function()
  assert_parse_ok("a >> 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>",
      left = {type = "Identifier", name = "a"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse unsigned right shift: a >>> 1", function()
  assert_parse_ok("a >>> 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>>",
      left = {type = "Identifier", name = "a"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

-- Parser: compound assignment

test("parse compound &= ", function()
  assert_parse_ok("x &= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse compound |= ", function()
  assert_parse_ok("x |= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse compound ^= ", function()
  assert_parse_ok("x ^= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "^=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse compound <<= ", function()
  assert_parse_ok("x <<= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}}
  })
end)

test("parse compound >>= ", function()
  assert_parse_ok("x >>= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}}
  })
end)

test("parse compound >>>= ", function()
  assert_parse_ok("x >>>= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>>=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}}
  })
end)

test("parse &= on member expression", function()
  assert_parse_ok("obj.x &= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "x"},
        computed = false},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse |= on computed member", function()
  assert_parse_ok("arr[i] |= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "Identifier", name = "i"},
        computed = true},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

-- Parser: left-associativity

test("parse a & b & c is left-associative", function()
  assert_parse_ok("a & b & c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse a | b | c is left-associative", function()
  assert_parse_ok("a | b | c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse a << b << c is left-associative", function()
  assert_parse_ok("a << b << c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<",
      left = {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: compound assignment right-associativity

test("parse &= right-associative: x &= y &= 1", function()
  assert_parse_ok("x &= y &= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "&=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 1}}}}
  })
end)

test("parse |= right-associative: x |= y |= 1", function()
  assert_parse_ok("x |= y |= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "|=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 1}}}}
  })
end)

-- Parser: precedence — arithmetic > shifts

test("parse precedence: + tighter than <<", function()
  assert_parse_ok("a + b << c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<",
      left = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: << tighter than ===", function()
  assert_parse_ok("a << b === c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "===",
      left = {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: precedence — comparison > bitwise AND

test("parse precedence: === tighter than &", function()
  assert_parse_ok("a === b & c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "BinaryExpression", operator = "===",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: precedence — & > ^ > |

test("parse precedence: & tighter than ^", function()
  assert_parse_ok("a & b ^ c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "^",
      left = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: ^ tighter than |", function()
  assert_parse_ok("a ^ b | c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "BinaryExpression", operator = "^",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: & tighter than |", function()
  assert_parse_ok("a & b | c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: precedence — | > && > ||

test("parse precedence: | tighter than &&", function()
  assert_parse_ok("a | b && c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&&",
      left = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: | tighter than ||", function()
  assert_parse_ok("a | b || c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "||",
      left = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: bitwise with unary ~

test("parse ~a & b (unary bitwise NOT then AND)", function()
  assert_parse_ok("~a & b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse a & ~b (bitwise AND then unary NOT)", function()
  assert_parse_ok("a & ~b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "Identifier", name = "a"},
      right = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "b"}}}}
  })
end)

test("parse ~a | ~b (both sides unary NOT)", function()
  assert_parse_ok("~a | ~b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "b"}}}}
  })
end)

-- Parser: bitwise in various contexts

test("parse let x = a & b (in variable init)", function()
  assert_parse_ok("let x = a & b;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "x"},
        init = {type = "BinaryExpression", operator = "&",
          left = {type = "Identifier", name = "a"},
          right = {type = "Identifier", name = "b"}}}
    }}
  })
end)

test("parse return a | b (in return)", function()
  assert_parse_ok("return a | b;", {
    {type = "ReturnStatement",
      argument = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse if (a & b) (in condition)", function()
  assert_parse_ok("if (a & b) { y; }", {
    {type = "IfStatement",
      test = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }}}
  })
end)

test("parse for (; a | b;) (in for test)", function()
  local ast = ljs.parse("for (; a | b;) { y; }")
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].test.type, "BinaryExpression")
  assert_eq(ast.body[1].test.operator, "|")
end)

test("parse f(a ^ b) (as call argument)", function()
  assert_parse_ok("f(a ^ b);", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {
        {type = "BinaryExpression", operator = "^",
          left = {type = "Identifier", name = "a"},
          right = {type = "Identifier", name = "b"}}
      }}}
  })
end)

test("parse [a << 1] (in array)", function()
  assert_parse_ok("[a << 1];", {
    {type = "ExpressionStatement", expression = {type = "ArrayExpression", elements = {
      {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "NumberLiteral", value = 1}}
    }}}
  })
end)

test("parse {x: a >> 1} (in object)", function()
  assert_parse_ok("let o = {x: a >> 1};", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "o"},
        init = {type = "ObjectExpression", properties = {
          {type = "Property",
            key = {type = "Identifier", name = "x"},
            value = {type = "BinaryExpression", operator = ">>",
              left = {type = "Identifier", name = "a"},
              right = {type = "NumberLiteral", value = 1}},
            computed = false}
        }}
      }
    }}
  })
end)

test("parse a | b ? 1 : 0 (bitwise in ternary test)", function()
  assert_parse_ok("a | b ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}}
  })
end)

test("parse x = a & b (bitwise in assignment RHS)", function()
  assert_parse_ok("x = a & b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}}}}
  })
end)

test("parse x++ & y (postfix in bitwise)", function()
  assert_parse_ok("x++ & y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse for with i <<= 1 update", function()
  local ast = ljs.parse("for (let i = 1; i < 256; i <<= 1) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "<<=")
  assert_eq(f.update.left.name, "i")
  assert_eq(f.update.right.value, 1)
end)

-- parse_tokens isolation tests for bitwise ops moved after TK definition

-- Bitwise negative tests

test("error: a & (missing right operand)", function()
  assert_parse_fail("let x = a &;", nil)
end)

test("error: & b (missing left operand)", function()
  assert_parse_fail("& b;", nil)
end)

test("error: a <<< b tokenizes as << < b, parse fails", function()
  assert_parse_fail("a <<< b;", nil)
end)

test("error: a >>>> b tokenizes as >>> > b, parse fails", function()
  assert_parse_fail("a >>>> b;", nil)
end)

test("error: a | (missing right operand)", function()
  assert_parse_fail("let x = a |;", nil)
end)

test("error: a ^ (missing right operand)", function()
  assert_parse_fail("let x = a ^;", nil)
end)

test("error: bitwise AND assign without right operand", function()
  assert_parse_fail("x &= ;", nil)
end)

test("error: left shift assign without right operand", function()
  assert_parse_fail("x <<= ;", nil)
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

-- ============================================================================
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
-- SWITCH/CASE/BREAK TESTS
-- ============================================================================

test("tokenize switch/case/default/break keywords", function()
  local src = "switch case default break"
  assert_tok(src, 1, "switch", "switch")
  assert_tok(src, 2, "case", "case")
  assert_tok(src, 3, "default", "default")
  assert_tok(src, 4, "break", "break")
end)

test("tokenize 'switchboard' as Identifier (not keyword prefix)", function()
  assert_tok("switchboard", 1, "Identifier", "switchboard")
end)

test("tokenize 'caseInsensitive' as Identifier", function()
  assert_tok("caseInsensitive", 1, "Identifier", "caseInsensitive")
end)

test("tokenize 'breakdown' as Identifier", function()
  assert_tok("breakdown", 1, "Identifier", "breakdown")
end)

test("tokenize 'continue' keyword", function()
  assert_tok("continue", 1, "continue", "continue")
end)

test("tokenize 'continuation' as Identifier (not keyword prefix)", function()
  assert_tok("continuation", 1, "Identifier", "continuation")
end)

-- SwitchStatement: basic structure

test("parse minimal switch with one case + break", function()
  assert_parse_ok("switch (x) { case 1: break; }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {
            {type = "BreakStatement"}
          }}
      }}
  })
end)

test("parse switch with default only", function()
  assert_parse_ok("switch (x) { default: y; }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = nil,
          consequent = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
          }}
      }}
  })
end)

test("parse empty switch body", function()
  assert_parse_ok("switch (x) {}", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {}}
  })
end)

test("parse multiple cases with break", function()
  assert_parse_ok("switch (x) { case 1: a; break; case 2: b; break; }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "a"}},
            {type = "BreakStatement"}
          }},
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 2},
          consequent = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "b"}},
            {type = "BreakStatement"}
          }}
      }}
  })
end)

test("parse case fallthrough (empty consequent)", function()
  assert_parse_ok("switch (x) { case 1: case 2: break; }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {}},
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 2},
          consequent = {
            {type = "BreakStatement"}
          }}
      }}
  })
end)

test("parse case + default + case (default in middle)", function()
  assert_parse_ok("switch (x) { case 1: a; break; default: b; break; case 2: c; break; }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "a"}},
            {type = "BreakStatement"}
          }},
        {type = "SwitchCase",
          test = nil,
          consequent = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "b"}},
            {type = "BreakStatement"}
          }},
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 2},
          consequent = {
            {type = "ExpressionStatement", expression = {type = "Identifier", name = "c"}},
            {type = "BreakStatement"}
          }}
      }}
  })
end)

-- SwitchStatement: discriminant expressions

test("parse switch discriminant is binary expression", function()
  local ast = ljs.parse("switch (a + b) {}")
  local sw = ast.body[1]
  assert_eq(sw.type, "SwitchStatement")
  assert_eq(sw.discriminant.type, "BinaryExpression")
  assert_eq(sw.discriminant.operator, "+")
end)

test("parse switch discriminant is call expression", function()
  local ast = ljs.parse("switch (f()) {}")
  local sw = ast.body[1]
  assert_eq(sw.discriminant.type, "CallExpression")
  assert_eq(sw.discriminant.callee.name, "f")
end)

test("parse switch discriminant is member expression", function()
  local ast = ljs.parse("switch (obj.prop) {}")
  local sw = ast.body[1]
  assert_eq(sw.discriminant.type, "MemberExpression")
  assert_eq(sw.discriminant.object.name, "obj")
  assert_eq(sw.discriminant.property.name, "prop")
end)

test("parse switch discriminant is ternary expression", function()
  local ast = ljs.parse("switch (a ? 1 : 2) {}")
  local sw = ast.body[1]
  assert_eq(sw.discriminant.type, "ConditionalExpression")
  assert_eq(sw.discriminant.test.name, "a")
end)

-- SwitchStatement: case test expressions

test("parse case test is string literal", function()
  local ast = ljs.parse('switch (x) { case "hello": break; }')
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "StringLiteral")
  assert_eq(case.test.value, "hello")
end)

test("parse case test is identifier", function()
  local ast = ljs.parse("switch (x) { case myVar: break; }")
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "Identifier")
  assert_eq(case.test.name, "myVar")
end)

test("parse case test is boolean", function()
  local ast = ljs.parse("switch (x) { case true: break; }")
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "BooleanLiteral")
  assert_eq(case.test.value, true)
end)

test("parse case test is member expression", function()
  local ast = ljs.parse("switch (x) { case obj.key: break; }")
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "MemberExpression")
  assert_eq(case.test.object.name, "obj")
  assert_eq(case.test.property.name, "key")
end)

test("parse case test is computed member", function()
  local ast = ljs.parse("switch (x) { case arr[0]: break; }")
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "MemberExpression")
  assert_eq(case.test.computed, true)
  assert_eq(case.test.object.name, "arr")
end)

-- SwitchStatement: case body variations

test("parse case body with multiple statements", function()
  local ast = ljs.parse("switch (x) { case 1: a; b; c; break; }")
  local case = ast.body[1].cases[1]
  assert_eq(#case.consequent, 4)
  assert_eq(case.consequent[1].expression.name, "a")
  assert_eq(case.consequent[2].expression.name, "b")
  assert_eq(case.consequent[3].expression.name, "c")
  assert_eq(case.consequent[4].type, "BreakStatement")
end)

test("parse case body with variable declaration", function()
  local ast = ljs.parse("switch (x) { case 1: let y = 2; break; }")
  local case = ast.body[1].cases[1]
  assert_eq(case.consequent[1].type, "VariableDeclaration")
  assert_eq(case.consequent[1].kind, "let")
  assert_eq(case.consequent[2].type, "BreakStatement")
end)

test("parse case body with if/else", function()
  local ast = ljs.parse("switch (x) { case 1: if (a) { b; } break; }")
  local case = ast.body[1].cases[1]
  assert_eq(case.consequent[1].type, "IfStatement")
  assert_eq(case.consequent[1].test.name, "a")
  assert_eq(case.consequent[2].type, "BreakStatement")
end)

test("parse case body with return", function()
  local ast = ljs.parse("function f(x) { switch (x) { case 1: return x; } }")
  local case = ast.body[1].body.body[1].cases[1]
  assert_eq(case.consequent[1].type, "ReturnStatement")
  assert_eq(case.consequent[1].argument.name, "x")
end)

test("parse case body with throw", function()
  local ast = ljs.parse('switch (x) { case 1: throw "err"; }')
  local case = ast.body[1].cases[1]
  assert_eq(case.consequent[1].type, "ThrowStatement")
  assert_eq(case.consequent[1].argument.value, "err")
end)

test("parse case with empty body at end of switch", function()
  assert_parse_ok("switch (x) { case 1: }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {}}
      }}
  })
end)

test("parse case with empty default at end", function()
  assert_parse_ok("switch (x) { default: }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = nil,
          consequent = {}}
      }}
  })
end)

-- SwitchStatement: default position

test("parse default first", function()
  local ast = ljs.parse("switch (x) { default: a; break; case 1: b; break; }")
  assert_eq(#ast.body[1].cases, 2)
  assert_eq(ast.body[1].cases[1].test, nil)
  assert_eq(ast.body[1].cases[2].test.value, 1)
end)

test("parse default last", function()
  local ast = ljs.parse("switch (x) { case 1: a; break; default: b; break; }")
  assert_eq(#ast.body[1].cases, 2)
  assert_eq(ast.body[1].cases[1].test.value, 1)
  assert_eq(ast.body[1].cases[2].test, nil)
end)

-- BreakStatement

test("parse bare break", function()
  assert_parse_ok("break;", {
    {type = "BreakStatement"}
  })
end)

test("parse break without semicolon before }", function()
  assert_parse_ok("switch (x) { case 1: break }", {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {
            {type = "BreakStatement"}
          }}
      }}
  })
end)

test("parse break inside while loop", function()
  local ast = ljs.parse("while (true) { break; }")
  local brk = ast.body[1].body.body[1]
  assert_eq(brk.type, "BreakStatement")
end)

test("parse break inside for loop", function()
  local ast = ljs.parse("for (;;) { break; }")
  local brk = ast.body[1].body.body[1]
  assert_eq(brk.type, "BreakStatement")
end)

test("parse break inside do...while", function()
  local ast = ljs.parse("do { break; } while (true);")
  local brk = ast.body[1].body.body[1]
  assert_eq(brk.type, "BreakStatement")
end)

-- ContinueStatement

test("parse bare continue", function()
  assert_parse_ok("continue;", {
    {type = "ContinueStatement"}
  })
end)

test("parse continue without semicolon before }", function()
  assert_parse_ok("while (x) { continue }", {
    {type = "WhileStatement",
      test = {type = "Identifier", name = "x"},
      body = {type = "BlockStatement", body = {
        {type = "ContinueStatement"}
      }}}
  })
end)

test("parse continue inside while loop", function()
  local ast = ljs.parse("while (true) { continue; }")
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside for-of loop", function()
  local ast = ljs.parse("for (let x of arr) { continue; }")
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside for-in loop", function()
  local ast = ljs.parse("for (let k in obj) { continue; }")
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside C-style for loop", function()
  local ast = ljs.parse("for (;;) { continue; }")
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside do...while", function()
  local ast = ljs.parse("do { continue; } while (true);")
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside nested if within loop", function()
  local ast = ljs.parse("while (x) { if (a) { continue; } b; }")
  local if_stmt = ast.body[1].body.body[1]
  assert_eq(if_stmt.type, "IfStatement")
  local cont = if_stmt.consequent.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside switch within loop", function()
  local ast = ljs.parse("while (x) { switch (a) { case 1: continue; } }")
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.type, "SwitchStatement")
  local cont = sw.cases[1].consequent[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue in nested loops (inner and outer)", function()
  local ast = ljs.parse("while (a) { while (b) { continue; } continue; }")
  local outer = ast.body[1]
  local inner = outer.body.body[1]
  local inner_cont = inner.body.body[1]
  assert_eq(inner_cont.type, "ContinueStatement")
  local outer_cont = outer.body.body[2]
  assert_eq(outer_cont.type, "ContinueStatement")
end)

test("parse continue mixed with break in switch inside loop", function()
  local ast = ljs.parse("while (x) { switch (a) { case 1: continue; case 2: break; default: continue; } }")
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.cases[1].consequent[1].type, "ContinueStatement")
  assert_eq(sw.cases[2].consequent[1].type, "BreakStatement")
  assert_eq(sw.cases[3].consequent[1].type, "ContinueStatement")
end)

test("parse continue after other statements", function()
  local ast = ljs.parse("while (x) { a; b; continue; c; }")
  local body = ast.body[1].body.body
  assert_eq(body[1].type, "ExpressionStatement")
  assert_eq(body[2].type, "ExpressionStatement")
  assert_eq(body[3].type, "ContinueStatement")
  assert_eq(body[4].type, "ExpressionStatement")
end)

test("parse multiple continues in same loop body", function()
  local ast = ljs.parse("while (x) { if (a) { continue; } if (b) { continue; } c; }")
  local body = ast.body[1].body.body
  assert_eq(body[1].consequent.body[1].type, "ContinueStatement")
  assert_eq(body[2].consequent.body[1].type, "ContinueStatement")
end)

test("error: continue as expression operand", function()
  assert_parse_fail("let x = continue;", nil)
end)

test("note: labeled continue accepted (labels ignored, same as break)", function()
  local ast = ljs.parse("while (x) { continue foo; }")
  assert_eq(ast.body[1].body.body[1].type, "ContinueStatement")
end)

-- Integration

test("integration: switch after variable declaration", function()
  local ast = ljs.parse("let x = 1; switch (x) { case 1: break; }")
  assert_eq(#ast.body, 2)
  assert_eq(ast.body[1].type, "VariableDeclaration")
  assert_eq(ast.body[2].type, "SwitchStatement")
end)

test("integration: switch inside function body", function()
  local ast = ljs.parse("function f(x) { switch (x) { case 1: return x; default: return 0; } }")
  local fn = ast.body[1]
  assert_eq(fn.type, "FunctionDeclaration")
  local sw = fn.body.body[1]
  assert_eq(sw.type, "SwitchStatement")
  assert_eq(#sw.cases, 2)
  assert_eq(sw.cases[1].test.value, 1)
  assert_eq(sw.cases[2].test, nil)
end)

test("integration: switch inside while", function()
  local ast = ljs.parse("while (cond) { switch (x) { case 1: break; } }")
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.type, "SwitchStatement")
end)

test("integration: nested switch statements", function()
  local ast = ljs.parse("switch (a) { case 1: switch (b) { case 2: break; } break; }")
  local outer = ast.body[1]
  assert_eq(outer.type, "SwitchStatement")
  assert_eq(outer.cases[1].test.value, 1)
  local inner = outer.cases[1].consequent[1]
  assert_eq(inner.type, "SwitchStatement")
  assert_eq(inner.cases[1].test.value, 2)
  local brk = outer.cases[1].consequent[2]
  assert_eq(brk.type, "BreakStatement")
end)

test("integration: switch inside for loop", function()
  local ast = ljs.parse("for (;;) { switch (x) { case 1: break; default: break; } }")
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.type, "SwitchStatement")
  assert_eq(#sw.cases, 2)
end)

test("integration: switch with complex case body", function()
  local ast = ljs.parse("switch (x) { case 1: let y = 2; if (y > 0) { y; } break; }")
  local case = ast.body[1].cases[1]
  assert_eq(#case.consequent, 3)
  assert_eq(case.consequent[1].type, "VariableDeclaration")
  assert_eq(case.consequent[2].type, "IfStatement")
  assert_eq(case.consequent[3].type, "BreakStatement")
end)

-- parse_tokens isolation

test("parse_tokens: minimal switch", function()
  local tokens = {
    tok(TK.SWITCH, "switch"), tok(TK.LPAREN), tok(TK.IDENTIFIER, "x"), tok(TK.RPAREN),
    tok(TK.LBRACE),
    tok(TK.CASE, "case"), tok(TK.NUMBER, 1), tok(TK.COLON),
    tok(TK.BREAK, "break"), tok(TK.SEMICOLON),
    tok(TK.RBRACE),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "SwitchStatement",
      discriminant = {type = "Identifier", name = "x"},
      cases = {
        {type = "SwitchCase",
          test = {type = "NumberLiteral", value = 1},
          consequent = {
            {type = "BreakStatement"}
          }}
      }}
  }})
end)

test("parse_tokens: break statement", function()
  local tokens = {
    tok(TK.BREAK, "break"), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "BreakStatement"}
  }})
end)

test("parse_tokens: continue statement", function()
  local tokens = {
    tok(TK.CONTINUE, "continue"), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ContinueStatement"}
  }})
end)

-- ============================================================================
-- SWITCH/CASE/BREAK NEGATIVE TESTS
-- ============================================================================

test("error: switch without parens", function()
  assert_parse_fail("switch x { }", "(")
end)

test("error: switch without braces", function()
  assert_parse_fail("switch (x) case 1: break;", "{")
end)

test("error: switch unclosed brace", function()
  assert_parse_fail("switch (x) { case 1: break;", "}")
end)

test("error: switch empty parens", function()
  assert_parse_fail("switch () { }", "Expected expression")
end)

test("error: switch at EOF", function()
  assert_parse_fail("switch", nil)
end)

test("error: switch (x) at EOF (no brace)", function()
  assert_parse_fail("switch (x)", "{")
end)

test("error: case without colon", function()
  assert_parse_fail("switch (x) { case 1 break; }", ":")
end)

test("error: case without test expression", function()
  assert_parse_fail("switch (x) { case : break; }", nil)
end)

test("error: case outside switch", function()
  assert_parse_fail("case 1: break;", nil)
end)

test("error: default outside switch", function()
  assert_parse_fail("default: x;", nil)
end)

test("error: multiple default clauses", function()
  assert_parse_fail("switch (x) { default: a; break; default: b; break; }", "Duplicate default")
end)

test("error: switch as variable name", function()
  assert_parse_fail("let switch = 1;", nil)
end)

test("error: case as variable name", function()
  assert_parse_fail("let case = 1;", nil)
end)

test("error: break as variable name", function()
  assert_parse_fail("let break = 1;", nil)
end)

test("error: continue as variable name", function()
  assert_parse_fail("let continue = 1;", nil)
end)

test("error: switch keyword in expression context", function()
  assert_parse_fail("let x = switch (y) { };", nil)
end)

test("error: junk inside switch body (not case/default/})", function()
  assert_parse_fail("switch (x) { 42; }", "Expected case or default")
end)

-- ============================================================================
-- BITWISE BINARY OPERATOR parse_tokens ISOLATION TESTS
-- ============================================================================

test("parse_tokens: a & b", function()
  local tokens = {
    tok(TK.IDENTIFIER, "a"), tok(TK.BITWISE_AND),
    tok(TK.IDENTIFIER, "b"), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  }})
end)

test("parse_tokens: x |= 1", function()
  local tokens = {
    tok(TK.IDENTIFIER, "x"), tok(TK.BITWISE_OR_ASSIGN),
    tok(TK.NUMBER, 1), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  }})
end)

test("parse_tokens: a << b >> c (shifts same precedence, left-assoc)", function()
  local tokens = {
    tok(TK.IDENTIFIER, "a"), tok(TK.LEFT_SHIFT),
    tok(TK.IDENTIFIER, "b"), tok(TK.RIGHT_SHIFT),
    tok(TK.IDENTIFIER, "c"), tok(TK.SEMICOLON), tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(ast, {type = "Program", body = {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>",
      left = {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  }})
end)

-- ============================================================================
-- SUMMARY
-- ============================================================================

T.summary()
