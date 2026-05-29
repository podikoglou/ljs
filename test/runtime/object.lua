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

-- ============================================================================
-- Object.assign
-- ============================================================================

test("Object.assign copies properties from source to target", function()
  local result = exec_js([[
    var target = {a: 1};
    Object.assign(target, {b: 2, c: 3});
    return target;
  ]])
  assert_eq(result.a, 1)
  assert_eq(result.b, 2)
  assert_eq(result.c, 3)
end)

test("Object.assign returns target", function()
  local result = exec_js([[
    var target = {x: 1};
    var returned = Object.assign(target, {y: 2});
    return returned === target;
  ]])
  assert_eq(result, true)
end)

test("Object.assign with single arg returns target", function()
  local result = exec_js([[
    var obj = {a: 1};
    return Object.assign(obj) === obj;
  ]])
  assert_eq(result, true)
end)

test("Object.assign skips null and undefined sources", function()
  local result = exec_js([[
    var target = {a: 1};
    Object.assign(target, null, undefined, {b: 2});
    return target;
  ]])
  assert_eq(result.a, 1)
  assert_eq(result.b, 2)
end)

test("Object.assign overwrites existing properties", function()
  local result = exec_js([[
    var target = {a: 1, b: 2};
    Object.assign(target, {a: 10});
    return target;
  ]])
  assert_eq(result.a, 10)
  assert_eq(result.b, 2)
end)

test("Object.assign throws TypeError on null target", function()
  local ok, err = pcall(exec_js, "return Object.assign(null, {a: 1});")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("Object.assign with multiple sources", function()
  local result = exec_js([[
    var target = {};
    Object.assign(target, {a: 1}, {b: 2}, {c: 3});
    return target;
  ]])
  assert_eq(result.a, 1)
  assert_eq(result.b, 2)
  assert_eq(result.c, 3)
end)

-- ============================================================================
-- Object.is
-- ============================================================================

test("Object.is with same numbers", function()
  assert_eq(exec_js("return Object.is(42, 42);"), true)
end)

test("Object.is with different numbers", function()
  assert_eq(exec_js("return Object.is(1, 2);"), false)
end)

test("Object.is NaN equals NaN", function()
  assert_eq(exec_js("return Object.is(NaN, NaN);"), true)
end)

test("Object.is distinguishes +0 and -0", function()
  assert_eq(exec_js("return Object.is(0, -0);"), false)
end)

test("Object.is +0 equals +0", function()
  assert_eq(exec_js("return Object.is(+0, +0);"), true)
end)

test("Object.is -0 equals -0", function()
  assert_eq(exec_js("return Object.is(-0, -0);"), true)
end)

test("Object.is with same strings", function()
  assert_eq(exec_js("return Object.is('hello', 'hello');"), true)
end)

test("Object.is with different strings", function()
  assert_eq(exec_js("return Object.is('a', 'b');"), false)
end)

test("Object.is with same booleans", function()
  assert_eq(exec_js("return Object.is(true, true);"), true)
end)

test("Object.is null equals null", function()
  assert_eq(exec_js("return Object.is(null, null);"), true)
end)

test("Object.is null not equal to undefined", function()
  assert_eq(exec_js("return Object.is(null, undefined);"), false)
end)

test("Object.is with objects checks identity", function()
  assert_eq(exec_js([[
    var obj = {};
    return Object.is(obj, obj);
  ]]), true)
end)

test("Object.is with different objects returns false", function()
  assert_eq(exec_js("return Object.is({}, {});"), false)
end)

-- ============================================================================
-- Object.getOwnPropertyNames
-- ============================================================================

test("Object.getOwnPropertyNames on plain object", function()
  local arr = exec_js("return Object.getOwnPropertyNames({a: 1, b: 2});")
  assert_eq(arr.length, 2)
  local found_a, found_b = false, false
  for i = 1, arr.length do
    if arr[i] == "a" then found_a = true end
    if arr[i] == "b" then found_b = true end
  end
  assert(found_a, "expected key 'a'")
  assert(found_b, "expected key 'b'")
end)

test("Object.getOwnPropertyNames on empty object", function()
  local arr = exec_js("return Object.getOwnPropertyNames({});")
  assert_eq(arr.length, 0)
end)

test("Object.getOwnPropertyNames throws TypeError on null", function()
  local ok, err = pcall(exec_js, "return Object.getOwnPropertyNames(null);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

-- ============================================================================
-- Object.freeze
-- ============================================================================

test("Object.freeze returns the object", function()
  local result = exec_js([[
    var obj = {a: 1};
    return Object.freeze(obj) === obj;
  ]])
  assert_eq(result, true)
end)

test("Object.freeze prevents adding new properties", function()
  local ok, err = pcall(exec_js, [[
    var obj = Object.freeze({a: 1});
    obj.b = 2;
  ]])
  assert(not ok, "expected TypeError on frozen object")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("Object.freeze on non-object returns the value", function()
  assert_eq(exec_js("return Object.freeze(42);"), 42)
end)

test("Object.freeze on string returns the string", function()
  assert_eq(exec_js("return Object.freeze('hello');"), "hello")
end)

-- ============================================================================
-- Object.seal
-- ============================================================================

test("Object.seal returns the object", function()
  local result = exec_js([[
    var obj = {a: 1};
    return Object.seal(obj) === obj;
  ]])
  assert_eq(result, true)
end)

test("Object.seal prevents adding new properties", function()
  local ok, err = pcall(exec_js, [[
    var obj = Object.seal({a: 1});
    obj.b = 2;
  ]])
  assert(not ok, "expected TypeError on sealed object")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("Object.seal allows modifying existing properties", function()
  local result = exec_js([[
    var obj = Object.seal({a: 1});
    obj.a = 99;
    return obj.a;
  ]])
  assert_eq(result, 99)
end)

test("Object.seal on non-object returns the value", function()
  assert_eq(exec_js("return Object.seal(42);"), 42)
end)

-- ============================================================================
-- Object.getPrototypeOf
-- ============================================================================

test("Object.getPrototypeOf({}) === Object.prototype", function()
  assert_eq(exec_js("return Object.getPrototypeOf({}) === Object.prototype;"), true)
end)
