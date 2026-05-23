local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js = H.run_js

-- ============================================================================
-- Unit tests — Function.prototype
-- ============================================================================

test("_ljs_function_prototype declared before helpers", function()
  local code = H.transpile_ok("let x = 1;")
  local fn_proto_pos = code:find("local _ljs_function_prototype", 1, true)
  local fn_pos = code:find("local function _ljs_fn", 1, true)
  assert(fn_proto_pos, "expected _ljs_function_prototype declaration")
  assert(fn_pos, "expected _ljs_fn definition")
  assert(fn_proto_pos < fn_pos, "_ljs_function_prototype must come before _ljs_fn")
end)

test("Function.prototype.call emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("_ljs_function_prototype.call", 1, true), "expected call method")
end)

test("Function.prototype.apply emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("_ljs_function_prototype.apply", 1, true), "expected apply method")
end)

test("Function.prototype is _ljs_function_prototype", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Function.prototype = _ljs_function_prototype", 1, true),
    "expected Function.prototype assignment"
  )
end)

-- ============================================================================
-- Integration tests — Function.prototype.call/apply
-- ============================================================================

test("Function.prototype.call invokes with custom this", function()
  local out = run_js([[
    function greet() { return "Hello, " + this.name; }
    let obj = { name: "World" };
    console.log(greet.call(obj));
  ]])
  assert_eq(out, "Hello, World\n")
end)

test("Function.prototype.call passes arguments", function()
  local out = run_js([[
    function add(a, b) { return a + b; }
    console.log(add.call(null, 3, 4));
  ]])
  assert_eq(out, "7\n")
end)

test("Function.prototype.apply invokes with args array", function()
  local out = run_js([[
    function sum(a, b, c) { return a + b + c; }
    let args = [1, 2, 3];
    console.log(sum.apply(null, args));
  ]])
  assert_eq(out, "6\n")
end)

test("Function.prototype.apply with no args", function()
  local out = run_js([[
    function greet() { return "hi"; }
    console.log(greet.apply(null));
  ]])
  assert_eq(out, "hi\n")
end)

test("method shorthand has call method via _ljs_fn", function()
  local out = run_js([[
    let obj = {
      name: "test",
      greet() { return "Hello " + this.name; }
    };
    let fn = obj.greet;
    let other = { name: "other" };
    console.log(fn.call(other));
  ]])
  assert_eq(out, "Hello other\n")
end)

test("arrow function has call method via _ljs_fn", function()
  local out = run_js([[
    let greet = (x) => "Hello " + x;
    console.log(greet.call(null, "World"));
  ]])
  assert_eq(out, "Hello World\n")
end)

test("constructor function has call method", function()
  local out = run_js([[
    function Foo(x) { this.x = x; }
    let obj = {};
    Foo.call(obj, 42);
    console.log(obj.x);
  ]])
  assert_eq(out, "42\n")
end)

test("console.log.call works", function()
  local out = run_js([[
    console.log.call(null, "hello from call");
  ]])
  assert_eq(out, "hello from call\n")
end)

test("console.log.apply works", function()
  local out = run_js([[
    console.log.apply(null, ["hello", "from", "apply"]);
  ]])
  assert_eq(out, "hello\tfrom\tapply\n")
end)

test("function inherits Object.prototype.hasOwnProperty", function()
  local out = run_js([[
    function foo() {}
    console.log(foo.hasOwnProperty("prototype"));
  ]])
  assert_eq(out, "true\n")
end)

test("recursive function declaration works", function()
  local out = run_js([[
    function fact(n) {
      if (n <= 1) return 1;
      return n * fact(n - 1);
    }
    console.log(fact(5));
  ]])
  assert_eq(out, "120\n")
end)
