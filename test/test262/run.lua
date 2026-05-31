local runner = require("test.test262.runner")

local verbose = false
local max_fail = 0
local suites = nil

for _, arg in ipairs(arg or {}) do
  if arg == "-v" or arg == "--verbose" then
    verbose = true
  elseif arg:match("^%-%-max%-fail=(%d+)$") then
    max_fail = tonumber(arg:match("^%-%-max%-fail=(%d+)$"))
  elseif arg:match("^%-%-suite=(.+)$") then
    suites = { arg:match("^%-%-suite=(.+)$") }
  elseif arg == "--help" then
    print("Usage: lua test/test262/run.lua [options]")
    print("Options:")
    print("  -v, --verbose       Show per-test results")
    print("  --max-fail=N        Stop after N failures")
    print("  --suite=PATH        Run only one suite (e.g. test/language/expressions/addition)")
    print("  --help              Show this help")
    os.exit(0)
  end
end

runner.run({
  test262_dir = "test262",
  verbose = verbose,
  max_fail = max_fail,
  suites = suites,
})
