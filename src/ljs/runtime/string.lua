_ljs_string_prototype.toString = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)
_ljs_string_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)
local function _ljs_trunc(n)
  if n ~= n then return 0 end
  return n >= 0 and math.floor(n) or -math.floor(-n)
end

_ljs_string_prototype.charCodeAt = _ljs_fn(function(_ljs_this, index)
  local s = _ljs_this._ljs_data
  index = _ljs_trunc(index or 0)
  if index < 0 or index >= #s then
    return (0 / 0)
  end
  return s:byte(index + 1)
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
String.fromCharCode = _ljs_fn(function(_ljs_this, ...)
  local chars = {}
  for i = 1, select("#", ...) do
    local code = select(i, ...)
    if code ~= code then code = 0 end
    chars[#chars + 1] = string.char(_ljs_trunc(code) % 256)
  end
  return table.concat(chars)
end)
