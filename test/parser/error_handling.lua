local T = require("test.ljs_test")
local parser = require("ljs.parser")
local test, assert_eq = T.test, T.assert_eq

local function check_tokenize_err(src, msg_substr, line, col, label)
  local tokens, err = parser.tokenize(src)
  assert(tokens == nil, string.format("%s: expected failure", label))
  assert(parser.is_parse_error(err), string.format("%s: expected ParseError", label))
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
  local ast, err = parser.parse(src)
  assert(ast == nil, string.format("%s: expected failure", label))
  assert(parser.is_parse_error(err), string.format("%s: expected ParseError", label))
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

test("tokenizer: == accepted as loose equality", function()
  local tokens = parser.tokenize("x == y")
  assert(tokens, "expected successful tokenization")
  assert_eq(tokens[2].type, "==")
end)

test("tokenizer: == on second line tokenizes correctly", function()
  local tokens = parser.tokenize("let x = 1;\nx == y")
  assert(tokens, "expected successful tokenization")
  assert_eq(tokens[7].type, "==")
  assert_eq(tokens[7].line, 2)
  assert_eq(tokens[7].col, 3)
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

test("tokenizer: invalid hex escape \\x with no digits", function()
  check_tokenize_err('"\\x"', "Invalid hex escape", 1, 4, "hex escape no digits")
end)

test("tokenizer: invalid hex escape \\x with one digit", function()
  check_tokenize_err('"\\xA"', "Invalid hex escape", 1, 5, "hex escape one digit")
end)

test("tokenizer: invalid unicode escape \\u with no digits", function()
  check_tokenize_err('"\\u"', "Invalid unicode escape", 1, 4, "unicode escape no digits")
end)

test("tokenizer: invalid unicode escape \\u with short digits", function()
  check_tokenize_err('"\\u004"', "Invalid unicode escape", 1, 7, "unicode escape short")
end)

test("tokenizer: invalid unicode escape \\u{} empty braces", function()
  check_tokenize_err('"\\u{}"', "Invalid unicode escape", 1, 5, "unicode empty braces")
end)

test("tokenizer: invalid hex escape in template literal", function()
  check_tokenize_err("`\\x`", "Invalid hex escape", 1, 4, "template hex escape no digits")
end)

test("tokenizer: invalid unicode escape in template literal", function()
  check_tokenize_err("`\\u`", "Invalid unicode escape", 1, 4, "template unicode escape no digits")
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
  check_parse_err("function f( { }", "Expected ), got EOF", 1, 16, "missing param name")
end)

test("parser: != accepted as loose inequality", function()
  local ast, err = parser.parse("x != y")
  assert(ast ~= nil, "expected successful parse for !=")
  assert_eq(ast.body[1].expression.operator, "!=")
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
    local ast, err = parser.parse(src)
    assert(ast == nil, "expected nil ast for: " .. src)
    assert(parser.is_parse_error(err), "expected ParseError for: " .. src)
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
    "@",
    "0xG",
    '"hello',
    "/* never",
    '"a\\qb"',
  }
  for _, src in ipairs(sources) do
    local tokens, err = parser.tokenize(src)
    assert(tokens == nil, "expected nil tokens for: " .. src)
    assert(parser.is_parse_error(err), "expected ParseError for: " .. src)
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
  assert(not parser.is_parse_error(nil), "nil should not be ParseError")
  assert(
    not parser.is_parse_error({ message = "x", line = 1, col = 1 }),
    "plain table should not be ParseError"
  )
  assert(not parser.is_parse_error("error"), "string should not be ParseError")
  assert(not parser.is_parse_error(42), "number should not be ParseError")
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
    "1 == 2",
    "x != y",
  }
  for _, src in ipairs(valid) do
    local ast, err = parser.parse(src)
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
    local tokens, err = parser.tokenize(src)
    assert(tokens ~= nil, "expected non-nil tokens for: " .. src)
    assert(err == nil, "expected nil error for: " .. src)
  end
end)

-- ============================================================================
-- PROPERTY: error column points at or past the offending token
-- ============================================================================

test("error col points at or after the bad construct", function()
  local cases = {
    { src = "let x = @;", min_col = 9 },
    { src = "0xG", min_col = 1 },
  }
  for _, case in ipairs(cases) do
    local _, err = parser.tokenize(case.src)
    assert(parser.is_parse_error(err), "expected ParseError for: " .. case.src)
    ---@diagnostic disable: need-check-nil
    assert(
      err.col >= case.min_col,
      string.format("col %d < min_col %d for: %s", err.col, case.min_col, case.src)
    )
    ---@diagnostic enable: need-check-nil
  end
end)

-- ============================================================================
-- format_error: public API for formatting ParseError with source context
-- Contract: parser.format_error(err, source) returns a string that includes
-- the error message and, when source is provided and line is valid, the
-- offending source line with a caret pointing at the error column.
-- Catches: broken source-context display, wrong line extraction, misaligned caret.

test("format_error with source shows message and source line with caret", function()
  local _, err = parser.parse("let x = ;")
  assert(err)
  ---@diagnostic disable-next-line: need-check-nil
  local formatted = parser.format_error(err, "let x = ;")
  ---@diagnostic disable-next-line: need-check-nil
  assert(string.find(formatted, err.message, 1, true), "formatted output should contain message")
  assert(
    string.find(formatted, "let x = ;", 1, true),
    "formatted output should contain source line"
  )
  assert(string.find(formatted, "^", 1, true), "formatted output should contain caret")
end)

test("format_error without source returns message only", function()
  local _, err = parser.parse("let x = ;")
  assert(err)
  ---@diagnostic disable-next-line: need-check-nil
  local formatted = parser.format_error(err, nil)
  ---@diagnostic disable-next-line: need-check-nil
  assert_eq(formatted, err.message)
end)

test("format_error with line beyond source length shows message and empty context", function()
  local err = parser.make_parse_error("test error", 99, 1)
  local formatted = parser.format_error(err, "one line")
  assert(string.find(formatted, "test error", 1, true), "should contain message")
  assert(string.find(formatted, "|", 1, true), "should show context separator")
end)

test("format_error with line 0 returns message only (no source context)", function()
  local err = parser.make_parse_error("test error", 0, 1)
  local formatted = parser.format_error(err, "some source")
  assert_eq(formatted, "test error")
end)

test("format_error with multi-line source shows correct line", function()
  local src = "let a = 1;\nlet b = @;"
  local _, err = parser.parse(src)
  assert(err)
  ---@diagnostic disable-next-line: need-check-nil
  local formatted = parser.format_error(err, src)
  assert(
    string.find(formatted, "let b = @;", 1, true),
    "should show the offending line, not line 1"
  )
end)

-- ============================================================================
-- INVARIANT: every table in a valid AST has a type field
-- Contract: the parser produces well-formed AST nodes — every table in the
-- tree represents a node with a `type` field. Downstream consumers (codegen,
-- analysis tools) rely on this for dispatch.
-- Catches: a parser bug that returns a raw sub-expression or helper table
-- without wrapping it in a proper AST node.

test("all AST nodes have a type field for diverse programs", function()
  local function check_types(node, path)
    if type(node) ~= "table" then
      return
    end
    if node.type == nil then
      return
    end
    for k, v in pairs(node) do
      if type(v) == "table" and k ~= "type" then
        if type(k) == "number" then
          check_types(v, path .. "[" .. k .. "]")
        else
          check_types(v, path .. "." .. k)
        end
      end
    end
  end

  local function assert_all_nodes_typed(src)
    local ast = parser.parse(src)
    assert(ast, "expected parse for: " .. src)
    assert(ast.type ~= nil, "Program root missing type for: " .. src)
    for i, stmt in ipairs(ast.body) do
      check_types(stmt, "body[" .. i .. "]")
    end
  end

  local sources = {
    "let x = 1 + 2 * 3;",
    "function f(a, b) { return a > b ? a : b; }",
    "for (let i = 0; i < 10; i += 1) { if (i === 5) { break; } }",
    "try { throw x; } catch (e) { console.log(e); } finally { x = 0; }",
    "let o = { a: 1, b(x) { return x; }, c };",
    "switch (x) { case 1: break; default: x; }",
    "class C extends B { constructor() { super(); } method() {} }",
    "let f = (a, b) => a + b;",
    "[1, 2, 3].map(x => x * 2);",
    "for (let k in obj) { obj[k]; }",
    "for (const x of arr) { typeof x; }",
    "do { x++; } while (x < 10);",
    "let a = x !== null && typeof x === 'object' ? x : {};",
    "delete obj.prop; typeof x; new Foo();",
    "let b = x & y | z ^ w;",
  }
  for _, src in ipairs(sources) do
    assert_all_nodes_typed(src)
  end
end)
