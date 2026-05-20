local cg = {}

-- ============================================================================
-- Utilities
-- ============================================================================

--- Escape a string for use inside double-quoted Lua string literals.
-- @param s (string) Raw string value
-- @return (string) Escaped string (without surrounding quotes)
function cg.escape_string(s)
  local out = {}
  for i = 1, #s do
    local c = s:sub(i, i)
    local b = string.byte(c)
    if c == "\\" then out[#out + 1] = "\\\\"
    elseif c == '"' then out[#out + 1] = '\\"'
    elseif c == "\n" then out[#out + 1] = "\\n"
    elseif c == "\r" then out[#out + 1] = "\\r"
    elseif c == "\t" then out[#out + 1] = "\\t"
    elseif b < 32 then out[#out + 1] = string.format("\\%03d", b)
    else out[#out + 1] = c end
  end
  return table.concat(out)
end

--- Produce indentation whitespace.
-- @param n (number) Indent level (each level = 2 spaces)
-- @return (string) Indentation string
function cg.pad(n)
  return string.rep("  ", n)
end

-- ============================================================================
-- Statements
-- ============================================================================

--- Emit a local variable declaration statement.
-- @param name (string) Variable name(s), e.g. "x" or "ok, err"
-- @param init (string|nil) Initializer expression, or nil for uninitialized
-- @param indent (number) Indentation level
-- @return (string) Formatted local declaration with trailing newline
function cg.local_decl(name, init, indent)
  if init then
    return cg.pad(indent) .. "local " .. name .. " = " .. init .. "\n"
  end
  return cg.pad(indent) .. "local " .. name .. "\n"
end

--- Emit a local function declaration statement.
-- @param name (string) Function name
-- @param params (string) Comma-separated parameter names
-- @param body (string) Function body (pre-formatted with indentation)
-- @param indent (number) Indentation level for declaration and closing end
-- @return (string) Formatted local function declaration with trailing newline
function cg.local_fn(name, params, body, indent)
  return cg.pad(indent) .. "local function " .. name .. "(" .. params .. ")\n"
    .. body .. cg.pad(indent) .. "end\n"
end

--- Emit an anonymous function expression.
-- @param params (string) Comma-separated parameter names
-- @param body (string) Function body (pre-formatted with indentation)
-- @param indent (number) Indentation level for the closing end
-- @return (string) Formatted function expression (no trailing newline)
function cg.fn_expr(params, body, indent)
  return "function(" .. params .. ")\n"
    .. body .. cg.pad(indent) .. "end"
end

--- Emit a return statement.
-- @param expr (string|nil) Return expression, or nil for bare return
-- @param indent (number) Indentation level
-- @return (string) Formatted return statement with trailing newline
function cg.return_stmt(expr, indent)
  if expr then
    return cg.pad(indent) .. "return " .. expr .. "\n"
  end
  return cg.pad(indent) .. "return\n"
end

--- Emit a break statement.
-- @param indent (number) Indentation level
-- @return (string) Formatted break statement with trailing newline
function cg.break_stmt(indent)
  return cg.pad(indent) .. "break\n"
end

--- Emit an expression statement.
-- @param expr (string) Expression code
-- @param indent (number) Indentation level
-- @return (string) Formatted expression statement with trailing newline
function cg.expr_stmt(expr, indent)
  return cg.pad(indent) .. expr .. "\n"
end

--- Emit a do...end block for scoping.
-- @param body (string) Block body (pre-formatted)
-- @param indent (number) Indentation level
-- @return (string) Formatted do block with trailing newline
function cg.do_block(body, indent)
  return cg.pad(indent) .. "do\n"
    .. body .. cg.pad(indent) .. "end\n"
end

--- Emit a while loop statement.
-- @param test (string) Loop condition expression
-- @param body (string) Loop body (pre-formatted)
-- @param indent (number) Indentation level
-- @return (string) Formatted while loop with trailing newline
function cg.while_stmt(test, body, indent)
  return cg.pad(indent) .. "while " .. test .. " do\n"
    .. body .. cg.pad(indent) .. "end\n"
end

--- Emit a repeat...until loop statement.
-- @param condition (string) Loop exit condition (loop stops when condition is true)
-- @param body (string) Loop body (pre-formatted)
-- @param indent (number) Indentation level
-- @return (string) Formatted repeat...until loop with trailing newline
function cg.repeat_until(condition, body, indent)
  return cg.pad(indent) .. "repeat\n"
    .. body .. cg.pad(indent) .. "until " .. condition .. "\n"
end

--- Emit a generic for..in loop statement.
-- @param vars (string) Comma-separated variable names
-- @param iter (string) Iterator expression
-- @param body (string) Loop body (pre-formatted)
-- @param indent (number) Indentation level
-- @return (string) Formatted for..in loop with trailing newline
function cg.for_in_stmt(vars, iter, body, indent)
  return cg.pad(indent) .. "for " .. vars .. " in " .. iter .. " do\n"
    .. body .. cg.pad(indent) .. "end\n"
end

--- Emit a numeric for loop statement.
-- @param var (string) Loop variable name
-- @param start (string) Start expression
-- @param stop (string) Stop expression
-- @param body (string) Loop body (pre-formatted)
-- @param indent (number) Indentation level
-- @return (string) Formatted numeric for loop with trailing newline
function cg.numeric_for(var, start, stop, body, indent)
  return cg.pad(indent) .. "for " .. var .. " = " .. start .. ", " .. stop .. " do\n"
    .. body .. cg.pad(indent) .. "end\n"
end

--- Emit an if/elseif/else/end statement.
-- @param test (string) Condition expression
-- @param then_body (string) Then branch body (pre-formatted)
-- @param elseifs (table|nil) List of {test=string, body=string} for elseif clauses
-- @param else_body (string|nil) Else branch body (pre-formatted)
-- @param indent (number) Indentation level
-- @return (string) Formatted if statement with trailing newline
function cg.if_stmt(test, then_body, elseifs, else_body, indent)
  local code = cg.pad(indent) .. "if " .. test .. " then\n" .. then_body
  if elseifs then
    for _, clause in ipairs(elseifs) do
      code = code .. cg.pad(indent) .. "elseif " .. clause.test .. " then\n" .. clause.body
    end
  end
  if else_body then
    code = code .. cg.pad(indent) .. "else\n" .. else_body
  end
  return code .. cg.pad(indent) .. "end\n"
end

-- ============================================================================
-- Expressions
-- ============================================================================

--- Emit a number literal.
-- @param n (number) Numeric value
-- @return (string) Formatted number literal
function cg.number(n)
  return tostring(n)
end

--- Emit a string literal.
-- @param s (string) Raw string value
-- @return (string) Formatted string literal with double quotes
function cg.string(s)
  return '"' .. cg.escape_string(s) .. '"'
end

--- Emit a boolean literal.
-- @param b (boolean) Boolean value
-- @return (string) "true" or "false"
function cg.boolean(b)
  return b and "true" or "false"
end

--- Emit a nil literal.
-- @return (string) "nil"
function cg.nil_val()
  return "nil"
end

--- Emit an identifier.
-- @param name (string) Identifier name
-- @return (string) The identifier as-is
function cg.ident(name)
  return name
end

--- Emit a parenthesized expression.
-- @param expr (string) Inner expression
-- @return (string) Parenthesized expression
function cg.paren(expr)
  return "(" .. expr .. ")"
end

--- Emit a bracket key for use inside a table constructor.
-- @param expr (string) Key expression
-- @return (string) Bracketed key, e.g. ["key"]
function cg.bracket_key(expr)
  return "[" .. expr .. "]"
end

--- Emit a binary operation expression.
-- @param op (string) Operator string
-- @param left (string) Left operand expression
-- @param right (string) Right operand expression
-- @return (string) Formatted binary expression
function cg.binop(op, left, right)
  return left .. " " .. op .. " " .. right
end

--- Emit a unary operation expression.
-- @param op (string) Operator ("not" or "-")
-- @param expr (string) Operand expression
-- @return (string) Formatted unary expression
function cg.unop(op, expr)
  if op == "not" then return "not " .. expr end
  return op .. expr
end

--- Emit a function call expression.
-- @param fn_expr (string) Function expression
-- @param args (table) List of argument expression strings
-- @return (string) Formatted function call
function cg.call(fn_expr, args)
  return fn_expr .. "(" .. table.concat(args, ", ") .. ")"
end

--- Emit a dot member access expression.
-- @param obj (string) Object expression
-- @param prop (string) Property name
-- @return (string) Formatted member access
function cg.member_dot(obj, prop)
  return obj .. "." .. prop
end

--- Emit a bracket member access expression.
-- @param obj (string) Object expression
-- @param index (string) Index expression
-- @return (string) Formatted index access
function cg.member_index(obj, index)
  return obj .. "[" .. index .. "]"
end

--- Emit a table constructor with key-value pairs.
-- @param fields (table) List of {key=string, value=string}
-- @return (string) Formatted table constructor
function cg.object(fields)
  if #fields == 0 then return "{}" end
  local parts = {}
  for _, f in ipairs(fields) do
    parts[#parts + 1] = f.key .. " = " .. f.value
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

--- Emit a table constructor with sequential values.
-- @param elems (table) List of expression strings
-- @return (string) Formatted table constructor
function cg.array(elems)
  return "{" .. table.concat(elems, ", ") .. "}"
end

-- ============================================================================
-- Goto and labels
-- ============================================================================

--- Emit a goto statement.
-- @param label (string) Label name
-- @param indent (number) Indentation level
-- @return (string) Formatted goto statement with trailing newline
function cg.goto_stmt(label, indent)
  return cg.pad(indent) .. "goto " .. label .. "\n"
end

--- Emit a goto label.
-- @param name (string) Label name
-- @param indent (number) Indentation level
-- @return (string) Formatted label with trailing newline
function cg.label(name, indent)
  return cg.pad(indent) .. "::" .. name .. "::\n"
end

-- ============================================================================
-- Inline statements (for IIFE bodies)
-- ============================================================================

--- Emit a local declaration as an inline statement (no trailing newline).
-- @param name (string) Variable name
-- @param init (string) Initializer expression
-- @return (string) Inline local declaration
function cg.local_inline(name, init)
  return "local " .. name .. " = " .. init
end

--- Emit a return as an inline statement (no trailing newline).
-- @param expr (string) Return expression
-- @return (string) Inline return statement
function cg.return_inline(expr)
  return "return " .. expr
end

--- Emit an inline if-return-else-return-end statement (for IIFE bodies).
-- @param test (string) Condition expression
-- @param consequent (string) Return value if truthy
-- @param alternate (string) Return value if falsy
-- @return (string) Inline if-return statement
function cg.inline_if_return(test, consequent, alternate)
  return "if " .. test .. " then return " .. consequent
    .. " else return " .. alternate .. " end"
end

-- ============================================================================
-- Compound: IIFE
-- ============================================================================

--- Emit an immediately-invoked function expression (IIFE).
-- @param stmts (table) List of inline statement strings
-- @return (string) Formatted IIFE expression
function cg.iife(stmts)
  return "(function() " .. table.concat(stmts, "; ") .. " end)()"
end

return cg
