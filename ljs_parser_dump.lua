-- ljs_parser_dump - CLI frontend for ljs parser
-- Reads JS from file argument or stdin, prints AST as JSON to stdout.
--
-- Usage:
--   lua ljs_parser_dump.lua file.js
--   cat file.js | lua ljs_parser_dump.lua
--   echo "let x = 42;" | lua ljs_parser_dump.lua

local ljs = require("ljs_parser")

-- JSON serialization --------------------------------------------------------

local function json_escape_string(s)
  local out = {}
  for i = 1, #s do
    local c = s:sub(i, i)
    local b = string.byte(c)
    if c == '"' then
      out[#out + 1] = '\\"'
    elseif c == "\\" then
      out[#out + 1] = "\\\\"
    elseif c == "\n" then
      out[#out + 1] = "\\n"
    elseif c == "\r" then
      out[#out + 1] = "\\r"
    elseif c == "\t" then
      out[#out + 1] = "\\t"
    elseif b < 32 then
      out[#out + 1] = string.format("\\u%04x", b)
    else
      out[#out + 1] = c
    end
  end
  return table.concat(out)
end

local function is_array(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

local json_null = {}

local function serialize(val, indent, visited)
  local t = type(val)

  if val == nil then
    return "null"
  elseif t == "string" then
    return '"' .. json_escape_string(val) .. '"'
  elseif t == "number" then
    if val ~= val then return "null" end
    if val == math.huge then return "1e308" end
    if val == -math.huge then return "-1e308" end
    return tostring(val)
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "table" then
    if val == json_null then
      return "null"
    end

    if visited then
      if visited[val] then return "null" end
      visited[val] = true
    else
      visited = { [val] = true }
    end

    local is_arr = is_array(val)
    local parts = {}
    local inner = indent .. "  "

    if is_arr then
      for i = 1, #val do
        parts[#parts + 1] = inner .. serialize(val[i], inner, visited)
      end
      if #parts == 0 then return "[]" end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
    else
      local keys = {}
      for k in pairs(val) do
        keys[#keys + 1] = k
      end
      table.sort(keys)
      for _, k in ipairs(keys) do
        local v = val[k]
        if v ~= nil then
          local vs = serialize(v, inner, visited)
          parts[#parts + 1] = inner .. '"' .. json_escape_string(tostring(k)) .. '": ' .. vs
        end
      end
      if #parts == 0 then return "{}" end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
  else
    return "null"
  end
end

-- Input reading -------------------------------------------------------------

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local content = f:read("*a")
  f:close()
  return content
end

local function read_stdin()
  return io.read("*a")
end

-- Main ----------------------------------------------------------------------

local function main()
  local source, err

  if #arg >= 1 then
    source, err = read_file(arg[1])
    if not source then
      io.stderr:write("error: " .. err .. "\n")
      os.exit(1)
    end
  else
    source = read_stdin()
    if not source then
      io.stderr:write("error: could not read stdin\n")
      os.exit(1)
    end
  end

  local ast, parse_err = ljs.parse(source)
  if not ast then
    io.stderr:write(parse_err .. "\n")
    os.exit(1)
  end

  io.write(serialize(ast, "") .. "\n")
end

main()
