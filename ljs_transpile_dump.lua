local ljs = require("ljs_parser")
local transpile = require("ljs_transpile")

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then
    return nil, err
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function main()
  local source, err

  if #arg >= 1 then
    source, err = read_file(arg[1])
    if not source then
      io.stderr:write("error: " .. err .. "\n")
      os.exit(1)
    end
  else
    source = io.read("*a")
    if not source then
      io.stderr:write("error: could not read stdin\n")
      os.exit(1)
    end
  end

  local lua_code, transpile_err = transpile.transpile_source(source)
  if not lua_code then
    io.stderr:write(ljs.format_error(transpile_err, source) .. "\n")
    os.exit(1)
  end

  io.write(lua_code)
end

main()
