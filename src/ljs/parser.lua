-- ljs.parser — JavaScript subset → Lua table AST.
--
-- Two-phase pipeline: tokenize(source) → parse(tokens) → AST.
-- Pure parser — knows nothing about Lua. No external dependencies.
-- All errors are ParseError tables {message, line, col} with __tostring metamethod,
-- thrown via error()/pcall(). Public API catches and returns nil, ParseError.
--
-- Supported: let/const/var, functions, arrows, classes (extends/super/static),
-- objects, arrays, all arithmetic/comparison/logical/bitwise/assignment ops, new,
-- typeof, delete, instanceof, in, if/else, while, do...while, for...of/in/(;;),
-- switch/case, throw/try/catch/finally, this, console.log, comments.
--
-- Rejected (parse error): async/await, == (use ===), regex literals.
--
-- Usage:
--   local parser = require("ljs.parser")
--   local ast, err = parser.parse("let x = 42; console.log(x);")
--   if not ast then print(err) end

local M = {}

-- ============================================================================
-- TOKEN TYPES
-- ============================================================================
-- Each constant maps to a string used as token.type throughout the tokenizer
-- and parser. String values match the JS source text for operators/keywords.

local TOKEN = {
  EOF = "EOF",
  NUMBER = "Number",
  STRING = "String",
  BOOLEAN = "Boolean",
  NULL = "Null",
  IDENTIFIER = "Identifier",

  -- Declaration keywords
  LET = "let",
  CONST = "const",
  FUNCTION = "function",
  -- Control flow keywords
  IF = "if",
  ELSE = "else",
  DO = "do",
  WHILE = "while",
  FOR = "for",
  OF = "of",
  IN = "in",
  SWITCH = "switch",
  CASE = "case",
  DEFAULT = "default",
  BREAK = "break",
  CONTINUE = "continue",
  THROW = "throw",
  TRY = "try",
  CATCH = "catch",
  FINALLY = "finally",
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
  QUESTION = "?",

  -- Arithmetic
  PLUS = "+",
  MINUS = "-",
  STAR = "*",
  STARSTAR = "**",
  SLASH = "/",
  PERCENT = "%",
  -- Comparison
  EQ = "===",
  NEQ = "!==",
  LT = "<",
  GT = ">",
  LTE = "<=",
  GTE = ">=",
  -- Logical
  AND = "&&",
  OR = "||",
  -- Bitwise binary
  BITWISE_AND = "&",
  BITWISE_OR = "|",
  BITWISE_XOR = "^",
  LEFT_SHIFT = "<<",
  RIGHT_SHIFT = ">>",
  UNSIGNED_RIGHT_SHIFT = ">>>",
  -- Assignment
  ASSIGN = "=",
  -- Compound assignment
  PLUS_ASSIGN = "+=",
  MINUS_ASSIGN = "-=",
  STAR_ASSIGN = "*=",
  STARSTAR_ASSIGN = "**=",
  SLASH_ASSIGN = "/=",
  PERCENT_ASSIGN = "%=",
  BITWISE_AND_ASSIGN = "&=",
  BITWISE_OR_ASSIGN = "|=",
  BITWISE_XOR_ASSIGN = "^=",
  LEFT_SHIFT_ASSIGN = "<<=",
  RIGHT_SHIFT_ASSIGN = ">>=",
  UNSIGNED_RIGHT_SHIFT_ASSIGN = ">>>=",
  -- Unary
  NOT = "!",
  TILDE = "~",
  -- Update
  INCREMENT = "++",
  DECREMENT = "--",
  -- Arrow function
  ARROW = "=>",
  NEW = "new",
  CLASS = "class",
  EXTENDS = "extends",
  SUPER = "super",
  STATIC = "static",

  UNDEFINED = "Undefined",
  DELETE = "delete",
  -- Error-triggering keywords: tokenized normally but rejected by the parser
  THIS = "this",
  ASYNC = "async",
  AWAIT = "await",
  TYPEOF = "typeof",
  INSTANCEOF = "instanceof",
}

M.TOKEN = TOKEN

-- Maps keyword strings to their token type. Looked up during tokenization
-- to distinguish keywords from plain identifiers. "var" maps to TOKEN.LET
-- so it's treated identically to let in the parser.
local KEYWORDS = {
  ["let"] = TOKEN.LET,
  ["const"] = TOKEN.CONST,
  ["function"] = TOKEN.FUNCTION,
  ["if"] = TOKEN.IF,
  ["else"] = TOKEN.ELSE,
  ["do"] = TOKEN.DO,
  ["while"] = TOKEN.WHILE,
  ["for"] = TOKEN.FOR,
  ["of"] = TOKEN.OF,
  ["in"] = TOKEN.IN,
  ["switch"] = TOKEN.SWITCH,
  ["case"] = TOKEN.CASE,
  ["default"] = TOKEN.DEFAULT,
  ["break"] = TOKEN.BREAK,
  ["continue"] = TOKEN.CONTINUE,
  ["throw"] = TOKEN.THROW,
  ["try"] = TOKEN.TRY,
  ["catch"] = TOKEN.CATCH,
  ["finally"] = TOKEN.FINALLY,
  ["return"] = TOKEN.RETURN,
  ["true"] = TOKEN.BOOLEAN,
  ["false"] = TOKEN.BOOLEAN,
  ["null"] = TOKEN.NULL,
  ["undefined"] = TOKEN.UNDEFINED,
  ["var"] = TOKEN.LET,
  ["delete"] = TOKEN.DELETE,
  ["this"] = TOKEN.THIS,
  ["async"] = TOKEN.ASYNC,
  ["await"] = TOKEN.AWAIT,
  ["typeof"] = TOKEN.TYPEOF,
  ["instanceof"] = TOKEN.INSTANCEOF,
  ["new"] = TOKEN.NEW,
  ["class"] = TOKEN.CLASS,
  ["extends"] = TOKEN.EXTENDS,
  ["super"] = TOKEN.SUPER,
  ["static"] = TOKEN.STATIC,
}

-- Reverse set of all unique token types produced by KEYWORDS.
-- Used by is_property_name() to accept keywords as property names (obj.return, {class: 1}).
local KEYWORD_TOKEN_TYPES = {}
for _, tok_type in pairs(KEYWORDS) do
  KEYWORD_TOKEN_TYPES[tok_type] = true
end

-- ============================================================================
-- PARSE ERROR
-- ============================================================================

local ParseError = {}
ParseError.__index = ParseError

function ParseError:__tostring()
  return self.message .. " at line " .. self.line .. ", col " .. self.col
end

--- Create a ParseError table without throwing.
-- @param message (string) Human-readable error description
-- @param line (number) 1-based source line
-- @param col (number) 1-based source column
-- @return table ParseError with __tostring metamethod
local function make_parse_error(message, line, col)
  return setmetatable({ message = message, line = line, col = col }, ParseError)
end

--- Throw a ParseError via error() at level 0 (avoids injecting this frame into traceback).
-- @param message (string) Human-readable error description
-- @param line (number) 1-based source line
-- @param col (number) 1-based source column
local function parse_error(message, line, col)
  error(make_parse_error(message, line, col), 0)
end

--- Check metatable identity to distinguish ParseError from other error types.
-- @param val (any) Value to check
-- @return boolean
local function is_parse_error(val)
  return getmetatable(val) == ParseError
end

-- ============================================================================
-- TOKENIZER
-- ============================================================================
-- Converts source string into an array of tokens.
-- Each token is {type, value, line, col} where:
--   - value is present for identifiers/keywords (string), numbers (number),
--     booleans (true/false), strings (unescaped string). Absent for punctuation.
--   - line/col are 1-based source positions.
-- Returns: tokens array on success, nil + ParseError on failure.

--- Tokenize JavaScript source code into a list of tokens.
-- @param source (string) The JavaScript source code to tokenize
-- @return tokens (table|nil) Array of token tables, or nil on error
-- @return err (table|nil) ParseError {message, line, col} if tokenization failed
local function tokenize(source)
  local tokens = {}
  local pos = 1
  local line = 1
  local col = 1
  local len = #source

  --- @return string|nil
  local function current()
    return pos <= len and source:sub(pos, pos) or nil
  end

  -- Returns n characters starting at current position, or nil if past end.
  local function lookahead(n)
    return pos + n - 1 <= len and source:sub(pos, pos + n - 1) or nil
  end

  -- Moves position forward by n characters, tracking line/col.
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

  local function skip_whitespace()
    while true do
      local c = current()
      if not c then
        break
      end
      if c:match("%s") then
        advance()
      else
        break
      end
    end
  end

  -- Returns true if a // comment was consumed.
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

  -- Returns true if a /* */ comment was consumed, false + error if unterminated.
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
      return false, make_parse_error("Unterminated multi-line comment", line, col)
    end
    return false
  end

  -- Skips all whitespace and comments, looping because comments can be
  -- adjacent to each other or to whitespace.
  local function skip_trivia()
    skip_whitespace()
    while current() do
      if skip_single_line_comment() then
        skip_whitespace()
      else
        local ok, err = skip_multi_line_comment()
        if not ok then
          if err then
            return false, err
          end
          break
        end
        skip_whitespace()
      end
    end
    return true
  end

  local function make_token(type, value, p_line, p_col)
    return {
      type = type,
      value = value,
      line = p_line or line,
      col = p_col or col,
    }
  end

  local function is_digit(c)
    return c:match("%d")
  end

  local function is_alpha(c)
    return c:match("[%a_]")
  end

  -- %w matches [0-9a-zA-Z] but NOT underscore, so we add it explicitly.
  local function is_alnum(c)
    return c:match("[%w_]")
  end

  while pos <= len do
    local ok, err = skip_trivia()
    if not ok then
      return nil, err
    end
    if pos > len then
      break
    end

    local c = current()

    if not c then
      table.insert(tokens, make_token(TOKEN.EOF))
      break
    end

    -- Identifiers and keywords: start with letter/underscore, continue with
    -- alnum+underscore. Look up the resulting text in KEYWORDS to distinguish
    -- keywords from plain identifiers. true/false/null get literal values.
    if is_alpha(c) then
      local start_pos = pos
      local start_col = col
      while current() and is_alnum(current()) do
        advance()
      end
      local text = source:sub(start_pos, pos - 1)
      local token_type = KEYWORDS[text] or TOKEN.IDENTIFIER
      if token_type == TOKEN.BOOLEAN then
        table.insert(tokens, make_token(TOKEN.BOOLEAN, text == "true", line, start_col))
      elseif token_type == TOKEN.NULL then
        table.insert(tokens, make_token(TOKEN.NULL, nil, line, start_col))
      elseif token_type == TOKEN.UNDEFINED then
        table.insert(tokens, make_token(TOKEN.UNDEFINED, nil, line, start_col))
      else
        table.insert(tokens, make_token(token_type, text, line, start_col))
      end

    -- Numbers: integer and float. Dots only start fractional part if followed
    -- by a digit (otherwise it's a member access like obj.length).
    -- Hex literals: 0x or 0X followed by hex digits.
    elseif is_digit(c) then
      local start_pos = pos
      local start_col = col
      if c == "0" and (lookahead(2) == "0x" or lookahead(2) == "0X") then
        advance()
        advance()
        if not current() or not current():match("%x") then
          return nil, make_parse_error("Invalid hex literal", line, start_col)
        end
        while current() and current():match("%x") do
          advance()
        end
      else
        while current() and is_digit(current()) do
          advance()
        end
        if current() == "." and is_digit(lookahead(2)) then
          advance()
          while current() and is_digit(current()) do
            advance()
          end
        end
      end
      local text = source:sub(start_pos, pos - 1)
      local num = tonumber(text)
      if not num then
        return nil, make_parse_error("Invalid number literal", line, start_col)
      end
      table.insert(tokens, make_token(TOKEN.NUMBER, num, line, start_col))

    -- Strings: double or single quoted with escape sequences.
    -- Newlines inside strings are errors (no template literals).
    -- found_closing tracks whether we exited via closing quote vs end-of-input.
    elseif c == '"' or c == "'" then
      local quote = c
      local start_pos = pos
      local start_col = col
      advance()
      local chars = {}
      local escaped = false
      local found_closing = false
      while current() do
        local ch = current()
        if escaped then
          if ch == "n" then
            ch = "\n"
          elseif ch == "r" then
            ch = "\r"
          elseif ch == "t" then
            ch = "\t"
          elseif ch == "b" then
            ch = "\b"
          elseif ch == "f" then
            ch = "\f"
          elseif ch == "\\" then
            ch = "\\"
          elseif ch == '"' then
            ch = '"'
          elseif ch == "'" then
            ch = "'"
          else
            return nil, make_parse_error("Invalid escape sequence", line, col)
          end
          table.insert(chars, ch)
          escaped = false
          advance()
        elseif ch == "\\" then
          escaped = true
          advance()
        elseif ch == quote then
          advance()
          found_closing = true
          break
        elseif ch == "\n" then
          return nil, make_parse_error("Unterminated string literal", line, start_col)
        else
          table.insert(chars, ch)
          advance()
        end
      end
      if not found_closing then
        return nil, make_parse_error("Unterminated string literal", line, start_col)
      end
      local str = table.concat(chars, "")
      table.insert(tokens, make_token(TOKEN.STRING, str, line, start_col))

    -- Punctuation and operators.
    -- Order matters: multi-char tokens must be checked before single-char
    -- prefixes (e.g. => before =, === before == before =).
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
    elseif c == "?" then
      table.insert(tokens, make_token(TOKEN.QUESTION))
      advance()
    elseif c == "+" then
      if lookahead(2) == "++" then
        table.insert(tokens, make_token(TOKEN.INCREMENT))
        advance(2)
      elseif lookahead(2) == "+=" then
        table.insert(tokens, make_token(TOKEN.PLUS_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.PLUS))
        advance()
      end
    elseif c == "-" then
      if lookahead(2) == "--" then
        table.insert(tokens, make_token(TOKEN.DECREMENT))
        advance(2)
      elseif lookahead(2) == "-=" then
        table.insert(tokens, make_token(TOKEN.MINUS_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.MINUS))
        advance()
      end
    elseif c == "*" then
      if lookahead(3) == "**=" then
        table.insert(tokens, make_token(TOKEN.STARSTAR_ASSIGN))
        advance(3)
      elseif lookahead(2) == "**" then
        table.insert(tokens, make_token(TOKEN.STARSTAR))
        advance(2)
      elseif lookahead(2) == "*=" then
        table.insert(tokens, make_token(TOKEN.STAR_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.STAR))
        advance()
      end
    elseif c == "/" then
      if lookahead(2) == "/=" then
        table.insert(tokens, make_token(TOKEN.SLASH_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.SLASH))
        advance()
      end
    elseif c == "%" then
      if lookahead(2) == "%=" then
        table.insert(tokens, make_token(TOKEN.PERCENT_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.PERCENT))
        advance()
      end
    -- = handler: must check => first (arrow), then ===, then reject ==,
    -- then fall through to plain assignment =.
    elseif c == "=" then
      if lookahead(2) == "=>" then
        table.insert(tokens, make_token(TOKEN.ARROW))
        advance(2)
      elseif lookahead(2) == "==" then
        if lookahead(3) == "===" then
          table.insert(tokens, make_token(TOKEN.EQ))
          advance(3)
        else
          return nil, make_parse_error("Use === instead of ==", line, col)
        end
      else
        table.insert(tokens, make_token(TOKEN.ASSIGN))
        advance()
      end
    -- ! handler: !== is the only multi-char form starting with !.
    -- Use source:sub instead of lookahead to get exact 3-char match.
    elseif c == "!" then
      if source:sub(pos, pos + 2) == "!==" then
        table.insert(tokens, make_token(TOKEN.NEQ))
        advance(3)
      else
        table.insert(tokens, make_token(TOKEN.NOT))
        advance()
      end
    elseif c == "~" then
      table.insert(tokens, make_token(TOKEN.TILDE))
      advance()
    elseif c == "^" then
      if lookahead(2) == "^=" then
        table.insert(tokens, make_token(TOKEN.BITWISE_XOR_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.BITWISE_XOR))
        advance()
      end
    elseif c == "<" then
      if source:sub(pos, pos + 2) == "<<=" then
        table.insert(tokens, make_token(TOKEN.LEFT_SHIFT_ASSIGN))
        advance(3)
      elseif lookahead(2) == "<<" then
        table.insert(tokens, make_token(TOKEN.LEFT_SHIFT))
        advance(2)
      elseif lookahead(2) == "<=" then
        table.insert(tokens, make_token(TOKEN.LTE))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.LT))
        advance()
      end
    elseif c == ">" then
      if source:sub(pos, pos + 3) == ">>>=" then
        table.insert(tokens, make_token(TOKEN.UNSIGNED_RIGHT_SHIFT_ASSIGN))
        advance(4)
      elseif source:sub(pos, pos + 2) == ">>>" then
        table.insert(tokens, make_token(TOKEN.UNSIGNED_RIGHT_SHIFT))
        advance(3)
      elseif source:sub(pos, pos + 2) == ">>=" then
        table.insert(tokens, make_token(TOKEN.RIGHT_SHIFT_ASSIGN))
        advance(3)
      elseif lookahead(2) == ">>" then
        table.insert(tokens, make_token(TOKEN.RIGHT_SHIFT))
        advance(2)
      elseif lookahead(2) == ">=" then
        table.insert(tokens, make_token(TOKEN.GTE))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.GT))
        advance()
      end
    -- & and | are tokenized as both logical (&&, ||) and bitwise (lone &, |) ops.
    elseif c == "&" then
      if lookahead(2) == "&&" then
        table.insert(tokens, make_token(TOKEN.AND))
        advance(2)
      elseif lookahead(2) == "&=" then
        table.insert(tokens, make_token(TOKEN.BITWISE_AND_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.BITWISE_AND))
        advance()
      end
    elseif c == "|" then
      if lookahead(2) == "||" then
        table.insert(tokens, make_token(TOKEN.OR))
        advance(2)
      elseif lookahead(2) == "|=" then
        table.insert(tokens, make_token(TOKEN.BITWISE_OR_ASSIGN))
        advance(2)
      else
        table.insert(tokens, make_token(TOKEN.BITWISE_OR))
        advance()
      end
    else
      return nil, make_parse_error(string.format("Unexpected character '%s'", c), line, col)
    end
  end

  -- Guarantee the stream always ends with EOF.
  if #tokens == 0 or tokens[#tokens].type ~= TOKEN.EOF then
    table.insert(tokens, make_token(TOKEN.EOF))
  end

  return tokens
end

M.tokenize = tokenize

-- ============================================================================
-- TOKEN STREAM CONSUMER
-- ============================================================================
-- Wraps the token array with cursor-based read operations used by the parser.
-- The stream never goes backwards — it's a forward-only cursor.

--- Create a token stream from a list of tokens.
-- @param tokens (table) Array of token tables from tokenize()
-- @return stream (table) Token stream with peek/advance/expect/consume/is/eof methods
local function make_token_stream(tokens)
  local pos = 1
  local len = #tokens

  local stream = {}

  --- Peek at the current token without consuming it.
  -- Falls back to the last token (EOF) if past the end.
  -- @return token (table) The current token
  function stream.peek()
    return tokens[pos] or tokens[len]
  end

  --- Peek at the token n positions ahead (1 = current, 2 = next, etc.)
  -- @param n (number) Offset from current position (default 1)
  -- @return token (table) The token at that offset, or EOF
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
  -- @param ... Expected token types (varargs)
  -- @return boolean True if current token type matches any
  function stream.is_any(...)
    local expected = { ... }
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

  --- Consume the current token if it matches the expected type (soft match).
  -- @param expected (string) Token type to expect
  -- @return token (table|nil) The consumed token, or nil if mismatch
  function stream.expect(expected)
    if stream.is(expected) then
      return stream.advance()
    end
    return nil
  end

  --- Consume the current token and assert it matches (hard match).
  -- Throws a Lua error with position info on mismatch.
  -- @param expected (string) Token type to expect
  -- @return token (table) The consumed token
  function stream.consume(expected)
    local token = stream.expect(expected)
    if not token then
      local current = stream.peek()
      parse_error(
        string.format("Expected %s, got %s", expected, current.type),
        current.line,
        current.col
      )
    end
    return token
  end

  --- Check if we've reached the end of the token stream.
  -- @return boolean True if at EOF
  function stream.eof()
    return stream.peek().type == TOKEN.EOF
  end

  --- Check if current token can be an object/class property name.
  -- Accepts identifiers and all keywords (JS allows keywords as property names: obj.return).
  -- @return boolean
  function stream.is_property_name()
    local t = stream.peek().type
    return t == TOKEN.IDENTIFIER or KEYWORD_TOKEN_TYPES[t] ~= nil
  end

  --- Consume current token as a property name, erroring if not valid.
  -- @return (table) The consumed token
  function stream.consume_property_name()
    if not stream.is_property_name() then
      local current = stream.peek()
      parse_error(
        string.format("Expected property name, got %s", current.type),
        current.line,
        current.col
      )
    end
    return stream.advance()
  end

  return stream
end

M.make_token_stream = make_token_stream

-- ============================================================================
-- AST BUILDERS
-- ============================================================================
-- Factory functions for each AST node type. All return a table with a `type`
-- field. See AGENTS.md for the full AST specification.

--- @param name (string) Variable/parameter name
--- @return table {type="Identifier", name=name}
local function identifier(name, token)
  return { type = "Identifier", name = name, line = token.line, col = token.col }
end

--- @param value (number) Numeric value
--- @return table {type="NumberLiteral", value=value}
local function number_literal(value, token)
  return { type = "NumberLiteral", value = value, line = token.line, col = token.col }
end

--- @param value (string) Unescaped string content
--- @return table {type="StringLiteral", value=value}
local function string_literal(value, token)
  return { type = "StringLiteral", value = value, line = token.line, col = token.col }
end

--- @param value (boolean) true or false
--- @return table {type="BooleanLiteral", value=value}
local function boolean_literal(value, token)
  return { type = "BooleanLiteral", value = value, line = token.line, col = token.col }
end

--- @return table {type="NullLiteral"}
local function null_literal(token)
  return { type = "NullLiteral", line = token.line, col = token.col }
end

--- @return table {type="UndefinedLiteral"}
local function undefined_literal(token)
  return { type = "UndefinedLiteral", line = token.line, col = token.col }
end

--- @param operator (string) One of: + - * / % ** === !== < > <= >= && || in = += -= *= /= %= **= & | ^ << >> >>> &= |= ^= <<= >>= >>>=
--- @param left (table) Left-hand AST expression
--- @param right (table) Right-hand AST expression
--- @return table {type="BinaryExpression", operator, left, right}
local function binary_expression(operator, left, right, token)
  return {
    type = "BinaryExpression",
    operator = operator,
    left = left,
    right = right,
    line = token.line,
    col = token.col,
  }
end

--- @param operator (string) "!" or "-" or "~"
--- @param argument (table) The operand AST expression
--- @return table {type="UnaryExpression", operator, argument}
local function unary_expression(operator, argument, token)
  return {
    type = "UnaryExpression",
    operator = operator,
    argument = argument,
    line = token.line,
    col = token.col,
  }
end

--- @param expr (table) AST expression node
--- @return boolean
local function is_valid_update_target(expr)
  local t = expr.type
  if t == "Identifier" then
    return true
  elseif t == "MemberExpression" then
    return true
  end
  return false
end

--- @param expr (table) AST expression node
--- @param tok (table) The ++ or -- token
local function check_update_target(expr, tok)
  if not is_valid_update_target(expr) then
    parse_error(
      "Invalid update target: cannot use " .. tok.type .. " on this expression",
      tok.line,
      tok.col
    )
  end
end

--- @param operator (string) "++" or "--"
--- @param argument (table) The operand AST expression
--- @param prefix (boolean) true for prefix (++x), false for postfix (x++)
--- @return table {type="UpdateExpression", operator, argument, prefix}
local function update_expression(operator, argument, prefix, token)
  return {
    type = "UpdateExpression",
    operator = operator,
    argument = argument,
    prefix = prefix,
    line = token.line,
    col = token.col,
  }
end

--- @param argument (table) The operand AST expression
--- @return table {type="DeleteExpression", argument}
local function delete_expression(argument, token)
  return { type = "DeleteExpression", argument = argument, line = token.line, col = token.col }
end

--- @return table {type="ThisExpression"}
local function this_expression(token)
  return { type = "ThisExpression", line = token.line, col = token.col }
end

--- @param argument (table) The operand AST expression
--- @return table {type="TypeofExpression", argument}
local function typeof_expression(argument, token)
  return { type = "TypeofExpression", argument = argument, line = token.line, col = token.col }
end

--- @param callee (table) Constructor expression (Identifier or MemberExpression)
--- @param arguments (table) Array of argument expressions
--- @return table {type="NewExpression", callee, arguments}
local function new_expression(callee, arguments, token)
  return {
    type = "NewExpression",
    callee = callee,
    arguments = arguments,
    line = token.line,
    col = token.col,
  }
end

--- @param name (string) Class name (required for declarations)
--- @param superClass (table|nil) Parent class expression, or nil
--- @param body (table) Array of MethodDefinition nodes
--- @return table {type="ClassDeclaration", name, superClass, body}
local function class_declaration(name, superClass, body, token)
  return {
    type = "ClassDeclaration",
    name = name,
    superClass = superClass,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param name (string|nil) Optional class name (nil for anonymous)
--- @param superClass (table|nil) Parent class expression, or nil
--- @param body (table) Array of MethodDefinition nodes
--- @return table {type="ClassExpression", name, superClass, body}
local function class_expression(name, superClass, body, token)
  return {
    type = "ClassExpression",
    name = name,
    superClass = superClass,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param kind (string) "constructor" or "method"
--- @param key (table) Identifier or StringLiteral for the method name
--- @param value (table) FunctionExpression for the method body
--- @param static_flag (boolean) true for static methods
--- @return table {type="MethodDefinition", kind, key, value, static}
local function method_definition(kind, key, value, static_flag, token)
  return {
    type = "MethodDefinition",
    kind = kind,
    key = key,
    value = value,
    static = static_flag,
    line = token.line,
    col = token.col,
  }
end

--- @return table {type="SuperExpression"}
local function super_expression(token)
  return { type = "SuperExpression", line = token.line, col = token.col }
end

--- @param test (table) Condition expression
--- @param consequent (table) Expression if truthy
--- @param alternate (table) Expression if falsy
--- @return table {type="ConditionalExpression", test, consequent, alternate}
local function conditional_expression(test, consequent, alternate, token)
  return {
    type = "ConditionalExpression",
    test = test,
    consequent = consequent,
    alternate = alternate,
    line = token.line,
    col = token.col,
  }
end

--- @param callee (table) Expression being called
--- @param arguments (table) Array of argument expressions
--- @return table {type="CallExpression", callee, arguments}
local function call_expression(callee, arguments, token)
  return {
    type = "CallExpression",
    callee = callee,
    arguments = arguments,
    line = token.line,
    col = token.col,
  }
end

--- @param object (table) Object expression
--- @param property (table) Property expression (Identifier or computed expression)
--- @param computed (boolean) true for bracket notation obj[expr], false for dot notation obj.prop
--- @return table {type="MemberExpression", object, property, computed}
local function member_expression(object, property, computed, token)
  return {
    type = "MemberExpression",
    object = object,
    property = property,
    computed = computed,
    line = token.line,
    col = token.col,
  }
end

--- @param kind (string) "let" or "const"
--- @param declarations (table) Array of VariableDeclarator nodes
--- @return table {type="VariableDeclaration", kind, declarations}
local function variable_declaration(kind, declarations, token)
  return {
    type = "VariableDeclaration",
    kind = kind,
    declarations = declarations,
    line = token.line,
    col = token.col,
  }
end

--- @param name (table) Identifier node
--- @param init (table|nil) Initializer expression, or nil
--- @return table {type="VariableDeclarator", name, init}
local function variable_declarator(name, init, token)
  return {
    type = "VariableDeclarator",
    name = name,
    init = init,
    line = token.line,
    col = token.col,
  }
end

--- @param name (string) Function name
--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement node
--- @return table {type="FunctionDeclaration", name, params, body}
local function function_declaration(name, params, body, token)
  return {
    type = "FunctionDeclaration",
    name = name,
    params = params,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement node
--- @return table {type="FunctionExpression", params, body}
local function function_expression(params, body, token)
  return {
    type = "FunctionExpression",
    params = params,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- Arrow functions are desugared: expression bodies become BlockStatement
--- wrapping a single ExpressionStatement.
--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement (always, even for expression bodies)
--- @return table {type="ArrowFunctionExpression", params, body}
local function arrow_function_expression(params, body, token)
  return {
    type = "ArrowFunctionExpression",
    params = params,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param test (table) Condition expression
--- @param consequent (table) Statement to run if truthy
--- @param alternate (table|nil) else branch, or nil
--- @return table {type="IfStatement", test, consequent, alternate}
local function if_statement(test, consequent, alternate, token)
  return {
    type = "IfStatement",
    test = test,
    consequent = consequent,
    alternate = alternate,
    line = token.line,
    col = token.col,
  }
end

--- @param test (table) Condition expression
--- @param body (table) Statement to repeat
--- @return table {type="WhileStatement", test, body}
local function while_statement(test, body, token)
  return { type = "WhileStatement", test = test, body = body, line = token.line, col = token.col }
end

--- @param body (table) Statement to repeat
--- @param test (table) Condition expression
--- @return table {type="DoWhileStatement", body, test}
local function do_while_statement(body, test, token)
  return { type = "DoWhileStatement", body = body, test = test, line = token.line, col = token.col }
end

--- @param left (table) VariableDeclaration or expression (the loop variable)
--- @param right (table) Iterable expression
--- @param body (table) Statement to repeat
--- @return table {type="ForOfStatement", left, right, body}
local function for_of_statement(left, right, body, token)
  return {
    type = "ForOfStatement",
    left = left,
    right = right,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param left (table) VariableDeclaration or expression (the loop variable)
--- @param right (table) Object expression to iterate over
--- @param body (table) Statement to repeat
--- @return table {type="ForInStatement", left, right, body}
local function for_in_statement(left, right, body, token)
  return {
    type = "ForInStatement",
    left = left,
    right = right,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param init (table|nil) Initialization expression or VariableDeclaration
--- @param test (table|nil) Loop condition expression
--- @param update (table|nil) Update expression evaluated after each iteration
--- @param body (table) Statement to repeat
--- @return table {type="ForStatement", init, test, update, body}
local function for_statement(init, test, update, body, token)
  return {
    type = "ForStatement",
    init = init,
    test = test,
    update = update,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param body (table) Array of statement nodes
--- @return table {type="BlockStatement", body}
local function block_statement(body, token)
  return { type = "BlockStatement", body = body, line = token.line, col = token.col }
end

--- @param expression (table) The expression being evaluated for side effects
--- @return table {type="ExpressionStatement", expression}
local function expression_statement(expression, token)
  return {
    type = "ExpressionStatement",
    expression = expression,
    line = token.line,
    col = token.col,
  }
end

--- @param argument (table) The value to throw
--- @return table {type="ThrowStatement", argument}
local function throw_statement(argument, token)
  return { type = "ThrowStatement", argument = argument, line = token.line, col = token.col }
end

--- @param block (table) BlockStatement (the try body)
--- @param handler (table|nil) CatchClause node, or nil
--- @param finalizer (table|nil) BlockStatement for finally body, or nil
--- @return table {type="TryStatement", block, handler, finalizer}
local function try_statement(block, handler, finalizer, token)
  return {
    type = "TryStatement",
    block = block,
    handler = handler,
    finalizer = finalizer,
    line = token.line,
    col = token.col,
  }
end

--- @param param (table) Identifier node for the caught error
--- @param body (table) BlockStatement for catch body
--- @return table {type="CatchClause", param, body}
local function catch_clause(param, body, token)
  return { type = "CatchClause", param = param, body = body, line = token.line, col = token.col }
end

--- @param argument (table|nil) Return value expression, or nil for bare return
--- @return table {type="ReturnStatement", argument}
local function return_statement(argument, token)
  return { type = "ReturnStatement", argument = argument, line = token.line, col = token.col }
end

--- @param properties (table) Array of Property nodes
--- @return table {type="ObjectExpression", properties}
local function object_expression(properties, token)
  return { type = "ObjectExpression", properties = properties, line = token.line, col = token.col }
end

--- @param key (table) Identifier or StringLiteral node
--- @param value (table) Expression node
--- @param computed (boolean) true if key is a computed [expr] property
--- @return table {type="Property", key, value, computed}
local function property(key, value, computed, token)
  return {
    type = "Property",
    key = key,
    value = value,
    computed = computed or false,
    line = token.line,
    col = token.col,
  }
end

--- @param elements (table) Array of expression nodes
--- @return table {type="ArrayExpression", elements}
local function array_expression(elements, token)
  return { type = "ArrayExpression", elements = elements, line = token.line, col = token.col }
end

--- @param discriminant (table) Expression being matched against
--- @param cases (table) Array of SwitchCase nodes
--- @return table {type="SwitchStatement", discriminant, cases}
local function switch_statement(discriminant, cases, token)
  return {
    type = "SwitchStatement",
    discriminant = discriminant,
    cases = cases,
    line = token.line,
    col = token.col,
  }
end

--- @param test (table|nil) Case value expression, or nil for default
--- @param consequent (table) Array of statement nodes in this case
--- @return table {type="SwitchCase", test, consequent}
local function switch_case(test, consequent, token)
  return {
    type = "SwitchCase",
    test = test,
    consequent = consequent,
    line = token.line,
    col = token.col,
  }
end

--- @return table {type="BreakStatement"}
local function break_statement(token)
  return { type = "BreakStatement", line = token.line, col = token.col }
end

--- @return table {type="ContinueStatement"}
local function continue_statement(token)
  return { type = "ContinueStatement", line = token.line, col = token.col }
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
-- Forward declarations are required because Lua's local functions must be
-- declared before use, and many parse functions are mutually recursive.

local parse_switch_statement
local parse_break_statement
local parse_continue_statement
local parse_statement
local parse_block_statement
local parse_variable_declaration
local parse_variable_declarator
local parse_if_statement
local parse_while_statement
local parse_for_statement
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
local parse_postfix

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
      table.insert(stmts, parse_statement(stream))
    end
    return { type = "Program", body = stmts, line = 1, col = 1 }
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
      table.insert(stmts, parse_statement(stream))
    end
    return { type = "Program", body = stmts, line = 1, col = 1 }
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
function parse_statement(stream)
  if stream.is(TOKEN.LET) or stream.is(TOKEN.CONST) then
    return parse_variable_declaration(stream)
  elseif stream.is(TOKEN.IF) then
    return parse_if_statement(stream)
  elseif stream.is(TOKEN.WHILE) then
    return parse_while_statement(stream)
  elseif stream.is(TOKEN.DO) then
    return parse_do_while_statement(stream)
  elseif stream.is(TOKEN.FOR) then
    return parse_for_statement(stream)
  elseif stream.is(TOKEN.THROW) then
    return parse_throw_statement(stream)
  elseif stream.is(TOKEN.TRY) then
    return parse_try_statement(stream)
  elseif stream.is(TOKEN.FUNCTION) then
    return parse_function_declaration(stream)
  elseif stream.is(TOKEN.CLASS) then
    return parse_class_declaration(stream)
  elseif stream.is(TOKEN.RETURN) then
    return parse_return_statement(stream)
  elseif stream.is(TOKEN.SWITCH) then
    return parse_switch_statement(stream)
  elseif stream.is(TOKEN.BREAK) then
    return parse_break_statement(stream)
  elseif stream.is(TOKEN.CONTINUE) then
    return parse_continue_statement(stream)
  elseif stream.is(TOKEN.LBRACE) then
    return parse_block_statement(stream)
  else
    local banned_err = check_banned(stream)
    if banned_err then
      error(banned_err, 0)
    end
    local expr_token = stream.peek()
    local expr = parse_expression(stream)
    if stream.is(TOKEN.SEMICOLON) then
      stream.advance()
    end
    return expression_statement(expr, expr_token)
  end
end

--- Parse a block: { stmt1; stmt2; ... }
-- Consumes the opening and closing braces.
function parse_block_statement(stream)
  local lbrace = stream.consume(TOKEN.LBRACE)
  local body = {}
  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    table.insert(body, parse_statement(stream))
  end
  stream.consume(TOKEN.RBRACE)
  return block_statement(body, lbrace)
end

--- Parse variable declaration: let/const/var x = expr, y = expr;
-- "var" is treated as "let" (maps to TOKEN.LET in the tokenizer).
-- Supports multiple declarators separated by commas.
-- Semicolon is optional.
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' in initializer expressions
function parse_variable_declaration(stream, no_in)
  local kind_token = stream.peek()
  local kind
  if kind_token.type == TOKEN.LET then
    stream.advance()
    -- var and let both map to TOKEN.LET; normalize var -> "let"
    kind = "let"
  elseif kind_token.type == TOKEN.CONST then
    stream.advance()
    kind = "const"
  else
    stream.consume(TOKEN.LET)
    kind = "let"
  end

  local declarations = {}
  while true do
    local decl = parse_variable_declarator(stream, no_in)
    table.insert(declarations, decl)
    if not stream.is(TOKEN.COMMA) then
      break
    end
    stream.advance()
  end

  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end

  return variable_declaration(kind, declarations, kind_token)
end

--- Parse a single variable declarator: name or name = init
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' in initializer expression
function parse_variable_declarator(stream, no_in)
  local token = stream.consume(TOKEN.IDENTIFIER)
  local name = identifier(token.value, token)

  local init = nil
  if stream.is(TOKEN.ASSIGN) then
    stream.advance()
    init = parse_expression(stream, no_in)
  end

  return variable_declarator(name, init, token)
end

--- Parse if/else: if (test) consequent [else alternate]
-- The consequent and alternate are single statements (can be blocks).
function parse_if_statement(stream)
  local kw = stream.consume(TOKEN.IF)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)

  local consequent = parse_statement(stream)

  local alternate = nil
  if stream.is(TOKEN.ELSE) then
    stream.advance()
    alternate = parse_statement(stream)
  end

  return if_statement(test, consequent, alternate, kw)
end

--- Parse while: while (test) body
function parse_while_statement(stream)
  local kw = stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return while_statement(test, body, kw)
end

--- Parse do...while: do body while (test);
-- Body always executes at least once. Semicolon after is optional.
-- @param stream (table) Token stream
-- @return (table|nil) DoWhileStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_do_while_statement(stream)
  local kw = stream.consume(TOKEN.DO)
  local body = parse_statement(stream)
  stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return do_while_statement(body, test, kw)
end

--- Parse for statement: dispatches between for...of, for...in, and C-style for(;;).
function parse_for_statement(stream)
  local kw = stream.consume(TOKEN.FOR)
  stream.consume(TOKEN.LPAREN)

  if stream.is(TOKEN.SEMICOLON) then
    return parse_c_style_for(stream, nil, kw)
  end

  if stream.is(TOKEN.LET) or stream.is(TOKEN.CONST) then
    local decl = parse_variable_declaration(stream, true)

    if stream.is(TOKEN.OF) then
      return parse_for_of_from_left(stream, decl, kw)
    end

    if stream.is(TOKEN.IN) then
      return parse_for_in_from_left(stream, decl, kw)
    end

    return parse_c_style_for_from_test(stream, decl, kw)
  end

  local expr_token = stream.peek()
  local expr = parse_expression(stream, true)

  if stream.is(TOKEN.OF) then
    stream.consume(TOKEN.OF)
    local right = parse_expression(stream)
    stream.consume(TOKEN.RPAREN)
    local body = parse_statement(stream)
    return for_of_statement(expr, right, body, kw)
  end

  if stream.is(TOKEN.IN) then
    stream.consume(TOKEN.IN)
    local right = parse_expression(stream)
    stream.consume(TOKEN.RPAREN)
    local body = parse_statement(stream)
    return for_in_statement(expr, right, body, kw)
  end

  local init = expression_statement(expr, expr_token)
  stream.consume(TOKEN.SEMICOLON)
  return parse_c_style_for_from_test(stream, init, kw)
end

--- Parse C-style for loop starting from the first semicolon (no init clause).
-- @param stream (table) Token stream
-- @param init (table|nil) Initialization expression or nil
-- @return (table|nil) ForStatement AST node, or nil on error
function parse_c_style_for(stream, init, kw)
  stream.consume(TOKEN.SEMICOLON)
  return parse_c_style_for_from_test(stream, init, kw)
end

--- Parse C-style for loop test and update clauses after init has been consumed.
-- @param stream (table) Token stream
-- @param init (table|nil) Initialization expression or VariableDeclaration
-- @return (table|nil) ForStatement AST node, or nil on error
function parse_c_style_for_from_test(stream, init, kw)
  local test
  if not stream.is(TOKEN.SEMICOLON) then
    test = parse_expression(stream)
  end
  stream.consume(TOKEN.SEMICOLON)

  local update
  if not stream.is(TOKEN.RPAREN) then
    update = parse_expression(stream)
  end
  stream.consume(TOKEN.RPAREN)

  local body = parse_statement(stream)
  return for_statement(init, test, update, body, kw)
end

--- Parse for...of loop after the left-hand variable declaration has been consumed.
-- @param stream (table) Token stream
-- @param left (table) VariableDeclaration for the loop variable
-- @return (table|nil) ForOfStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_for_of_from_left(stream, left, kw)
  stream.consume(TOKEN.OF)
  local right = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return for_of_statement(left, right, body, kw)
end

--- Parse for...in loop after the left-hand variable declaration has been consumed.
-- Validates that there is exactly one declarator with no initializer.
-- @param stream (table) Token stream
-- @param left (table) VariableDeclaration for the loop variable
-- @return (table|nil) ForInStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_for_in_from_left(stream, left, kw)
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
  local right = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return for_in_statement(left, right, body, kw)
end

--- Parse throw: throw expression;
function parse_throw_statement(stream)
  local kw = stream.consume(TOKEN.THROW)
  local argument = parse_expression(stream)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return throw_statement(argument, kw)
end

--- Parse try/catch/finally: try { ... } catch (param) { ... } finally { ... }
-- At least one of catch or finally must be present.
function parse_try_statement(stream)
  local kw = stream.consume(TOKEN.TRY)
  local block = parse_block_statement(stream)

  local handler = nil
  if stream.is(TOKEN.CATCH) then
    local catch_kw = stream.advance()
    stream.consume(TOKEN.LPAREN)
    local param_token = stream.consume(TOKEN.IDENTIFIER)
    local param = identifier(param_token.value, param_token)
    stream.consume(TOKEN.RPAREN)
    local catch_body = parse_block_statement(stream)
    handler = catch_clause(param, catch_body, catch_kw)
  end

  local finalizer = nil
  if stream.is(TOKEN.FINALLY) then
    stream.advance()
    finalizer = parse_block_statement(stream)
  end

  if not handler and not finalizer then
    parse_error("Expected catch or finally after try block", stream.peek().line, stream.peek().col)
  end

  return try_statement(block, handler, finalizer, kw)
end

--- Parse function declaration: function name(params) { body }
-- Always has a name (unlike function expressions which can be anonymous).
function parse_function_declaration(stream)
  local kw = stream.consume(TOKEN.FUNCTION)
  local name_token = stream.consume(TOKEN.IDENTIFIER)
  local name = name_token.value

  stream.consume(TOKEN.LPAREN)
  local params = parse_parameters(stream)
  stream.consume(TOKEN.RPAREN)

  local body = parse_block_statement(stream)
  return function_declaration(name, params, body, kw)
end

--- Parse class body: { constructor(){} method(){} static fn(){} }
-- Disambiguates static modifier from method named "static": static foo() is a
-- static method, static() is a regular method named "static".
-- @param stream (table) Token stream
-- @return (table) Array of MethodDefinition nodes
function parse_class_body(stream)
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
      key = identifier(key_token.value, key_token)
      if key_token.value == "constructor" then
        kind = "constructor"
      end
    elseif stream.is(TOKEN.STRING) then
      key_token = stream.advance()
      key = string_literal(key_token.value, key_token)
    else
      parse_error("Expected method name in class body", stream.peek().line, stream.peek().col)
    end
    stream.consume(TOKEN.LPAREN)
    local params = parse_parameters(stream)
    stream.consume(TOKEN.RPAREN)
    local body = parse_block_statement(stream)
    local fn = function_expression(params, body, key_token)
    fn.is_method = true
    if kind == "constructor" then
      fn.is_method = false
    end
    table.insert(methods, method_definition(kind, key, fn, is_static, key_token))
  end
  stream.consume(TOKEN.RBRACE)
  return methods
end

--- Parse class declaration: class Name [extends Super] { body }
-- Always requires a name (unlike class expressions).
-- @param stream (table) Token stream
-- @return table ClassDeclaration AST node
function parse_class_declaration(stream)
  local kw = stream.consume(TOKEN.CLASS)
  local name_token = stream.consume(TOKEN.IDENTIFIER)
  local name = name_token.value
  local superClass = nil
  if stream.is(TOKEN.EXTENDS) then
    stream.advance()
    superClass = parse_expression(stream)
  end
  local body = parse_class_body(stream)
  return class_declaration(name, superClass, body, kw)
end

--- Parse class expression: class [Name] [extends Super] { body }
-- Name is optional and only consumed if followed by something other than (
-- (to disambiguate from a call expression in certain contexts).
-- @param stream (table) Token stream
-- @return table ClassExpression AST node
function parse_class_expression(stream)
  local kw = stream.consume(TOKEN.CLASS)
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
    superClass = parse_expression(stream)
  end
  local body = parse_class_body(stream)
  return class_expression(name, superClass, body, kw)
end

--- Parse return: return expression?;
-- Bare return (no expression) is allowed — argument will be nil.
-- Heuristic: if next token is ; or }, there's no expression.
function parse_return_statement(stream)
  local kw = stream.consume(TOKEN.RETURN)
  local argument = nil
  if not stream.is(TOKEN.SEMICOLON) and not stream.is(TOKEN.RBRACE) then
    argument = parse_expression(stream)
  end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return return_statement(argument, kw)
end

--- Parse switch: switch (expr) { case val: stmts default: stmts }
function parse_switch_statement(stream)
  local kw = stream.consume(TOKEN.SWITCH)
  stream.consume(TOKEN.LPAREN)
  local discriminant = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  stream.consume(TOKEN.LBRACE)

  local cases = {}
  local has_default = false

  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    local test = nil
    local case_token

    if stream.is(TOKEN.CASE) then
      case_token = stream.advance()
      test = parse_expression(stream)
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
      table.insert(consequent, parse_statement(stream))
    end

    table.insert(cases, switch_case(test, consequent, case_token))
  end

  stream.consume(TOKEN.RBRACE)
  return switch_statement(discriminant, cases, kw)
end

--- Parse break: break ;
function parse_break_statement(stream)
  local kw = stream.consume(TOKEN.BREAK)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return break_statement(kw)
end

--- Parse continue: continue ;
function parse_continue_statement(stream)
  local kw = stream.consume(TOKEN.CONTINUE)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return continue_statement(kw)
end

--- Parse a comma-separated list of identifier parameters.
-- Used by both function declarations and function expressions.
-- Assumes opening ( has been consumed; does NOT consume closing ).
function parse_parameters(stream)
  local params = {}
  if not stream.is(TOKEN.RPAREN) then
    while true do
      local param_token = stream.consume(TOKEN.IDENTIFIER)
      table.insert(params, identifier(param_token.value, param_token))
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
-- Uses Pratt parsing (top-down operator precedence):
--   parse_expression -> parse_binary_expression(min_prec=0)
--     -> parse_unary_expression -> parse_primary_expression
--     -> loops while next operator has sufficient precedence
--
-- Precedence levels (higher = binds tighter):
--   6   unary ! -
--   5.5 ** (exponentiation, right-associative)
--   5   * / %
--   4   + -
--   3.5 << >> >>> (bitwise shifts)
--   3   === !== < > <= >= in
--   2.75 & (bitwise AND)
--   2.5 ^ (bitwise XOR)
--   2.25 | (bitwise OR)
--   2   &&
--   1   ||
--   0.5 = += -= *= /= %= **= &= |= ^= <<= >>= >>>= (assignment, right-associative)
--
-- All binary operators except assignment, compound assignment, and ** are left-associative.

local PRECEDENCE = {
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
  [TOKEN.EQ] = 3,
  [TOKEN.NEQ] = 3,
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

--- Entry point for expression parsing. Starts at minimum precedence 0.
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' as a binary operator (for for-loop init)
function parse_expression(stream, no_in)
  return parse_binary_expression(stream, 0, no_in)
end

--- Pratt parser core: parse binary expressions with precedence climbing.
-- 1. Parse a unary expression (the left operand).
-- 2. Loop: while the next token is an operator with precedence >= min_precedence,
--    consume it and parse the right operand at a higher precedence level.
-- 3. Assignment is right-associative (right-recursive call to parse_expression
--    instead of parse_binary_expression with +1).
-- @param stream (table) Token stream
-- @param min_precedence (number) Minimum precedence to continue parsing
-- @param no_in (boolean|nil) If true, suppress 'in' as a binary operator
function parse_binary_expression(stream, min_precedence, no_in)
  local left = parse_unary_expression(stream)

  while true do
    local op_token = stream.peek()
    local op = op_token.type
    local precedence = PRECEDENCE[op]

    if not precedence or precedence < min_precedence then
      break
    end

    if op == TOKEN.IN and no_in then
      break
    end

    if
      op == TOKEN.ASSIGN
      or op == TOKEN.PLUS_ASSIGN
      or op == TOKEN.MINUS_ASSIGN
      or op == TOKEN.STAR_ASSIGN
      or op == TOKEN.STARSTAR_ASSIGN
      or op == TOKEN.SLASH_ASSIGN
      or op == TOKEN.PERCENT_ASSIGN
      or op == TOKEN.BITWISE_AND_ASSIGN
      or op == TOKEN.BITWISE_OR_ASSIGN
      or op == TOKEN.BITWISE_XOR_ASSIGN
      or op == TOKEN.LEFT_SHIFT_ASSIGN
      or op == TOKEN.RIGHT_SHIFT_ASSIGN
      or op == TOKEN.UNSIGNED_RIGHT_SHIFT_ASSIGN
    then
      stream.advance()
      local right = parse_expression(stream, no_in)
      left = binary_expression(op, left, right, op_token)
    elseif op == TOKEN.STARSTAR then
      stream.advance()
      local right = parse_binary_expression(stream, precedence, no_in)
      left = binary_expression(op, left, right, op_token)
    elseif op == TOKEN.QUESTION then
      stream.advance()
      local consequent = parse_expression(stream, no_in)
      stream.consume(TOKEN.COLON)
      local alternate = parse_expression(stream, no_in)
      left = conditional_expression(left, consequent, alternate, op_token)
    else
      stream.advance()
      local next_min = precedence + 0.01
      local right = parse_binary_expression(stream, next_min, no_in)
      left = binary_expression(op, left, right, op_token)
    end
  end

  return left
end

--- Parse unary prefix expressions: !expr, -expr, +expr, ~expr, or delete expr.
-- Unary operators have the highest precedence and are right-recursive
-- (so !!x parses as !(!(x))).
function parse_unary_expression(stream)
  if
    stream.is(TOKEN.NOT)
    or stream.is(TOKEN.MINUS)
    or stream.is(TOKEN.PLUS)
    or stream.is(TOKEN.TILDE)
  then
    local op_token = stream.advance()
    local op = op_token.type
    local argument = parse_unary_expression(stream)
    local op_str = op == TOKEN.NOT and "!"
      or op == TOKEN.TILDE and "~"
      or op == TOKEN.PLUS and "+"
      or "-"
    return unary_expression(op_str, argument, op_token)
  elseif stream.is(TOKEN.INCREMENT) or stream.is(TOKEN.DECREMENT) then
    local op_token = stream.advance()
    local argument = parse_unary_expression(stream)
    check_update_target(argument, op_token)
    return update_expression(op_token.type, argument, true, op_token)
  elseif stream.is(TOKEN.DELETE) then
    local kw = stream.advance()
    local argument = parse_unary_expression(stream)
    return delete_expression(argument, kw)
  elseif stream.is(TOKEN.TYPEOF) then
    local kw = stream.advance()
    local argument = parse_unary_expression(stream)
    return typeof_expression(argument, kw)
  elseif stream.is(TOKEN.NEW) then
    local new_kw = stream.advance()
    if stream.is(TOKEN.NEW) then
      local inner = parse_unary_expression(stream)
      return parse_postfix(stream, inner, true)
    end
    local banned_err = check_banned(stream)
    if banned_err then
      error(banned_err, 0)
    end
    local token = stream.consume(TOKEN.IDENTIFIER)
    local callee = identifier(token.value, token)
    while stream.is(TOKEN.DOT) or stream.is(TOKEN.LBRACKET) do
      if stream.is(TOKEN.DOT) then
        local dot = stream.advance()
        local prop_token = stream.consume_property_name()
        callee = member_expression(callee, identifier(prop_token.value, prop_token), false, dot)
      else
        local lbracket = stream.advance()
        local prop = parse_expression(stream)
        stream.consume(TOKEN.RBRACKET)
        callee = member_expression(callee, prop, true, lbracket)
      end
    end
    local args = {}
    if stream.is(TOKEN.LPAREN) then
      stream.advance()
      if not stream.is(TOKEN.RPAREN) then
        while true do
          local arg = parse_expression(stream)
          table.insert(args, arg)
          if not stream.is(TOKEN.COMMA) then
            break
          end
          stream.advance()
        end
      end
      stream.consume(TOKEN.RPAREN)
    end
    return parse_postfix(stream, new_expression(callee, args, new_kw), true)
  end
  return parse_primary_expression(stream)
end

--- Parse primary (leaf) expressions — the atomic units that operators combine.
-- Handles: literals, identifiers, parenthesized exprs, arrow functions,
-- arrays, objects, function expressions.
-- Also rejects excluded keywords (this, async, etc.) in expression context.
function parse_primary_expression(stream)
  local banned_err = check_banned(stream)
  if banned_err then
    error(banned_err, 0)
  end

  local token = stream.peek()

  if stream.is(TOKEN.NUMBER) then
    stream.advance()
    -- NOTE: NumberLiteral deliberately NOT wrapped in parse_postfix because
    -- `42.toString()` is a SyntaxError in JS (the dot after a number literal
    -- is parsed as a decimal point). Use (42).toString() instead.
    return number_literal(token.value, token)
  elseif stream.is(TOKEN.STRING) then
    stream.advance()
    return parse_postfix(stream, string_literal(token.value, token), true)
  elseif stream.is(TOKEN.BOOLEAN) then
    stream.advance()
    return parse_postfix(stream, boolean_literal(token.value, token), true)
  elseif stream.is(TOKEN.NULL) then
    stream.advance()
    return parse_postfix(stream, null_literal(token), true)
  elseif stream.is(TOKEN.UNDEFINED) then
    stream.advance()
    return parse_postfix(stream, undefined_literal(token), true)
  elseif stream.is(TOKEN.THIS) then
    stream.advance()
    return parse_postfix(stream, this_expression(token), true)
  elseif stream.is(TOKEN.SUPER) then
    stream.advance()
    return parse_postfix(stream, super_expression(token), true)
  elseif stream.is(TOKEN.IDENTIFIER) then
    return parse_identifier_or_call(stream)
  elseif stream.is(TOKEN.LPAREN) then
    -- Disambiguate (expr) from (params) => body: scan ahead to matching )
    -- and check if => follows. Without this lookahead, (x) => x would be
    -- misparsed as a parenthesized identifier.
    local depth = 0
    local n = 0
    local found_arrow = false

    while true do
      local t = stream.peek_n(n + 1)
      if t.type == "EOF" then
        break
      end
      if t.type == TOKEN.LPAREN then
        depth = depth + 1
      elseif t.type == TOKEN.RPAREN then
        depth = depth - 1
      end
      if depth == 0 then
        if stream.peek_n(n + 2) and stream.peek_n(n + 2).type == TOKEN.ARROW then
          found_arrow = true
        end
        break
      end
      n = n + 1
    end

    if found_arrow then
      local arrow_token = token
      stream.advance()
      local params = {}
      if not stream.is(TOKEN.RPAREN) then
        while true do
          if stream.is(TOKEN.IDENTIFIER) then
            local id_token = stream.advance()
            table.insert(params, identifier(id_token.value, id_token))
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
      local body = parse_arrow_function_body(stream)
      return arrow_function_expression(params, body, arrow_token)
    else
      stream.advance()
      local expr = parse_expression(stream)
      stream.consume(TOKEN.RPAREN)
      return parse_postfix(stream, expr, not is_valid_update_target(expr))
    end
  elseif stream.is(TOKEN.LBRACKET) then
    return parse_postfix(stream, parse_array_literal(stream), true)
  elseif stream.is(TOKEN.LBRACE) then
    return parse_postfix(stream, parse_object_literal(stream), true)
  elseif stream.is(TOKEN.FUNCTION) then
    return parse_postfix(stream, parse_function_expression(stream), true)
  elseif stream.is(TOKEN.ARROW) then
    parse_error("Unexpected arrow token", token.line, token.col)
  elseif stream.is(TOKEN.CLASS) then
    -- NOTE: no parse_postfix wrapper — class expressions can't be directly
    -- chained with .prop or (args). They're always parenthesized in practice.
    return parse_class_expression(stream)
  else
    parse_error(string.format("Unexpected token %s", token.type), token.line, token.col)
  end
end

--- Parse the body of an arrow function.
-- If body starts with {, it's a block body.
-- Otherwise it's an expression body, which gets wrapped in a BlockStatement
-- containing a single ExpressionStatement (desugared form).
function parse_arrow_function_body(stream)
  if stream.is(TOKEN.LBRACE) then
    return parse_block_statement(stream)
  else
    local expr_token = stream.peek()
    local expr = parse_expression(stream)
    local ret = return_statement(expr, expr_token)
    return block_statement({ ret }, expr_token)
  end
end

--- Parse postfix operations on an expression: .prop, [expr], (args).
-- Loops to handle chaining: obj.method()[0].field
-- This is shared between parse_identifier_or_call and parse_call_expression
-- to avoid duplicating the chaining logic.
-- @param stream (table) Token stream
-- @param expr (table) The expression to apply postfix ops to
-- @return (table) The resulting expression after all postfix ops
function parse_postfix(stream, expr, no_update)
  while true do
    if stream.is(TOKEN.DOT) then
      local dot = stream.advance()
      local prop_token = stream.consume_property_name()
      expr = member_expression(expr, identifier(prop_token.value, prop_token), false, dot)
      no_update = false
    elseif stream.is(TOKEN.LBRACKET) then
      local lbracket = stream.advance()
      local prop = parse_expression(stream)
      stream.consume(TOKEN.RBRACKET)
      expr = member_expression(expr, prop, true, lbracket)
      no_update = false
    elseif stream.is(TOKEN.LPAREN) then
      local lparen = stream.advance()
      local args = {}
      if not stream.is(TOKEN.RPAREN) then
        while true do
          local arg = parse_expression(stream)
          table.insert(args, arg)
          if not stream.is(TOKEN.COMMA) then
            break
          end
          stream.advance()
        end
      end
      stream.consume(TOKEN.RPAREN)
      expr = call_expression(expr, args, lparen)
      no_update = false
    else
      break
    end
  end
  -- Postfix ++/-- is checked once after the chain, not inside the loop,
  -- because it's not chainable: x++++ is not valid JS.
  if stream.is(TOKEN.INCREMENT) or stream.is(TOKEN.DECREMENT) then
    local op_token = stream.advance()
    if no_update then
      parse_error(
        "Invalid update target: cannot use " .. op_token.type .. " on this expression",
        op_token.line,
        op_token.col
      )
    end
    return update_expression(op_token.type, expr, false, op_token)
  end
  return expr
end

--- Parse an identifier, which might be:
--   1. A bare identifier (variable reference)
--   2. The start of an arrow function: x => expr
--   3. Followed by member access/calls via parse_postfix
function parse_identifier_or_call(stream)
  local token = stream.consume(TOKEN.IDENTIFIER)
  local expr = identifier(token.value, token)

  if stream.is(TOKEN.ARROW) then
    local arrow_token = stream.advance()
    local body = parse_arrow_function_body(stream)
    return arrow_function_expression({ expr }, body, arrow_token)
  end

  return parse_postfix(stream, expr)
end

--- Parse call expression after callee has been identified.
-- Called when the caller has already determined that ( follows an expression.
-- Delegates to parse_postfix for further chaining after the call.
-- @param stream (table) Token stream
-- @param callee (table) The expression being called
function parse_call_expression(stream, callee)
  local lparen = stream.consume(TOKEN.LPAREN)
  local arguments = {}
  if not stream.is(TOKEN.RPAREN) then
    while true do
      local arg = parse_expression(stream)
      table.insert(arguments, arg)
      if not stream.is(TOKEN.COMMA) then
        break
      end
      stream.advance()
    end
  end
  stream.consume(TOKEN.RPAREN)
  local expr = call_expression(callee, arguments, lparen)
  return parse_postfix(stream, expr)
end

--- Parse array literal: [expr, expr, ...]
-- Empty arrays [] are valid.
function parse_array_literal(stream)
  local lbracket = stream.consume(TOKEN.LBRACKET)
  local elements = {}
  if not stream.is(TOKEN.RBRACKET) then
    while true do
      local element = parse_expression(stream)
      table.insert(elements, element)
      if not stream.is(TOKEN.COMMA) then
        break
      end
      stream.advance()
      if stream.is(TOKEN.RBRACKET) then
        break
      end
    end
  end
  stream.consume(TOKEN.RBRACKET)
  return array_expression(elements, lbracket)
end

--- Parse object literal: { key: value, key: value, ... }
-- Property forms:
--   key: value       — regular key-value pair
--   key(params) {}   — method shorthand (identifier keys only)
--   key              — shorthand property, equivalent to key: key (identifier keys only)
-- String keys only support the key: value form.
-- Computed keys (e.g. {[expr]: value}) are not supported.
-- Empty objects {} are valid.
function parse_object_literal(stream)
  local lbrace = stream.consume(TOKEN.LBRACE)
  local properties = {}
  if not stream.is(TOKEN.RBRACE) then
    while true do
      local key
      local key_is_identifier = false
      if stream.is_property_name() then
        local key_token = stream.advance()
        key = identifier(key_token.value, key_token)
        key_is_identifier = true
      elseif stream.is(TOKEN.STRING) then
        local key_token = stream.advance()
        key = string_literal(key_token.value, key_token)
      else
        parse_error("Expected property key", stream.peek().line, stream.peek().col)
      end

      if stream.is(TOKEN.COLON) then
        stream.advance()
        local value = parse_expression(stream)
        table.insert(properties, property(key, value, false, key))
      elseif key_is_identifier and stream.is(TOKEN.LPAREN) then
        stream.consume(TOKEN.LPAREN)
        local params = parse_parameters(stream)
        stream.consume(TOKEN.RPAREN)
        local body = parse_block_statement(stream)
        local fn = function_expression(params, body, key)
        fn.name = key.name
        fn.is_method = true
        table.insert(properties, property(key, fn, false, key))
      elseif key_is_identifier and (stream.is(TOKEN.COMMA) or stream.is(TOKEN.RBRACE)) then
        table.insert(properties, property(key, identifier(key.name, key), false, key))
      else
        parse_error(
          "Expected ':', '(', ',', or '}' after property key",
          stream.peek().line,
          stream.peek().col
        )
      end

      if not stream.is(TOKEN.COMMA) then
        break
      end
      stream.advance()
      if stream.is(TOKEN.RBRACE) then
        break
      end
    end
  end
  stream.consume(TOKEN.RBRACE)
  return object_expression(properties, lbrace)
end

--- Parse function expression: function(params) { body } or function name(params) { body }
-- Can be anonymous (no name) or named. Named function expressions produce
-- a FunctionExpression node with a `name` field (not FunctionDeclaration).
function parse_function_expression(stream)
  local kw = stream.consume(TOKEN.FUNCTION)

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
  local params = parse_parameters(stream)
  stream.consume(TOKEN.RPAREN)

  local body = parse_block_statement(stream)

  if name then
    local fn = function_expression(params, body, kw)
    fn.name = name
    return fn
  else
    return function_expression(params, body, kw)
  end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

M.ParseError = ParseError
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
