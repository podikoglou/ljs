local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js = H.transpile_ok, H.expr_code, H.run_js

-- ============================================================================
-- Unit tests — this binding
-- ============================================================================

test("this in method body emits _ljs_arrow_this", function()
  local code = expr_code("this")
  assert_eq(code, "local _ = _ljs_arrow_this")
end)

test("method call routes through _ljs_call_member", function()
  local code = expr_code("obj.m(a)")
  assert_eq(code, '_ljs_call_member(obj, "m", a)')
end)

test("direct call routes through _ljs_call", function()
  local code = expr_code("f(a)")
  assert_eq(code, "_ljs_call(f, a)")
end)

test("computed member call routes through _ljs_call_member", function()
  local code = expr_code("obj[k](a)")
  assert_eq(code, "_ljs_call_member(obj, (k) + 1, a)")
end)

test("method shorthand gets _ljs_this param", function()
  local code = transpile_ok("let o = { m(x) { return x; } };")
  assert(code:find("function%(_ljs_this, x%)"), "expected _ljs_this in method params")
end)

test("function expression in object gets _ljs_this param", function()
  local code = transpile_ok("let o = { fn: function(x) { return x; } };")
  assert(code:find("function%(_ljs_this, x%)"), "expected _ljs_this in function params")
end)

test("arrow function gets _ljs_this param", function()
  local code = transpile_ok("let f = (x) => { return x; };")
  assert(code:find("_ljs_this, x"), "expected _ljs_this in arrow function params")
end)

test("function declaration gets _ljs_this param", function()
  local code = transpile_ok("function f(x) { return x; }")
  assert(code:find("function%(_ljs_this, x%)"), "expected _ljs_this in function declaration")
end)

test("_ljs_call helper emitted when call exists", function()
  local code = transpile_ok("f();")
  assert(code:find("local function _ljs_call"), "expected _ljs_call helper")
end)

test("_ljs_call_member helper emitted when member call exists", function()
  local code = transpile_ok("obj.m();")
  assert(code:find("local function _ljs_call_member"), "expected _ljs_call_member helper")
end)

test("_ljs_object helper emitted when object literal exists", function()
  local code = transpile_ok("let o = {a: 1};")
  assert(code:find("local function _ljs_object"), "expected _ljs_object helper")
end)

-- ============================================================================
-- Integration tests — this binding behavior
-- ============================================================================

test("method call binds this to object", function()
  local output = run_js([[
    let obj = {
      name: "hello",
      greet() { return this.name; }
    };
    console.log(obj.greet());
  ]])
  assert_eq(output:gsub("%s+", ""), "hello")
end)

test("this in method with params", function()
  local output = run_js([[
    let obj = {
      x: 10,
      add(y) { return this.x + y; }
    };
    console.log(obj.add(5));
  ]])
  assert_eq(output:gsub("%s+", ""), "15")
end)

test("direct call this is undefined (nil)", function()
  local output = run_js([[
    function getThis() { return this; }
    let t = getThis();
    console.log(t === undefined);
  ]])
  assert_eq(output:gsub("%s+", ""), "true")
end)

test("arrow function captures lexical this", function()
  local output = run_js([[
    let obj = {
      name: "captured",
      getArrow() {
        let arrow = () => this.name;
        return arrow();
      }
    };
    console.log(obj.getArrow());
  ]])
  assert_eq(output:gsub("%s+", ""), "captured")
end)

test("chained method calls bind this correctly", function()
  local output = run_js([[
    let obj = {
      x: 5,
      double() { return this.x * 2; }
    };
    console.log(obj.double());
  ]])
  assert_eq(output:gsub("%s+", ""), "10")
end)

test("dynamic method addition works", function()
  local output = run_js([[
    let obj = { x: 42 };
    obj.getX = function() { return this.x; };
    console.log(obj.getX());
  ]])
  assert_eq(output:gsub("%s+", ""), "42")
end)

test("typeof this in method returns object", function()
  local output = run_js([[
    let obj = {
      check() { return typeof this; }
    };
    console.log(obj.check());
  ]])
  assert_eq(output:gsub("%s+", ""), "object")
end)

test("this in nested object method binds to inner object", function()
  local output = run_js([[
    let obj = {
      inner: {
        val: 99,
        get() { return this.val; }
      }
    };
    console.log(obj.inner.get());
  ]])
  assert_eq(output:gsub("%s+", ""), "99")
end)
