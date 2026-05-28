local T = require("test.ljs_test")
if arg and arg[1] == "-v" then
  T.set_verbose(true)
end

local function discover_lua_modules(dir)
  local modules = {}
  local p = io.popen(string.format('ls -1p "%s" 2>/dev/null', dir))
  if not p then
    return modules
  end
  for entry in p:lines() do
    if not entry:match("/$") then
      local name = entry:match("^(.+)%.lua$")
      if name then
        table.insert(modules, name)
      end
    end
  end
  p:close()
  table.sort(modules)
  return modules
end

local suites = {
  { dir = "test/parser",    mod = "test.parser",    prefix = "parser" },
  { dir = "test/transpile", mod = "test.transpile", prefix = "transpile" },
  {
    dir = "test",
    mod = "test",
    prefix = "",
    exclude = { helpers = true, ljs_test = true, run = true },
  },
  { dir = "test/runtime", mod = "test.runtime", prefix = "runtime", pcall = true },
}

for _, suite in ipairs(suites) do
  local modules = discover_lua_modules(suite.dir)
  local exclude = suite.exclude or {}
  for _, name in ipairs(modules) do
    if not exclude[name] then
      local display = suite.prefix ~= "" and (suite.prefix .. "/" .. name) or name
      local mod_path = suite.mod .. "." .. name
      if suite.pcall then
        T.describe(display, function()
          local ok, err = pcall(require, mod_path)
          if not ok then
            print(
              string.format("  \27[33m⚠\27[0m %s: %s", display, tostring(err):match("^[^\n]*"))
            )
          end
        end)
      else
        T.describe(display, function()
          require(mod_path)
        end)
      end
    end
  end
end

T.summary()
