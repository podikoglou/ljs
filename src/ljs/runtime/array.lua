local Array = _ljs_ctor(function(_ljs_this, ...)
  local n = select("#", ...)
  for i = 1, n do
    _ljs_this[i] = select(i, ...)
  end
  _ljs_this.length = n
end)
Array.prototype.push = function(_ljs_this, ...)
  local n = select("#", ...)
  for i = 1, n do
    _ljs_this[_ljs_this.length + i] = select(i, ...)
  end
  _ljs_this.length = _ljs_this.length + n
  return _ljs_this.length
end
Array.prototype.pop = function(_ljs_this)
  if _ljs_this.length == 0 then
    return nil
  end
  local val = _ljs_this[_ljs_this.length]
  _ljs_this[_ljs_this.length] = nil
  _ljs_this.length = _ljs_this.length - 1
  return val
end

-- ---------------------------------------------------------------------------
-- Array.isArray
-- ---------------------------------------------------------------------------
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
      arr[i] = val
    end
    arr.length = #source
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
      arr[i] = val
    end
    arr.length = len
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
