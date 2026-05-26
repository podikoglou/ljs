-- ljs.ast — AST node constructors.
--
-- Factory functions for each AST node type. All return a table with a `type`
-- field. See AGENTS.md for the full AST specification.

local M = {}

--- @param name (string) Variable/parameter name
--- @return table {type="Identifier", name=name}
function M.identifier(name, token)
  return { type = "Identifier", name = name, line = token.line, col = token.col }
end

--- @param value (number) Numeric value
--- @return table {type="NumberLiteral", value=value}
function M.number_literal(value, token)
  return { type = "NumberLiteral", value = value, line = token.line, col = token.col }
end

--- @param value (string) Unescaped string content
--- @return table {type="StringLiteral", value=value}
function M.string_literal(value, token)
  return { type = "StringLiteral", value = value, line = token.line, col = token.col }
end

--- @param value (boolean) true or false
--- @return table {type="BooleanLiteral", value=value}
function M.boolean_literal(value, token)
  return { type = "BooleanLiteral", value = value, line = token.line, col = token.col }
end

--- @return table {type="NullLiteral"}
function M.null_literal(token)
  return { type = "NullLiteral", line = token.line, col = token.col }
end

--- @return table {type="UndefinedLiteral"}
function M.undefined_literal(token)
  return { type = "UndefinedLiteral", line = token.line, col = token.col }
end

--- @param operator (string) One of: + - * / % ** == != === !== < > <= >= && || in = += -= *= /= %= **= & | ^ << >> >>> &= |= ^= <<= >>= >>>=
--- @param left (table) Left-hand AST expression
--- @param right (table) Right-hand AST expression
--- @return table {type="BinaryExpression", operator, left, right}
function M.binary_expression(operator, left, right, token)
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
function M.unary_expression(operator, argument, token)
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
function M.is_valid_update_target(expr)
  local t = expr.type
  if t == "Identifier" then
    return true
  elseif t == "MemberExpression" then
    return true
  end
  return false
end

--- @param operator (string) "++" or "--"
--- @param argument (table) The operand AST expression
--- @param prefix (boolean) true for prefix (++x), false for postfix (x++)
--- @return table {type="UpdateExpression", operator, argument, prefix}
function M.update_expression(operator, argument, prefix, token)
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
function M.delete_expression(argument, token)
  return { type = "DeleteExpression", argument = argument, line = token.line, col = token.col }
end

--- @return table {type="ThisExpression"}
function M.this_expression(token)
  return { type = "ThisExpression", line = token.line, col = token.col }
end

--- @param argument (table) The operand AST expression
--- @return table {type="TypeofExpression", argument}
function M.typeof_expression(argument, token)
  return { type = "TypeofExpression", argument = argument, line = token.line, col = token.col }
end

--- @param callee (table) Constructor expression (Identifier or MemberExpression)
--- @param arguments (table) Array of argument expressions
--- @return table {type="NewExpression", callee, arguments}
function M.new_expression(callee, arguments, token)
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
function M.class_declaration(name, superClass, body, token)
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
function M.class_expression(name, superClass, body, token)
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
function M.method_definition(kind, key, value, static_flag, token)
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
function M.super_expression(token)
  return { type = "SuperExpression", line = token.line, col = token.col }
end

--- @param test (table) Condition expression
--- @param consequent (table) Expression if truthy
--- @param alternate (table) Expression if falsy
--- @return table {type="ConditionalExpression", test, consequent, alternate}
function M.conditional_expression(test, consequent, alternate, token)
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
function M.call_expression(callee, arguments, token)
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
function M.member_expression(object, property, computed, token)
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
function M.variable_declaration(kind, declarations, token)
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
function M.variable_declarator(name, init, token)
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
function M.function_declaration(name, params, body, token)
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
function M.function_expression(params, body, token)
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
function M.arrow_function_expression(params, body, token)
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
function M.if_statement(test, consequent, alternate, token)
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
function M.while_statement(test, body, token)
  return { type = "WhileStatement", test = test, body = body, line = token.line, col = token.col }
end

--- @param body (table) Statement to repeat
--- @param test (table) Condition expression
--- @return table {type="DoWhileStatement", body, test}
function M.do_while_statement(body, test, token)
  return { type = "DoWhileStatement", body = body, test = test, line = token.line, col = token.col }
end

--- @param left (table) VariableDeclaration or expression (the loop variable)
--- @param right (table) Iterable expression
--- @param body (table) Statement to repeat
--- @return table {type="ForOfStatement", left, right, body}
function M.for_of_statement(left, right, body, token)
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
function M.for_in_statement(left, right, body, token)
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
function M.for_statement(init, test, update, body, token)
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
function M.block_statement(body, token)
  return { type = "BlockStatement", body = body, line = token.line, col = token.col }
end

--- @param expression (table) The expression being evaluated for side effects
--- @return table {type="ExpressionStatement", expression}
function M.expression_statement(expression, token)
  return {
    type = "ExpressionStatement",
    expression = expression,
    line = token.line,
    col = token.col,
  }
end

--- @param argument (table) The value to throw
--- @return table {type="ThrowStatement", argument}
function M.throw_statement(argument, token)
  return { type = "ThrowStatement", argument = argument, line = token.line, col = token.col }
end

--- @param block (table) BlockStatement (the try body)
--- @param handler (table|nil) CatchClause node, or nil
--- @param finalizer (table|nil) BlockStatement for finally body, or nil
--- @return table {type="TryStatement", block, handler, finalizer}
function M.try_statement(block, handler, finalizer, token)
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
function M.catch_clause(param, body, token)
  return { type = "CatchClause", param = param, body = body, line = token.line, col = token.col }
end

--- @param argument (table|nil) Return value expression, or nil for bare return
--- @return table {type="ReturnStatement", argument}
function M.return_statement(argument, token)
  return { type = "ReturnStatement", argument = argument, line = token.line, col = token.col }
end

--- @param properties (table) Array of Property nodes
--- @return table {type="ObjectExpression", properties}
function M.object_expression(properties, token)
  return { type = "ObjectExpression", properties = properties, line = token.line, col = token.col }
end

--- @param key (table) Identifier or StringLiteral node
--- @param value (table) Expression node
--- @param computed (boolean) true if key is a computed [expr] property
--- @return table {type="Property", key, value, computed}
function M.property(key, value, computed, token)
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
function M.array_expression(elements, token)
  return { type = "ArrayExpression", elements = elements, line = token.line, col = token.col }
end

--- @param discriminant (table) Expression being matched against
--- @param cases (table) Array of SwitchCase nodes
--- @return table {type="SwitchStatement", discriminant, cases}
function M.switch_statement(discriminant, cases, token)
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
function M.switch_case(test, consequent, token)
  return {
    type = "SwitchCase",
    test = test,
    consequent = consequent,
    line = token.line,
    col = token.col,
  }
end

--- @return table {type="BreakStatement"}
function M.break_statement(token)
  return { type = "BreakStatement", line = token.line, col = token.col }
end

--- @return table {type="ContinueStatement"}
function M.continue_statement(token)
  return { type = "ContinueStatement", line = token.line, col = token.col }
end

return M
