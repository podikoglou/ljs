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
  local n = _ljs_to_number(x)
  if n ~= n then
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

local function _ljs_parse_exp(s)
  local m_str, e_sign, e_str = s:match("^([%d%.]+)e([+-])(%d+)$")
  if not m_str then
    return nil, nil
  end
  local exp = tonumber(e_str)
  if e_sign == "-" then
    exp = -exp
  end
  local int_part, frac_part = m_str:match("^(%d+)%.?(%d*)$")
  if not int_part then
    return nil, nil
  end
  local digits = int_part .. frac_part
  return digits, exp
end

local function _ljs_format_exp_str(abs_x, f)
  if abs_x == 0 then
    if f == 0 then
      return "0", 0
    end
    return "0" .. string.rep("0", f), 0
  end
  local fmt = "%." .. math.min(f, 99) .. "e"
  local raw = string.format(fmt, abs_x)
  local digits, exp = _ljs_parse_exp(raw)
  if not digits then
    return "0", 0
  end
  if f > 99 then
    digits = digits .. string.rep("0", f - 99)
  end
  return digits, exp
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
  local auto = fractionDigits == nil or fractionDigits == _ljs_undefined
  local f
  if auto then
    f = -1
  else
    f = _ljs_to_integer_or_infinity(fractionDigits)
  end
  if x ~= x then
    return "NaN"
  end
  if x == math.huge then
    return "Infinity"
  end
  if x == -math.huge then
    return "-Infinity"
  end
  if not auto and (f < 0 or f > 100) then
    error("RangeError: toExponential() argument must be between 0 and 100")
  end
  local sign = ""
  local abs_x = x
  if abs_x < 0 or (1 / abs_x) == -math.huge then
    sign = "-"
    abs_x = -abs_x
  end
  if auto then
    if abs_x == 0 then
      return "0e+0"
    end
    local raw = string.format("%.17e", abs_x)
    local all_digits, exp = _ljs_parse_exp(raw)
    local nd
    for i = 1, 17 do
      local last = tonumber(all_digits:sub(i, i))
      local next_d = tonumber(all_digits:sub(i + 1, i + 1)) or 0
      local d = all_digits:sub(1, i)
      local e = exp
      if next_d >= 5 then
        local carry = true
        local t = {}
        for j = i, 1, -1 do
          local c = tonumber(d:sub(j, j))
          if carry then
            c = c + 1
            if c >= 10 then
              c = 0
            else
              carry = false
            end
          end
          t[j] = tostring(c)
        end
        d = table.concat(t)
        if carry then
          d = "1" .. d:sub(2)
          e = e + 1
        end
      end
      local s = d:sub(1, 1) .. "." .. d:sub(2) .. "e" .. e
      if tonumber(s) == abs_x then
        all_digits = d
        exp = e
        break
      end
    end
    local digits = all_digits
    digits = digits:gsub("0+$", "")
    if #digits == 0 then
      digits = "0"
    end
    local mantissa_str = digits:sub(1, 1)
    local frac = digits:sub(2)
    if #frac > 0 then
      mantissa_str = mantissa_str .. "." .. frac
    end
    local exp_sign = exp >= 0 and "+" or "-"
    local exp_abs = math.abs(exp)
    return sign .. mantissa_str .. "e" .. exp_sign .. tostring(exp_abs)
  end
  if abs_x == 0 then
    if f == 0 then
      return "0e+0"
    end
    return "0." .. string.rep("0", f) .. "e+0"
  end
  local digits, exp = _ljs_format_exp_str(abs_x, f)
  local exp_sign = exp >= 0 and "+" or "-"
  local exp_abs = math.abs(exp)
  if f == 0 then
    return sign .. digits:sub(1, 1) .. "e" .. exp_sign .. tostring(exp_abs)
  end
  return sign .. digits:sub(1, 1) .. "." .. digits:sub(2) .. "e" .. exp_sign .. tostring(exp_abs)
end)

_ljs_number_prototype.toPrecision = _ljs_fn(function(_ljs_this, precision)
  local x = _ljs_this_number_value(_ljs_this)
  if precision == nil or precision == _ljs_undefined then
    return _ljs_tostring(x)
  end
  local p = _ljs_to_integer_or_infinity(precision)
  if x ~= x then
    return "NaN"
  end
  if x == math.huge then
    return "Infinity"
  end
  if x == -math.huge then
    return "-Infinity"
  end
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
      return "0"
    end
    return "0." .. string.rep("0", p - 1)
  end
  local digits, exp = _ljs_format_exp_str(abs_x, p - 1)
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

Number.isNaN = _ljs_fn(function(_ljs_this, number)
  if type(number) ~= "number" then
    return false
  end
  return number ~= number
end)

Number.isFinite = _ljs_fn(function(_ljs_this, number)
  if type(number) ~= "number" then
    return false
  end
  if number ~= number then
    return false
  end
  if number == math.huge or number == -math.huge then
    return false
  end
  return true
end)
