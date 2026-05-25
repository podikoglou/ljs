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
    value = ...
    if value == _ljs_null then
      value = "null"
    elseif value == nil then
      value = "undefined"
    elseif type(value) == "string" then
      -- keep as-is
    elseif type(value) == "number" then
      if value ~= value then
        value = "NaN"
      elseif value == math.huge then
        value = "Infinity"
      elseif value == -math.huge then
        value = "-Infinity"
      else
        if value == 0 then
          value = "0"
        elseif math.floor(value) == value then
          value = tostring(math.floor(value))
        else
          value = tostring(value)
        end
      end
    else
      value = tostring(value)
    end
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
String.prototype = _ljs_string_prototype
_ljs_string_prototype.constructor = String
