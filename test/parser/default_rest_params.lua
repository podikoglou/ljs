local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local ast = require("ljs.ast")
local test, assert_table_eq = T.test, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

local function assignment_pattern(left, right)
  return { type = ast.TYPE_ASSIGNMENT_PATTERN, left = left, right = right }
end

local function rest_element(arg)
  return { type = ast.TYPE_REST_ELEMENT, argument = arg }
end

-- ============================================================================
-- Default parameters — function declarations
-- ============================================================================

test("parse function with single default parameter", function()
  assert_parse_ok("function f(x = 10) {}", {
    A.func("f", {
      assignment_pattern(A.id("x"), A.num(10)),
    }, A.block({})),
  })
end)

test("parse function with multiple default parameters", function()
  assert_parse_ok("function f(a = 1, b = 2) {}", {
    A.func("f", {
      assignment_pattern(A.id("a"), A.num(1)),
      assignment_pattern(A.id("b"), A.num(2)),
    }, A.block({})),
  })
end)

test("parse function with mixed params and defaults", function()
  assert_parse_ok("function f(a, b = 5, c) {}", {
    A.func("f", {
      A.id("a"),
      assignment_pattern(A.id("b"), A.num(5)),
      A.id("c"),
    }, A.block({})),
  })
end)

test("parse function with default string parameter", function()
  assert_parse_ok('function f(s = "hello") {}', {
    A.func("f", {
      assignment_pattern(A.id("s"), A.str("hello")),
    }, A.block({})),
  })
end)

-- ============================================================================
-- Rest parameters — function declarations
-- ============================================================================

test("parse function with rest parameter", function()
  assert_parse_ok("function f(...args) {}", {
    A.func("f", {
      rest_element(A.id("args")),
    }, A.block({})),
  })
end)

test("parse function with regular and rest parameters", function()
  assert_parse_ok("function f(a, b, ...rest) {}", {
    A.func("f", {
      A.id("a"),
      A.id("b"),
      rest_element(A.id("rest")),
    }, A.block({})),
  })
end)

test("parse function with default and rest parameters", function()
  assert_parse_ok("function f(a = 1, ...rest) {}", {
    A.func("f", {
      assignment_pattern(A.id("a"), A.num(1)),
      rest_element(A.id("rest")),
    }, A.block({})),
  })
end)

-- ============================================================================
-- Rest parameter validation
-- ============================================================================

test("rest parameter must be last", function()
  assert_parse_fail("function f(...a, b) {}", "rest")
end)

test("only one rest parameter allowed", function()
  assert_parse_fail("function f(...a, ...b) {}", "rest")
end)

-- ============================================================================
-- Arrow functions with default/rest
-- ============================================================================

test("parse arrow function with default parameter", function()
  assert_parse_ok("(x = 5) => x;", {
    A.expr_stmt(A.arrow({
      assignment_pattern(A.id("x"), A.num(5)),
    }, A.block({ A.ret(A.id("x")) }))),
  })
end)

test("parse arrow function with rest parameter", function()
  assert_parse_ok("(...args) => args;", {
    A.expr_stmt(A.arrow({
      rest_element(A.id("args")),
    }, A.block({ A.ret(A.id("args")) }))),
  })
end)

-- ============================================================================
-- Function expressions with default/rest
-- ============================================================================

test("parse function expression with default parameter", function()
  assert_parse_ok("let f = function(x = 10) {};", {
    A.let("f", A.func_expr({
      assignment_pattern(A.id("x"), A.num(10)),
    }, A.block({}))),
  })
end)

test("parse function expression with rest parameter", function()
  assert_parse_ok("let f = function(...args) {};", {
    A.let("f", A.func_expr({
      rest_element(A.id("args")),
    }, A.block({}))),
  })
end)
