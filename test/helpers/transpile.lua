-- Transpile test helpers module
local transpile = require("ljs_transpile")
local parser = require("ljs_parser")
local T = require("ljs_test") -- ljs_test is at root

local test, assert_eq = T.test, T.assert_eq

-- Unit test helpers

local function transpile_ast(ast)
  local code, err = transpile.transpile(ast)
  if not code then
    error("transpile failed: " .. tostring(err))
  end
  return code
end

local function transpile_ok(src)
  local ast, err = parser.parse(src)
  if not ast then
    error("parse failed: " .. tostring(err))
  end
  return transpile_ast(ast)
end

local function expr_code(src)
  local ast, err = parser.parse(src)
  if not ast then
    error("parse failed: " .. tostring(err))
  end
  local code, err2 = transpile.transpile(ast)
  if not code then
    error("transpile failed: " .. tostring(err2))
  end
  code = code:gsub("\n$", "")
  local last_line = code:match("([^\n]*)$")
  return last_line
end

-- Integration test helpers

local function run_lua_source(code)
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  f:write(code)
  f:close()
  local pipe = io.popen("lua " .. tmp .. " 2>&1", "r")
  local output = pipe:read("*a")
  pipe:close()
  os.remove(tmp)
  return output
end

local function run_js(js)
  return run_lua_source(transpile_ok(js))
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    error("cannot open: " .. path)
  end
  local content = f:read("*a")
  f:close()
  return content
end

return {
  transpile = transpile,
  parser = parser,
  test = test,
  assert_eq = assert_eq,
  transpile_ast = transpile_ast,
  transpile_ok = transpile_ok,
  expr_code = expr_code,
  run_lua_source = run_lua_source,
  run_js = run_js,
  read_file = read_file,
}
