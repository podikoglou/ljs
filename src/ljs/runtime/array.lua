local Array = _ljs_ctor(function(_ljs_this, ...)
  local n = select("#", ...)
  for i = 1, n do
    _ljs_this[i] = select(i, ...)
  end
  _ljs_this.length = n
end)
Array.prototype.push = function(_ljs_this, ...)
  local n = select("#", ...)
  for i = 1, n do
    _ljs_this[_ljs_this.length + i] = select(i, ...)
  end
  _ljs_this.length = _ljs_this.length + n
  return _ljs_this.length
end
Array.prototype.pop = function(_ljs_this)
  if _ljs_this.length == 0 then
    return nil
  end
  local val = _ljs_this[_ljs_this.length]
  _ljs_this[_ljs_this.length] = nil
  _ljs_this.length = _ljs_this.length - 1
  return val
end
