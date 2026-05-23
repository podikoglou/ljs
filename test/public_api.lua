local T = require("ljs_test")
local ljs = require("ljs")
local parser = require("ljs_parser")
local test, assert_eq = T.test, T.assert_eq

-- ============================================================================
-- ljs.parse()
-- ============================================================================

test("parse returns ast on valid source", function()
  local ast, err = ljs.parse("let x = 42;")
  assert(ast ~= nil, "expected ast")
  assert_eq(ast.type, "Program")
  assert_eq(#ast.body, 1)
  assert_eq(err, nil)
end)

test("parse returns error on invalid source", function()
  local ast, err = ljs.parse("let x = ;")
  assert_eq(ast, nil)
  assert(err ~= nil)
end)

-- ============================================================================
-- ljs.parse_tokens()
-- ============================================================================

test("parse_tokens accepts pre-built token array", function()
  local tokens = parser.tokenize("let x = 1;")
  assert(tokens ~= nil, "expected tokens")
  local ast, err = ljs.parse_tokens(tokens)
  assert(ast ~= nil, "expected ast")
  assert_eq(ast.type, "Program")
  assert_eq(err, nil)
end)

-- ============================================================================
-- ljs.tokenize()
-- ============================================================================

test("tokenize returns tokens on valid source", function()
  local tokens, err = ljs.tokenize("let x = 1;")
  assert(tokens ~= nil, "expected tokens")
  assert(#tokens > 0)
  assert_eq(err, nil)
  assert_eq(tokens[1].type, "let")
end)

-- ============================================================================
-- ljs.transpile()
-- ============================================================================

test("transpile returns Lua code on valid source", function()
  local code, err = ljs.transpile("let x = 42;")
  assert(code ~= nil)
  assert_eq(err, nil)
  -- Verify it's loadable Lua
  local fn, load_err = load(code)
  assert(fn ~= nil, "expected loadable Lua, got: " .. tostring(load_err))
end)

test("transpile returns error on invalid source", function()
  local code, err = ljs.transpile("let x = ;")
  assert_eq(code, nil)
  assert(err ~= nil)
end)

test("transpile script mode: no implicit return", function()
  local code, err = ljs.transpile("1 + 2")
  assert_eq(err, nil)
  assert(code ~= nil, "expected code")
  local fn = load(code)
  assert(fn ~= nil, "expected loadable function")
  local ok, result = pcall(fn)
  assert(ok, "expected pcall success, got: " .. tostring(result))
  assert_eq(result, nil, "script mode should not implicitly return")
end)

-- ============================================================================
-- ljs.transpile_ast()
-- ============================================================================

test("transpile_ast accepts parsed AST", function()
  local ast, err = ljs.parse("let x = 5;")
  local code = ljs.transpile_ast(ast)
  assert(code ~= nil)
  local fn = load(code)
  assert(fn ~= nil)
end)

-- ============================================================================
-- ljs.run() — expression evaluation
-- ============================================================================

test("run returns expression result for single expression", function()
  local result, err = ljs.run("1 + 2")
  assert_eq(err, nil)
  assert_eq(result, 3)
end)

test("run returns expression result with variables", function()
  local result, err = ljs.run("let x = 10; x + 3")
  assert_eq(err, nil)
  assert_eq(result, 13)
end)

test("run returns nil when last statement is not an expression", function()
  local result, err = ljs.run("let x = 42;")
  assert_eq(err, nil)
  assert_eq(result, nil)
end)

test("run returns error on invalid source", function()
  local result, err = ljs.run("let x = ;")
  assert_eq(result, nil)
  assert(err ~= nil)
end)

test("run evaluates ternary expression", function()
  local result, err = ljs.run("true ? 1 : 0")
  assert_eq(err, nil)
  assert_eq(result, 1)
end)

test("run evaluates typeof expression", function()
  local result, err = ljs.run("typeof 42")
  assert_eq(err, nil)
  assert_eq(result, "number")
end)

test("run evaluates prefix increment", function()
  local result, err = ljs.run("let x = 5; ++x")
  assert_eq(err, nil)
  assert_eq(result, 6)
end)

test("run evaluates postfix increment", function()
  local result, err = ljs.run("let x = 5; x++")
  assert_eq(err, nil)
  assert_eq(result, 5)
end)

test("run evaluates delete expression", function()
  local result, err = ljs.run("let obj = {a: 1, b: 2}; delete obj.a")
  assert_eq(err, nil)
  assert_eq(result, true)
end)

-- ============================================================================
-- ljs.load() — compile to callable function
-- ============================================================================

test("load returns callable function", function()
  local fn, err = ljs.load("1 + 2")
  assert_eq(err, nil)
  assert(fn ~= nil, "expected function")
  assert_eq(fn(), 3)
end)

test("load function returns expression result", function()
  local fn, err = ljs.load("let x = 7; x * 3")
  assert_eq(err, nil)
  assert(fn ~= nil, "expected function")
  assert_eq(fn(), 21)
end)

test("load returns error on invalid source", function()
  local fn, err = ljs.load("let x = ;")
  assert_eq(fn, nil)
  assert(err ~= nil)
end)

test("load returns error on invalid Lua output", function()
  local fn, err = ljs.load("class {")
  assert_eq(fn, nil)
  assert(err ~= nil)
end)

-- ============================================================================
-- Invariants
-- ============================================================================

test("invariant: run result equals load()() for expressions", function()
  local sources = {
    "1 + 2",
    "let x = 3; x + 4",
    "5 * 6 + 2",
    "true ? 10 : 20",
    "typeof 'hello'",
  }
  for _, src in ipairs(sources) do
    local run_result, run_err = ljs.run(src)
    local fn, load_err = ljs.load(src)
    assert_eq(run_err, nil, "run error for: " .. src)
    assert_eq(load_err, nil, "load error for: " .. src)
    assert(fn ~= nil, "expected function for: " .. src)
    assert_eq(run_result, fn(), "run != load()() for: " .. src)
  end
end)

test("invariant: transpile output is always loadable Lua", function()
  local sources = {
    "let x = 1;",
    "let x = 1; let y = 2; let z = x + y;",
    "function f(n) { return n * 2; }",
    "if (true) { let a = 1; } else { let b = 2; }",
    "while (false) { let a = 1; }",
    "for (let i = 0; i < 10; i = i + 1) { let a = i; }",
    "let arr = [1, 2, 3];",
    "let obj = {a: 1, b: 2};",
    "let x = true ? 1 : 0;",
    "try { let a = 1; } catch (e) { let b = 2; }",
    "switch (1) { case 1: break; default: let a = 1; }",
    "let f = (a, b) => { return a + b; };",
    "typeof 42",
    "let x = 5; x++",
    "let x = 5; ++x",
    "let obj = {a: 1}; delete obj.a",
  }
  for _, src in ipairs(sources) do
    local code, err = ljs.transpile(src)
    assert_eq(err, nil, "transpile error for: " .. src)
    assert(code ~= nil, "expected code for: " .. src)
    local fn, load_err = load(code)
    assert(fn ~= nil, "load error for: " .. src .. "\n  " .. tostring(load_err))
  end
end)

-- ============================================================================
-- ljs.format_error()
-- ============================================================================

test("format_error returns message with source context", function()
  local source = "let x = 1\nlet y = ;"
  local err = parser.make_parse_error("Unexpected token ;", 2, 9)
  local formatted = parser.format_error(err, source)
  assert(string.find(formatted, "let y = ;"), "should contain source line")
  assert(string.find(formatted, "^"), "should contain caret")
end)

test("format_error handles missing source", function()
  local err = parser.make_parse_error("test error", 1, 1)
  local formatted = parser.format_error(err, nil)
  assert_eq(formatted, "test error")
end)

test("format_error handles line=0 errors", function()
  local err = parser.make_parse_error("internal error", 0, 0)
  local formatted = parser.format_error(err, "some source")
  assert_eq(formatted, "internal error")
end)
