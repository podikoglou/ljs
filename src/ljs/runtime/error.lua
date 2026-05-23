local Error = _ljs_ctor(function(_ljs_this, message)
  _ljs_this.message = message
end)
Error.prototype.name = "Error"
Error.prototype.toString = function(_ljs_this)
  if _ljs_this.message ~= nil then
    return _ljs_this.name .. ": " .. tostring(_ljs_this.message)
  end
  return _ljs_this.name
end

local function _ljs_error_subclass(name)
  local prototype = setmetatable({}, { __index = Error.prototype })
  prototype.name = name
  prototype.constructor = nil
  local Ctor = _ljs_ctor(function(_ljs_this, message)
    _ljs_this.message = message
  end)
  Ctor.prototype = prototype
  return Ctor
end

local TypeError = _ljs_error_subclass("TypeError")
local RangeError = _ljs_error_subclass("RangeError")
local SyntaxError = _ljs_error_subclass("SyntaxError")
local ReferenceError = _ljs_error_subclass("ReferenceError")
