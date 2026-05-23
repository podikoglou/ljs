local T = require("ljs_test")
local ljs = require("ljs_parser")
local test, assert_eq = T.test, T.assert_eq

local function check_tokenize_err(src, msg_substr, line, col, label)
  local tokens, err = ljs.tokenize(src)
  assert(tokens == nil, string.format("%s: expected failure", label))
  assert(ljs.is_parse_error(err), string.format("%s: expected ParseError", label))
  ---@diagnostic disable: need-check-nil
  assert(
    string.find(err.message, msg_substr, 1, true),
    string.format("%s: expected '%s' in '%s'", label, msg_substr, err.message)
  )
  assert_eq(err.line, line, label .. " line")
  assert_eq(err.col, col, label .. " col")
  ---@diagnostic enable: need-check-nil
end

local function check_parse_err(src, msg_substr, line, col, label)
  local ast, err = ljs.parse(src)
  assert(ast == nil, string.format("%s: expected failure", label))
  assert(ljs.is_parse_error(err), string.format("%s: expected ParseError", label))
  ---@diagnostic disable: need-check-nil
  assert(
    string.find(err.message, msg_substr, 1, true),
    string.format("%s: expected '%s' in '%s'", label, msg_substr, err.message)
  )
  assert_eq(err.line, line, label .. " line")
  assert_eq(err.col, col, label .. " col")
  ---@diagnostic enable: need-check-nil
end

-- ============================================================================
-- TOKENIZER ERRORS: message + position
-- ============================================================================

test("tokenizer: == rejected with message and position", function()
  check_tokenize_err("x == y", "Use ===", 1, 3, "== operator")
end)

test("tokenizer: == on second line has correct line number", function()
  check_tokenize_err("let x = 1;\nx == y", "Use ===", 2, 3, "== on line 2")
end)

test("tokenizer: unexpected character with message and position", function()
  check_tokenize_err("let x = @;", "Unexpected character", 1, 9, "@ character")
end)

test("tokenizer: invalid hex literal", function()
  check_tokenize_err("0xG", "Invalid hex", 1, 1, "hex literal")
end)

test("tokenizer: invalid escape sequence", function()
  check_tokenize_err('"a\\qb"', "Invalid escape", 1, 4, "bad escape")
end)

test("tokenizer: unterminated double-quoted string", function()
  check_tokenize_err('"hello', "Unterminated string", 1, 1, "unterminated string")
end)

test("tokenizer: unterminated single-quoted string", function()
  check_tokenize_err("'hello", "Unterminated string", 1, 1, "unterminated single-quoted string")
end)

test("tokenizer: invalid escape in single-quoted string", function()
  check_tokenize_err("'a\\qb'", "Invalid escape", 1, 4, "bad escape single-quoted")
end)

test("tokenizer: unexpected char on third line has correct position", function()
  check_tokenize_err(
    "let a = 1;\nlet b = 2;\nlet c = @;",
    "Unexpected character",
    3,
    9,
    "@ on line 3"
  )
end)

test("tokenizer: unterminated multi-line comment", function()
  check_tokenize_err("/* never ends", "Unterminated", 1, 14, "unterminated comment")
end)

-- ============================================================================
-- PARSER ERRORS: message + position
-- ============================================================================

test("parser: unexpected token identifies the token type", function()
  check_parse_err("let x = ;", "Unexpected token", 1, 9, "bare semicolon")
end)

test("parser: error on second line has correct line number", function()
  check_parse_err("let x = 1;\nlet y = ;", "Unexpected token", 2, 9, "line 2 error")
end)

test("parser: banned async keyword", function()
  check_parse_err("async", "not supported", 1, 1, "async")
end)

test("parser: banned await keyword", function()
  check_parse_err("await x", "not supported", 1, 1, "await")
end)

test("parser: try without catch or finally", function()
  check_parse_err("try {}", "Expected catch or finally", 1, 7, "try alone")
end)

test("parser: for-in with multiple variables", function()
  check_parse_err("for (let x, y in obj) {}", "for-in loop requires", 1, 15, "multi var for-in")
end)

test("parser: for-in variable cannot have initializer", function()
  check_parse_err(
    "for (let x = 1 in obj) {}",
    "cannot have an initializer",
    1,
    16,
    "init in for-in"
  )
end)

test("parser: duplicate default in switch", function()
  check_parse_err(
    "switch(1) { default: break; default: break; }",
    "Duplicate default",
    1,
    29,
    "dup default"
  )
end)

test("parser: expected case or default in switch", function()
  check_parse_err("switch(1) { if", "Expected case or default", 1, 13, "bad switch body")
end)

test("parser: arrow function with non-identifier param", function()
  check_parse_err("(a, 1) => x", "Arrow function parameters", 1, 5, "arrow non-ident")
end)

test("parser: bare arrow token", function()
  check_parse_err("=> x", "Unexpected arrow", 1, 1, "bare arrow")
end)

test("parser: number as object property key", function()
  check_parse_err("let o = {123: 1}", "Expected property key", 1, 10, "number key")
end)

test("parser: missing colon after object key", function()
  check_parse_err("let o = {a 1}", "Expected ':'", 1, 12, "missing colon")
end)

test("parser: invalid method name in class body", function()
  check_parse_err("class C { 1() {} }", "Expected method name", 1, 11, "bad class method")
end)

test("parser: consume mismatch shows expected and actual", function()
  check_parse_err("function f( { }", "Expected Identifier, got {", 1, 13, "missing param name")
end)

test("parser: != produces an error (excluded operator)", function()
  local ast, err = ljs.parse("x != y")
  assert(ast == nil, "expected nil ast for !=")
  assert(ljs.is_parse_error(err), "expected ParseError for !=")
end)

test("parser: error on third line has correct line number", function()
  check_parse_err("let a = 1;\nlet b = 2;\nlet c = ;", "Unexpected token", 3, 9, "line 3 error")
end)

-- ============================================================================
-- PROPERTY: all error paths return well-formed ParseError
-- ============================================================================

test("all parse errors have line >= 1, col >= 1, non-empty message", function()
  local sources = {
    "==;",
    "{;}",
    "let = 3;",
    "++;",
    "5++;",
    "x += ;",
    "** 3;",
    "2 * * 3;",
    "try {}",
    "async",
    "=> x",
    "(a, 1) => x",
    "switch(1) { if }",
    "class C { 1() {} }",
    "let o = {123: 1}",
    "let o = {a 1}",
    "for (let x, y in obj) {}",
    "for (let x = 1 in obj) {}",
    "switch(1) { default: break; default: break; }",
    "let x = ;",
    "function f( { }",
    "await x",
  }
  for _, src in ipairs(sources) do
    local ast, err = ljs.parse(src)
    assert(ast == nil, "expected nil ast for: " .. src)
    assert(ljs.is_parse_error(err), "expected ParseError for: " .. src)
    ---@diagnostic disable-next-line: need-check-nil
    assert(type(err.message) == "string" and #err.message > 0, "missing message for: " .. src)
    ---@diagnostic disable-next-line: need-check-nil
    assert(err.line >= 1, "line < 1 for: " .. src)
    ---@diagnostic disable-next-line: need-check-nil
    assert(err.col >= 1, "col < 1 for: " .. src)
  end
end)

test("all tokenize errors have line >= 1, col >= 1, non-empty message", function()
  local sources = {
    "==",
    "x == y",
    "@",
    "0xG",
    '"hello',
    "/* never",
    '"a\\qb"',
  }
  for _, src in ipairs(sources) do
    local tokens, err = ljs.tokenize(src)
    assert(tokens == nil, "expected nil tokens for: " .. src)
    assert(ljs.is_parse_error(err), "expected ParseError for: " .. src)
    ---@diagnostic disable-next-line: need-check-nil
    assert(type(err.message) == "string" and #err.message > 0, "missing message for: " .. src)
    ---@diagnostic disable-next-line: need-check-nil
    assert(err.line >= 1, "line < 1 for: " .. src)
    ---@diagnostic disable-next-line: need-check-nil
    assert(err.col >= 1, "col < 1 for: " .. src)
  end
end)

-- ============================================================================
-- PROPERTY: is_parse_error is a precise type guard
-- ============================================================================

test("is_parse_error returns false for non-ParseError values", function()
  assert(not ljs.is_parse_error(nil), "nil should not be ParseError")
  assert(
    not ljs.is_parse_error({ message = "x", line = 1, col = 1 }),
    "plain table should not be ParseError"
  )
  assert(not ljs.is_parse_error("error"), "string should not be ParseError")
  assert(not ljs.is_parse_error(42), "number should not be ParseError")
end)

-- ============================================================================
-- PROPERTY: valid input never returns errors
-- ============================================================================

test("parse returns ast with no error for valid source", function()
  local valid = {
    "",
    "let x = 1;",
    "function f() { return 1; }",
    "let a = [1, 2, 3];",
    "let o = { x: 1 };",
    "if (true) {} else {}",
    "while (false) {}",
    "for (let i of arr) {}",
    "try {} catch (e) {}",
    "switch (x) { case 1: break; }",
    "(a) => a + 1",
    "class C {}",
  }
  for _, src in ipairs(valid) do
    local ast, err = ljs.parse(src)
    assert(ast ~= nil, "expected non-nil ast for: " .. src)
    assert(err == nil, "expected nil error for: " .. src)
  end
end)

test("tokenize returns tokens with no error for valid source", function()
  local valid = {
    "",
    "let x = 1;",
    "'hello'",
    '"world"',
  }
  for _, src in ipairs(valid) do
    local tokens, err = ljs.tokenize(src)
    assert(tokens ~= nil, "expected non-nil tokens for: " .. src)
    assert(err == nil, "expected nil error for: " .. src)
  end
end)

-- ============================================================================
-- PROPERTY: error column points at or past the offending token
-- ============================================================================

test("error col points at or after the bad construct", function()
  local cases = {
    { src = "x == y", min_col = 3 },
    { src = "let x = @;", min_col = 9 },
    { src = "0xG", min_col = 1 },
  }
  for _, case in ipairs(cases) do
    local _, err = ljs.tokenize(case.src)
    assert(ljs.is_parse_error(err), "expected ParseError for: " .. case.src)
    ---@diagnostic disable: need-check-nil
    assert(
      err.col >= case.min_col,
      string.format("col %d < min_col %d for: %s", err.col, case.min_col, case.src)
    )
    ---@diagnostic enable: need-check-nil
  end
end)
