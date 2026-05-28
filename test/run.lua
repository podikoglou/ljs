local T = require("test.ljs_test")
local lfs = require("lfs")

if arg and arg[1] == "-v" then
  T.set_verbose(true)
end

local function describe(name, mod)
  T.describe(name, function()
    require(mod)
  end)
end

-- Auto-discover tests from a directory
local function auto_discover_tests(directory, describe_fn, prefix)
  local tests = {}
  for entry in lfs.dir(directory) do
    if entry ~= "." and entry ~= ".." and entry:match("%.lua$") then
      local name = entry:sub(1, -5) -- remove .lua extension
      tests[#tests + 1] = name
    end
  end
  table.sort(tests)
  for _, name in ipairs(tests) do
    local display_name = prefix .. "/" .. name
    local module_name = "test." .. prefix .. "." .. name
    describe_fn(display_name, module_name)
  end
end

local function describe_soft(name, mod)
  T.describe(name, function()
    local ok, err = pcall(require, mod)
    if not ok then
      print(string.format("  \27[33m⚠\27[0m %s: %s", name, tostring(err):match("^[^\n]*")))
    end
  end)
end

auto_discover_tests("test/parser", describe, "parser")

auto_discover_tests("test/transpile", describe, "transpile")

describe("codegen", "test.codegen")

describe("public_api", "test.public_api")

auto_discover_tests("test/runtime", describe_soft, "runtime")

T.summary()
