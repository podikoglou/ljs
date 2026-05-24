-- Global value properties (ECMA-262 §19.1): NaN, Infinity.
-- Global function properties (ECMA-262 §19.2): isNaN, isFinite.
-- isNaN/isFinite coerce via ToNumber (ECMA-262 §7.1.4) per spec.
-- Lua's tonumber() differs from JS ToNumber on: '', null, true, false.
-- _ljs_toNumber bridges the gap.

local NaN = (0 / 0)
local Infinity = math.huge

-- ToNumber: mirrors JS Number() coercion (ECMA-262 §7.1.4).
-- nil → NaN, true → 1, false → 0, '' → 0, ' ' → 0, then tonumber().
local function _ljs_toNumber(x)
  if x == nil then
    return 0 / 0
  end
  local tx = type(x)
  if tx == "boolean" then
    return x and 1 or 0
  end
  if tx == "number" then
    return x
  end
  if tx == "string" then
    if x == "" or x:match("^%s*$") then
      return 0
    end
    local n = tonumber(x)
    if n then
      return n
    end
    return 0 / 0
  end
  return 0 / 0
end

-- isNaN(x): ToNumber then check NaN via self-inequality (ECMA-262 §19.2.3).
local isNaN = _ljs_fn(function(_ljs_this, x)
  x = _ljs_toNumber(x)
  return x ~= x
end)

-- isFinite(x): ToNumber then reject NaN and ±Infinity (ECMA-262 §19.2.2).
local isFinite = _ljs_fn(function(_ljs_this, x)
  local n = _ljs_toNumber(x)
  if n ~= n then
    return false
  end
  if n == math.huge or n == -math.huge then
    return false
  end
  return true
end)
