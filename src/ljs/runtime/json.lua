-- JSON.parse/stringify wrapping rxi's json.lua (loaded as `json` in the preamble).
-- Post-processes decoded values to produce proper ljs runtime objects:
-- arrays get Array.prototype chain + .length, objects get Object.prototype chain.
-- stringify handles ljs-specific types (callable tables → skip, checks .length
-- for array detection via prototype chain walk).

--- Recursively wrap a decoded JSON value into ljs runtime objects.
-- Arrays (marked with _ljs_arr by json_lib.parse_array) become Array instances
-- with 1-based indexing and .length. Objects become _ljs_object instances.
-- The _ljs_arr marker is stripped after detection.
local function _ljs_json_wrap(val)
  if val == json.null then
    return val
  end
  if type(val) ~= "table" then
    return val
  end
  if rawget(val, "_ljs_arr") then
    rawset(val, "_ljs_arr", nil)
    local n = #val
    for i = 1, n do
      val[i] = _ljs_json_wrap(val[i])
    end
    setmetatable(val, { __index = Array.prototype })
    val.length = n
    return val
  end
  local result = _ljs_object({})
  for k, v in pairs(val) do
    result[k] = _ljs_json_wrap(v)
  end
  return result
end

-- JSON object: plain _ljs_object with parse and stringify methods.
local JSON = _ljs_object({})
JSON.null = json.null

JSON.parse = _ljs_fn(function(_ljs_this, text)
  return _ljs_json_wrap(json.decode(text))
end)

-- Detect callable tables (functions) by checking for __call metamethod.
-- Used by stringify to skip function-valued properties.
local function _ljs_is_fn(val)
  if type(val) ~= "table" then
    return false
  end
  local mt = getmetatable(val)
  return mt and mt.__call ~= nil
end

-- Check if a value is an Array instance by walking its __index chain
-- looking for Array.prototype. Needed because JSON.stringify must distinguish
-- arrays from plain objects.
local function _ljs_is_array(val)
  local mt = getmetatable(val)
  if not mt then
    return false
  end
  local proto = mt.__index
  while proto ~= nil do
    if proto == Array.prototype then
      return true
    end
    local pmt = getmetatable(proto)
    proto = pmt and pmt.__index
  end
  return false
end

-- Custom stringify that understands ljs runtime objects: uses rawget for array
-- elements (skips inherited properties), checks prototype chain for array type,
-- skips functions. Circular reference detection via stack.
-- _ljs_null (JS null) → "null", nil (JS undefined) → nil (omitted) per §25.5.4.2.
local function _ljs_json_stringify(val, stack)
  stack = stack or {}
  if val == json.null then
    return "null"
  end
  if _ljs_is_undef(val) then
    return nil
  end
  if val == _ljs_null then
    return "null"
  end
  if type(val) == "boolean" then
    return tostring(val)
  end
  if type(val) == "number" then
    if val ~= val or val <= -math.huge or val >= math.huge then
      return "null"
    end
    return string.format("%.14g", val)
  end
  if type(val) == "string" then
    return json.encode(val)
  end
  if type(val) == "table" then
    if _ljs_is_fn(val) then
      return nil
    end
    if stack[val] then
      error("circular reference")
    end
    stack[val] = true
    if _ljs_is_array(val) then
      local len = val.length
      local items = {}
      for i = 1, len do
        local s = _ljs_json_stringify(rawget(val, i), stack)
        items[i] = s or "null"
      end
      stack[val] = nil
      return "[" .. table.concat(items, ",") .. "]"
    end
    local parts = {}
    for k, v in pairs(val) do
      if type(k) == "string" then
        local s = _ljs_json_stringify(v, stack)
        if s ~= nil then
          parts[#parts + 1] = json.encode(k) .. ":" .. s
        end
      end
    end
    stack[val] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return nil
end

JSON.stringify = _ljs_fn(function(_ljs_this, value)
  return _ljs_json_stringify(value)
end)
