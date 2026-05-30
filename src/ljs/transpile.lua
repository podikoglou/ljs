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
-- prototype chains, and constructor mechanics. All 46 are always emitted
-- regardless of whether the source code uses them — no tree-shaking pass.
-- See docs/ARCHITECTURE.md § "Runtime call ABI" and "Constructors".
-- ============================================================================

local HELPERS = {}

HELPERS._ljs_is_undef = [[local function _ljs_is_undef(x)
  return x == nil or x == _ljs_undefined
end]]

HELPERS._ljs_is_nilish = [[local function _ljs_is_nilish(x)
  return x == nil or x == _ljs_null or x == _ljs_undefined
end]]

HELPERS._ljs_to_int32 = [[local function _ljs_to_int32(x)
  x = _ljs_to_number(x)
  if x ~= x then return 0 end
  x = math.floor(x) % 0x100000000
  if x >= 0x80000000 then x = x - 0x100000000 end
  return x
end]]

HELPERS._ljs_to_number = [[local function _ljs_to_number(x)
  if x == _ljs_null then
    return 0
  end
  if _ljs_is_undef(x) then
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

HELPERS._ljs_neg = [[local function _ljs_neg(x)
  x = _ljs_to_number(x)
  if x == 0 then
    if 1/x == math.huge then return -0.0 end
    return 0.0
  end
  return -x
end]]

HELPERS._ljs_to_float = [[local function _ljs_to_float(x)
  if math.type(x) == "integer" then return x * 1.0 end
  return x
end]]

HELPERS._ljs_to_boolean = [[local function _ljs_to_boolean(x)
  if _ljs_is_nilish(x) then
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
  elseif _ljs_is_undef(x) then return "undefined"
  elseif type(x) == "number" then
    if x ~= x then return "NaN" end
    if x == math.huge then return "Infinity" end
    if x == -math.huge then return "-Infinity" end
    if x == 0 then return "0" end
    if math.floor(x) == x then return tostring(math.floor(x)) end
    return tostring(x)
  elseif type(x) == "table" then
    return _ljs_tostring(_ljs_to_primitive(x))
  else return tostring(x) end
end]]

HELPERS._ljs_add = [[local function _ljs_add(a, b)
  if type(a) == "table" and a ~= _ljs_null and not _ljs_is_undef(a) then
    a = _ljs_to_primitive(a)
  end
  if type(b) == "table" and b ~= _ljs_null and not _ljs_is_undef(b) then
    b = _ljs_to_primitive(b)
  end
  if type(a) == "string" or type(b) == "string" then
    return _ljs_tostring(a) .. _ljs_tostring(b)
  end
  return _ljs_to_float(_ljs_to_number(a)) + _ljs_to_float(_ljs_to_number(b))
end]]

HELPERS._ljs_sub = [[local function _ljs_sub(a, b)
  return _ljs_to_float(_ljs_to_number(a)) - _ljs_to_float(_ljs_to_number(b))
end]]

HELPERS._ljs_mul = [[local function _ljs_mul(a, b)
  return _ljs_to_float(_ljs_to_number(a)) * _ljs_to_float(_ljs_to_number(b))
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
  a = math.floor(_ljs_to_number(a)) % 0x100000000
  b = math.floor(_ljs_to_number(b)) % 0x100000000
  local r, m = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return _ljs_to_int32(r)
end]]

HELPERS._ljs_bor = [[local function _ljs_bor(a, b)
  a = math.floor(_ljs_to_number(a)) % 0x100000000
  b = math.floor(_ljs_to_number(b)) % 0x100000000
  local r, m = 0, 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return _ljs_to_int32(r)
end]]

HELPERS._ljs_bxor = [[local function _ljs_bxor(a, b)
  local an = _ljs_to_number(a)
  if an ~= an then an = 0 else an = math.floor(an) % 0x100000000 end
  a = an
  local bn = _ljs_to_number(b)
  if bn ~= bn then bn = 0 else bn = math.floor(bn) % 0x100000000 end
  b = bn
  local r, m = 0, 1
  while a > 0 or b > 0 do
    if a % 2 ~= b % 2 then r = r + m end
    a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
  end
  return _ljs_to_int32(r)
end]]

HELPERS._ljs_shl = [[local function _ljs_shl(a, b)
  a = _ljs_to_int32(a)
  local bn = _ljs_to_number(b)
  if bn ~= bn then return a end
  b = math.floor(bn) % 32
  if b == 0 then return a end
  return _ljs_to_int32(a * 2^b)
end]]

HELPERS._ljs_shr = [[local function _ljs_shr(a, b)
  a = _ljs_to_int32(a)
  local bn = _ljs_to_number(b)
  if bn ~= bn then return a end
  b = math.floor(bn) % 32
  if b == 0 then return a end
  return math.floor(a / 2^b)
end]]

HELPERS._ljs_usr = [[local function _ljs_usr(a, b)
  local an = _ljs_to_number(a)
  if an ~= an then an = 0 else an = math.floor(an) % 0x100000000 end
  a = an
  local bn = _ljs_to_number(b)
  if bn ~= bn then b = 0 else b = math.floor(bn) % 32 end
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

HELPERS._ljs_index = [[local function _ljs_index(k)
  if type(k) == "string" then
    local n = tonumber(k)
    if n and math.floor(n) == n and n >= 0 and tostring(n) == k then
      return n + 1
    end
    return k
  end
  return k + 1
end]]

-- typeof per §13.5.3: nil (undefined) → "undefined", _ljs_null → "object".
HELPERS._ljs_typeof = [[local function _ljs_typeof(x)
  if _ljs_is_undef(x) then return "undefined"
  elseif x == _ljs_null then return "object"
  elseif type(x) == "table" then
    local mt = getmetatable(x)
    if mt and mt.__call then return "function" end
    return "object"
  else return type(x) end
end]]

-- Check if a value can be called as a function (has [[Call]] internal method).
-- Returns true if value is a function or table with _ljs_raw.
HELPERS._ljs_is_function = [[local function _ljs_is_function(x)
  if type(x) == "function" then return true end
  if type(x) == "table" then
    local raw = rawget(x, "_ljs_raw")
    if raw then return true end
  end
  return false
end]]

-- Check if a value can be used as a constructor (has [[Construct]] internal method).
-- In our implementation, constructors are wrapped by _ljs_ctor and have .prototype.
HELPERS._ljs_is_constructor = [[local function _ljs_is_constructor(x)
  if type(x) == "table" then
    local raw = rawget(x, "_ljs_raw")
    if raw and x.prototype then return true end
  end
  return false
end]]

-- Get a string representation of a value for error messages (similar to Node.js).
-- Returns a representation suitable for use in "X is not a function" style errors.
HELPERS._ljs_value_repr = [[local function _ljs_value_repr(x)
  if _ljs_is_undef(x) then return "undefined"
  elseif x == _ljs_null then return "null"
  elseif type(x) == "number" then
    if x ~= x then return "NaN" end
    if x == math.huge then return "Infinity" end
    if x == -math.huge then return "-Infinity" end
    return tostring(x)
  elseif type(x) == "string" then
    return string.format("%q", x)
  elseif type(x) == "boolean" then
    return tostring(x)
  elseif type(x) == "table" then
    local raw = rawget(x, "_ljs_raw")
    if raw then return "[Function]" end
    return "{(intermediate value)}"
  else
    return tostring(x)
  end
end]]

-- Direct call: f(a,b) → _ljs_call(f,a,b). Passes nil as _ljs_this (no receiver).
-- Throws TypeError if fn is not callable.
HELPERS._ljs_type_error = [[local function _ljs_type_error(msg)
  error(setmetatable({ message = msg }, { __index = TypeError.prototype }), 0)
end]]

HELPERS._ljs_range_error = [[local function _ljs_range_error(msg)
  error(setmetatable({ message = msg }, { __index = RangeError.prototype }), 0)
end]]

HELPERS._ljs_for_in_keys = [[local function _ljs_for_in_keys(obj)
  local keys = {}
  if type(obj) ~= "table" then
    return keys
  end
  if _ljs_instanceof(obj, Array) then
    local len = obj.length or 0
    for i = 1, len do
      if rawget(obj, i) ~= nil then
        keys[#keys + 1] = tostring(i - 1)
      end
    end
  else
    for k in pairs(obj) do
      if type(k) == "string" then
        keys[#keys + 1] = k
      end
    end
  end
  return keys
end]]

HELPERS._ljs_call = [[local function _ljs_call(fn, ...)
  if not _ljs_is_function(fn) then
    _ljs_type_error(_ljs_value_repr(fn) .. " is not a function")
  end
  if type(fn) == "table" then
    local raw = rawget(fn, "_ljs_raw")
    if raw then return raw(nil, ...) end
  end
  return fn(nil, ...)
end]]

-- ES2026 §7.1.19 ToObject: boxes primitives into wrapper objects for property access.
HELPERS._ljs_to_object = [[local function _ljs_to_object(obj)
  local t = type(obj)
  if t == "number" then
    return setmetatable({ _ljs_data = obj }, { __index = _ljs_number_prototype })
  end
  if t == "string" then
    return setmetatable({ _ljs_data = obj }, { __index = _ljs_string_box_index or _ljs_string_prototype })
  end
  if t == "boolean" then
    return setmetatable({ _ljs_data = obj }, { __index = _ljs_boolean_prototype })
  end
  return obj
end]]

-- Method call: obj.m(a,b) → _ljs_call_member(obj,"m",a,b). Passes obj as _ljs_this.
-- Throws TypeError on null/undefined per RequireObjectCoercible (§7.2.1).
-- Boxes primitives via _ljs_to_object before property lookup.
-- Throws TypeError if method is not callable.
HELPERS._ljs_call_member = [[local function _ljs_call_member(obj, key, ...)
  if _ljs_is_nilish(obj) then
    local desc = _ljs_is_undef(obj) and "undefined" or "null"
    _ljs_type_error("Cannot read properties of " .. desc .. " (reading '" .. tostring(key) .. "')")
  end
  local boxed = _ljs_to_object(obj)
  local method = boxed[key]
  if not _ljs_is_function(method) then
    _ljs_type_error(_ljs_value_repr(method) .. " is not a function")
  end
  if type(method) == "table" then
    local raw = rawget(method, "_ljs_raw")
    if raw then return raw(boxed, ...) end
  end
  return method(boxed, ...)
end]]

-- Wraps a table with Object.prototype as __index. Used for all object literals.
HELPERS._ljs_object = [[local function _ljs_object(t)
  return setmetatable(t, { __index = _ljs_object_prototype })
end]]

HELPERS._ljs_object_create = [[local function _ljs_object_create(_ljs_this, proto)
  if proto == nil or proto == _ljs_null then
    return setmetatable({}, { __index = function(t, k) return _ljs_undefined end })
  end
  return setmetatable({}, {__index = proto})
end]]

-- Wraps a plain Lua function as a callable table with Function.prototype chain.
-- Used for arrow functions and method shorthand — no .prototype property.
HELPERS._ljs_fn = [[local function _ljs_fn(fn, name)
  local t = setmetatable({}, {
    __call = function(_, ...)
      return fn(nil, ...)
    end,
    __index = _ljs_function_prototype,
  })
  rawset(t, "_ljs_raw", fn)
  rawset(t, "name", name or "")
  return t
end]]

-- Wraps a function as a constructor: callable table + .prototype inheriting
-- from _ljs_object_prototype. Used for FunctionDeclaration, FunctionExpression,
-- and class constructors.
HELPERS._ljs_ctor = [[local function _ljs_ctor(fn, name)
  local ctor = _ljs_fn(fn, name)
  ctor.prototype = setmetatable({ constructor = ctor }, { __index = _ljs_object_prototype })
  return ctor
end]]

-- new Foo(args) → creates instance with Foo.prototype chain, calls ctor.
-- If ctor returns a table, that table is returned instead of the instance
-- (matching JS constructor return semantics).
-- Throws TypeError if ctor is not a constructor.
HELPERS._ljs_new = [[local function _ljs_new(ctor, ...)
  if not _ljs_is_constructor(ctor) then
    _ljs_type_error(_ljs_value_repr(ctor) .. " is not a constructor")
  end
  local proto = ctor.prototype
  local instance = setmetatable({}, {__index = proto})
  local raw = rawget(ctor, "_ljs_raw")
  local result
  if raw then
    result = raw(instance, ...)
  else
    result = ctor(instance, ...)
  end
  if type(result) == "table" and not _ljs_is_undef(result) and result ~= _ljs_null then
    return result
  end
  return instance
end]]

HELPERS._ljs_arr_lit = [[local function _ljs_arr_lit(...)
  local _t = _ljs_new(Array)
  local _n = select("#", ...)
  for _i = 1, _n do
    rawset(_t, _i, select(_i, ...))
  end
  rawset(_t, "length", _n)
  return _t
end]]

HELPERS._ljs_call_this = [[local function _ljs_call_this(fn, this_val, ...)
  if not _ljs_is_function(fn) then
    _ljs_type_error(_ljs_value_repr(fn) .. " is not a function")
  end
  if type(fn) == "table" then
    local raw = rawget(fn, "_ljs_raw")
    if raw then return raw(this_val, ...) end
  end
  return fn(this_val, ...)
end]]

HELPERS._ljs_spread_build = [[local function _ljs_spread_build(...)
  local result = {}
  result.n = 0
  local nargs = select('#', ...)
  local i = 1
  while i <= nargs do
    local val = select(i, ...)
    local is_spread = select(i + 1, ...)
    if is_spread then
      local vt = type(val)
      if vt == "string" then
        for j = 1, #val do
          result.n = result.n + 1
          result[result.n] = val:sub(j, j)
        end
      else
        for j = 1, val.length do
          result.n = result.n + 1
          result[result.n] = val[j]
        end
      end
    else
      result.n = result.n + 1
      result[result.n] = val
    end
    i = i + 2
  end
  return result
end]]

HELPERS._ljs_unpack = [[local function _ljs_unpack(arr)
  return table.unpack(arr, 1, arr.n)
end]]

HELPERS._ljs_rest = [[local function _ljs_rest(obj, excluded)
  local result = {}
  for k, v in pairs(obj) do
    local skip = false
    for _, e in ipairs(excluded) do
      if k == e then skip = true; break end
    end
    if not skip then result[k] = v end
  end
  return setmetatable(result, { __index = _ljs_object_prototype })
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
  local method = proto[key]
  if type(method) == "table" then
    local raw = rawget(method, "_ljs_raw")
    if raw then return raw(this_val, ...) end
  end
  return method(this_val, ...)
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
  local function _ljs_invoke(fn, this_val)
    if type(fn) == "table" then
      local raw = rawget(fn, "_ljs_raw")
      if raw then return raw(this_val) end
    end
    return fn(this_val)
  end
  local val_of = obj.valueOf
  if _callable(val_of) then
    local result = _ljs_invoke(val_of, obj)
    if type(result) ~= "table" then return result end
  end
  local to_str = obj.toString
  if _callable(to_str) then
    local result = _ljs_invoke(to_str, obj)
    if type(result) ~= "table" then return result end
  end
  _ljs_type_error("Cannot convert object to primitive value")
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
  local a_is_undef = _ljs_is_undef(a)
  local b_is_undef = _ljs_is_undef(b)
  local ta = a_is_null and "null" or a_is_undef and "undefined" or type(a)
  local tb = b_is_null and "null" or b_is_undef and "undefined" or type(b)
  if ta == tb then
    if ta == "number" then
      if a ~= a or b ~= b then return false end
      return a == b
    end
    if ta == "undefined" then return true end
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

HELPERS._ljs_strict_eq = [[local function _ljs_strict_eq(a, b)
  if a == b then return true end
  return (a == nil and b == _ljs_undefined) or (a == _ljs_undefined and b == nil)
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

HELPERS._ljs_has_property = [[local function _ljs_has_property(obj, key)
  local current = obj
  while current ~= nil do
    if rawget(current, key) ~= nil then
      return true
    end
    local mt = getmetatable(current)
    if mt == nil then break end
    local idx = mt.__index
    if type(idx) ~= "table" then break end
    current = idx
  end
  return false
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

--- Check whether an AST subtree contains break, continue, or return
-- that would cross a pcall function boundary.
-- Stops at loop boundaries (for break/continue) and function boundaries.
-- @param node (table|nil) AST node
-- @param in_switch (boolean|nil) true when inside a SwitchStatement (break exits switch, not loop)
-- @return (table|nil) { break, continue, return } flags, or nil if none
local function detect_control_flow(node, in_switch)
  if not node or type(node) ~= "table" then
    return nil
  end
  local t = node.type
  if t == ast.TYPE_BREAK_STATEMENT then
    if in_switch then
      return nil
    end
    return { break_ = true }
  end
  if t == ast.TYPE_CONTINUE_STATEMENT then
    return { continue_ = true }
  end
  if t == ast.TYPE_RETURN_STATEMENT then
    return { return_ = true }
  end
  if
    t == ast.TYPE_WHILE_STATEMENT
    or t == ast.TYPE_FOR_OF_STATEMENT
    or t == ast.TYPE_FOR_IN_STATEMENT
    or t == ast.TYPE_FOR_STATEMENT
    or t == ast.TYPE_DO_WHILE_STATEMENT
  then
    return nil
  end
  if
    t == ast.TYPE_FUNCTION_DECLARATION
    or t == ast.TYPE_FUNCTION_EXPRESSION
    or t == ast.TYPE_ARROW_FUNCTION_EXPRESSION
  then
    return nil
  end
  local child_in_switch = in_switch or t == ast.TYPE_SWITCH_STATEMENT
  local result = nil
  for _, v in pairs(node) do
    if type(v) == "table" then
      local inner = detect_control_flow(v, child_in_switch)
      if inner then
        if not result then
          result = {}
        end
        if inner.break_ then
          result.break_ = true
        end
        if inner.continue_ then
          result.continue_ = true
        end
        if inner.return_ then
          result.return_ = true
        end
      end
    end
  end
  return result
end

local DUMMY_TOKEN = { line = 0, col = 0 }

--- Deep-clone an AST subtree, replacing break/continue/return with throw-sentinel.
-- Stops at loop boundaries (for break/continue) and function boundaries.
-- @param node (table|nil) AST node
-- @param in_switch (boolean|nil) true when inside a SwitchStatement (break exits switch, not loop)
-- @return (table|nil) transformed node
local function transform_control_flow(node, in_switch)
  if not node or type(node) ~= "table" then
    return node
  end
  local t = node.type
  if t == ast.TYPE_BREAK_STATEMENT then
    if in_switch then
      return node
    end
    return ast.throw_statement(
      ast.object_expression({
        ast.property(
          ast.identifier("_ljs_cf", DUMMY_TOKEN),
          ast.string_literal("break", DUMMY_TOKEN),
          false,
          DUMMY_TOKEN
        ),
      }, DUMMY_TOKEN),
      DUMMY_TOKEN
    )
  end
  if t == ast.TYPE_CONTINUE_STATEMENT then
    return ast.throw_statement(
      ast.object_expression({
        ast.property(
          ast.identifier("_ljs_cf", DUMMY_TOKEN),
          ast.string_literal("continue", DUMMY_TOKEN),
          false,
          DUMMY_TOKEN
        ),
      }, DUMMY_TOKEN),
      DUMMY_TOKEN
    )
  end
  if t == ast.TYPE_RETURN_STATEMENT then
    local props = {
      ast.property(
        ast.identifier("_ljs_cf", DUMMY_TOKEN),
        ast.string_literal("return", DUMMY_TOKEN),
        false,
        DUMMY_TOKEN
      ),
    }
    if node.argument then
      props[#props + 1] =
        ast.property(ast.identifier("_ljs_v", DUMMY_TOKEN), node.argument, false, DUMMY_TOKEN)
    end
    return ast.throw_statement(ast.object_expression(props, DUMMY_TOKEN), DUMMY_TOKEN)
  end
  if
    t == ast.TYPE_WHILE_STATEMENT
    or t == ast.TYPE_FOR_OF_STATEMENT
    or t == ast.TYPE_FOR_IN_STATEMENT
    or t == ast.TYPE_FOR_STATEMENT
    or t == ast.TYPE_DO_WHILE_STATEMENT
  then
    return node
  end
  if
    t == ast.TYPE_FUNCTION_DECLARATION
    or t == ast.TYPE_FUNCTION_EXPRESSION
    or t == ast.TYPE_ARROW_FUNCTION_EXPRESSION
  then
    return node
  end
  if t == ast.TYPE_TRY_STATEMENT then
    return node
  end
  local child_in_switch = in_switch or t == ast.TYPE_SWITCH_STATEMENT
  local copy = {}
  for k, v in pairs(node) do
    if type(v) == "table" then
      copy[k] = transform_control_flow(v, child_in_switch)
    else
      copy[k] = v
    end
  end
  return copy
end

--- Generate post-pcall sentinel check code.
-- Checks if pcall error is a control-flow sentinel and re-emits it.
-- @param indent (number) indentation level
-- @return (string) Lua code for sentinel handling
local function sentinel_handler(indent, err_var, cf, rethrow)
  err_var = err_var or "err"
  local pad = cg.pad(indent)
  local lines = {
    pad .. "if type(" .. err_var .. ') == "table" and ' .. err_var .. "._ljs_cf then",
  }
  if cf.break_ then
    if rethrow then
      lines[#lines + 1] = pad
        .. "  if "
        .. err_var
        .. '._ljs_cf == "break" then error('
        .. err_var
        .. ") end"
    else
      lines[#lines + 1] = pad .. "  if " .. err_var .. '._ljs_cf == "break" then break end'
    end
  end
  if cf.continue_ then
    if rethrow then
      lines[#lines + 1] = pad
        .. "  if "
        .. err_var
        .. '._ljs_cf == "continue" then error('
        .. err_var
        .. ") end"
    else
      lines[#lines + 1] = pad
        .. "  if "
        .. err_var
        .. '._ljs_cf == "continue" then goto _continue end'
    end
  end
  if cf.return_ then
    if rethrow then
      lines[#lines + 1] = pad
        .. "  if "
        .. err_var
        .. '._ljs_cf == "return" then error('
        .. err_var
        .. ") end"
    else
      lines[#lines + 1] = pad
        .. "  if "
        .. err_var
        .. '._ljs_cf == "return" then return '
        .. err_var
        .. "._ljs_v end"
    end
  end
  lines[#lines + 1] = pad .. "end\n"
  return table.concat(lines, "\n") .. "\n"
end
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

local function scope_declare(ctx, name, kind)
  local scope = ctx.scopes[#ctx.scopes]
  local existing = scope[name]
  if existing then
    if not (existing == "var" and kind == "var") then
      error("SyntaxError: Identifier '" .. name .. "' has already been declared", 0)
    end
  end
  scope[name] = kind or "let"
end

local function scope_lookup(ctx, name)
  for i = #ctx.scopes, 1, -1 do
    local k = ctx.scopes[i][name]
    if k then
      return k
    end
  end
  return nil
end

local function check_assign(ctx, name)
  if scope_lookup(ctx, name) == "const" then
    error("TypeError: Assignment to constant variable '" .. name .. "'", 0)
  end
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
local function collect_var_names(node, names)
  if node.type == ast.TYPE_VARIABLE_DECLARATION then
    for _, decl in ipairs(node.declarations) do
      local nt = decl.name.type
      if nt == ast.TYPE_IDENTIFIER then
        names[#names + 1] = decl.name.name
      end
    end
  end
end

local function emit_body(stmts, indent, ctx)
  local func_decls = {}
  for _, s in ipairs(stmts) do
    if s.type == ast.TYPE_FUNCTION_DECLARATION then
      func_decls[#func_decls + 1] = s
    end
  end
  if #func_decls == 0 then
    local parts = {}
    for _, s in ipairs(stmts) do
      local code = emit(s, indent, ctx)
      if #parts > 0 and #code > 0 then
        local prev = parts[#parts]
        if prev:sub(-1) == "\n" then
          prev = prev:sub(1, -2)
        end
        local prev_last = prev:match("(%S)$")
        if prev_last and (prev_last:match("[%w%)%]']") or prev_last == '"') then
          local first_sig = code:match("^%s*(%S)")
          if first_sig == "(" then
            code = cg.pad(indent) .. ";\n" .. code
          end
        end
      end
      parts[#parts + 1] = code
    end
    return table.concat(parts)
  end
  local func_names = {}
  for _, s in ipairs(func_decls) do
    func_names[s.name] = true
  end
  local var_names = {}
  for _, s in ipairs(stmts) do
    if s.type ~= ast.TYPE_FUNCTION_DECLARATION then
      collect_var_names(s, var_names)
    end
  end
  local parts = {}
  local all_fwd = {}
  for name, _ in pairs(func_names) do
    all_fwd[#all_fwd + 1] = name
  end
  for _, name in ipairs(var_names) do
    if not func_names[name] then
      all_fwd[#all_fwd + 1] = name
    end
  end
  if #all_fwd > 0 then
    table.sort(all_fwd)
    parts[#parts + 1] = cg.local_decl(table.concat(all_fwd, ", "), nil, indent)
    local scope = ctx.scopes[#ctx.scopes]
    for _, name in ipairs(all_fwd) do
      scope[name] = "__fwd"
    end
  end
  for _, s in ipairs(func_decls) do
    local code = emit(s, indent, ctx)
    parts[#parts + 1] = code
  end
  for _, s in ipairs(stmts) do
    if s.type ~= ast.TYPE_FUNCTION_DECLARATION then
      local code = emit(s, indent, ctx)
      if #parts > 0 and #code > 0 then
        local prev = parts[#parts]
        if prev:sub(-1) == "\n" then
          prev = prev:sub(1, -2)
        end
        local prev_last = prev:match("(%S)$")
        if prev_last and (prev_last:match("[%w%)%]']") or prev_last == '"') then
          local first_sig = code:match("^%s*(%S)")
          if first_sig == "(" then
            code = cg.pad(indent) .. ";\n" .. code
          end
        end
      end
      parts[#parts + 1] = code
    end
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
local fresh_tmp
local emit_destructure
local emit_block_body
local emit_controlled_body

local function param_name(p)
  if p.type == ast.TYPE_IDENTIFIER then
    return p.name
  elseif p.type == ast.TYPE_ASSIGNMENT_PATTERN then
    return p.left.name
  elseif p.type == ast.TYPE_REST_ELEMENT then
    return p.argument.name
  end
  return nil
end

local function is_pattern(p)
  return p.type == ast.TYPE_ARRAY_PATTERN or p.type == ast.TYPE_OBJECT_PATTERN
end

local function emit_fn(fn_node, indent, ctx, extra_scope_names)
  local params = { "_ljs_this" }
  local has_rest = false
  local destructuring_params = {}
  for i, p in ipairs(fn_node.params) do
    if p.type == ast.TYPE_REST_ELEMENT then
      has_rest = true
    elseif is_pattern(p) then
      local tmp = fresh_tmp()
      params[#params + 1] = tmp
      destructuring_params[i] = { pattern = p, tmp = tmp }
    elseif p.type == ast.TYPE_ASSIGNMENT_PATTERN and is_pattern(p.left) then
      local tmp = fresh_tmp()
      params[#params + 1] = tmp
      destructuring_params[i] = { pattern = p.left, tmp = tmp, default = p.right }
    else
      params[#params + 1] = param_name(p)
    end
  end
  if has_rest then
    params[#params + 1] = "..."
  end
  scope_push(ctx)
  if extra_scope_names then
    for _, name in ipairs(extra_scope_names) do
      scope_declare(ctx, name, "let")
    end
  end
  if fn_node.name then
    scope_declare(ctx, fn_node.name, "let")
  end
  for _, p in ipairs(fn_node.params) do
    local name = param_name(p)
    if name then
      scope_declare(ctx, name, "let")
    end
  end
  local body = emit_block_body(fn_node.body, indent, ctx)
  local preamble = ""
  for _, p in ipairs(fn_node.params) do
    if
      p.type ~= ast.TYPE_REST_ELEMENT
      and not is_pattern(p)
      and p.type ~= ast.TYPE_ASSIGNMENT_PATTERN
    then
      local pname = param_name(p)
      if pname then
        preamble = preamble
          .. cg.if_stmt(
            pname .. " == nil",
            cg.expr_stmt(cg.binop("=", pname, "_ljs_undefined"), indent + 2),
            nil,
            nil,
            indent + 1
          )
      end
    end
  end
  for _, p in ipairs(fn_node.params) do
    if p.type == ast.TYPE_REST_ELEMENT then
      preamble = preamble
        .. cg.local_decl(p.argument.name, cg.call("_ljs_arr_lit", { "..." }), indent + 1)
    elseif p.type == ast.TYPE_ASSIGNMENT_PATTERN and not is_pattern(p.left) then
      local pname = p.left.name
      local default_code = emit(p.right, indent + 1, ctx)
      preamble = preamble
        .. cg.if_stmt(
          "_ljs_is_undef(" .. pname .. ")",
          cg.expr_stmt(cg.binop("=", pname, default_code), indent + 2),
          nil,
          nil,
          indent + 1
        )
    end
  end
  for _, entry in pairs(destructuring_params) do
    if entry.default then
      local default_code = emit(entry.default, indent + 1, ctx)
      preamble = preamble
        .. cg.if_stmt(
          "_ljs_is_undef(" .. entry.tmp .. ")",
          cg.expr_stmt(cg.binop("=", entry.tmp, default_code), indent + 2),
          nil,
          nil,
          indent + 1
        )
    end
    local out = {}
    emit_destructure(entry.pattern, entry.tmp, indent + 1, ctx, out)
    for _, line in ipairs(out) do
      preamble = preamble .. line
    end
  end
  local save_src = fn_node.type == ast.TYPE_ARROW_FUNCTION_EXPRESSION and "_ljs_arrow_this"
    or "_ljs_this"
  local stmts = fn_node.body.body
  local last = stmts[#stmts]
  local trailing = ""
  if not last or last.type ~= ast.TYPE_RETURN_STATEMENT then
    trailing = cg.return_stmt("_ljs_undefined", indent + 1)
  end
  body = cg.local_decl("_ljs_arrow_this", save_src, indent + 1) .. preamble .. body .. trailing
  scope_pop(ctx)
  return cg.fn_expr(cg.join(params), body, indent)
end

local function is_elseif_chain(node)
  if node.type == ast.TYPE_IF_STATEMENT then
    return true
  end
  if
    node.type == ast.TYPE_BLOCK_STATEMENT
    and #node.body == 1
    and node.body[1].type == ast.TYPE_IF_STATEMENT
  then
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
  local body = emit_controlled_body(node.consequent, indent, ctx)
  local elseifs = {}
  local else_body = nil

  local alternate = node.alternate
  while alternate do
    if is_elseif_chain(alternate) then
      local inner = alternate.type == ast.TYPE_IF_STATEMENT and alternate or alternate.body[1]
      elseifs[#elseifs + 1] = {
        test = cg.call("_ljs_to_boolean", { emit(inner.test, indent, ctx) }),
        body = emit_controlled_body(inner.consequent, indent, ctx),
      }
      alternate = inner.alternate
    else
      else_body = emit_controlled_body(alternate, indent, ctx)
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
    local prefix = {}
    for i = 1, #body - 1 do
      prefix[#prefix + 1] = body[i]
    end
    local code = emit_body(prefix, indent, ctx)
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
  return "_ljs_undefined"
end

gen.Identifier = function(node)
  return cg.ident(node.name)
end

gen.TemplateLiteral = function(node, indent, ctx)
  if #node.expressions == 0 then
    return cg.string(node.quasis[1].value)
  end
  local parts = {}
  for i, quasi in ipairs(node.quasis) do
    if #quasi.value > 0 then
      parts[#parts + 1] = cg.string(quasi.value)
    end
    if i <= #node.expressions then
      parts[#parts + 1] = cg.call("_ljs_tostring", { emit(node.expressions[i], indent, ctx) })
    end
  end
  return table.concat(parts, " .. ")
end

gen.ThisExpression = function()
  return "_ljs_arrow_this"
end

-- === Statements ===

local function expr_produces_valid_stmt(node)
  local t = node.type
  if t == ast.TYPE_CALL_EXPRESSION then
    return true
  end
  if t == ast.TYPE_NEW_EXPRESSION then
    return true
  end
  if t == ast.TYPE_OBJECT_EXPRESSION then
    return true
  end
  if t == ast.TYPE_ARRAY_EXPRESSION then
    return true
  end
  if t == ast.TYPE_FUNCTION_EXPRESSION then
    return true
  end
  if t == ast.TYPE_ARROW_FUNCTION_EXPRESSION then
    return true
  end
  if t == ast.TYPE_CLASS_EXPRESSION then
    return true
  end
  if t == ast.TYPE_BINARY_EXPRESSION then
    local op = node.operator
    if op == "===" or op == "!==" or op == "!=" or op == "in" then
      return false
    end
    return true
  end
  if t == ast.TYPE_UNARY_EXPRESSION then
    local op = node.operator
    if op == "~" or op == "+" then
      return true
    end
    return false
  end
  return false
end

gen.EmptyStatement = function()
  return ""
end

gen.ExpressionStatement = function(node, indent, ctx)
  local stmt_fn = gen_stmt[node.expression.type]
  if stmt_fn then
    return stmt_fn(node.expression, indent, ctx)
  end
  local expr = emit(node.expression, indent, ctx)
  if expr_produces_valid_stmt(node.expression) then
    return cg.expr_stmt(expr, indent)
  end
  return cg.discard_stmt(expr, indent)
end

local destructure_counter = 0

fresh_tmp = function()
  destructure_counter = destructure_counter + 1
  return "_ljs_d" .. destructure_counter
end

local function emit_binding(target, access, indent, ctx, out, kind)
  if target.type == ast.TYPE_IDENTIFIER then
    scope_declare(ctx, target.name, kind)
    out[#out + 1] = cg.local_decl(target.name, access, indent)
  elseif target.type == ast.TYPE_ASSIGNMENT_PATTERN then
    local inner = target.left
    local default_expr = emit(target.right, indent, ctx)
    local var_name
    if inner.type == ast.TYPE_IDENTIFIER then
      var_name = inner.name
      scope_declare(ctx, var_name, kind)
    else
      var_name = fresh_tmp()
    end
    out[#out + 1] = cg.local_decl(var_name, access, indent)
    out[#out + 1] = cg.if_stmt(
      "_ljs_is_undef(" .. var_name .. ")",
      cg.expr_stmt(cg.binop("=", var_name, default_expr), indent + 1),
      nil,
      nil,
      indent
    )
    if inner.type ~= ast.TYPE_IDENTIFIER then
      emit_destructure(inner, var_name, indent, ctx, out, kind)
    end
  elseif target.type == ast.TYPE_OBJECT_PATTERN or target.type == ast.TYPE_ARRAY_PATTERN then
    local tmp = fresh_tmp()
    out[#out + 1] = cg.local_decl(tmp, access, indent)
    emit_destructure(target, tmp, indent, ctx, out, kind)
  end
end

emit_destructure = function(pattern, rhs, indent, ctx, out, kind)
  if pattern.type == ast.TYPE_OBJECT_PATTERN then
    for _, prop_node in ipairs(pattern.properties) do
      if prop_node.type == ast.TYPE_REST_ELEMENT then
        local rest_name = prop_node.argument.name
        scope_declare(ctx, rest_name, kind)
        local collected = {}
        for _, p in ipairs(pattern.properties) do
          if p.type == ast.TYPE_PROPERTY then
            if p.key.type == ast.TYPE_IDENTIFIER then
              collected[#collected + 1] = cg.string(p.key.name)
            end
          end
        end
        local keys_expr = cg.array(collected)
        out[#out + 1] = cg.local_decl(rest_name, cg.call("_ljs_rest", { rhs, keys_expr }), indent)
      else
        local key_str
        if prop_node.key.type == ast.TYPE_IDENTIFIER then
          key_str = cg.string(prop_node.key.name)
        else
          key_str = emit(prop_node.key, indent, ctx)
        end
        local access = cg.member_index(rhs, key_str)
        emit_binding(prop_node.value, access, indent, ctx, out, kind)
      end
    end
  elseif pattern.type == ast.TYPE_ARRAY_PATTERN then
    local count = pattern.count or #pattern.elements
    for i = 1, count do
      local elem = pattern.elements[i]
      if elem == nil then
        -- hole: skip
      elseif elem.type == ast.TYPE_REST_ELEMENT then
        local rest_name = elem.argument.name
        scope_declare(ctx, rest_name, kind)
        out[#out + 1] = cg.local_decl(
          rest_name,
          cg.iife({
            cg.local_inline("_r", cg.array({ cg.call("table.unpack", { rhs, tostring(i) }) })),
            "_r.n = #" .. rhs .. " - " .. tostring(i - 1),
            cg.return_inline(cg.call("_ljs_arr_lit", { cg.call("_ljs_unpack", { "_r" }) })),
          }),
          indent
        )
      else
        local access = cg.member_index(rhs, tostring(i))
        emit_binding(elem, access, indent, ctx, out, kind)
      end
    end
  end
end

local emit_assign_binding

local function emit_assign_target(target, access, indent, ctx, out)
  if target.type == ast.TYPE_IDENTIFIER then
    check_assign(ctx, target.name)
    out[#out + 1] = cg.expr_stmt(cg.binop("=", target.name, access), indent)
  elseif target.type == ast.TYPE_MEMBER_EXPRESSION then
    local obj = emit(target.object, indent, ctx)
    local prop
    if target.computed then
      prop = emit(target.property, indent, ctx)
    else
      prop = cg.string(target.property.name)
    end
    out[#out + 1] = cg.expr_stmt(cg.binop("=", cg.member_index(obj, prop), access), indent)
  elseif target.type == ast.TYPE_ASSIGNMENT_PATTERN then
    local inner = target.left
    local default_expr = emit(target.right, indent, ctx)
    local var_name
    if inner.type == ast.TYPE_IDENTIFIER then
      var_name = inner.name
      out[#out + 1] = cg.expr_stmt(cg.binop("=", var_name, access), indent)
    elseif inner.type == ast.TYPE_MEMBER_EXPRESSION then
      var_name = fresh_tmp()
      out[#out + 1] = cg.local_decl(var_name, access, indent)
      emit_assign_target(inner, var_name, indent, ctx, out)
    else
      var_name = fresh_tmp()
      out[#out + 1] = cg.local_decl(var_name, access, indent)
      emit_assign_binding(inner, var_name, indent, ctx, out)
    end
    out[#out + 1] = cg.if_stmt(
      "_ljs_is_undef(" .. var_name .. ")",
      cg.expr_stmt(cg.binop("=", var_name, default_expr), indent + 1),
      nil,
      nil,
      indent
    )
  elseif target.type == ast.TYPE_OBJECT_PATTERN or target.type == ast.TYPE_ARRAY_PATTERN then
    local tmp = fresh_tmp()
    out[#out + 1] = cg.local_decl(tmp, access, indent)
    emit_assign_binding(target, tmp, indent, ctx, out)
  end
end

emit_assign_binding = function(pattern, rhs, indent, ctx, out)
  if pattern.type == ast.TYPE_OBJECT_PATTERN then
    for _, prop_node in ipairs(pattern.properties) do
      if prop_node.type == ast.TYPE_REST_ELEMENT then
        local rest_name = prop_node.argument.name
        local collected = {}
        for _, p in ipairs(pattern.properties) do
          if p.type == ast.TYPE_PROPERTY then
            if p.key.type == ast.TYPE_IDENTIFIER then
              collected[#collected + 1] = cg.string(p.key.name)
            end
          end
        end
        local keys_expr = cg.array(collected)
        out[#out + 1] =
          cg.expr_stmt(cg.binop("=", rest_name, cg.call("_ljs_rest", { rhs, keys_expr })), indent)
      else
        local key_str
        if prop_node.key.type == ast.TYPE_IDENTIFIER then
          key_str = cg.string(prop_node.key.name)
        else
          key_str = emit(prop_node.key, indent, ctx)
        end
        local access = cg.member_index(rhs, key_str)
        emit_assign_target(prop_node.value, access, indent, ctx, out)
      end
    end
  elseif pattern.type == ast.TYPE_ARRAY_PATTERN then
    local count = pattern.count or #pattern.elements
    for i = 1, count do
      local elem = pattern.elements[i]
      if elem == nil then
        -- hole: skip
      elseif elem.type == ast.TYPE_REST_ELEMENT then
        local rest_name = elem.argument.name
        out[#out + 1] = cg.expr_stmt(
          cg.binop(
            "=",
            rest_name,
            cg.iife({
              cg.local_inline("_r", cg.array({ cg.call("table.unpack", { rhs, tostring(i) }) })),
              "_r.n = #" .. rhs .. " - " .. tostring(i - 1),
              cg.return_inline(cg.call("_ljs_arr_lit", { cg.call("_ljs_unpack", { "_r" }) })),
            })
          ),
          indent
        )
      else
        local access = cg.member_index(rhs, tostring(i))
        emit_assign_target(elem, access, indent, ctx, out)
      end
    end
  end
end

gen.VariableDeclaration = function(node, indent, ctx)
  local out = {}
  for _, decl in ipairs(node.declarations) do
    if node.kind == "const" and not decl.init then
      error("SyntaxError: Missing initializer in const declaration", 0)
    end
    local name_type = decl.name.type
    if name_type == ast.TYPE_OBJECT_PATTERN or name_type == ast.TYPE_ARRAY_PATTERN then
      if decl.init then
        local init_expr = emit(decl.init, indent, ctx)
        local tmp = fresh_tmp()
        out[#out + 1] = cg.local_decl(tmp, init_expr, indent)
        emit_destructure(decl.name, tmp, indent, ctx, out, node.kind)
      end
    else
      local scope = ctx.scopes[#ctx.scopes]
      local is_fwd = scope[decl.name.name] == "__fwd"
      if is_fwd then
        if node.kind == "let" or node.kind == "const" then
          error("SyntaxError: Identifier '" .. decl.name.name .. "' has already been declared", 0)
        end
        scope[decl.name.name] = node.kind
      else
        scope_declare(ctx, decl.name.name, node.kind)
      end
      local init = decl.init
      if not init then
        if is_fwd then
          out[#out + 1] = cg.expr_stmt(cg.binop("=", decl.name.name, "_ljs_undefined"), indent)
        else
          out[#out + 1] = cg.local_decl(decl.name.name, "_ljs_undefined", indent)
        end
      elseif
        init.type == ast.TYPE_ARROW_FUNCTION_EXPRESSION
        or init.type == ast.TYPE_FUNCTION_EXPRESSION
      then
        local fn = emit_fn(init, indent, ctx)
        local wrapper = (init.type == ast.TYPE_FUNCTION_EXPRESSION and not init.is_method)
            and "_ljs_ctor"
          or "_ljs_fn"
        local inferred_name
        if init.type == ast.TYPE_FUNCTION_EXPRESSION and init.name then
          inferred_name = cg.string(init.name)
        else
          inferred_name = cg.string(decl.name.name)
        end
        if not is_fwd then
          out[#out + 1] = cg.local_decl(decl.name.name, nil, indent)
        end
        out[#out + 1] = cg.expr_stmt(
          cg.binop("=", decl.name.name, cg.call(wrapper, { fn, inferred_name })),
          indent
        )
      else
        if is_fwd then
          out[#out + 1] =
            cg.expr_stmt(cg.binop("=", decl.name.name, emit(init, indent, ctx)), indent)
        else
          out[#out + 1] = cg.local_decl(decl.name.name, emit(init, indent, ctx), indent)
        end
      end
    end
  end
  return table.concat(out)
end

gen.ReturnStatement = function(node, indent, ctx)
  local expr = node.argument and emit(node.argument, indent, ctx) or "_ljs_undefined"
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
  local fn = emit_fn(node, indent, ctx)
  return cg.expr_stmt(
    cg.binop("=", node.name, cg.call("_ljs_ctor", { fn, cg.string(node.name) })),
    indent
  )
end

--- Shared lowering logic for ClassDeclaration and ClassExpression.
-- Extracts the common class compilation into a single function; callers format
-- the result as either a statement (declaration) or expression (IIFE).
-- @param node (table) ClassDeclaration or ClassExpression AST node
-- @param indent (number) Current indentation level
-- @param ctx (table) Transpilation context
-- @param opts (table) { class_name: string, extra_scope: table|nil }
-- @return (table) { class_name, ctor_init_expr, stmts }
local function lower_class(node, indent, ctx, opts)
  local class_name = opts.class_name
  local extra_scope = opts.extra_scope
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

  local ctor_fn
  if constructor_method then
    ctor_fn = emit_fn(constructor_method.value, indent, ctx, extra_scope)
  elseif has_super then
    local params = { "_ljs_this", "..." }
    local body_code =
      cg.expr_stmt(cg.call("_ljs_call_this", { super_code, "_ljs_arrow_this", "..." }), indent + 1)
    body_code = cg.local_decl("_ljs_arrow_this", "_ljs_this", indent + 1) .. body_code
    ctor_fn = cg.fn_expr(cg.join(params), body_code, indent)
  else
    ctor_fn = cg.fn_expr("_ljs_this", "", indent)
  end

  local stmts = {}

  if has_super then
    stmts[#stmts + 1] = cg.binop(
      "=",
      cg.member_dot(class_name, "prototype"),
      cg.call("_ljs_object_create", { cg.nil_val(), cg.member_dot(super_code, "prototype") })
    )
    stmts[#stmts + 1] = cg.binop(
      "=",
      cg.member_dot(cg.member_dot(class_name, "prototype"), "constructor"),
      class_name
    )
  end

  for _, m in ipairs(methods) do
    local m_fn = emit_fn(m.value, indent, ctx, extra_scope)
    local m_name = method_key(m)
    stmts[#stmts + 1] = cg.binop(
      "=",
      cg.member_index(cg.member_dot(class_name, "prototype"), m_name),
      cg.call("_ljs_fn", { m_fn, m_name })
    )
  end

  for _, m in ipairs(statics) do
    local m_fn = emit_fn(m.value, indent, ctx, extra_scope)
    local m_name = method_key(m)
    stmts[#stmts + 1] =
      cg.binop("=", cg.member_index(class_name, m_name), cg.call("_ljs_fn", { m_fn, m_name }))
  end

  if has_super then
    ctx.super_stack[#ctx.super_stack] = nil
  end

  return {
    class_name = class_name,
    ctor_init_expr = cg.call("_ljs_ctor", { ctor_fn, cg.string(class_name) }),
    stmts = stmts,
  }
end

gen.ClassDeclaration = function(node, indent, ctx)
  scope_declare(ctx, node.name, "let")
  local result = lower_class(node, indent, ctx, {
    class_name = node.name,
    extra_scope = nil,
  })
  local out = cg.local_decl(result.class_name, result.ctor_init_expr, indent)
  for _, s in ipairs(result.stmts) do
    out = out .. cg.expr_stmt(s, indent)
  end
  return out
end

gen.ClassExpression = function(node, indent, ctx)
  local extra_scope = node.name and { node.name } or nil
  local result = lower_class(node, indent, ctx, {
    class_name = node.name or "_ljs_class",
    extra_scope = extra_scope,
  })
  local iife_stmts = {}
  iife_stmts[#iife_stmts + 1] = cg.local_inline(result.class_name, result.ctor_init_expr)
  for _, s in ipairs(result.stmts) do
    iife_stmts[#iife_stmts + 1] = s
  end
  iife_stmts[#iife_stmts + 1] = cg.return_inline(result.class_name)
  return cg.iife(iife_stmts)
end

gen.FunctionExpression = function(node, indent, ctx)
  local fn = emit_fn(node, indent, ctx)
  if node.is_method then
    return cg.call("_ljs_fn", { fn })
  end
  local args = { fn }
  if node.name then
    args[#args + 1] = cg.string(node.name)
  end
  return cg.call("_ljs_ctor", args)
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
  return cg.do_block(code, indent)
end

emit_block_body = function(block_node, indent, ctx)
  scope_push(ctx)
  local code = emit_body(block_node.body, indent + 1, ctx)
  scope_pop(ctx)
  return code
end

emit_controlled_body = function(node, indent, ctx)
  if node.type == ast.TYPE_BLOCK_STATEMENT then
    return emit_block_body(node, indent, ctx)
  end
  return emit(node, indent, ctx)
end

gen.IfStatement = function(node, indent, ctx)
  local test, body, elseifs, else_body = collect_if_chain(node, indent, ctx)
  return cg.if_stmt(test, body, elseifs, else_body, indent)
end

gen.WhileStatement = function(node, indent, ctx)
  local test_code = cg.call("_ljs_to_boolean", { emit(node.test, indent, ctx) })
  local body = emit_controlled_body(node.body, indent, ctx)
  if has_continue(node.body) then
    body = cg.do_block(body, indent + 1) .. cg.label("_continue", indent + 1)
  end
  return cg.while_stmt(test_code, body, indent)
end

-- JS do..while → Lua repeat..until. `until` takes an exit condition, so the
-- test is negated: JS `do {} while(cond)` → Lua `repeat until not cond`.
gen.DoWhileStatement = function(node, indent, ctx)
  local test_code = emit(node.test, indent, ctx)
  local body = emit_controlled_body(node.body, indent, ctx)
  if has_continue(node.body) then
    body = cg.do_block(body, indent + 1) .. cg.label("_continue", indent + 1)
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
  local iterable = emit(node.right, indent, ctx)
  local iter_tmp = fresh_tmp()
  local idx_tmp = fresh_tmp()
  scope_push(ctx)
  scope_declare(
    ctx,
    var_name,
    node.left.type == ast.TYPE_VARIABLE_DECLARATION and node.left.kind or "let"
  )
  local body = emit_controlled_body(node.body, indent, ctx)
  local var_init = cg.local_decl(var_name, cg.member_index(iter_tmp, idx_tmp), indent + 1)
  body = var_init .. body
  if has_continue(node.body) then
    body = cg.do_block(body, indent + 1) .. cg.label("_continue", indent + 1)
  end
  scope_pop(ctx)
  return cg.local_decl(iter_tmp, cg.call("_ljs_to_object", { iterable }), indent)
    .. cg.numeric_for(idx_tmp, "1", cg.member_dot(iter_tmp, "length"), body, indent)
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
  scope_declare(
    ctx,
    var_name,
    node.left.type == ast.TYPE_VARIABLE_DECLARATION and node.left.kind or "let"
  )
  local iter_tmp = fresh_tmp()
  local idx_tmp = fresh_tmp()
  local body = emit_controlled_body(node.body, indent, ctx)
  local var_init = cg.local_decl(var_name, cg.member_index(iter_tmp, idx_tmp), indent + 1)
  body = var_init .. body
  if has_continue(node.body) then
    body = cg.do_block(body, indent + 1) .. cg.label("_continue", indent + 1)
  end
  scope_pop(ctx)
  local keys_expr = cg.call("_ljs_for_in_keys", { emit(node.right, indent, ctx) })
  return cg.local_decl(iter_tmp, keys_expr, indent)
    .. cg.numeric_for(idx_tmp, "1", "#" .. iter_tmp, body, indent)
end

-- C-style for → init statement + while loop. The init is emitted as a separate
-- statement BEFORE the while so it runs once; the update runs at the END of
-- each loop iteration body (before the continue label, if present).
gen.ForStatement = function(node, indent, ctx)
  local parts = {}
  scope_push(ctx)
  if node.init then
    parts[#parts + 1] = emit(node.init, indent, ctx)
  end
  local test_code = node.test and cg.call("_ljs_to_boolean", { emit(node.test, indent, ctx) })
    or "true"
  local body = emit_controlled_body(node.body, indent, ctx)
  if has_continue(node.body) then
    body = cg.do_block(body, indent + 1) .. cg.label("_continue", indent + 1)
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
  local rethrow = not not ctx._in_try_pcall
  local cf = detect_control_flow(node.block)
  local block = cf and transform_control_flow(node.block) or node.block

  local prev = ctx._in_try_pcall
  ctx._in_try_pcall = true
  local try_body = emit(block, indent + 1, ctx)
  ctx._in_try_pcall = prev

  local param = node.handler and node.handler.param.name or nil
  local catch_body = nil
  if node.handler then
    scope_push(ctx)
    if param then
      scope_declare(ctx, param, "let")
    end
    catch_body = emit_block_body(node.handler.body, indent + 1, ctx)
    scope_pop(ctx)
  end

  local finalizer_body = nil
  if node.finalizer then
    finalizer_body = emit(node.finalizer, indent + 1, ctx)
  end

  local pcall_fn = cg.fn_expr("", try_body, indent + 1)
  local pcall_expr = cg.call("pcall", { pcall_fn })

  if cf and not node.handler and not node.finalizer then
    error("try with control flow requires surrounding loop or function")
  end

  if node.finalizer and not node.handler then
    local names = "_ljs_ok, _ljs_err"
    local pcall_line = cg.local_decl(names, pcall_expr, indent)
    local finally_block = finalizer_body
    local rethrow_inner = ""
    if cf then
      rethrow_inner = sentinel_handler(indent + 1, "_ljs_err", cf, rethrow)
    end
    local rethrow_block = cg.if_stmt(
      "not _ljs_ok",
      rethrow_inner ~= "" and rethrow_inner
        or cg.expr_stmt(cg.call("error", { "_ljs_err", "0" }), indent + 2),
      nil,
      nil,
      indent
    )
    return pcall_line .. finally_block .. rethrow_block
  end

  if cf then
    local err_var = "_ljs_err"
    local pcall_line = cg.local_decl(cg.join({ "ok", err_var }), pcall_expr, indent)
    local cf_check = sentinel_handler(indent + 1, err_var, cf, rethrow)
    local catch_inner = ""
    if node.handler then
      if param then
        catch_inner = cg.local_decl(param, err_var, indent + 2)
      end
      catch_inner = catch_inner .. catch_body
    end
    local catch_block = cg.if_stmt("not ok", cf_check .. catch_inner, nil, nil, indent)
    if node.finalizer then
      return pcall_line .. catch_block .. finalizer_body
    end
    return pcall_line .. catch_block
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

local SIMPLE_OPS = {
  ["+"] = "_ljs_add",
  ["-"] = "_ljs_sub",
  ["*"] = "_ljs_mul",
  ["/"] = "_ljs_div",
  ["**"] = "_ljs_pow",
  ["&"] = "_ljs_band",
  ["|"] = "_ljs_bor",
  ["^"] = "_ljs_bxor",
  ["<<"] = "_ljs_shl",
  [">>"] = "_ljs_shr",
  [">>>"] = "_ljs_usr",
  ["<"] = "_ljs_lt",
  [">"] = "_ljs_gt",
  ["<="] = "_ljs_le",
  [">="] = "_ljs_ge",
  ["instanceof"] = "_ljs_instanceof",
}

local COMPOUND_OPS = {
  ["+="] = "_ljs_add",
  ["-="] = "_ljs_sub",
  ["*="] = "_ljs_mul",
  ["/="] = "_ljs_div",
  ["**="] = "_ljs_pow",
  ["&="] = "_ljs_band",
  ["|="] = "_ljs_bor",
  ["^="] = "_ljs_bxor",
  ["<<="] = "_ljs_shl",
  [">>="] = "_ljs_shr",
  [">>>="] = "_ljs_usr",
}

gen.BinaryExpression = function(node, indent, ctx)
  local op = node.operator
  if
    op == "="
    and (node.left.type == ast.TYPE_ARRAY_PATTERN or node.left.type == ast.TYPE_OBJECT_PATTERN)
  then
    local right = emit(node.right, indent, ctx)
    local tmp = fresh_tmp()
    local out = {}
    out[#out + 1] = cg.local_inline(tmp, right)
    emit_assign_binding(node.left, tmp, indent, ctx, out)
    out[#out + 1] = cg.return_inline(tmp)
    return cg.iife(out)
  end
  if op == "=" and node.right.type == ast.TYPE_BINARY_EXPRESSION and node.right.operator == "=" then
    local targets = { node.left }
    local current = node.right
    while current.type == ast.TYPE_BINARY_EXPRESSION and current.operator == "=" do
      targets[#targets + 1] = current.left
      current = current.right
    end
    for _, lhs in ipairs(targets) do
      if lhs.type == ast.TYPE_IDENTIFIER then
        check_assign(ctx, lhs.name)
      end
    end
    local value = emit(current, indent, ctx)
    local tmp = fresh_tmp()
    local stmts = {}
    stmts[#stmts + 1] = cg.local_inline(tmp, value)
    for _, lhs in ipairs(targets) do
      stmts[#stmts + 1] = cg.binop("=", emit(lhs, indent, ctx), tmp)
    end
    stmts[#stmts + 1] = cg.return_inline(tmp)
    return cg.iife(stmts)
  end
  if node.left.type == ast.TYPE_IDENTIFIER then
    if op == "=" or COMPOUND_OPS[op] or op == "%=" then
      check_assign(ctx, node.left.name)
    end
  end
  local left = emit(node.left, indent, ctx)
  local right = emit(node.right, indent, ctx)
  local helper = SIMPLE_OPS[op]
  if helper then
    return cg.call(helper, { left, right })
  end
  local compound_helper = COMPOUND_OPS[op]
  if compound_helper then
    return cg.binop("=", left, cg.call(compound_helper, { left, right }))
  end
  -- Compound special: modulo
  if op == "%=" then
    return cg.binop(
      "=",
      left,
      cg.call(
        "_ljs_mod",
        { cg.call("_ljs_to_number", { left }), cg.call("_ljs_to_number", { right }) }
      )
    )
  end
  -- Direct mappings
  if op == "=" then
    return cg.binop("=", left, right)
  elseif op == "===" then
    return cg.call("_ljs_strict_eq", { left, right })
  elseif op == "!==" then
    return cg.unop("not", cg.call("_ljs_strict_eq", { left, right }))
  -- Equality with helper
  elseif op == "==" then
    return cg.call("_ljs_eq", { left, right })
  elseif op == "!=" then
    return cg.unop("not", cg.call("_ljs_eq", { left, right }))
  -- Logical (IIFE short-circuit)
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
  -- in operator
  elseif op == "in" then
    local key_code
    if node.left.type == ast.TYPE_STRING_LITERAL then
      key_code = left
    elseif node.left.type == ast.TYPE_NUMBER_LITERAL then
      key_code = cg.binop("+", cg.paren(left), "1")
    else
      key_code = cg.call("_ljs_index", { left })
    end
    local right_expr = right:sub(1, 1) == "{" and cg.paren(right) or right
    return cg.call("_ljs_has_property", { right_expr, key_code })
  -- Arithmetic special: modulo
  elseif op == "%" then
    return cg.call(
      "_ljs_mod",
      { cg.call("_ljs_to_number", { left }), cg.call("_ljs_to_number", { right }) }
    )
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
  return cg.call("_ljs_neg", { expr })
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
    if node.property.type == ast.TYPE_NUMBER_LITERAL then
      return cg.binop("+", cg.paren(emit(node.property, indent, ctx)), "1")
    end
    return cg.call("_ljs_index", { emit(node.property, indent, ctx) })
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
  local arg = node.argument
  if arg.type == ast.TYPE_UNDEFINED_LITERAL then
    return "false"
  end
  if arg.type == ast.TYPE_IDENTIFIER then
    if arg.name == "NaN" or arg.name == "Infinity" then
      return "false"
    end
    if scope_lookup(ctx, arg.name) then
      return "false"
    end
  end
  return "true"
end

gen.TypeofExpression = function(node, indent, ctx)
  return cg.call("_ljs_typeof", { emit(node.argument, indent, ctx) })
end

-- Expression-context ++/--: wrapped in IIFE to return the value.
-- Prefix returns the new value; postfix saves old value, increments, returns old.
gen.UpdateExpression = function(node, indent, ctx)
  if node.argument.type == ast.TYPE_IDENTIFIER then
    check_assign(ctx, node.argument.name)
  end
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
  return cg.iife({
    cg.local_inline("_t", cg.call("_ljs_to_number", { arg })),
    cg.binop("=", arg, val),
    cg.return_inline("_t"),
  })
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
local function has_spread_element(nodes)
  for _, n in ipairs(nodes) do
    if n.type == ast.TYPE_SPREAD_ELEMENT then
      return true
    end
  end
  return false
end

local function emit_spread_args(nodes, indent, ctx)
  local args = {}
  for _, n in ipairs(nodes) do
    if n.type == ast.TYPE_SPREAD_ELEMENT then
      args[#args + 1] = emit(n.argument, indent, ctx)
      args[#args + 1] = "true"
    else
      args[#args + 1] = emit(n, indent, ctx)
      args[#args + 1] = "false"
    end
  end
  return args
end

gen.CallExpression = function(node, indent, ctx)
  local has_spread = has_spread_element(node.arguments)

  if has_spread then
    local spread_args = emit_spread_args(node.arguments, indent, ctx)
    local build_call = cg.call("_ljs_spread_build", spread_args)
    local unpack_call = cg.call("_ljs_unpack", { "_s" })

    if node.callee.type == ast.TYPE_SUPER_EXPRESSION then
      local super_parent = ctx.super_stack[#ctx.super_stack]
      return cg.iife({
        cg.local_inline("_s", build_call),
        cg.return_inline(cg.call(super_parent, { "_ljs_arrow_this", unpack_call })),
      })
    end

    if
      node.callee.type == ast.TYPE_MEMBER_EXPRESSION
      and node.callee.object.type == ast.TYPE_SUPER_EXPRESSION
    then
      local super_parent = ctx.super_stack[#ctx.super_stack]
      local proto = cg.member_dot(super_parent, "prototype")
      local key_expr = member_key(node.callee, indent, ctx)
      return cg.iife({
        cg.local_inline("_s", build_call),
        cg.return_inline(
          cg.call("_ljs_super_call", { proto, key_expr, "_ljs_arrow_this", unpack_call })
        ),
      })
    end

    if node.callee.type == ast.TYPE_MEMBER_EXPRESSION then
      local obj_expr = emit(node.callee.object, indent, ctx)
      local key_expr = member_key(node.callee, indent, ctx)
      return cg.iife({
        cg.local_inline("_s", build_call),
        cg.return_inline(cg.call("_ljs_call_member", { obj_expr, key_expr, unpack_call })),
      })
    end

    return cg.iife({
      cg.local_inline("_s", build_call),
      cg.return_inline(cg.call("_ljs_call", { emit(node.callee, indent, ctx), unpack_call })),
    })
  end

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

  if
    node.callee.type == ast.TYPE_MEMBER_EXPRESSION
    and node.callee.object.type == ast.TYPE_SUPER_EXPRESSION
  then
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
  if has_spread_element(node.arguments) then
    local spread_args = emit_spread_args(node.arguments, indent, ctx)
    return cg.iife({
      cg.local_inline("_s", cg.call("_ljs_spread_build", spread_args)),
      cg.return_inline(
        cg.call("_ljs_new", { emit(node.callee, indent, ctx), cg.call("_ljs_unpack", { "_s" }) })
      ),
    })
  end
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
  local count = node.count or #node.elements
  local has_spread = false
  for i = 1, count do
    local e = node.elements[i]
    if e ~= nil and e.type == ast.TYPE_SPREAD_ELEMENT then
      has_spread = true
      break
    end
  end
  if not has_spread then
    local args = {}
    for i = 1, count do
      local e = node.elements[i]
      if e ~= nil then
        args[#args + 1] = emit(e, indent, ctx)
      else
        args[#args + 1] = "nil"
      end
    end
    return cg.call("_ljs_arr_lit", args)
  end
  local spread_args = {}
  for i = 1, count do
    local e = node.elements[i]
    if e == nil then
      spread_args[#spread_args + 1] = "nil"
      spread_args[#spread_args + 1] = "false"
    elseif e.type == ast.TYPE_SPREAD_ELEMENT then
      spread_args[#spread_args + 1] = emit(e.argument, indent, ctx)
      spread_args[#spread_args + 1] = "true"
    else
      spread_args[#spread_args + 1] = emit(e, indent, ctx)
      spread_args[#spread_args + 1] = "false"
    end
  end
  return cg.iife({
    cg.local_inline("_s", cg.call("_ljs_spread_build", spread_args)),
    cg.return_inline(cg.call("_ljs_arr_lit", { cg.call("_ljs_unpack", { "_s" }) })),
  })
end

-- === Statement-context emission ===
-- gen_stmt handlers produce cheaper code than the expression-context gen handlers.
-- Used when an expression appears as the sole child of an ExpressionStatement,
-- avoiding IIFE wrapping where a direct statement will do.

-- Statement-context ++/--: direct assignment, no IIFE needed.
gen_stmt.UpdateExpression = function(node, indent, ctx)
  if node.argument.type == ast.TYPE_IDENTIFIER then
    check_assign(ctx, node.argument.name)
  end
  local arg = emit(node.argument, indent, ctx)
  if node.operator == "++" then
    return cg.expr_stmt(
      cg.binop("=", arg, cg.binop("+", cg.call("_ljs_to_number", { arg }), "1")),
      indent
    )
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

gen_stmt.BinaryExpression = function(node, indent, ctx)
  local op = node.operator
  if
    op == "="
    and (node.left.type == ast.TYPE_ARRAY_PATTERN or node.left.type == ast.TYPE_OBJECT_PATTERN)
  then
    local right = emit(node.right, indent, ctx)
    local tmp = fresh_tmp()
    local out = {}
    out[#out + 1] = cg.local_decl(tmp, right, indent)
    emit_assign_binding(node.left, tmp, indent, ctx, out)
    return table.concat(out)
  end
  local expr = emit(node, indent, ctx)
  if expr_produces_valid_stmt(node) then
    return cg.expr_stmt(expr, indent)
  end
  return cg.discard_stmt(expr, indent)
end

-- === Top-level preamble and emit ===

-- Emission order: _ljs_to_number before _ljs_to_int32 (which depends on it),
-- _ljs_to_number/_ljs_to_boolean before arithmetic and coercion helpers,
-- _ljs_fn before _ljs_ctor (which depends on it), _ljs_to_object before
-- _ljs_call_member (which calls it), _ljs_tostring, rest alphabetical.
-- All 44 helpers are always emitted unconditionally.
local HELPER_ORDER = {
  "_ljs_is_undef",
  "_ljs_is_nilish",
  "_ljs_type_error",
  "_ljs_range_error",
  "_ljs_to_primitive",
  "_ljs_to_number",
  "_ljs_to_int32",
  "_ljs_to_float",
  "_ljs_neg",
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
  "_ljs_is_function",
  "_ljs_is_constructor",
  "_ljs_value_repr",
  "_ljs_call",
  "_ljs_call_member",
  "_ljs_object",
  "_ljs_object_create",
  "_ljs_ctor",
  "_ljs_new",
  "_ljs_arr_lit",
  "_ljs_call_this",
  "_ljs_instanceof",
  "_ljs_for_in_keys",
  "_ljs_str_to_num",
  "_ljs_super_call",
  "_ljs_spread_build",
  "_ljs_unpack",
  "_ljs_rest",
  "_ljs_eq",
  "_ljs_strict_eq",
  "_ljs_lt",
  "_ljs_gt",
  "_ljs_le",
  "_ljs_ge",
  "_ljs_has_property",
  "_ljs_index",
}

local _preamble_cache = nil

--- Build the runtime preamble (helpers + stdlib). Result is cached after first call.
-- Structure: proto declarations → _ljs_arrow_this → _ljs_undefined → _ljs_null → setmetatable → _ljs_is_undef → _ljs_is_nilish → _ljs_to_primitive → _ljs_to_number → _ljs_to_int32 → remaining helpers → runtime stdlib files.
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
    .. "local _ljs_undefined = {}\n"
    .. "local _ljs_null = {}\n"
    .. "local TypeError, RangeError\n"
    .. "setmetatable(_ljs_object_prototype, { __index = function(t, k) return _ljs_undefined end })\n\n"
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
  destructure_counter = 0
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
