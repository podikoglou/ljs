local console = _ljs_object({})

local _ljs_internal_keys = { _ljs_raw = true, _ljs_data = true }

local function _ljs_escape_string(s)
  local has_single = s:find("'") ~= nil
  local has_double = s:find('"') ~= nil
  local escaped = s:gsub("\\", "\\\\")
    :gsub("\b", "\\b")
    :gsub("\f", "\\f")
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
  for i = 0, 0x1F do
    if i ~= 8 and i ~= 9 and i ~= 10 and i ~= 12 and i ~= 13 then
      local ch = string.char(i)
      local hex = string.format("\\x%02X", i)
      escaped = escaped:gsub(ch, hex)
    end
  end
  if has_single and has_double then
    escaped = escaped:gsub("`", "\\`")
    return "`" .. escaped .. "`"
  elseif has_single then
    return '"' .. escaped .. '"'
  else
    return "'" .. escaped .. "'"
  end
end

local function _ljs_is_identifier(k)
  return k:match("^[A-Za-z_$][A-Za-z0-9_$]*$") ~= nil
end

local function _ljs_format_key(k)
  if type(k) == "number" then
    return "'" .. tostring(k - 1) .. "'"
  end
  if _ljs_is_identifier(k) then
    return k
  end
  return _ljs_escape_string(k)
end

local function _ljs_inspect(x, depth, ctx)
  depth = depth or 0
  ctx = ctx or { refs = {}, path = {}, counter = 0 }

  if x == _ljs_null then
    return "null"
  end
  if _ljs_is_undef(x) then
    return "undefined"
  end
  if type(x) == "number" then
    if x == 0 and 1 / x < 0 then
      return "-0"
    end
    return _ljs_tostring(x)
  end
  if type(x) == "string" then
    if depth > 0 then
      return _ljs_escape_string(x)
    end
    return x
  end
  if type(x) == "boolean" then
    return tostring(x)
  end
  if type(x) ~= "table" then
    return tostring(x)
  end

  if rawget(x, "_ljs_raw") then
    local name = x.name
    if name and name ~= "" then
      return "[Function: " .. name .. "]"
    end
    return "[Function (anonymous)]"
  end

  local existing_ref = ctx.refs[x]
  if existing_ref then
    ctx.has_circular = true
    return "[Circular *" .. existing_ref .. "]"
  end

  ctx.counter = ctx.counter + 1
  local my_ref = ctx.counter
  ctx.refs[x] = my_ref
  ctx.path[x] = true

  if _ljs_instanceof(x, Error) then
    ctx.path[x] = nil
    return _ljs_tostring(x)
  end

  if _ljs_instanceof(x, Array) then
    local len = x.length or 0
    local items = {}
    local i = 1
    while i <= len do
      if rawget(x, i) == nil then
        local hole_start = i
        repeat
          i = i + 1
        until i > len or rawget(x, i) ~= nil
        local count = i - hole_start
        if count == 1 then
          items[#items + 1] = "<1 empty item>"
        else
          items[#items + 1] = "<" .. count .. " empty items>"
        end
      else
        items[#items + 1] = _ljs_inspect(rawget(x, i), depth + 1, ctx)
        i = i + 1
      end
    end
    ctx.path[x] = nil
    if #items == 0 then
      return "[]"
    end
    return "[ " .. table.concat(items, ", ") .. " ]"
  end

  local string_keys = {}
  local num_keys = {}
  local k = nil
  while true do
    k = next(x, k)
    if k == nil then
      break
    end
    if type(k) == "string" and not _ljs_internal_keys[k] then
      string_keys[#string_keys + 1] = k
    elseif type(k) == "number" then
      num_keys[#num_keys + 1] = k
    end
  end
  table.sort(num_keys, function(a, b)
    return a < b
  end)
  table.sort(string_keys)
  local parts = {}
  for _, k in ipairs(num_keys) do
    parts[#parts + 1] = _ljs_format_key(k) .. ": " .. _ljs_inspect(rawget(x, k), depth + 1, ctx)
  end
  for _, k in ipairs(string_keys) do
    parts[#parts + 1] = _ljs_format_key(k) .. ": " .. _ljs_inspect(rawget(x, k), depth + 1, ctx)
  end
  ctx.path[x] = nil
  if #parts == 0 then
    return "{}"
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function _console_write(handle, ...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do
    local x = select(i, ...)
    local ctx = { refs = {}, path = {}, counter = 0 }
    ctx.has_circular = false
    local s = _ljs_inspect(x, 0, ctx)
    if type(x) == "table" then
      if ctx.has_circular and ctx.refs[x] then
        s = "<ref *" .. ctx.refs[x] .. "> " .. s
      end
    end
    parts[i] = s
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
  _console_write(io.stderr, ...)
end)

console.info = _ljs_fn(function(_ljs_this, ...)
  _console_write(io.stdout, ...)
end)
