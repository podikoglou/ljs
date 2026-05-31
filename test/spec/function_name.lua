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
