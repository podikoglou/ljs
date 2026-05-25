-- Global value properties (ECMA-262 §19.1): NaN, Infinity.
-- Global function properties (ECMA-262 §19.2): isNaN, isFinite.
-- isNaN/isFinite coerce via _ljs_to_number (preamble helper, ECMA-262 §7.1.4).

local NaN = (0 / 0)
local Infinity = math.huge

-- isNaN(x): ToNumber then check NaN via self-inequality (ECMA-262 §19.2.3).
local isNaN = _ljs_fn(function(_ljs_this, x)
  x = _ljs_to_number(x)
  return x ~= x
end)

-- isFinite(x): ToNumber then reject NaN and ±Infinity (ECMA-262 §19.2.2).
local isFinite = _ljs_fn(function(_ljs_this, x)
  local n = _ljs_to_number(x)
  if n ~= n then
    return false
  end
  if n == math.huge or n == -math.huge then
    return false
  end
  return true
end)
