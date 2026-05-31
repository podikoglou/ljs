local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js = H.run_js

test("function declaration has .name", function()
  local out = run_js([[
    function foo() {}
    console.log(foo.name);
  ]])
  assert_eq(out, "foo\n")
end)

test("named function expression has .name", function()
  local out = run_js([[
    var fn = function bar() {};
    console.log(fn.name);
  ]])
  assert_eq(out, "bar\n")
end)

test("anonymous function expression gets inferred name from var", function()
  local out = run_js([[
    var baz = function() {};
    console.log(baz.name);
  ]])
  assert_eq(out, "baz\n")
end)

test("arrow function gets inferred name from var", function()
  local out = run_js([[
    var arrow = () => {};
    console.log(arrow.name);
  ]])
  assert_eq(out, "arrow\n")
end)

test("anonymous function expression without assignment has empty name", function()
  local out = run_js([[
    console.log((function() {}).name === "");
  ]])
  assert_eq(out, "true\n")
end)

test("anonymous arrow without assignment has empty name", function()
  local out = run_js([[
    console.log((() => {}).name === "");
  ]])
  assert_eq(out, "true\n")
end)

test("function.name is non-writable: assignment silently fails", function()
  local out = run_js([[
    function foo() {}
    foo.name = "bar"
    console.log(foo.name);
  ]])
  assert_eq(out, "foo\n")
end)

test("named function expression .name is non-writable", function()
  local out = run_js([[
    var fn = function bar() {};
    fn.name = "baz";
    console.log(fn.name);
  ]])
  assert_eq(out, "bar\n")
end)

test("arrow function .name is non-writable", function()
  local out = run_js([[
    var arrow = () => {};
    arrow.name = "other";
    console.log(arrow.name);
  ]])
  assert_eq(out, "arrow\n")
end)

test("Function.prototype.name is non-writable", function()
  local out = run_js([[
    var orig = Function.prototype.name;
    Function.prototype.name = "hacked";
    console.log(Function.prototype.name === orig);
  ]])
  assert_eq(out, "true\n")
end)

-- Regression tests: function-based __index must not break instanceof/prototype chain

test("function Foo() {}; Foo instanceof Function", function()
  local out = run_js([[
    function Foo() {}
    console.log(Foo instanceof Function);
  ]])
  assert_eq(out, "true\n")
end)

test("Object.getPrototypeOf(Function.prototype) === Object.prototype", function()
  local out = run_js([[
    console.log(Object.getPrototypeOf(Function.prototype) === Object.prototype);
  ]])
  assert_eq(out, "true\n")
end)

test("Object.getPrototypeOf(fn) on user functions", function()
  local out = run_js([[
    function foo() {}
    console.log(Object.getPrototypeOf(foo) === Function.prototype);
    var arrow = () => {};
    console.log(Object.getPrototypeOf(arrow) === Function.prototype);
  ]])
  assert_eq(out, "true\ntrue\n")
end)

test("fn.__proto__ access", function()
  local out = run_js([[
    function foo() {}
    console.log(foo.__proto__ === Function.prototype);
  ]])
  assert_eq(out, "true\n")
end)

test("custom properties still work on functions", function()
  local out = run_js([[
    function fn() {}
    fn.x = 1;
    console.log(fn.x);
  ]])
  assert_eq(out, "1\n")
end)

test('"name" in fn (in operator on function properties)', function()
  local out = run_js([[
    function foo() {}
    console.log("name" in foo);
  ]])
  assert_eq(out, "true\n")
end)
