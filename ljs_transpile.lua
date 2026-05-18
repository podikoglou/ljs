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

local function analyze(ast)
  error("not implemented: analyze")
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
