_ljs_string_prototype.toString = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)
_ljs_string_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)

setmetatable(_ljs_string_prototype, { __index = _ljs_object_prototype })

_ljs_string_box_index = function(t, k)
  if k == "length" then
    return #(rawget(t, "_ljs_data") or "")
  end
  if type(k) == "number" then
    local s = rawget(t, "_ljs_data") or ""
    if k >= 1 and k <= #s and math.floor(k) == k then
      return s:sub(k, k)
    end
    return nil
  end
  return _ljs_string_prototype[k]
end

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
