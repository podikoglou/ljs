--- Transpiler: AST → Lua source via codegen.
-- Depends on `ljs.codegen` for all Lua syntax construction; never concatenates
-- raw Lua keywords/operators itself. Depends on `ljs.parser` only via the
-- public API (`M.transpile_source`).
--
-- Architecture:
--   JS source → [Parser] → AST → [this module] → cg.* calls → [Codegen] → Lua source
--
-- The transpiler decides WHAT to emit based on the AST node type.
-- Codegen decides HOW to format it as Lua source text.
-- See docs/ARCHITECTURE.md § "Transpiler boundary rule" for the full contract.
--
-- Key design decisions:
--   - All JS functions receive a hidden `_ljs_this` first parameter (JS-ABI).
--   - `this` compiles to `_ljs_arrow_this`, which is saved from `_ljs_this`
--     (regular functions) or captured via closure (arrow functions).
--   - `goto`/`labels` are used for `continue` (Lua has no `continue` keyword).
--   - `switch` is lowered to chained `if/elseif` wrapped in a single-iteration
--     `for` loop so `break` exits the switch without leaving the enclosing loop.
--   - `try/catch/finally` is lowered to `pcall` with manual rethrow for
--     finally-only blocks.
--   - Expression-context constructs that need statements (ternary, ++/--) are
--     wrapped in IIFEs; statement-context versions avoid the IIFE overhead.
local M = {}

local cg = require("ljs.codegen")
local ast = require("ljs.ast")

--- Read a runtime template file from the runtime/ directory.
-- Uses debug.getinfo to resolve the path relative to this source file,
-- so it works regardless of the working directory.
-- @param name (string) Runtime file name without extension (e.g. "proto", "object")
-- @return (string) File content with trailing newline
-- @error "cannot open runtime file: <path>" if the file doesn't exist
local function read_runtime(name)
  local info = debug.getinfo(1, "S")
  local dir = info.source:gsub("^@", ""):match("^(.*/)")
  local path = dir .. "runtime/" .. name .. ".lua"
  local f = io.open(path, "r")
  if not f then
    error("cannot open runtime file: " .. path)
  end
  local content = f:read("*a")
  f:close()
  return content .. "\n"
end

-- ============================================================================
-- Runtime helpers (emitted unconditionally in every preamble).
-- These are the JS-ABI runtime functions that support operator semantics,
-- prototype chains, and constructor mechanics. All 22 are always emitted
-- regardless of whether the source code uses them — no tree-shaking pass.
-- See docs/ARCHITECTURE.md § "Runtime call ABI" and "Constructors".
-- ============================================================================

local HELPERS = {}

HELPERS._ljs_to_int32 = [[local function _ljs_to_int32(x)
  x = math.floor(x) % 0x100000000
  if x >= 0x80000000 then x = x - 0x100000000 end
  return x
end]]

HELPERS._ljs_to_number = [[local function _ljs_to_number(x)
  if x == _ljs_null then
    return 0
  end
  if x == nil then
    return 0 / 0
  end
  local tx = type(x)
  if tx == "boolean" then
    return x and 1 or 0
  end
  if tx == "number" then
    return x
  end
  if tx == "string" then
    local t = x:match("^%s*(.-)%s*$")
    if t == "" then
      return 0
    end
    if t == "Infinity" or t == "+Infinity" then
      return math.huge
    end
    if t == "-Infinity" then
      return -math.huge
    end
    local s, p = t:match("^([+-]?)(0[bBoOxX])")
    if p then
      if s ~= "" then return 0 / 0 end
      local lo = p:lower()
      local digits = t:sub(3)
      if digits == "" then return 0 / 0 end
      if lo == "0x" then
        if not digits:match("^%x+$") then return 0 / 0 end
        return tonumber(t)
      elseif lo == "0o" then
        if not digits:match("^[0-7]+$") then return 0 / 0 end
        return tonumber(digits, 8)
      else
        if not digits:match("^[01]+$") then return 0 / 0 end
        return tonumber(digits, 2)
      end
    end
    local n = tonumber(t)
    if n then
      if n == 0 and t:match("^%-") then
        return -1 / math.huge
      end
      return n
    end
    return 0 / 0
  end
  if tx == "table" then
    return _ljs_to_number(_ljs_to_primitive(x))
  end
  return 0 / 0
end]]

HELPERS._ljs_to_boolean = [[local function _ljs_to_boolean(x)
  if x == nil or x == _ljs_null then
    return false
  end
  if type(x) == "boolean" then
    return x
  end
  if type(x) == "number" then
    return x ~= 0 and x == x
  end
  if type(x) == "string" then
    return #x > 0
  end
  return true
end]]

HELPERS._ljs_tostring = [[local function _ljs_tostring(x)
  if x == _ljs_null then return "null"
  elseif x == nil then return "undefined"
  elseif type(x) == "number" then
    if x ~= x then return "NaN" end
    if x == math.huge then return "Infinity" end
    if x == -math.huge then return "-Infinity" end
    if x == 0 then return "0" end
    if math.floor(x) == x then return tostring(math.floor(x)) end
    return tostring(x)
  else return tostring(x) end
end]]

HELPERS._ljs_add = [[local function _ljs_add(a, b)
  if type(a) == "string" or type(b) == "string" then
    return _ljs_tostring(a) .. _ljs_tostring(b)
  end
  return _ljs_to_number(a) + _ljs_to_number(b)
end]]

HELPERS._ljs_sub = [[local function _ljs_sub(a, b)
  return _ljs_to_number(a) - _ljs_to_number(b)
end]]

HELPERS._ljs_mul = [[local function _ljs_mul(a, b)
  return _ljs_to_number(a) * _ljs_to_number(b)
end]]

HELPERS._ljs_div = [[local function _ljs_div(a, b)
  return _ljs_to_number(a) / _ljs_to_number(b)
end]]

HELPERS._ljs_pow = [[local function _ljs_pow(a, b)
  a = _ljs_to_number(a)
  b = _ljs_to_number(b)
  if b ~= b then return 0 / 0 end
  if (a == 1 or a == -1) and (b == math.huge or b == -math.huge) then return 0 / 0 end
  return a ^ b
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

HELPERS._ljs_mod = [[local function _ljs_mod(n, d)
  if n ~= n or d ~= d then return 0/0 end
  if n == math.huge or n == -math.huge then return 0/0 end
  if d == math.huge or d == -math.huge then return n end
  if d == 0 then return 0/0 end
  if n == 0 then return n end
  local q = n / d
  local t = q >= 0 and math.floor(q) or math.ceil(q)
  local r = n - t * d
  if r == 0 and 1/n < 0 then return -0.0 end
  return r
end]]

-- typeof per §13.5.3: nil (undefined) → "undefined", _ljs_null → "object".
HELPERS._ljs_typeof = [[local function _ljs_typeof(x)
  if x == nil then return "undefined"
  elseif x == _ljs_null then return "object"
  elseif type(x) == "table" then
    local mt = getmetatable(x)
    if mt and mt.__call then return "function" end
    return "object"
  else return type(x) end
end]]

-- Direct call: f(a,b) → _ljs_call(f,a,b). Passes nil as _ljs_this (no receiver).
HELPERS._ljs_call = [[local function _ljs_call(fn, ...)
  return fn(nil, ...)
end]]

-- ES2026 §7.1.19 ToObject: boxes primitives into wrapper objects for property access.
HELPERS._ljs_to_object = [[local function _ljs_to_object(obj)
  local t = type(obj)
  if t == "number" then
    return setmetatable({ _ljs_data = obj }, { __index = _ljs_number_prototype })
  end
  if t == "string" then
    return setmetatable({ _ljs_data = obj }, { __index = _ljs_string_prototype })
  end
  if t == "boolean" then
    return setmetatable({ _ljs_data = obj }, { __index = _ljs_boolean_prototype })
  end
  return obj
end]]

-- Method call: obj.m(a,b) → _ljs_call_member(obj,"m",a,b). Passes obj as _ljs_this.
-- Throws TypeError on null/undefined per RequireObjectCoercible (§7.2.1).
-- Boxes primitives via _ljs_to_object before property lookup.
HELPERS._ljs_call_member = [[local function _ljs_call_member(obj, key, ...)
  if obj == nil or obj == _ljs_null then
    local desc = obj == nil and "undefined" or "null"
    error("TypeError: Cannot read properties of " .. desc .. " (reading '" .. tostring(key) .. "')")
  end
  local boxed = _ljs_to_object(obj)
  return boxed[key](boxed, ...)
end]]

-- Wraps a table with Object.prototype as __index. Used for all object literals.
HELPERS._ljs_object = [[local function _ljs_object(t)
  return setmetatable(t, { __index = _ljs_object_prototype })
end]]

HELPERS._ljs_object_create = [[local function _ljs_object_create(_ljs_this, proto)
  return setmetatable({}, {__index = proto})
end]]

-- Wraps a plain Lua function as a callable table with Function.prototype chain.
-- Used for arrow functions and method shorthand — no .prototype property.
HELPERS._ljs_fn = [[local function _ljs_fn(fn)
  return setmetatable({}, {
    __call = function(_, ...)
      return fn(...)
    end,
    __index = _ljs_function_prototype,
  })
end]]

-- Wraps a function as a constructor: callable table + .prototype inheriting
-- from _ljs_object_prototype. Used for FunctionDeclaration, FunctionExpression,
-- and class constructors.
HELPERS._ljs_ctor = [[local function _ljs_ctor(fn)
  local ctor = _ljs_fn(fn)
  ctor.prototype = setmetatable({ constructor = ctor }, { __index = _ljs_object_prototype })
  return ctor
end]]

-- new Foo(args) → creates instance with Foo.prototype chain, calls ctor.
-- If ctor returns a table, that table is returned instead of the instance
-- (matching JS constructor return semantics).
HELPERS._ljs_new = [[local function _ljs_new(ctor, ...)
  local proto = ctor.prototype
  local instance = setmetatable({}, {__index = proto})
  local result = ctor(instance, ...)
  if type(result) == "table" then
    return result
  end
  return instance
end]]

-- Walks __index chain checking for ctor.prototype. Primitives always false.
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

-- super.method() → looks up proto[key] and calls with the current instance.
HELPERS._ljs_super_call = [[local function _ljs_super_call(proto, key, this_val, ...)
  return proto[key](this_val, ...)
  end]]

-- ToPrimitive per §7.1.1: OrdinaryToPrimitive with hint=number.
-- Tries valueOf first, then toString. Returns first primitive result.
-- Throws TypeError if neither returns a primitive.
-- Per §7.1.1.1 step 3.b: only calls method if IsCallable is true.
HELPERS._ljs_to_primitive = [[local function _ljs_to_primitive(obj)
  local function _callable(v)
    if type(v) == "function" then return true end
    if type(v) == "table" then
      local mt = getmetatable(v)
      return mt and mt.__call ~= nil
    end
    return false
  end
  local val_of = obj.valueOf
  if _callable(val_of) then
    local result = val_of(obj)
    if type(result) ~= "table" then return result end
  end
  local to_str = obj.toString
  if _callable(to_str) then
    local result = to_str(obj)
    if type(result) ~= "table" then return result end
  end
  error("TypeError: Cannot convert object to primitive value")
end]]

-- StringToNumber per §7.1.4.1: converts a JS string to a number.
-- Lua's tonumber() doesn't handle "", whitespace-only, "Infinity".
HELPERS._ljs_str_to_num = [[local function _ljs_str_to_num(s)
  local t = s:match("^%s*(.-)%s*$")
  if t == "" then return 0 end
  if t == "Infinity" or t == "+Infinity" then return math.huge end
  if t == "-Infinity" then return -math.huge end
  local s, p = t:match("^([+-]?)(0[bBoOxX])")
  if p then
    if s ~= "" then return 0 / 0 end
    local lo = p:lower()
    local digits = t:sub(3)
    if digits == "" then return 0 / 0 end
    if lo == "0x" then
      if not digits:match("^%x+$") then return 0 / 0 end
      return tonumber(t)
    elseif lo == "0o" then
      if not digits:match("^[0-7]+$") then return 0 / 0 end
      return tonumber(digits, 8)
    else
      if not digits:match("^[01]+$") then return 0 / 0 end
      return tonumber(digits, 2)
    end
  end
  return tonumber(t) or (0 / 0)
end]]

-- IsLooselyEqual per §7.2.13. Handles == operator semantics.
-- Lua representation: nil = JS undefined, _ljs_null = JS null,
-- number/string/boolean/table = JS Number/String/Boolean/Object.
-- Depends on _ljs_to_primitive and _ljs_str_to_num (must be emitted first).
HELPERS._ljs_eq = [[local function _ljs_eq(a, b)
  local a_is_null = (a == _ljs_null)
  local b_is_null = (b == _ljs_null)
  local ta = a_is_null and "null" or (a == nil) and "undefined" or type(a)
  local tb = b_is_null and "null" or (b == nil) and "undefined" or type(b)
  if ta == tb then
    if ta == "number" then
      if a ~= a or b ~= b then return false end
      return a == b
    end
    return a == b
  end
  if (ta == "null" and tb == "undefined") or (ta == "undefined" and tb == "null") then
    return true
  end
  if ta == "number" and tb == "string" then
    return _ljs_eq(a, _ljs_str_to_num(b))
  end
  if ta == "string" and tb == "number" then
    return _ljs_eq(_ljs_str_to_num(a), b)
  end
  if ta == "boolean" then
    return _ljs_eq(a and 1 or 0, b)
  end
  if tb == "boolean" then
    return _ljs_eq(a, b and 1 or 0)
  end
  if (ta == "string" or ta == "number") and tb == "table" then
    return _ljs_eq(a, _ljs_to_primitive(b))
  end
  if ta == "table" and (tb == "string" or tb == "number") then
    return _ljs_eq(_ljs_to_primitive(a), b)
  end
  return false
end]]

HELPERS._ljs_lt = [[local function _ljs_lt(a, b)
  if type(a) == "string" and type(b) == "string" then
    return a < b
  end
  return _ljs_to_number(a) < _ljs_to_number(b)
end]]

HELPERS._ljs_gt = [[local function _ljs_gt(a, b)
  if type(a) == "string" and type(b) == "string" then
    return a > b
  end
  return _ljs_to_number(a) > _ljs_to_number(b)
end]]

HELPERS._ljs_le = [[local function _ljs_le(a, b)
  if type(a) == "string" and type(b) == "string" then
    return a <= b
  end
  return _ljs_to_number(a) <= _ljs_to_number(b)
end]]

HELPERS._ljs_ge = [[local function _ljs_ge(a, b)
  if type(a) == "string" and type(b) == "string" then
    return a >= b
  end
  return _ljs_to_number(a) >= _ljs_to_number(b)
end]]

-- ============================================================================
-- Section 3: Continue detection helper
-- ============================================================================

--- Check whether an AST subtree contains a ContinueStatement.
-- Stops at loop and function boundaries (each loop handles its own continue).
-- @param node (table|nil) AST node
-- @return (boolean) true if a ContinueStatement exists in the subtree
local function has_continue(node)
  if not node or type(node) ~= "table" then
    return false
  end
  if node.type == ast.TYPE_CONTINUE_STATEMENT then
    return true
  end
  if
    node.type == ast.TYPE_WHILE_STATEMENT
    or node.type == ast.TYPE_FOR_OF_STATEMENT
    or node.type == ast.TYPE_FOR_IN_STATEMENT
    or node.type == ast.TYPE_FOR_STATEMENT
    or node.type == ast.TYPE_DO_WHILE_STATEMENT
  then
    return false
  end
  if
    node.type == ast.TYPE_FUNCTION_DECLARATION
    or node.type == ast.TYPE_FUNCTION_EXPRESSION
    or node.type == ast.TYPE_ARROW_FUNCTION_EXPRESSION
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
-- Section 4: Code generation (JS AST → Lua source via ljs_codegen)
-- ============================================================================

-- ============================================================================
-- Scope tracking (lexical variable declarations).
-- Scopes are a stack of sets; used only for tracking declared names,
-- not for Lua `local` emission (that's handled structurally by emit).
-- ============================================================================

local function scope_push(ctx)
  ctx.scopes[#ctx.scopes + 1] = {}
end

local function scope_pop(ctx)
  ctx.scopes[#ctx.scopes] = nil
end

local function scope_declare(ctx, name)
  ctx.scopes[#ctx.scopes][name] = true
end

-- gen[node_type] handles expression-context emission.
-- gen_stmt[node_type] handles statement-context emission for types that
-- produce different code when used as a statement (e.g. UpdateExpression
-- avoids IIFE overhead in statement context).
local gen = {}
local gen_stmt = {}

--- Compute the Lua string key for a class method definition.
-- Identifier keys use `.name`; literal keys use `.value`.
-- @param m (table) MethodDefinition AST node
-- @return (string) Lua expression for the key (always a cg.string result)
local function method_key(m)
  if m.key.type == ast.TYPE_IDENTIFIER then
    return cg.string(m.key.name)
  end
  return cg.string(m.key.value)
end

--- Dispatch to the type-specific emitter for the given AST node.
-- @param node (table) AST node with a `type` field
-- @param indent (number) Current indentation level
-- @param ctx (table) Transpilation context {eval_mode, super_stack, scopes}
-- @return (string) Lua source fragment
local function emit(node, indent, ctx)
  return gen[node.type](node, indent, ctx)
end

--- Emit a sequence of statements, concatenating their output.
-- @param stmts (table) Array of AST statement nodes
-- @param indent (number) Current indentation level
-- @param ctx (table) Transpilation context
-- @return (string) Concatenated Lua source
local function emit_body(stmts, indent, ctx)
  local parts = {}
  for _, s in ipairs(stmts) do
    parts[#parts + 1] = emit(s, indent, ctx)
  end
  return table.concat(parts)
end

--- Emit a JS function (FunctionExpression/ArrowFunctionExpression/ctor) as a Lua
--- function expression.
-- Prepends `_ljs_this` to the parameter list (JS-ABI hidden-this convention).
-- Emits `local _ljs_arrow_this = _ljs_this` (regular) or `= _ljs_arrow_this`
-- (arrow) at the top of the body so that `this` resolves correctly:
--   - Regular functions: saves the received `_ljs_this` for inner arrows.
--   - Arrow functions: captures the enclosing scope's `_ljs_arrow_this` via
--     closure, matching JS lexical-this semantics.
-- @param fn_node (table) AST FunctionExpression or ArrowFunctionExpression
-- @param indent (number) Current indentation level
-- @param ctx (table) Transpilation context
-- @param extra_scope_names (table|nil) Additional names to declare in scope
--   (used for class expression self-references like the class name inside its body)
-- @return (string) Lua function expression string
local function emit_fn(fn_node, indent, ctx, extra_scope_names)
  local params = { "_ljs_this" }
  for _, p in ipairs(fn_node.params) do
    params[#params + 1] = p.name
  end
  scope_push(ctx)
  if extra_scope_names then
    for _, name in ipairs(extra_scope_names) do
      scope_declare(ctx, name)
    end
  end
  if fn_node.name then
    scope_declare(ctx, fn_node.name)
  end
  for _, p in ipairs(fn_node.params) do
    scope_declare(ctx, p.name)
  end
  local body = emit(fn_node.body, indent, ctx)
  -- Selects the source variable for _ljs_arrow_this:
  --   ArrowFunctionExpression → "_ljs_arrow_this" (captures enclosing scope via closure)
  --   everything else → "_ljs_this" (saves the received hidden-this parameter)
  local save_src = fn_node.type == ast.TYPE_ARROW_FUNCTION_EXPRESSION and "_ljs_arrow_this" or "_ljs_this"
  body = cg.local_decl("_ljs_arrow_this", save_src, indent + 1) .. body
  scope_pop(ctx)
  return cg.fn_expr(cg.join(params), body, indent)
end

local function is_elseif_chain(node)
  if node.type == ast.TYPE_IF_STATEMENT then
    return true
  end
  if node.type == ast.TYPE_BLOCK_STATEMENT and #node.body == 1 and node.body[1].type == ast.TYPE_IF_STATEMENT then
    return true
  end
  return false
end

--- Collect if/elseif/else parts from a JS AST if-else chain.
-- @param node (table) JS IfStatement node
-- @param indent (number) Indentation level
-- @param scopes (table) Transpilation context
-- @return (string) test, (string) then_body, (table|nil) elseifs, (string|nil) else_body
local function collect_if_chain(node, indent, ctx)
  local test = cg.call("_ljs_to_boolean", { emit(node.test, indent, ctx) })
  local body = emit(node.consequent, indent, ctx)
  local elseifs = {}
  local else_body = nil

  local alternate = node.alternate
  while alternate do
    if is_elseif_chain(alternate) then
      local inner = alternate.type == ast.TYPE_IF_STATEMENT and alternate or alternate.body[1]
      elseifs[#elseifs + 1] = {
        test = cg.call("_ljs_to_boolean", { emit(inner.test, indent, ctx) }),
        body = emit(inner.consequent, indent, ctx),
      }
      alternate = inner.alternate
    else
      else_body = emit(alternate, indent, ctx)
      break
    end
  end

  return test, body, elseifs, else_body
end

-- === Program ===

gen.Program = function(node, indent, ctx)
  scope_push(ctx)
  local body = node.body

  -- In eval mode the last expression is returned as the program's value.
  if ctx.eval_mode and #body > 0 and body[#body].type == ast.TYPE_EXPRESSION_STATEMENT then
    local code = ""
    for i = 1, #body - 1 do
      code = code .. emit(body[i], indent, ctx)
    end
    local last_expr = emit(body[#body].expression, indent, ctx)
    code = code .. cg.return_expr(last_expr, indent)
    scope_pop(ctx)
    return code
  end

  local code = emit_body(body, indent, ctx)
  scope_pop(ctx)
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
  return "_ljs_null"
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

gen.ExpressionStatement = function(node, indent, ctx)
  local stmt_fn = gen_stmt[node.expression.type]
  if stmt_fn then
    return stmt_fn(node.expression, indent, ctx)
  end
  return cg.expr_stmt(emit(node.expression, indent, ctx), indent)
end

gen.VariableDeclaration = function(node, indent, ctx)
  local out = {}
  for _, decl in ipairs(node.declarations) do
    scope_declare(ctx, decl.name.name)
    local init = decl.init
    if not init then
      out[#out + 1] = cg.local_decl(decl.name.name, nil, indent)
    -- Split pattern: `local x; x = _ljs_ctor(fn)` instead of `local x = _ljs_ctor(fn)`.
    -- Works around Lua 5.5 closure upvalue issue where the function's self-reference
    -- would resolve to nil if the local hasn't been assigned yet.
    elseif init.type == ast.TYPE_ARROW_FUNCTION_EXPRESSION or init.type == ast.TYPE_FUNCTION_EXPRESSION then
      local fn = emit_fn(init, indent, ctx)
      -- Non-method FunctionExpressions get _ljs_ctor (has .prototype);
      -- arrows and method shorthand get _ljs_fn (no .prototype).
      local wrapper = (init.type == ast.TYPE_FUNCTION_EXPRESSION and not init.is_method) and "_ljs_ctor"
        or "_ljs_fn"
      out[#out + 1] = cg.local_decl(decl.name.name, nil, indent)
      out[#out + 1] = cg.expr_stmt(cg.binop("=", decl.name.name, cg.call(wrapper, { fn })), indent)
    else
      out[#out + 1] = cg.local_decl(decl.name.name, emit(init, indent, ctx), indent)
    end
  end
  return table.concat(out)
end

gen.ReturnStatement = function(node, indent, ctx)
  local expr = node.argument and emit(node.argument, indent, ctx) or nil
  return cg.return_stmt(expr, indent)
end

-- error(msg, 0) — level 0 prevents pcall from adding position info to the message,
-- matching JS throw semantics (the thrown value IS the error).
gen.ThrowStatement = function(node, indent, ctx)
  return cg.expr_stmt(cg.call("error", { emit(node.argument, indent, ctx), "0" }), indent)
end

-- Declarations use the same split pattern as VariableDeclaration for the
-- Lua 5.5 closure upvalue workaround.
gen.FunctionDeclaration = function(node, indent, ctx)
  scope_declare(ctx, node.name)
  local fn = emit_fn(node, indent, ctx)
  return cg.local_decl(node.name, nil, indent)
    .. cg.expr_stmt(cg.binop("=", node.name, cg.call("_ljs_ctor", { fn })), indent)
end

--- Class declaration lowering: syntactic sugar over _ljs_ctor + prototype assignments.
-- Emits: 1) `_ljs_ctor`-wrapped constructor, 2) prototype chain setup if extends,
-- 3) prototype method assignments, 4) static method assignments.
-- See docs/ARCHITECTURE.md § "Class syntax" for the full lowering spec.
gen.ClassDeclaration = function(node, indent, ctx)
  scope_declare(ctx, node.name)

  local class_name = node.name
  local has_super = node.superClass ~= nil
  local super_code = has_super and emit(node.superClass, indent, ctx) or nil

  -- super_stack tracks the current superclass for super()/super.method() resolution.
  -- Pushed here, popped after emission — supports nested classes.
  if has_super then
    ctx.super_stack[#ctx.super_stack + 1] = super_code
  end

  local constructor_method = nil
  local methods = {}
  local statics = {}

  for _, m in ipairs(node.body) do
    if m.kind == "constructor" then
      constructor_method = m
    elseif m.static then
      statics[#statics + 1] = m
    else
      methods[#methods + 1] = m
    end
  end

  -- Default constructor: empty body if no extends, forwards all args to parent otherwise.
  local ctor_fn
  if constructor_method then
    ctor_fn = emit_fn(constructor_method.value, indent, ctx)
  elseif has_super then
    local params = { "_ljs_this", "..." }
    local body_code = cg.expr_stmt(cg.call(super_code, { "_ljs_arrow_this", "..." }), indent + 1)
    body_code = cg.local_decl("_ljs_arrow_this", "_ljs_this", indent + 1) .. body_code
    ctor_fn = cg.fn_expr(cg.join(params), body_code, indent)
  else
    ctor_fn = cg.fn_expr("_ljs_this", "", indent)
  end

  local out = cg.local_decl(class_name, cg.call("_ljs_ctor", { ctor_fn }), indent)

  if has_super then
    local proto_setup = cg.expr_stmt(
      cg.binop(
        "=",
        cg.member_dot(class_name, "prototype"),
        cg.call("_ljs_object_create", { cg.nil_val(), cg.member_dot(super_code, "prototype") })
      ),
      indent
    )
    out = out .. proto_setup
    out = out
      .. cg.expr_stmt(
        cg.binop(
          "=",
          cg.member_dot(cg.member_dot(class_name, "prototype"), "constructor"),
          class_name
        ),
        indent
      )
  end

  for _, m in ipairs(methods) do
    local m_fn = emit_fn(m.value, indent, ctx)
    out = out
      .. cg.expr_stmt(
        cg.binop(
          "=",
          cg.member_index(cg.member_dot(class_name, "prototype"), method_key(m)),
          cg.call("_ljs_fn", { m_fn })
        ),
        indent
      )
  end

  for _, m in ipairs(statics) do
    local m_fn = emit_fn(m.value, indent, ctx)
    out = out
      .. cg.expr_stmt(
        cg.binop("=", cg.member_index(class_name, method_key(m)), cg.call("_ljs_fn", { m_fn })),
        indent
      )
  end

  if has_super then
    ctx.super_stack[#ctx.super_stack] = nil
  end

  return out
end

gen.ClassExpression = function(node, indent, ctx)
  local class_name = node.name or "_ljs_class"
  local has_super = node.superClass ~= nil
  local super_code = has_super and emit(node.superClass, indent, ctx) or nil

  if has_super then
    ctx.super_stack[#ctx.super_stack + 1] = super_code
  end

  local constructor_method = nil
  local methods = {}
  local statics = {}

  for _, m in ipairs(node.body) do
    if m.kind == "constructor" then
      constructor_method = m
    elseif m.static then
      statics[#statics + 1] = m
    else
      methods[#methods + 1] = m
    end
  end

  local extra_scope = node.name and { node.name } or nil

  local ctor_fn
  if constructor_method then
    ctor_fn = emit_fn(constructor_method.value, indent, ctx, extra_scope)
  elseif has_super then
    local params = { "_ljs_this", "..." }
    local body_code = cg.expr_stmt(cg.call(super_code, { "_ljs_arrow_this", "..." }), indent + 1)
    body_code = cg.local_decl("_ljs_arrow_this", "_ljs_this", indent + 1) .. body_code
    ctor_fn = cg.fn_expr(cg.join(params), body_code, indent)
  else
    ctor_fn = cg.fn_expr("_ljs_this", "", indent)
  end

  local iife_stmts = {}
  iife_stmts[#iife_stmts + 1] = cg.local_inline(class_name, cg.call("_ljs_ctor", { ctor_fn }))

  if has_super then
    iife_stmts[#iife_stmts + 1] = cg.binop(
      "=",
      cg.member_dot(class_name, "prototype"),
      cg.call("_ljs_object_create", { cg.nil_val(), cg.member_dot(super_code, "prototype") })
    )
    iife_stmts[#iife_stmts + 1] = cg.binop(
      "=",
      cg.member_dot(cg.member_dot(class_name, "prototype"), "constructor"),
      class_name
    )
  end

  for _, m in ipairs(methods) do
    local m_fn = emit_fn(m.value, indent, ctx, extra_scope)
    iife_stmts[#iife_stmts + 1] = cg.binop(
      "=",
      cg.member_index(cg.member_dot(class_name, "prototype"), method_key(m)),
      cg.call("_ljs_fn", { m_fn })
    )
  end

  for _, m in ipairs(statics) do
    local m_fn = emit_fn(m.value, indent, ctx, extra_scope)
    iife_stmts[#iife_stmts + 1] =
      cg.binop("=", cg.member_index(class_name, method_key(m)), cg.call("_ljs_fn", { m_fn }))
  end

  iife_stmts[#iife_stmts + 1] = cg.return_inline(class_name)

  if has_super then
    ctx.super_stack[#ctx.super_stack] = nil
  end

  return cg.iife(iife_stmts)
end

gen.FunctionExpression = function(node, indent, ctx)
  local fn = emit_fn(node, indent, ctx)
  if node.is_method then
    return cg.call("_ljs_fn", { fn })
  end
  return cg.call("_ljs_ctor", { fn })
end

gen.ArrowFunctionExpression = function(node, indent, ctx)
  local fn = emit_fn(node, indent, ctx)
  return cg.call("_ljs_fn", { fn })
end

-- === Control flow ===

gen.BlockStatement = function(node, indent, ctx)
  scope_push(ctx)
  local code = emit_body(node.body, indent + 1, ctx)
  scope_pop(ctx)
  return code
end

gen.IfStatement = function(node, indent, ctx)
  local test, body, elseifs, else_body = collect_if_chain(node, indent, ctx)
  return cg.if_stmt(test, body, elseifs, else_body, indent)
end

gen.WhileStatement = function(node, indent, ctx)
  local test_code = cg.call("_ljs_to_boolean", { emit(node.test, indent, ctx) })
  local body = emit(node.body, indent, ctx)
  if has_continue(node.body) then
    body = body .. cg.label("_continue", indent + 1)
  end
  return cg.while_stmt(test_code, body, indent)
end

-- JS do..while → Lua repeat..until. `until` takes an exit condition, so the
-- test is negated: JS `do {} while(cond)` → Lua `repeat until not cond`.
gen.DoWhileStatement = function(node, indent, ctx)
  local test_code = emit(node.test, indent, ctx)
  local body = emit(node.body, indent, ctx)
  if has_continue(node.body) then
    body = body .. cg.label("_continue", indent + 1)
  end
  local negated = cg.unop("not", cg.call("_ljs_to_boolean", { test_code }))
  return cg.repeat_until(negated, body, indent)
end

gen.ForOfStatement = function(node, indent, ctx)
  local var_name
  if node.left.type == ast.TYPE_VARIABLE_DECLARATION then
    var_name = node.left.declarations[1].name.name
  else
    var_name = node.left.name
  end
  scope_push(ctx)
  scope_declare(ctx, var_name)
  local body = emit(node.body, indent, ctx)
  if has_continue(node.body) then
    body = body .. cg.label("_continue", indent + 1)
  end
  scope_pop(ctx)
  local iter = cg.call("ipairs", { emit(node.right, indent, ctx) })
  return cg.for_in_stmt(cg.join({ "_", var_name }), iter, body, indent)
end

-- JS for..in → Lua pairs(). The dummy `_` catches the value since JS for..in
-- only yields keys. Note: does not walk prototype chain (Lua pairs() limitation).
gen.ForInStatement = function(node, indent, ctx)
  local var_name
  if node.left.type == ast.TYPE_VARIABLE_DECLARATION then
    var_name = node.left.declarations[1].name.name
  else
    var_name = node.left.name
  end
  scope_push(ctx)
  scope_declare(ctx, var_name)
  local body = emit(node.body, indent, ctx)
  if has_continue(node.body) then
    body = body .. cg.label("_continue", indent + 1)
  end
  scope_pop(ctx)
  local iter = cg.call("pairs", { emit(node.right, indent, ctx) })
  return cg.for_in_stmt(cg.join({ var_name, "_" }), iter, body, indent)
end

-- C-style for → init statement + while loop. The init is emitted as a separate
-- statement BEFORE the while so it runs once; the update runs at the END of
-- each loop iteration body (before the continue label, if present).
gen.ForStatement = function(node, indent, ctx)
  local parts = {}
  if node.init then
    parts[#parts + 1] = emit(node.init, indent, ctx)
  end
  local test_code = node.test and cg.call("_ljs_to_boolean", { emit(node.test, indent, ctx) })
    or "true"
  scope_push(ctx)
  if node.init and node.init.type == ast.TYPE_VARIABLE_DECLARATION then
    for _, decl in ipairs(node.init.declarations) do
      scope_declare(ctx, decl.name.name)
    end
  end
  local body = emit(node.body, indent, ctx)
  if has_continue(node.body) then
    body = body .. cg.label("_continue", indent + 1)
  end
  if node.update then
    local stmt_fn = gen_stmt[node.update.type]
    if stmt_fn then
      body = body .. stmt_fn(node.update, indent + 1, ctx)
    else
      body = body .. cg.expr_stmt(emit(node.update, indent + 1, ctx), indent + 1)
    end
  end
  scope_pop(ctx)
  parts[#parts + 1] = cg.while_stmt(test_code, body, indent)
  return table.concat(parts)
end

-- Switch lowering: chained if/elseif with fallthrough via `_ljs_matched` flag,
-- wrapped in `for _ = 1, 1 do ... end` so that `break` exits the switch
-- without breaking the enclosing loop. Each case sets `_ljs_matched = true`;
-- subsequent cases check `_ljs_matched or _ljs_sw == test` for fallthrough.
gen.SwitchStatement = function(node, indent, ctx)
  local disc = emit(node.discriminant, indent, ctx)
  local parts = {}
  parts[#parts + 1] = cg.local_decl("_ljs_sw", disc, indent)
  parts[#parts + 1] = cg.local_decl("_ljs_matched", "false", indent)
  local cases_body = {}
  for _, case in ipairs(node.cases) do
    local case_body = cg.expr_stmt("_ljs_matched = true", indent + 2)
    for _, stmt in ipairs(case.consequent) do
      case_body = case_body .. emit(stmt, indent + 2, ctx)
    end
    if case.test then
      local test_code = emit(case.test, indent, ctx)
      local test_expr = cg.binop("or", "_ljs_matched", cg.binop("==", "_ljs_sw", test_code))
      cases_body[#cases_body + 1] = cg.if_stmt(test_expr, case_body, nil, nil, indent + 1)
    else
      cases_body[#cases_body + 1] = cg.if_stmt("true", case_body, nil, nil, indent + 1)
    end
  end
  parts[#parts + 1] = cg.numeric_for("_", "1", "1", table.concat(cases_body), indent)
  return table.concat(parts)
end

gen.BreakStatement = function(node, indent, ctx)
  return cg.break_stmt(indent)
end

gen.ContinueStatement = function(node, indent, ctx)
  return cg.goto_stmt("_continue", indent)
end

-- === Exception handling ===

-- try/catch/finally lowering via pcall. Three patterns:
--   1) try+finally (no catch): pcall + finally + conditional rethrow
--   2) try+catch+finally: pcall into (ok, err) + catch if not ok + finally
--   3) try+catch (no finally): pcall into (ok, err) + catch if not ok
-- The pcall wraps the try body in an anonymous function to delimit its scope.
gen.TryStatement = function(node, indent, ctx)
  local try_body = emit(node.block, indent + 1, ctx)

  local param = node.handler and node.handler.param.name or nil
  local catch_body = nil
  if param then
    scope_push(ctx)
    scope_declare(ctx, param)
    catch_body = emit(node.handler.body, indent + 1, ctx)
    scope_pop(ctx)
  end

  local finalizer_body = nil
  if node.finalizer then
    finalizer_body = emit(node.finalizer, indent + 1, ctx)
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

gen.BinaryExpression = function(node, indent, ctx)
  local op = node.operator
  local left = emit(node.left, indent, ctx)
  local right = emit(node.right, indent, ctx)
  if op == "+" then
    return cg.call("_ljs_add", { left, right })
  elseif op == "==" then
    return cg.call("_ljs_eq", { left, right })
  elseif op == "!=" then
    return cg.unop("not", cg.call("_ljs_eq", { left, right }))
  elseif op == "===" then
    return cg.binop("==", left, right)
  elseif op == "!==" then
    return cg.binop("~=", left, right)
  elseif op == "&&" then
    return cg.iife({
      cg.local_inline("_ljs_v", left),
      cg.inline_if_return(cg.call("_ljs_to_boolean", { "_ljs_v" }), right, "_ljs_v"),
    })
  elseif op == "||" then
    return cg.iife({
      cg.local_inline("_ljs_v", left),
      cg.inline_if_return(cg.call("_ljs_to_boolean", { "_ljs_v" }), "_ljs_v", right),
    })
  elseif op == "=" then
    return cg.binop("=", left, right)
  elseif op == "+=" then
    return cg.binop("=", left, cg.call("_ljs_add", { left, right }))
  elseif op == "**" then
    return cg.call("_ljs_pow", { left, right })
  elseif op == "**=" then
    return cg.binop("=", left, cg.call("_ljs_pow", { left, right }))
  elseif op == "-" then
    return cg.call("_ljs_sub", { left, right })
  elseif op == "*" then
    return cg.call("_ljs_mul", { left, right })
  elseif op == "/" then
    return cg.call("_ljs_div", { left, right })
  elseif op == "-=" then
    return cg.binop("=", left, cg.call("_ljs_sub", { left, right }))
  elseif op == "*=" then
    return cg.binop("=", left, cg.call("_ljs_mul", { left, right }))
  elseif op == "/=" then
    return cg.binop("=", left, cg.call("_ljs_div", { left, right }))
  elseif op == "%=" then
    return cg.binop("=", left, cg.call("_ljs_mod", { cg.call("_ljs_to_number", { left }), cg.call("_ljs_to_number", { right }) }))
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
  -- The `in` operator: `key in obj` → `obj[key] ~= nil`.
  -- For non-string computed keys, adds 1 to convert JS 0-based to Lua 1-based index
  -- (so `"prop" in obj` with a numeric key works against Lua array indices).
  -- Wraps object literal RHS in parens to avoid ambiguous Lua syntax.
  elseif op == "in" then
    local key_code
    if node.left.type == ast.TYPE_STRING_LITERAL then
      key_code = left
    else
      key_code = cg.binop("+", cg.paren(left), "1")
    end
    local right_expr = right:sub(1, 1) == "{" and cg.paren(right) or right
    return cg.paren(cg.binop("~=", cg.member_index(right_expr, key_code), cg.nil_val()))
  elseif op == "%" then
    return cg.call("_ljs_mod", { cg.call("_ljs_to_number", { left }), cg.call("_ljs_to_number", { right }) })
  elseif op == "<" then
    return cg.call("_ljs_lt", { left, right })
  elseif op == ">" then
    return cg.call("_ljs_gt", { left, right })
  elseif op == "<=" then
    return cg.call("_ljs_le", { left, right })
  elseif op == ">=" then
    return cg.call("_ljs_ge", { left, right })
  else
    return cg.binop(op, left, right)
  end
end

gen.UnaryExpression = function(node, indent, ctx)
  if
    node.operator == "-"
    and node.argument.type == ast.TYPE_NUMBER_LITERAL
    and node.argument.value == 0
  then
    return cg.paren(cg.binop("/", cg.unop("-", "1"), "math.huge"))
  end
  local expr = emit(node.argument, indent, ctx)
  if node.operator == "!" then
    return cg.unop("not", cg.call("_ljs_to_boolean", { expr }))
  elseif node.operator == "~" then
    return cg.call("_ljs_bnot", { expr })
  elseif node.operator == "+" then
    return cg.call("_ljs_to_number", { expr })
  end
  return cg.unop("-", cg.call("_ljs_to_number", { expr }))
end

--- Compute the Lua key for a MemberExpression.
-- Computed string keys are used as-is. Computed non-string keys (numbers) get
-- +1 to convert JS 0-based indices to Lua 1-based. Non-computed keys become
-- Lua string keys via cg.string().
-- @param node (table) MemberExpression AST node
-- @param indent (number) Current indentation level
-- @param ctx (table) Transpilation context
-- @return (string) Lua expression for the key
local function member_key(node, indent, ctx)
  if node.computed then
    if node.property.type == ast.TYPE_STRING_LITERAL then
      return emit(node.property, indent, ctx)
    end
    return cg.binop("+", cg.paren(emit(node.property, indent, ctx)), "1")
  end
  return cg.string(node.property.name)
end

local function delete_key_and_obj(arg, indent, ctx)
  if arg.type ~= ast.TYPE_MEMBER_EXPRESSION then
    return nil, nil
  end
  local obj = emit(arg.object, indent, ctx)
  local key = member_key(arg, indent, ctx)
  return obj, key
end

gen.DeleteExpression = function(node, indent, ctx)
  local obj, key = delete_key_and_obj(node.argument, indent, ctx)
  if obj then
    return cg.paren(cg.binop("and", cg.call("rawset", { obj, key, cg.nil_val() }), "true"))
  end
  return "true"
end

gen.TypeofExpression = function(node, indent, ctx)
  return cg.call("_ljs_typeof", { emit(node.argument, indent, ctx) })
end

-- Expression-context ++/--: wrapped in IIFE to return the value.
-- Prefix returns the new value; postfix saves old value, increments, returns old.
gen.UpdateExpression = function(node, indent, ctx)
  local arg = emit(node.argument, indent, ctx)
  local val
  if node.operator == "++" then
    val = cg.binop("+", cg.call("_ljs_to_number", { arg }), "1")
  else
    val = cg.call("_ljs_sub", { arg, "1" })
  end
  if node.prefix then
    return cg.iife({ cg.binop("=", arg, val), cg.return_inline(arg) })
  end
  return cg.iife({ cg.local_inline("_t", cg.call("_ljs_to_number", { arg })), cg.binop("=", arg, val), cg.return_inline("_t") })
end

gen.ConditionalExpression = function(node, indent, ctx)
  local test_code = cg.call("_ljs_to_boolean", { emit(node.test, indent, ctx) })
  local cons_code = emit(node.consequent, indent, ctx)
  local alt_code = emit(node.alternate, indent, ctx)
  return cg.iife({ cg.inline_if_return(test_code, cons_code, alt_code) })
end

-- Call emission: four dispatch paths checked in order:
--   1) super() → direct parent constructor call with current instance
--   2) super.method() → _ljs_super_call with parent prototype
--   3) obj.method() → _ljs_call_member (passes obj as _ljs_this)
--   4) fn() → _ljs_call (passes nil as _ljs_this)
gen.CallExpression = function(node, indent, ctx)
  local args = {}
  for _, a in ipairs(node.arguments) do
    args[#args + 1] = emit(a, indent, ctx)
  end

  if node.callee.type == ast.TYPE_SUPER_EXPRESSION then
    local super_parent = ctx.super_stack[#ctx.super_stack]
    local call_args = { "_ljs_arrow_this" }
    for _, a in ipairs(args) do
      call_args[#call_args + 1] = a
    end
    return cg.call(super_parent, call_args)
  end

  if node.callee.type == ast.TYPE_MEMBER_EXPRESSION and node.callee.object.type == ast.TYPE_SUPER_EXPRESSION then
    local super_parent = ctx.super_stack[#ctx.super_stack]
    local proto = cg.member_dot(super_parent, "prototype")
    local key_expr = member_key(node.callee, indent, ctx)
    local call_args = { proto, key_expr, "_ljs_arrow_this" }
    for _, a in ipairs(args) do
      call_args[#call_args + 1] = a
    end
    return cg.call("_ljs_super_call", call_args)
  end

  if node.callee.type == ast.TYPE_MEMBER_EXPRESSION then
    local obj_expr = emit(node.callee.object, indent, ctx)
    local key_expr = member_key(node.callee, indent, ctx)
    local call_args = { obj_expr, key_expr }
    for _, a in ipairs(args) do
      call_args[#call_args + 1] = a
    end
    return cg.call("_ljs_call_member", call_args)
  end

  local call_args = { emit(node.callee, indent, ctx) }
  for _, a in ipairs(args) do
    call_args[#call_args + 1] = a
  end
  return cg.call("_ljs_call", call_args)
end

gen.NewExpression = function(node, indent, ctx)
  local args = { emit(node.callee, indent, ctx) }
  for _, a in ipairs(node.arguments) do
    args[#args + 1] = emit(a, indent, ctx)
  end
  return cg.call("_ljs_new", args)
end

gen.MemberExpression = function(node, indent, ctx)
  local obj
  if node.object.type == ast.TYPE_SUPER_EXPRESSION then
    local super_parent = ctx.super_stack[#ctx.super_stack]
    obj = cg.member_dot(super_parent, "prototype")
  else
    obj = emit(node.object, indent, ctx)
  end
  obj = cg.call("_ljs_to_object", { obj })
  if node.computed then
    return cg.member_index(obj, member_key(node, indent, ctx))
  end
  return cg.member_dot(obj, node.property.name)
end

-- === Objects and arrays ===

gen.ObjectExpression = function(node, indent, ctx)
  local fields = {}
  for _, prop in ipairs(node.properties) do
    local key
    if prop.key.type == ast.TYPE_IDENTIFIER then
      key = prop.key.name
    else
      key = cg.bracket_key(cg.string(prop.key.value))
    end
    fields[#fields + 1] = { key = key, value = emit(prop.value, indent, ctx) }
  end
  return cg.call("_ljs_object", { cg.object(fields) })
end

gen.ArrayExpression = function(node, indent, ctx)
  local args = { "Array" }
  for _, e in ipairs(node.elements) do
    args[#args + 1] = emit(e, indent, ctx)
  end
  return cg.call("_ljs_new", args)
end

-- === Statement-context emission ===
-- gen_stmt handlers produce cheaper code than the expression-context gen handlers.
-- Used when an expression appears as the sole child of an ExpressionStatement,
-- avoiding IIFE wrapping where a direct statement will do.

-- Statement-context ++/--: direct assignment, no IIFE needed.
gen_stmt.UpdateExpression = function(node, indent, ctx)
  local arg = emit(node.argument, indent, ctx)
  if node.operator == "++" then
    return cg.expr_stmt(cg.binop("=", arg, cg.binop("+", cg.call("_ljs_to_number", { arg }), "1")), indent)
  end
  return cg.expr_stmt(cg.binop("=", arg, cg.call("_ljs_sub", { arg, "1" })), indent)
end

gen_stmt.ConditionalExpression = function(node, indent, ctx)
  return cg.expr_stmt(emit(node, indent, ctx), indent)
end

-- Statement-context delete: just rawset, no need for the `and true` wrapper.
gen_stmt.DeleteExpression = function(node, indent, ctx)
  local obj, key = delete_key_and_obj(node.argument, indent, ctx)
  if obj then
    return cg.expr_stmt(cg.call("rawset", { obj, key, cg.nil_val() }), indent)
  end
  return ""
end

-- typeof as a statement has no side effects; emit nothing.
gen_stmt.TypeofExpression = function(node, indent, ctx)
  return ""
end

-- === Top-level preamble and emit ===

-- Emission order: _ljs_to_int32 first (other helpers depend on it),
-- _ljs_to_number/_ljs_to_boolean before arithmetic and coercion helpers,
-- _ljs_fn before _ljs_ctor (which depends on it), _ljs_to_object before
-- _ljs_call_member (which calls it), _ljs_tostring, rest alphabetical.
-- All 27 helpers are always emitted unconditionally.
local HELPER_ORDER = {
  "_ljs_to_int32",
  "_ljs_to_primitive",
  "_ljs_to_number",
  "_ljs_to_boolean",
  "_ljs_fn",
  "_ljs_to_object",
  "_ljs_tostring",
  "_ljs_add",
  "_ljs_sub",
  "_ljs_mul",
  "_ljs_div",
  "_ljs_pow",
  "_ljs_bnot",
  "_ljs_band",
  "_ljs_bor",
  "_ljs_bxor",
  "_ljs_shl",
  "_ljs_shr",
  "_ljs_usr",
  "_ljs_mod",
  "_ljs_typeof",
  "_ljs_call",
  "_ljs_call_member",
  "_ljs_object",
  "_ljs_object_create",
  "_ljs_ctor",
  "_ljs_new",
  "_ljs_instanceof",
  "_ljs_str_to_num",
  "_ljs_super_call",
  "_ljs_eq",
  "_ljs_lt",
  "_ljs_gt",
  "_ljs_le",
  "_ljs_ge",
}

local _preamble_cache = nil

--- Build the runtime preamble (helpers + stdlib). Result is cached after first call.
-- Structure: proto declarations → _ljs_arrow_this → 24 helpers → runtime stdlib files.
-- Idempotent; safe to call for multi-file output (emit preamble once, then per-file emit).
-- @return (string) Complete Lua preamble source
function M.preamble()
  if _preamble_cache then
    return _preamble_cache
  end
  local helper_parts = {}
  for _, name in ipairs(HELPER_ORDER) do
    helper_parts[#helper_parts + 1] = HELPERS[name]
  end
  local helpers_str = table.concat(helper_parts, "\n\n")
  _preamble_cache = read_runtime("proto")
    .. "local _ljs_arrow_this = nil\n"
    .. "local _ljs_null = {}\n\n"
    .. helpers_str
    .. "\n\n"
    .. read_runtime("object")
    .. read_runtime("function")
    .. read_runtime("number")
    .. read_runtime("string")
    .. read_runtime("boolean")
    .. read_runtime("array")
    .. read_runtime("error")
    .. read_runtime("object_tostring")
    .. read_runtime("console")
    .. read_runtime("json_lib")
    .. read_runtime("json")
    .. read_runtime("math")
    .. read_runtime("globals")
  return _preamble_cache
end

--- Emit Lua source for an AST (user code only, no preamble).
-- @param ast (table) AST from parser.parse()
-- @param opts (table|nil) Options table; opts.mode = "script" (default) or "eval"
-- @return (string) Lua source code (user code only)
function M.emit(ast, opts)
  opts = opts or {}
  local ctx = {
    eval_mode = (opts.mode == "eval"),
    super_stack = {},
    scopes = {},
  }
  return emit(ast, 0, ctx)
end

-- ============================================================================
-- Section 5: Public API
-- ============================================================================

--- Transpile a parsed JS AST into Lua source code.
-- @param ast (table) AST from parser.parse()
-- @param opts (table|nil) Options table; opts.mode = "script" (default) or "eval"
-- @return (string) Lua source code
function M.transpile(ast, opts)
  return M.preamble() .. M.emit(ast, opts)
end

--- Parse JS source and transpile to Lua in one step.
-- @param source (string) JavaScript source code
-- @param opts (table|nil) Options table; opts.mode = "script" (default) or "eval"
-- @return (string|nil) Lua source code, or nil on error
-- @return (table|nil) ParseError {message, line, col}, or nil on success
function M.transpile_source(source, opts)
  local parser = require("ljs.parser")
  local ast, err = parser.parse(source)
  if not ast then
    return nil, err
  end
  return M.transpile(ast, opts)
end

M.HELPERS = HELPERS

-- ============================================================================
-- Section 6: Module return
-- ============================================================================

return M
