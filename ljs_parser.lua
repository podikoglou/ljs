-- ljs_parser - JavaScript subset parser for Lua
-- Parses a well-defined subset of JavaScript into a Lua table-based AST.
--
-- Supported: let/const/var, functions, arrow functions, objects, arrays,
-- arithmetic/comparison/logical/assignment operators, if/else, while, for...of,
-- throw/try/catch, console.log, member access, method calls, comments.
--
-- Excluded (errors): this, async/await, typeof, instanceof, == (use ===),
-- regex literals, prototypal inheritance, Promises.
--
-- Usage:
--   local parser = require("ljs_parser")
--   local ast, err = parser.parse("let x = 42; console.log(x);")
--   if not ast then print(err) end

local ljs = {}

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
  QUESTION = "?",

  -- Arithmetic
  PLUS = "+",
  MINUS = "-",
  STAR = "*",
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
  -- Assignment
  ASSIGN = "=",
  -- Compound assignment
  PLUS_ASSIGN = "+=",
  MINUS_ASSIGN = "-=",
  STAR_ASSIGN = "*=",
  SLASH_ASSIGN = "/=",
  PERCENT_ASSIGN = "%=",
  -- Unary
  NOT = "!",
  -- Update
  INCREMENT = "++",
  DECREMENT = "--",
  -- Arrow function
  ARROW = "=>",

  UNDEFINED = "Undefined",
  -- Error-triggering keywords: tokenized normally but rejected by the parser
  THIS = "this",
  ASYNC = "async",
  AWAIT = "await",
  TYPEOF = "typeof",
  INSTANCEOF = "instanceof",
}

ljs.TOKEN = TOKEN

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
  ["throw"] = TOKEN.THROW,
  ["try"] = TOKEN.TRY,
  ["catch"] = TOKEN.CATCH,
  ["return"] = TOKEN.RETURN,
  ["true"] = TOKEN.BOOLEAN,
  ["false"] = TOKEN.BOOLEAN,
  ["null"] = TOKEN.NULL,
  ["undefined"] = TOKEN.UNDEFINED,
  ["var"] = TOKEN.LET,
  ["this"] = TOKEN.THIS,
  ["async"] = TOKEN.ASYNC,
  ["await"] = TOKEN.AWAIT,
  ["typeof"] = TOKEN.TYPEOF,
  ["instanceof"] = TOKEN.INSTANCEOF,
}

-- ============================================================================
-- TOKENIZER
-- ============================================================================
-- Converts source string into an array of tokens.
-- Each token is {type, value, line, col} where:
--   - value is present for identifiers/keywords (string), numbers (number),
--     booleans (true/false), strings (unescaped string). Absent for punctuation.
--   - line/col are 1-based source positions.
-- Returns: tokens array on success, nil + error string on failure.

--- Tokenize JavaScript source code into a list of tokens.
-- @param source (string) The JavaScript source code to tokenize
-- @return tokens (table|nil) Array of token tables, or nil on error
-- @return err (string|nil) Error message if tokenization failed
local function tokenize(source)
  local tokens = {}
  local pos = 1
  local line = 1
  local col = 1
  local len = #source

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
    while current() do
      local c = current()
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
      return false, "Unterminated multi-line comment"
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
      elseif skip_multi_line_comment() then
        skip_whitespace()
      else
        break
      end
    end
  end

  local function make_token(type, value)
    return {
      type = type,
      value = value,
      line = line,
      col = col,
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
    skip_trivia()
    if pos > len then break end

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
        table.insert(tokens, make_token(TOKEN.BOOLEAN, text == "true"))
      elseif token_type == TOKEN.NULL then
        table.insert(tokens, make_token(TOKEN.NULL, nil))
      elseif token_type == TOKEN.UNDEFINED then
        table.insert(tokens, make_token(TOKEN.UNDEFINED, nil))
      else
        table.insert(tokens, make_token(token_type, text))
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
          return nil, string.format("Invalid hex literal at line %d, col %d", line, start_col)
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
        return nil, string.format("Invalid number literal at line %d, col %d", line, start_col)
      end
      table.insert(tokens, make_token(TOKEN.NUMBER, num))

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
          advance()
          found_closing = true
          break
        elseif ch == "\n" then
          return nil, string.format("Unterminated string literal at line %d, col %d", line, start_col)
        else
          table.insert(chars, ch)
          advance()
        end
      end
      if not found_closing then
        return nil, string.format("Unterminated string literal at line %d, col %d", line, start_col)
      end
      local str = table.concat(chars, "")
      table.insert(tokens, make_token(TOKEN.STRING, str))

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
      if lookahead(2) == "*=" then
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
          return nil, string.format("Use === instead of == at line %d, col %d", line, col)
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
    -- & and | only appear as && and || in this subset. Lone & or | is an error.
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

    else
      return nil, string.format("Unexpected character '%s' at line %d, col %d", c, line, col)
    end
  end

  -- Guarantee the stream always ends with EOF.
  if #tokens == 0 or tokens[#tokens].type ~= TOKEN.EOF then
    table.insert(tokens, make_token(TOKEN.EOF))
  end

  return tokens
end

ljs.tokenize = tokenize

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

ljs.make_token_stream = make_token_stream

-- ============================================================================
-- AST BUILDERS
-- ============================================================================
-- Factory functions for each AST node type. All return a table with a `type`
-- field. See AGENTS.md for the full AST specification.

--- @param name (string) Variable/parameter name
--- @return table {type="Identifier", name=name}
local function identifier(name, token)
  return { type = "Identifier", name = name }
end

--- @param value (number) Numeric value
--- @return table {type="NumberLiteral", value=value}
local function number_literal(value, token)
  return { type = "NumberLiteral", value = value }
end

--- @param value (string) Unescaped string content
--- @return table {type="StringLiteral", value=value}
local function string_literal(value, token)
  return { type = "StringLiteral", value = value }
end

--- @param value (boolean) true or false
--- @return table {type="BooleanLiteral", value=value}
local function boolean_literal(value, token)
  return { type = "BooleanLiteral", value = value }
end

--- @return table {type="NullLiteral"}
local function null_literal(token)
  return { type = "NullLiteral" }
end

--- @return table {type="UndefinedLiteral"}
local function undefined_literal(token)
  return { type = "UndefinedLiteral" }
end

--- @param operator (string) One of: + - * / % === !== < > <= >= && || = += -= *= /= %=
--- @param left (table) Left-hand AST expression
--- @param right (table) Right-hand AST expression
--- @return table {type="BinaryExpression", operator, left, right}
local function binary_expression(operator, left, right)
  return { type = "BinaryExpression", operator = operator, left = left, right = right }
end

--- @param operator (string) "!" or "-"
--- @param argument (table) The operand AST expression
--- @return table {type="UnaryExpression", operator, argument}
local function unary_expression(operator, argument)
  return { type = "UnaryExpression", operator = operator, argument = argument }
end

--- @param operator (string) "++" or "--"
--- @param argument (table) The operand AST expression
--- @param prefix (boolean) true for prefix (++x), false for postfix (x++)
--- @return table {type="UpdateExpression", operator, argument, prefix}
local function update_expression(operator, argument, prefix)
  return { type = "UpdateExpression", operator = operator, argument = argument, prefix = prefix }
end

--- @param test (table) Condition expression
--- @param consequent (table) Expression if truthy
--- @param alternate (table) Expression if falsy
--- @return table {type="ConditionalExpression", test, consequent, alternate}
local function conditional_expression(test, consequent, alternate)
  return { type = "ConditionalExpression", test = test, consequent = consequent, alternate = alternate }
end

--- @param callee (table) Expression being called
--- @param arguments (table) Array of argument expressions
--- @return table {type="CallExpression", callee, arguments}
local function call_expression(callee, arguments)
  return { type = "CallExpression", callee = callee, arguments = arguments }
end

--- @param object (table) Object expression
--- @param property (table) Property expression (Identifier or computed expression)
--- @param computed (boolean) true for bracket notation obj[expr], false for dot notation obj.prop
--- @return table {type="MemberExpression", object, property, computed}
local function member_expression(object, property, computed)
  return { type = "MemberExpression", object = object, property = property, computed = computed }
end

--- @param kind (string) "let" or "const"
--- @param declarations (table) Array of VariableDeclarator nodes
--- @return table {type="VariableDeclaration", kind, declarations}
local function variable_declaration(kind, declarations)
  return { type = "VariableDeclaration", kind = kind, declarations = declarations }
end

--- @param name (table) Identifier node
--- @param init (table|nil) Initializer expression, or nil
--- @return table {type="VariableDeclarator", name, init}
local function variable_declarator(name, init)
  return { type = "VariableDeclarator", name = name, init = init }
end

--- @param name (string) Function name
--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement node
--- @return table {type="FunctionDeclaration", name, params, body}
local function function_declaration(name, params, body)
  return { type = "FunctionDeclaration", name = name, params = params, body = body }
end

--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement node
--- @return table {type="FunctionExpression", params, body}
local function function_expression(params, body)
  return { type = "FunctionExpression", params = params, body = body }
end

--- Arrow functions are desugared: expression bodies become BlockStatement
--- wrapping a single ExpressionStatement.
--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement (always, even for expression bodies)
--- @return table {type="ArrowFunctionExpression", params, body}
local function arrow_function_expression(params, body)
  return { type = "ArrowFunctionExpression", params = params, body = body }
end

--- @param test (table) Condition expression
--- @param consequent (table) Statement to run if truthy
--- @param alternate (table|nil) else branch, or nil
--- @return table {type="IfStatement", test, consequent, alternate}
local function if_statement(test, consequent, alternate)
  return { type = "IfStatement", test = test, consequent = consequent, alternate = alternate }
end

--- @param test (table) Condition expression
--- @param body (table) Statement to repeat
--- @return table {type="WhileStatement", test, body}
local function while_statement(test, body)
  return { type = "WhileStatement", test = test, body = body }
end

--- @param body (table) Statement to repeat
--- @param test (table) Condition expression
--- @return table {type="DoWhileStatement", body, test}
local function do_while_statement(body, test)
  return { type = "DoWhileStatement", body = body, test = test }
end

--- @param left (table) VariableDeclaration or expression (the loop variable)
--- @param right (table) Iterable expression
--- @param body (table) Statement to repeat
--- @return table {type="ForOfStatement", left, right, body}
local function for_of_statement(left, right, body)
  return { type = "ForOfStatement", left = left, right = right, body = body }
end

--- @param left (table) VariableDeclaration or expression (the loop variable)
--- @param right (table) Object expression to iterate over
--- @param body (table) Statement to repeat
--- @return table {type="ForInStatement", left, right, body}
local function for_in_statement(left, right, body)
  return { type = "ForInStatement", left = left, right = right, body = body }
end

--- @param init (table|nil) Initialization expression or VariableDeclaration
--- @param test (table|nil) Loop condition expression
--- @param update (table|nil) Update expression evaluated after each iteration
--- @param body (table) Statement to repeat
--- @return table {type="ForStatement", init, test, update, body}
local function for_statement(init, test, update, body)
  return { type = "ForStatement", init = init, test = test, update = update, body = body }
end

--- @param body (table) Array of statement nodes
--- @return table {type="BlockStatement", body}
local function block_statement(body)
  return { type = "BlockStatement", body = body }
end

--- @param expression (table) The expression being evaluated for side effects
--- @return table {type="ExpressionStatement", expression}
local function expression_statement(expression)
  return { type = "ExpressionStatement", expression = expression }
end

--- @param argument (table) The value to throw
--- @return table {type="ThrowStatement", argument}
local function throw_statement(argument)
  return { type = "ThrowStatement", argument = argument }
end

--- @param block (table) BlockStatement (the try body)
--- @param handler (table|nil) CatchClause node, or nil
--- @return table {type="TryStatement", block, handler}
local function try_statement(block, handler)
  return { type = "TryStatement", block = block, handler = handler }
end

--- @param param (table) Identifier node for the caught error
--- @param body (table) BlockStatement for catch body
--- @return table {type="CatchClause", param, body}
local function catch_clause(param, body)
  return { type = "CatchClause", param = param, body = body }
end

--- @param argument (table|nil) Return value expression, or nil for bare return
--- @return table {type="ReturnStatement", argument}
local function return_statement(argument)
  return { type = "ReturnStatement", argument = argument }
end

--- @param properties (table) Array of Property nodes
--- @return table {type="ObjectExpression", properties}
local function object_expression(properties)
  return { type = "ObjectExpression", properties = properties }
end

--- @param key (table) Identifier or StringLiteral node
--- @param value (table) Expression node
--- @param computed (boolean) true if key is a computed [expr] property
--- @return table {type="Property", key, value, computed}
local function property(key, value, computed)
  return { type = "Property", key = key, value = value, computed = computed or false }
end

--- @param elements (table) Array of expression nodes
--- @return table {type="ArrayExpression", elements}
local function array_expression(elements)
  return { type = "ArrayExpression", elements = elements }
end

--- @param discriminant (table) Expression being matched against
--- @param cases (table) Array of SwitchCase nodes
--- @return table {type="SwitchStatement", discriminant, cases}
local function switch_statement(discriminant, cases)
  return { type = "SwitchStatement", discriminant = discriminant, cases = cases }
end

--- @param test (table|nil) Case value expression, or nil for default
--- @param consequent (table) Array of statement nodes in this case
--- @return table {type="SwitchCase", test, consequent}
local function switch_case(test, consequent)
  return { type = "SwitchCase", test = test, consequent = consequent }
end

--- @return table {type="BreakStatement"}
local function break_statement()
  return { type = "BreakStatement" }
end

-- ============================================================================
-- PARSER
-- ============================================================================
-- Top-down recursive descent parser with Pratt parsing for expressions.
--
-- Architecture:
--   ljs.parse(source)
--     -> tokenize(source) -> make_token_stream(tokens) -> parse_statement*
--
-- Statements are dispatched by the first token (let/const, if, while, etc).
-- Expressions use precedence climbing (Pratt parsing) with a precedence table.
--
-- Forward declarations are required because Lua's local functions must be
-- declared before use, and many parse functions are mutually recursive.

local parse_switch_statement
local parse_break_statement
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
function ljs.parse(source)
  local tokens, tokenize_err = tokenize(source)
  if not tokens then
    return nil, "parse error: " .. tokenize_err
  end

  local stream = make_token_stream(tokens)

  local ok, result = pcall(function()
    local statements = {}
    while not stream.eof() do
      local stmt, err = parse_statement(stream)
      if not stmt then
        error(err, 0)
      end
      table.insert(statements, stmt)
    end
    return { type = "Program", body = statements }
  end)

  if ok then
    return result
  end
  return nil, "parse error: " .. tostring(result)
end

--- Parse a pre-built token array into an AST.
-- Bypasses tokenization — takes the token array directly.
-- Useful for testing parser grammar rules in isolation from the tokenizer,
-- or for feeding tokens from an alternative source.
-- @param tokens (table) Array of token tables {type, value?, line, col}
-- @return ast (table) The AST root node (Program)
-- @return err (string) Error message if parsing failed
function ljs.parse_tokens(tokens)
  local stream = make_token_stream(tokens)

  local ok, result = pcall(function()
    local statements = {}
    while not stream.eof() do
      local stmt, err = parse_statement(stream)
      if not stmt then
        error(err, 0)
      end
      table.insert(statements, stmt)
    end
    return { type = "Program", body = statements }
  end)

  if ok then
    return result
  end
  return nil, "parse error: " .. tostring(result)
end

-- ============================================================================
-- BANNED KEYWORD CHECK
-- ============================================================================

local BANNED_KEYWORDS = {
  [TOKEN.THIS] = "this",
  [TOKEN.ASYNC] = "async",
  [TOKEN.AWAIT] = "await",
  [TOKEN.TYPEOF] = "typeof",
  [TOKEN.INSTANCEOF] = "instanceof",
}

--- Check if the current token is a banned keyword and return an error message.
-- @param stream (table) Token stream
-- @return (string|nil) Error message if banned keyword found, nil otherwise
local function check_banned(stream)
  local kw = BANNED_KEYWORDS[stream.peek().type]
  if kw then
    return string.format("'%s' is not supported at line %d", kw, stream.peek().line)
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
  elseif stream.is(TOKEN.RETURN) then
    return parse_return_statement(stream)
  elseif stream.is(TOKEN.SWITCH) then
    return parse_switch_statement(stream)
  elseif stream.is(TOKEN.BREAK) then
    return parse_break_statement(stream)
  elseif stream.is(TOKEN.LBRACE) then
    return parse_block_statement(stream)
  else
    local banned_err = check_banned(stream)
    if banned_err then return nil, banned_err end
  -- Expression statement: any expression followed by optional semicolon.
    local expr, err = parse_expression(stream)
    if not expr then
      return nil, err
    end
    if stream.is(TOKEN.SEMICOLON) then
      stream.advance()
    end
    return expression_statement(expr)
  end
end

--- Parse a block: { stmt1; stmt2; ... }
-- Consumes the opening and closing braces.
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

--- Parse variable declaration: let/const/var x = expr, y = expr;
-- "var" is treated as "let" (maps to TOKEN.LET in the tokenizer).
-- Supports multiple declarators separated by commas.
-- Semicolon is optional.
function parse_variable_declaration(stream)
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
    local decl = parse_variable_declarator(stream)
    if not decl then return nil, "Expected variable declarator" end
    table.insert(declarations, decl)
    if not stream.is(TOKEN.COMMA) then break end
    stream.advance()
  end

  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end

  return variable_declaration(kind, declarations)
end

--- Parse a single variable declarator: name or name = init
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

--- Parse if/else: if (test) consequent [else alternate]
-- The consequent and alternate are single statements (can be blocks).
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

--- Parse while: while (test) body
function parse_while_statement(stream)
  stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  if not test then return nil, "Expected expression" end
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return while_statement(test, body)
end

--- Parse do...while: do body while (test);
-- Body always executes at least once. Semicolon after is optional.
-- @param stream (table) Token stream
-- @return (table|nil) DoWhileStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_do_while_statement(stream)
  stream.consume(TOKEN.DO)
  local body = parse_statement(stream)
  if not body then return nil, "Expected statement after 'do'" end
  stream.consume(TOKEN.WHILE)
  stream.consume(TOKEN.LPAREN)
  local test = parse_expression(stream)
  if not test then return nil, "Expected expression" end
  stream.consume(TOKEN.RPAREN)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return do_while_statement(body, test)
end

--- Parse for statement: dispatches between for...of, for...in, and C-style for(;;).
function parse_for_statement(stream)
  stream.consume(TOKEN.FOR)
  stream.consume(TOKEN.LPAREN)

  if stream.is(TOKEN.SEMICOLON) then
    return parse_c_style_for(stream, nil)
  end

  if stream.is(TOKEN.LET) or stream.is(TOKEN.CONST) then
    local decl = parse_variable_declaration(stream)

    if stream.is(TOKEN.OF) then
      return parse_for_of_from_left(stream, decl)
    end

    if stream.is(TOKEN.IN) then
      return parse_for_in_from_left(stream, decl)
    end

    return parse_c_style_for_from_test(stream, decl)
  end

  local expr = parse_expression(stream)
  if not expr then return nil, "Expected expression in for" end

  if stream.is(TOKEN.OF) then
    stream.consume(TOKEN.OF)
    local right = parse_expression(stream)
    if not right then return nil, "Expected expression after 'of'" end
    stream.consume(TOKEN.RPAREN)
    local body = parse_statement(stream)
    return for_of_statement(expr, right, body)
  end

  if stream.is(TOKEN.IN) then
    stream.consume(TOKEN.IN)
    local right = parse_expression(stream)
    if not right then return nil, "Expected expression after 'in'" end
    stream.consume(TOKEN.RPAREN)
    local body = parse_statement(stream)
    return for_in_statement(expr, right, body)
  end

  local init = expression_statement(expr)
  stream.consume(TOKEN.SEMICOLON)
  return parse_c_style_for_from_test(stream, init)
end

--- Parse C-style for loop starting from the first semicolon (no init clause).
-- @param stream (table) Token stream
-- @param init (table|nil) Initialization expression or nil
-- @return (table|nil) ForStatement AST node, or nil on error
function parse_c_style_for(stream, init)
  stream.consume(TOKEN.SEMICOLON)
  return parse_c_style_for_from_test(stream, init)
end

--- Parse C-style for loop test and update clauses after init has been consumed.
-- @param stream (table) Token stream
-- @param init (table|nil) Initialization expression or VariableDeclaration
-- @return (table|nil) ForStatement AST node, or nil on error
function parse_c_style_for_from_test(stream, init)
  local test
  if not stream.is(TOKEN.SEMICOLON) then
    test = parse_expression(stream)
    if not test then return nil, "Expected expression in for test" end
  end
  stream.consume(TOKEN.SEMICOLON)

  local update
  if not stream.is(TOKEN.RPAREN) then
    update = parse_expression(stream)
    if not update then return nil, "Expected expression in for update" end
  end
  stream.consume(TOKEN.RPAREN)

  local body = parse_statement(stream)
  return for_statement(init, test, update, body)
end

--- Parse for...of loop after the left-hand variable declaration has been consumed.
-- @param stream (table) Token stream
-- @param left (table) VariableDeclaration for the loop variable
-- @return (table|nil) ForOfStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_for_of_from_left(stream, left)
  stream.consume(TOKEN.OF)
  local right = parse_expression(stream)
  if not right then return nil, "Expected expression" end
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return for_of_statement(left, right, body)
end

--- Parse for...in loop after the left-hand variable declaration has been consumed.
-- Validates that there is exactly one declarator with no initializer.
-- @param stream (table) Token stream
-- @param left (table) VariableDeclaration for the loop variable
-- @return (table|nil) ForInStatement AST node, or nil on error
-- @return (string|nil) Error message if parsing failed
function parse_for_in_from_left(stream, left)
  if #left.declarations ~= 1 then
    return nil, "for-in loop requires a single variable"
  end
  if left.declarations[1].init ~= nil then
    return nil, "for-in loop variable cannot have an initializer"
  end
  stream.consume(TOKEN.IN)
  local right = parse_expression(stream)
  if not right then return nil, "Expected expression after 'in'" end
  stream.consume(TOKEN.RPAREN)
  local body = parse_statement(stream)
  return for_in_statement(left, right, body)
end

--- Parse throw: throw expression;
function parse_throw_statement(stream)
  stream.consume(TOKEN.THROW)
  local argument = parse_expression(stream)
  if not argument then return nil, "Expected expression" end
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return throw_statement(argument)
end

--- Parse try/catch: try { ... } catch (param) { ... }
-- The catch clause is optional (though rare to omit in practice).
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
-- Always has a name (unlike function expressions which can be anonymous).
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

--- Parse return: return expression?;
-- Bare return (no expression) is allowed — argument will be nil.
-- Heuristic: if next token is ; or }, there's no expression.
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

--- Parse switch: switch (expr) { case val: stmts default: stmts }
function parse_switch_statement(stream)
  stream.consume(TOKEN.SWITCH)
  stream.consume(TOKEN.LPAREN)
  local discriminant = parse_expression(stream)
  if not discriminant then return nil, "Expected expression after switch" end
  stream.consume(TOKEN.RPAREN)
  stream.consume(TOKEN.LBRACE)

  local cases = {}
  local has_default = false

  while not stream.is(TOKEN.RBRACE) and not stream.eof() do
    local test = nil

    if stream.is(TOKEN.CASE) then
      stream.advance()
      test = parse_expression(stream)
      if not test then return nil, "Expected expression after case" end
    elseif stream.is(TOKEN.DEFAULT) then
      if has_default then
        error(string.format("Duplicate default clause at line %d", stream.peek().line), 0)
      end
      has_default = true
      stream.advance()
    else
      error(string.format("Expected case or default, got %s at line %d, col %d",
        stream.peek().type, stream.peek().line, stream.peek().col), 0)
    end

    stream.consume(TOKEN.COLON)

    local consequent = {}
    while not stream.is(TOKEN.CASE)
        and not stream.is(TOKEN.DEFAULT)
        and not stream.is(TOKEN.RBRACE)
        and not stream.eof() do
      local stmt, err = parse_statement(stream)
      if not stmt then return nil, err end
      table.insert(consequent, stmt)
    end

    table.insert(cases, switch_case(test, consequent))
  end

  stream.consume(TOKEN.RBRACE)
  return switch_statement(discriminant, cases)
end

--- Parse break: break ;
function parse_break_statement(stream)
  stream.consume(TOKEN.BREAK)
  if stream.is(TOKEN.SEMICOLON) then
    stream.advance()
  end
  return break_statement()
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
      if not stream.is(TOKEN.COMMA) then break end
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
--   5   * / %
--   4   + -
--   3   === !== < > <= >=
--   2   &&
--   1   ||
--   0.5 = += -= *= /= %= (assignment and compound assignment, right-associative)
--
-- All binary operators except assignment and compound assignment are left-associative.

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
  [TOKEN.QUESTION] = 0.75,
  [TOKEN.ASSIGN] = 0.5,
  [TOKEN.PLUS_ASSIGN] = 0.5,
  [TOKEN.MINUS_ASSIGN] = 0.5,
  [TOKEN.STAR_ASSIGN] = 0.5,
  [TOKEN.SLASH_ASSIGN] = 0.5,
  [TOKEN.PERCENT_ASSIGN] = 0.5,
}

--- Entry point for expression parsing. Starts at minimum precedence 0.
function parse_expression(stream)
  return parse_binary_expression(stream, 0)
end

--- Pratt parser core: parse binary expressions with precedence climbing.
-- 1. Parse a unary expression (the left operand).
-- 2. Loop: while the next token is an operator with precedence >= min_precedence,
--    consume it and parse the right operand at a higher precedence level.
-- 3. Assignment is right-associative (right-recursive call to parse_expression
--    instead of parse_binary_expression with +1).
-- @param stream (table) Token stream
-- @param min_precedence (number) Minimum precedence to continue parsing
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

    -- Assignment and compound assignment are right-associative: a = b = c parses as a = (b = c).
    -- All other operators are left-associative: a + b + c parses as (a + b) + c.
    if op == TOKEN.ASSIGN or op == TOKEN.PLUS_ASSIGN or op == TOKEN.MINUS_ASSIGN
        or op == TOKEN.STAR_ASSIGN or op == TOKEN.SLASH_ASSIGN or op == TOKEN.PERCENT_ASSIGN then
      stream.advance()
      local right = parse_expression(stream)
      if not right then return nil end
      left = binary_expression(op, left, right)
    elseif op == TOKEN.QUESTION then
      stream.advance()
      local consequent = parse_expression(stream)
      if not consequent then return nil end
      stream.consume(TOKEN.COLON)
      local alternate = parse_expression(stream)
      if not alternate then return nil end
      left = conditional_expression(left, consequent, alternate)
    else
      stream.advance()
      -- Left-associative: parse right at precedence+1 so same-level ops
      -- bind to the left (they stop the inner parse, letting the outer loop consume them).
      local next_min = precedence + 1
      local right = parse_binary_expression(stream, next_min)
      if not right then return nil end
      left = binary_expression(op, left, right)
    end
  end

  return left
end

--- Parse unary prefix expressions: !expr, -expr, or +expr.
-- Unary operators have the highest precedence and are right-recursive
-- (so !!x parses as !(!(x))).
function parse_unary_expression(stream)
  if stream.is(TOKEN.NOT) or stream.is(TOKEN.MINUS) or stream.is(TOKEN.PLUS) then
    local op_token = stream.advance()
    local op = op_token.type
    local argument = parse_unary_expression(stream)
    if not argument then return nil end
    local op_str = op == TOKEN.NOT and "!" or op == TOKEN.PLUS and "+" or "-"
    return unary_expression(op_str, argument)
  elseif stream.is(TOKEN.INCREMENT) or stream.is(TOKEN.DECREMENT) then
    local op_token = stream.advance()
    local argument = parse_unary_expression(stream)
    if not argument then return nil end
    return update_expression(op_token.type, argument, true)
  end
  return parse_primary_expression(stream)
end

--- Parse primary (leaf) expressions — the atomic units that operators combine.
-- Handles: literals, identifiers, parenthesized exprs, arrow functions,
-- arrays, objects, function expressions.
-- Also rejects excluded keywords (this, async, etc.) in expression context.
function parse_primary_expression(stream)
  local banned_err = check_banned(stream)
  if banned_err then return nil, banned_err end

  local token = stream.peek()

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
  elseif stream.is(TOKEN.UNDEFINED) then
    stream.advance()
    return undefined_literal(token)
  elseif stream.is(TOKEN.IDENTIFIER) then
    return parse_identifier_or_call(stream)
  -- Parenthesized expression OR arrow function with parenthesized params.
  -- Disambiguation: scan ahead for matching ) then check if => follows.
  -- depth starts at 0 because peek_n(1) is the current token (the opening ().
  elseif stream.is(TOKEN.LPAREN) then
    local depth = 0
    local n = 0
    local found_arrow = false

    while true do
      local t = stream.peek_n(n + 1)
      if t.type == "EOF" then break end
      if t.type == TOKEN.LPAREN then depth = depth + 1
      elseif t.type == TOKEN.RPAREN then depth = depth - 1
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
      -- Arrow function with parenthesized params: (a, b) => body
      stream.advance()
      local params = {}
      if not stream.is(TOKEN.RPAREN) then
        while true do
          if stream.is(TOKEN.IDENTIFIER) then
            table.insert(params, identifier(stream.advance().value))
          else
            return nil, "Arrow function parameters must be identifiers"
          end
          if not stream.is(TOKEN.COMMA) then break end
          stream.advance()
        end
      end
      stream.consume(TOKEN.RPAREN)
      stream.consume(TOKEN.ARROW)
      local body = parse_arrow_function_body(stream)
      return arrow_function_expression(params, body)
    else
      -- Regular parenthesized expression: (expr)
      stream.advance()
      local expr = parse_expression(stream)
      stream.consume(TOKEN.RPAREN)
      return expr
    end
  elseif stream.is(TOKEN.LBRACKET) then
    return parse_array_literal(stream)
  elseif stream.is(TOKEN.LBRACE) then
    return parse_object_literal(stream)
  elseif stream.is(TOKEN.FUNCTION) then
    return parse_function_expression(stream)
  elseif stream.is(TOKEN.ARROW) then
    return nil, "Unexpected arrow token"
  else
    return nil, string.format("Unexpected token %s at line %d, col %d",
      token.type, token.line, token.col)
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
    local expr = parse_expression(stream)
    return block_statement({ return_statement(expr) })
  end
end

--- Parse postfix operations on an expression: .prop, [expr], (args).
-- Loops to handle chaining: obj.method()[0].field
-- This is shared between parse_identifier_or_call and parse_call_expression
-- to avoid duplicating the chaining logic.
-- @param stream (table) Token stream
-- @param expr (table) The expression to apply postfix ops to
-- @return (table) The resulting expression after all postfix ops
function parse_postfix(stream, expr)
  while true do
    if stream.is(TOKEN.DOT) then
      stream.advance()
      local prop_token = stream.consume(TOKEN.IDENTIFIER)
      expr = member_expression(expr, identifier(prop_token.value, prop_token), false)
    elseif stream.is(TOKEN.LBRACKET) then
      stream.advance()
      local prop = parse_expression(stream)
      if not prop then return nil end
      stream.consume(TOKEN.RBRACKET)
      expr = member_expression(expr, prop, true)
    elseif stream.is(TOKEN.LPAREN) then
      -- Call: consume (args) then continue chaining
      stream.advance()
      local args = {}
      if not stream.is(TOKEN.RPAREN) then
        while true do
          local arg = parse_expression(stream)
          if not arg then return nil end
          table.insert(args, arg)
          if not stream.is(TOKEN.COMMA) then break end
          stream.advance()
        end
      end
      stream.consume(TOKEN.RPAREN)
      expr = call_expression(expr, args)
    else
      break
    end
  end
  if stream.is(TOKEN.INCREMENT) then
    stream.advance()
    return update_expression("++", expr, false)
  elseif stream.is(TOKEN.DECREMENT) then
    stream.advance()
    return update_expression("--", expr, false)
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

  -- Bare identifier arrow function: x => x + 1
  if stream.is(TOKEN.ARROW) then
    stream.advance()
    local body = parse_arrow_function_body(stream)
    return arrow_function_expression({expr}, body)
  end

  return parse_postfix(stream, expr)
end

--- Parse call expression after callee has been identified.
-- Called when the caller has already determined that ( follows an expression.
-- Delegates to parse_postfix for further chaining after the call.
-- @param stream (table) Token stream
-- @param callee (table) The expression being called
function parse_call_expression(stream, callee)
  stream.consume(TOKEN.LPAREN)
  local arguments = {}
  if not stream.is(TOKEN.RPAREN) then
    while true do
      local arg = parse_expression(stream)
      if not arg then return nil end
      table.insert(arguments, arg)
      if not stream.is(TOKEN.COMMA) then break end
      stream.advance()
    end
  end
  stream.consume(TOKEN.RPAREN)
  local expr = call_expression(callee, arguments)
  return parse_postfix(stream, expr)
end

--- Parse array literal: [expr, expr, ...]
-- Empty arrays [] are valid.
function parse_array_literal(stream)
  stream.consume(TOKEN.LBRACKET)
  local elements = {}
  if not stream.is(TOKEN.RBRACKET) then
    while true do
      local element = parse_expression(stream)
      if not element then return nil end
      table.insert(elements, element)
      if not stream.is(TOKEN.COMMA) then break end
      stream.advance()
      if stream.is(TOKEN.RBRACKET) then break end
    end
  end
  stream.consume(TOKEN.RBRACKET)
  return array_expression(elements)
end

--- Parse object literal: { key: value, key: value, ... }
-- Keys can be identifiers or string literals.
-- Computed keys (e.g. {[expr]: value}) are not supported.
-- Empty objects {} are valid.
function parse_object_literal(stream)
  stream.consume(TOKEN.LBRACE)
  local properties = {}
  if not stream.is(TOKEN.RBRACE) then
    while true do
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
      if not stream.is(TOKEN.COMMA) then break end
      stream.advance()
      if stream.is(TOKEN.RBRACE) then break end
    end
  end
  stream.consume(TOKEN.RBRACE)
  return object_expression(properties)
end

--- Parse function expression: function(params) { body } or function name(params) { body }
-- Can be anonymous (no name) or named. Named function expressions produce
-- a FunctionExpression node with a `name` field (not FunctionDeclaration).
function parse_function_expression(stream)
  stream.consume(TOKEN.FUNCTION)

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
    return { type = "FunctionExpression", name = name, params = params, body = body }
  else
    return function_expression(params, body)
  end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return ljs
