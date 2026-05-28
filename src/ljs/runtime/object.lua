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
  if obj == nil or obj == _ljs_null then
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
  if obj == nil or obj == _ljs_null then
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
