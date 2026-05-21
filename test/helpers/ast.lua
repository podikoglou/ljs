local A = {}

A.num = function(v)
  return { type = "NumberLiteral", value = v }
end

A.str = function(v)
  return { type = "StringLiteral", value = v }
end

A.bool = function(v)
  return { type = "BooleanLiteral", value = v }
end

A.null = function()
  return { type = "NullLiteral" }
end

A.undef = function()
  return { type = "UndefinedLiteral" }
end

A.this_ = function()
  return { type = "ThisExpression" }
end

A.id = function(name)
  return { type = "Identifier", name = name }
end

A.ids = function(...)
  local result = {}
  for i = 1, select("#", ...) do
    result[i] = A.id(select(i, ...))
  end
  return result
end

A.bin = function(op, left, right)
  return { type = "BinaryExpression", operator = op, left = left, right = right }
end

A.una = function(op, arg)
  return { type = "UnaryExpression", operator = op, argument = arg }
end

A.del = function(arg)
  return { type = "DeleteExpression", argument = arg }
end

A.typeof_ = function(arg)
  return { type = "TypeofExpression", argument = arg }
end

A.update = function(op, arg, prefix)
  return { type = "UpdateExpression", operator = op, argument = arg, prefix = prefix }
end

A.ternary = function(test, cons, alt)
  return { type = "ConditionalExpression", test = test, consequent = cons, alternate = alt }
end

A.call = function(callee, args)
  return { type = "CallExpression", callee = callee, arguments = args }
end

A.member = function(obj, prop)
  return { type = "MemberExpression", object = obj, property = prop, computed = false }
end

A.member_c = function(obj, prop)
  return { type = "MemberExpression", object = obj, property = prop, computed = true }
end

A.expr_stmt = function(expr)
  return { type = "ExpressionStatement", expression = expr }
end

A.obj = function(props)
  return { type = "ObjectExpression", properties = props }
end

A.prop = function(key, value)
  return { type = "Property", key = key, value = value, computed = false }
end

A.prop_c = function(key, value)
  return { type = "Property", key = key, value = value, computed = true }
end

A.arr = function(elements)
  return { type = "ArrayExpression", elements = elements }
end

A.declarator = function(name, init)
  if init == nil then
    return { type = "VariableDeclarator", name = name }
  end
  return { type = "VariableDeclarator", name = name, init = init }
end

A.var_decl = function(kind, declarations)
  return { type = "VariableDeclaration", kind = kind, declarations = declarations }
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
  return { type = "FunctionDeclaration", name = name, params = params, body = body }
end

A.func_expr = function(params_or_name, body_or_params, body_or_nil)
  if body_or_nil == nil then
    return { type = "FunctionExpression", params = params_or_name, body = body_or_params }
  end
  return {
    type = "FunctionExpression",
    name = params_or_name,
    params = body_or_params,
    body = body_or_nil,
  }
end

A.arrow = function(params, body)
  return { type = "ArrowFunctionExpression", params = params, body = body }
end

A.block = function(stmts)
  return { type = "BlockStatement", body = stmts }
end

A.ret = function(...)
  if select("#", ...) == 0 then
    return { type = "ReturnStatement" }
  end
  return { type = "ReturnStatement", argument = (...) }
end

A.if_ = function(test, cons, alt)
  if alt == nil then
    return { type = "IfStatement", test = test, consequent = cons }
  end
  return { type = "IfStatement", test = test, consequent = cons, alternate = alt }
end

A.while_ = function(test, body)
  return { type = "WhileStatement", test = test, body = body }
end

A.do_while = function(body, test)
  return { type = "DoWhileStatement", body = body, test = test }
end

A.for_of = function(left, right, body)
  return { type = "ForOfStatement", left = left, right = right, body = body }
end

A.for_in = function(left, right, body)
  return { type = "ForInStatement", left = left, right = right, body = body }
end

A.for_ = function(init, test, update, body)
  return { type = "ForStatement", init = init, test = test, update = update, body = body }
end

A.break_ = function()
  return { type = "BreakStatement" }
end

A.continue_ = function()
  return { type = "ContinueStatement" }
end

A.throw = function(arg)
  return { type = "ThrowStatement", argument = arg }
end

A.try_catch = function(block, handler)
  return { type = "TryStatement", block = block, handler = handler }
end

A.try_finally = function(block, finalizer)
  return { type = "TryStatement", block = block, finalizer = finalizer }
end

A.try = function(block, handler, finalizer)
  return { type = "TryStatement", block = block, handler = handler, finalizer = finalizer }
end

A.catch = function(param, body)
  return { type = "CatchClause", param = param, body = body }
end

A.switch = function(discriminant, cases)
  return { type = "SwitchStatement", discriminant = discriminant, cases = cases }
end

A.case = function(test, consequent)
  return { type = "SwitchCase", test = test, consequent = consequent }
end

A.default = function(consequent)
  return { type = "SwitchCase", test = nil, consequent = consequent }
end

A.program = function(body)
  return { type = "Program", body = body }
end

return A
