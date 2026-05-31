-- ljs.parser — JavaScript subset → Lua table AST.
--
-- Two-phase pipeline: tokenize(source) → parse(tokens) → AST.
-- Pure parser — knows nothing about Lua. No external dependencies.
-- All errors are ParseError tables {message, line, col} with __tostring metamethod,
-- thrown via error()/pcall(). Public API catches and returns nil, ParseError.
--
-- Supported: let/const/var, functions, arrows, classes (extends/super/static),
-- objects, arrays, template literals, all arithmetic/comparison/logical/bitwise/
-- assignment ops, new, typeof, delete, instanceof, in, if/else, while,
-- do...while, for...of/in/(;;), switch/case, throw/try/catch/finally, this,
-- console.log, comments.
--
-- Rejected (parse error): async/await, regex literals.
--
-- Usage:
--   local parser = require("ljs.parser")
--   local ast, err = parser.parse("let x = 42; console.log(x);")
--   if not ast then print(err) end

local M = {}

local ast = require("ljs.ast")
local tokenizer = require("ljs.tokenizer")

local TOKEN = tokenizer.TOKEN
local tokenize = tokenizer.tokenize
local make_token_stream = tokenizer.make_token_stream
local parse_error = tokenizer.parse_error
local make_parse_error = tokenizer.make_parse_error
local is_parse_error = tokenizer.is_parse_error

--- @param expr (table) AST expression node
--- @param tok (table) The ++ or -- token
local function check_update_target(expr, tok)
  if not ast.is_valid_update_target(expr) then
    parse_error(
      "Invalid update target: cannot use " .. tok.type .. " on this expression",
      tok.line,
      tok.col
    )
  end
end

-- ============================================================================
-- PARSER
-- ============================================================================
-- Top-down recursive descent parser with Pratt parsing for expressions.
--
-- Architecture:
--   M.parse(source)
--     -> tokenize(source) -> make_token_stream(tokens) -> parse_statement*
--
-- Statements are dispatched by the first token (let/const, if, while, etc).
-- Expressions use precedence climbing (Pratt parsing) with a precedence table.
--
-- Parse functions are stored in a late-binding dispatch table P, so mutual
-- recursion works without forward declarations (table fields resolve at call time).

local P = {}

--- Parse JavaScript source into an AST.
-- @param source (string) JavaScript source code
-- @return ast (table) The AST root node (Program)
-- @return err (string) Error message if parsing failed
function M.parse(source)
  local tokens, tokenize_err = tokenize(source)
  if not tokens then
    return nil, tokenize_err
  end

  local stream = make_token_stream(tokens)

  local ok, result = pcall(function()
    local stmts = {}
    while not stream.eof() do
      table.insert(stmts, P.statement(stream))
    end
    return { type = ast.TYPE_PROGRAM, body = stmts, line = 1, col = 1 }
  end)

  if ok then
    return result
  end
  if is_parse_error(result) then
    return nil, result
  end
  return nil, make_parse_error(tostring(result), 0, 0)
end

--- Parse a pre-built token array into an AST.
-- Bypasses tokenization — takes the token array directly.
-- Useful for testing parser grammar rules in isolation from the tokenizer,
-- or for feeding tokens from an alternative source.
-- @param tokens (table) Array of token tables {type, value?, line, col}
-- @return ast (table) The AST root node (Program)
-- @return err (string) Error message if parsing failed
function M.parse_tokens(tokens)
  local stream = make_token_stream(tokens)

  local ok, result = pcall(function()
    local stmts = {}
    while not stream.eof() do
      table.insert(stmts, P.statement(stream))
    end
    return { type = ast.TYPE_PROGRAM, body = stmts, line = 1, col = 1 }
  end)

  if ok then
    return result
  end
  if is_parse_error(result) then
    return nil, result
  end
  return nil, make_parse_error(tostring(result), 0, 0)
end

-- ============================================================================
-- BANNED KEYWORD CHECK
-- ============================================================================

-- Keywords that tokenize normally but are rejected in expression/statement context.
-- These are valid JS but outside this subset's scope.
local BANNED_KEYWORDS = {
  [TOKEN.ASYNC] = "async",
  [TOKEN.AWAIT] = "await",
}

--- Check if the current token is a banned keyword and return an error message.
-- @param stream (table) Token stream
-- @return (string|nil) Error message if banned keyword found, nil otherwise
local function check_banned(stream)
  local token = stream.peek()
  local kw = BANNED_KEYWORDS[token.type]
  if kw then
    return make_parse_error(string.format("'%s' is not supported", kw), token.line, token.col)
  end
  return nil
end

-- ============================================================================
-- STATEMENT PARSERS
-- ============================================================================

--- Dispatch to the correct statement parser based on the current token.
-- Falls through to expression statement for anything unrecognized.
-- Semicolons are optional — consumed if present, no error if absent.
-- @param stream (table) Token stream
-- @return (table|nil) AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function P.statement(stream)
  if stream.is(TOKEN.LET) or stream.is(TOKEN.VAR) or stream.is(TOKEN.CONST) then
    return P.variable_declaration(stream)
  elseif stream.is(TOKEN.IF) then
    return P.if_statement(stream)
  elseif stream.is(TOKEN.WHILE) then
    return P.while_statement(stream)
  elseif stream.is(TOKEN.DO) then
    return P.do_while_statement(stream)
  elseif stream.is(TOKEN.FOR) then
    return P.for_statement(stream)
  elseif stream.is(TOKEN.THROW) then
    return P.throw_statement(stream)
  elseif stream.is(TOKEN.TRY) then
    return P.try_statement(stream)
  elseif stream.is(TOKEN.FUNCTION) then
    return P.function_declaration(stream)
  elseif stream.is(TOKEN.CLASS) then
    return P.class_declaration(stream)
  elseif stream.is(TOKEN.RETURN) then
    return P.return_statement(stream)
  elseif stream.is(TOKEN.SWITCH) then
    return P.switch_statement(stream)
  elseif stream.is(TOKEN.BREAK) then
    return P.break_statement(stream)
  elseif stream.is(TOKEN.CONTINUE) then
    return P.continue_statement(stream)
  elseif stream.is(TOKEN.LBRACE) then
    return P.block_statement(stream)
  elseif stream.is(TOKEN.SEMICOLON) then
    local tok = stream.advance()
    return ast.empty_statement(tok)
  else
    local banned_err = check_banned(stream)
    if banned_err then
      error(banned_err, 0)
    end
    local expr_token = stream.peek()
    local expr = P.expression(stream)
    if stream.is(TOKEN.SEMICOLON) then
      stream.advance()
    end
    return ast.expression_statement(expr, expr_token)
  end
end

--- Parse a block: { stmt1; stmt2; ... }
-- Consumes the opening and closing braces.
function P.block_statement(stream)
  local lbrace = stream.consume(TOKEN.LBRACE)
  local body = {}
  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    table.insert(body, P.statement(stream))
  end
  stream.consume(TOKEN.RBRACE)
  return ast.block_statement(body, lbrace)
end

--- Parse variable declaration: let/const/var x = expr, y = expr;
-- Supports multiple declarators separated by commas.
-- Semicolon is optional.
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' in initializer expressions
function P.variable_declaration(stream, no_in)
  local kind_token = stream.peek()
  local kind
  if kind_token.type == TOKEN.LET then
    stream.advance()
    kind = "let"
  elseif kind_token.type == TOKEN.VAR then
    stream.advance()
    kind = "var"
  elseif kind_token.type == TOKEN.CONST then
    stream.advance()
    kind = "const"
  else
    stream.consume(TOKEN.LET)
    kind = "let"
  end

  local declarations = {}
  while true do
    local decl = P.variable_declarator(stream, no_in)
    table.insert(declarations, decl)
    if not stream.is(TOKEN.COMMA) then
      break
    end
    stream.advance()
  end

  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end

  return ast.variable_declaration(kind, declarations, kind_token)
end

--- Parse a single variable declarator: name or name = init
-- Supports destructuring: let [a, b] = arr; let {x, y} = obj;
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' in initializer expression
function P.variable_declarator(stream, no_in)
  local token = stream.peek()
  local name
  if token.type == TOKEN.LBRACE then
    name = P.object_pattern(stream)
  elseif token.type == TOKEN.LBRACKET then
    name = P.array_pattern(stream)
  else
    stream.consume(TOKEN.IDENTIFIER)
    name = ast.identifier(token.value, token)
  end

  local init = nil
  if stream.is(TOKEN.ASSIGN) then
    stream.advance()
    init = P.expression(stream, no_in)
  end

  if not init and (name.type == ast.TYPE_OBJECT_PATTERN or name.type == ast.TYPE_ARRAY_PATTERN) then
    parse_error("Missing initializer in destructuring declaration", token.line, token.col)
  end

  return ast.variable_declarator(name, init, token)
end

function P.object_pattern(stream)
  local lbrace = stream.consume(TOKEN.LBRACE)
  local properties = {}

  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    if stream.is(TOKEN.ELLIPSIS) then
      local ellipsis = stream.advance()
      local id_token = stream.consume(TOKEN.IDENTIFIER)
      properties[#properties + 1] =
        ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis)
    else
      local key_token = stream.consume_property_name()
      local key = ast.identifier(key_token.value, key_token)

      if stream.is(TOKEN.COLON) then
        stream.advance()
        local value = P.binding_element(stream)
        properties[#properties + 1] = ast.property(key, value, false, key_token, false)
      elseif stream.is(TOKEN.ASSIGN) then
        stream.advance()
        local default_expr = P.expression(stream)
        properties[#properties + 1] = ast.property(
          key,
          ast.assignment_pattern(ast.identifier(key.name, key_token), default_expr, key_token),
          false,
          key_token,
          true
        )
      else
        properties[#properties + 1] =
          ast.property(key, ast.identifier(key.name, key_token), false, key_token, true)
      end
    end

    if not stream.is(TOKEN.COMMA) then
      break
    end
    stream.advance()
  end

  stream.consume(TOKEN.RBRACE)
  return ast.object_pattern(properties, lbrace)
end

function P.array_pattern(stream)
  local lbracket = stream.consume(TOKEN.LBRACKET)
  local elements = {}
  local idx = 1

  while not stream.is(TOKEN.RBRACKET) and not stream.eof() do
    if stream.is(TOKEN.COMMA) then
      elements[idx] = nil
      idx = idx + 1
      stream.advance()
    elseif stream.is(TOKEN.ELLIPSIS) then
      local ellipsis = stream.advance()
      local id_token = stream.consume(TOKEN.IDENTIFIER)
      elements[idx] = ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis)
      idx = idx + 1
      if stream.is(TOKEN.COMMA) then
        stream.advance()
      end
    else
      local elem = P.binding_element(stream)
      elements[idx] = elem
      idx = idx + 1
      if stream.is(TOKEN.COMMA) then
        stream.advance()
      end
    end
  end

  stream.consume(TOKEN.RBRACKET)
  local result = ast.array_pattern(elements, lbracket)
  result.count = idx - 1
  return result
end

function P.binding_element(stream)
  local token = stream.peek()
  if token.type == TOKEN.LBRACE then
    return P.object_pattern(stream)
  elseif token.type == TOKEN.LBRACKET then
    return P.array_pattern(stream)
  else
    stream.consume(TOKEN.IDENTIFIER)
    local name = ast.identifier(token.value, token)
    if stream.is(TOKEN.ASSIGN) then
      local assign_tok = stream.advance()
      local default_expr = P.expression(stream)
      return ast.assignment_pattern(name, default_expr, assign_tok)
    end
    return name
  end
end

--- Parse if/else: if (test) consequent [else alternate]
-- The consequent and alternate are single statements (can be blocks).
function P.if_statement(stream)
  local kw = stream.consume(TOKEN.IF)
  stream.consume(TOKEN.LPAREN)
  local test = P.expression(stream)
  stream.consume(TOKEN.RPAREN)

  local consequent = P.statement(stream)

  local alternate = nil
  if stream.is(TOKEN.ELSE) then
    stream.advance()
    alternate = P.statement(stream)
  end

  return ast.if_statement(test, consequent, alternate, kw)
end

--- Parse while: while (test) body
function P.while_statement(stream)
  local kw = stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = P.expression(stream)
  stream.consume(TOKEN.RPAREN)
  stream.loop_depth = stream.loop_depth + 1
  local body = P.statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.while_statement(test, body, kw)
end

--- Parse do...while: do body while (test);
-- Body always executes at least once. Semicolon after is optional.
-- @param stream (table) Token stream
-- @return (table|nil) DoWhileStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function P.do_while_statement(stream)
  local kw = stream.consume(TOKEN.DO)
  stream.loop_depth = stream.loop_depth + 1
  local body = P.statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = P.expression(stream)
  stream.consume(TOKEN.RPAREN)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.do_while_statement(body, test, kw)
end

--- Coerce an already-parsed expression node into a pattern node.
-- Used when the parser discovers after the fact that an expression is in
-- a pattern position (assignment LHS, for-of/in left without declaration).
-- Handles: ArrayExpression→ArrayPattern, ObjectExpression→ObjectPattern,
-- SpreadElement→RestElement, BinaryExpression(=)→AssignmentPattern.
local coerce_to_pattern
coerce_to_pattern = function(node)
  if node.type == ast.TYPE_ARRAY_EXPRESSION then
    local elements = {}
    local count = node.count or #node.elements
    for i = 1, count do
      local elem = node.elements[i]
      if elem == nil then
        elements[i] = nil
      elseif elem.type == ast.TYPE_SPREAD_ELEMENT then
        elements[i] = ast.rest_element(elem.argument, elem)
      elseif elem.type == ast.TYPE_IDENTIFIER then
        elements[i] = elem
      elseif elem.type == ast.TYPE_ASSIGNMENT_PATTERN then
        elements[i] = elem
      elseif elem.type == ast.TYPE_BINARY_EXPRESSION and elem.operator == "=" then
        local left = coerce_to_pattern(elem.left)
        elements[i] = ast.assignment_pattern(left, elem.right, elem)
      else
        elements[i] = coerce_to_pattern(elem)
      end
    end
    local result = ast.array_pattern(elements, node)
    result.count = count
    return result
  elseif node.type == ast.TYPE_OBJECT_EXPRESSION then
    local properties = {}
    for _, prop_node in ipairs(node.properties) do
      if prop_node.type == ast.TYPE_SPREAD_ELEMENT then
        properties[#properties + 1] = ast.rest_element(prop_node.argument, prop_node)
      else
        local new_value = prop_node.value
        if new_value.type == ast.TYPE_IDENTIFIER then
          -- keep as-is
        elseif new_value.type == ast.TYPE_ASSIGNMENT_PATTERN then
          -- keep as-is
        elseif new_value.type == ast.TYPE_BINARY_EXPRESSION and new_value.operator == "=" then
          local left = coerce_to_pattern(new_value.left)
          new_value = ast.assignment_pattern(left, new_value.right, new_value)
        else
          new_value = coerce_to_pattern(new_value)
        end
        properties[#properties + 1] =
          ast.property(prop_node.key, new_value, prop_node.computed, prop_node, prop_node.shorthand)
      end
    end
    return ast.object_pattern(properties, node)
  end
  return node
end

--- Parse for statement: dispatches between for...of, for...in, and C-style for(;;).
function P.for_statement(stream)
  local kw = stream.consume(TOKEN.FOR)
  stream.consume(TOKEN.LPAREN)

  if stream.is(TOKEN.SEMICOLON) then
    return P.c_style_for(stream, nil, kw)
  end

  if stream.is(TOKEN.LET) or stream.is(TOKEN.VAR) or stream.is(TOKEN.CONST) then
    local decl = P.variable_declaration(stream, true)

    if stream.is(TOKEN.OF) then
      return P.for_of_from_left(stream, decl, kw)
    end

    if stream.is(TOKEN.IN) then
      return P.for_in_from_left(stream, decl, kw)
    end

    return P.c_style_for_from_test(stream, decl, kw)
  end

  local expr_token = stream.peek()
  local expr = P.expression(stream, true)

  if stream.is(TOKEN.OF) then
    if expr.type == ast.TYPE_ARRAY_EXPRESSION or expr.type == ast.TYPE_OBJECT_EXPRESSION then
      expr = coerce_to_pattern(expr)
    end
    stream.consume(TOKEN.OF)
    local right = P.expression(stream)
    stream.consume(TOKEN.RPAREN)
    stream.loop_depth = stream.loop_depth + 1
    local body = P.statement(stream)
    stream.loop_depth = stream.loop_depth - 1
    return ast.for_of_statement(expr, right, body, kw)
  end

  if stream.is(TOKEN.IN) then
    if expr.type == ast.TYPE_ARRAY_EXPRESSION or expr.type == ast.TYPE_OBJECT_EXPRESSION then
      expr = coerce_to_pattern(expr)
    end
    stream.consume(TOKEN.IN)
    local right = P.expression(stream)
    stream.consume(TOKEN.RPAREN)
    stream.loop_depth = stream.loop_depth + 1
    local body = P.statement(stream)
    stream.loop_depth = stream.loop_depth - 1
    return ast.for_in_statement(expr, right, body, kw)
  end

  local init = ast.expression_statement(expr, expr_token)
  stream.consume(TOKEN.SEMICOLON)
  return P.c_style_for_from_test(stream, init, kw)
end

--- Parse C-style for loop starting from the first semicolon (no init clause).
-- @param stream (table) Token stream
-- @param init (table|nil) Initialization expression or nil
-- @return (table|nil) ForStatement AST node, or nil on error
function P.c_style_for(stream, init, kw)
  stream.consume(TOKEN.SEMICOLON)
  return P.c_style_for_from_test(stream, init, kw)
end

--- Parse C-style for loop test and update clauses after init has been consumed.
-- @param stream (table) Token stream
-- @param init (table|nil) Initialization expression or VariableDeclaration
-- @return (table|nil) ForStatement AST node, or nil on error
function P.c_style_for_from_test(stream, init, kw)
  local test
  if not stream.is(TOKEN.SEMICOLON) then
    test = P.expression(stream)
  end
  stream.consume(TOKEN.SEMICOLON)

  local update
  if not stream.is(TOKEN.RPAREN) then
    update = P.expression(stream)
  end
  stream.consume(TOKEN.RPAREN)

  stream.loop_depth = stream.loop_depth + 1
  local body = P.statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.for_statement(init, test, update, body, kw)
end

--- Parse for...of loop after the left-hand variable declaration has been consumed.
-- @param stream (table) Token stream
-- @param left (table) VariableDeclaration for the loop variable
-- @return (table|nil) ForOfStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function P.for_of_from_left(stream, left, kw)
  stream.consume(TOKEN.OF)
  local right = P.expression(stream)
  stream.consume(TOKEN.RPAREN)
  stream.loop_depth = stream.loop_depth + 1
  local body = P.statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.for_of_statement(left, right, body, kw)
end

--- Parse for...in loop after the left-hand variable declaration has been consumed.
-- Validates that there is exactly one declarator with no initializer.
-- @param stream (table) Token stream
-- @param left (table) VariableDeclaration for the loop variable
-- @return (table|nil) ForInStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function P.for_in_from_left(stream, left, kw)
  if #left.declarations ~= 1 then
    parse_error("for-in loop requires a single variable", stream.peek().line, stream.peek().col)
  end
  if left.declarations[1].init ~= nil then
    parse_error(
      "for-in loop variable cannot have an initializer",
      stream.peek().line,
      stream.peek().col
    )
  end
  stream.consume(TOKEN.IN)
  local right = P.expression(stream)
  stream.consume(TOKEN.RPAREN)
  stream.loop_depth = stream.loop_depth + 1
  local body = P.statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.for_in_statement(left, right, body, kw)
end

--- Parse throw: throw expression;
function P.throw_statement(stream)
  local kw = stream.consume(TOKEN.THROW)
  local argument = P.expression(stream)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.throw_statement(argument, kw)
end

--- Parse try/catch/finally: try { ... } catch (param) { ... } finally { ... }
-- At least one of catch or finally must be present.
function P.try_statement(stream)
  local kw = stream.consume(TOKEN.TRY)
  local block = P.block_statement(stream)

  local handler = nil
  if stream.is(TOKEN.CATCH) then
    local catch_kw = stream.advance()
    stream.consume(TOKEN.LPAREN)
    local param_token = stream.consume(TOKEN.IDENTIFIER)
    local param = ast.identifier(param_token.value, param_token)
    stream.consume(TOKEN.RPAREN)
    local catch_body = P.block_statement(stream)
    handler = ast.catch_clause(param, catch_body, catch_kw)
  end

  local finalizer = nil
  if stream.is(TOKEN.FINALLY) then
    stream.advance()
    finalizer = P.block_statement(stream)
  end

  if not handler and not finalizer then
    parse_error("Expected catch or finally after try block", stream.peek().line, stream.peek().col)
  end

  return ast.try_statement(block, handler, finalizer, kw)
end

--- Parse function declaration: function name(params) { body }
-- Always has a name (unlike function expressions which can be anonymous).
function P.function_declaration(stream)
  local kw = stream.consume(TOKEN.FUNCTION)
  local name_token = stream.consume(TOKEN.IDENTIFIER)
  local name = name_token.value

  stream.consume(TOKEN.LPAREN)
  local params = P.parameters(stream)
  stream.consume(TOKEN.RPAREN)

  local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
  stream.loop_depth, stream.switch_depth = 0, 0
  local body = P.block_statement(stream)
  stream.loop_depth, stream.switch_depth = saved_loop, saved_switch
  return ast.function_declaration(name, params, body, kw)
end

--- Parse class body: { constructor(){} method(){} static fn(){} }
-- Disambiguates static modifier from method named "static": static foo() is a
-- static method, static() is a regular method named "static".
-- @param stream (table) Token stream
-- @return (table) Array of MethodDefinition nodes
function P.class_body(stream)
  stream.consume(TOKEN.LBRACE)
  local methods = {}
  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    local is_static = false
    if stream.is(TOKEN.STATIC) then
      local next_tok = stream.peek_n(2)
      -- If next token after "static" is (, then "static" is the method name, not a modifier
      if next_tok and next_tok.type ~= TOKEN.LPAREN then
        stream.advance()
        is_static = true
      end
    end
    local key
    local key_token
    local kind = "method"
    if stream.is_property_name() then
      key_token = stream.advance()
      key = ast.identifier(key_token.value, key_token)
      if key_token.value == "constructor" then
        kind = "constructor"
      end
    elseif stream.is(TOKEN.STRING) then
      key_token = stream.advance()
      key = ast.string_literal(key_token.value, key_token)
    else
      parse_error("Expected method name in class body", stream.peek().line, stream.peek().col)
    end
    stream.consume(TOKEN.LPAREN)
    local params = P.parameters(stream)
    stream.consume(TOKEN.RPAREN)
    local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
    stream.loop_depth, stream.switch_depth = 0, 0
    local body = P.block_statement(stream)
    stream.loop_depth, stream.switch_depth = saved_loop, saved_switch
    local fn = ast.function_expression(params, body, key_token)
    fn.is_method = true
    if kind == "constructor" then
      fn.is_method = false
    end
    table.insert(methods, ast.method_definition(kind, key, fn, is_static, key_token))
  end
  stream.consume(TOKEN.RBRACE)
  return methods
end

--- Parse class declaration: class Name [extends Super] { body }
-- Always requires a name (unlike class expressions).
-- @param stream (table) Token stream
-- @return table ClassDeclaration AST node
function P.class_declaration(stream)
  local kw = stream.consume(TOKEN.CLASS)
  local name_token = stream.consume(TOKEN.IDENTIFIER)
  local name = name_token.value
  local superClass = nil
  if stream.is(TOKEN.EXTENDS) then
    stream.advance()
    superClass = P.expression(stream)
  end
  local body = P.class_body(stream)
  return ast.class_declaration(name, superClass, body, kw)
end

--- Parse class expression: class [Name] [extends Super] { body }
-- Name is optional and only consumed if followed by something other than (
-- (to disambiguate from a call expression in certain contexts).
-- @param stream (table) Token stream
-- @return table ClassExpression AST node
function P.class_expression(stream, tok)
  local kw = tok or stream.consume(TOKEN.CLASS)
  local name = nil
  if stream.is(TOKEN.IDENTIFIER) then
    local next_tok = stream.peek_n(2)
    -- Consume identifier as class name only if next token isn't ( — distinguishes
    -- class Foo {} (named) from class {} (anonymous)
    if next_tok and next_tok.type ~= TOKEN.LPAREN then
      local name_token = stream.advance()
      name = name_token.value
    end
  end
  local superClass = nil
  if stream.is(TOKEN.EXTENDS) then
    stream.advance()
    superClass = P.expression(stream)
  end
  local body = P.class_body(stream)
  return ast.class_expression(name, superClass, body, kw)
end

--- Parse return: return expression?;
-- Bare return (no expression) is allowed — argument will be nil.
-- Heuristic: if next token is ; or }, there's no expression.
function P.return_statement(stream)
  local kw = stream.consume(TOKEN.RETURN)
  local argument = nil
  if not stream.is(TOKEN.SEMICOLON) and not stream.is(TOKEN.RBRACE) then
    argument = P.expression(stream)
  end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.return_statement(argument, kw)
end

--- Parse switch: switch (expr) { case val: stmts default: stmts }
function P.switch_statement(stream)
  local kw = stream.consume(TOKEN.SWITCH)
  stream.consume(TOKEN.LPAREN)
  local discriminant = P.expression(stream)
  stream.consume(TOKEN.RPAREN)
  stream.consume(TOKEN.LBRACE)

  local cases = {}
  local has_default = false
  stream.switch_depth = stream.switch_depth + 1

  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    local test = nil
    local case_token

    if stream.is(TOKEN.CASE) then
      case_token = stream.advance()
      test = P.expression(stream)
    elseif stream.is(TOKEN.DEFAULT) then
      if has_default then
        parse_error("Duplicate default clause", stream.peek().line, stream.peek().col)
      end
      has_default = true
      case_token = stream.advance()
    else
      parse_error(
        string.format("Expected case or default, got %s", stream.peek().type),
        stream.peek().line,
        stream.peek().col
      )
    end

    stream.consume(TOKEN.COLON)

    local consequent = {}
    while
      not stream.is(TOKEN.CASE)
      and not stream.is(TOKEN.DEFAULT)
      and not stream.is(TOKEN.RBRACE)
      and not stream.eof()
    do
      table.insert(consequent, P.statement(stream))
    end

    table.insert(cases, ast.switch_case(test, consequent, case_token))
  end

  stream.switch_depth = stream.switch_depth - 1
  stream.consume(TOKEN.RBRACE)
  return ast.switch_statement(discriminant, cases, kw)
end

--- Parse break: break ;
function P.break_statement(stream)
  local kw = stream.consume(TOKEN.BREAK)
  if stream.loop_depth == 0 and stream.switch_depth == 0 then
    parse_error("break not allowed outside of loop or switch", kw.line, kw.col)
  end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.break_statement(kw)
end

--- Parse continue: continue ;
function P.continue_statement(stream)
  local kw = stream.consume(TOKEN.CONTINUE)
  if stream.loop_depth == 0 then
    parse_error("continue not allowed outside of loop", kw.line, kw.col)
  end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.continue_statement(kw)
end

--- Parse a comma-separated list of items.
-- @param stream (table) Token stream
-- @param close_token (number) Token type that ends the list
-- @param parse_fn (function) Function to parse each item; receives stream, returns item
-- @param allow_trailing (boolean|nil) If true, trailing comma before close_token is allowed
-- @return (table) Array of parsed items
local function parse_comma_list(stream, close_token, parse_fn, allow_trailing)
  local items = {}
  if not stream.is(close_token) then
    while true do
      local item = parse_fn(stream)
      table.insert(items, item)
      if not stream.is(TOKEN.COMMA) then
        break
      end
      stream.advance()
      if allow_trailing and stream.is(close_token) then
        break
      end
    end
  end
  return items
end

--- Parse a comma-separated list of identifier parameters.
-- Used by both function declarations and function expressions.
-- Assumes opening ( has been consumed; does NOT consume closing ).
function P.parameters(stream)
  local function parse_param_item(s)
    if s.is(TOKEN.ELLIPSIS) then
      local ellipsis = s.advance()
      local id_token = s.consume(TOKEN.IDENTIFIER)
      return ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis)
    end
    local param
    if s.is(TOKEN.LBRACKET) then
      param = P.array_pattern(s)
    elseif s.is(TOKEN.LBRACE) then
      param = P.object_pattern(s)
    else
      local id_token = s.consume(TOKEN.IDENTIFIER)
      param = ast.identifier(id_token.value, id_token)
    end
    if s.is(TOKEN.ASSIGN) then
      local assign_tok = s.advance()
      local default_expr = P.expression(s)
      return ast.assignment_pattern(param, default_expr, assign_tok)
    end
    return param
  end
  local params = {}
  local found_rest = false
  if not stream.is(TOKEN.RPAREN) then
    while true do
      if found_rest then
        parse_error(
          "Rest parameter must be the last parameter",
          stream.peek().line,
          stream.peek().col
        )
      end
      local item = parse_param_item(stream)
      if item.type == ast.TYPE_REST_ELEMENT then
        found_rest = true
      end
      table.insert(params, item)
      if not stream.is(TOKEN.COMMA) then
        break
      end
      stream.advance()
    end
  end
  return params
end

-- ============================================================================
-- EXPRESSION PARSERS
-- ============================================================================
-- Uses Pratt parsing (top-down operator precedence) with nud/led tables:
--   pratt_expr(min_prec=0) -> nud handler for first token
--     -> loops while next token has a led handler with sufficient precedence
--
-- Precedence levels (higher = binds tighter):
--   6   unary ! -
--   5.5 ** (exponentiation, right-associative)
--   5   * / %
--   4   + -
--   3.5 << >> >>> (bitwise shifts)
--   3   < > <= >= in instanceof
--   2.9 === !== == != (equality)
--   2.75 & (bitwise AND)
--   2.5 ^ (bitwise XOR)
--   2.25 | (bitwise OR)
--   2   &&
--   1   ||
--   0.5 = += -= *= /= %= **= &= |= ^= <<= >>= >>>= (assignment, right-associative)
--
-- All binary operators except assignment, compound assignment, and ** are left-associative.

local PRECEDENCE = {
  [TOKEN.DOT] = 10,
  [TOKEN.LBRACKET] = 10,
  [TOKEN.LPAREN] = 10,
  [TOKEN.NOT] = 6,
  [TOKEN.TILDE] = 6,
  [TOKEN.STARSTAR] = 5.5,
  [TOKEN.STAR] = 5,
  [TOKEN.SLASH] = 5,
  [TOKEN.PERCENT] = 5,
  [TOKEN.PLUS] = 4,
  [TOKEN.MINUS] = 4,
  [TOKEN.LEFT_SHIFT] = 3.5,
  [TOKEN.RIGHT_SHIFT] = 3.5,
  [TOKEN.UNSIGNED_RIGHT_SHIFT] = 3.5,
  [TOKEN.EQ] = 2.9,
  [TOKEN.NEQ] = 2.9,
  [TOKEN.LOOSE_EQ] = 2.9,
  [TOKEN.LOOSE_NEQ] = 2.9,
  [TOKEN.LT] = 3,
  [TOKEN.GT] = 3,
  [TOKEN.LTE] = 3,
  [TOKEN.GTE] = 3,
  [TOKEN.IN] = 3,
  [TOKEN.INSTANCEOF] = 3,
  [TOKEN.BITWISE_AND] = 2.75,
  [TOKEN.BITWISE_XOR] = 2.5,
  [TOKEN.BITWISE_OR] = 2.25,
  [TOKEN.AND] = 2,
  [TOKEN.OR] = 1,
  [TOKEN.QUESTION] = 0.75,
  [TOKEN.ASSIGN] = 0.5,
  [TOKEN.PLUS_ASSIGN] = 0.5,
  [TOKEN.MINUS_ASSIGN] = 0.5,
  [TOKEN.STAR_ASSIGN] = 0.5,
  [TOKEN.STARSTAR_ASSIGN] = 0.5,
  [TOKEN.SLASH_ASSIGN] = 0.5,
  [TOKEN.PERCENT_ASSIGN] = 0.5,
  [TOKEN.BITWISE_AND_ASSIGN] = 0.5,
  [TOKEN.BITWISE_OR_ASSIGN] = 0.5,
  [TOKEN.BITWISE_XOR_ASSIGN] = 0.5,
  [TOKEN.LEFT_SHIFT_ASSIGN] = 0.5,
  [TOKEN.RIGHT_SHIFT_ASSIGN] = 0.5,
  [TOKEN.UNSIGNED_RIGHT_SHIFT_ASSIGN] = 0.5,
}

local nuds = {}
local leds = {}

local pratt_expr

local UNARY_PREFIX_OPS = {
  [TOKEN.NOT] = "!",
  [TOKEN.TILDE] = "~",
  [TOKEN.PLUS] = "+",
  [TOKEN.MINUS] = "-",
}

for tok_type, op_str in pairs(UNARY_PREFIX_OPS) do
  nuds[tok_type] = function(stream, tok)
    local argument = pratt_expr(stream, 6)
    return ast.unary_expression(op_str, argument, tok)
  end
end

nuds[TOKEN.INCREMENT] = function(stream, tok)
  local argument = pratt_expr(stream, 6)
  check_update_target(argument, tok)
  return ast.update_expression(tok.type, argument, true, tok)
end

nuds[TOKEN.DECREMENT] = function(stream, tok)
  local argument = pratt_expr(stream, 6)
  check_update_target(argument, tok)
  return ast.update_expression(tok.type, argument, true, tok)
end

nuds[TOKEN.DELETE] = function(stream, tok)
  local argument = pratt_expr(stream, 6)
  return ast.delete_expression(argument, tok)
end

nuds[TOKEN.TYPEOF] = function(stream, tok)
  local argument = pratt_expr(stream, 6)
  return ast.typeof_expression(argument, tok)
end

nuds[TOKEN.NEW] = function(stream, tok)
  if stream.is(TOKEN.NEW) then
    return pratt_expr(stream, 6)
  end
  local banned_err = check_banned(stream)
  if banned_err then
    error(banned_err, 0)
  end
  local id_token = stream.consume(TOKEN.IDENTIFIER)
  local callee = ast.identifier(id_token.value, id_token)
  while stream.is(TOKEN.DOT) or stream.is(TOKEN.LBRACKET) do
    if stream.is(TOKEN.DOT) then
      local dot = stream.advance()
      local prop_token = stream.consume_property_name()
      callee =
        ast.member_expression(callee, ast.identifier(prop_token.value, prop_token), false, dot)
    else
      local lbracket = stream.advance()
      local prop = P.expression(stream)
      stream.consume(TOKEN.RBRACKET)
      callee = ast.member_expression(callee, prop, true, lbracket)
    end
  end
  local args = {}
  if stream.is(TOKEN.LPAREN) then
    stream.advance()
    args = parse_comma_list(stream, TOKEN.RPAREN, P.maybe_spread)
    stream.consume(TOKEN.RPAREN)
  end
  return ast.new_expression(callee, args, tok)
end

nuds[TOKEN.NUMBER] = function(stream, tok)
  if stream.is(TOKEN.DOT) and stream.peek_n(2).type == TOKEN.DOT then
    stream.advance()
    return ast.number_literal(tok.value, tok)
  end
  if tok.value % 1 == 0 and stream.is(TOKEN.DOT) then
    parse_error(
      "Unexpected token after integer literal",
      stream.peek().line,
      stream.peek().col
    )
  end
  return ast.number_literal(tok.value, tok)
end

nuds[TOKEN.STRING] = function(stream, tok)
  return ast.string_literal(tok.value, tok)
end

nuds[TOKEN.BOOLEAN] = function(stream, tok)
  return ast.boolean_literal(tok.value, tok)
end

nuds[TOKEN.NULL] = function(stream, tok)
  return ast.null_literal(tok)
end

nuds[TOKEN.UNDEFINED] = function(stream, tok)
  return ast.undefined_literal(tok)
end

nuds[TOKEN.THIS] = function(stream, tok)
  return ast.this_expression(tok)
end

nuds[TOKEN.SUPER] = function(stream, tok)
  return ast.super_expression(tok)
end

nuds[TOKEN.IDENTIFIER] = function(stream, tok)
  local expr = ast.identifier(tok.value, tok)

  if stream.is(TOKEN.ARROW) then
    stream.advance()
    local body = P.arrow_function_body(stream)
    return ast.arrow_function_expression({ expr }, body, tok)
  end

  return expr
end

nuds[TOKEN.LPAREN] = function(stream, tok)
  local depth = 0
  local n = 0
  local found_arrow = false

  while true do
    local t = stream.peek_n(n)
    if t.type == TOKEN.EOF then
      break
    end
    if t.type == TOKEN.LPAREN then
      depth = depth + 1
    elseif t.type == TOKEN.RPAREN then
      depth = depth - 1
    end
    if depth == 0 then
      if stream.peek_n(n + 1) and stream.peek_n(n + 1).type == TOKEN.ARROW then
        found_arrow = true
      end
      break
    end
    n = n + 1
  end

  if found_arrow then
    local arrow_token = tok
    local params = {}
    local found_rest = false
    if not stream.is(TOKEN.RPAREN) then
      while true do
        if found_rest then
          parse_error(
            "Rest parameter must be the last parameter",
            stream.peek().line,
            stream.peek().col
          )
        end
        if stream.is(TOKEN.ELLIPSIS) then
          local ellipsis = stream.advance()
          local id_token = stream.consume(TOKEN.IDENTIFIER)
          table.insert(
            params,
            ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis)
          )
          found_rest = true
        elseif stream.is(TOKEN.LBRACKET) then
          local param = P.array_pattern(stream)
          if stream.is(TOKEN.ASSIGN) then
            local assign_tok = stream.advance()
            local default_expr = P.expression(stream)
            table.insert(params, ast.assignment_pattern(param, default_expr, assign_tok))
          else
            table.insert(params, param)
          end
        elseif stream.is(TOKEN.LBRACE) then
          local param = P.object_pattern(stream)
          if stream.is(TOKEN.ASSIGN) then
            local assign_tok = stream.advance()
            local default_expr = P.expression(stream)
            table.insert(params, ast.assignment_pattern(param, default_expr, assign_tok))
          else
            table.insert(params, param)
          end
        elseif stream.is(TOKEN.IDENTIFIER) then
          local id_token = stream.advance()
          local param = ast.identifier(id_token.value, id_token)
          if stream.is(TOKEN.ASSIGN) then
            local assign_tok = stream.advance()
            local default_expr = P.expression(stream)
            table.insert(params, ast.assignment_pattern(param, default_expr, assign_tok))
          else
            table.insert(params, param)
          end
        else
          parse_error(
            "Arrow function parameters must be identifiers",
            stream.peek().line,
            stream.peek().col
          )
        end
        if not stream.is(TOKEN.COMMA) then
          break
        end
        stream.advance()
      end
    end
    stream.consume(TOKEN.RPAREN)
    stream.consume(TOKEN.ARROW)
    local body = P.arrow_function_body(stream)
    return ast.arrow_function_expression(params, body, arrow_token)
  else
    local expr = P.expression(stream)
    stream.consume(TOKEN.RPAREN)
    return expr
  end
end

nuds[TOKEN.LBRACKET] = function(stream, tok)
  return P.array_literal(stream, tok)
end

nuds[TOKEN.LBRACE] = function(stream, tok)
  return P.object_literal(stream, tok)
end

nuds[TOKEN.FUNCTION] = function(stream, tok)
  return P.function_expression(stream, tok)
end

nuds[TOKEN.CLASS] = function(stream, tok)
  return P.class_expression(stream, tok)
end

nuds[TOKEN.TEMPLATE_LITERAL] = function(stream, tok)
  local quasis = {}
  local expressions = {}
  for i, q in ipairs(tok.value.quasis) do
    local is_tail = (i == #tok.value.quasis)
    quasis[#quasis + 1] = ast.template_element(q, is_tail, tok)
  end
  for _, expr_src in ipairs(tok.value.expression_sources) do
    local expr_tokens = tokenize(expr_src)
    if not expr_tokens then
      parse_error("Failed to tokenize template expression", tok.line, tok.col)
    end
    local expr_stream = make_token_stream(expr_tokens)
    expressions[#expressions + 1] = P.expression(expr_stream)
  end
  return ast.template_literal(quasis, expressions, tok)
end

nuds[TOKEN.ARROW] = function(stream, tok)
  parse_error("Unexpected arrow token", tok.line, tok.col)
end

pratt_expr = function(stream, min_prec, no_in)
  local tok = stream.peek()
  local nud_fn = nuds[tok.type]
  local left
  local left
  if nud_fn then
    stream.advance()
    left = nud_fn(stream, tok)
  else
    local banned_err = check_banned(stream)
    if banned_err then
      error(banned_err, 0)
    end
    parse_error(
      string.format("Unexpected token %s", tok.type),
      tok.line,
      tok.col
    )
  end

  local had_postfix = false

  while true do
    local next_tok = stream.peek()
    local op = next_tok.type

    if op == TOKEN.INCREMENT or op == TOKEN.DECREMENT then
      if had_postfix then break end
      stream.advance()
      if not ast.is_valid_update_target(left) and left.type ~= ast.TYPE_CALL_EXPRESSION then
        parse_error(
          "Invalid update target: cannot use " .. op .. " on this expression",
          next_tok.line,
          next_tok.col
        )
      end
      left = ast.update_expression(op, left, false, next_tok)
      had_postfix = true
    else
      local prec = PRECEDENCE[op]
      if not prec or prec < min_prec then
        break
      end
      if op == TOKEN.IN and no_in then
        break
      end
      if had_postfix and (op == TOKEN.DOT or op == TOKEN.LBRACKET or op == TOKEN.LPAREN) then
        break
      end

      local led_fn = leds[op]
      if led_fn then
        stream.advance()
        left = led_fn(stream, next_tok, left, no_in)
      else
        break
      end
    end
  end

  return left
end

function P.arrow_function_body(stream)
  if stream.is(TOKEN.LBRACE) then
    local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
    stream.loop_depth, stream.switch_depth = 0, 0
    local body = P.block_statement(stream)
    stream.loop_depth, stream.switch_depth = saved_loop, saved_switch
    return body
  else
    local expr_token = stream.peek()
    local expr = P.expression(stream)
    local ret = ast.return_statement(expr, expr_token)
    return ast.block_statement({ ret }, expr_token)
  end
end

local function led_binary_left(tok_type)
  return function(stream, tok, left, no_in)
    local right = pratt_expr(stream, PRECEDENCE[tok_type] + 0.01, no_in)
    return ast.binary_expression(tok_type, left, right, tok)
  end
end

leds[TOKEN.STAR] = led_binary_left(TOKEN.STAR)
leds[TOKEN.STARSTAR] = function(stream, tok, left, no_in)
  local right = pratt_expr(stream, PRECEDENCE[TOKEN.STARSTAR], no_in)
  return ast.binary_expression(TOKEN.STARSTAR, left, right, tok)
end
leds[TOKEN.SLASH] = led_binary_left(TOKEN.SLASH)
leds[TOKEN.PERCENT] = led_binary_left(TOKEN.PERCENT)
leds[TOKEN.PLUS] = led_binary_left(TOKEN.PLUS)
leds[TOKEN.MINUS] = led_binary_left(TOKEN.MINUS)
leds[TOKEN.LEFT_SHIFT] = led_binary_left(TOKEN.LEFT_SHIFT)
leds[TOKEN.RIGHT_SHIFT] = led_binary_left(TOKEN.RIGHT_SHIFT)
leds[TOKEN.UNSIGNED_RIGHT_SHIFT] = led_binary_left(TOKEN.UNSIGNED_RIGHT_SHIFT)
leds[TOKEN.LT] = led_binary_left(TOKEN.LT)
leds[TOKEN.GT] = led_binary_left(TOKEN.GT)
leds[TOKEN.LTE] = led_binary_left(TOKEN.LTE)
leds[TOKEN.GTE] = led_binary_left(TOKEN.GTE)
leds[TOKEN.INSTANCEOF] = led_binary_left(TOKEN.INSTANCEOF)
leds[TOKEN.IN] = led_binary_left(TOKEN.IN)
leds[TOKEN.EQ] = led_binary_left(TOKEN.EQ)
leds[TOKEN.NEQ] = led_binary_left(TOKEN.NEQ)
leds[TOKEN.LOOSE_EQ] = led_binary_left(TOKEN.LOOSE_EQ)
leds[TOKEN.LOOSE_NEQ] = led_binary_left(TOKEN.LOOSE_NEQ)
leds[TOKEN.BITWISE_AND] = led_binary_left(TOKEN.BITWISE_AND)
leds[TOKEN.BITWISE_XOR] = led_binary_left(TOKEN.BITWISE_XOR)
leds[TOKEN.BITWISE_OR] = led_binary_left(TOKEN.BITWISE_OR)
leds[TOKEN.AND] = led_binary_left(TOKEN.AND)
leds[TOKEN.OR] = led_binary_left(TOKEN.OR)

local ASSIGN_OPS = {
  [TOKEN.ASSIGN] = true,
  [TOKEN.PLUS_ASSIGN] = true,
  [TOKEN.MINUS_ASSIGN] = true,
  [TOKEN.STAR_ASSIGN] = true,
  [TOKEN.STARSTAR_ASSIGN] = true,
  [TOKEN.SLASH_ASSIGN] = true,
  [TOKEN.PERCENT_ASSIGN] = true,
  [TOKEN.BITWISE_AND_ASSIGN] = true,
  [TOKEN.BITWISE_OR_ASSIGN] = true,
  [TOKEN.BITWISE_XOR_ASSIGN] = true,
  [TOKEN.LEFT_SHIFT_ASSIGN] = true,
  [TOKEN.RIGHT_SHIFT_ASSIGN] = true,
  [TOKEN.UNSIGNED_RIGHT_SHIFT_ASSIGN] = true,
}

local function led_assign(stream, tok, left, no_in)
  local op = tok.type
  if op == TOKEN.ASSIGN then
    if left.type == ast.TYPE_ARRAY_EXPRESSION or left.type == ast.TYPE_OBJECT_EXPRESSION then
      left = coerce_to_pattern(left)
    end
  end
  local right = P.expression(stream, no_in)
  return ast.binary_expression(op, left, right, tok)
end

for op_type, _ in pairs(ASSIGN_OPS) do
  leds[op_type] = led_assign
end

leds[TOKEN.QUESTION] = function(stream, tok, left, no_in)
  local consequent = P.expression(stream, no_in)
  stream.consume(TOKEN.COLON)
  local alternate = P.expression(stream, no_in)
  return ast.conditional_expression(left, consequent, alternate, tok)
end

leds[TOKEN.DOT] = function(stream, tok, left)
  local prop_token = stream.consume_property_name()
  return ast.member_expression(left, ast.identifier(prop_token.value, prop_token), false, tok)
end

leds[TOKEN.LBRACKET] = function(stream, tok, left)
  local prop = P.expression(stream)
  stream.consume(TOKEN.RBRACKET)
  return ast.member_expression(left, prop, true, tok)
end

leds[TOKEN.LPAREN] = function(stream, tok, left)
  local args = parse_comma_list(stream, TOKEN.RPAREN, P.maybe_spread)
  stream.consume(TOKEN.RPAREN)
  return ast.call_expression(left, args, tok)
end

--- Entry point for expression parsing. Starts at minimum precedence 0.
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' as a binary operator (for for-loop init)
function P.expression(stream, no_in)
  return pratt_expr(stream, 0, no_in)
end

function P.maybe_spread(stream)
  if stream.is(TOKEN.ELLIPSIS) then
    local ellipsis = stream.advance()
    local expr = P.expression(stream)
    return ast.spread_element(expr, ellipsis)
  end
  return P.expression(stream)
end

--- Parse array literal: [expr, expr, ...]
-- Empty arrays [] are valid.
function P.array_literal(stream, tok)
  local lbracket = tok or stream.consume(TOKEN.LBRACKET)
  local elements = {}
  local idx = 1

  while not stream.is(TOKEN.RBRACKET) and not stream.eof() do
    if stream.is(TOKEN.COMMA) then
      elements[idx] = nil
      idx = idx + 1
      stream.advance()
    elseif stream.is(TOKEN.ELLIPSIS) then
      local ellipsis = stream.advance()
      local expr = P.expression(stream)
      elements[idx] = ast.spread_element(expr, ellipsis)
      idx = idx + 1
      if stream.is(TOKEN.COMMA) then
        stream.advance()
      end
    else
      local expr = P.expression(stream)
      elements[idx] = expr
      idx = idx + 1
      if stream.is(TOKEN.COMMA) then
        stream.advance()
      end
    end
  end

  stream.consume(TOKEN.RBRACKET)
  local node = ast.array_expression(elements, lbracket)
  node.count = idx - 1
  return node
end

--- Parse object literal: { key: value, key: value, ... }
-- Property forms:
--   key: value       — regular key-value pair
--   key(params) {}   — method shorthand (identifier keys only)
--   key              — shorthand property, equivalent to key: key (identifier keys only)
-- String keys only support the key: value form.
-- Computed keys (e.g. {[expr]: value}) are not supported.
-- Empty objects {} are valid.
function P.object_literal(stream, tok)
  local lbrace = tok or stream.consume(TOKEN.LBRACE)

  local function parse_property(s)
    local key
    local key_is_identifier = false
    if s.is_property_name() then
      local key_token = s.advance()
      key = ast.identifier(key_token.value, key_token)
      key_is_identifier = true
    elseif s.is(TOKEN.STRING) then
      local key_token = s.advance()
      key = ast.string_literal(key_token.value, key_token)
    else
      parse_error("Expected property key", s.peek().line, s.peek().col)
    end

    if s.is(TOKEN.COLON) then
      s.advance()
      local value = P.expression(s)
      return ast.property(key, value, false, key)
    elseif key_is_identifier and s.is(TOKEN.LPAREN) then
      s.consume(TOKEN.LPAREN)
      local params = P.parameters(s)
      s.consume(TOKEN.RPAREN)
      local body = P.block_statement(s)
      local fn = ast.function_expression(params, body, key)
      fn.name = key.name
      fn.is_method = true
      return ast.property(key, fn, false, key)
    elseif key_is_identifier and (s.is(TOKEN.COMMA) or s.is(TOKEN.RBRACE)) then
      return ast.property(key, ast.identifier(key.name, key), false, key, true)
    else
      parse_error("Expected ':', '(', ',', or '}' after property key", s.peek().line, s.peek().col)
    end
  end

  local properties = parse_comma_list(stream, TOKEN.RBRACE, parse_property, true)
  stream.consume(TOKEN.RBRACE)
  return ast.object_expression(properties, lbrace)
end

--- Parse function expression: function(params) { body } or function name(params) { body }
-- Can be anonymous (no name) or named. Named function expressions produce
-- a FunctionExpression node with a `name` field (not FunctionDeclaration).
function P.function_expression(stream, tok)
  local kw = tok or stream.consume(TOKEN.FUNCTION)

  local name = nil
  -- Disambiguate: function foo( is a named expression, function( is anonymous.
  -- Check if current token is identifier AND the one after it is (.
  if stream.is(TOKEN.IDENTIFIER) then
    local name_token = stream.peek_n(2)
    if name_token and name_token.type == TOKEN.LPAREN then
      local id_token = stream.advance()
      name = id_token.value
    end
  end

  stream.consume(TOKEN.LPAREN)
  local params = P.parameters(stream)
  stream.consume(TOKEN.RPAREN)

  local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
  stream.loop_depth, stream.switch_depth = 0, 0
  local body = P.block_statement(stream)
  stream.loop_depth, stream.switch_depth = saved_loop, saved_switch

  if name then
    local fn = ast.function_expression(params, body, kw)
    fn.name = name
    return fn
  else
    return ast.function_expression(params, body, kw)
  end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

M.TOKEN = TOKEN
M.tokenize = tokenize
M.make_token_stream = make_token_stream
M.ParseError = tokenizer.ParseError
M.is_parse_error = is_parse_error
M.make_parse_error = make_parse_error

--- Format a ParseError with source context for terminal display.
-- @param err (table) ParseError {message, line, col}
-- @param source (string) The original source code
-- @return (string) Formatted multi-line error string
function M.format_error(err, source)
  local result = err.message

  if err.line and err.line > 0 and source then
    local lines = {}
    for line in source:gmatch("[^\n]*") do
      table.insert(lines, line)
    end

    local line_str = tostring(err.line)
    local pad = string.rep(" ", #line_str)

    result = result .. "\n  " .. pad .. " |"

    if err.line <= #lines then
      local source_line = lines[err.line]
      result = result .. "\n" .. line_str .. " | " .. source_line
      result = result .. "\n  " .. pad .. " | " .. string.rep(" ", math.max(0, err.col - 1)) .. "^"
    end
  end

  return result
end

return M
