local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js = H.run_js

test("function declaration is hoisted before use", function()
  local out = run_js([[
    console.log(foo());
    function foo() { return 42; }
  ]])
  assert_eq(out, "42\n")
end)

test("multiple function declarations are hoisted", function()
  local out = run_js([[
    console.log(a());
    console.log(b());
    function a() { return 1; }
    function b() { return 2; }
  ]])
  assert_eq(out, "1\n2\n")
end)

test("last duplicate function declaration wins", function()
  local out = run_js([[
    console.log(foo());
    function foo() { return 1; }
    function foo() { return 2; }
  ]])
  assert_eq(out, "2\n")
end)

test("function declarations are hoisted inside function body", function()
  local out = run_js([[
    function outer() {
      console.log(inner());
      function inner() { return "hoisted"; }
    }
    outer();
  ]])
  assert_eq(out, "hoisted\n")
end)

test("function hoisting works with var declarations", function()
  local out = run_js([[
    console.log(typeof greet);
    var x = 1;
    function greet() { return "hi"; }
    console.log(x);
    console.log(greet());
  ]])
  assert_eq(out, "function\n1\nhi\n")
end)

test("function expression is NOT hoisted", function()
  local out = run_js([[
    var x = typeof bar;
    var bar = function() { return 1; };
    console.log(x);
  ]])
  assert_eq(out, "undefined\n")
end)

test("function hoisting with var destructured object — ok", function()
  local out = run_js([[
    function a() {}
    var {a} = {};
    console.log(typeof a);
  ]])
  assert_eq(out, "undefined\n")
end)

test("function hoisting with let destructured object — SyntaxError", function()
  local ok, err = pcall(
    run_js,
    [[
    function a() {}
    let {a} = {};
  ]]
  )
  assert_eq(ok, false)
  assert(err:find("SyntaxError"), "expected SyntaxError, got: " .. tostring(err))
end)

test("function hoisting with var multi-prop destructured object — ok", function()
  local out = run_js([[
    function a() {}
    var {a, b} = {b: 2};
    console.log(typeof a, b);
  ]])
  assert_eq(out, "undefined 2\n")
end)

test("function hoisting with var simple declaration — ok", function()
  local out = run_js([[
    function a() {}
    var a = 1;
    console.log(a);
  ]])
  assert_eq(out, "1\n")
end)

test("function hoisting with var rest destructured object — ok", function()
  local out = run_js([[
    function a() {}
    var {...a} = {x: 1};
    console.log(a.x);
  ]])
  assert_eq(out, "1\n")
end)
