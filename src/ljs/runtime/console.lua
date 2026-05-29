local console = _ljs_object({})

local function _console_write(handle, ...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do
    parts[i] = _ljs_tostring((select(i, ...)))
  end
  handle:write(table.concat(parts, " ") .. "\n")
end

console.log = _ljs_fn(function(_ljs_this, ...)
  _console_write(io.stdout, ...)
end)

console.error = _ljs_fn(function(_ljs_this, ...)
  _console_write(io.stderr, ...)
end)

console.warn = _ljs_fn(function(_ljs_this, ...)
  io.stderr:write("Warning: ")
  _console_write(io.stderr, ...)
end)

console.info = _ljs_fn(function(_ljs_this, ...)
  _console_write(io.stdout, ...)
end)
