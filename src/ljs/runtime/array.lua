-- Array constructor + prototype methods + static methods.
-- Array constructor stores elements at 1-based indices and sets .length.
-- All methods follow the JS-ABI convention: first param is _ljs_this.

local function _ljs_arr_newindex(t, k, v)
  rawset(t, k, v)
  if type(k) == "number" and k == math.floor(k) and k > 0 then
    local len = rawget(t, "length")
    if len ~= nil and k > len then
      rawset(t, "length", k)
    end
  end
end

local Array = _ljs_ctor(function(_ljs_this, ...)
  local mt = getmetatable(_ljs_this)
  mt.__newindex = _ljs_arr_newindex
  local n = select("#", ...)
  for i = 1, n do
    rawset(_ljs_this, i, select(i, ...))
  end
  rawset(_ljs_this, "length", n)
end)
-- push supports multiple arguments (matching JS Array.prototype.push semantics).
Array.prototype.push = _ljs_fn(function(_ljs_this, ...)
  local n = select("#", ...)
  local len = _ljs_this.length
  for i = 1, n do
    rawset(_ljs_this, len + i, select(i, ...))
  end
  rawset(_ljs_this, "length", len + n)
  return len + n
end)
Array.prototype.pop = _ljs_fn(function(_ljs_this)
  if _ljs_this.length == 0 then
    return nil
  end
  local val = _ljs_this[_ljs_this.length]
  rawset(_ljs_this, _ljs_this.length, nil)
  rawset(_ljs_this, "length", _ljs_this.length - 1)
  return val
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.map
-- ---------------------------------------------------------------------------
Array.prototype.map = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local result = _ljs_new(Array)
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local mapped = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      rawset(result, i, mapped)
    end
  end
  rawset(result, "length", len)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.forEach
-- ---------------------------------------------------------------------------
Array.prototype.forEach = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
    end
  end
  return nil
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.filter
-- ---------------------------------------------------------------------------
Array.prototype.filter = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local result = _ljs_new(Array)
  local to = 1
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local selected = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      if _ljs_to_boolean(selected) then
        rawset(result, to, v)
        to = to + 1
      end
    end
  end
  rawset(result, "length", to - 1)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.reduce
-- ---------------------------------------------------------------------------
Array.prototype.reduce = _ljs_fn(function(_ljs_this, callbackFn, initialValue)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local accumulator
  local k = 1
  if initialValue ~= nil then
    accumulator = initialValue
  else
    if len == 0 then
      error("TypeError: Reduce of empty array with no initial value")
    end
    local found = false
    while k <= len do
      local v = rawget(_ljs_this, k)
      if v ~= nil then
        accumulator = v
        found = true
        k = k + 1
        break
      end
      k = k + 1
    end
    if not found then
      error("TypeError: Reduce of empty array with no initial value")
    end
  end
  while k <= len do
    local v = rawget(_ljs_this, k)
    if v ~= nil then
      accumulator = _ljs_call_member(callbackFn, "call", nil, accumulator, v, k - 1, _ljs_this)
    end
    k = k + 1
  end
  return accumulator
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.reduceRight
-- ---------------------------------------------------------------------------
Array.prototype.reduceRight = _ljs_fn(function(_ljs_this, callbackFn, initialValue)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local accumulator
  local k = len
  if initialValue ~= nil then
    accumulator = initialValue
  else
    if len == 0 then
      error("TypeError: Reduce of empty array with no initial value")
    end
    local found = false
    while k >= 1 do
      local v = rawget(_ljs_this, k)
      if v ~= nil then
        accumulator = v
        found = true
        k = k - 1
        break
      end
      k = k - 1
    end
    if not found then
      error("TypeError: Reduce of empty array with no initial value")
    end
  end
  while k >= 1 do
    local v = rawget(_ljs_this, k)
    if v ~= nil then
      accumulator = _ljs_call_member(callbackFn, "call", nil, accumulator, v, k - 1, _ljs_this)
    end
    k = k - 1
  end
  return accumulator
end)

-- ---------------------------------------------------------------------------
-- Array Iterator Helper
-- ---------------------------------------------------------------------------
local function _ljs_array_iterator_next(_ljs_this)
  local arr = rawget(_ljs_this, "_iter_array")
  if arr == nil then
    return { value = nil, done = true }
  end
  local idx = rawget(_ljs_this, "_iter_index")
  local len = arr.length or 0
  if idx >= len then
    rawset(_ljs_this, "_iter_array", nil)
    return { value = nil, done = true }
  end
  rawset(_ljs_this, "_iter_index", idx + 1)
  local kind = rawget(_ljs_this, "_iter_kind")
  if kind == "key" then
    return { value = idx, done = false }
  elseif kind == "value" then
    return { value = rawget(arr, idx + 1), done = false }
  else
    local pair = _ljs_new(Array)
    rawset(pair, 1, idx)
    rawset(pair, 2, rawget(arr, idx + 1))
    rawset(pair, "length", 2)
    return { value = pair, done = false }
  end
end

local function _ljs_create_array_iterator(arr, kind)
  local it = {}
  rawset(it, "_iter_array", arr)
  rawset(it, "_iter_index", 0)
  rawset(it, "_iter_kind", kind)
  rawset(it, "next", _ljs_fn(function()
    return _ljs_array_iterator_next(it)
  end))
  return it
end

-- ---------------------------------------------------------------------------
-- Array.prototype.keys
-- ---------------------------------------------------------------------------
Array.prototype.keys = _ljs_fn(function(_ljs_this)
  return _ljs_create_array_iterator(_ljs_this, "key")
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.values
-- ---------------------------------------------------------------------------
Array.prototype.values = _ljs_fn(function(_ljs_this)
  return _ljs_create_array_iterator(_ljs_this, "value")
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.entries
-- ---------------------------------------------------------------------------
Array.prototype.entries = _ljs_fn(function(_ljs_this)
  return _ljs_create_array_iterator(_ljs_this, "key+value")
end)

-- ---------------------------------------------------------------------------
-- FlattenIntoArray (shared by flat and flatMap)
-- ---------------------------------------------------------------------------
local function flatten_into_array(target, source, source_len, start, depth, mapper, thisArg)
  local target_idx = start
  for i = 1, source_len do
    local v = rawget(source, i)
    if v ~= nil then
      if mapper ~= nil then
        v = _ljs_call_member(mapper, "call", thisArg, v, i - 1, source)
      end
      if depth > 0 and _ljs_instanceof(v, Array) then
        local sub_len = v.length or 0
        target_idx = flatten_into_array(target, v, sub_len, target_idx, depth - 1, nil, nil)
      else
        rawset(target, target_idx, v)
        target_idx = target_idx + 1
      end
    end
  end
  return target_idx
end

-- ---------------------------------------------------------------------------
-- Array.prototype.flat
-- ---------------------------------------------------------------------------
Array.prototype.flat = _ljs_fn(function(_ljs_this, depth_val)
  local len = _ljs_this.length or 0
  local depth
  if depth_val == nil then
    depth = 1
  else
    local n = tonumber(depth_val)
    if n == nil or n ~= n then
      depth = 0
    elseif n == math.huge then
      depth = math.huge
    elseif n == -math.huge then
      depth = 0
    else
      depth = math.floor(n)
      if depth < 0 then depth = 0 end
    end
  end
  local result = _ljs_new(Array)
  local final_idx = flatten_into_array(result, _ljs_this, len, 1, depth, nil, nil)
  rawset(result, "length", final_idx - 1)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.flatMap
-- ---------------------------------------------------------------------------
Array.prototype.flatMap = _ljs_fn(function(_ljs_this, mapperFunction, thisArg)
  if not _ljs_is_function(mapperFunction) then
    error("TypeError: " .. _ljs_value_repr(mapperFunction) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local result = _ljs_new(Array)
  local final_idx = flatten_into_array(result, _ljs_this, len, 1, 1, mapperFunction, thisArg)
  rawset(result, "length", final_idx - 1)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.some
-- ---------------------------------------------------------------------------
Array.prototype.some = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local testResult = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      if _ljs_to_boolean(testResult) then
        return true
      end
    end
  end
  return false
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.every
-- ---------------------------------------------------------------------------
Array.prototype.every = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      local testResult = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
      if not _ljs_to_boolean(testResult) then
        return false
      end
    end
  end
  return true
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.slice
-- ---------------------------------------------------------------------------
Array.prototype.slice = _ljs_fn(function(_ljs_this, start_val, end_val)
  local len = _ljs_this.length or 0
  local function to_int(v)
    if v == nil then return 0 end
    local n = tonumber(v)
    if n == nil or n ~= n then return 0 end
    return math.floor(n)
  end

  local relative_start = to_int(start_val)
  local k
  if relative_start < 0 then
    k = math.max(len + relative_start, 0)
  else
    k = math.min(relative_start, len)
  end

  local relative_end
  if end_val == nil then
    relative_end = len
  else
    relative_end = to_int(end_val)
  end
  local final_
  if relative_end < 0 then
    final_ = math.max(len + relative_end, 0)
  else
    final_ = math.min(relative_end, len)
  end

  local result = _ljs_new(Array)
  local ri = 1
  for i = k + 1, final_ do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      rawset(result, ri, v)
    end
    ri = ri + 1
  end
  rawset(result, "length", math.max(final_ - k, 0))
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.concat
-- ---------------------------------------------------------------------------
Array.prototype.concat = _ljs_fn(function(_ljs_this, ...)
  local result = _ljs_new(Array)
  local next_idx = 1

  local function append_item(item)
    if _ljs_instanceof(item, Array) then
      local item_len = item.length or 0
      for i = 1, item_len do
        local v = rawget(item, i)
        if v ~= nil then
          rawset(result, next_idx, v)
        end
        next_idx = next_idx + 1
      end
    else
      rawset(result, next_idx, item)
      next_idx = next_idx + 1
    end
  end

  append_item(_ljs_this)

  local n = select("#", ...)
  for i = 1, n do
    append_item(select(i, ...))
  end

  rawset(result, "length", next_idx - 1)
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.at
-- ---------------------------------------------------------------------------
Array.prototype.at = _ljs_fn(function(_ljs_this, index_val)
  local len = _ljs_this.length or 0
  local relative_index
  if index_val == nil then
    relative_index = 0
  else
    local n = tonumber(index_val)
    if n == nil or n ~= n then
      relative_index = 0
    elseif n == math.huge or n == -math.huge then
      relative_index = n
    else
      relative_index = n >= 0 and math.floor(n) or math.ceil(n)
    end
  end
  local k
  if relative_index >= 0 then
    k = relative_index
  else
    k = len + relative_index
  end
  if k < 0 or k >= len then
    return nil
  end
  return rawget(_ljs_this, k + 1)
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.indexOf
-- ---------------------------------------------------------------------------
Array.prototype.indexOf = _ljs_fn(function(_ljs_this, searchElement, fromIndex)
  local len = _ljs_this.length or 0
  if len == 0 then return -1 end
  local n
  if fromIndex == nil then
    n = 0
  else
    local num = tonumber(fromIndex)
    if num == nil or num ~= num then
      n = 0
    elseif num == math.huge then
      return -1
    elseif num == -math.huge then
      n = 0
    else
      n = num >= 0 and math.floor(num) or math.ceil(num)
    end
  end
  local k
  if n >= 0 then
    k = n
  else
    k = len + n
  end
  if k < 0 then k = 0 end
  for i = k + 1, len do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      if v == searchElement then return i - 1 end
    end
  end
  return -1
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.lastIndexOf
-- ---------------------------------------------------------------------------
Array.prototype.lastIndexOf = _ljs_fn(function(_ljs_this, searchElement, fromIndex)
  local len = _ljs_this.length or 0
  if len == 0 then return -1 end
  local n
  if fromIndex == nil then
    n = len - 1
  else
    local num = tonumber(fromIndex)
    if num == nil or num ~= num then
      n = 0
    elseif num == -math.huge then
      return -1
    elseif num == math.huge then
      n = len - 1
    else
      n = num >= 0 and math.floor(num) or math.ceil(num)
    end
  end
  local k
  if n >= 0 then
    k = math.min(n, len - 1)
  else
    k = len + n
  end
  for i = k + 1, 1, -1 do
    local v = rawget(_ljs_this, i)
    if v ~= nil then
      if v == searchElement then return i - 1 end
    end
  end
  return -1
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.includes
-- ---------------------------------------------------------------------------
local function _ljs_same_value_zero(x, y)
  if type(x) == "number" and type(y) == "number" then
    if x ~= x and y ~= y then return true end
    return x == y
  end
  return x == y
end

Array.prototype.includes = _ljs_fn(function(_ljs_this, searchElement, fromIndex)
  local len = _ljs_this.length or 0
  if len == 0 then return false end
  local n
  if fromIndex == nil then
    n = 0
  else
    local num = tonumber(fromIndex)
    if num == nil or num ~= num then
      n = 0
    elseif num == math.huge then
      return false
    elseif num == -math.huge then
      n = 0
    else
      n = num >= 0 and math.floor(num) or math.ceil(num)
    end
  end
  local k
  if n >= 0 then
    k = n
  else
    k = len + n
  end
  if k < 0 then k = 0 end
  for i = k + 1, len do
    local v = rawget(_ljs_this, i)
    if _ljs_same_value_zero(searchElement, v) then return true end
  end
  return false
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.find
-- ---------------------------------------------------------------------------
Array.prototype.find = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    local testResult = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
    if _ljs_to_boolean(testResult) then return v end
  end
  return nil
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.findIndex
-- ---------------------------------------------------------------------------
Array.prototype.findIndex = _ljs_fn(function(_ljs_this, callbackFn, thisArg)
  if not _ljs_is_function(callbackFn) then
    error("TypeError: " .. _ljs_value_repr(callbackFn) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  for i = 1, len do
    local v = rawget(_ljs_this, i)
    local testResult = _ljs_call_member(callbackFn, "call", thisArg, v, i - 1, _ljs_this)
    if _ljs_to_boolean(testResult) then return i - 1 end
  end
  return -1
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.reverse
-- ---------------------------------------------------------------------------
Array.prototype.reverse = _ljs_fn(function(_ljs_this)
  local len = _ljs_this.length or 0
  local middle = math.floor(len / 2)
  local lower = 0
  while lower ~= middle do
    local upper = len - lower - 1
    local lower_lua = lower + 1
    local upper_lua = upper + 1
    local lower_exists = rawget(_ljs_this, lower_lua) ~= nil
    local upper_exists = rawget(_ljs_this, upper_lua) ~= nil
    if lower_exists and upper_exists then
      local lv = rawget(_ljs_this, lower_lua)
      local uv = rawget(_ljs_this, upper_lua)
      rawset(_ljs_this, lower_lua, uv)
      rawset(_ljs_this, upper_lua, lv)
    elseif not lower_exists and upper_exists then
      local uv = rawget(_ljs_this, upper_lua)
      rawset(_ljs_this, lower_lua, uv)
      rawset(_ljs_this, upper_lua, nil)
    elseif lower_exists and not upper_exists then
      local lv = rawget(_ljs_this, lower_lua)
      rawset(_ljs_this, upper_lua, lv)
      rawset(_ljs_this, lower_lua, nil)
    end
    lower = lower + 1
  end
  return _ljs_this
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.fill
-- ---------------------------------------------------------------------------
local function _to_integer_or_inf(v, default)
  if v == nil then return default or 0 end
  local n = tonumber(v)
  if n == nil or n ~= n then return 0 end
  if n == math.huge then return math.huge end
  if n == -math.huge then return -math.huge end
  return (n >= 0 and math.floor or math.ceil)(n)
end

Array.prototype.fill = _ljs_fn(function(_ljs_this, value, start_val, end_val)
  local len = _ljs_this.length or 0
  local relative_start = _to_integer_or_inf(start_val)
  local k
  if relative_start == -math.huge then
    k = 0
  elseif relative_start < 0 then
    k = math.max(len + relative_start, 0)
  else
    k = math.min(relative_start, len)
  end
  local relative_end
  if end_val == nil then
    relative_end = len
  else
    relative_end = _to_integer_or_inf(end_val)
  end
  local final_
  if relative_end == -math.huge then
    final_ = 0
  elseif relative_end < 0 then
    final_ = math.max(len + relative_end, 0)
  else
    final_ = math.min(relative_end, len)
  end
  for i = k + 1, final_ do
    rawset(_ljs_this, i, value)
  end
  return _ljs_this
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.shift
-- ---------------------------------------------------------------------------
Array.prototype.shift = _ljs_fn(function(_ljs_this)
  local len = _ljs_this.length or 0
  if len == 0 then
    rawset(_ljs_this, "length", 0)
    return nil
  end
  local first = rawget(_ljs_this, 1)
  for k = 2, len do
    local v = rawget(_ljs_this, k)
    if v ~= nil then
      rawset(_ljs_this, k - 1, v)
    else
      rawset(_ljs_this, k - 1, nil)
    end
  end
  rawset(_ljs_this, len, nil)
  rawset(_ljs_this, "length", len - 1)
  return first
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.unshift
-- ---------------------------------------------------------------------------
Array.prototype.unshift = _ljs_fn(function(_ljs_this, ...)
  local len = _ljs_this.length or 0
  local arg_count = select("#", ...)
  if arg_count > 0 then
    for k = len, 1, -1 do
      local v = rawget(_ljs_this, k)
      if v ~= nil then
        rawset(_ljs_this, k + arg_count, v)
      else
        rawset(_ljs_this, k + arg_count, nil)
      end
    end
    for j = 1, arg_count do
      rawset(_ljs_this, j, select(j, ...))
    end
  end
  rawset(_ljs_this, "length", len + arg_count)
  return len + arg_count
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.splice
-- ---------------------------------------------------------------------------
Array.prototype.splice = _ljs_fn(function(_ljs_this, start, deleteCount, ...)
  local len = _ljs_this.length or 0
  local relative_start = _to_integer_or_inf(start)
  local actual_start
  if relative_start == -math.huge then
    actual_start = 0
  elseif relative_start < 0 then
    actual_start = math.max(len + relative_start, 0)
  else
    actual_start = math.min(relative_start, len)
  end
  local item_count = select("#", ...)
  local actual_delete_count
  if start == nil then
    actual_delete_count = 0
  elseif deleteCount == nil then
    actual_delete_count = len - actual_start
  else
    local dc = _to_integer_or_inf(deleteCount)
    actual_delete_count = math.max(0, math.min(dc, len - actual_start))
  end
  local deleted = _ljs_new(Array)
  for k = 0, actual_delete_count - 1 do
    local v = rawget(_ljs_this, actual_start + k + 1)
    if v ~= nil then
      rawset(deleted, k + 1, v)
    end
  end
  rawset(deleted, "length", actual_delete_count)
  if item_count < actual_delete_count then
    local k = actual_start
    while k < (len - actual_delete_count) do
      local from_val = rawget(_ljs_this, k + actual_delete_count + 1)
      if from_val ~= nil then
        rawset(_ljs_this, k + item_count + 1, from_val)
      else
        rawset(_ljs_this, k + item_count + 1, nil)
      end
      k = k + 1
    end
    for k2 = len, len - actual_delete_count + item_count + 1, -1 do
      rawset(_ljs_this, k2, nil)
    end
  elseif item_count > actual_delete_count then
    local k = len - actual_delete_count
    while k > actual_start do
      local from_val = rawget(_ljs_this, k + actual_delete_count - 1 + 1)
      if from_val ~= nil then
        rawset(_ljs_this, k + item_count - 1 + 1, from_val)
      else
        rawset(_ljs_this, k + item_count - 1 + 1, nil)
      end
      k = k - 1
    end
  end
  for j = 1, item_count do
    rawset(_ljs_this, actual_start + j, select(j, ...))
  end
  rawset(_ljs_this, "length", len - actual_delete_count + item_count)
  return deleted
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.sort
-- ---------------------------------------------------------------------------
local function _merge_sort(items, compare)
  local n = #items
  if n <= 1 then return items end
  local mid = math.floor(n / 2)
  local left, right = {}, {}
  for i = 1, mid do left[i] = items[i] end
  for i = mid + 1, n do right[i - mid] = items[i] end
  left = _merge_sort(left, compare)
  right = _merge_sort(right, compare)
  local result = {}
  local li, ri, ri2 = 1, 1, 1
  while li <= #left and ri <= #right do
    if compare(left[li], right[ri]) <= 0 then
      result[ri2] = left[li]
      li = li + 1
    else
      result[ri2] = right[ri]
      ri = ri + 1
    end
    ri2 = ri2 + 1
  end
  while li <= #left do
    result[ri2] = left[li]
    li = li + 1
    ri2 = ri2 + 1
  end
  while ri <= #right do
    result[ri2] = right[ri]
    ri = ri + 1
    ri2 = ri2 + 1
  end
  return result
end

Array.prototype.sort = _ljs_fn(function(_ljs_this, comparator)
  if comparator ~= nil and not _ljs_is_function(comparator) then
    error("TypeError: " .. _ljs_value_repr(comparator) .. " is not a function")
  end
  local len = _ljs_this.length or 0
  local items = {}
  for k = 1, len do
    local v = rawget(_ljs_this, k)
    if v ~= nil then
      items[#items + 1] = v
    end
  end
  local compare
  if comparator ~= nil then
    compare = function(x, y)
      local result = _ljs_call_member(comparator, "call", nil, x, y)
      local n = tonumber(result)
      if n == nil or n ~= n then return 0 end
      return n
    end
  else
    compare = function(x, y)
      local xs = _ljs_tostring(x)
      local ys = _ljs_tostring(y)
      if xs < ys then return -1 end
      if ys < xs then return 1 end
      return 0
    end
  end
  items = _merge_sort(items, compare)
  for j = 1, #items do
    rawset(_ljs_this, j, items[j])
  end
  for j = #items + 1, len do
    rawset(_ljs_this, j, nil)
  end
  return _ljs_this
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.join
-- ---------------------------------------------------------------------------
-- Converts each element to a string (using tostring; nil/undefined → ""),
-- then concatenates with the given separator (default ",").
Array.prototype.join = _ljs_fn(function(_ljs_this, sep)
  if sep == nil then
    sep = ","
  end
  if _ljs_this.length == 0 then
    return ""
  end
  local parts = {}
  for i = 1, _ljs_this.length do
    local v = _ljs_this[i]
    if v == nil then
      parts[i] = ""
    else
      parts[i] = tostring(v)
    end
  end
  return table.concat(parts, sep)
end)

-- ---------------------------------------------------------------------------
-- Array.prototype.toString
-- ---------------------------------------------------------------------------
-- Per spec: calls .join(",") on this.
Array.prototype.toString = _ljs_fn(function(_ljs_this)
  local join = _ljs_to_object(_ljs_this).join
  if _ljs_typeof(join) == "function" then
    local raw = rawget(join, "_ljs_raw")
    if raw then return raw(_ljs_this, ",") end
    return join(_ljs_this, ",")
  end
  local ts_raw = rawget(_ljs_object_prototype.toString, "_ljs_raw")
  if ts_raw then return ts_raw(_ljs_this) end
  return _ljs_object_prototype.toString(_ljs_this)
end)

Array.prototype.toLocaleString = _ljs_fn(function(_ljs_this)
  local array = _ljs_to_object(_ljs_this)
  local len = array.length or 0
  local separator = ","
  local result = ""
  for i = 1, len do
    if i > 1 then
      result = result .. separator
    end
    local element = array[i]
    if element ~= nil and element ~= _ljs_null then
      local element_str = _ljs_call_member(element, "toLocaleString")
      result = result .. _ljs_tostring(element_str)
    end
  end
  return result
end)

-- ---------------------------------------------------------------------------
-- Array.isArray
-- ---------------------------------------------------------------------------
-- Array.isArray: checks via _ljs_instanceof so subclass instances return true.
-- Wrapped in _ljs_fn (no .prototype) since it's a static utility.
Array.isArray = _ljs_fn(function(_ljs_this, x)
  return _ljs_instanceof(x, Array)
end)

-- ---------------------------------------------------------------------------
-- Array.from
-- ---------------------------------------------------------------------------
Array.from = _ljs_fn(function(_ljs_this, source, mapFn, thisArg)
  local arr = _ljs_new(Array)
  if source == nil then
    return arr
  end
  if type(source) == "string" then
    for i = 1, #source do
      local val = source:sub(i, i)
      if mapFn ~= nil then
        val = _ljs_call_member(mapFn, "call", thisArg, val, i - 1)
      end
      rawset(arr, i, val)
    end
    rawset(arr, "length", #source)
    return arr
  end
  if type(source) == "table" then
    local len = source.length
    if len == nil then
      return arr
    end
    for i = 1, len do
      local val = source[i]
      if mapFn ~= nil then
        val = _ljs_call_member(mapFn, "call", thisArg, val, i - 1)
      end
      rawset(arr, i, val)
    end
    rawset(arr, "length", len)
    return arr
  end
  return arr
end)

-- ---------------------------------------------------------------------------
-- Array.of
-- ---------------------------------------------------------------------------
Array.of = _ljs_fn(function(_ljs_this, ...)
  return _ljs_new(Array, ...)
end)
