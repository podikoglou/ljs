local ljs_test = {}

local passed = 0
local failed = 0

function ljs_test.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. " - " .. tostring(err))
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
    for k, _ in pairs(actual) do
      if expected[k] == nil then
        error(string.format("%s: unexpected key %s", path, tostring(k)))
      end
    end
  else
    if actual ~= expected then
      error(string.format("%s: expected %s, got %s", path, tostring(expected), tostring(actual)))
    end
  end
end

function ljs_test.summary()
  print(string.format("\n%d passed, %d failed", passed, failed))
  os.exit(failed > 0 and 1 or 0)
end

return ljs_test
