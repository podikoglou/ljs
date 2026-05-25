_ljs_number_prototype.toString = _ljs_fn(function(_ljs_this)
  local v = _ljs_this._ljs_data
  if v ~= v then
    return "NaN"
  end
  if v == math.huge then
    return "Infinity"
  end
  if v == -math.huge then
    return "-Infinity"
  end
  if v == 0 then
    return "0"
  end
  if math.floor(v) == v then
    return tostring(math.floor(v))
  end
  return tostring(v)
end)
_ljs_number_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)

setmetatable(_ljs_number_prototype, { __index = _ljs_object_prototype })

local Number = _ljs_fn(function(_ljs_this, ...)
  local value
  if select("#", ...) == 0 then
    value = 0
  else
    value = _ljs_to_number(...)
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
Number.prototype = _ljs_number_prototype
_ljs_number_prototype.constructor = Number
