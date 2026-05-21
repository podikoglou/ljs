local ljs_transpile = {}

local cg = require("ljs_codegen")

-- ============================================================================
-- Section 2: Helper definitions (HELPERS registry)
-- ============================================================================

local HELPERS = {}

HELPERS._ljs_to_int32 = [[local function _ljs_to_int32(x)
  x = math.floor(x) % 0x100000000
  if x >= 0x80000000 then x = x - 0x100000000 end
  return x
end]]

HELPERS._ljs_add = [[local function _ljs_add(a, b)
  if type(a) == "string" or type(b) == "string" then
    return tostring(a) .. tostring(b)
  end
  return a + b
end]]

HELPERS._ljs_bnot = [[local function _ljs_bnot(x)
  return -_ljs_to_int32(x) - 1
end]]

HELPERS._ljs_band = [[local function _ljs_band(a, b)
  a = math.floor(a) % 0x100000000
  b = math.floor(b) % 0x100000000
  local r, m = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return _ljs_to_int32(r)
end]]

HELPERS._ljs_bor = [[local function _ljs_bor(a, b)
  a = math.floor(a) % 0x100000000
  b = math.floor(b) % 0x100000000
  local r, m = 0, 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return _ljs_to_int32(r)
end]]

HELPERS._ljs_bxor = [[local function _ljs_bxor(a, b)
  a = math.floor(a) % 0x100000000
  b = math.floor(b) % 0x100000000
  local r, m = 0, 1
  while a > 0 or b > 0 do
    if a % 2 ~= b % 2 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return _ljs_to_int32(r)
end]]

HELPERS._ljs_shl = [[local function _ljs_shl(a, b)
  a = _ljs_to_int32(a)
  b = math.floor(b) % 32
  if b == 0 then return a end
  return _ljs_to_int32(a * 2^b)
end]]

HELPERS._ljs_shr = [[local function _ljs_shr(a, b)
  a = _ljs_to_int32(a)
  b = math.floor(b) % 32
  if b == 0 then return a end
  return math.floor(a / 2^b)
end]]

HELPERS._ljs_usr = [[local function _ljs_usr(a, b)
  a = math.floor(a) % 0x100000000
  b = math.floor(b) % 32
  if b == 0 then return a end
  return math.floor(a / 2^b)
end]]

HELPERS._ljs_typeof = [[local function _ljs_typeof(x)
  local t = type(x)
  if t == "nil" then return "undefined"
  elseif t == "table" then
    local mt = getmetatable(x)
    if mt and mt.__call then return "function" end
    return "object"
  else return t end
end]]

HELPERS._ljs_call = [[local function _ljs_call(fn, ...)
  return fn(nil, ...)
end]]

HELPERS._ljs_call_member = [[local function _ljs_call_member(obj, key, ...)
  return obj[key](obj, ...)
end]]

HELPERS._ljs_object = [[local function _ljs_object(t)
  return t
end]]

HELPERS._ljs_object_create = [[local function _ljs_object_create(_ljs_this, proto)
  return setmetatable({}, {__index = proto})
end]]

HELPERS._ljs_ctor = [[local function _ljs_ctor(fn)
  local ctor = {}
  ctor.prototype = {}
  ctor.prototype.constructor = ctor
  return setmetatable(ctor, {
    __call = function(_, ...)
      return fn(...)
    end,
  })
end]]

HELPERS._ljs_new = [[local function _ljs_new(ctor, ...)
  local proto = ctor.prototype
  local instance = setmetatable({}, {__index = proto})
  local result = ctor(instance, ...)
  if type(result) == "table" then
    return result
  end
  return instance
end]]

HELPERS._ljs_instanceof = [[local function _ljs_instanceof(value, ctor)
  if type(value) ~= "table" then
    return false
  end
  local target = ctor.prototype
  if target == nil then
    return false
  end
  local proto = getmetatable(value)
  if proto then proto = proto.__index end
  while proto ~= nil do
    if proto == target then
      return true
    end
    local mt = getmetatable(proto)
    proto = mt and mt.__index
  end
  return false
end]]

-- ============================================================================
-- Section 3: Pass 1 — Analysis (scope tracker, helper detection)
-- ============================================================================

local BUILTINS = {}

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
    if scopes[i][name] then
      return true
    end
  end
  return false
end

local function lookup_builtin(node, scopes)
  if node.type ~= "CallExpression" then
    return nil
  end
  local callee = node.callee
  if not callee or callee.type ~= "MemberExpression" then
    return nil
  end
  if callee.computed then
    return nil
  end
  if callee.object.type ~= "Identifier" then
    return nil
  end
  if callee.property.type ~= "Identifier" then
    return nil
  end
  local obj_entry = BUILTINS[callee.object.name]
  if not obj_entry then
    return nil
  end
  local entry = obj_entry[callee.property.name]
  if not entry then
    return nil
  end
  if scope_is_shadowed(scopes, callee.object.name) then
    return nil
  end
  return entry
end

local function analyze_node(node, meta, scopes)
  if not node or type(node) ~= "table" then
    return
  end
  local t = node.type

  if t == "Program" then
    scope_push(scopes)
    for _, child in ipairs(node.body) do
      analyze_node(child, meta, scopes)
    end
    scope_pop(scopes)
  elseif t == "BlockStatement" then
    scope_push(scopes)
    for _, child in ipairs(node.body) do
      analyze_node(child, meta, scopes)
    end
    scope_pop(scopes)
  elseif t == "VariableDeclaration" then
    for _, decl in ipairs(node.declarations) do
      scope_declare(scopes, decl.name.name)
      if decl.init then
        analyze_node(decl.init, meta, scopes)
      end
    end
  elseif t == "FunctionDeclaration" then
    scope_declare(scopes, node.name)
    scope_push(scopes)
    for _, p in ipairs(node.params) do
      scope_declare(scopes, p.name)
    end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)
  elseif t == "FunctionExpression" then
    scope_push(scopes)
    if node.name then
      scope_declare(scopes, node.name)
    end
    for _, p in ipairs(node.params) do
      scope_declare(scopes, p.name)
    end
    analyze_node(node.body, meta, scopes)
    scope_pop(scopes)
  elseif t == "ArrowFunctionExpression" then
    scope_push(scopes)
    for _, p in ipairs(node.params) do
      scope_declare(scopes, p.name)
    end
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
    if node.init then
      analyze_node(node.init, meta, scopes)
    end
    if node.test then
      analyze_node(node.test, meta, scopes)
    end
    if node.update then
      analyze_node(node.update, meta, scopes)
    end
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
    if node.alternate then
      analyze_node(node.alternate, meta, scopes)
    end
  elseif t == "WhileStatement" then
    analyze_node(node.test, meta, scopes)
    analyze_node(node.body, meta, scopes)
  elseif t == "DoWhileStatement" then
    analyze_node(node.body, meta, scopes)
    analyze_node(node.test, meta, scopes)
  elseif t == "TryStatement" then
    analyze_node(node.block, meta, scopes)
    if node.handler then
      analyze_node(node.handler, meta, scopes)
    end
    if node.finalizer then
      analyze_node(node.finalizer, meta, scopes)
    end
  elseif t == "SwitchStatement" then
    analyze_node(node.discriminant, meta, scopes)
    for _, case in ipairs(node.cases) do
      if case.test then
        analyze_node(case.test, meta, scopes)
      end
      for _, stmt in ipairs(case.consequent) do
        analyze_node(stmt, meta, scopes)
      end
    end
  elseif t == "ThrowStatement" then
    if node.argument then
      analyze_node(node.argument, meta, scopes)
    end
  elseif t == "ReturnStatement" then
    if node.argument then
      analyze_node(node.argument, meta, scopes)
    end
  elseif t == "ExpressionStatement" then
    analyze_node(node.expression, meta, scopes)
  elseif t == "BinaryExpression" then
    local op = node.operator
    if op == "+" or op == "+=" then
      meta.needed_helpers["_ljs_add"] = true
    elseif op == "&" or op == "&=" then
      meta.needed_helpers["_ljs_band"] = true
    elseif op == "|" or op == "|=" then
      meta.needed_helpers["_ljs_bor"] = true
    elseif op == "^" or op == "^=" then
      meta.needed_helpers["_ljs_bxor"] = true
    elseif op == "<<" or op == "<<=" then
      meta.needed_helpers["_ljs_shl"] = true
    elseif op == ">>" or op == ">>=" then
      meta.needed_helpers["_ljs_shr"] = true
    elseif op == ">>>" or op == ">>>=" then
      meta.needed_helpers["_ljs_usr"] = true
    elseif op == "instanceof" then
      meta.needed_helpers["_ljs_instanceof"] = true
      meta.needed_helpers["_ljs_ctor"] = true
    end
    analyze_node(node.left, meta, scopes)
    analyze_node(node.right, meta, scopes)
  elseif t == "UpdateExpression" then
    if node.operator == "++" then
      meta.needed_helpers["_ljs_add"] = true
    end
    analyze_node(node.argument, meta, scopes)
  elseif t == "UnaryExpression" then
    if node.operator == "~" then
      meta.needed_helpers["_ljs_bnot"] = true
    end
    analyze_node(node.argument, meta, scopes)
  elseif t == "DeleteExpression" then
    analyze_node(node.argument, meta, scopes)
  elseif t == "TypeofExpression" then
    meta.needed_helpers["_ljs_typeof"] = true
    analyze_node(node.argument, meta, scopes)
  elseif t == "ConditionalExpression" then
    analyze_node(node.test, meta, scopes)
    analyze_node(node.consequent, meta, scopes)
    analyze_node(node.alternate, meta, scopes)
  elseif t == "CallExpression" then
    local builtin = lookup_builtin(node, scopes)
    if builtin then
      meta.needed_helpers[builtin.helper] = true
    elseif node.callee.type == "MemberExpression" then
      meta.needed_helpers["_ljs_call_member"] = true
    else
      meta.needed_helpers["_ljs_call"] = true
    end
    analyze_node(node.callee, meta, scopes)
    for _, arg in ipairs(node.arguments) do
      analyze_node(arg, meta, scopes)
    end
  elseif t == "NewExpression" then
    meta.needed_helpers["_ljs_new"] = true
    meta.needed_helpers["_ljs_ctor"] = true
    analyze_node(node.callee, meta, scopes)
    for _, arg in ipairs(node.arguments) do
      analyze_node(arg, meta, scopes)
    end
  elseif t == "MemberExpression" then
    analyze_node(node.object, meta, scopes)
    if node.computed then
      analyze_node(node.property, meta, scopes)
    end
  elseif t == "ObjectExpression" then
    meta.needed_helpers["_ljs_object"] = true
    for _, prop in ipairs(node.properties) do
      analyze_node(prop.value, meta, scopes)
    end
  elseif t == "ArrayExpression" then
    for _, elem in ipairs(node.elements) do
      analyze_node(elem, meta, scopes)
    end
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
  if not node or type(node) ~= "table" then
    return false
  end
  if node.type == "ContinueStatement" then
    return true
  end
  if
    node.type == "WhileStatement"
    or node.type == "ForOfStatement"
    or node.type == "ForInStatement"
    or node.type == "ForStatement"
    or node.type == "DoWhileStatement"
  then
    return false
  end
  if
    node.type == "FunctionDeclaration"
    or node.type == "FunctionExpression"
    or node.type == "ArrowFunctionExpression"
  then
    return false
  end
  for _, v in pairs(node) do
    if type(v) == "table" then
      if has_continue(v) then
        return true
      end
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
  for _, s in ipairs(stmts) do
    parts[#parts + 1] = emit(s, indent, scopes)
  end
  return table.concat(parts)
end

local function is_elseif_chain(node)
  if node.type == "IfStatement" then
    return true
  end
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
  return cg.local_decl("_ljs_arrow_this", "nil", 0) .. code
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

gen.UndefinedLiteral = function()
  return cg.nil_val()
end

gen.Identifier = function(node)
  return cg.ident(node.name)
end

gen.ThisExpression = function()
  return "_ljs_arrow_this"
end

-- === Statements ===

gen.ExpressionStatement = function(node, indent, scopes)
  local stmt_fn = gen_stmt[node.expression.type]
  if stmt_fn then
    return stmt_fn(node.expression, indent, scopes)
  end
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
      local params = { "_ljs_this" }
      for _, p in ipairs(init.params) do
        params[#params + 1] = p.name
      end
      scope_push(scopes)
      for _, p in ipairs(init.params) do
        scope_declare(scopes, p.name)
      end
      local body = emit(init.body, indent, scopes)
      local save_src = init.type == "ArrowFunctionExpression" and "_ljs_arrow_this" or "_ljs_this"
      body = cg.local_decl("_ljs_arrow_this", save_src, indent + 1) .. body
      scope_pop(scopes)
      if init.type == "FunctionExpression" and not init.is_method then
        out[#out + 1] = cg.local_decl(
          decl.name.name,
          cg.call("_ljs_ctor", { cg.fn_expr(cg.join(params), body, indent) }),
          indent
        )
      else
        out[#out + 1] = cg.local_fn(decl.name.name, cg.join(params), body, indent)
      end
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
  return cg.expr_stmt(cg.call("error", { emit(node.argument, indent, scopes), "0" }), indent)
end

-- === Functions ===

gen.FunctionDeclaration = function(node, indent, scopes)
  scope_declare(scopes, node.name)
  local params = { "_ljs_this" }
  for _, p in ipairs(node.params) do
    params[#params + 1] = p.name
  end
  scope_push(scopes)
  for _, p in ipairs(node.params) do
    scope_declare(scopes, p.name)
  end
  local body = emit(node.body, indent, scopes)
  body = cg.local_decl("_ljs_arrow_this", "_ljs_this", indent + 1) .. body
  scope_pop(scopes)
  return cg.local_decl(
    node.name,
    cg.call("_ljs_ctor", { cg.fn_expr(cg.join(params), body, indent) }),
    indent
  )
end

gen.FunctionExpression = function(node, indent, scopes)
  local params = { "_ljs_this" }
  for _, p in ipairs(node.params) do
    params[#params + 1] = p.name
  end
  scope_push(scopes)
  if node.name then
    scope_declare(scopes, node.name)
  end
  for _, p in ipairs(node.params) do
    scope_declare(scopes, p.name)
  end
  local body = emit(node.body, indent, scopes)
  body = cg.local_decl("_ljs_arrow_this", "_ljs_this", indent + 1) .. body
  scope_pop(scopes)
  local fn = cg.fn_expr(cg.join(params), body, indent)
  if node.is_method then
    return fn
  end
  return cg.call("_ljs_ctor", { fn })
end

gen.ArrowFunctionExpression = function(node, indent, scopes)
  local params = { "_ljs_this" }
  for _, p in ipairs(node.params) do
    params[#params + 1] = p.name
  end
  scope_push(scopes)
  for _, p in ipairs(node.params) do
    scope_declare(scopes, p.name)
  end
  local body = emit(node.body, indent, scopes)
  body = cg.local_decl("_ljs_arrow_this", "_ljs_arrow_this", indent + 1) .. body
  scope_pop(scopes)
  return cg.fn_expr(cg.join(params), body, indent)
end

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
    body = body .. cg.label("_continue", indent + 1)
  end
  return cg.while_stmt(test_code, body, indent)
end

gen.DoWhileStatement = function(node, indent, scopes)
  local test_code = emit(node.test, indent, scopes)
  local body = emit(node.body, indent, scopes)
  if has_continue(node.body) then
    body = body .. cg.label("_continue", indent + 1)
  end
  local negated = cg.unop("not", "(" .. test_code .. ")")
  return cg.repeat_until(negated, body, indent)
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
    body = body .. cg.label("_continue", indent + 1)
  end
  scope_pop(scopes)
  local iter = cg.call("ipairs", { emit(node.right, indent, scopes) })
  return cg.for_in_stmt(cg.join({ "_", var_name }), iter, body, indent)
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
    body = body .. cg.label("_continue", indent + 1)
  end
  scope_pop(scopes)
  local iter = cg.call("pairs", { emit(node.right, indent, scopes) })
  return cg.for_in_stmt(cg.join({ var_name, "_" }), iter, body, indent)
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
    body = body .. cg.label("_continue", indent + 1)
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
  return cg.goto_stmt("_continue", indent)
end

-- === Exception handling ===

gen.TryStatement = function(node, indent, scopes)
  local try_body = emit(node.block, indent + 1, scopes)

  local param = node.handler and node.handler.param.name or nil
  local catch_body = nil
  if param then
    scope_push(scopes)
    scope_declare(scopes, param)
    catch_body = emit(node.handler.body, indent + 1, scopes)
    scope_pop(scopes)
  end

  local finalizer_body = nil
  if node.finalizer then
    finalizer_body = emit(node.finalizer, indent + 1, scopes)
  end

  local pcall_fn = cg.fn_expr("", try_body, indent + 1)
  local pcall_expr = cg.call("pcall", { pcall_fn })

  if node.finalizer and not node.handler then
    local names = "_ljs_ok, _ljs_err"
    local pcall_line = cg.local_decl(names, pcall_expr, indent)
    local finally_block = finalizer_body
    local rethrow = cg.if_stmt(
      "not _ljs_ok",
      cg.expr_stmt(cg.call("error", { "_ljs_err" }), indent + 2),
      nil,
      nil,
      indent
    )
    return pcall_line .. finally_block .. rethrow
  end

  if node.finalizer and node.handler then
    local pcall_line = cg.local_decl(cg.join({ "ok", param }), pcall_expr, indent)
    local catch_block = cg.if_stmt("not ok", catch_body, nil, nil, indent)
    return pcall_line .. catch_block .. finalizer_body
  end

  local pcall_line = cg.local_decl(cg.join({ "ok", param }), pcall_expr, indent)
  return pcall_line .. cg.if_stmt("not ok", catch_body, nil, nil, indent)
end

-- === Expressions ===

gen.BinaryExpression = function(node, indent, scopes)
  local op = node.operator
  local left = emit(node.left, indent, scopes)
  local right = emit(node.right, indent, scopes)
  if op == "+" then
    return cg.call("_ljs_add", { left, right })
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
    return cg.binop("=", left, cg.call("_ljs_add", { left, right }))
  elseif op == "**" then
    return cg.binop("^", left, right)
  elseif op == "**=" then
    return cg.binop("=", left, cg.binop("^", left, right))
  elseif op == "-=" or op == "*=" or op == "/=" or op == "%=" then
    local base_op = op:sub(1, 1)
    return cg.binop("=", left, cg.binop(base_op, left, right))
  elseif op == "&" then
    return cg.call("_ljs_band", { left, right })
  elseif op == "|" then
    return cg.call("_ljs_bor", { left, right })
  elseif op == "^" then
    return cg.call("_ljs_bxor", { left, right })
  elseif op == "<<" then
    return cg.call("_ljs_shl", { left, right })
  elseif op == ">>" then
    return cg.call("_ljs_shr", { left, right })
  elseif op == ">>>" then
    return cg.call("_ljs_usr", { left, right })
  elseif op == "&=" then
    return cg.binop("=", left, cg.call("_ljs_band", { left, right }))
  elseif op == "|=" then
    return cg.binop("=", left, cg.call("_ljs_bor", { left, right }))
  elseif op == "^=" then
    return cg.binop("=", left, cg.call("_ljs_bxor", { left, right }))
  elseif op == "<<=" then
    return cg.binop("=", left, cg.call("_ljs_shl", { left, right }))
  elseif op == ">>=" then
    return cg.binop("=", left, cg.call("_ljs_shr", { left, right }))
  elseif op == ">>>=" then
    return cg.binop("=", left, cg.call("_ljs_usr", { left, right }))
  elseif op == "instanceof" then
    return cg.call("_ljs_instanceof", { left, right })
  elseif op == "in" then
    local key_code
    if node.left.type == "StringLiteral" then
      key_code = left
    else
      key_code = cg.binop("+", cg.paren(left), "1")
    end
    local right_expr = right:sub(1, 1) == "{" and cg.paren(right) or right
    return cg.paren(cg.binop("~=", cg.member_index(right_expr, key_code), cg.nil_val()))
  else
    return cg.binop(op, left, right)
  end
end

gen.UnaryExpression = function(node, indent, scopes)
  local expr = emit(node.argument, indent, scopes)
  if node.operator == "!" then
    return cg.unop("not", expr)
  elseif node.operator == "~" then
    return cg.call("_ljs_bnot", { expr })
  elseif node.operator == "+" then
    return cg.call("tonumber", { expr })
  end
  return cg.unop("-", expr)
end

local function delete_key_and_obj(arg, indent, scopes)
  if arg.type ~= "MemberExpression" then
    return nil, nil
  end
  local obj = emit(arg.object, indent, scopes)
  local key
  if arg.computed then
    if arg.property.type == "StringLiteral" then
      key = emit(arg.property, indent, scopes)
    else
      key = cg.binop("+", cg.paren(emit(arg.property, indent, scopes)), "1")
    end
  else
    key = cg.string(arg.property.name)
  end
  return obj, key
end

gen.DeleteExpression = function(node, indent, scopes)
  local obj, key = delete_key_and_obj(node.argument, indent, scopes)
  if obj then
    return cg.paren(cg.binop("and", cg.call("rawset", { obj, key, cg.nil_val() }), "true"))
  end
  return "true"
end

gen.TypeofExpression = function(node, indent, scopes)
  return cg.call("_ljs_typeof", { emit(node.argument, indent, scopes) })
end

gen.UpdateExpression = function(node, indent, scopes)
  local arg = emit(node.argument, indent, scopes)
  local val
  if node.operator == "++" then
    val = cg.call("_ljs_add", { arg, "1" })
  else
    val = cg.binop("-", arg, "1")
  end
  if node.prefix then
    return cg.iife({ cg.binop("=", arg, val), cg.return_inline(arg) })
  end
  return cg.iife({ cg.local_inline("_t", arg), cg.binop("=", arg, val), cg.return_inline("_t") })
end

gen.ConditionalExpression = function(node, indent, scopes)
  local test_code = emit(node.test, indent, scopes)
  local cons_code = emit(node.consequent, indent, scopes)
  local alt_code = emit(node.alternate, indent, scopes)
  return cg.iife({ cg.inline_if_return(test_code, cons_code, alt_code) })
end

gen.CallExpression = function(node, indent, scopes)
  local args = {}
  for _, a in ipairs(node.arguments) do
    args[#args + 1] = emit(a, indent, scopes)
  end

  local builtin = lookup_builtin(node, scopes)
  if builtin then
    return cg.call(builtin.helper, args)
  end

  if node.callee.type == "MemberExpression" then
    local obj_expr = emit(node.callee.object, indent, scopes)
    local key_expr
    if node.callee.computed then
      if node.callee.property.type == "StringLiteral" then
        key_expr = emit(node.callee.property, indent, scopes)
      else
        key_expr = cg.binop("+", cg.paren(emit(node.callee.property, indent, scopes)), "1")
      end
    else
      key_expr = cg.string(node.callee.property.name)
    end
    local call_args = { obj_expr, key_expr }
    for _, a in ipairs(args) do
      call_args[#call_args + 1] = a
    end
    return cg.call("_ljs_call_member", call_args)
  end

  local call_args = { emit(node.callee, indent, scopes) }
  for _, a in ipairs(args) do
    call_args[#call_args + 1] = a
  end
  return cg.call("_ljs_call", call_args)
end

gen.NewExpression = function(node, indent, scopes)
  local args = { emit(node.callee, indent, scopes) }
  for _, a in ipairs(node.arguments) do
    args[#args + 1] = emit(a, indent, scopes)
  end
  return cg.call("_ljs_new", args)
end

gen.MemberExpression = function(node, indent, scopes)
  local obj = emit(node.object, indent, scopes)
  if node.computed then
    if node.property.type == "StringLiteral" then
      return cg.member_index(obj, emit(node.property, indent, scopes))
    end
    return cg.member_index(obj, cg.binop("+", cg.paren(emit(node.property, indent, scopes)), "1"))
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
      key = cg.bracket_key(cg.string(prop.key.value))
    end
    fields[#fields + 1] = { key = key, value = emit(prop.value, indent, scopes) }
  end
  return cg.call("_ljs_object", { cg.object(fields) })
end

gen.ArrayExpression = function(node, indent, scopes)
  local elems = {}
  for _, e in ipairs(node.elements) do
    elems[#elems + 1] = emit(e, indent, scopes)
  end
  return cg.array(elems)
end

-- === Statement emission for IIFE-returning expressions ===

gen_stmt.UpdateExpression = function(node, indent, scopes)
  local arg = emit(node.argument, indent, scopes)
  if node.operator == "++" then
    return cg.expr_stmt(cg.binop("=", arg, cg.call("_ljs_add", { arg, "1" })), indent)
  end
  return cg.expr_stmt(cg.binop("=", arg, cg.binop("-", arg, "1")), indent)
end

gen_stmt.ConditionalExpression = function(node, indent, scopes)
  return cg.expr_stmt(emit(node, indent, scopes), indent)
end

gen_stmt.DeleteExpression = function(node, indent, scopes)
  local obj, key = delete_key_and_obj(node.argument, indent, scopes)
  if obj then
    return cg.expr_stmt(cg.call("rawset", { obj, key, cg.nil_val() }), indent)
  end
  return ""
end

gen_stmt.TypeofExpression = function(node, indent, scopes)
  return ""
end

-- === Top-level generate ===

local function generate(ast, meta)
  if
    meta.needed_helpers["_ljs_bnot"]
    or meta.needed_helpers["_ljs_band"]
    or meta.needed_helpers["_ljs_bor"]
    or meta.needed_helpers["_ljs_bxor"]
    or meta.needed_helpers["_ljs_shl"]
    or meta.needed_helpers["_ljs_shr"]
    or meta.needed_helpers["_ljs_usr"]
  then
    meta.needed_helpers["_ljs_to_int32"] = true
  end
  meta.needed_helpers["_ljs_object"] = true
  meta.needed_helpers["_ljs_object_create"] = true
  meta.needed_helpers["_ljs_ctor"] = true
  meta.needed_helpers["_ljs_new"] = true
  meta.needed_helpers["_ljs_instanceof"] = true
  local scopes = {}
  local code = emit(ast, 0, scopes)
  local helper_parts = {}
  if meta.needed_helpers["_ljs_to_int32"] then
    helper_parts[#helper_parts + 1] = HELPERS["_ljs_to_int32"]
  end
  local rest = {}
  for name, _ in pairs(meta.needed_helpers) do
    if name ~= "_ljs_to_int32" then
      rest[#rest + 1] = HELPERS[name]
    end
  end
  table.sort(rest)
  for _, h in ipairs(rest) do
    helper_parts[#helper_parts + 1] = h
  end
  local prefix = table.concat(helper_parts, "\n\n")
  if #prefix > 0 then
    prefix = prefix .. "\n\n"
  end
  local runtime_init = [[
local Object = _ljs_ctor(function(_ljs_this)
  return _ljs_this
end)
Object.create = _ljs_object_create

local console = _ljs_object({})
console.log = function(_ljs_this, ...)
  print(...)
end

]]
  return prefix .. runtime_init .. code
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
  if not ast then
    return nil, err
  end
  return ljs_transpile.transpile(ast)
end

ljs_transpile.BUILTINS = BUILTINS
ljs_transpile.HELPERS = HELPERS

-- ============================================================================
-- Section 6: Module return
-- ============================================================================

return ljs_transpile
