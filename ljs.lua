-- ljs - JavaScript subset parser for Lua
-- Parses a well-defined subset of JavaScript into a Lua table-based AST.
--
-- Usage:
--   local ljs = require("ljs")
--   local ast, err = ljs.parse("let x = 42; console.log(x);")
--   if not ast then print(err) end

local ljs = {}

-- ============================================================================
-- TOKEN TYPES
-- ============================================================================

-- Token type constants
local TOKEN = {
  -- End of input
  EOF = "EOF",

  -- Literals
  NUMBER = "Number",
  STRING = "String",
  BOOLEAN = "Boolean",
  NULL = "Null",

  -- Identifiers and keywords
  IDENTIFIER = "Identifier",

  -- Keywords
  LET = "let",
  CONST = "const",
  FUNCTION = "function",
  IF = "if",
  ELSE = "else",
  WHILE = "while",
  FOR = "for",
  OF = "of",
  THROW = "throw",
  TRY = "try",
  CATCH = "catch",
  RETURN = "return",

  -- Punctuation
  LPAREN = "(",
  RPAREN = ")",
  LBRACE = "{",
  RBRACE = "}",
  LBRACKET = "[",
  RBRACKET = "]",
  COMMA = ",",
  SEMICOLON = ";",
  COLON = ":",
  DOT = ".",

  -- Operators
  PLUS = "+",
  MINUS = "-",
  STAR = "*",
  SLASH = "/",
  EQ = "===",
  ASSIGN = "=",
  -- Unary
  NOT = "!",
  NEQ = "!==",
  LT = "<",
  GT = ">",
  LTE = "<=",
  GTE = ">=",
  AND = "&&",
  OR = "||",
  PERCENT = "%",

  -- Arrow function
  ARROW = "=>",

  -- Error-triggering keywords
  THIS = "this",
  ASYNC = "async",
  AWAIT = "await",
  TYPEOF = "typeof",
  INSTANCEOF = "instanceof",
}

-- Keyword lookup - maps keyword strings to token types
local KEYWORDS = {
  ["let"] = TOKEN.LET,
  ["const"] = TOKEN.CONST,
  ["function"] = TOKEN.FUNCTION,
  ["if"] = TOKEN.IF,
  ["else"] = TOKEN.ELSE,
  ["while"] = TOKEN.WHILE,
  ["for"] = TOKEN.FOR,
  ["of"] = TOKEN.OF,
  ["throw"] = TOKEN.THROW,
  ["try"] = TOKEN.TRY,
  ["catch"] = TOKEN.CATCH,
  ["return"] = TOKEN.RETURN,
  ["true"] = TOKEN.BOOLEAN,
  ["false"] = TOKEN.BOOLEAN,
  ["null"] = TOKEN.NULL,
}

-- ============================================================================
-- TOKENIZER
-- ============================================================================

-- Token structure: {type, value, line, col}
-- For EOF: {type = "EOF", line, col}
-- For identifiers/keywords: {type, value (string), line, col}
-- For literals: {type, value (actual value), line, col}
-- For punctuation/operators: {type, line, col}

--- Tokenize JavaScript source code into a list of tokens.
-- @param source (string) The JavaScript source code to tokenize
-- @return tokens (table) Array of token tables
-- @return err (string) Error message if tokenization failed
local function tokenize(source)
  local tokens = {}
  local pos = 1
  local line = 1
  local col = 1
  local len = #source

  -- Helper: get current character
  local function current()
    return pos <= len and source:sub(pos, pos) or nil
  end

  -- Helper: lookahead n characters
  local function lookahead(n)
    return pos + n - 1 <= len and source:sub(pos, pos + n - 1) or nil
  end

  -- Helper: advance position
  local function advance(n)
    n = n or 1
    for i = 1, n do
      local c = source:sub(pos, pos)
      pos = pos + 1
      if c == "\n" then
        line = line + 1
        col = 1
      else
        col = col + 1
      end
    end
  end

  -- Helper: skip whitespace
  local function skip_whitespace()
    while current() do
      local c = current()
      if c:match("%s") then
        advance()
      else
        break
      end
    end
  end

  -- Helper: skip single-line comments
  local function skip_single_line_comment()
    if lookahead(2) == "//" then
      advance(2)
      while current() and current() ~= "\n" do
        advance()
      end
      return true
    end
    return false
  end

  -- Helper: skip multi-line comments
  local function skip_multi_line_comment()
    if lookahead(2) == "/*" then
      advance(2)
      while current() do
        if lookahead(2) == "*/" then
          advance(2)
          return true
        end
        advance()
      end
      return false, "Unterminated multi-line comment"
    end
    return false
  end

  -- Helper: skip all comments and whitespace
  local function skip_trivia()
    skip_whitespace()
    while current() do
      if skip_single_line_comment() then
        skip_whitespace()
      elseif skip_multi_line_comment() then
        skip_whitespace()
      else
        break
      end
    end
  end

  -- Helper: create a token
  local function make_token(type, value)
    return {
      type = type,
      value = value,
      line = line,
      col = col,
    }
  end

  -- Helper: check if character is a digit
  local function is_digit(c)
    return c:match("%d")
  end

  -- Helper: check if character is a letter or underscore
  local function is_alpha(c)
    return c:match("[%a_]")
  end

  -- Helper: check if character is alphanumeric or underscore
  local function is_alnum(c)
    return c:match("[%w_]")
  end

  while pos <= len do
    skip_trivia()
    if pos > len then break end

    local c = current()

    -- EOF
    if not c then
      table.insert(tokens, make_token(TOKEN.EOF))
      break
    end

    -- Identifiers and keywords
    if is_alpha(c) then
      local start_pos = pos
      local start_col = col
      while current() and is_alnum(current()) do
        advance()
      end
      local text = source:sub(start_pos, pos - 1)
      local token_type = KEYWORDS[text] or TOKEN.IDENTIFIER
      -- Convert boolean/null to their literal types
      if token_type == TOKEN.BOOLEAN then
        table.insert(tokens, make_token(TOKEN.BOOLEAN, text == "true"))
      elseif token_type == TOKEN.NULL then
        table.insert(tokens, make_token(TOKEN.NULL, nil))
      else
        table.insert(tokens, make_token(token_type, text))
      end

    -- Numbers
    elseif is_digit(c) then
      local start_pos = pos
      local start_col = col
      -- Integer part
      while current() and is_digit(current()) do
        advance()
      end
      -- Fractional part
      if current() == "." and is_digit(lookahead(2)) then
        advance()
        while current() and is_digit(current()) do
          advance()
        end
      end
      local text = source:sub(start_pos, pos - 1)
      local num = tonumber(text)
      if not num then
        return nil, string.format("Invalid number literal at line %d, col %d", line, start_col)
      end
      table.insert(tokens, make_token(TOKEN.NUMBER, num))

    -- Strings
    elseif c == '"' or c == "'" then
      local quote = c
      local start_pos = pos
      local start_col = col
      advance() -- skip opening quote
      local chars = {}
      local escaped = false
      while current() do
        local ch = current()
        if escaped then
          -- Handle escape sequences
          if ch == "n" then ch = "\n"
          elseif ch == "r" then ch = "\r"
          elseif ch == "t" then ch = "\t"
          elseif ch == "b" then ch = "\b"
          elseif ch == "f" then ch = "\f"
          elseif ch == "\\" then ch = "\\"
          elseif ch == '"' then ch = '"'
          elseif ch == "'" then ch = "'"
          else
            return nil, string.format("Invalid escape sequence at line %d, col %d", line, col)
          end
          table.insert(chars, ch)
          escaped = false
          advance()
        elseif ch == "\\" then
          escaped = true
          advance()
        elseif ch == quote then
          advance() -- skip closing quote
          break
        elseif ch == "\n" then
          return nil, string.format("Unterminated string literal at line %d, col %d", line, start_col)
        else
          table.insert(chars, ch)
          advance()
        end
      end
      if not current() then
        return nil, string.format("Unterminated string literal at line %d, col %d", line, start_col)
      end
      local str = table.concat(chars, "")
      table.insert(tokens, make_token(TOKEN.STRING, str))

    -- Punctuation and operators
    elseif c == "(" then
      table.insert(tokens, make_token(TOKEN.LPAREN))
      advance()
    elseif c == ")" then
      table.insert(tokens, make_token(TOKEN.RPAREN))
      advance()
    elseif c == "{" then
      table.insert(tokens, make_token(TOKEN.LBRACE))
      advance()
    elseif c == "}" then
      table.insert(tokens, make_token(TOKEN.RBRACE))
      advance()
    elseif c == "[" then
      table.insert(tokens, make_token(TOKEN.LBRACKET))
      advance()
    elseif c == "]" then
      table.insert(tokens, make_token(TOKEN.RBRACKET))
      advance()
    elseif c == "," then
      table.insert(tokens, make_token(TOKEN.COMMA))
      advance()
    elseif c == ";" then
      table.insert(tokens, make_token(TOKEN.SEMICOLON))
      advance()
    elseif c == ":" then
      table.insert(tokens, make_token(TOKEN.COLON))
      advance()
    elseif c == "." then
      table.insert(tokens, make_token(TOKEN.DOT))
      advance()
    elseif c == "+" then
      table.insert(tokens, make_token(TOKEN.PLUS))
      advance()
    elseif c == "-" then
      table.insert(tokens, make_token(TOKEN.MINUS))
      advance()
    elseif c == "*" then
      table.insert(tokens, make_token(TOKEN.STAR))
      advance()
    elseif c == "/" then
      table.insert(tokens, make_token(TOKEN.SLASH))
      advance()
    elseif c == "%" then
      table.insert(tokens, make_token(TOKEN.PERCENT))
      advance()
    elseif c == "=" then
      if lookahead(2) == "==" then
        if lookahead(3) == "===" then
          table.insert(tokens, make_token(TOKEN.EQ))
          advance(3)
        else
          return nil, string.format("Use === instead of == at line %d, col %d", line, col)
        end
      else
        table.insert(tokens, make_token(TOKEN.ASSIGN))
        advance()
      end
    elseif c == "!" then
      if source:sub(pos, pos + 2) == "!==" then
        table.insert(tokens, make_token(TOKEN.NEQ))
        advance(3)
      else
        table.insert(tokens, make_token(TOKEN.NOT))
        advance()
      end
    elseif c == "<" then
      if lookahead(2) == "<=" then
        table.insert(tokens, make_token(TOKEN.LTE))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.LT))
        advance()
      end
    elseif c == ">" then
      if lookahead(2) == ">=" then
        table.insert(tokens, make_token(TOKEN.GTE))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.GT))
        advance()
      end
    elseif c == "&" then
      if lookahead(2) == "&&" then
        table.insert(tokens, make_token(TOKEN.AND))
        advance(2)
      else
        return nil, string.format("Unexpected character '%s' at line %d, col %d", c, line, col)
      end
    elseif c == "|" then
      if lookahead(2) == "||" then
        table.insert(tokens, make_token(TOKEN.OR))
        advance(2)
      else
        return nil, string.format("Unexpected character '%s' at line %d, col %d", c, line, col)
      end
    elseif lookahead(2) == "=>" then
      table.insert(tokens, make_token(TOKEN.ARROW))
      advance(2)

    else
      return nil, string.format("Unexpected character '%s' at line %d, col %d", c, line, col)
    end
  end

  -- Add EOF token if not already added
  if #tokens == 0 or tokens[#tokens].type ~= TOKEN.EOF then
    table.insert(tokens, make_token(TOKEN.EOF))
  end

  return tokens
end

ljs.tokenize = tokenize

-- ============================================================================
-- TOKEN STREAM CONSUMER
-- ============================================================================

--- Create a token stream from a list of tokens.
-- @param tokens (table) Array of token tables from tokenize()
-- @return stream (table) Token stream with peek/advance/expect methods
local function make_token_stream(tokens)
  local pos = 1
  local len = #tokens

  local stream = {}

  --- Peek at the current token without consuming it.
  -- @return token (table) The current token, or EOF token if at end
  function stream.peek()
    return tokens[pos] or tokens[len]
  end

  --- Peek at the token n positions ahead.
  -- @param n (number) Number of tokens to look ahead (default 1)
  -- @return token (table) The token n positions ahead, or EOF
  function stream.peek_n(n)
    n = n or 1
    local idx = pos + n - 1
    return tokens[idx] or tokens[len]
  end

  --- Check if current token matches the expected type.
  -- @param expected (string) Token type to check
  -- @return boolean True if current token type matches
  function stream.is(expected)
    return stream.peek().type == expected
  end

  --- Check if current token matches any of the expected types.
  -- @param ... Expected token types
  -- @return boolean True if current token type matches any expected
  function stream.is_any(...)
    local expected = {...}
    local t = stream.peek().type
    for i = 1, #expected do
      if t == expected[i] then
        return true
      end
    end
    return false
  end

  --- Advance to the next token and return the current one.
  -- @return token (table) The token that was current before advancing
  function stream.advance()
    local token = stream.peek()
    pos = pos + 1
    return token
  end

  --- Consume the current token if it matches the expected type.
  -- @param expected (string) Token type to expect
  -- @return token (table) The consumed token, or nil if mismatch
  function stream.expect(expected)
    if stream.is(expected) then
      return stream.advance()
    end
    return nil
  end

  --- Consume the current token and assert it matches the expected type.
  -- @param expected (string) Token type to expect
  -- @return token (table) The consumed token
  -- @raises error if token type doesn't match
  function stream.consume(expected)
    local token = stream.expect(expected)
    if not token then
      local current = stream.peek()
      error(string.format("Expected %s, got %s at line %d, col %d",
        expected, current.type, current.line, current.col))
    end
    return token
  end

  --- Check if we've reached the end of the token stream.
  -- @return boolean True if at EOF
  function stream.eof()
    return stream.peek().type == TOKEN.EOF
  end

  return stream
end

-- ============================================================================
-- AST BUILDERS
-- ============================================================================

-- Helper functions to create AST nodes consistently

local function identifier(name, token)
  return { type = "Identifier", name = name }
end

local function number_literal(value, token)
  return { type = "NumberLiteral", value = value }
end

local function string_literal(value, token)
  return { type = "StringLiteral", value = value }
end

local function boolean_literal(value, token)
  return { type = "BooleanLiteral", value = value }
end

local function null_literal(token)
  return { type = "NullLiteral" }
end

local function binary_expression(operator, left, right)
  return { type = "BinaryExpression", operator = operator, left = left, right = right }
end

local function unary_expression(operator, argument)
  return { type = "UnaryExpression", operator = operator, argument = argument }
end

local function call_expression(callee, arguments)
  return { type = "CallExpression", callee = callee, arguments = arguments }
end

local function member_expression(object, property, computed)
  return { type = "MemberExpression", object = object, property = property, computed = computed }
end

local function variable_declaration(kind, declarations)
  return { type = "VariableDeclaration", kind = kind, declarations = declarations }
end

local function variable_declarator(name, init)
  return { type = "VariableDeclarator", name = name, init = init }
end

local function function_declaration(name, params, body)
  return { type = "FunctionDeclaration", name = name, params = params, body = body }
end

local function function_expression(params, body)
  return { type = "FunctionExpression", params = params, body = body }
end

local function arrow_function_expression(params, body)
  return { type = "ArrowFunctionExpression", params = params, body = body }
end

local function if_statement(test, consequent, alternate)
  return { type = "IfStatement", test = test, consequent = consequent, alternate = alternate }
end

local function while_statement(test, body)
  return { type = "WhileStatement", test = test, body = body }
end

local function for_of_statement(left, right, body)
  return { type = "ForOfStatement", left = left, right = right, body = body }
end

local function block_statement(body)
  return { type = "BlockStatement", body = body }
end

local function expression_statement(expression)
  return { type = "ExpressionStatement", expression = expression }
end

local function throw_statement(argument)
  return { type = "ThrowStatement", argument = argument }
end

local function try_statement(block, handler)
  return { type = "TryStatement", block = block, handler = handler }
end

local function catch_clause(param, body)
  return { type = "CatchClause", param = param, body = body }
end

local function return_statement(argument)
  return { type = "ReturnStatement", argument = argument }
end

local function object_expression(properties)
  return { type = "ObjectExpression", properties = properties }
end

local function property(key, value, computed)
  return { type = "Property", key = key, value = value, computed = computed or false }
end

local function array_expression(elements)
  return { type = "ArrayExpression", elements = elements }
end

-- ============================================================================
-- PARSER
-- ============================================================================

local parse_statement
local parse_block_statement
local parse_variable_declaration
local parse_variable_declarator
local parse_if_statement
local parse_while_statement
local parse_for_of_statement
local parse_throw_statement
local parse_try_statement
local parse_function_declaration
local parse_return_statement
local parse_parameters
local parse_expression
local parse_binary_expression
local parse_unary_expression
local parse_primary_expression
local parse_arrow_function_body
local parse_identifier_or_call
local parse_call_expression
local parse_array_literal
local parse_object_literal
local parse_function_expression

--- Parse JavaScript source into an AST.
-- @param source (string) JavaScript source code
-- @return ast (table) The AST root node (Program)
-- @return err (string) Error message if parsing failed
function ljs.parse(source)
  local tokens, tokenize_err = tokenize(source)
  if not tokens then
    return nil, tokenize_err
  end

  local stream = make_token_stream(tokens)

  -- Parse the entire program as a list of statements
  local statements = {}
  while not stream.eof() do
    local stmt, err = parse_statement(stream)
    if not stmt then
      return nil, err
    end
    table.insert(statements, stmt)
  end

  return { type = "Program", body = statements }
end

-- ============================================================================
-- STATEMENT PARSERS
-- ============================================================================

--- Parse a single statement.
-- @param stream Token stream
-- @return statement (table) AST node for the statement
-- @return err (string) Error message if parsing failed
function parse_statement(stream)
  -- let/const variable declaration
  if stream.is(TOKEN.LET) or stream.is(TOKEN.CONST) then
    return parse_variable_declaration(stream)
  -- if statement
  elseif stream.is(TOKEN.IF) then
    return parse_if_statement(stream)
  -- while statement
  elseif stream.is(TOKEN.WHILE) then
    return parse_while_statement(stream)
  -- for...of statement
  elseif stream.is(TOKEN.FOR) then
    return parse_for_of_statement(stream)
  -- throw statement
  elseif stream.is(TOKEN.THROW) then
    return parse_throw_statement(stream)
  -- try statement
  elseif stream.is(TOKEN.TRY) then
    return parse_try_statement(stream)
  -- function declaration
  elseif stream.is(TOKEN.FUNCTION) then
    return parse_function_declaration(stream)
  -- return statement
  elseif stream.is(TOKEN.RETURN) then
    return parse_return_statement(stream)
  -- Block statement (starts with {)
  elseif stream.is(TOKEN.LBRACE) then
    return parse_block_statement(stream)
  -- Expression statement (everything else)
  else
    local expr, err = parse_expression(stream)
    if not expr then
      return nil, err
    end
    -- Check for semicolon
    if stream.is(TOKEN.SEMICOLON) then
      stream.advance()
    end
    return expression_statement(expr)
  end
end

--- Parse a block statement: { ... }
function parse_block_statement(stream)
  stream.consume(TOKEN.LBRACE)
  local body = {}
  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    local stmt, err = parse_statement(stream)
    if not stmt then
      return nil, err
    end
    table.insert(body, stmt)
  end
  stream.consume(TOKEN.RBRACE)
  return block_statement(body)
end

--- Parse variable declaration: let x = 1; const y = 2;
function parse_variable_declaration(stream)
  local kind_token = stream.peek()
  local kind
  if kind_token.type == TOKEN.LET then
    stream.advance()
    kind = "let"
  elseif kind_token.type == TOKEN.CONST then
    stream.advance()
    kind = "const"
  else
    stream.consume(TOKEN.LET)
    kind = "let"
  end

  local declarations = {}
  repeat
    local decl = parse_variable_declarator(stream)
    if not decl then return nil, "Expected variable declarator" end
    table.insert(declarations, decl)
  until not stream.is(TOKEN.COMMA)

  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end

  return variable_declaration(kind, declarations)
end

--- Parse variable declarator: x = 1
function parse_variable_declarator(stream)
  local token = stream.consume(TOKEN.IDENTIFIER)
  local name = identifier(token.value, token)

  local init = nil
  if stream.is(TOKEN.ASSIGN) then
    stream.advance()
    init, _ = parse_expression(stream)
    if not init then return nil, "Expected initializer" end
  end

  return variable_declarator(name, init)
end

--- Parse if statement: if (test) consequent [else alternate]
function parse_if_statement(stream)
  stream.consume(TOKEN.IF)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  if not test then return nil, "Expected expression" end
  stream.consume(TOKEN.RPAREN)

  local consequent = parse_statement(stream)

  local alternate = nil
  if stream.is(TOKEN.ELSE) then
    stream.advance()
    alternate = parse_statement(stream)
  end

  return if_statement(test, consequent, alternate)
end

--- Parse while statement: while (test) body
function parse_while_statement(stream)
  stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  if not test then return nil, "Expected expression" end
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return while_statement(test, body)
end

--- Parse for...of statement: for (left of right) body
function parse_for_of_statement(stream)
  stream.consume(TOKEN.FOR)
  stream.consume(TOKEN.LPAREN)

  local left
  if stream.is(TOKEN.LET) or stream.is(TOKEN.CONST) then
    left = parse_variable_declaration(stream)
  else
    left = parse_expression(stream)
  end

  stream.consume(TOKEN.OF)
  local right = parse_expression(stream)
  if not right then return nil, "Expected expression" end
  stream.consume(TOKEN.RPAREN)

  local body = parse_statement(stream)
  return for_of_statement(left, right, body)
end

--- Parse throw statement: throw expression;
function parse_throw_statement(stream)
  stream.consume(TOKEN.THROW)
  local argument = parse_expression(stream)
  if not argument then return nil, "Expected expression" end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return throw_statement(argument)
end

--- Parse try statement: try block catch (param) body
function parse_try_statement(stream)
  stream.consume(TOKEN.TRY)
  local block = parse_block_statement(stream)

  local handler = nil
  if stream.is(TOKEN.CATCH) then
    stream.advance()
    stream.consume(TOKEN.LPAREN)
    local param = identifier(stream.consume(TOKEN.IDENTIFIER).value)
    stream.consume(TOKEN.RPAREN)
    local catch_body = parse_block_statement(stream)
    handler = catch_clause(param, catch_body)
  end

  return try_statement(block, handler)
end

--- Parse function declaration: function name(params) { body }
function parse_function_declaration(stream)
  stream.consume(TOKEN.FUNCTION)
  local name_token = stream.consume(TOKEN.IDENTIFIER)
  local name = name_token.value

  stream.consume(TOKEN.LPAREN)
  local params = parse_parameters(stream)
  stream.consume(TOKEN.RPAREN)

  local body = parse_block_statement(stream)
  return function_declaration(name, params, body)
end

--- Parse return statement: return expression?;
function parse_return_statement(stream)
  stream.consume(TOKEN.RETURN)
  local argument = nil
  if not stream.is(TOKEN.SEMICOLON) and not stream.is(TOKEN.RBRACE) then
    argument = parse_expression(stream)
  end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return return_statement(argument)
end

-- Helper to parse function parameters
function parse_parameters(stream)
  local params = {}
  if not stream.is(TOKEN.RPAREN) then
    repeat
      local param_token = stream.consume(TOKEN.IDENTIFIER)
      table.insert(params, identifier(param_token.value, param_token))
    until not stream.is(TOKEN.COMMA)
  end
  return params
end

-- ============================================================================
-- EXPRESSION PARSERS
-- ============================================================================

-- Operator precedence levels (higher = binds tighter)
local PRECEDENCE = {
  [TOKEN.NOT] = 6,
  [TOKEN.STAR] = 5,
  [TOKEN.SLASH] = 5,
  [TOKEN.PERCENT] = 5,
  [TOKEN.PLUS] = 4,
  [TOKEN.MINUS] = 4,
  [TOKEN.EQ] = 3,
  [TOKEN.NEQ] = 3,
  [TOKEN.LT] = 3,
  [TOKEN.GT] = 3,
  [TOKEN.LTE] = 3,
  [TOKEN.GTE] = 3,
  [TOKEN.AND] = 2,
  [TOKEN.OR] = 1,
  [TOKEN.ASSIGN] = 0.5,
}

--- Parse an expression, handling operator precedence.
-- Uses Pratt parsing (top-down operator precedence parsing)
function parse_expression(stream)
  return parse_binary_expression(stream, 0)
end

--- Parse binary expressions with precedence climbing
-- @param stream Token stream
-- @param min_precedence Minimum precedence level to parse at
function parse_binary_expression(stream, min_precedence)
  local left = parse_unary_expression(stream)
  if not left then return nil end

  while true do
    local op_token = stream.peek()
    local op = op_token.type
    local precedence = PRECEDENCE[op]

    if not precedence or precedence < min_precedence then
      break
    end

    -- Special case: assignment is right-associative, others are left
    if op == TOKEN.ASSIGN then
      stream.advance()
      local right = parse_expression(stream)
      left = binary_expression("=", left, right)
    else
      stream.advance()
      -- For right-associative operators, use precedence - 1
      -- For left-associative, use precedence
      local next_min = op == TOKEN.ASSIGN and precedence - 1 or precedence + 1
      local right = parse_binary_expression(stream, next_min)
      if not right then return nil end
      left = binary_expression(op, left, right)
    end
  end

  return left
end

--- Parse unary expressions: !expr, -expr
function parse_unary_expression(stream)
  if stream.is(TOKEN.NOT) or stream.is(TOKEN.MINUS) then
    local op_token = stream.advance()
    local op = op_token.type
    local argument = parse_unary_expression(stream)
    if not argument then return nil end
    return unary_expression(op == TOKEN.NOT and "!" or "-", argument)
  end
  return parse_primary_expression(stream)
end

--- Parse primary expressions (literals, identifiers, parenthesized, etc.)
function parse_primary_expression(stream)
  local token = stream.peek()

  -- Literals
  if stream.is(TOKEN.NUMBER) then
    stream.advance()
    return number_literal(token.value, token)
  elseif stream.is(TOKEN.STRING) then
    stream.advance()
    return string_literal(token.value, token)
  elseif stream.is(TOKEN.BOOLEAN) then
    stream.advance()
    return boolean_literal(token.value, token)
  elseif stream.is(TOKEN.NULL) then
    stream.advance()
    return null_literal(token)
  -- Identifier (could be variable reference or function call)
  elseif stream.is(TOKEN.IDENTIFIER) then
    return parse_identifier_or_call(stream)
  -- Parenthesized expression (could be followed by => for arrow function)
  elseif stream.is(TOKEN.LPAREN) then
    -- Look ahead to check if this is an arrow function: (params) =>
    -- We need to find the matching ) and check if => follows
    local depth = 1
    local n = 0
    local found_arrow = false
    
    while true do
      local t = stream.peek_n(n + 1)
      if not t then break end
      if t.type == TOKEN.LPAREN then depth = depth + 1
      elseif t.type == TOKEN.RPAREN then depth = depth - 1
      end
      if depth == 0 then
        -- Found matching ), check next token
        if stream.peek_n(n + 2) and stream.peek_n(n + 2).type == TOKEN.ARROW then
          found_arrow = true
        end
        break
      end
      n = n + 1
    end
    
    if found_arrow then
      -- It's an arrow function
      stream.advance() -- consume (
      local params = {}
      if not stream.is(TOKEN.RPAREN) then
        repeat
          if stream.is(TOKEN.IDENTIFIER) then
            table.insert(params, identifier(stream.advance().value))
          else
            return nil, "Arrow function parameters must be identifiers"
          end
        until not stream.is(TOKEN.COMMA)
      end
      stream.consume(TOKEN.RPAREN)
      stream.consume(TOKEN.ARROW)
      local body = parse_arrow_function_body(stream)
      return arrow_function_expression(params, body)
    else
      -- Regular parenthesized expression
      stream.advance()
      local expr = parse_expression(stream)
      stream.consume(TOKEN.RPAREN)
      return expr
    end
  -- Array literal
  elseif stream.is(TOKEN.LBRACKET) then
    return parse_array_literal(stream)
  -- Object literal
  elseif stream.is(TOKEN.LBRACE) then
    return parse_object_literal(stream)
  -- Function expression
  elseif stream.is(TOKEN.FUNCTION) then
    return parse_function_expression(stream)
  -- Arrow function without parentheses: x => x + 1
  elseif stream.is(TOKEN.ARROW) then
    return nil, "Unexpected arrow token"
  else
    return nil, string.format("Unexpected token %s at line %d, col %d",
      token.type, token.line, token.col)
  end
end

--- Parse arrow function body (can be expression or block)
function parse_arrow_function_body(stream)
  if stream.is(TOKEN.LBRACE) then
    return parse_block_statement(stream)
  else
    -- Expression body - parse as expression statement
    local expr = parse_expression(stream)
    return block_statement({ expression_statement(expr) })
  end
end

--- Parse identifier which might be followed by call, member access, or arrow function
function parse_identifier_or_call(stream)
  local token = stream.consume(TOKEN.IDENTIFIER)
  local expr = identifier(token.value, token)

  -- Check for arrow function without parens: x => ...
  if stream.is(TOKEN.ARROW) then
    stream.advance()
    local body = parse_arrow_function_body(stream)
    return arrow_function_expression({expr}, body)
  end

  while true do
    -- Member access: .property or [property]
    if stream.is(TOKEN.DOT) then
      stream.advance()
      local prop_token = stream.consume(TOKEN.IDENTIFIER)
      expr = member_expression(expr, identifier(prop_token.value, prop_token), false)
      -- After member access, check for => (arrow function)
      if stream.is(TOKEN.ARROW) then
        stream.advance()
        local body = parse_arrow_function_body(stream)
        return arrow_function_expression({expr}, body)
      end
    elseif stream.is(TOKEN.LBRACKET) then
      stream.advance()
      local prop = parse_expression(stream)
      stream.consume(TOKEN.RBRACKET)
      expr = member_expression(expr, prop, true)
      -- After computed member access, check for =>
      if stream.is(TOKEN.ARROW) then
        stream.advance()
        local body = parse_arrow_function_body(stream)
        return arrow_function_expression({expr}, body)
      end
    -- Call expression: (args)
    elseif stream.is(TOKEN.LPAREN) then
      expr = parse_call_expression(stream, expr)
      -- After call, check for => (arrow function)
      if stream.is(TOKEN.ARROW) then
        stream.advance()
        local body = parse_arrow_function_body(stream)
        return arrow_function_expression({expr}, body)
      end
    else
      break
    end
  end

  return expr
end

--- Parse call expression: callee(args)
function parse_call_expression(stream, callee)
  stream.consume(TOKEN.LPAREN)
  local arguments = {}
  if not stream.is(TOKEN.RPAREN) then
    repeat
      local arg = parse_expression(stream)
      if not arg then return nil end
      table.insert(arguments, arg)
    until not stream.is(TOKEN.COMMA)
  end
  stream.consume(TOKEN.RPAREN)

  -- Handle chained calls: obj.method().another()
  local expr = call_expression(callee, arguments)

  while stream.is(TOKEN.DOT) or stream.is(TOKEN.LBRACKET) or stream.is(TOKEN.LPAREN) do
    if stream.is(TOKEN.DOT) then
      stream.advance()
      local prop_token = stream.consume(TOKEN.IDENTIFIER)
      expr = member_expression(expr, identifier(prop_token.value, prop_token), false)
    elseif stream.is(TOKEN.LBRACKET) then
      stream.advance()
      local prop = parse_expression(stream)
      stream.consume(TOKEN.RBRACKET)
      expr = member_expression(expr, prop, true)
    elseif stream.is(TOKEN.LPAREN) then
      stream.advance()
      local args = {}
      if not stream.is(TOKEN.RPAREN) then
        repeat
          local arg = parse_expression(stream)
          if not arg then return nil end
          table.insert(args, arg)
        until not stream.is(TOKEN.COMMA)
      end
      stream.consume(TOKEN.RPAREN)
      expr = call_expression(expr, args)
    end
  end

  return expr
end

--- Parse array literal: [element, element, ...]
function parse_array_literal(stream)
  stream.consume(TOKEN.LBRACKET)
  local elements = {}
  if not stream.is(TOKEN.RBRACKET) then
    repeat
      local element = parse_expression(stream)
      if not element then return nil end
      table.insert(elements, element)
    until not stream.is(TOKEN.COMMA)
  end
  stream.consume(TOKEN.RBRACKET)
  return array_expression(elements)
end

--- Parse object literal: { key: value, key: value, ... }
function parse_object_literal(stream)
  stream.consume(TOKEN.LBRACE)
  local properties = {}
  if not stream.is(TOKEN.RBRACE) then
    repeat
      local key
      if stream.is(TOKEN.IDENTIFIER) then
        local key_token = stream.advance()
        key = identifier(key_token.value, key_token)
      elseif stream.is(TOKEN.STRING) then
        local key_token = stream.advance()
        key = string_literal(key_token.value, key_token)
      else
        return nil, "Expected property key"
      end

      stream.consume(TOKEN.COLON)
      local value = parse_expression(stream)
      if not value then return nil end

      table.insert(properties, property(key, value, false))
    until not stream.is(TOKEN.COMMA)
  end
  stream.consume(TOKEN.RBRACE)
  return object_expression(properties)
end

--- Parse function expression: function(params) { body }
function parse_function_expression(stream)
  stream.consume(TOKEN.FUNCTION)

  -- Function expressions can be anonymous
  local name = nil
  -- Note: In JS, function expressions can have a name: function foo() {}
  -- We check if next token is an identifier
  if stream.is(TOKEN.IDENTIFIER) then
    local name_token = stream.peek_n(2)
    if name_token and name_token.type == TOKEN.LPAREN then
      -- It's a name, not a parameter
      local id_token = stream.advance()
      name = id_token.value
    end
  end

  stream.consume(TOKEN.LPAREN)
  local params = parse_parameters(stream)
  stream.consume(TOKEN.RPAREN)

  local body = parse_block_statement(stream)

  if name then
    -- Named function expression
    return function_declaration(name, params, body)
  else
    return function_expression(params, body)
  end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return ljs
