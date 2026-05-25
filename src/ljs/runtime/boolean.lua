_ljs_boolean_prototype.toString = _ljs_fn(function(_ljs_this)
  if _ljs_this._ljs_data then
    return "true"
  end
  return "false"
end)
_ljs_boolean_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)

setmetatable(_ljs_boolean_prototype, { __index = _ljs_object_prototype })

local Boolean = _ljs_fn(function(_ljs_this, value)
  if value == nil or value == _ljs_null then
    value = false
  elseif type(value) ~= "boolean" then
    local vt = type(value)
    if vt == "number" then
      value = value ~= 0 and value == value
    elseif vt == "string" then
      value = #value > 0
    else
      value = true
    end
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
Boolean.prototype = _ljs_boolean_prototype
_ljs_boolean_prototype.constructor = Boolean
