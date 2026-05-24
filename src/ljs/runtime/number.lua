_ljs_number_prototype.toString = _ljs_fn(function(_ljs_this)
  local v = _ljs_this._ljs_data
  local s = tostring(v)
  if s == "nan" or s == "-nan" then
    return "NaN"
  end
  if s == "inf" then
    return "Infinity"
  end
  if s == "-inf" then
    return "-Infinity"
  end
  return s
end)
_ljs_number_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)

setmetatable(_ljs_number_prototype, { __index = _ljs_object_prototype })

local Number = _ljs_fn(function(_ljs_this, value)
  if value == nil then
    value = 0
  end
  if type(value) ~= "number" then
    value = tonumber(value) or 0
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
Number.prototype = _ljs_number_prototype
_ljs_number_prototype.constructor = Number
