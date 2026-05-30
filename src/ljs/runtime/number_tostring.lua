local function _ljs_number_to_string(x)
  if x ~= x then
    return "NaN"
  end
  if x == 0 then
    return "0"
  end
  if x < 0 then
    return "-" .. _ljs_number_to_string(-x)
  end
  if x == math.huge then
    return "Infinity"
  end

  local function parse_exponential(str)
    local mant, e_str = str:match("^(.+)e(.+)$")
    local exp = tonumber(e_str)
    local digits = mant:gsub("%.", "")
    digits = digits:gsub("0+$", "")
    if #digits == 0 then
      digits = "0"
    end
    return digits, #digits, exp + 1
  end

  local s_digits, k, n
  for precision = 0, 20 do
    local fmt = "%." .. precision .. "e"
    local str = string.format(fmt, x)
    if tonumber(str) == x then
      s_digits, k, n = parse_exponential(str)
      break
    end
  end

  if not s_digits then
    s_digits, k, n = parse_exponential(string.format("%.20e", x))
  end

  if n >= -5 and n <= 21 then
    if n >= k then
      return s_digits .. string.rep("0", n - k)
    elseif n > 0 then
      return s_digits:sub(1, n) .. "." .. s_digits:sub(n + 1)
    else
      return "0." .. string.rep("0", -n) .. s_digits
    end
  end

  local exp_val = n - 1
  local exp_abs = tostring(math.abs(exp_val))
  local exp_sign
  if exp_val < 0 then
    exp_sign = "-" .. exp_abs
  else
    exp_sign = "+" .. exp_abs
  end

  if k == 1 then
    return s_digits .. "e" .. exp_sign
  else
    return s_digits:sub(1, 1) .. "." .. s_digits:sub(2) .. "e" .. exp_sign
  end
end
