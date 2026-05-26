_ljs_object_prototype.toString = _ljs_fn(function(_ljs_this)
  if _ljs_this == nil then return "[object Undefined]" end
  if _ljs_this == _ljs_null then return "[object Null]" end
  local t = type(_ljs_this)
  if t == "number" then return "[object Number]" end
  if t == "string" then return "[object String]" end
  if t == "boolean" then return "[object Boolean]" end
  if t == "table" then
    if _ljs_instanceof(_ljs_this, Array) then return "[object Array]" end
    local mt = getmetatable(_ljs_this)
    if mt and mt.__call then return "[object Function]" end
    if _ljs_instanceof(_ljs_this, Error) then return "[object Error]" end
    if mt and mt.__index == _ljs_boolean_prototype then return "[object Boolean]" end
    if mt and mt.__index == _ljs_number_prototype then return "[object Number]" end
    if mt and mt.__index == _ljs_string_prototype then return "[object String]" end
  end
  return "[object Object]"
end)
