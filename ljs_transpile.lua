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
  -- TODO: dispatch on node type
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
