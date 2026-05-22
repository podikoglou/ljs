local T = require("ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_js = R.test, R.assert_eq, R.assert_js
local eval_js, exec_js, transpile_js = R.eval_js, R.exec_js, R.transpile_js

-- ============================================================================
-- Array.prototype.push
-- ============================================================================

test("push returns new length", function()
  assert_eq(exec_js("let a = [1, 2, 3]; return a.push(4);"), 4)
end)

test("push appends element", function()
  local arr = exec_js("let a = [1, 2]; a.push(99); return a;")
  assert_eq(arr[3], 99)
  assert_eq(arr.length, 3)
end)

test("push with multiple args", function()
  assert_eq(exec_js("let a = [1]; a.push(2, 3); return a.length;"), 3)
end)

-- ============================================================================
-- Array.prototype.pop
-- ============================================================================

test("pop returns last element", function()
  assert_eq(exec_js("let a = [10, 20, 30]; return a.pop();"), 30)
end)

test("pop reduces length", function()
  local arr = exec_js("let a = [1, 2, 3]; a.pop(); return a;")
  assert_eq(arr.length, 2)
  assert_eq(arr[2], 2)
end)

test("pop on empty returns nil", function()
  assert_eq(exec_js("let a = []; return a.pop();"), nil)
end)

-- ============================================================================
-- Array constructor / literal
-- ============================================================================

test("array literal length and indexing", function()
  local arr = eval_js("[1, 2, 3]")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[3], 3)
end)

test("new Array with elements", function()
  local arr = eval_js("new Array(7, 8, 9)")
  assert_eq(arr[1], 7)
  assert_eq(arr[2], 8)
  assert_eq(arr[3], 9)
  assert_eq(arr.length, 3)
end)

-- ============================================================================
-- Object.prototype.toString
-- ============================================================================

test("toString on empty object", function()
  assert_eq(exec_js("let o = {}; return o.toString();"), "[object Object]")
end)

test("toString on object with properties", function()
  assert_eq(exec_js("let o = {a: 1}; return o.toString();"), "[object Object]")
end)

-- ============================================================================
-- Object.prototype.hasOwnProperty
-- ============================================================================

test("hasOwnProperty true for own key", function()
  assert_eq(exec_js("let o = {a: 1}; return o.hasOwnProperty('a');"), true)
end)

test("hasOwnProperty false for missing key", function()
  assert_eq(exec_js("let o = {a: 1}; return o.hasOwnProperty('b');"), false)
end)

-- ============================================================================
-- Object.create
-- ============================================================================

test("Object.create inherits properties", function()
  assert_eq(
    exec_js([[
    let proto = { greet: function() { return "hi"; } };
    let child = Object.create(proto);
    return child.greet();
  ]]),
    "hi"
  )
end)

-- ============================================================================
-- Function.prototype.call / apply
-- ============================================================================

test("Function.prototype.call", function()
  assert_eq(exec_js("let f = function() { return this.x; }; return f.call({x: 42});"), 42)
end)

test("Function.prototype.apply", function()
  assert_eq(exec_js("let f = function(a, b) { return a + b; }; return f.apply(null, [3, 4]);"), 7)
end)

-- ============================================================================
-- Code generation checks
-- ============================================================================

test("member call emits _ljs_call_member", function()
  local code = transpile_js("arr.push(1);")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member in output")
end)

test("new emits _ljs_new", function()
  local code = transpile_js("new Array(1, 2);")
  assert(code:find("_ljs_new"), "expected _ljs_new in output")
end)

T.summary()
