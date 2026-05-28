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

-- Register runtime tests with error handling
local function register_runtime_tests(tests)
  for _, name in ipairs(tests) do
    T.describe("runtime/" .. name, function()
      local ok, err = pcall(require, "test.runtime." .. name)
      if not ok then
        print(
          string.format("  \27[33m⚠\27[0m runtime/%s: %s", name, tostring(err):match("^[^\n]*"))
        )
      end
    end)
  end
end

auto_discover_tests("test/parser", describe, "parser")

auto_discover_tests("test/transpile", describe, "transpile")

describe("codegen", "test.codegen")

describe("public_api", "test.public_api")

local runtime_tests = {
  "array",
  "error",
  "json",
  "math",
  "console",
  "globals",
  "null_undefined",
  "loose_equality",
  "helpers",
  "logical_operators",
  "tostring",
  "object_tostring",
  "string",
  "function_errors",
  "number",
  "object",
}
register_runtime_tests(runtime_tests)

T.summary()
