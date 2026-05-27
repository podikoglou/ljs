local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local parser = require("ljs.parser")
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

test("tokenize escape \\0", function()
  assert_tok('"a\\0b"', 1, "String", "a" .. string.char(0) .. "b")
end)

test("tokenize legacy octal escape \\1", function()
  assert_tok('"\\1"', 1, "String", string.char(1))
end)

test("tokenize legacy octal escape \\7", function()
  assert_tok('"\\7"', 1, "String", string.char(7))
end)

test("tokenize legacy octal escape \\5 in context", function()
  assert_tok('"a\\5b"', 1, "String", "a" .. string.char(5) .. "b")
end)

test("tokenize legacy octal escape \\12 (two-digit)", function()
  assert_tok('"\\12"', 1, "String", string.char(10))
end)

test("tokenize legacy octal escape \\77 (two-digit max for 4-7)", function()
  assert_tok('"\\77"', 1, "String", string.char(63))
end)

test("tokenize legacy octal escape \\01 (two-digit starting 0)", function()
  assert_tok('"\\01"', 1, "String", string.char(1))
end)

test("tokenize legacy octal escape \\07 (two-digit starting 0)", function()
  assert_tok('"\\07"', 1, "String", string.char(7))
end)

test("tokenize legacy octal escape \\123 (three-digit)", function()
  assert_tok('"\\123"', 1, "String", string.char(83))
end)

test("tokenize legacy octal escape \\377 (max octal value 255)", function()
  assert_tok('"\\377"', 1, "String", string.char(255))
end)

test("tokenize legacy octal escape \\100 (three-digit starting 1)", function()
  assert_tok('"\\100"', 1, "String", string.char(64))
end)

test("tokenize legacy octal escape \\200 (three-digit starting 2)", function()
  assert_tok('"\\200"', 1, "String", string.char(128))
end)

test("tokenize legacy octal: \\0 alone is null", function()
  assert_tok('"\\0"', 1, "String", string.char(0))
end)

test("tokenize legacy octal: \\0x is null + literal x", function()
  assert_tok('"\\0x"', 1, "String", string.char(0) .. "x")
end)

test("tokenize legacy octal: \\08 is null + literal 8", function()
  assert_tok('"\\08"', 1, "String", string.char(0) .. "8")
end)

test("tokenize legacy octal: \\09 is null + literal 9", function()
  assert_tok('"\\09"', 1, "String", string.char(0) .. "9")
end)

test("tokenize NonOctalDecimalEscapeSequence \\8", function()
  assert_tok('"\\8"', 1, "String", "8")
end)

test("tokenize NonOctalDecimalEscapeSequence \\9", function()
  assert_tok('"\\9"', 1, "String", "9")
end)

test("tokenize legacy octal: \\078 is \\07 octal + literal 8", function()
  assert_tok('"\\078"', 1, "String", string.char(7) .. "8")
end)

test("tokenize legacy octal: \\400 is \\40 octal + literal 0", function()
  assert_tok('"\\400"', 1, "String", string.char(32) .. "0")
end)

test("tokenize legacy octal: \\077 is octal 63", function()
  assert_tok('"\\077"', 1, "String", string.char(63))
end)

test("tokenize legacy octal: \\00 is octal 0", function()
  assert_tok('"\\00"', 1, "String", string.char(0))
end)

test("tokenize legacy octal: \\000 is octal 0", function()
  assert_tok('"\\000"', 1, "String", string.char(0))
end)

test("tokenize escape \\xHH", function()
  assert_tok('"\\x41"', 1, "String", "A")
end)

test("tokenize escape \\xFF", function()
  assert_tok('"\\xFF"', 1, "String", string.char(255))
end)

test("tokenize escape \\uXXXX", function()
  assert_tok('"\\u0041"', 1, "String", "A")
end)

test("tokenize escape \\uXXXX multi-byte", function()
  assert_tok('"\\u00E9"', 1, "String", "\xC3\xA9")
end)

test("tokenize escape \\u{X...}", function()
  assert_tok('"\\u{41}"', 1, "String", "A")
end)

test("tokenize escape \\u{X...} emoji", function()
  assert_tok('"\\u{1F600}"', 1, "String", "\xF0\x9F\x98\x80")
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

test("tokenize == (loose equality)", function()
  local tokens = parser.tokenize("a == b")
  assert(tokens)
  assert_tok("a == b", 2, "==")
end)

test("tokenize != (loose inequality)", function()
  local tokens = parser.tokenize("a != b")
  assert(tokens)
  assert_tok("a != b", 2, "!=")
end)

test("tokenize operators", function()
  local src = "+ - * / % === !== == != < > <= >= && || = ! ~ ++ -- += -= *= /= %= ** **="
  assert_tok(src, 1, "+")
  assert_tok(src, 2, "-")
  assert_tok(src, 3, "*")
  assert_tok(src, 4, "/")
  assert_tok(src, 5, "%")
  assert_tok(src, 6, "===")
  assert_tok(src, 7, "!==")
  assert_tok(src, 8, "==")
  assert_tok(src, 9, "!=")
  assert_tok(src, 10, "<")
  assert_tok(src, 11, ">")
  assert_tok(src, 12, "<=")
  assert_tok(src, 13, ">=")
  assert_tok(src, 14, "&&")
  assert_tok(src, 15, "||")
  assert_tok(src, 16, "=")
  assert_tok(src, 17, "!")
  assert_tok(src, 18, "~")
  assert_tok(src, 19, "++")
  assert_tok(src, 20, "--")
  assert_tok(src, 21, "+=")
  assert_tok(src, 22, "-=")
  assert_tok(src, 23, "*=")
  assert_tok(src, 24, "/=")
  assert_tok(src, 25, "%=")
  assert_tok(src, 26, "**")
  assert_tok(src, 27, "**=")
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

test("tokenize error: unexpected character", function()
  assert_tokenize_fail("@", "Unexpected character")
end)

test("tokenize +++ maximal munch", function()
  local tokens = parser.tokenize("+++")
  assert(tokens)
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "+")
end)

test("tokenize --- maximal munch", function()
  local tokens = parser.tokenize("---")
  assert(tokens)
  assert_eq(tokens[1].type, "--")
  assert_eq(tokens[2].type, "-")
end)

test("tokenize + + with space is not ++", function()
  local tokens = parser.tokenize("+ +")
  assert(tokens)
  assert_eq(tokens[1].type, "+")
  assert_eq(tokens[2].type, "+")
end)

test("tokenize - - with space is not --", function()
  local tokens = parser.tokenize("- -")
  assert(tokens)
  assert_eq(tokens[1].type, "-")
  assert_eq(tokens[2].type, "-")
end)

test("tokenize ++++ (two increments)", function()
  local tokens = parser.tokenize("++++")
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
  local tokens = parser.tokenize("+ =")
  assert(tokens)
  assert_eq(tokens[1].type, "+")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize * = with space is not *=", function()
  local tokens = parser.tokenize("* =")
  assert(tokens)
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize +++= maximal munch: ++ +=", function()
  local tokens = parser.tokenize("+++=")
  assert(tokens)
  assert_eq(tokens[1].type, "++")
  assert_eq(tokens[2].type, "+=")
end)

test("tokenize ---= maximal munch: -- -=", function()
  local tokens = parser.tokenize("---=")
  assert(tokens)
  assert_eq(tokens[1].type, "--")
  assert_eq(tokens[2].type, "-=")
end)

test("tokenize ** (exponentiation)", function()
  local tokens = parser.tokenize("**")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
end)

test("tokenize **= (exponentiation assignment)", function()
  local tokens = parser.tokenize("**=")
  assert(tokens)
  assert_eq(tokens[1].type, "**=")
end)

test("tokenize *** maximal munch: ** *", function()
  local tokens = parser.tokenize("***")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "*")
end)

test("tokenize **** maximal munch: ** **", function()
  local tokens = parser.tokenize("****")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "**")
end)

test("tokenize ***= maximal munch: ** *=", function()
  local tokens = parser.tokenize("***=")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "*=")
end)

test("tokenize * * with space is not **", function()
  local tokens = parser.tokenize("* *")
  assert(tokens)
  assert_eq(tokens[1].type, "*")
  assert_eq(tokens[2].type, "*")
end)

test("tokenize ** = with space is not **=", function()
  local tokens = parser.tokenize("** =")
  assert(tokens)
  assert_eq(tokens[1].type, "**")
  assert_eq(tokens[2].type, "=")
end)

test("tokenize * *= maximal munch: * *=", function()
  local tokens = parser.tokenize("* *=")
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
    local tokens = parser.tokenize(src)
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
    local tokens = parser.tokenize(src)
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

test("tokenize escape \\v", function()
  assert_tok('"a\\vb"', 1, "String", "a\vb")
end)

-- ============================================================================
-- Unterminated multi-line comment: the tokenizer has a specific error path
-- for /* without */. If this path breaks, the tokenizer might loop forever
-- or silently produce wrong tokens.

test("tokenize error: unterminated multi-line comment", function()
  assert_tokenize_fail("/* never ends", "Unterminated")
end)

-- ============================================================================
-- INVARIANT: token type determines value type
-- Contract: the docstring says "value is present for identifiers/keywords
-- (string), numbers (number), booleans (true/false), strings (unescaped
-- string). Absent for punctuation."  Downstream consumers (parser, error
-- messages) rely on this — a nil value where a string was expected, or a
-- non-nil value where nil was expected, would cascade into obscure bugs.
-- Catches: accidental addition of value to punctuation tokens, or removal
-- of value from literal/identifier tokens.

test("invariant: token value type matches token type", function()
  local punctuation = {
    ["("] = true,
    [")"] = true,
    ["{"] = true,
    ["}"] = true,
    ["["] = true,
    ["]"] = true,
    [","] = true,
    [";"] = true,
    [":"] = true,
    ["."] = true,
    ["?"] = true,
    ["+"] = true,
    ["-"] = true,
    ["*"] = true,
    ["/"] = true,
    ["%"] = true,
    ["==="] = true,
    ["!=="] = true,
    ["=="] = true,
    ["!="] = true,
    ["<"] = true,
    [">"] = true,
    ["<="] = true,
    [">="] = true,
    ["&&"] = true,
    ["||"] = true,
    ["="] = true,
    ["!"] = true,
    ["~"] = true,
    ["=>"] = true,
    ["++"] = true,
    ["--"] = true,
    ["+="] = true,
    ["-="] = true,
    ["*="] = true,
    ["**="] = true,
    ["/="] = true,
    ["%="] = true,
    ["&"] = true,
    ["|"] = true,
    ["^"] = true,
    ["<<"] = true,
    [">>"] = true,
    [">>>"] = true,
    ["&="] = true,
    ["|="] = true,
    ["^="] = true,
    ["<<="] = true,
    [">>="] = true,
    [">>>="] = true,
  }

  local src = "+ - * / % === !== == != < > <= >= && || = ! ~ => ++ -- += -= *= **= /= %= & | ^ << >> >>> &= |= ^= <<= >>= >>>="
    .. ' let x = 42; "hello" true false null undefined'
  local tokens = parser.tokenize(src)
  assert(tokens)
  for i, t in ipairs(tokens) do
    if t.type == "EOF" then
      assert(t.value == nil, string.format("EOF token %d should have nil value", i))
    elseif punctuation[t.type] then
      assert(
        t.value == nil,
        string.format(
          "punctuation token %d (%s) should have nil value, got %s",
          i,
          t.type,
          tostring(t.value)
        )
      )
    elseif t.type == "Number" then
      assert(
        type(t.value) == "number",
        string.format("Number token %d should have number value, got %s", i, type(t.value))
      )
    elseif t.type == "String" then
      assert(
        type(t.value) == "string",
        string.format("String token %d should have string value, got %s", i, type(t.value))
      )
    elseif t.type == "Boolean" then
      assert(
        type(t.value) == "boolean",
        string.format("Boolean token %d should have boolean value, got %s", i, type(t.value))
      )
    elseif t.type == "Identifier" then
      assert(
        type(t.value) == "string",
        string.format("Identifier token %d should have string value, got %s", i, type(t.value))
      )
    elseif t.type == "Null" or t.type == "Undefined" then
      assert(
        t.value == nil,
        string.format("%s token %d should have nil value, got %s", t.type, i, tostring(t.value))
      )
    end
  end
end)

-- ============================================================================
-- INVARIANT: null and undefined tokens have value=nil but distinct types
-- Contract: null and undefined are distinct token types ("Null" vs "Undefined")
-- even though both carry nil values. The parser uses the type to build
-- different AST nodes (NullLiteral vs UndefinedLiteral).
-- Catches: accidental unification of Null and Undefined types.

test("invariant: null and undefined produce distinct token types", function()
  local null_t = P.tok("null", 1)
  local undef_t = P.tok("undefined", 1)
  assert_eq(null_t.type, "Null")
  assert_eq(undef_t.type, "Undefined")
  assert(null_t.type ~= undef_t.type, "null and undefined must have distinct types")
end)

-- ============================================================================
-- SCIENTIFIC NOTATION (EXPONENT) NUMBER LITERALS
-- Spec: ES2026 §12.9.3 NumericLiteral → DecimalLiteral → ExponentPart
--   ExponentPart :: ExponentIndicator SignedInteger
--   ExponentIndicator :: one of e E
--   SignedInteger :: [+/-] DecimalDigits
-- ============================================================================

-- Basic exponent forms (lowercase e)
test("tokenize scientific notation: 1e10", function()
  assert_tok("1e10", 1, "Number", 1e10)
end)

test("tokenize scientific notation: 1e0", function()
  assert_tok("1e0", 1, "Number", 1)
end)

test("tokenize scientific notation: 1e1", function()
  assert_tok("1e1", 1, "Number", 10)
end)

test("tokenize scientific notation: 1e+10", function()
  assert_tok("1e+10", 1, "Number", 1e10)
end)

test("tokenize scientific notation: 1e-10", function()
  assert_tok("1e-10", 1, "Number", 1e-10)
end)

-- Uppercase E
test("tokenize scientific notation: 1E10", function()
  assert_tok("1E10", 1, "Number", 1E10)
end)

test("tokenize scientific notation: 1E+4", function()
  assert_tok("1E+4", 1, "Number", 1E4)
end)

test("tokenize scientific notation: 1E-2", function()
  assert_tok("1E-2", 1, "Number", 1E-2)
end)

-- Float with exponent (DecimalIntegerLiteral . DecimalDigits ExponentPart)
test("tokenize scientific notation: 1.5e2", function()
  assert_tok("1.5e2", 1, "Number", 150)
end)

test("tokenize scientific notation: 1.5e-2", function()
  assert_tok("1.5e-2", 1, "Number", 0.015)
end)

test("tokenize scientific notation: 3.14e+0", function()
  assert_tok("3.14e+0", 1, "Number", 3.14)
end)

test("tokenize scientific notation: 0.5e3", function()
  assert_tok("0.5e3", 1, "Number", 500)
end)

test("tokenize scientific notation: 0.1e-1", function()
  assert_tok("0.1e-1", 1, "Number", 0.01)
end)

-- Large and small exponents
test("tokenize scientific notation: 1e308", function()
  assert_tok("1e308", 1, "Number", 1e308)
end)

test("tokenize scientific notation: 1e-308", function()
  assert_tok("1e-308", 1, "Number", 1e-308)
end)

test("tokenize scientific notation: 9.99e99", function()
  assert_tok("9.99e99", 1, "Number", 9.99e99)
end)

-- Zero with exponent
test("tokenize scientific notation: 0e10", function()
  assert_tok("0e10", 1, "Number", 0)
end)

test("tokenize scientific notation: 0e0", function()
  assert_tok("0e0", 1, "Number", 0)
end)

test("tokenize scientific notation: 0e+5", function()
  assert_tok("0e+5", 1, "Number", 0)
end)

test("tokenize scientific notation: 0e-5", function()
  assert_tok("0e-5", 1, "Number", 0)
end)

-- Multi-digit integer base
test("tokenize scientific notation: 123e4", function()
  assert_tok("123e4", 1, "Number", 123e4)
end)

test("tokenize scientific notation: 999e1", function()
  assert_tok("999e1", 1, "Number", 9990)
end)

-- Multi-digit exponent
test("tokenize scientific notation: 1e20", function()
  assert_tok("1e20", 1, "Number", 1e20)
end)

test("tokenize scientific notation: 1e+20", function()
  assert_tok("1e+20", 1, "Number", 1e20)
end)

test("tokenize scientific notation: 1e-20", function()
  assert_tok("1e-20", 1, "Number", 1e-20)
end)

-- Exponent in expression context (token boundary tests)
test("tokenize scientific notation in expression: x + 1e10", function()
  assert_tok("x + 1e10", 1, "Identifier", "x")
  assert_tok("x + 1e10", 2, "+")
  assert_tok("x + 1e10", 3, "Number", 1e10)
end)

test("tokenize scientific notation in expression: 1e10 + 2e5", function()
  assert_tok("1e10 + 2e5", 1, "Number", 1e10)
  assert_tok("1e10 + 2e5", 2, "+")
  assert_tok("1e10 + 2e5", 3, "Number", 2e5)
end)

test("tokenize scientific notation followed by semicolon: 1e10;", function()
  assert_tok("1e10;", 1, "Number", 1e10)
  assert_tok("1e10;", 2, ";")
end)

test("tokenize scientific notation in parens: (1e10)", function()
  assert_tok("(1e10)", 1, "(")
  assert_tok("(1e10)", 2, "Number", 1e10)
  assert_tok("(1e10)", 3, ")")
end)

test("tokenize scientific notation as function arg: f(1e10)", function()
  assert_tok("f(1e10)", 1, "Identifier", "f")
  assert_tok("f(1e10)", 2, "(")
  assert_tok("f(1e10)", 3, "Number", 1e10)
  assert_tok("f(1e10)", 4, ")")
end)

-- NOT scientific notation: e/E as identifier or part of identifier
test("tokenize: e10 is identifier, not exponent", function()
  assert_tok("e10", 1, "Identifier", "e10")
end)

test("tokenize: E10 is identifier, not exponent", function()
  assert_tok("E10", 1, "Identifier", "E10")
end)

test("tokenize: xe10 is identifier", function()
  assert_tok("xe10", 1, "Identifier", "xe10")
end)

test("tokenize: 1e is not a valid number (no exponent digits)", function()
  assert_tokenize_fail("1e", "number")
end)

test("tokenize: 1E is not a valid number (no exponent digits)", function()
  assert_tokenize_fail("1E", "number")
end)

test("tokenize: 1e+ is not a valid number (no exponent digits)", function()
  assert_tokenize_fail("1e+", "number")
end)

test("tokenize: 1e- is not a valid number (no exponent digits)", function()
  assert_tokenize_fail("1e-", "number")
end)

test("tokenize: 1e+x is not a valid number", function()
  assert_tokenize_fail("1e+x", "number")
end)

test("tokenize: 1.5e is not a valid number", function()
  assert_tokenize_fail("1.5e", "number")
end)

test("tokenize: 1.5e- is not a valid number", function()
  assert_tokenize_fail("1.5e-", "number")
end)

-- Exponent must have digits after e/E, even with sign
-- Exponent must have digits after e/E (V8 rejects "1e;" as Invalid or unexpected token)
test("tokenize: 1e; should fail (e with no exponent digits)", function()
  assert_tokenize_fail("1e;", "number")
end)

test("tokenize: 1e+; should fail (sign but no digits)", function()
  assert_tokenize_fail("1e+;", "number")
end)

test("tokenize: 1e-; should fail (sign but no digits)", function()
  assert_tokenize_fail("1e-;", "number")
end)

-- Exponent with decimal in exponent is NOT valid (e.g. 1e1.5)
-- .5 as a standalone number literal is not supported (numbers must start
-- with a digit), so the dot becomes a punctuation token.
test("tokenize: 1e1.5 should parse 1e1 as number then dot then number", function()
  assert_tok("1e1.5", 1, "Number", 1e1)
  assert_tok("1e1.5", 2, ".")
  assert_tok("1e1.5", 3, "Number", 5)
end)

-- Multiple exponent indicators is invalid
test("tokenize: 1e1e2 should parse as 1e1 then identifier e2", function()
  assert_tok("1e1e2", 1, "Number", 1e1)
  assert_tok("1e1e2", 2, "Identifier", "e2")
end)

-- Exponent on zero-fraction: "0.0e5"
test("tokenize scientific notation: 0.0e5", function()
  assert_tok("0.0e5", 1, "Number", 0)
end)

-- Negative number is NOT a literal; it's unary minus + number
-- This tests that the tokenizer doesn't try to handle -e as exponent
test("tokenize: -1e10 is unary minus then number", function()
  assert_tok("-1e10", 1, "-")
  assert_tok("-1e10", 2, "Number", 1e10)
end)

-- Scientific notation value type invariant
test("invariant: scientific notation token has number value", function()
  local t = P.tok("1e10", 1)
  assert_eq(t.type, "Number")
  assert_eq(type(t.value), "number")
end)

-- EOF invariant with scientific notation
test("invariant: scientific notation tokenize ends with EOF", function()
  local tokens = parser.tokenize("1e10")
  assert(tokens)
  assert_eq(tokens[#tokens].type, "EOF")
end)

-- Position tracking: exponent chars should advance column correctly
test("invariant: scientific notation token has valid position", function()
  local t = P.tok("  1e10", 1)
  assert(t.line >= 1)
  assert(t.col >= 1)
  assert_eq(t.col, 3)
end)

-- Hex literal should NOT get exponent (hex digits include e, so 0xFFe10 is hex 0xFFE10)
test("tokenize: 0xFFe10 is hex number, not exponent", function()
  assert_tok("0xFFe10", 1, "Number", 1048080)
end)
