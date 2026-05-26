_ljs_string_prototype.toString = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)
_ljs_string_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)

setmetatable(_ljs_string_prototype, { __index = _ljs_object_prototype })

local String = _ljs_fn(function(_ljs_this, ...)
  local value
  if select("#", ...) == 0 then
    value = ""
  else
    value = _ljs_tostring(...)
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
String.prototype = _ljs_string_prototype
_ljs_string_prototype.constructor = String
