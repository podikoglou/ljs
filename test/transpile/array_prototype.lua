local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js, expr_code = H.run_js, H.expr_code

-- ============================================================================
-- Unit tests — Array
-- ============================================================================

test("Array constructor emitted in runtime init", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("local Array = _ljs_ctor", 1, true), "expected Array constructor")
end)

test("Array.prototype.push emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("Array.prototype.push", 1, true), "expected Array.prototype.push")
end)

test("Array.prototype.pop emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("Array.prototype.pop", 1, true), "expected Array.prototype.pop")
end)

test("array literal emits _ljs_new(Array, ...)", function()
  local code = expr_code("[1, 2, 3]")
  assert_eq(code, "_ljs_new(Array, 1, 2, 3)")
end)

test("empty array literal emits _ljs_new(Array)", function()
  local code = expr_code("[]")
  assert_eq(code, "_ljs_new(Array)")
end)

-- ============================================================================
-- Integration tests — Array behavior
-- ============================================================================

test("array literal stores elements", function()
  local out = run_js([[
    let arr = [10, 20, 30];
    console.log(arr[0]);
    console.log(arr[1]);
    console.log(arr[2]);
  ]])
  assert_eq(out, "10\n20\n30\n")
end)

test("array has length property", function()
  local out = run_js([[
    let arr = [1, 2, 3];
    console.log(arr.length);
  ]])
  assert_eq(out, "3\n")
end)

test("array push adds elements and returns length", function()
  local out = run_js([[
    let arr = [1, 2];
    let len = arr.push(3, 4);
    console.log(arr.length);
    console.log(len);
    console.log(arr[2]);
    console.log(arr[3]);
  ]])
  assert_eq(out, "4\n4\n3\n4\n")
end)

test("array pop removes last element and returns it", function()
  local out = run_js([[
    let arr = [1, 2, 3];
    let val = arr.pop();
    console.log(val);
    console.log(arr.length);
    console.log(arr[0]);
    console.log(arr[1]);
  ]])
  assert_eq(out, "3\n2\n1\n2\n")
end)

test("array pop on empty returns undefined", function()
  local out = run_js([[
    let arr = [];
    let val = arr.pop();
    console.log(val === undefined);
  ]])
  assert_eq(out, "true\n")
end)

test("for...of iterates array elements", function()
  local out = run_js([[
    let arr = [10, 20, 30];
    for (let x of arr) {
      console.log(x);
    }
  ]])
  assert_eq(out, "10\n20\n30\n")
end)

test("array inherits Object.prototype.toString", function()
  local out = run_js([[
    let arr = [1, 2];
    console.log(arr.hasOwnProperty("length"));
    console.log(arr.toString());
  ]])
  assert_eq(out, "true\n[object Object]\n")
end)
