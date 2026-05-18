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

local function is_console_log(node, scopes)
  if node.type ~= "CallExpression" then return false end
  local callee = node.callee
  if not callee or callee.type ~= "MemberExpression" then return false end
  if callee.computed then return false end
  if callee.object.type ~= "Identifier" or callee.object.name ~= "console" then return false end
  if callee.property.type ~= "Identifier" or callee.property.name ~= "log" then return false end
  return not scope_is_shadowed(scopes, "console")
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
    if is_console_log(node, scopes) then
      meta.needed_helpers["_ljs_log"] = true
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

local function generate(ast, meta)
  error("not implemented: generate")
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

ljs_transpile.HELPERS = HELPERS

-- ============================================================================
-- Section 6: Module return
-- ============================================================================

return ljs_transpile
