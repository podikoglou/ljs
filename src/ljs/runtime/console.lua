-- console object with log method. Plain _ljs_object (not _ljs_ctor) — console
-- is not callable and has no .prototype. console.log delegates to Lua's print().
local console = _ljs_object({})
console.log = _ljs_fn(function(_ljs_this, ...)
  print(...)
end)
