local T = require("ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok_from_source, assert_tok, assert_tokenize_fail =
  P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs
local TK = ljs.TOKEN

-- PARSER TESTS - ERROR CASES
-- ============================================================================

test("this keyword is now supported", function()
  assert_parse_ok("this.x;", {
    A.expr_stmt(A.member(A.this_(), A.id("x"))),
  })
end)

test("error: async is not supported", function()
  assert_parse_fail("async function f() {}", "'async'")
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

test("parse postfix on parenthesized expression", function()
  local ast = ljs.parse("(x)++;")
  assert(ast, "expected parse to succeed")
end)

test("parse postfix on array literal", function()
  local ast = ljs.parse("[1, 2]++;")
  assert(ast, "expected parse to succeed")
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
    A.expr_stmt(A.bin("+", A.num(1), A.bin("*", A.num(2), A.num(3)))),
  })
end)

-- ============================================================================
-- INTEGRATION TESTS
-- ============================================================================

test("integration: full program with multiple statements", function()
  assert_parse_ok("let x = 10;\nlet y = 20;\nconsole.log(x + y);", {
    A.let("x", A.num(10)),
    A.let("y", A.num(20)),
    A.expr_stmt(
      A.call(A.member(A.id("console"), A.id("log")), { A.bin("+", A.id("x"), A.id("y")) })
    ),
  })
end)

test("integration: function with control flow", function()
  assert_parse_ok("function abs(n) { if (n < 0) { return -n; } else { return n; } }", {
    A.func(
      "abs",
      { A.id("n") },
      A.block({
        A.if_(
          A.bin("<", A.id("n"), A.num(0)),
          A.block({ A.ret(A.una("-", A.id("n"))) }),
          A.block({ A.ret(A.id("n")) })
        ),
      })
    ),
  })
end)

test("integration: object methods and calls", function()
  assert_parse_ok("let obj = {a: 1}; obj.a;", {
    A.let("obj", A.obj({ A.prop(A.id("a"), A.num(1)) })),
    A.expr_stmt(A.member(A.id("obj"), A.id("a"))),
  })
end)

test("integration: complex chained expression with arrow functions", function()
  assert_parse_ok("let result = arr.filter(x => x > 0).map(x => x * 2);", {
    A.let(
      "result",
      A.call(
        A.member(
          A.call(A.member(A.id("arr"), A.id("filter")), {
            A.arrow(
              { A.id("x") },
              A.block({
                A.ret(A.bin(">", A.id("x"), A.num(0))),
              })
            ),
          }),
          A.id("map")
        ),
        {
          A.arrow(
            { A.id("x") },
            A.block({
              A.ret(A.bin("*", A.id("x"), A.num(2))),
            })
          ),
        }
      )
    ),
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
    tok(TK.LET, "let"),
    tok(TK.IDENTIFIER, "x"),
    tok(TK.ASSIGN),
    tok(TK.NUMBER, 42),
    tok(TK.SEMICOLON),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.let("x", A.num(42)),
    })
  )
end)

test("parse_tokens: if/else", function()
  local tokens = {
    tok(TK.IF, "if"),
    tok(TK.LPAREN),
    tok(TK.IDENTIFIER, "x"),
    tok(TK.RPAREN),
    tok(TK.LBRACE),
    tok(TK.IDENTIFIER, "y"),
    tok(TK.SEMICOLON),
    tok(TK.RBRACE),
    tok(TK.ELSE, "else"),
    tok(TK.LBRACE),
    tok(TK.IDENTIFIER, "z"),
    tok(TK.SEMICOLON),
    tok(TK.RBRACE),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.if_(A.id("x"), A.block({ A.expr_stmt(A.id("y")) }), A.block({ A.expr_stmt(A.id("z")) })),
    })
  )
end)

test("parse_tokens: binary expression with precedence", function()
  local tokens = {
    tok(TK.NUMBER, 1),
    tok(TK.PLUS),
    tok(TK.NUMBER, 2),
    tok(TK.STAR),
    tok(TK.NUMBER, 3),
    tok(TK.SEMICOLON),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.expr_stmt(A.bin("+", A.num(1), A.bin("*", A.num(2), A.num(3)))),
    })
  )
end)

test("parse_tokens: error on unexpected token", function()
  local tokens = {
    tok(TK.RPAREN),
    tok(TK.EOF),
  }
  local ast, err = ljs.parse_tokens(tokens)
  assert_eq(ast, nil, "expected nil ast")
  assert(err ~= nil, "expected error message")
end)

test("parse_tokens: empty program", function()
  local ast = ljs.parse_tokens({ tok(TK.EOF) })
  assert_table_eq(ast, A.program({}))
end)

test("parse_tokens: compound assignment x += 1", function()
  local tokens = {
    tok(TK.IDENTIFIER, "x"),
    tok(TK.PLUS_ASSIGN),
    tok(TK.NUMBER, 1),
    tok(TK.SEMICOLON),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.expr_stmt(A.bin("+=", A.id("x"), A.num(1))),
    })
  )
end)

test("parse_tokens: ternary x ? 1 : 0", function()
  local tokens = {
    tok(TK.IDENTIFIER, "x"),
    tok(TK.QUESTION),
    tok(TK.NUMBER, 1),
    tok(TK.COLON),
    tok(TK.NUMBER, 0),
    tok(TK.SEMICOLON),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.expr_stmt(A.ternary(A.id("x"), A.num(1), A.num(0))),
    })
  )
end)

test("parse_tokens: do...while with braces", function()
  local tokens = {
    tok(TK.DO, "do"),
    tok(TK.LBRACE),
    tok(TK.IDENTIFIER, "x"),
    tok(TK.SEMICOLON),
    tok(TK.RBRACE),
    tok(TK.WHILE, "while"),
    tok(TK.LPAREN),
    tok(TK.IDENTIFIER, "y"),
    tok(TK.RPAREN),
    tok(TK.SEMICOLON),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.do_while(A.block({ A.expr_stmt(A.id("x")) }), A.id("y")),
    })
  )
end)

test("parse_tokens: do...while without braces", function()
  local tokens = {
    tok(TK.DO, "do"),
    tok(TK.IDENTIFIER, "x"),
    tok(TK.SEMICOLON),
    tok(TK.WHILE, "while"),
    tok(TK.LPAREN),
    tok(TK.IDENTIFIER, "y"),
    tok(TK.RPAREN),
    tok(TK.EOF),
  }
  local ast = ljs.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.do_while(A.expr_stmt(A.id("x")), A.id("y")),
    })
  )
end)

-- ============================================================================
-- INVARIANT: parse errors return nil, msg where msg starts with "parse error:"
-- Contract: callers pattern-match on "parse error:" to distinguish parse
-- failures from other nil returns. If the prefix changes, error handling
-- in downstream tools silently breaks.

test("error return convention: nil + 'parse error:' prefix", function()
  local cases = {
    "async function f() {}",
    "1 == 2",
    "++;",
    "5++;",
    "x += ;",
    "** 3;",
    "2 * * 3;",
  }
  for _, src in ipairs(cases) do
    local ast, err = ljs.parse(src)
    assert(ast == nil, "expected nil ast for: " .. src)
    assert(err ~= nil, "expected error message for: " .. src)
    assert(
      err:find("parse error:") == 1,
      "expected 'parse error:' prefix, got: " .. err .. " for: " .. src
    )
  end
end)

-- ============================================================================
