-- Array constructor + prototype methods + static methods.
-- Array constructor stores elements at 1-based indices and sets .length.
-- All methods follow the JS-ABI convention: first param is _ljs_this.

local function _ljs_arr_newindex(t, k, v)
  rawset(t, k, v)
  if type(k) == "number" and k == math.floor(k) and k > 0 then
    local len = rawget(t, "length")
    if len ~= nil and k > len then
      rawset(t, "length", k)
    end
  end
end

local Array = _ljs_ctor(function(_ljs_this, ...)
  local mt = getmetatable(_ljs_this)
  mt.__newindex = _ljs_arr_newindex
  local n = select("#", ...)
  for i = 1, n do
    rawset(_ljs_this, i, select(i, ...))
  end
  rawset(_ljs_this, "length", n)
end)
-- push supports multiple arguments (matching JS Array.prototype.push semantics).
Array.prototype.push = _ljs_fn(function(_ljs_this, ...)
  local n = select("#", ...)
  local len = _ljs_this.length
  for i = 1, n do
    rawset(_ljs_this, len + i, select(i, ...))
  end
  rawset(_ljs_this, "length", len + n)
  return len + n
end)
Array.prototype.pop = _ljs_fn(function(_ljs_this)
  if _ljs_this.length == 0 then
    return nil
  end
  local val = _ljs_this[_ljs_this.length]
  rawset(_ljs_this, _ljs_this.length, nil)
  rawset(_ljs_this, "length", _ljs_this.length - 1)
  return val
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.map
-- ---------------------------------------------------------------------------
Array.prototype.map = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local result = _ljs_new(Array)
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local mapped = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      rawset(result, i, mapped)
    end
  end
  rawset(result, "length", len)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.join
-- ---------------------------------------------------------------------------
-- Converts each element to a string (using tostring; nil/undefined → ""),
-- then concatenates with the given separator (default ",").
Array.prototype.join = _ljs_fn(function(_ljs_this, sep)
  if sep == nil then
    sep = ","
  end
  if _ljs_this.length == 0 then
    return ""
  end
  local parts = {}
  for i = 1, _ljs_this.length do
    local v = _ljs_this[i]
    if v == nil then
      parts[i] = ""
    else
      parts[i] = tostring(v)
    end
  end
  return table.concat(parts, sep)
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.toString
-- ---------------------------------------------------------------------------
-- Per spec: calls .join(",") on this.
Array.prototype.toString = _ljs_fn(function(_ljs_this)
  local join = _ljs_to_object(_ljs_this).join
  if _ljs_typeof(join) == "function" then
    local raw = rawget(join, "_ljs_raw")
    if raw then return raw(_ljs_this, ",") end
    return join(_ljs_this, ",")
  end
  local ts_raw = rawget(_ljs_object_prototype.toString, "_ljs_raw")
  if ts_raw then return ts_raw(_ljs_this) end
  return _ljs_object_prototype.toString(_ljs_this)
end)

-- ---------------------------------------------------------------------------
-- Array.isArray
-- ---------------------------------------------------------------------------
-- Array.isArray: checks via _ljs_instanceof so subclass instances return true.
-- Wrapped in _ljs_fn (no .prototype) since it's a static utility.
Array.isArray = _ljs_fn(function(_ljs_this, x)
  return _ljs_instanceof(x, Array)
end)

-- ---------------------------------------------------------------------------
-- Array.from
-- ---------------------------------------------------------------------------
Array.from = _ljs_fn(function(_ljs_this, source, mapFn, thisArg)
  local arr = _ljs_new(Array)
  if source == nil then
    return arr
  end
  if type(source) == "string" then
    for i = 1, #source do
      local val = source:sub(i, i)
      if mapFn ~= nil then
        val = _ljs_call_member(mapFn, "call", thisArg, val, i - 1)
      end
      rawset(arr, i, val)
    end
    rawset(arr, "length", #source)
    return arr
  end
  if type(source) == "table" then
    local len = source.length
    if len == nil then
      return arr
    end
    for i = 1, len do
      local val = source[i]
      if mapFn ~= nil then
        val = _ljs_call_member(mapFn, "call", thisArg, val, i - 1)
      end
      rawset(arr, i, val)
    end
    rawset(arr, "length", len)
    return arr
  end
  return arr
end)

-- ---------------------------------------------------------------------------
-- Array.of
-- ---------------------------------------------------------------------------
Array.of = _ljs_fn(function(_ljs_this, ...)
  return _ljs_new(Array, ...)
end)
