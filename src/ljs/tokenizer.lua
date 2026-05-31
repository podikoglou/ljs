-- ljs.tokenizer — JavaScript subset tokenizer.
--
-- Converts source string into an array of tokens and provides a forward-only
-- token stream consumer for the parser. Pure tokenizer — no AST knowledge.
-- All errors are ParseError tables {message, line, col} with __tostring metamethod,
-- thrown via error()/pcall().
--
-- Usage:
--   local tokenizer = require("ljs.tokenizer")
--   local tokens, err = tokenizer.tokenize("let x = 42;")
--   if not tokens then print(err) end

local M = {}

local utf8 = require("ljs.utf8")

local codepoint_to_utf8 = utf8.codepoint_to_utf8

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
  VAR = "var",
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
-- to distinguish keywords from plain identifiers.
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
  ["var"] = TOKEN.VAR,
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

M.KEYWORDS = KEYWORDS

-- Reverse set of all unique token types produced by KEYWORDS.
-- Used by is_property_name() to accept keywords as property names (obj.return, {class: 1}).
local KEYWORD_TOKEN_TYPES = {}
for _, tok_type in pairs(KEYWORDS) do
  KEYWORD_TOKEN_TYPES[tok_type] = true
end

M.KEYWORD_TOKEN_TYPES = KEYWORD_TOKEN_TYPES

-- Operator dispatch table keyed by leading character.
-- Each value is an array of {s, n, tok} sorted longest-first so that
-- multi-character operators are tried before their single-character prefixes.
local OP_TABLE = {
  ["("] = { { s = "(",  n = 1, tok = TOKEN.LPAREN } },
  [")"] = { { s = ")",  n = 1, tok = TOKEN.RPAREN } },
  ["{"] = { { s = "{",  n = 1, tok = TOKEN.LBRACE } },
  ["}"] = { { s = "}",  n = 1, tok = TOKEN.RBRACE } },
  ["["] = { { s = "[",  n = 1, tok = TOKEN.LBRACKET } },
  ["]"] = { { s = "]",  n = 1, tok = TOKEN.RBRACKET } },
  [","] = { { s = ",",  n = 1, tok = TOKEN.COMMA } },
  [";"] = { { s = ";",  n = 1, tok = TOKEN.SEMICOLON } },
  [":"] = { { s = ":",  n = 1, tok = TOKEN.COLON } },
  ["."] = {
    { s = "...", n = 3, tok = TOKEN.ELLIPSIS },
    { s = ".",   n = 1, tok = TOKEN.DOT },
  },
  ["?"] = { { s = "?",  n = 1, tok = TOKEN.QUESTION } },
  ["+"] = {
    { s = "++", n = 2, tok = TOKEN.INCREMENT },
    { s = "+=", n = 2, tok = TOKEN.PLUS_ASSIGN },
    { s = "+",  n = 1, tok = TOKEN.PLUS },
  },
  ["-"] = {
    { s = "--", n = 2, tok = TOKEN.DECREMENT },
    { s = "-=", n = 2, tok = TOKEN.MINUS_ASSIGN },
    { s = "-",  n = 1, tok = TOKEN.MINUS },
  },
  ["*"] = {
    { s = "**=", n = 3, tok = TOKEN.STARSTAR_ASSIGN },
    { s = "**",  n = 2, tok = TOKEN.STARSTAR },
    { s = "*=",  n = 2, tok = TOKEN.STAR_ASSIGN },
    { s = "*",   n = 1, tok = TOKEN.STAR },
  },
  ["/"] = {
    { s = "/=", n = 2, tok = TOKEN.SLASH_ASSIGN },
    { s = "/",  n = 1, tok = TOKEN.SLASH },
  },
  ["%"] = {
    { s = "%=", n = 2, tok = TOKEN.PERCENT_ASSIGN },
    { s = "%",  n = 1, tok = TOKEN.PERCENT },
  },
  ["="] = {
    { s = "===", n = 3, tok = TOKEN.EQ },
    { s = "=>",  n = 2, tok = TOKEN.ARROW },
    { s = "==",  n = 2, tok = TOKEN.LOOSE_EQ },
    { s = "=",   n = 1, tok = TOKEN.ASSIGN },
  },
  ["!"] = {
    { s = "!==", n = 3, tok = TOKEN.NEQ },
    { s = "!=",  n = 2, tok = TOKEN.LOOSE_NEQ },
    { s = "!",   n = 1, tok = TOKEN.NOT },
  },
  ["~"] = { { s = "~",  n = 1, tok = TOKEN.TILDE } },
  ["^"] = {
    { s = "^=", n = 2, tok = TOKEN.BITWISE_XOR_ASSIGN },
    { s = "^",  n = 1, tok = TOKEN.BITWISE_XOR },
  },
  ["<"] = {
    { s = "<<=", n = 3, tok = TOKEN.LEFT_SHIFT_ASSIGN },
    { s = "<<",  n = 2, tok = TOKEN.LEFT_SHIFT },
    { s = "<=",  n = 2, tok = TOKEN.LTE },
    { s = "<",   n = 1, tok = TOKEN.LT },
  },
  [">"] = {
    { s = ">>>=", n = 4, tok = TOKEN.UNSIGNED_RIGHT_SHIFT_ASSIGN },
    { s = ">>>",  n = 3, tok = TOKEN.UNSIGNED_RIGHT_SHIFT },
    { s = ">>=",  n = 3, tok = TOKEN.RIGHT_SHIFT_ASSIGN },
    { s = ">>",   n = 2, tok = TOKEN.RIGHT_SHIFT },
    { s = ">=",   n = 2, tok = TOKEN.GTE },
    { s = ">",    n = 1, tok = TOKEN.GT },
  },
  ["&"] = {
    { s = "&&", n = 2, tok = TOKEN.AND },
    { s = "&=", n = 2, tok = TOKEN.BITWISE_AND_ASSIGN },
    { s = "&",  n = 1, tok = TOKEN.BITWISE_AND },
  },
  ["|"] = {
    { s = "||", n = 2, tok = TOKEN.OR },
    { s = "|=", n = 2, tok = TOKEN.BITWISE_OR_ASSIGN },
    { s = "|",  n = 1, tok = TOKEN.BITWISE_OR },
  },
}

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
          elseif ch:match("[0-7]") then
            local max_digits = (tonumber(ch) <= 3) and 3 or 2
            local octal = ch
            local extra_to_consume = 0
            for i = 1, max_digits - 1 do
              local peek_pos = pos + i
              if peek_pos > len then
                break
              end
              local next_ch = source:sub(peek_pos, peek_pos)
              if not next_ch:match("[0-7]") then
                break
              end
              octal = octal .. next_ch
              extra_to_consume = extra_to_consume + 1
            end
            if extra_to_consume > 0 then
              advance(extra_to_consume)
            end
            ch = string.char(tonumber(octal, 8))
          elseif ch == "8" or ch == "9" then
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
          elseif ch == "u" then
            advance()
            local hex_str = ""
            if current() == "{" then
              advance()
              while current() and current() ~= "}" do
                local hc = current()
                if not hc:match("%x") then
                  return nil, make_parse_error("Invalid unicode escape sequence", line, col)
                end
                hex_str = hex_str .. hc
                advance()
              end
              if not current() or #hex_str == 0 or #hex_str > 6 then
                return nil, make_parse_error("Invalid unicode escape sequence", line, col)
              end
            else
              for i = 1, 4 do
                local hc = current()
                if not hc or not hc:match("%x") then
                  return nil, make_parse_error("Invalid unicode escape sequence", line, col)
                end
                hex_str = hex_str .. hc
                if i < 4 then
                  advance()
                end
              end
            end
            local cp = tonumber(hex_str, 16)
            if not cp or cp > 0x10FFFF then
              return nil, make_parse_error("Invalid unicode codepoint", line, col)
            end
            ch = codepoint_to_utf8(cp)
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
                  if current() then
                    advance()
                  end
                end
                if current() then
                  advance()
                end
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
                    if current() then
                      advance()
                    end
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
          elseif esc:match("[0-7]") then
            local max_digits = (tonumber(esc) <= 3) and 3 or 2
            local octal = esc
            local extra_to_consume = 0
            for i = 1, max_digits - 1 do
              local peek_pos = pos + i
              if peek_pos > len then
                break
              end
              local next_ch = source:sub(peek_pos, peek_pos)
              if not next_ch:match("[0-7]") then
                break
              end
              octal = octal .. next_ch
              extra_to_consume = extra_to_consume + 1
            end
            if extra_to_consume > 0 then
              advance(extra_to_consume)
            end
            chars[#chars + 1] = string.char(tonumber(octal, 8))
          elseif esc == "8" or esc == "9" then
            chars[#chars + 1] = esc
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
          elseif esc == "u" then
            advance()
            local hex_str = ""
            if current() == "{" then
              advance()
              while current() and current() ~= "}" do
                local hc = current()
                if not hc:match("%x") then
                  return nil, make_parse_error("Invalid unicode escape sequence", line, col)
                end
                hex_str = hex_str .. hc
                advance()
              end
              if not current() or #hex_str == 0 or #hex_str > 6 then
                return nil, make_parse_error("Invalid unicode escape sequence", line, col)
              end
            else
              for i = 1, 4 do
                local hc = current()
                if not hc or not hc:match("%x") then
                  return nil, make_parse_error("Invalid unicode escape sequence", line, col)
                end
                hex_str = hex_str .. hc
                if i < 4 then
                  advance()
                end
              end
            end
            local cp = tonumber(hex_str, 16)
            if not cp or cp > 0x10FFFF then
              return nil, make_parse_error("Invalid unicode codepoint", line, col)
            end
            chars[#chars + 1] = codepoint_to_utf8(cp)
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
        make_token(
          TOKEN.TEMPLATE_LITERAL,
          { quasis = quasis, expression_sources = expression_sources },
          line,
          start_col
        )
      )

    -- Punctuation and operators (table-driven dispatch).
    else
      local op_group = OP_TABLE[c]
      if op_group then
        for _, entry in ipairs(op_group) do
          if lookahead(entry.n) == entry.s then
            table.insert(tokens, make_token(entry.tok))
            advance(entry.n)
            break
          end
        end
      else
        return nil, make_parse_error(
          string.format("Unexpected character '%s'", c), line, col)
      end
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

-- ============================================================================
-- EXPORTS
-- ============================================================================

M.ParseError = ParseError
M.is_parse_error = is_parse_error
M.make_parse_error = make_parse_error
M.parse_error = parse_error

return M
