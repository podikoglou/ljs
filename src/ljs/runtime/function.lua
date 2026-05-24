-- Function.prototype: call, apply, toString. Wires _ljs_function_prototype into
-- the Object.prototype chain via __index so functions inherit Object methods too.
-- Function constructor is _ljs_ctor(nil) — no user-defined body.
_ljs_function_prototype.call = _ljs_fn(function(_ljs_this, thisArg, ...)
  return _ljs_this(thisArg, ...)
end)
-- apply: uses args.length (not #args) because ljs arrays store length explicitly.
-- Falls back to no-args if args is nil.
_ljs_function_prototype.apply = _ljs_fn(function(_ljs_this, thisArg, args)
  if args == nil then
    return _ljs_this(thisArg)
  end
  local _unpack = unpack or table.unpack
  return _ljs_this(thisArg, _unpack(args, 1, args.length))
end)
-- toString: returns native-code representation matching Node.js behavior for
-- built-in functions. All ljs functions are Lua-native, so source text is
-- unavailable.
_ljs_function_prototype.toString = _ljs_fn(function(_ljs_this)
  return "function () { [native code] }"
end)
setmetatable(_ljs_function_prototype, { __index = _ljs_object_prototype })

local Function = _ljs_ctor(nil)
Function.prototype = _ljs_function_prototype
