--- ljs — Lua JS Toolkit: parse, transpile, and run JavaScript subsets.
-- Single entry point that aggregates ljs_parser and ljs_transpile.
-- Lower-level modules remain directly requireable for advanced use.
-- @module ljs

local ljs = {}

-- ============================================================================
-- Parse (source → AST)
-- ============================================================================

--- Parse JavaScript source into an AST.
-- @param source (string) JavaScript source code
-- @return (table|nil) AST root node (Program), or nil on failure
-- @return (table|nil) ParseError {message, line, col}, or nil on success
function ljs.parse(source)
  local parser = require("ljs_parser")
  return parser.parse(source)
end

--- Parse a pre-built token array into an AST (bypasses tokenizer).
-- @param tokens (table) Array of token tables {type, value?, line, col}
-- @return (table|nil) AST root node (Program), or nil on failure
-- @return (table|nil) ParseError {message, line, col}, or nil on success
function ljs.parse_tokens(tokens)
  local parser = require("ljs_parser")
  return parser.parse_tokens(tokens)
end

--- Tokenize JavaScript source (low-level).
-- @param source (string) JavaScript source code
-- @return (table|nil) Array of token tables, or nil on failure
-- @return (table|nil) ParseError {message, line, col}, or nil on success
function ljs.tokenize(source)
  local parser = require("ljs_parser")
  return parser.tokenize(source)
end

-- ============================================================================
-- Transpile (source/AST → Lua)
-- ============================================================================

--- Transpile JavaScript source to Lua source code.
-- Uses "script" mode: no implicit returns.
-- @param source (string) JavaScript source code
-- @return (string|nil) Lua source code, or nil on failure
-- @return (table|nil) ParseError {message, line, col}, or nil on success
function ljs.transpile(source)
  local transpiler = require("ljs_transpile")
  return transpiler.transpile_source(source)
end

--- Transpile an AST directly to Lua source code.
-- Use this after ljs.parse() when you want to inspect or modify the AST.
-- @param ast (table) AST root node (Program)
-- @return (string) Lua source code
function ljs.transpile_ast(ast)
  local transpiler = require("ljs_transpile")
  return transpiler.transpile(ast)
end

-- ============================================================================
-- Execute (source → result)
-- ============================================================================

--- Transpile JavaScript source and compile it into a callable Lua function.
-- Uses "eval" mode: the completion value of the last expression is returned
-- when the compiled function is called.
-- @param source (string) JavaScript source code
-- @return (function|nil) Callable Lua function, or nil on failure
-- @return (table|nil) ParseError {message, line, col}, or nil on success
function ljs.load(source)
  local transpiler = require("ljs_transpile")
  local code, err = transpiler.transpile_source(source, { mode = "eval" })
  if not code then
    return nil, err
  end
  local fn, load_err = load(code)
  if not fn then
    return nil,
      require("ljs_parser").make_parse_error("compile error: " .. tostring(load_err), 0, 0)
  end
  return fn
end

--- Transpile, compile, and execute JavaScript code.
-- Returns the completion value of the script. For single-expression input
-- (e.g. "1 + 2"), returns the expression's value.
-- console.log writes to stdout via Lua's print().
-- @param source (string) JavaScript source code
-- @return (any) Result of executing the code
-- @return (nil|table) nil on success, or ParseError {message, line, col} on failure
function ljs.run(source)
  local fn, err = ljs.load(source)
  if not fn then
    return nil, err
  end
  local ok, result = pcall(fn)
  if not ok then
    return nil, require("ljs_parser").make_parse_error("runtime error: " .. tostring(result), 0, 0)
  end
  return result
end

function ljs.is_parse_error(val)
  return require("ljs_parser").is_parse_error(val)
end

return ljs
