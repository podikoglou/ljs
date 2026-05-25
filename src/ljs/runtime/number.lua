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

local Number = _ljs_fn(function(_ljs_this, ...)
  local value
  if select("#", ...) == 0 then
    value = 0
  else
    value = ...
    if value == _ljs_null then
      value = 0
    elseif value == nil then
      value = 0 / 0
    elseif type(value) == "boolean" then
      value = value and 1 or 0
    elseif type(value) == "number" then
      -- keep as-is
    elseif type(value) == "string" then
      if value == "" or value:match("^%s*$") then
        value = 0
      elseif value == "Infinity" or value == "+Infinity" then
        value = math.huge
      elseif value == "-Infinity" then
        value = -math.huge
      else
        local n = tonumber(value)
        if n then
          value = n
        else
          value = 0 / 0
        end
      end
    else
      value = 0 / 0
    end
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
Number.prototype = _ljs_number_prototype
_ljs_number_prototype.constructor = Number
