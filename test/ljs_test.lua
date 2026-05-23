local ljs_test = {}

---@type { name: string, tests: { name: string, status: string, err: string?, time: number }[] }[]
local groups = {}
---@type { name: string, tests: { name: string, status: string, err: string?, time: number }[] }?
local current_group = nil
local verbose = false

function ljs_test.set_verbose(v)
  verbose = v
end

function ljs_test.describe(name, fn)
  current_group = { name = name, tests = {} }
  table.insert(groups, current_group)
  fn()
  current_group = nil
end

function ljs_test.test(name, fn)
  local group = current_group or error("test() called outside describe()")
  local start = os.clock()
  local ok, err = pcall(fn)
  local elapsed = os.clock() - start
  if ok then
    table.insert(group.tests, { name = name, status = "pass", time = elapsed })
  else
    table.insert(group.tests, { name = name, status = "fail", err = err, time = elapsed })
  end
end

function ljs_test.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(
      string.format(
        "%s: expected %s, got %s",
        msg or "assertion failed",
        tostring(expected),
        tostring(actual)
      )
    )
  end
end

function ljs_test.assert_table_eq(actual, expected, path)
  path = path or "root"
  if type(actual) ~= type(expected) then
    error(
      string.format("%s: type mismatch, expected %s got %s", path, type(expected), type(actual))
    )
  end
  if type(expected) == "table" then
    for k, v in pairs(expected) do
      ljs_test.assert_table_eq(actual[k], v, path .. "." .. tostring(k))
    end
  else
    if actual ~= expected then
      error(string.format("%s: expected %s, got %s", path, tostring(expected), tostring(actual)))
    end
  end
end

function ljs_test.summary()
  local total_pass = 0
  local total_fail = 0
  local start = os.clock()

  print("ljs test suite\n")

  for _, group in ipairs(groups) do
    local passed = 0
    local failed = 0
    local failures = {}

    for _, t in ipairs(group.tests) do
      if t.status == "pass" then
        passed = passed + 1
      else
        failed = failed + 1
        table.insert(failures, t)
      end
    end

    total_pass = total_pass + passed
    total_fail = total_fail + failed

    if verbose then
      print(group.name)
      for _, t in ipairs(group.tests) do
        if t.status == "pass" then
          print(string.format("  \27[32m✓\27[0m %s", t.name))
        else
          print(string.format("  \27[31m✗\27[0m %s", t.name))
          print(string.format("    %s", tostring(t.err):gsub("\n", "\n    ")))
        end
      end
      print(string.format("  (%d tests)\n", #group.tests))
    else
      if failed == 0 then
        print(string.format("  \27[32m✓\27[0m %s (%d)", group.name, passed))
      else
        print(
          string.format("  \27[31m✗\27[0m %s (%d passed, %d failed)", group.name, passed, failed)
        )
        for _, t in ipairs(failures) do
          print(string.format("    FAIL: %s", t.name))
          print(string.format("      %s", tostring(t.err):gsub("\n", "\n      ")))
        end
      end
    end
  end

  local elapsed = os.clock() - start
  print("")
  if total_fail == 0 then
    print(string.format("\27[32mAll %d tests passed\27[0m (%.2fs)", total_pass, elapsed))
  else
    print(
      string.format("\27[31m%d passed, %d failed\27[0m (%.2fs)", total_pass, total_fail, elapsed)
    )
  end

  os.exit(total_fail > 0 and 1 or 0)
end

return ljs_test
