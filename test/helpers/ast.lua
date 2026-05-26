local ast = require("ljs.ast")
local A = {}

A.num = function(v)
  return { type = ast.TYPE_NUMBER_LITERAL, value = v }
end

A.str = function(v)
  return { type = ast.TYPE_STRING_LITERAL, value = v }
end

A.bool = function(v)
  return { type = ast.TYPE_BOOLEAN_LITERAL, value = v }
end

A.null = function()
  return { type = ast.TYPE_NULL_LITERAL }
end

A.undef = function()
  return { type = ast.TYPE_UNDEFINED_LITERAL }
end

A.this_ = function()
  return { type = ast.TYPE_THIS_EXPRESSION }
end

A.id = function(name)
  return { type = ast.TYPE_IDENTIFIER, name = name }
end

A.ids = function(...)
  local result = {}
  for i = 1, select("#", ...) do
    result[i] = A.id(select(i, ...))
  end
  return result
end

A.bin = function(op, left, right)
  return { type = ast.TYPE_BINARY_EXPRESSION, operator = op, left = left, right = right }
end

A.una = function(op, arg)
  return { type = ast.TYPE_UNARY_EXPRESSION, operator = op, argument = arg }
end

A.del = function(arg)
  return { type = ast.TYPE_DELETE_EXPRESSION, argument = arg }
end

A.typeof_ = function(arg)
  return { type = ast.TYPE_TYPEOF_EXPRESSION, argument = arg }
end

A.update = function(op, arg, prefix)
  return { type = ast.TYPE_UPDATE_EXPRESSION, operator = op, argument = arg, prefix = prefix }
end

A.ternary = function(test, cons, alt)
  return { type = ast.TYPE_CONDITIONAL_EXPRESSION, test = test, consequent = cons, alternate = alt }
end

A.call = function(callee, args)
  return { type = ast.TYPE_CALL_EXPRESSION, callee = callee, arguments = args }
end

A.new_expr = function(callee, args)
  return { type = ast.TYPE_NEW_EXPRESSION, callee = callee, arguments = args }
end

A.member = function(obj, prop)
  return { type = ast.TYPE_MEMBER_EXPRESSION, object = obj, property = prop, computed = false }
end

A.member_c = function(obj, prop)
  return { type = ast.TYPE_MEMBER_EXPRESSION, object = obj, property = prop, computed = true }
end

A.expr_stmt = function(expr)
  return { type = ast.TYPE_EXPRESSION_STATEMENT, expression = expr }
end

A.obj = function(props)
  return { type = ast.TYPE_OBJECT_EXPRESSION, properties = props }
end

A.prop = function(key, value)
  return { type = ast.TYPE_PROPERTY, key = key, value = value, computed = false }
end

A.prop_c = function(key, value)
  return { type = ast.TYPE_PROPERTY, key = key, value = value, computed = true }
end

A.arr = function(elements)
  return { type = ast.TYPE_ARRAY_EXPRESSION, elements = elements }
end

A.declarator = function(name, init)
  if init == nil then
    return { type = ast.TYPE_VARIABLE_DECLARATOR, name = name }
  end
  return { type = ast.TYPE_VARIABLE_DECLARATOR, name = name, init = init }
end

A.var_decl = function(kind, declarations)
  return { type = ast.TYPE_VARIABLE_DECLARATION, kind = kind, declarations = declarations }
end

A.let = function(name, init)
  if init == nil then
    return A.var_decl("let", { A.declarator(A.id(name)) })
  end
  return A.var_decl("let", { A.declarator(A.id(name), init) })
end

A.const = function(name, init)
  return A.var_decl("const", { A.declarator(A.id(name), init) })
end

A.func = function(name, params, body)
  return { type = ast.TYPE_FUNCTION_DECLARATION, name = name, params = params, body = body }
end

A.func_expr = function(params_or_name, body_or_params, body_or_nil)
  if body_or_nil == nil then
    return { type = ast.TYPE_FUNCTION_EXPRESSION, params = params_or_name, body = body_or_params }
  end
  return {
    type = ast.TYPE_FUNCTION_EXPRESSION,
    name = params_or_name,
    params = body_or_params,
    body = body_or_nil,
  }
end

A.method_expr = function(name, params, body)
  return {
    type = ast.TYPE_FUNCTION_EXPRESSION,
    name = name,
    params = params,
    body = body,
    is_method = true,
  }
end

A.arrow = function(params, body)
  return { type = ast.TYPE_ARROW_FUNCTION_EXPRESSION, params = params, body = body }
end

A.block = function(stmts)
  return { type = ast.TYPE_BLOCK_STATEMENT, body = stmts }
end

A.ret = function(...)
  if select("#", ...) == 0 then
    return { type = ast.TYPE_RETURN_STATEMENT }
  end
  return { type = ast.TYPE_RETURN_STATEMENT, argument = (...) }
end

A.if_ = function(test, cons, alt)
  if alt == nil then
    return { type = ast.TYPE_IF_STATEMENT, test = test, consequent = cons }
  end
  return { type = ast.TYPE_IF_STATEMENT, test = test, consequent = cons, alternate = alt }
end

A.while_ = function(test, body)
  return { type = ast.TYPE_WHILE_STATEMENT, test = test, body = body }
end

A.do_while = function(body, test)
  return { type = ast.TYPE_DO_WHILE_STATEMENT, body = body, test = test }
end

A.for_of = function(left, right, body)
  return { type = ast.TYPE_FOR_OF_STATEMENT, left = left, right = right, body = body }
end

A.for_in = function(left, right, body)
  return { type = ast.TYPE_FOR_IN_STATEMENT, left = left, right = right, body = body }
end

A.for_ = function(init, test, update, body)
  return { type = ast.TYPE_FOR_STATEMENT, init = init, test = test, update = update, body = body }
end

A.break_ = function()
  return { type = ast.TYPE_BREAK_STATEMENT }
end

A.continue_ = function()
  return { type = ast.TYPE_CONTINUE_STATEMENT }
end

A.throw = function(arg)
  return { type = ast.TYPE_THROW_STATEMENT, argument = arg }
end

A.try_catch = function(block, handler)
  return { type = ast.TYPE_TRY_STATEMENT, block = block, handler = handler }
end

A.try_finally = function(block, finalizer)
  return { type = ast.TYPE_TRY_STATEMENT, block = block, finalizer = finalizer }
end

A.try = function(block, handler, finalizer)
  return { type = ast.TYPE_TRY_STATEMENT, block = block, handler = handler, finalizer = finalizer }
end

A.catch = function(param, body)
  return { type = ast.TYPE_CATCH_CLAUSE, param = param, body = body }
end

A.switch = function(discriminant, cases)
  return { type = ast.TYPE_SWITCH_STATEMENT, discriminant = discriminant, cases = cases }
end

A.case = function(test, consequent)
  return { type = ast.TYPE_SWITCH_CASE, test = test, consequent = consequent }
end

A.default = function(consequent)
  return { type = ast.TYPE_SWITCH_CASE, test = nil, consequent = consequent }
end

A.program = function(body)
  return { type = ast.TYPE_PROGRAM, body = body }
end

A.tpl = function(quasis, expressions)
  return { type = ast.TYPE_TEMPLATE_LITERAL, quasis = quasis, expressions = expressions }
end

A.tpl_elem = function(value, tail)
  return { type = ast.TYPE_TEMPLATE_ELEMENT, value = value, tail = tail }
end

A.spread = function(arg)
  return { type = ast.TYPE_SPREAD_ELEMENT, argument = arg }
end

return A
