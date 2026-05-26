-- Object.prototype methods + Object constructor. Populates the root
-- _ljs_object_prototype declared in proto.lua, then creates the Object
-- constructor (via _ljs_ctor) and wires up Object.create.
--
-- hasOwnProperty uses rawget to check own properties only (no prototype chain walk).
_ljs_object_prototype.hasOwnProperty = _ljs_fn(function(_ljs_this, key)
  return rawget(_ljs_this, key) ~= nil
end)
_ljs_object_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this
end)

local Object = _ljs_ctor(function(_ljs_this)
  return _ljs_this
end)
Object.prototype = _ljs_object_prototype
Object.prototype.constructor = Object
Object.create = _ljs_fn(_ljs_object_create)
