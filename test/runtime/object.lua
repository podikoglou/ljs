local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_js = R.test, R.assert_eq, R.assert_js
local eval_js, exec_js, transpile_js = R.eval_js, R.exec_js, R.transpile_js

-- ============================================================================
-- Object.keys
-- ============================================================================

test("Object.keys on plain object", function()
  local arr = exec_js("return Object.keys({a: 1, b: 2});")
  assert_eq(arr.length, 2)
  local found_a, found_b = false, false
  for i = 1, arr.length do
    if arr[i] == "a" then found_a = true end
    if arr[i] == "b" then found_b = true end
  end
  assert(found_a, "expected key 'a'")
  assert(found_b, "expected key 'b'")
end)

test("Object.keys on empty object", function()
  local arr = exec_js("return Object.keys({});")
  assert_eq(arr.length, 0)
end)

test("Object.keys throws TypeError on null", function()
  local ok, err = pcall(exec_js, "return Object.keys(null);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("Object.keys throws TypeError on undefined", function()
  local ok, err = pcall(exec_js, "return Object.keys(undefined);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

-- ============================================================================
-- Object.values
-- ============================================================================

test("Object.values on plain object", function()
  local arr = exec_js("return Object.values({a: 1, b: 2});")
  assert_eq(arr.length, 2)
  local found_1, found_2 = false, false
  for i = 1, arr.length do
    if arr[i] == 1 then found_1 = true end
    if arr[i] == 2 then found_2 = true end
  end
  assert(found_1, "expected value 1")
  assert(found_2, "expected value 2")
end)

test("Object.values on empty object", function()
  local arr = exec_js("return Object.values({});")
  assert_eq(arr.length, 0)
end)

test("Object.values throws TypeError on null", function()
  local ok, err = pcall(exec_js, "return Object.values(null);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

-- ============================================================================
-- Object.entries
-- ============================================================================

test("Object.entries on plain object", function()
  local arr = exec_js("return Object.entries({a: 1, b: 2});")
  assert_eq(arr.length, 2)
  local found_a, found_b = false, false
  for i = 1, arr.length do
    local entry = arr[i]
    assert_eq(entry.length, 2)
    if entry[1] == "a" then
      assert_eq(entry[2], 1)
      found_a = true
    end
    if entry[1] == "b" then
      assert_eq(entry[2], 2)
      found_b = true
    end
  end
  assert(found_a, "expected entry with key 'a'")
  assert(found_b, "expected entry with key 'b'")
end)

test("Object.entries on empty object", function()
  local arr = exec_js("return Object.entries({});")
  assert_eq(arr.length, 0)
end)

test("Object.entries throws TypeError on null", function()
  local ok, err = pcall(exec_js, "return Object.entries(null);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)
