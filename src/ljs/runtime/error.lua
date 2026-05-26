-- Error and built-in subclasses (TypeError, RangeError, SyntaxError, ReferenceError).
-- Each subclass gets its own prototype inheriting from Error.prototype via __index.
-- The constructor is built with _ljs_ctor(nil) then has .prototype replaced to point
-- at the subclass prototype (not the default _ljs_object_prototype).
local Error = _ljs_ctor(function(_ljs_this, message)
  _ljs_this.message = message
end)
Error.prototype.name = "Error"
Error.prototype.toString = _ljs_fn(function(_ljs_this)
  local name = _ljs_this.name
  if name == nil then name = "Error" end
  local msg = _ljs_this.message
  if msg == nil then msg = "" end
  if name == "" then return _ljs_tostring(msg) end
  if msg == "" then return _ljs_tostring(name) end
  return _ljs_tostring(name) .. ": " .. _ljs_tostring(msg)
end)

-- Factory for Error subclasses: creates a prototype chain off Error.prototype,
-- sets .name, and wires a _ljs_ctor-wrapped constructor with that prototype.
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
