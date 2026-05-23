local function _ljs_json_wrap(val)
  if type(val) ~= "table" then
    return val
  end
  if rawget(val, "_ljs_arr") then
    rawset(val, "_ljs_arr", nil)
    local n = 0
    for i, v in ipairs(val) do
      val[i] = _ljs_json_wrap(v)
      n = n + 1
    end
    val.length = n
    return val
  end
  local result = _ljs_object({})
  for k, v in pairs(val) do
    result[k] = _ljs_json_wrap(v)
  end
  return result
end

local JSON = _ljs_object({})

JSON.parse = _ljs_fn(function(_ljs_this, text)
  return _ljs_json_wrap(json.decode(text))
end)

local function _ljs_is_fn(val)
  if type(val) ~= "table" then
    return false
  end
  local mt = getmetatable(val)
  return mt and mt.__call ~= nil
end

local function _ljs_json_stringify(val, stack)
  stack = stack or {}
  if val == nil then
    return "null"
  end
  if type(val) == "boolean" then
    return tostring(val)
  end
  if type(val) == "number" then
    if val ~= val or val <= -math.huge or val >= math.huge then
      return "null"
    end
    return string.format("%.14g", val)
  end
  if type(val) == "string" then
    return json.encode(val)
  end
  if type(val) == "table" then
    if _ljs_is_fn(val) then
      return nil
    end
    if stack[val] then
      error("circular reference")
    end
    stack[val] = true
    local len = rawget(val, "length")
    if len and type(len) == "number" then
      local items = {}
      for i = 1, len do
        local s = _ljs_json_stringify(rawget(val, i), stack)
        items[i] = s or "null"
      end
      stack[val] = nil
      return "[" .. table.concat(items, ",") .. "]"
    end
    local parts = {}
    for k, v in pairs(val) do
      if type(k) == "string" then
        local s = _ljs_json_stringify(v, stack)
        if s ~= nil then
          parts[#parts + 1] = json.encode(k) .. ":" .. s
        end
      end
    end
    stack[val] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return nil
end

JSON.stringify = _ljs_fn(function(_ljs_this, value)
  return _ljs_json_stringify(value)
end)
