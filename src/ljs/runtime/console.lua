local console = _ljs_object({})

local _ljs_internal_keys = { _ljs_raw = true, _ljs_data = true }

local function _ljs_inspect(x, depth, stack)
  depth = depth or 0
  stack = stack or {}

  if x == _ljs_null then return "null" end
  if _ljs_is_undef(x) then return "undefined" end
  if type(x) == "number" then return _ljs_tostring(x) end
  if type(x) == "string" then
    if depth > 0 then
      return "'" .. x .. "'"
    end
    return x
  end
  if type(x) == "boolean" then return tostring(x) end
  if type(x) ~= "table" then return tostring(x) end

  if stack[x] then return "[Circular]" end

  if rawget(x, "_ljs_raw") then
    local name = rawget(x, "name") or "(anonymous)"
    return "[Function: " .. name .. "]"
  end

  stack[x] = true

  if _ljs_instanceof(x, Array) then
    local len = x.length or 0
    local items = {}
    for i = 1, len do
      local v = rawget(x, i)
      items[i] = _ljs_inspect(v, depth + 1, stack)
    end
    stack[x] = nil
    if #items == 0 then return "[]" end
    return "[ " .. table.concat(items, ", ") .. " ]"
  end

  local parts = {}
  local k = nil
  while true do
    k = next(x, k)
    if k == nil then break end
    if type(k) == "string" and not _ljs_internal_keys[k] then
      local v = rawget(x, k)
      parts[#parts + 1] = k .. ": " .. _ljs_inspect(v, depth + 1, stack)
    end
  end
  stack[x] = nil
  if #parts == 0 then return "{}" end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function _console_write(handle, ...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do
    parts[i] = _ljs_inspect((select(i, ...)))
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
