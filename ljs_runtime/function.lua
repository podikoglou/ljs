_ljs_function_prototype.call = function(_ljs_this, thisArg, ...)
  return _ljs_this(thisArg, ...)
end
_ljs_function_prototype.apply = function(_ljs_this, thisArg, args)
  if args == nil then
    return _ljs_this(thisArg)
  end
  local _unpack = unpack or table.unpack
  return _ljs_this(thisArg, _unpack(args, 1, args.length))
end
setmetatable(_ljs_function_prototype, { __index = _ljs_object_prototype })

local Function = _ljs_ctor(nil)
Function.prototype = _ljs_function_prototype
