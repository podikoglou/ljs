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
-- Array.prototype.some
-- ---------------------------------------------------------------------------
Array.prototype.some = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local testResult = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      if testResult then
        return true
      end
    end
  end
  return false
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.every
-- ---------------------------------------------------------------------------
Array.prototype.every = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local testResult = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      if not testResult then
        return false
      end
    end
  end
  return true
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.slice
-- ---------------------------------------------------------------------------
Array.prototype.slice = _ljs_fn(function(_ljs_this, start_val, end_val)
  local len = _ljs_this.length or 0
  local function to_int(v)
    if v == nil then return 0 end
    local n = tonumber(v)
    if n == nil or n ~= n then return 0 end
    return math.floor(n)
  end

  local relative_start = to_int(start_val)
  local k
  if relative_start < 0 then
    k = math.max(len + relative_start, 0)
  else
    k = math.min(relative_start, len)
  end

  local relative_end
  if end_val == nil then
    relative_end = len
  else
    relative_end = to_int(end_val)
  end
  local final_
  if relative_end < 0 then
    final_ = math.max(len + relative_end, 0)
  else
    final_ = math.min(relative_end, len)
  end

  local result = _ljs_new(Array)
  local ri = 1
  for i = k + 1, final_ do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      rawset(result, ri, v)
    end
    ri = ri + 1
  end
  rawset(result, "length", math.max(final_ - k, 0))
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.concat
-- ---------------------------------------------------------------------------
Array.prototype.concat = _ljs_fn(function(_ljs_this, ...)
  local result = _ljs_new(Array)
  local next_idx = 1

  local function append_item(item)
    if _ljs_instanceof(item, Array) then
      local item_len = item.length or 0
      for i = 1, item_len do
        local v = rawget(item, i)
        if v ~= nil then
          rawset(result, next_idx, v)
        end
        next_idx = next_idx + 1
      end
    else
      rawset(result, next_idx, item)
      next_idx = next_idx + 1
    end
  end

  append_item(_ljs_this)

  local n = select("#", ...)
  for i = 1, n do
    append_item(select(i, ...))
  end

  rawset(result, "length", next_idx - 1)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.at
-- ---------------------------------------------------------------------------
Array.prototype.at = _ljs_fn(function(_ljs_this, index_val)
  local len = _ljs_this.length or 0
  local relative_index
  if index_val == nil then
    relative_index = 0
  else
    local n = tonumber(index_val)
    if n == nil or n ~= n then
      relative_index = 0
    elseif n == math.huge or n == -math.huge then
      relative_index = n
    else
      relative_index = n >= 0 and math.floor(n) or math.ceil(n)
    end
  end
  local k
  if relative_index >= 0 then
    k = relative_index
  else
    k = len + relative_index
  end
  if k < 0 or k >= len then
    return nil
  end
  return rawget(_ljs_this, k + 1)
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
