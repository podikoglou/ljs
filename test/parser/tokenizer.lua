local T = require("ljs_test")
local P = require("test.helpers.parser")
local ljs = require("ljs_parser")
local test, assert_eq = T.test, T.assert_eq
local assert_tok, assert_tokenize_fail = P.assert_tok, P.assert_tokenize_fail

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

test('tokenize escape \\"', function()
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
  local t = P.tok("null", 1)
  assert_eq(t.type, "Null")
end)

test("tokenize undefined", function()
  local t = P.tok("undefined", 1)
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
  local t = P.tok("1 // comment\n2", 1)
  assert_eq(t.type, "Number")
  assert_eq(t.value, 1)
  local t2 = P.tok("1 // comment\n2", 2)
  assert_eq(t2.type, "Number")
  assert_eq(t2.value, 2)
end)

test("tokenize multi-line comment", function()
  local t = P.tok("1 /* comment */ 2", 1)
  assert_eq(t.type, "Number")
  assert_eq(t.value, 1)
  local t2 = P.tok("1 /* comment */ 2", 2)
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
  assert(tokens)
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "+")
end)

test("tokenize --- maximal munch", function()
  local tokens = ljs.tokenize("---")
  assert(tokens)
  assert_eq(tokens[1].type, "--")
  assert_eq(tokens[2].type, "-")
end)

test("tokenize + + with space is not ++", function()
  local tokens = ljs.tokenize("+ +")
  assert(tokens)
  assert_eq(tokens[1].type, "+")
  assert_eq(tokens[2].type, "+")
end)

test("tokenize - - with space is not --", function()
  local tokens = ljs.tokenize("- -")
  assert(tokens)
  assert_eq(tokens[1].type, "-")
  assert_eq(tokens[2].type, "-")
end)

test("tokenize ++++ (two increments)", function()
  local tokens = ljs.tokenize("++++")
  assert(tokens)
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
  assert(tokens)
  assert_eq(tokens[1].type, "+")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize * = with space is not *=", function()
  local tokens = ljs.tokenize("* =")
  assert(tokens)
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize +++= maximal munch: ++ +=", function()
  local tokens = ljs.tokenize("+++=")
  assert(tokens)
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "+=")
end)

test("tokenize ---= maximal munch: -- -=", function()
  local tokens = ljs.tokenize("---=")
  assert(tokens)
  assert_eq(tokens[1].type, "--")
  assert_eq(tokens[2].type, "-=")
end)

test("tokenize ** (exponentiation)", function()
  local tokens = ljs.tokenize("**")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
end)

test("tokenize **= (exponentiation assignment)", function()
  local tokens = ljs.tokenize("**=")
  assert(tokens)
  assert_eq(tokens[1].type, "**=")
end)

test("tokenize *** maximal munch: ** *", function()
  local tokens = ljs.tokenize("***")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "*")
end)

test("tokenize **** maximal munch: ** **", function()
  local tokens = ljs.tokenize("****")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "**")
end)

test("tokenize ***= maximal munch: ** *=", function()
  local tokens = ljs.tokenize("***=")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "*=")
end)

test("tokenize * * with space is not **", function()
  local tokens = ljs.tokenize("* *")
  assert(tokens)
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "*")
end)

test("tokenize ** = with space is not **=", function()
  local tokens = ljs.tokenize("** =")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize * *= maximal munch: * *=", function()
  local tokens = ljs.tokenize("* *=")
  assert(tokens)
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "*=")
end)

-- ============================================================================
-- INVARIANT: tokenize() always returns a stream ending with EOF
-- Contract: the parser assumes EOF-terminated streams (stream.eof() checks
-- peek().type == TOKEN.EOF). If tokenize ever returns a stream without a
-- trailing EOF, the parser could read past the array bounds.
-- Catches: accidental removal of the EOF-emission logic at the end of tokenize().

test("invariant: tokenize always ends with EOF", function()
  local sources = {
    "",
    "42",
    "let x = 1;",
    "  \n  \t  ",
    "// comment\n",
    "a + b * c",
    "function f() { return 1; }",
    "1 + 2; 3 - 4;",
    '"hello"',
    "[]",
    "{}",
    "true false null undefined",
  }
  for _, src in ipairs(sources) do
    local tokens = ljs.tokenize(src)
    assert(tokens)
    assert(tokens and #tokens > 0, "expected tokens for: " .. src)
    assert_eq(tokens[#tokens].type, "EOF", "last token must be EOF for: " .. src)
  end
end)

-- ============================================================================
-- INVARIANT: every token has valid line (>=1) and col (>=1)
-- Contract: error messages in the parser use token.line and token.col.
-- If positions are ever zero or nil, error messages become misleading.
-- Catches: off-by-one bugs in the line/col tracking inside advance().

test("invariant: all tokens have valid positions", function()
  local sources = {
    "let x = 1;\nlet y = 2;",
    "/* comment */\nfoo",
    "  \n  \n  a",
    '"hello\\nworld"',
    "a + b\n* c",
  }
  for _, src in ipairs(sources) do
    local tokens = ljs.tokenize(src)
    assert(tokens)
    if tokens then
      for i, t in ipairs(tokens) do
        assert(t.line >= 1, string.format("token %d has line=%s in: %s", i, tostring(t.line), src))
        assert(t.col >= 1, string.format("token %d has col=%s in: %s", i, tostring(t.col), src))
      end
    end
  end
end)

-- ============================================================================
-- String escape completeness: \r, \b, \f are defined in the tokenizer
-- switch but never tested. If the escape table entries were removed or
-- mistyped, strings with these chars would silently produce wrong values.

test("tokenize escape \\r", function()
  assert_tok('"a\\rb"', 1, "String", "a\rb")
end)

test("tokenize escape \\b", function()
  assert_tok('"a\\bb"', 1, "String", "a\bb")
end)

test("tokenize escape \\f", function()
  assert_tok('"a\\fb"', 1, "String", "a\fb")
end)

-- ============================================================================
-- Unterminated multi-line comment: the tokenizer has a specific error path
-- for /* without */. If this path breaks, the tokenizer might loop forever
-- or silently produce wrong tokens.

test("tokenize error: unterminated multi-line comment", function()
  assert_tokenize_fail("/* never ends", "Unterminated")
end)
