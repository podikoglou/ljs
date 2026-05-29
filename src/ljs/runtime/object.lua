-- Object.prototype methods + Object constructor. Populates the root
-- _ljs_object_prototype declared in proto.lua, then creates the Object
-- constructor (via _ljs_ctor) and wires up Object.create.
--
-- hasOwnProperty uses rawget to check own properties only (no prototype chain walk).
_ljs_object_prototype.hasOwnProperty = _ljs_fn(function(_ljs_this, key)
  return rawget(_ljs_this, key) ~= nil
end)
_ljs_object_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this
end)
_ljs_object_prototype.toLocaleString = _ljs_fn(function(_ljs_this)
  return _ljs_call_member(_ljs_this, "toString")
end)

local _ljs_internal_keys = { _ljs_raw = true, _ljs_data = true }

local function _ljs_own_keys(obj)
  local keys = {}
  local k = nil
  while true do
    k = next(obj, k)
    if k == nil then break end
    if type(k) == "string" and not _ljs_internal_keys[k] then
      keys[#keys + 1] = k
    end
  end
  return keys
end

local function _ljs_own_entries(obj)
  local entries = {}
  local k = nil
  while true do
    k = next(obj, k)
    if k == nil then break end
    if type(k) == "string" and not _ljs_internal_keys[k] then
      entries[#entries + 1] = { k, rawget(obj, k) }
    end
  end
  return entries
end

local Object = _ljs_ctor(function(_ljs_this)
  return _ljs_this
end)
Object.prototype = _ljs_object_prototype
Object.prototype.constructor = Object
Object.create = _ljs_fn(_ljs_object_create)

Object.keys = _ljs_fn(function(_ljs_this, obj)
  if _ljs_is_nilish(obj) then
    error("TypeError: Cannot convert " .. _ljs_value_repr(obj) .. " to object")
  end
  local o = _ljs_to_object(obj)
  local keyList = _ljs_own_keys(o)
  local result = { length = #keyList }
  for i, k in ipairs(keyList) do
    rawset(result, i, k)
  end
  return result
end)

Object.values = _ljs_fn(function(_ljs_this, obj)
  if _ljs_is_nilish(obj) then
    error("TypeError: Cannot convert " .. _ljs_value_repr(obj) .. " to object")
  end
  local o = _ljs_to_object(obj)
  local entries = _ljs_own_entries(o)
  local result = { length = #entries }
  for i, e in ipairs(entries) do
    rawset(result, i, e[2])
  end
  return result
end)

Object.entries = _ljs_fn(function(_ljs_this, obj)
  if _ljs_is_nilish(obj) then
    error("TypeError: Cannot convert " .. _ljs_value_repr(obj) .. " to object")
  end
  local o = _ljs_to_object(obj)
  local entries = _ljs_own_entries(o)
  local result = { length = #entries }
  for i, e in ipairs(entries) do
    rawset(result, i, { length = 2, e[1], e[2] })
  end
  return result
end)

Object.assign = _ljs_fn(function(_ljs_this, target, ...)
  if _ljs_is_nilish(target) then
    error("TypeError: Cannot convert " .. _ljs_value_repr(target) .. " to object")
  end
  local to = _ljs_to_object(target)
  local n = select("#", ...)
  if n == 0 then
    return to
  end
  for i = 1, n do
    local source = select(i, ...)
    if not _ljs_is_nilish(source) then
      local from = _ljs_to_object(source)
      local keys = _ljs_own_keys(from)
      for _, k in ipairs(keys) do
        rawset(to, k, rawget(from, k))
      end
    end
  end
  return to
end)

Object.is = _ljs_fn(function(_ljs_this, x, y)
  if type(x) == "number" and type(y) == "number" then
    if x ~= x and y ~= y then return true end
    if x == 0 and y == 0 then
      return (1 / x == 1 / y)
    end
    return x == y
  end
  if x == y then return true end
  return (x == nil and y == _ljs_undefined) or (x == _ljs_undefined and y == nil)
end)

Object.getOwnPropertyNames = _ljs_fn(function(_ljs_this, obj)
  if _ljs_is_nilish(obj) then
    error("TypeError: Cannot convert " .. _ljs_value_repr(obj) .. " to object")
  end
  local o = _ljs_to_object(obj)
  local keyList = _ljs_own_keys(o)
  local result = { length = #keyList }
  for i, k in ipairs(keyList) do
    rawset(result, i, k)
  end
  return result
end)

Object.freeze = _ljs_fn(function(_ljs_this, obj)
  if type(obj) ~= "table" then
    return obj
  end
  if obj == _ljs_null then
    return obj
  end
  local mt = getmetatable(obj)
  local new_mt = {}
  if mt then
    for k, v in pairs(mt) do
      new_mt[k] = v
    end
  end
  new_mt.__newindex = function(_, k, v)
    error("TypeError: Cannot assign to property '" .. tostring(k) .. "' of frozen object")
  end
  setmetatable(obj, new_mt)
  return obj
end)

Object.seal = _ljs_fn(function(_ljs_this, obj)
  if type(obj) ~= "table" then
    return obj
  end
  if obj == _ljs_null then
    return obj
  end
  local mt = getmetatable(obj)
  local new_mt = {}
  if mt then
    for k, v in pairs(mt) do
      new_mt[k] = v
    end
  end
  new_mt.__newindex = function(_, k, v)
    error("TypeError: Cannot add property '" .. tostring(k) .. "' to sealed object")
  end
  setmetatable(obj, new_mt)
  return obj
end)

Object.getPrototypeOf = _ljs_fn(function(_ljs_this, obj)
  if _ljs_is_nilish(obj) then
    error("TypeError: Cannot convert " .. _ljs_value_repr(obj) .. " to object")
  end
  local o = _ljs_to_object(obj)
  local mt = getmetatable(o)
  if mt == nil then
    return _ljs_null
  end
  local proto = mt.__index
  if type(proto) ~= "table" then
    return _ljs_null
  end
  return proto
end)
