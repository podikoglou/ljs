-- Math object: mirrors JS Math API over Lua's math library.
-- All methods wrapped in _ljs_fn (no .prototype — Math is not a constructor).
-- Constants match JS values exactly.
local Math = _ljs_object({})

Math.PI = math.pi
Math.E = 2.718281828459045
Math.LN2 = 0.6931471805599453
Math.LN10 = 2.302585092994046
Math.LOG2E = 1.4426950408889634
Math.LOG10E = 0.4342944819032518
Math.SQRT2 = 1.4142135623730951
Math.SQRT1_2 = 0.7071067811865476

Math.abs = _ljs_fn(function(_ljs_this, x)
  return math.abs(x)
end)

Math.ceil = _ljs_fn(function(_ljs_this, x)
  return math.ceil(x)
end)

Math.floor = _ljs_fn(function(_ljs_this, x)
  return math.floor(x)
end)

-- round: floor(x + 0.5) matches JS Math.round behavior (rounds half-up).
Math.round = _ljs_fn(function(_ljs_this, x)
  return math.floor(x + 0.5)
end)

Math.trunc = _ljs_fn(function(_ljs_this, x)
  if x < 0 then
    return math.ceil(x)
  end
  return math.floor(x)
end)

Math.sign = _ljs_fn(function(_ljs_this, x)
  if x ~= x then
    return 0 / 0
  end
  if x == 0 then
    return x
  end
  if x > 0 then
    return 1
  end
  return -1
end)

Math.min = _ljs_fn(function(_ljs_this, ...)
  if select("#", ...) == 0 then
    return math.huge
  end
  return math.min(...)
end)

Math.max = _ljs_fn(function(_ljs_this, ...)
  if select("#", ...) == 0 then
    return -math.huge
  end
  return math.max(...)
end)

Math.random = _ljs_fn(function(_ljs_this)
  return math.random()
end)

Math.pow = _ljs_fn(function(_ljs_this, x, y)
  return x ^ y
end)

Math.sqrt = _ljs_fn(function(_ljs_this, x)
  return math.sqrt(x)
end)

Math.log = _ljs_fn(function(_ljs_this, x)
  return math.log(x)
end)

Math.exp = _ljs_fn(function(_ljs_this, x)
  return math.exp(x)
end)

Math.sin = _ljs_fn(function(_ljs_this, x)
  return math.sin(x)
end)

Math.cos = _ljs_fn(function(_ljs_this, x)
  return math.cos(x)
end)

Math.tan = _ljs_fn(function(_ljs_this, x)
  return math.tan(x)
end)

Math.asin = _ljs_fn(function(_ljs_this, x)
  return math.asin(x)
end)

Math.acos = _ljs_fn(function(_ljs_this, x)
  return math.acos(x)
end)

Math.atan = _ljs_fn(function(_ljs_this, x)
  return math.atan(x)
end)

Math.atan2 = _ljs_fn(function(_ljs_this, y, x)
  return math.atan(y, x)
end)
