local console = _ljs_object({})

local function _console_write(handle, ...)
  local args = { ... }
  for i = 1, #args do
    args[i] = tostring(args[i])
  end
  handle:write(table.concat(args, "\t") .. "\n")
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
