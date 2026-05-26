-- ljs.ast — AST node constructors.
--
-- Factory functions for each AST node type. All return a table with a `type`
-- field. See AGENTS.md for the full AST specification.

local M = {}

M.TYPE_IDENTIFIER = "Identifier"
M.TYPE_NUMBER_LITERAL = "NumberLiteral"
M.TYPE_STRING_LITERAL = "StringLiteral"
M.TYPE_BOOLEAN_LITERAL = "BooleanLiteral"
M.TYPE_NULL_LITERAL = "NullLiteral"
M.TYPE_UNDEFINED_LITERAL = "UndefinedLiteral"
M.TYPE_BINARY_EXPRESSION = "BinaryExpression"
M.TYPE_UNARY_EXPRESSION = "UnaryExpression"
M.TYPE_UPDATE_EXPRESSION = "UpdateExpression"
M.TYPE_DELETE_EXPRESSION = "DeleteExpression"
M.TYPE_THIS_EXPRESSION = "ThisExpression"
M.TYPE_TYPEOF_EXPRESSION = "TypeofExpression"
M.TYPE_NEW_EXPRESSION = "NewExpression"
M.TYPE_CLASS_DECLARATION = "ClassDeclaration"
M.TYPE_CLASS_EXPRESSION = "ClassExpression"
M.TYPE_METHOD_DEFINITION = "MethodDefinition"
M.TYPE_SUPER_EXPRESSION = "SuperExpression"
M.TYPE_CONDITIONAL_EXPRESSION = "ConditionalExpression"
M.TYPE_CALL_EXPRESSION = "CallExpression"
M.TYPE_MEMBER_EXPRESSION = "MemberExpression"
M.TYPE_VARIABLE_DECLARATION = "VariableDeclaration"
M.TYPE_VARIABLE_DECLARATOR = "VariableDeclarator"
M.TYPE_FUNCTION_DECLARATION = "FunctionDeclaration"
M.TYPE_FUNCTION_EXPRESSION = "FunctionExpression"
M.TYPE_ARROW_FUNCTION_EXPRESSION = "ArrowFunctionExpression"
M.TYPE_IF_STATEMENT = "IfStatement"
M.TYPE_WHILE_STATEMENT = "WhileStatement"
M.TYPE_DO_WHILE_STATEMENT = "DoWhileStatement"
M.TYPE_FOR_OF_STATEMENT = "ForOfStatement"
M.TYPE_FOR_IN_STATEMENT = "ForInStatement"
M.TYPE_FOR_STATEMENT = "ForStatement"
M.TYPE_BLOCK_STATEMENT = "BlockStatement"
M.TYPE_EXPRESSION_STATEMENT = "ExpressionStatement"
M.TYPE_THROW_STATEMENT = "ThrowStatement"
M.TYPE_TRY_STATEMENT = "TryStatement"
M.TYPE_CATCH_CLAUSE = "CatchClause"
M.TYPE_RETURN_STATEMENT = "ReturnStatement"
M.TYPE_OBJECT_EXPRESSION = "ObjectExpression"
M.TYPE_PROPERTY = "Property"
M.TYPE_ARRAY_EXPRESSION = "ArrayExpression"
M.TYPE_SWITCH_STATEMENT = "SwitchStatement"
M.TYPE_SWITCH_CASE = "SwitchCase"
M.TYPE_BREAK_STATEMENT = "BreakStatement"
M.TYPE_CONTINUE_STATEMENT = "ContinueStatement"
M.TYPE_PROGRAM = "Program"
M.TYPE_ASSIGNMENT_PATTERN = "AssignmentPattern"
M.TYPE_REST_ELEMENT = "RestElement"
M.TYPE_SPREAD_ELEMENT = "SpreadElement"
M.TYPE_TEMPLATE_LITERAL = "TemplateLiteral"
M.TYPE_TEMPLATE_ELEMENT = "TemplateElement"

--- @param name (string) Variable/parameter name
--- @return table {type=M.TYPE_IDENTIFIER, name=name}
function M.identifier(name, token)
  return { type = M.TYPE_IDENTIFIER, name = name, line = token.line, col = token.col }
end

--- @param value (number) Numeric value
--- @return table {type=M.TYPE_NUMBER_LITERAL, value=value}
function M.number_literal(value, token)
  return { type = M.TYPE_NUMBER_LITERAL, value = value, line = token.line, col = token.col }
end

--- @param value (string) Unescaped string content
--- @return table {type=M.TYPE_STRING_LITERAL, value=value}
function M.string_literal(value, token)
  return { type = M.TYPE_STRING_LITERAL, value = value, line = token.line, col = token.col }
end

--- @param value (boolean) true or false
--- @return table {type=M.TYPE_BOOLEAN_LITERAL, value=value}
function M.boolean_literal(value, token)
  return { type = M.TYPE_BOOLEAN_LITERAL, value = value, line = token.line, col = token.col }
end

--- @return table {type=M.TYPE_NULL_LITERAL}
function M.null_literal(token)
  return { type = M.TYPE_NULL_LITERAL, line = token.line, col = token.col }
end

--- @return table {type=M.TYPE_UNDEFINED_LITERAL}
function M.undefined_literal(token)
  return { type = M.TYPE_UNDEFINED_LITERAL, line = token.line, col = token.col }
end

--- @param operator (string) One of: + - * / % ** == != === !== < > <= >= && || in = += -= *= /= %= **= & | ^ << >> >>> &= |= ^= <<= >>= >>>=
--- @param left (table) Left-hand AST expression
--- @param right (table) Right-hand AST expression
--- @return table {type=M.TYPE_BINARY_EXPRESSION, operator, left, right}
function M.binary_expression(operator, left, right, token)
  return {
    type = M.TYPE_BINARY_EXPRESSION,
    operator = operator,
    left = left,
    right = right,
    line = token.line,
    col = token.col,
  }
end

--- @param operator (string) "!" or "-" or "~"
--- @param argument (table) The operand AST expression
--- @return table {type=M.TYPE_UNARY_EXPRESSION, operator, argument}
function M.unary_expression(operator, argument, token)
  return {
    type = M.TYPE_UNARY_EXPRESSION,
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
  if t == M.TYPE_IDENTIFIER then
    return true
  elseif t == M.TYPE_MEMBER_EXPRESSION then
    return true
  end
  return false
end

--- @param operator (string) "++" or "--"
--- @param argument (table) The operand AST expression
--- @param prefix (boolean) true for prefix (++x), false for postfix (x++)
--- @return table {type=M.TYPE_UPDATE_EXPRESSION, operator, argument, prefix}
function M.update_expression(operator, argument, prefix, token)
  return {
    type = M.TYPE_UPDATE_EXPRESSION,
    operator = operator,
    argument = argument,
    prefix = prefix,
    line = token.line,
    col = token.col,
  }
end

--- @param argument (table) The operand AST expression
--- @return table {type=M.TYPE_DELETE_EXPRESSION, argument}
function M.delete_expression(argument, token)
  return { type = M.TYPE_DELETE_EXPRESSION, argument = argument, line = token.line, col = token.col }
end

--- @return table {type=M.TYPE_THIS_EXPRESSION}
function M.this_expression(token)
  return { type = M.TYPE_THIS_EXPRESSION, line = token.line, col = token.col }
end

--- @param argument (table) The operand AST expression
--- @return table {type=M.TYPE_TYPEOF_EXPRESSION, argument}
function M.typeof_expression(argument, token)
  return { type = M.TYPE_TYPEOF_EXPRESSION, argument = argument, line = token.line, col = token.col }
end

--- @param callee (table) Constructor expression (Identifier or MemberExpression)
--- @param arguments (table) Array of argument expressions
--- @return table {type=M.TYPE_NEW_EXPRESSION, callee, arguments}
function M.new_expression(callee, arguments, token)
  return {
    type = M.TYPE_NEW_EXPRESSION,
    callee = callee,
    arguments = arguments,
    line = token.line,
    col = token.col,
  }
end

--- @param name (string) Class name (required for declarations)
--- @param superClass (table|nil) Parent class expression, or nil
--- @param body (table) Array of MethodDefinition nodes
--- @return table {type=M.TYPE_CLASS_DECLARATION, name, superClass, body}
function M.class_declaration(name, superClass, body, token)
  return {
    type = M.TYPE_CLASS_DECLARATION,
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
--- @return table {type=M.TYPE_CLASS_EXPRESSION, name, superClass, body}
function M.class_expression(name, superClass, body, token)
  return {
    type = M.TYPE_CLASS_EXPRESSION,
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
--- @return table {type=M.TYPE_METHOD_DEFINITION, kind, key, value, static}
function M.method_definition(kind, key, value, static_flag, token)
  return {
    type = M.TYPE_METHOD_DEFINITION,
    kind = kind,
    key = key,
    value = value,
    static = static_flag,
    line = token.line,
    col = token.col,
  }
end

--- @return table {type=M.TYPE_SUPER_EXPRESSION}
function M.super_expression(token)
  return { type = M.TYPE_SUPER_EXPRESSION, line = token.line, col = token.col }
end

--- @param test (table) Condition expression
--- @param consequent (table) Expression if truthy
--- @param alternate (table) Expression if falsy
--- @return table {type=M.TYPE_CONDITIONAL_EXPRESSION, test, consequent, alternate}
function M.conditional_expression(test, consequent, alternate, token)
  return {
    type = M.TYPE_CONDITIONAL_EXPRESSION,
    test = test,
    consequent = consequent,
    alternate = alternate,
    line = token.line,
    col = token.col,
  }
end

--- @param callee (table) Expression being called
--- @param arguments (table) Array of argument expressions
--- @return table {type=M.TYPE_CALL_EXPRESSION, callee, arguments}
function M.call_expression(callee, arguments, token)
  return {
    type = M.TYPE_CALL_EXPRESSION,
    callee = callee,
    arguments = arguments,
    line = token.line,
    col = token.col,
  }
end

--- @param object (table) Object expression
--- @param property (table) Property expression (Identifier or computed expression)
--- @param computed (boolean) true for bracket notation obj[expr], false for dot notation obj.prop
--- @return table {type=M.TYPE_MEMBER_EXPRESSION, object, property, computed}
function M.member_expression(object, property, computed, token)
  return {
    type = M.TYPE_MEMBER_EXPRESSION,
    object = object,
    property = property,
    computed = computed,
    line = token.line,
    col = token.col,
  }
end

--- @param kind (string) "let" or "const"
--- @param declarations (table) Array of VariableDeclarator nodes
--- @return table {type=M.TYPE_VARIABLE_DECLARATION, kind, declarations}
function M.variable_declaration(kind, declarations, token)
  return {
    type = M.TYPE_VARIABLE_DECLARATION,
    kind = kind,
    declarations = declarations,
    line = token.line,
    col = token.col,
  }
end

--- @param name (table) Identifier node
--- @param init (table|nil) Initializer expression, or nil
--- @return table {type=M.TYPE_VARIABLE_DECLARATOR, name, init}
function M.variable_declarator(name, init, token)
  return {
    type = M.TYPE_VARIABLE_DECLARATOR,
    name = name,
    init = init,
    line = token.line,
    col = token.col,
  }
end

--- @param name (string) Function name
--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement node
--- @return table {type=M.TYPE_FUNCTION_DECLARATION, name, params, body}
function M.function_declaration(name, params, body, token)
  return {
    type = M.TYPE_FUNCTION_DECLARATION,
    name = name,
    params = params,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param params (table) Array of Identifier nodes
--- @param body (table) BlockStatement node
--- @return table {type=M.TYPE_FUNCTION_EXPRESSION, params, body}
function M.function_expression(params, body, token)
  return {
    type = M.TYPE_FUNCTION_EXPRESSION,
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
--- @return table {type=M.TYPE_ARROW_FUNCTION_EXPRESSION, params, body}
function M.arrow_function_expression(params, body, token)
  return {
    type = M.TYPE_ARROW_FUNCTION_EXPRESSION,
    params = params,
    body = body,
    line = token.line,
    col = token.col,
  }
end

function M.assignment_pattern(left, right, token)
  return {
    type = M.TYPE_ASSIGNMENT_PATTERN,
    left = left,
    right = right,
    line = token.line,
    col = token.col,
  }
end

function M.rest_element(argument, token)
  return {
    type = M.TYPE_REST_ELEMENT,
    argument = argument,
    line = token.line,
    col = token.col,
  }
end

function M.spread_element(argument, token)
  return {
    type = M.TYPE_SPREAD_ELEMENT,
    argument = argument,
    line = token.line,
    col = token.col,
  }
end

function M.template_literal(quasis, expressions, token)
  return {
    type = M.TYPE_TEMPLATE_LITERAL,
    quasis = quasis,
    expressions = expressions,
    line = token.line,
    col = token.col,
  }
end

function M.template_element(value, tail, token)
  return {
    type = M.TYPE_TEMPLATE_ELEMENT,
    value = value,
    tail = tail,
    line = token.line,
    col = token.col,
  }
end

--- @param test (table) Condition expression
--- @param consequent (table) Statement to run if truthy
--- @param alternate (table|nil) else branch, or nil
--- @return table {type=M.TYPE_IF_STATEMENT, test, consequent, alternate}
function M.if_statement(test, consequent, alternate, token)
  return {
    type = M.TYPE_IF_STATEMENT,
    test = test,
    consequent = consequent,
    alternate = alternate,
    line = token.line,
    col = token.col,
  }
end

--- @param test (table) Condition expression
--- @param body (table) Statement to repeat
--- @return table {type=M.TYPE_WHILE_STATEMENT, test, body}
function M.while_statement(test, body, token)
  return { type = M.TYPE_WHILE_STATEMENT, test = test, body = body, line = token.line, col = token.col }
end

--- @param body (table) Statement to repeat
--- @param test (table) Condition expression
--- @return table {type=M.TYPE_DO_WHILE_STATEMENT, body, test}
function M.do_while_statement(body, test, token)
  return { type = M.TYPE_DO_WHILE_STATEMENT, body = body, test = test, line = token.line, col = token.col }
end

--- @param left (table) VariableDeclaration or expression (the loop variable)
--- @param right (table) Iterable expression
--- @param body (table) Statement to repeat
--- @return table {type=M.TYPE_FOR_OF_STATEMENT, left, right, body}
function M.for_of_statement(left, right, body, token)
  return {
    type = M.TYPE_FOR_OF_STATEMENT,
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
--- @return table {type=M.TYPE_FOR_IN_STATEMENT, left, right, body}
function M.for_in_statement(left, right, body, token)
  return {
    type = M.TYPE_FOR_IN_STATEMENT,
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
--- @return table {type=M.TYPE_FOR_STATEMENT, init, test, update, body}
function M.for_statement(init, test, update, body, token)
  return {
    type = M.TYPE_FOR_STATEMENT,
    init = init,
    test = test,
    update = update,
    body = body,
    line = token.line,
    col = token.col,
  }
end

--- @param body (table) Array of statement nodes
--- @return table {type=M.TYPE_BLOCK_STATEMENT, body}
function M.block_statement(body, token)
  return { type = M.TYPE_BLOCK_STATEMENT, body = body, line = token.line, col = token.col }
end

--- @param expression (table) The expression being evaluated for side effects
--- @return table {type=M.TYPE_EXPRESSION_STATEMENT, expression}
function M.expression_statement(expression, token)
  return {
    type = M.TYPE_EXPRESSION_STATEMENT,
    expression = expression,
    line = token.line,
    col = token.col,
  }
end

--- @param argument (table) The value to throw
--- @return table {type=M.TYPE_THROW_STATEMENT, argument}
function M.throw_statement(argument, token)
  return { type = M.TYPE_THROW_STATEMENT, argument = argument, line = token.line, col = token.col }
end

--- @param block (table) BlockStatement (the try body)
--- @param handler (table|nil) CatchClause node, or nil
--- @param finalizer (table|nil) BlockStatement for finally body, or nil
--- @return table {type=M.TYPE_TRY_STATEMENT, block, handler, finalizer}
function M.try_statement(block, handler, finalizer, token)
  return {
    type = M.TYPE_TRY_STATEMENT,
    block = block,
    handler = handler,
    finalizer = finalizer,
    line = token.line,
    col = token.col,
  }
end

--- @param param (table) Identifier node for the caught error
--- @param body (table) BlockStatement for catch body
--- @return table {type=M.TYPE_CATCH_CLAUSE, param, body}
function M.catch_clause(param, body, token)
  return { type = M.TYPE_CATCH_CLAUSE, param = param, body = body, line = token.line, col = token.col }
end

--- @param argument (table|nil) Return value expression, or nil for bare return
--- @return table {type=M.TYPE_RETURN_STATEMENT, argument}
function M.return_statement(argument, token)
  return { type = M.TYPE_RETURN_STATEMENT, argument = argument, line = token.line, col = token.col }
end

--- @param properties (table) Array of Property nodes
--- @return table {type=M.TYPE_OBJECT_EXPRESSION, properties}
function M.object_expression(properties, token)
  return { type = M.TYPE_OBJECT_EXPRESSION, properties = properties, line = token.line, col = token.col }
end

--- @param key (table) Identifier or StringLiteral node
--- @param value (table) Expression node
--- @param computed (boolean) true if key is a computed [expr] property
--- @return table {type=M.TYPE_PROPERTY, key, value, computed}
function M.property(key, value, computed, token)
  return {
    type = M.TYPE_PROPERTY,
    key = key,
    value = value,
    computed = computed or false,
    line = token.line,
    col = token.col,
  }
end

--- @param elements (table) Array of expression nodes
--- @return table {type=M.TYPE_ARRAY_EXPRESSION, elements}
function M.array_expression(elements, token)
  return { type = M.TYPE_ARRAY_EXPRESSION, elements = elements, line = token.line, col = token.col }
end

--- @param discriminant (table) Expression being matched against
--- @param cases (table) Array of SwitchCase nodes
--- @return table {type=M.TYPE_SWITCH_STATEMENT, discriminant, cases}
function M.switch_statement(discriminant, cases, token)
  return {
    type = M.TYPE_SWITCH_STATEMENT,
    discriminant = discriminant,
    cases = cases,
    line = token.line,
    col = token.col,
  }
end

--- @param test (table|nil) Case value expression, or nil for default
--- @param consequent (table) Array of statement nodes in this case
--- @return table {type=M.TYPE_SWITCH_CASE, test, consequent}
function M.switch_case(test, consequent, token)
  return {
    type = M.TYPE_SWITCH_CASE,
    test = test,
    consequent = consequent,
    line = token.line,
    col = token.col,
  }
end

--- @return table {type=M.TYPE_BREAK_STATEMENT}
function M.break_statement(token)
  return { type = M.TYPE_BREAK_STATEMENT, line = token.line, col = token.col }
end

--- @return table {type=M.TYPE_CONTINUE_STATEMENT}
function M.continue_statement(token)
  return { type = M.TYPE_CONTINUE_STATEMENT, line = token.line, col = token.col }
end

return M
