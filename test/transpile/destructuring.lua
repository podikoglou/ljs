local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

test("array destructuring transpiles to temp + index extraction", function()
  local code = transpile_ok("let [a, b] = [1, 2];")
  assert(code:find("local _ljs_d", 1, true), "expected temp var")
  assert(code:find('local a = _ljs_d', 1, true), "expected a = _ljs_d")
  assert(code:find('local b = _ljs_d', 1, true), "expected b = _ljs_d")
end)

test("array destructuring — runtime values", function()
  local out = run_js("let [a, b] = [10, 20];\nconsole.log(a, b);")
  assert_eq(out, "10\t20\n")
end)

test("object destructuring transpiles to temp + key extraction", function()
  local code = transpile_ok("let {x, y} = obj;")
  assert(code:find("local _ljs_d", 1, true), "expected temp var")
  assert(code:find('local x = _ljs_d', 1, true), "expected x = _ljs_d")
  assert(code:find('local y = _ljs_d', 1, true), "expected y = _ljs_d")
end)

test("object destructuring — runtime values", function()
  local out = run_js('let {x, y} = {x: 1, y: 2};\nconsole.log(x, y);')
  assert_eq(out, "1\t2\n")
end)

test("object rename destructuring", function()
  local out = run_js('let {x: y} = {x: 42};\nconsole.log(y);')
  assert_eq(out, "42\n")
end)

test("default value in object destructuring — default used", function()
  local out = run_js('let {x = 10} = {};\nconsole.log(x);')
  assert_eq(out, "10\n")
end)

test("default value in object destructuring — value present", function()
  local out = run_js('let {x = 10} = {x: 5};\nconsole.log(x);')
  assert_eq(out, "5\n")
end)

test("default value in array destructuring — default used", function()
  local out = run_js('let [a = 99] = [undefined];\nconsole.log(a);')
  assert_eq(out, "99\n")
end)

test("default value in array destructuring — value present", function()
  local out = run_js('let [a = 99] = [7];\nconsole.log(a);')
  assert_eq(out, "7\n")
end)

test("rest in array destructuring", function()
  local out = run_js('let [a, ...rest] = [1, 2, 3];\nconsole.log(a, rest[0], rest[1]);')
  assert_eq(out, "1\t2\t3\n")
end)

test("hole in array destructuring", function()
  local out = run_js('let [, b] = [10, 20];\nconsole.log(b);')
  assert_eq(out, "20\n")
end)

test("nested object destructuring", function()
  local out = run_js('let {a: {b}} = {a: {b: 42}};\nconsole.log(b);')
  assert_eq(out, "42\n")
end)

test("nested array in object destructuring", function()
  local out = run_js('let {a: [b]} = {a: [99]};\nconsole.log(b);')
  assert_eq(out, "99\n")
end)

test("default value not triggered by false (#173)", function()
  local out = run_js('let {x = 10} = {x: false};\nconsole.log(x);')
  assert_eq(out, "false\n")
end)

test("default value not triggered by 0 (#173)", function()
  local out = run_js('let {x = 10} = {x: 0};\nconsole.log(x);')
  assert_eq(out, "0\n")
end)

test("default value not triggered by empty string (#173)", function()
  local out = run_js('let {x = 10} = {x: ""};\nconsole.log(x);')
  assert_eq(out, "\n")
end)

test("default value not triggered by null (#173)", function()
  local out = run_js('let {x = 10} = {x: null};\nconsole.log(x);')
  assert_eq(out, "null\n")
end)

test("rest in object destructuring", function()
  local out = run_js('let {x, ...rest} = {x: 1, y: 2, z: 3};\nconsole.log(x, rest.y, rest.z);')
  assert_eq(out, "1\t2\t3\n")
end)

test("destructure_counter resets between transpiles (#174)", function()
  local src = "let {x} = obj;"
  local code1 = transpile_ok(src)
  local code2 = transpile_ok(src)
  assert(code1:find("_ljs_d1", 1, true), "first transpile should use _ljs_d1")
  assert(code2:find("_ljs_d1", 1, true), "second transpile should also use _ljs_d1")
  assert(not code2:find("_ljs_d2", 1, true), "second transpile should not leak _ljs_d2")
end)

test("bare array destructuring assignment — runtime values (#181)", function()
  local out = run_js("let a, b; [a, b] = [1, 2];\nconsole.log(a, b);")
  assert_eq(out, "1\t2\n")
end)

test("bare array destructuring with holes — runtime values (#181)", function()
  local out = run_js("let a, b; [a, , b] = [1, 2, 3];\nconsole.log(a, b);")
  assert_eq(out, "1\t3\n")
end)

test("bare object destructuring assignment — runtime values (#181)", function()
  local out = run_js('let x, y; ({x, y} = {x: 1, y: 2});\nconsole.log(x, y);')
  assert_eq(out, "1\t2\n")
end)

test("nested array destructuring assignment — runtime values (#181)", function()
  local out = run_js("let a, b; [a, [b]] = [1, [2]];\nconsole.log(a, b);")
  assert_eq(out, "1\t2\n")
end)

test("default value in bare array destructuring — default used (#181)", function()
  local out = run_js("let a; [a = 10] = [undefined];\nconsole.log(a);")
  assert_eq(out, "10\n")
end)

test("default value in bare array destructuring — value present (#181)", function()
  local out = run_js("let a; [a = 10] = [5];\nconsole.log(a);")
  assert_eq(out, "5\n")
end)

test("rest in bare array destructuring assignment (#181)", function()
  local out = run_js("let a, b; [a, ...b] = [1, 2, 3];\nconsole.log(a, b[0], b[1]);")
  assert_eq(out, "1\t2\t3\n")
end)

test("destructuring assignment expression context — IIFE (#181)", function()
  local code = transpile_ok("let a, b; while ([a, b] = [1, 2]) { break; }")
  assert(code:find("function()", 1, true), "expected IIFE for expression context")
end)

test("destructuring assignment returns RHS value (#181)", function()
  local out = run_js("let a, b; let c = [a, b] = [42, 99];\nconsole.log(c[0], c[1]);")
  assert_eq(out, "42\t99\n")
end)

test("object destructuring assignment with rename (#181)", function()
  local out = run_js('let y; ({x: y} = {x: 42});\nconsole.log(y);')
  assert_eq(out, "42\n")
end)
