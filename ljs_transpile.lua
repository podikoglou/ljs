local ljs_transpile = {}

local cg = require("ljs_codegen")

-- ============================================================================
-- Section 2: Helper definitions (HELPERS registry)
-- ============================================================================

local HELPERS = {}

HELPERS._ljs_add = [[local function _ljs_add(a, b)
  if type(a) == "string" or type(b) == "string" then
    return tostring(a) .. tostring(b)
  end
  return a + b
end]]

HELPERS._ljs_log = [[local function _ljs_log(...)
  print(...)
end]]

-- ============================================================================
-- Section 3: Pass 1 — Analysis (scope tracker, helper detection)
-- ============================================================================

local BUILTINS = {
  console = {
    log = { helper = "_ljs_log" },
  },
}

local function scope_push(scopes)
  scopes[#scopes + 1] = {}
end

local function scope_pop(scopes)
  scopes[#scopes] = nil
end

local function scope_declare(scopes, name)
  scopes[#scopes][name] = true
end

local function scope_is_shadowed(scopes, name)
  for i = #scopes, 1, -1 do
    if scopes[i][name] then return true end
  end
  return false
end

local function lookup_builtin(node, scopes)
  if node.type ~= "CallExpression" then return nil end
  local callee = node.callee
  if not callee or callee.type ~= "MemberExpression" then return nil end
  if callee.computed then return nil end
  if callee.object.type ~= "Identifier" then return nil end
  if callee.property.type ~= "Identifier" then return nil end
  local obj_entry = BUILTINS[callee.object.name]
  if not obj_entry then return nil end
  local entry = obj_entry[callee.property.name]
  if not entry then return nil end
  if scope_is_shadowed(scopes, callee.object.name) then return nil end
  return entry
end

local function analyze_node(node, meta, scopes)
  if not node or type(node) ~= "table" then return end
  local t = node.type

  if t == "Program" then
    scope_push(scopes)
    for _, child in ipairs(node.body) do analyze_node(child, meta, scopes) end
    scope_pop(scopes)

  elseif t == "BlockStatement" then
    scope_push(scopes)
    for _, child in ipairs(node.body) do analyze_node(child, meta, scopes) end
    scope_pop(scopes)

  elseif t == "VariableDeclaration" then
    for _, decl in ipairs(node.declarations) do
      scope_declare(scopes, decl.name.name)
      if decl.init then analyze_node(decl.init, meta, scopes) end
    end

  elseif t == "FunctionDeclaration" then
    scope_declare(scopes, node.name)
    scope_push(scopes)
    for _, p in ipairs(node.params) do scope_declare(scopes, p.name) end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "FunctionExpression" then
    scope_push(scopes)
    if node.name then scope_declare(scopes, node.name) end
    for _, p in ipairs(node.params) do scope_declare(scopes, p.name) end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "ArrowFunctionExpression" then
    scope_push(scopes)
    for _, p in ipairs(node.params) do scope_declare(scopes, p.name) end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "ForOfStatement" then
    analyze_node(node.right, meta, scopes)
    scope_push(scopes)
    if node.left.type == "VariableDeclaration" then
      for _, decl in ipairs(node.left.declarations) do
        scope_declare(scopes, decl.name.name)
      end
    end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "ForInStatement" then
    analyze_node(node.right, meta, scopes)
    scope_push(scopes)
    if node.left.type == "VariableDeclaration" then
      for _, decl in ipairs(node.left.declarations) do
        scope_declare(scopes, decl.name.name)
      end
    end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "ForStatement" then
    if node.init then analyze_node(node.init, meta, scopes) end
    if node.test then analyze_node(node.test, meta, scopes) end
    if node.update then analyze_node(node.update, meta, scopes) end
    scope_push(scopes)
    if node.init and node.init.type == "VariableDeclaration" then
      for _, decl in ipairs(node.init.declarations) do
        scope_declare(scopes, decl.name.name)
      end
    end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "CatchClause" then
    scope_push(scopes)
    scope_declare(scopes, node.param.name)
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)

  elseif t == "IfStatement" then
    analyze_node(node.test, meta, scopes)
    analyze_node(node.consequent, meta, scopes)
    if node.alternate then analyze_node(node.alternate, meta, scopes) end

  elseif t == "WhileStatement" then
    analyze_node(node.test, meta, scopes)
    analyze_node(node.body, meta, scopes)

  elseif t == "TryStatement" then
    analyze_node(node.block, meta, scopes)
    if node.handler then analyze_node(node.handler, meta, scopes) end

  elseif t == "SwitchStatement" then
    analyze_node(node.discriminant, meta, scopes)
    for _, case in ipairs(node.cases) do
      if case.test then analyze_node(case.test, meta, scopes) end
      for _, stmt in ipairs(case.consequent) do
        analyze_node(stmt, meta, scopes)
      end
    end

  elseif t == "ThrowStatement" then
    if node.argument then analyze_node(node.argument, meta, scopes) end

  elseif t == "ReturnStatement" then
    if node.argument then analyze_node(node.argument, meta, scopes) end

  elseif t == "ExpressionStatement" then
    analyze_node(node.expression, meta, scopes)

  elseif t == "BinaryExpression" then
    if node.operator == "+" or node.operator == "+=" then
      meta.needed_helpers["_ljs_add"] = true
    end
    analyze_node(node.left, meta, scopes)
    analyze_node(node.right, meta, scopes)

  elseif t == "UpdateExpression" then
    if node.operator == "++" then
      meta.needed_helpers["_ljs_add"] = true
    end
    analyze_node(node.argument, meta, scopes)

  elseif t == "UnaryExpression" then
    analyze_node(node.argument, meta, scopes)

  elseif t == "ConditionalExpression" then
    analyze_node(node.test, meta, scopes)
    analyze_node(node.consequent, meta, scopes)
    analyze_node(node.alternate, meta, scopes)

  elseif t == "CallExpression" then
    local builtin = lookup_builtin(node, scopes)
    if builtin then
      meta.needed_helpers[builtin.helper] = true
    end
    analyze_node(node.callee, meta, scopes)
    for _, arg in ipairs(node.arguments) do analyze_node(arg, meta, scopes) end

  elseif t == "MemberExpression" then
    analyze_node(node.object, meta, scopes)
    if node.computed then analyze_node(node.property, meta, scopes) end

  elseif t == "ObjectExpression" then
    for _, prop in ipairs(node.properties) do
      analyze_node(prop.value, meta, scopes)
    end

  elseif t == "ArrayExpression" then
    for _, elem in ipairs(node.elements) do analyze_node(elem, meta, scopes) end

  end
end

local function analyze(ast)
  local meta = { needed_helpers = {} }
  analyze_node(ast, meta, {})
  return meta
end

-- ============================================================================
-- Section 3b: Continue detection helper
-- ============================================================================

--- Check whether an AST subtree contains a ContinueStatement.
-- Stops at loop and function boundaries (each loop handles its own continue).
-- @param node (table|nil) AST node
-- @return (boolean) true if a ContinueStatement exists in the subtree
local function has_continue(node)
  if not node or type(node) ~= "table" then return false end
  if node.type == "ContinueStatement" then return true end
  if node.type == "WhileStatement" or node.type == "ForOfStatement"
    or node.type == "ForInStatement" or node.type == "ForStatement"
    or node.type == "DoWhileStatement" then
    return false
  end
  if node.type == "FunctionDeclaration" or node.type == "FunctionExpression"
    or node.type == "ArrowFunctionExpression" then
    return false
  end
  for _, v in pairs(node) do
    if type(v) == "table" then
      if has_continue(v) then return true end
    end
  end
  return false
end

-- ============================================================================
-- Section 4: Pass 2 — Code generation (JS AST → Lua source via ljs_codegen)
-- ============================================================================

local gen = {}
local gen_stmt = {}

local function emit(node, indent, scopes)
  return gen[node.type](node, indent, scopes)
end

local function emit_body(stmts, indent, scopes)
  local parts = {}
  for _, s in ipairs(stmts) do parts[#parts + 1] = emit(s, indent, scopes) end
  return table.concat(parts)
end

local function is_elseif_chain(node)
  if node.type == "IfStatement" then return true end
  if node.type == "BlockStatement" and #node.body == 1 and node.body[1].type == "IfStatement" then
    return true
  end
  return false
end

--- Collect if/elseif/else parts from a JS AST if-else chain.
-- @param node (table) JS IfStatement node
-- @param indent (number) Indentation level
-- @param scopes (table) Scope stack
-- @return (string) test, (string) then_body, (table|nil) elseifs, (string|nil) else_body
local function collect_if_chain(node, indent, scopes)
  local test = emit(node.test, indent, scopes)
  local body = emit(node.consequent, indent, scopes)
  local elseifs = {}
  local else_body = nil

  local alternate = node.alternate
  while alternate do
    if is_elseif_chain(alternate) then
      local inner = alternate.type == "IfStatement" and alternate or alternate.body[1]
      elseifs[#elseifs + 1] = {
        test = emit(inner.test, indent, scopes),
        body = emit(inner.consequent, indent, scopes),
      }
      alternate = inner.alternate
    else
      else_body = emit(alternate, indent, scopes)
      break
    end
  end

  return test, body, elseifs, else_body
end

-- === Program ===

gen.Program = function(node, indent, scopes)
  scope_push(scopes)
  local code = emit_body(node.body, indent, scopes)
  scope_pop(scopes)
  return code
end

-- === Literals ===

gen.NumberLiteral = function(node)
  return cg.number(node.value)
end

gen.StringLiteral = function(node)
  return cg.string(node.value)
end

gen.BooleanLiteral = function(node)
  return cg.boolean(node.value)
end

gen.NullLiteral = function()
  return cg.nil_val()
end

gen.Identifier = function(node)
  return cg.ident(node.name)
end

-- === Statements ===

gen.ExpressionStatement = function(node, indent, scopes)
  local stmt_fn = gen_stmt[node.expression.type]
  if stmt_fn then return stmt_fn(node.expression, indent, scopes) end
  return cg.expr_stmt(emit(node.expression, indent, scopes), indent)
end

gen.VariableDeclaration = function(node, indent, scopes)
  local out = {}
  for _, decl in ipairs(node.declarations) do
    scope_declare(scopes, decl.name.name)
    local init = decl.init
    if not init then
      out[#out + 1] = cg.local_decl(decl.name.name, nil, indent)
    elseif init.type == "ArrowFunctionExpression" or init.type == "FunctionExpression" then
      local params = {}
      for _, p in ipairs(init.params) do params[#params + 1] = p.name end
      scope_push(scopes)
      for _, p in ipairs(init.params) do scope_declare(scopes, p.name) end
      local body = emit(init.body, indent, scopes)
      scope_pop(scopes)
      out[#out + 1] = cg.local_fn(decl.name.name, table.concat(params, ", "), body, indent)
    else
      out[#out + 1] = cg.local_decl(decl.name.name, emit(init, indent, scopes), indent)
    end
  end
  return table.concat(out)
end

gen.ReturnStatement = function(node, indent, scopes)
  local expr = node.argument and emit(node.argument, indent, scopes) or nil
  return cg.return_stmt(expr, indent)
end

gen.ThrowStatement = function(node, indent, scopes)
  return cg.expr_stmt(cg.call("error", {emit(node.argument, indent, scopes), "0"}), indent)
end

-- === Functions ===

gen.FunctionDeclaration = function(node, indent, scopes)
  scope_declare(scopes, node.name)
  local params = {}
  for _, p in ipairs(node.params) do params[#params + 1] = p.name end
  scope_push(scopes)
  for _, p in ipairs(node.params) do scope_declare(scopes, p.name) end
  local body = emit(node.body, indent, scopes)
  scope_pop(scopes)
  return cg.local_fn(node.name, table.concat(params, ", "), body, indent)
end

gen.FunctionExpression = function(node, indent, scopes)
  local params = {}
  for _, p in ipairs(node.params) do params[#params + 1] = p.name end
  scope_push(scopes)
  if node.name then scope_declare(scopes, node.name) end
  for _, p in ipairs(node.params) do scope_declare(scopes, p.name) end
  local body = emit(node.body, indent, scopes)
  scope_pop(scopes)
  return cg.fn_expr(table.concat(params, ", "), body, indent)
end

gen.ArrowFunctionExpression = gen.FunctionExpression

-- === Control flow ===

gen.BlockStatement = function(node, indent, scopes)
  scope_push(scopes)
  local code = emit_body(node.body, indent + 1, scopes)
  scope_pop(scopes)
  return code
end

gen.IfStatement = function(node, indent, scopes)
  local test, body, elseifs, else_body = collect_if_chain(node, indent, scopes)
  return cg.if_stmt(test, body, elseifs, else_body, indent)
end

gen.WhileStatement = function(node, indent, scopes)
  local test_code = emit(node.test, indent, scopes)
  local body = emit(node.body, indent, scopes)
  if has_continue(node.body) then
    body = body .. cg.pad(indent + 1) .. "::_continue::\n"
  end
  return cg.while_stmt(test_code, body, indent)
end

gen.ForOfStatement = function(node, indent, scopes)
  local var_name
  if node.left.type == "VariableDeclaration" then
    var_name = node.left.declarations[1].name.name
  else
    var_name = node.left.name
  end
  scope_push(scopes)
  scope_declare(scopes, var_name)
  local body = emit(node.body, indent, scopes)
  if has_continue(node.body) then
    body = body .. cg.pad(indent + 1) .. "::_continue::\n"
  end
  scope_pop(scopes)
  local iter = cg.call("ipairs", {emit(node.right, indent, scopes)})
  return cg.for_in_stmt("_, " .. var_name, iter, body, indent)
end

gen.ForInStatement = function(node, indent, scopes)
  local var_name
  if node.left.type == "VariableDeclaration" then
    var_name = node.left.declarations[1].name.name
  else
    var_name = node.left.name
  end
  scope_push(scopes)
  scope_declare(scopes, var_name)
  local body = emit(node.body, indent, scopes)
  if has_continue(node.body) then
    body = body .. cg.pad(indent + 1) .. "::_continue::\n"
  end
  scope_pop(scopes)
  local iter = cg.call("pairs", {emit(node.right, indent, scopes)})
  return cg.for_in_stmt(var_name .. ", _", iter, body, indent)
end

gen.ForStatement = function(node, indent, scopes)
  local parts = {}
  if node.init then
    parts[#parts + 1] = emit(node.init, indent, scopes)
  end
  local test_code = node.test and emit(node.test, indent, scopes) or "true"
  scope_push(scopes)
  if node.init and node.init.type == "VariableDeclaration" then
    for _, decl in ipairs(node.init.declarations) do
      scope_declare(scopes, decl.name.name)
    end
  end
  local body = emit(node.body, indent, scopes)
  if has_continue(node.body) then
    body = body .. cg.pad(indent + 1) .. "::_continue::\n"
  end
  if node.update then
    local stmt_fn = gen_stmt[node.update.type]
    if stmt_fn then
      body = body .. stmt_fn(node.update, indent + 1, scopes)
    else
      body = body .. cg.expr_stmt(emit(node.update, indent + 1, scopes), indent + 1)
    end
  end
  scope_pop(scopes)
  parts[#parts + 1] = cg.while_stmt(test_code, body, indent)
  return table.concat(parts)
end

gen.SwitchStatement = function(node, indent, scopes)
  local disc = emit(node.discriminant, indent, scopes)
  local parts = {}
  parts[#parts + 1] = cg.local_decl("_ljs_sw", disc, indent)
  parts[#parts + 1] = cg.local_decl("_ljs_matched", "false", indent)
  local cases_body = {}
  for _, case in ipairs(node.cases) do
    local case_body = cg.expr_stmt("_ljs_matched = true", indent + 2)
    for _, stmt in ipairs(case.consequent) do
      case_body = case_body .. emit(stmt, indent + 2, scopes)
    end
    if case.test then
      local test_code = emit(case.test, indent, scopes)
      local test_expr = cg.binop("or", "_ljs_matched", cg.binop("==", "_ljs_sw", test_code))
      cases_body[#cases_body + 1] = cg.if_stmt(test_expr, case_body, nil, nil, indent + 1)
    else
      cases_body[#cases_body + 1] = cg.if_stmt("true", case_body, nil, nil, indent + 1)
    end
  end
  parts[#parts + 1] = cg.numeric_for("_", "1", "1", table.concat(cases_body), indent)
  return table.concat(parts)
end

gen.BreakStatement = function(node, indent, scopes)
  return cg.break_stmt(indent)
end

gen.ContinueStatement = function(node, indent, scopes)
  return cg.pad(indent) .. "goto _continue\n"
end

-- === Exception handling ===

gen.TryStatement = function(node, indent, scopes)
  local param = node.handler.param.name
  local try_body = emit(node.block, indent, scopes)
  scope_push(scopes)
  scope_declare(scopes, param)
  local catch_body = emit(node.handler.body, indent, scopes)
  scope_pop(scopes)
  local pcall_fn = cg.fn_expr("", try_body, indent)
  local pcall_expr = cg.call("pcall", {pcall_fn})
  return cg.local_decl("ok, " .. param, pcall_expr, indent)
    .. cg.if_stmt("not ok", catch_body, nil, nil, indent)
end

-- === Expressions ===

gen.BinaryExpression = function(node, indent, scopes)
  local op = node.operator
  local left = emit(node.left, indent, scopes)
  local right = emit(node.right, indent, scopes)
  if op == "+" then
    return cg.call("_ljs_add", {left, right})
  elseif op == "===" then
    return cg.binop("==", left, right)
  elseif op == "!==" then
    return cg.binop("~=", left, right)
  elseif op == "&&" then
    return cg.binop("and", left, right)
  elseif op == "||" then
    return cg.binop("or", left, right)
  elseif op == "=" then
    return cg.binop("=", left, right)
  elseif op == "+=" then
    return cg.binop("=", left, cg.call("_ljs_add", {left, right}))
  elseif op == "-=" or op == "*=" or op == "/=" or op == "%=" then
    local base_op = op:sub(1, 1)
    return cg.binop("=", left, cg.binop(base_op, left, right))
  else
    return cg.binop(op, left, right)
  end
end

gen.UnaryExpression = function(node, indent, scopes)
  local expr = emit(node.argument, indent, scopes)
  if node.operator == "!" then
    return cg.unop("not", expr)
  elseif node.operator == "+" then
    return cg.call("tonumber", {expr})
  end
  return cg.unop("-", expr)
end

gen.UpdateExpression = function(node, indent, scopes)
  local arg = emit(node.argument, indent, scopes)
  if node.operator == "++" then
    local add = cg.call("_ljs_add", {arg, "1"})
    if node.prefix then
      return "(function() " .. arg .. " = " .. add .. "; return " .. arg .. " end)()"
    end
    return "(function() local _t = " .. arg .. "; " .. arg .. " = " .. add .. "; return _t end)()"
  end
  local sub = arg .. " - 1"
  if node.prefix then
    return "(function() " .. arg .. " = " .. sub .. "; return " .. arg .. " end)()"
  end
  return "(function() local _t = " .. arg .. "; " .. arg .. " = " .. sub .. "; return _t end)()"
end

gen.ConditionalExpression = function(node, indent, scopes)
  local test_code = emit(node.test, indent, scopes)
  local cons_code = emit(node.consequent, indent, scopes)
  local alt_code = emit(node.alternate, indent, scopes)
  return "(function() if " .. test_code .. " then return " .. cons_code .. " else return " .. alt_code .. " end end)()"
end

gen.CallExpression = function(node, indent, scopes)
  local args = {}
  for _, a in ipairs(node.arguments) do args[#args + 1] = emit(a, indent, scopes) end
  local builtin = lookup_builtin(node, scopes)
  if builtin then
    return cg.call(builtin.helper, args)
  end
  return cg.call(emit(node.callee, indent, scopes), args)
end

gen.MemberExpression = function(node, indent, scopes)
  local obj = emit(node.object, indent, scopes)
  if node.computed then
    if node.property.type == "StringLiteral" then
      return cg.member_index(obj, emit(node.property, indent, scopes))
    end
    return cg.member_index(obj, "(" .. emit(node.property, indent, scopes) .. ") + 1")
  end
  return cg.member_dot(obj, node.property.name)
end

-- === Objects and arrays ===

gen.ObjectExpression = function(node, indent, scopes)
  local fields = {}
  for _, prop in ipairs(node.properties) do
    local key
    if prop.key.type == "Identifier" then
      key = prop.key.name
    else
      key = "[\"" .. cg.escape_string(prop.key.value) .. "\"]"
    end
    fields[#fields + 1] = { key = key, value = emit(prop.value, indent, scopes) }
  end
  return cg.object(fields)
end

gen.ArrayExpression = function(node, indent, scopes)
  local elems = {}
  for _, e in ipairs(node.elements) do elems[#elems + 1] = emit(e, indent, scopes) end
  return cg.array(elems)
end

-- === Statement emission for IIFE-returning expressions ===

gen_stmt.UpdateExpression = function(node, indent, scopes)
  local arg = emit(node.argument, indent, scopes)
  if node.operator == "++" then
    return cg.expr_stmt(arg .. " = " .. cg.call("_ljs_add", {arg, "1"}), indent)
  end
  return cg.expr_stmt(arg .. " = " .. arg .. " - 1", indent)
end

gen_stmt.ConditionalExpression = function(node, indent, scopes)
  return cg.pad(indent) .. ";" .. emit(node, indent, scopes) .. "\n"
end

-- === Top-level generate ===

local function generate(ast, meta)
  local scopes = {}
  local code = emit(ast, 0, scopes)
  local helper_parts = {}
  for name, _ in pairs(meta.needed_helpers) do
    helper_parts[#helper_parts + 1] = HELPERS[name]
  end
  table.sort(helper_parts)
  local prefix = table.concat(helper_parts, "\n\n")
  if #prefix > 0 then prefix = prefix .. "\n\n" end
  return prefix .. code
end

-- ============================================================================
-- Section 5: Public API
-- ============================================================================

--- Transpile a parsed JS AST into Lua source code.
-- @param ast (table) AST from parser.parse()
-- @return (string) Lua source code
function ljs_transpile.transpile(ast)
  local meta = analyze(ast)
  return generate(ast, meta)
end

--- Parse JS source and transpile to Lua in one step.
-- @param source (string) JavaScript source code
-- @return (string|nil) Lua source code, or nil on error
-- @return (string|nil) Error message, or nil on success
function ljs_transpile.transpile_source(source)
  local parser = require("ljs_parser")
  local ast, err = parser.parse(source)
  if not ast then return nil, err end
  return ljs_transpile.transpile(ast)
end

ljs_transpile.BUILTINS = BUILTINS
ljs_transpile.HELPERS = HELPERS

-- ============================================================================
-- Section 6: Module return
-- ============================================================================

return ljs_transpile
