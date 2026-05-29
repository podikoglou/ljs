local function _ljs_trunc(n)
  if n ~= n then
    return 0
  end
  if n == math.huge or n == -math.huge then
    return n
  end
  return n >= 0 and math.floor(n) or -math.floor(-n)
end

local function _ljs_this_number_value(_ljs_this)
  if type(_ljs_this) == "number" then
    return _ljs_this
  end
  if type(_ljs_this) == "table" and rawget(_ljs_this, "_ljs_data") ~= nil then
    return rawget(_ljs_this, "_ljs_data")
  end
  error("TypeError: this is not a Number")
end

local function _ljs_to_integer_or_infinity(x)
  if x == nil then
    return 0
  end
  local n = tonumber(x)
  if n == nil or n ~= n then
    return 0
  end
  if n == 0 then
    return 0
  end
  if n == math.huge or n == -math.huge then
    return n
  end
  return _ljs_trunc(n)
end

local function _ljs_log10(n)
  if n <= 0 then
    return -math.huge
  end
  return math.log(n) / math.log(10)
end

local function _ljs_format_fixed(val, n)
  if n <= 99 then
    return string.format("%." .. n .. "f", val)
  end
  local safe = string.format("%.50f", val)
  local int_part, frac_part = safe:match("^(-?%d+)%.(%d+)$")
  if not int_part then
    return safe
  end
  frac_part = frac_part .. string.rep("0", n - #frac_part)
  return int_part .. "." .. frac_part
end

_ljs_number_prototype.toString = _ljs_fn(function(_ljs_this)
  return _ljs_tostring(_ljs_this._ljs_data)
end)
_ljs_number_prototype.valueOf = _ljs_fn(function(_ljs_this)
  return _ljs_this._ljs_data
end)
_ljs_number_prototype.toLocaleString = _ljs_fn(function(_ljs_this)
  return _ljs_tostring(_ljs_this._ljs_data)
end)

_ljs_number_prototype.toExponential = _ljs_fn(function(_ljs_this, fractionDigits)
  local x = _ljs_this_number_value(_ljs_this)
  if fractionDigits == nil or fractionDigits == _ljs_undefined then
    local auto_frac
    if x ~= x then
      return "NaN"
    end
    if x == math.huge then
      return "Infinity"
    end
    if x == -math.huge then
      return "-Infinity"
    end
    local sign = ""
    local abs_x = x
    if abs_x < 0 or (1 / abs_x) == -math.huge then
      sign = "-"
      abs_x = -abs_x
    end
    if abs_x == 0 then
      return "0e+0"
    end
    local exp = math.floor(_ljs_log10(abs_x))
    local mantissa = abs_x / (10 ^ exp)
    if mantissa >= 10 then
      mantissa = mantissa / 10
      exp = exp + 1
    end
    if mantissa < 1 then
      mantissa = mantissa * 10
      exp = exp - 1
    end
    local mantissa_str = string.format("%.14g", mantissa)
    mantissa_str = mantissa_str:gsub("%.0$", "")
    local exp_sign = exp >= 0 and "+" or "-"
    local exp_abs = math.abs(exp)
    return sign .. mantissa_str .. "e" .. exp_sign .. tostring(exp_abs)
  end
  local f = _ljs_to_integer_or_infinity(fractionDigits)
  if x ~= x then
    return "NaN"
  end
  if x == math.huge then
    return "Infinity"
  end
  if x == -math.huge then
    return "-Infinity"
  end
  if f < 0 or f > 100 then
    error("RangeError: toExponential() argument must be between 0 and 100")
  end
  local sign = ""
  local abs_x = x
  if abs_x < 0 or (1 / abs_x) == -math.huge then
    sign = "-"
    abs_x = -abs_x
  end
  if abs_x == 0 then
    if f == 0 then
      return "0e+0"
    end
    return "0." .. string.rep("0", f) .. "e+0"
  end
  local exp = math.floor(_ljs_log10(abs_x))
  local mantissa = abs_x / (10 ^ exp)
  if mantissa >= 10 then
    mantissa = mantissa / 10
    exp = exp + 1
  end
  if mantissa < 1 then
    mantissa = mantissa * 10
    exp = exp - 1
  end
  local rounded = math.floor(mantissa * (10 ^ f) + 0.5) / (10 ^ f)
  if rounded >= 10 then
    rounded = rounded / 10
    exp = exp + 1
  end
  local mantissa_str
  if f == 0 then
    mantissa_str = string.format("%.0f", rounded)
  else
    mantissa_str = _ljs_format_fixed(rounded, f)
  end
  local exp_sign = exp >= 0 and "+" or "-"
  local exp_abs = math.abs(exp)
  return sign .. mantissa_str .. "e" .. exp_sign .. tostring(exp_abs)
end)

_ljs_number_prototype.toPrecision = _ljs_fn(function(_ljs_this, precision)
  local x = _ljs_this_number_value(_ljs_this)
  if precision == nil or precision == _ljs_undefined then
    return _ljs_tostring(x)
  end
  local p = _ljs_to_integer_or_infinity(precision)
  if x ~= x then return "NaN" end
  if x == math.huge then return "Infinity" end
  if x == -math.huge then return "-Infinity" end
  if p < 1 or p > 100 then
    error("RangeError: toPrecision() argument must be between 1 and 100")
  end
  local sign = ""
  local abs_x = x
  if abs_x < 0 or (1 / abs_x) == -math.huge then
    sign = "-"
    abs_x = -abs_x
  end
  if abs_x == 0 then
    if p == 1 then
      return sign .. "0"
    end
    return sign .. "0." .. string.rep("0", p - 1)
  end
  local exp = math.floor(_ljs_log10(abs_x))
  local mantissa = abs_x / (10 ^ exp)
  if mantissa >= 10 then
    mantissa = mantissa / 10
    exp = exp + 1
  end
  if mantissa < 1 then
    mantissa = mantissa * 10
    exp = exp - 1
  end
  local rounded = math.floor(mantissa * (10 ^ (p - 1)) + 0.5) / (10 ^ (p - 1))
  if rounded >= 10 then
    rounded = rounded / 10
    exp = exp + 1
  end
  local m
  if p <= 99 then
    m = string.format("%." .. (p - 1) .. "f", rounded)
  else
    m = _ljs_format_fixed(rounded, p - 1)
  end
  local digits = m:gsub("%.", "")
  if exp < -6 or exp >= p then
    local int_part = digits:sub(1, 1)
    local frac = digits:sub(2)
    local exp_sign = exp >= 0 and "+" or "-"
    local exp_abs = math.abs(exp)
    if p == 1 then
      return sign .. int_part .. "e" .. exp_sign .. tostring(exp_abs)
    end
    return sign .. int_part .. "." .. frac .. "e" .. exp_sign .. tostring(exp_abs)
  end
  if exp == p - 1 then
    return sign .. digits
  end
  if exp >= 0 then
    local int_part = digits:sub(1, exp + 1)
    local frac_part = digits:sub(exp + 2)
    return sign .. int_part .. "." .. frac_part
  end
  local zeros = string.rep("0", -(exp + 1))
  return sign .. "0." .. zeros .. digits
end)

setmetatable(_ljs_number_prototype, { __index = _ljs_object_prototype })

local Number = _ljs_fn(function(_ljs_this, ...)
  local value
  if select("#", ...) == 0 then
    value = 0
  else
    value = _ljs_to_number(...)
  end
  if _ljs_this == nil then
    return value
  end
  _ljs_this._ljs_data = value
  return _ljs_this
end)
Number.prototype = _ljs_number_prototype
_ljs_number_prototype.constructor = Number
