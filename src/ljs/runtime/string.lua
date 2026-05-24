_ljs_string_prototype.toString = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)
_ljs_string_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)

setmetatable(_ljs_string_prototype, { __index = _ljs_object_prototype })

local String = _ljs_fn(function(_ljs_this, value)
  if value == nil then
    value = ""
  end
  if type(value) ~= "string" then
    value = tostring(value)
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
String.prototype = _ljs_string_prototype
_ljs_string_prototype.constructor = String
