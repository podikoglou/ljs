_ljs_object_prototype.toString = function(_ljs_this)
  return "[object Object]"
end
_ljs_object_prototype.hasOwnProperty = function(_ljs_this, key)
  return rawget(_ljs_this, key) ~= nil
end
_ljs_object_prototype.valueOf = function(_ljs_this)
  return _ljs_this
end

local Object = _ljs_ctor(function(_ljs_this)
  return _ljs_this
end)
Object.prototype = _ljs_object_prototype
Object.prototype.constructor = Object
Object.create = _ljs_object_create
