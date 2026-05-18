local ljs_transpile = {}

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

  elseif t == "ThrowStatement" then
    if node.argument then analyze_node(node.argument, meta, scopes) end

  elseif t == "ReturnStatement" then
    if node.argument then analyze_node(node.argument, meta, scopes) end

  elseif t == "ExpressionStatement" then
    analyze_node(node.expression, meta, scopes)

  elseif t == "BinaryExpression" then
    if node.operator == "+" then
      meta.needed_helpers["_ljs_add"] = true
    end
    analyze_node(node.left, meta, scopes)
    analyze_node(node.right, meta, scopes)

  elseif t == "UnaryExpression" then
    analyze_node(node.argument, meta, scopes)

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
-- Section 4: Pass 2 — Code generation (recursive AST walk, Lua emission)
-- ============================================================================

local function escape_lua_string(s)
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

local function pad(n)
  return string.rep("  ", n)
end

local function is_elseif_chain(node)
  if node.type == "IfStatement" then return true end
  if node.type == "BlockStatement" and #node.body == 1 and node.body[1].type == "IfStatement" then
    return true
  end
  return false
end

local gen = {}

local function emit(node, indent, scopes)
  return gen[node.type](node, indent, scopes)
end

local function emit_body(stmts, indent, scopes)
  local parts = {}
  for _, s in ipairs(stmts) do parts[#parts + 1] = emit(s, indent, scopes) end
  return table.concat(parts)
end

-- === Program ===

gen.Program = function(node, indent, scopes)
  scope_push(scopes)
  local code = emit_body(node.body, indent, scopes)
  scope_pop(scopes)
  return code
end

-- === Literals ===

gen.NumberLiteral = function(node) return tostring(node.value) end

gen.StringLiteral = function(node)
  return '"' .. escape_lua_string(node.value) .. '"'
end

gen.BooleanLiteral = function(node) return node.value and "true" or "false" end

gen.NullLiteral = function() return "nil" end

gen.Identifier = function(node) return node.name end

-- === Statements ===

gen.ExpressionStatement = function(node, indent, scopes)
  return pad(indent) .. emit(node.expression, indent, scopes) .. "\n"
end

gen.VariableDeclaration = function(node, indent, scopes)
  local out = {}
  for _, decl in ipairs(node.declarations) do
    scope_declare(scopes, decl.name.name)
    local init = decl.init
    if not init then
      out[#out + 1] = pad(indent) .. "local " .. decl.name.name .. "\n"
    elseif init.type == "ArrowFunctionExpression" or init.type == "FunctionExpression" then
      local params = {}
      for _, p in ipairs(init.params) do params[#params + 1] = p.name end
      scope_push(scopes)
      for _, p in ipairs(init.params) do scope_declare(scopes, p.name) end
      local body = emit(init.body, indent, scopes)
      scope_pop(scopes)
      out[#out + 1] = pad(indent) .. "local function " .. decl.name.name .. "(" .. table.concat(params, ", ") .. ")\n"
        .. body .. pad(indent) .. "end\n"
    else
      out[#out + 1] = pad(indent) .. "local " .. decl.name.name .. " = " .. emit(init, indent, scopes) .. "\n"
    end
  end
  return table.concat(out)
end

gen.ReturnStatement = function(node, indent, scopes)
  if node.argument then
    return pad(indent) .. "return " .. emit(node.argument, indent, scopes) .. "\n"
  end
  return pad(indent) .. "return\n"
end

gen.ThrowStatement = function(node, indent, scopes)
  return pad(indent) .. "error(" .. emit(node.argument, indent, scopes) .. ", 0)\n"
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
  return pad(indent) .. "local function " .. node.name .. "(" .. table.concat(params, ", ") .. ")\n"
    .. body .. pad(indent) .. "end\n"
end

gen.FunctionExpression = function(node, indent, scopes)
  local params = {}
  for _, p in ipairs(node.params) do params[#params + 1] = p.name end
  scope_push(scopes)
  if node.name then scope_declare(scopes, node.name) end
  for _, p in ipairs(node.params) do scope_declare(scopes, p.name) end
  local body = emit(node.body, indent, scopes)
  scope_pop(scopes)
  return "function(" .. table.concat(params, ", ") .. ")\n"
    .. body .. pad(indent) .. "end"
end

gen.ArrowFunctionExpression = gen.FunctionExpression

-- === Control flow ===

gen.BlockStatement = function(node, indent, scopes)
  scope_push(scopes)
  local code = emit_body(node.body, indent + 1, scopes)
  scope_pop(scopes)
  return code
end

local function emit_if_parts(node, indent, scopes, keyword)
  local code = pad(indent) .. keyword .. " " .. emit(node.test, indent, scopes) .. " then\n"
    .. emit(node.consequent, indent, scopes)
  if not node.alternate then
    return code .. pad(indent) .. "end\n"
  end
  if is_elseif_chain(node.alternate) then
    local inner = node.alternate.type == "IfStatement" and node.alternate or node.alternate.body[1]
    return code .. emit_if_parts(inner, indent, scopes, "elseif")
  end
  return code .. pad(indent) .. "else\n"
    .. emit(node.alternate, indent, scopes)
    .. pad(indent) .. "end\n"
end

gen.IfStatement = function(node, indent, scopes)
  return emit_if_parts(node, indent, scopes, "if")
end

gen.WhileStatement = function(node, indent, scopes)
  return pad(indent) .. "while " .. emit(node.test, indent, scopes) .. " do\n"
    .. emit(node.body, indent, scopes)
    .. pad(indent) .. "end\n"
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
  scope_pop(scopes)
  return pad(indent) .. "for _, " .. var_name .. " in ipairs(" .. emit(node.right, indent, scopes) .. ") do\n"
    .. body .. pad(indent) .. "end\n"
end

gen.ForStatement = function(node, indent, scopes)
  local parts = {}
  if node.init then
    parts[#parts + 1] = emit(node.init, indent, scopes)
  end
  local test_code = node.test and emit(node.test, indent, scopes) or "true"
  parts[#parts + 1] = pad(indent) .. "while " .. test_code .. " do\n"
  scope_push(scopes)
  if node.init and node.init.type == "VariableDeclaration" then
    for _, decl in ipairs(node.init.declarations) do
      scope_declare(scopes, decl.name.name)
    end
  end
  local body = emit(node.body, indent, scopes)
  if node.update then
    body = body .. pad(indent + 1) .. emit(node.update, indent + 1, scopes) .. "\n"
  end
  scope_pop(scopes)
  parts[#parts + 1] = body .. pad(indent) .. "end\n"
  return table.concat(parts)
end

-- === Exception handling ===

gen.TryStatement = function(node, indent, scopes)
  local param = node.handler.param.name
  scope_push(scopes)
  scope_declare(scopes, param)
  local catch_body = emit(node.handler.body, indent, scopes)
  scope_pop(scopes)
  return pad(indent) .. "local ok, " .. param .. " = pcall(function()\n"
    .. emit(node.block, indent, scopes)
    .. pad(indent) .. "end)\n"
    .. pad(indent) .. "if not ok then\n"
    .. catch_body
    .. pad(indent) .. "end\n"
end

-- === Expressions ===

gen.BinaryExpression = function(node, indent, scopes)
  local op = node.operator
  if op == "+" then
    return "_ljs_add(" .. emit(node.left, indent, scopes) .. ", " .. emit(node.right, indent, scopes) .. ")"
  elseif op == "===" then
    return emit(node.left, indent, scopes) .. " == " .. emit(node.right, indent, scopes)
  elseif op == "!==" then
    return emit(node.left, indent, scopes) .. " ~= " .. emit(node.right, indent, scopes)
  elseif op == "&&" then
    return emit(node.left, indent, scopes) .. " and " .. emit(node.right, indent, scopes)
  elseif op == "||" then
    return emit(node.left, indent, scopes) .. " or " .. emit(node.right, indent, scopes)
  elseif op == "=" then
    return emit(node.left, indent, scopes) .. " = " .. emit(node.right, indent, scopes)
  else
    return emit(node.left, indent, scopes) .. " " .. op .. " " .. emit(node.right, indent, scopes)
  end
end

gen.UnaryExpression = function(node, indent, scopes)
  if node.operator == "!" then
    return "not " .. emit(node.argument, indent, scopes)
  end
  return "-" .. emit(node.argument, indent, scopes)
end

gen.CallExpression = function(node, indent, scopes)
  local args = {}
  for _, a in ipairs(node.arguments) do args[#args + 1] = emit(a, indent, scopes) end
  local builtin = lookup_builtin(node, scopes)
  if builtin then
    return builtin.helper .. "(" .. table.concat(args, ", ") .. ")"
  end
  return emit(node.callee, indent, scopes) .. "(" .. table.concat(args, ", ") .. ")"
end

gen.MemberExpression = function(node, indent, scopes)
  local obj = emit(node.object, indent, scopes)
  if node.computed then
    if node.property.type == "StringLiteral" then
      return obj .. "[" .. emit(node.property, indent, scopes) .. "]"
    end
    return obj .. "[(" .. emit(node.property, indent, scopes) .. ") + 1]"
  end
  return obj .. "." .. node.property.name
end

-- === Objects and arrays ===

gen.ObjectExpression = function(node, indent, scopes)
  if #node.properties == 0 then return "{}" end
  local parts = {}
  for _, prop in ipairs(node.properties) do
    local key
    if prop.key.type == "Identifier" then
      key = prop.key.name
    else
      key = "[\"" .. escape_lua_string(prop.key.value) .. "\"]"
    end
    parts[#parts + 1] = key .. " = " .. emit(prop.value, indent, scopes)
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

gen.ArrayExpression = function(node, indent, scopes)
  local elems = {}
  for _, e in ipairs(node.elements) do elems[#elems + 1] = emit(e, indent, scopes) end
  return "{" .. table.concat(elems, ", ") .. "}"
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

function ljs_transpile.transpile(ast)
  local meta = analyze(ast)
  return generate(ast, meta)
end

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
