-- Global value properties (ECMA-262 §19.1): NaN, Infinity.
-- Global function properties (ECMA-262 §19.2): isNaN, isFinite, parseInt, parseFloat.
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

-- parseInt(string, radix): ECMA-262 §19.2.5.
local parseInt = _ljs_fn(function(_ljs_this, string, radix)
  local s = _ljs_tostring(string)
  s = s:match("^%s*(.-)$")
  if s == "" then
    return 0 / 0
  end
  local sign = 1
  if s:sub(1, 1) == "-" then
    sign = -1
    s = s:sub(2)
  elseif s:sub(1, 1) == "+" then
    s = s:sub(2)
  end
  if s == "" then
    return 0 / 0
  end

  local r = 0
  if radix ~= nil then
    r = _ljs_to_int32(radix)
    if r ~= r then
      r = 0
    end
  end

  local strip_prefix = true
  if r ~= 0 then
    if r < 2 or r > 36 then
      return 0 / 0
    end
    if r ~= 16 then
      strip_prefix = false
    end
  else
    r = 10
  end

  if strip_prefix and #s >= 2 and (s:sub(1, 2) == "0x" or s:sub(1, 2) == "0X") then
    s = s:sub(3)
    r = 16
  end

  if s == "" then
    return 0 / 0
  end

  local function digit_value(c)
    if c >= "0" and c <= "9" then
      return c:byte() - 48
    end
    if c >= "a" and c <= "z" then
      return c:byte() - 87
    end
    if c >= "A" and c <= "Z" then
      return c:byte() - 55
    end
    return -1
  end

  local result = 0
  local found = false
  for i = 1, #s do
    local d = digit_value(s:sub(i, i))
    if d < 0 or d >= r then
      break
    end
    result = result * r + d
    found = true
  end

  if not found then
    return 0 / 0
  end
  return sign * result
end)

Number.parseInt = parseInt

-- parseFloat(string): ECMA-262 §19.2.4.
local parseFloat = _ljs_fn(function(_ljs_this, string)
  local s = _ljs_tostring(string)
  s = s:match("^%s*(.-)$")
  if s == "" then
    return 0 / 0
  end

  local sign = ""
  if s:sub(1, 1) == "+" or s:sub(1, 1) == "-" then
    sign = s:sub(1, 1)
    s = s:sub(2)
  end

  if s:sub(1, 1) == "I" and s:sub(1, #"Infinity") == "Infinity" then
    if sign == "-" then
      return -math.huge
    end
    return math.huge
  end

  local matched = s:match("^%d+%.%d*[eE][+-]?%d+")
    or s:match("^%d+%.%d*")
    or s:match("^%d+[eE][+-]?%d+")
    or s:match("^%d+")
    or s:match("^%.%d+[eE][+-]?%d+")
    or s:match("^%.%d+")
    or s:match("^[eE][+-]?%d+")

  if not matched then
    return 0 / 0
  end
  local n = tonumber(sign .. matched)
  if n == nil then
    return 0 / 0
  end
  return n
end)

Number.parseFloat = parseFloat
