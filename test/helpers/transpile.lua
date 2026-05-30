-- Transpile test helpers module
local transpile = require("ljs.transpile")
local parser = require("ljs.parser")
local T = require("test.ljs_test") -- ljs_test is at root

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

local function emit_ok(src)
  local ast, err = parser.parse(src)
  if not ast then
    error("parse failed: " .. tostring(err))
  end
  local code, err2 = transpile.emit(ast)
  if not code then
    error("emit failed: " .. tostring(err2))
  end
  return code
end

local function emit_expr_code(src)
  local ast, err = parser.parse(src)
  if not ast then
    error("parse failed: " .. tostring(err))
  end
  local code, err2 = transpile.emit(ast)
  if not code then
    error("emit failed: " .. tostring(err2))
  end
  code = code:gsub("\n$", "")
  return code:match("([^\n]*)$")
end

local expr_code = emit_expr_code

-- Integration test helpers

local function run_lua_source(code)
  local chunks = {}
  local function emit(s)
    chunks[#chunks + 1] = s
  end
  local capture = {
    write = function(_, ...)
      for i = 1, select("#", ...) do
        emit(tostring(select(i, ...)))
      end
    end,
    close = function() end,
    flush = function() end,
  }

  local old_stdout = io.stdout
  local old_stderr = io.stderr
  local old_print = print
  io.stdout = capture
  io.stderr = capture
  print = function(...)
    local n = select("#", ...)
    for i = 1, n do
      if i > 1 then
        emit("\t")
      end
      emit(tostring(select(i, ...)))
    end
    emit("\n")
  end

  local ok, result = pcall(function()
    local fn, load_err = load(code)
    if not fn then
      return tostring(load_err) .. "\n"
    end
    local pok, err = pcall(fn)
    if not pok then
      emit(tostring(err) .. "\n")
    end
    return table.concat(chunks)
  end)

  io.stdout = old_stdout
  io.stderr = old_stderr
  print = old_print

  if not ok then
    error(result)
  end
  return result
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
  emit_ok = emit_ok,
  emit_expr_code = emit_expr_code,
  expr_code = expr_code,
  run_lua_source = run_lua_source,
  run_js = run_js,
  read_file = read_file,
}
