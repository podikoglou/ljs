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
  ELLIPSIS = "...",
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
  LOOSE_EQ = "==",
  LOOSE_NEQ = "!=",
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
  TEMPLATE_LITERAL = "TemplateLiteral",
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
    return c and c:match("%d")
  end

  local function is_alpha(c)
    return c and c:match("[%a_]")
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
        if current() and (current() == "e" or current() == "E") then
          advance()
          if current() == "+" or current() == "-" then
            advance()
          end
          if not current() or not is_digit(current()) then
            return nil, make_parse_error("Invalid number literal", line, start_col)
          end
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
          elseif ch == "v" then
            ch = "\v"
          elseif ch == "\\" then
            ch = "\\"
          elseif ch == '"' then
            ch = '"'
          elseif ch == "'" then
            ch = "'"
          elseif ch == "0" then
            ch = string.char(0)
          elseif ch == "x" then
            advance()
            local h1 = current()
            if not h1 or not h1:match("%x") then
              return nil, make_parse_error("Invalid hex escape sequence", line, col)
            end
            advance()
            local h2 = current()
            if not h2 or not h2:match("%x") then
              return nil, make_parse_error("Invalid hex escape sequence", line, col)
            end
            ch = string.char(tonumber(h1 .. h2, 16))
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

    elseif c == "`" then
      local start_col = col
      advance()
      local quasis = {}
      local expression_sources = {}
      local chars = {}
      local found_closing = false
      while current() do
        local ch = current()
        if ch == "`" then
          advance()
          quasis[#quasis + 1] = table.concat(chars, "")
          chars = {}
          found_closing = true
          break
        elseif ch == "$" then
          advance()
          if current() == "{" then
            advance()
            quasis[#quasis + 1] = table.concat(chars, "")
            chars = {}
            local depth = 1
            local expr_start = pos
            while current() and depth > 0 do
              local ec = current()
              if ec == "{" then
                depth = depth + 1
              elseif ec == "}" then
                depth = depth - 1
                if depth == 0 then
                  break
                end
              elseif ec == '"' or ec == "'" then
                local quote = ec
                advance()
                while current() and current() ~= quote do
                  if current() == "\\" then
                    advance()
                  end
                  if current() then advance() end
                end
                if current() then advance() end
              elseif ec == "`" then
                advance()
                local inner_depth = 0
                while current() do
                  local ic = current()
                  if ic == "`" then
                    advance()
                    break
                  elseif ic == "$" then
                    advance()
                    if current() == "{" then
                      advance()
                      inner_depth = inner_depth + 1
                    end
                  elseif ic == "}" and inner_depth > 0 then
                    advance()
                    inner_depth = inner_depth - 1
                  elseif ic == "\\" then
                    advance()
                    if current() then advance() end
                  else
                    advance()
                  end
                end
              else
                advance()
              end
            end
            if depth ~= 0 then
              return nil, make_parse_error("Unterminated template expression", line, start_col)
            end
            expression_sources[#expression_sources + 1] = source:sub(expr_start, pos - 1)
            advance()
          else
            chars[#chars + 1] = "$"
          end
        elseif ch == "\\" then
          advance()
          local esc = current()
          if not esc then
            return nil, make_parse_error("Unterminated template escape", line, start_col)
          end
          if esc == "n" then
            chars[#chars + 1] = "\n"
          elseif esc == "r" then
            chars[#chars + 1] = "\r"
          elseif esc == "t" then
            chars[#chars + 1] = "\t"
          elseif esc == "b" then
            chars[#chars + 1] = "\b"
          elseif esc == "f" then
            chars[#chars + 1] = "\f"
          elseif esc == "v" then
            chars[#chars + 1] = "\v"
          elseif esc == "\\" then
            chars[#chars + 1] = "\\"
          elseif esc == "`" then
            chars[#chars + 1] = "`"
          elseif esc == "$" then
            chars[#chars + 1] = "$"
          elseif esc == '"' then
            chars[#chars + 1] = '"'
          elseif esc == "'" then
            chars[#chars + 1] = "'"
          elseif esc == "0" then
            chars[#chars + 1] = string.char(0)
          elseif esc == "x" then
            advance()
            local h1 = current()
            if not h1 or not h1:match("%x") then
              return nil, make_parse_error("Invalid hex escape sequence", line, col)
            end
            advance()
            local h2 = current()
            if not h2 or not h2:match("%x") then
              return nil, make_parse_error("Invalid hex escape sequence", line, col)
            end
            chars[#chars + 1] = string.char(tonumber(h1 .. h2, 16))
          else
            return nil, make_parse_error("Invalid escape sequence in template literal", line, col)
          end
          advance()
        else
          chars[#chars + 1] = ch
          advance()
        end
      end
      if not found_closing then
        return nil, make_parse_error("Unterminated template literal", line, start_col)
      end
      table.insert(
        tokens,
        make_token(TOKEN.TEMPLATE_LITERAL, { quasis = quasis, expression_sources = expression_sources }, line, start_col)
      )

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
      if source:sub(pos, pos + 2) == "..." then
        table.insert(tokens, make_token(TOKEN.ELLIPSIS))
        advance(3)
      else
        table.insert(tokens, make_token(TOKEN.DOT))
        advance()
      end
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
          table.insert(tokens, make_token(TOKEN.LOOSE_EQ))
          advance(2)
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
      elseif source:sub(pos, pos + 1) == "!=" then
        table.insert(tokens, make_token(TOKEN.LOOSE_NEQ))
        advance(2)
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
  stream.loop_depth = 0
  stream.switch_depth = 0

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
local parse_maybe_spread
local parse_do_while_statement
local parse_c_style_for
local parse_c_style_for_from_test
local parse_for_of_from_left
local parse_for_in_from_left
local parse_class_body
local parse_class_declaration
local parse_class_expression

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
      table.insert(stmts, parse_statement(stream))
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
    return ast.expression_statement(expr, expr_token)
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
  return ast.block_statement(body, lbrace)
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

  return ast.variable_declaration(kind, declarations, kind_token)
end

--- Parse a single variable declarator: name or name = init
-- Supports destructuring: let [a, b] = arr; let {x, y} = obj;
-- @param stream (table) Token stream
-- @param no_in (boolean|nil) If true, suppress 'in' in initializer expression
function parse_variable_declarator(stream, no_in)
  local token = stream.peek()
  local name
  if token.type == TOKEN.LBRACE then
    name = parse_object_pattern(stream)
  elseif token.type == TOKEN.LBRACKET then
    name = parse_array_pattern(stream)
  else
    stream.consume(TOKEN.IDENTIFIER)
    name = ast.identifier(token.value, token)
  end

  local init = nil
  if stream.is(TOKEN.ASSIGN) then
    stream.advance()
    init = parse_expression(stream, no_in)
  end

  if not init and (name.type == ast.TYPE_OBJECT_PATTERN or name.type == ast.TYPE_ARRAY_PATTERN) then
    parse_error("Missing initializer in destructuring declaration", token.line, token.col)
  end

  return ast.variable_declarator(name, init, token)
end

function parse_object_pattern(stream)
  local lbrace = stream.consume(TOKEN.LBRACE)
  local properties = {}

  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    if stream.is(TOKEN.ELLIPSIS) then
      local ellipsis = stream.advance()
      local id_token = stream.consume(TOKEN.IDENTIFIER)
      properties[#properties + 1] = ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis)
    else
      local key_token = stream.consume_property_name()
      local key = ast.identifier(key_token.value, key_token)

      if stream.is(TOKEN.COLON) then
        stream.advance()
        local value = parse_binding_element(stream)
        properties[#properties + 1] = ast.property(key, value, false, key_token, false)
      elseif stream.is(TOKEN.ASSIGN) then
        stream.advance()
        local default_expr = parse_expression(stream)
        properties[#properties + 1] = ast.property(
          key,
          ast.assignment_pattern(ast.identifier(key.name, key_token), default_expr, key_token),
          false,
          key_token,
          true
        )
      else
        properties[#properties + 1] = ast.property(
          key,
          ast.identifier(key.name, key_token),
          false,
          key_token,
          true
        )
      end
    end

    if not stream.is(TOKEN.COMMA) then break end
    stream.advance()
  end

  stream.consume(TOKEN.RBRACE)
  return ast.object_pattern(properties, lbrace)
end

function parse_array_pattern(stream)
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
      if stream.is(TOKEN.COMMA) then stream.advance() end
    else
      local elem = parse_binding_element(stream)
      elements[idx] = elem
      idx = idx + 1
      if stream.is(TOKEN.COMMA) then stream.advance() end
    end
  end

  stream.consume(TOKEN.RBRACKET)
  return ast.array_pattern(elements, lbracket)
end

function parse_binding_element(stream)
  local token = stream.peek()
  if token.type == TOKEN.LBRACE then
    return parse_object_pattern(stream)
  elseif token.type == TOKEN.LBRACKET then
    return parse_array_pattern(stream)
  else
    stream.consume(TOKEN.IDENTIFIER)
    local name = ast.identifier(token.value, token)
    if stream.is(TOKEN.ASSIGN) then
      local assign_tok = stream.advance()
      local default_expr = parse_expression(stream)
      return ast.assignment_pattern(name, default_expr, assign_tok)
    end
    return name
  end
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

  return ast.if_statement(test, consequent, alternate, kw)
end

--- Parse while: while (test) body
function parse_while_statement(stream)
  local kw = stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  stream.loop_depth = stream.loop_depth + 1
  local body = parse_statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.while_statement(test, body, kw)
end

--- Parse do...while: do body while (test);
-- Body always executes at least once. Semicolon after is optional.
-- @param stream (table) Token stream
-- @return (table|nil) DoWhileStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_do_while_statement(stream)
  local kw = stream.consume(TOKEN.DO)
  stream.loop_depth = stream.loop_depth + 1
  local body = parse_statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  stream.consume(TOKEN.RPAREN)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.do_while_statement(body, test, kw)
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
    stream.loop_depth = stream.loop_depth + 1
    local body = parse_statement(stream)
    stream.loop_depth = stream.loop_depth - 1
    return ast.for_of_statement(expr, right, body, kw)
  end

  if stream.is(TOKEN.IN) then
    stream.consume(TOKEN.IN)
    local right = parse_expression(stream)
    stream.consume(TOKEN.RPAREN)
    stream.loop_depth = stream.loop_depth + 1
    local body = parse_statement(stream)
    stream.loop_depth = stream.loop_depth - 1
    return ast.for_in_statement(expr, right, body, kw)
  end

  local init = ast.expression_statement(expr, expr_token)
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

  stream.loop_depth = stream.loop_depth + 1
  local body = parse_statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.for_statement(init, test, update, body, kw)
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
  stream.loop_depth = stream.loop_depth + 1
  local body = parse_statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.for_of_statement(left, right, body, kw)
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
  stream.loop_depth = stream.loop_depth + 1
  local body = parse_statement(stream)
  stream.loop_depth = stream.loop_depth - 1
  return ast.for_in_statement(left, right, body, kw)
end

--- Parse throw: throw expression;
function parse_throw_statement(stream)
  local kw = stream.consume(TOKEN.THROW)
  local argument = parse_expression(stream)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return ast.throw_statement(argument, kw)
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
    local param = ast.identifier(param_token.value, param_token)
    stream.consume(TOKEN.RPAREN)
    local catch_body = parse_block_statement(stream)
    handler = ast.catch_clause(param, catch_body, catch_kw)
  end

  local finalizer = nil
  if stream.is(TOKEN.FINALLY) then
    stream.advance()
    finalizer = parse_block_statement(stream)
  end

  if not handler and not finalizer then
    parse_error("Expected catch or finally after try block", stream.peek().line, stream.peek().col)
  end

  return ast.try_statement(block, handler, finalizer, kw)
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

  local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
  stream.loop_depth, stream.switch_depth = 0, 0
  local body = parse_block_statement(stream)
  stream.loop_depth, stream.switch_depth = saved_loop, saved_switch
  return ast.function_declaration(name, params, body, kw)
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
    local params = parse_parameters(stream)
    stream.consume(TOKEN.RPAREN)
    local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
    stream.loop_depth, stream.switch_depth = 0, 0
    local body = parse_block_statement(stream)
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
  return ast.class_declaration(name, superClass, body, kw)
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
  return ast.class_expression(name, superClass, body, kw)
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
  return ast.return_statement(argument, kw)
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
  stream.switch_depth = stream.switch_depth + 1

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

    table.insert(cases, ast.switch_case(test, consequent, case_token))
  end

  stream.switch_depth = stream.switch_depth - 1
  stream.consume(TOKEN.RBRACE)
  return ast.switch_statement(discriminant, cases, kw)
end

--- Parse break: break ;
function parse_break_statement(stream)
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
function parse_continue_statement(stream)
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
      if not stream.is(TOKEN.COMMA) then break end
      stream.advance()
      if allow_trailing and stream.is(close_token) then break end
    end
  end
  return items
end

--- Parse a comma-separated list of identifier parameters.
-- Used by both function declarations and function expressions.
-- Assumes opening ( has been consumed; does NOT consume closing ).
function parse_parameters(stream)
  local function parse_param_item(s)
    if s.is(TOKEN.ELLIPSIS) then
      local ellipsis = s.advance()
      local id_token = s.consume(TOKEN.IDENTIFIER)
      return ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis)
    end
    local id_token = s.consume(TOKEN.IDENTIFIER)
    local param = ast.identifier(id_token.value, id_token)
    if s.is(TOKEN.ASSIGN) then
      local assign_tok = s.advance()
      local default_expr = parse_expression(s)
      return ast.assignment_pattern(param, default_expr, assign_tok)
    end
    return param
  end
  local params = {}
  local found_rest = false
  if not stream.is(TOKEN.RPAREN) then
    while true do
      if found_rest then
        parse_error("Rest parameter must be the last parameter", stream.peek().line, stream.peek().col)
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
      left = ast.binary_expression(op, left, right, op_token)
    elseif op == TOKEN.STARSTAR then
      stream.advance()
      local right = parse_binary_expression(stream, precedence, no_in)
      left = ast.binary_expression(op, left, right, op_token)
    elseif op == TOKEN.QUESTION then
      stream.advance()
      local consequent = parse_expression(stream, no_in)
      stream.consume(TOKEN.COLON)
      local alternate = parse_expression(stream, no_in)
      left = ast.conditional_expression(left, consequent, alternate, op_token)
    else
      stream.advance()
      local next_min = precedence + 0.01
      local right = parse_binary_expression(stream, next_min, no_in)
      left = ast.binary_expression(op, left, right, op_token)
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
    return ast.unary_expression(op_str, argument, op_token)
  elseif stream.is(TOKEN.INCREMENT) or stream.is(TOKEN.DECREMENT) then
    local op_token = stream.advance()
    local argument = parse_unary_expression(stream)
    check_update_target(argument, op_token)
    return ast.update_expression(op_token.type, argument, true, op_token)
  elseif stream.is(TOKEN.DELETE) then
    local kw = stream.advance()
    local argument = parse_unary_expression(stream)
    return ast.delete_expression(argument, kw)
  elseif stream.is(TOKEN.TYPEOF) then
    local kw = stream.advance()
    local argument = parse_unary_expression(stream)
    return ast.typeof_expression(argument, kw)
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
    local callee = ast.identifier(token.value, token)
    while stream.is(TOKEN.DOT) or stream.is(TOKEN.LBRACKET) do
      if stream.is(TOKEN.DOT) then
        local dot = stream.advance()
        local prop_token = stream.consume_property_name()
        callee = ast.member_expression(callee, ast.identifier(prop_token.value, prop_token), false, dot)
      else
        local lbracket = stream.advance()
        local prop = parse_expression(stream)
        stream.consume(TOKEN.RBRACKET)
        callee = ast.member_expression(callee, prop, true, lbracket)
      end
    end
    local args = {}
    if stream.is(TOKEN.LPAREN) then
      stream.advance()
      args = parse_comma_list(stream, TOKEN.RPAREN, parse_maybe_spread)
      stream.consume(TOKEN.RPAREN)
    end
    return parse_postfix(stream, ast.new_expression(callee, args, new_kw), true)
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
    if stream.is(TOKEN.DOT) and stream.peek_n(2).type == TOKEN.DOT then
      stream.advance()
      return parse_postfix(stream, ast.number_literal(token.value, token), true)
    end
    if token.value % 1 ~= 0 and stream.is(TOKEN.DOT) then
      return parse_postfix(stream, ast.number_literal(token.value, token), true)
    end
    return ast.number_literal(token.value, token)
  elseif stream.is(TOKEN.STRING) then
    stream.advance()
    return parse_postfix(stream, ast.string_literal(token.value, token), true)
  elseif stream.is(TOKEN.BOOLEAN) then
    stream.advance()
    return parse_postfix(stream, ast.boolean_literal(token.value, token), true)
  elseif stream.is(TOKEN.NULL) then
    stream.advance()
    return parse_postfix(stream, ast.null_literal(token), true)
  elseif stream.is(TOKEN.UNDEFINED) then
    stream.advance()
    return parse_postfix(stream, ast.undefined_literal(token), true)
  elseif stream.is(TOKEN.THIS) then
    stream.advance()
    return parse_postfix(stream, ast.this_expression(token), true)
  elseif stream.is(TOKEN.SUPER) then
    stream.advance()
    return parse_postfix(stream, ast.super_expression(token), true)
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
      if t.type == TOKEN.EOF then
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
      local found_rest = false
      if not stream.is(TOKEN.RPAREN) then
        while true do
          if found_rest then
            parse_error("Rest parameter must be the last parameter", stream.peek().line, stream.peek().col)
          end
          if stream.is(TOKEN.ELLIPSIS) then
            local ellipsis = stream.advance()
            local id_token = stream.consume(TOKEN.IDENTIFIER)
            table.insert(params, ast.rest_element(ast.identifier(id_token.value, id_token), ellipsis))
            found_rest = true
          elseif stream.is(TOKEN.IDENTIFIER) then
            local id_token = stream.advance()
            local param = ast.identifier(id_token.value, id_token)
            if stream.is(TOKEN.ASSIGN) then
              local assign_tok = stream.advance()
              local default_expr = parse_expression(stream)
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
      local body = parse_arrow_function_body(stream)
      return ast.arrow_function_expression(params, body, arrow_token)
    else
      stream.advance()
      local expr = parse_expression(stream)
      stream.consume(TOKEN.RPAREN)
      return parse_postfix(stream, expr, not ast.is_valid_update_target(expr))
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
    return parse_postfix(stream, parse_class_expression(stream), true)
  elseif stream.is(TOKEN.TEMPLATE_LITERAL) then
    local token = stream.advance()
    local quasis = {}
    local expressions = {}
    for i, q in ipairs(token.value.quasis) do
      local is_tail = (i == #token.value.quasis)
      quasis[#quasis + 1] = ast.template_element(q, is_tail, token)
    end
    for _, expr_src in ipairs(token.value.expression_sources) do
      local expr_tokens = tokenize(expr_src)
      if not expr_tokens then
        parse_error("Failed to tokenize template expression", token.line, token.col)
      end
      local expr_stream = make_token_stream(expr_tokens)
      expressions[#expressions + 1] = parse_expression(expr_stream)
    end
    return parse_postfix(stream, ast.template_literal(quasis, expressions, token), true)
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
    local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
    stream.loop_depth, stream.switch_depth = 0, 0
    local body = parse_block_statement(stream)
    stream.loop_depth, stream.switch_depth = saved_loop, saved_switch
    return body
  else
    local expr_token = stream.peek()
    local expr = parse_expression(stream)
    local ret = ast.return_statement(expr, expr_token)
    return ast.block_statement({ ret }, expr_token)
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
      expr = ast.member_expression(expr, ast.identifier(prop_token.value, prop_token), false, dot)
      no_update = false
    elseif stream.is(TOKEN.LBRACKET) then
      local lbracket = stream.advance()
      local prop = parse_expression(stream)
      stream.consume(TOKEN.RBRACKET)
      expr = ast.member_expression(expr, prop, true, lbracket)
      no_update = false
    elseif stream.is(TOKEN.LPAREN) then
      local lparen = stream.advance()
      local args = parse_comma_list(stream, TOKEN.RPAREN, parse_maybe_spread)
      stream.consume(TOKEN.RPAREN)
      expr = ast.call_expression(expr, args, lparen)
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
    return ast.update_expression(op_token.type, expr, false, op_token)
  end
  return expr
end

--- Parse an identifier, which might be:
--   1. A bare identifier (variable reference)
--   2. The start of an arrow function: x => expr
--   3. Followed by member access/calls via parse_postfix
function parse_identifier_or_call(stream)
  local token = stream.consume(TOKEN.IDENTIFIER)
  local expr = ast.identifier(token.value, token)

  if stream.is(TOKEN.ARROW) then
    stream.advance()
    local body = parse_arrow_function_body(stream)
    return ast.arrow_function_expression({ expr }, body, token)
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
  local arguments = parse_comma_list(stream, TOKEN.RPAREN, parse_maybe_spread)
  stream.consume(TOKEN.RPAREN)
  local expr = ast.call_expression(callee, arguments, lparen)
  return parse_postfix(stream, expr)
end

function parse_maybe_spread(stream)
  if stream.is(TOKEN.ELLIPSIS) then
    local ellipsis = stream.advance()
    local expr = parse_expression(stream)
    return ast.spread_element(expr, ellipsis)
  end
  return parse_expression(stream)
end

--- Parse array literal: [expr, expr, ...]
-- Empty arrays [] are valid.
function parse_array_literal(stream)
  local lbracket = stream.consume(TOKEN.LBRACKET)
  local elements = parse_comma_list(stream, TOKEN.RBRACKET, parse_maybe_spread, true)
  stream.consume(TOKEN.RBRACKET)
  return ast.array_expression(elements, lbracket)
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
      local value = parse_expression(s)
      return ast.property(key, value, false, key)
    elseif key_is_identifier and s.is(TOKEN.LPAREN) then
      s.consume(TOKEN.LPAREN)
      local params = parse_parameters(s)
      s.consume(TOKEN.RPAREN)
      local body = parse_block_statement(s)
      local fn = ast.function_expression(params, body, key)
      fn.name = key.name
      fn.is_method = true
      return ast.property(key, fn, false, key)
    elseif key_is_identifier and (s.is(TOKEN.COMMA) or s.is(TOKEN.RBRACE)) then
      return ast.property(key, ast.identifier(key.name, key), false, key)
    else
      parse_error(
        "Expected ':', '(', ',', or '}' after property key",
        s.peek().line,
        s.peek().col
      )
    end
  end

  local properties = parse_comma_list(stream, TOKEN.RBRACE, parse_property, true)
  stream.consume(TOKEN.RBRACE)
  return ast.object_expression(properties, lbrace)
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

  local saved_loop, saved_switch = stream.loop_depth, stream.switch_depth
  stream.loop_depth, stream.switch_depth = 0, 0
  local body = parse_block_statement(stream)
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
