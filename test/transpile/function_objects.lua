local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js = H.run_js

-- ============================================================================
-- Unit tests — runtime methods are wrapped in _ljs_fn
-- ============================================================================

test("_ljs_function_prototype.call is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("_ljs_function_prototype.call = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped call"
  )
end)

test("_ljs_function_prototype.apply is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("_ljs_function_prototype.apply = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped apply"
  )
end)

test("_ljs_object_prototype.toString is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("_ljs_object_prototype.toString = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped toString"
  )
end)

test("_ljs_object_prototype.hasOwnProperty is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("_ljs_object_prototype.hasOwnProperty = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped hasOwnProperty"
  )
end)

test("_ljs_object_prototype.valueOf is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("_ljs_object_prototype.valueOf = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped valueOf"
  )
end)

test("Object.create is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("Object.create = _ljs_fn(", 1, true), "expected _ljs_fn-wrapped Object.create")
end)

test("Array.prototype.push is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Array.prototype.push = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped push"
  )
end)

test("Array.prototype.pop is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Array.prototype.pop = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped pop"
  )
end)

test("Array.prototype.join is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Array.prototype.join = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped join"
  )
end)

test("Array.prototype.toString is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Array.prototype.toString = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped Array.prototype.toString"
  )
end)

test("Error.prototype.toString is wrapped in _ljs_fn", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Error.prototype.toString = _ljs_fn(function", 1, true),
    "expected _ljs_fn-wrapped Error.prototype.toString"
  )
end)

-- ============================================================================
-- Integration tests — extracting methods and calling .call()/.apply()
-- ============================================================================

-- Object.prototype methods extracted and called with .call()

test("extracted hasOwnProperty.call works", function()
  local out = run_js([[
    let o = { x: 1 };
    let fn = o.hasOwnProperty;
    console.log(fn.call(o, "x"));
    console.log(fn.call(o, "y"));
  ]])
  assert_eq(out, "true\nfalse\n")
end)

test("extracted toString.call works", function()
  local out = run_js([[
    let o = { a: 1 };
    let fn = o.toString;
    console.log(fn.call(o));
  ]])
  assert_eq(out, "[object Object]\n")
end)

test("extracted valueOf.call works", function()
  local out = run_js([[
    let o = { a: 1 };
    let fn = o.valueOf;
    console.log(fn.call(o) === o);
  ]])
  assert_eq(out, "true\n")
end)

-- Function.prototype methods extracted and called with .call()

test("extracted Function.prototype.call.call works", function()
  local out = run_js([[
    function greet() { return "Hello, " + this.name; }
    let callFn = greet.call;
    console.log(callFn.call(greet, { name: "World" }));
  ]])
  assert_eq(out, "Hello, World\n")
end)

test("extracted Function.prototype.apply.call works", function()
  local out = run_js([[
    function add(a, b) { return a + b; }
    let applyFn = add.apply;
    console.log(applyFn.call(add, null, [3, 4]));
  ]])
  assert_eq(out, "7\n")
end)

test("extracted Function.prototype.call.apply works", function()
  local out = run_js([[
    function greet() { return "Hello, " + this.name; }
    let callFn = greet.call;
    console.log(callFn.apply(greet, [{ name: "Applied" }]));
  ]])
  assert_eq(out, "Hello, Applied\n")
end)

-- Array.prototype methods extracted and called with .call()

test("extracted Array.prototype.push.call works", function()
  local out = run_js([[
    let arr = [1, 2];
    let push = arr.push;
    let len = push.call(arr, 3, 4);
    console.log(arr.length);
    console.log(len);
    console.log(arr[2]);
    console.log(arr[3]);
  ]])
  assert_eq(out, "4\n4\n3\n4\n")
end)

test("extracted Array.prototype.pop.call works", function()
  local out = run_js([[
    let arr = [1, 2, 3];
    let pop = arr.pop;
    let val = pop.call(arr);
    console.log(val);
    console.log(arr.length);
  ]])
  assert_eq(out, "3\n2\n")
end)

test("extracted Array.prototype.join.call works", function()
  local out = run_js([[
    let arr = [1, 2, 3];
    let join = arr.join;
    console.log(join.call(arr, "-"));
  ]])
  assert_eq(out, "1-2-3\n")
end)

test("extracted Array.prototype.toString.call works", function()
  local out = run_js([[
    let arr = [1, 2, 3];
    let toString = arr.toString;
    console.log(toString.call(arr));
  ]])
  assert_eq(out, "1,2,3\n")
end)

-- Error.prototype methods extracted and called

test("extracted Error.prototype.toString.call works", function()
  local out = run_js([[
    let e = new Error("test error");
    let fn = e.toString;
    console.log(fn.call(e));
  ]])
  assert_eq(out, "Error: test error\n")
end)

test("extracted TypeError.prototype.toString.call works", function()
  local out = run_js([[
    let e = new TypeError("bad type");
    let fn = e.toString;
    console.log(fn.call(e));
  ]])
  assert_eq(out, "TypeError: bad type\n")
end)

-- Object.create extracted and called

test("extracted Object.create.call works", function()
  local out = run_js([[
    let create = Object.create;
    let proto = { greet: "hello" };
    let o = create.call(Object, proto);
    console.log(o.greet);
  ]])
  assert_eq(out, "hello\n")
end)

-- Direct prototype method calls (without extraction)

test("Object.prototype.hasOwnProperty.call(obj, key) works", function()
  local out = run_js([[
    let o = { x: 1 };
    console.log(Object.prototype.hasOwnProperty.call(o, "x"));
    console.log(Object.prototype.hasOwnProperty.call(o, "y"));
  ]])
  assert_eq(out, "true\nfalse\n")
end)

test("Array.prototype.push.call(arr, val) works", function()
  local out = run_js([[
    let arr = [1];
    Array.prototype.push.call(arr, 2, 3);
    console.log(arr.length);
    console.log(arr[1]);
    console.log(arr[2]);
  ]])
  assert_eq(out, "3\n2\n3\n")
end)

test("Array.prototype.pop.call(arr) works", function()
  local out = run_js([[
    let arr = [10, 20];
    let val = Array.prototype.pop.call(arr);
    console.log(val);
    console.log(arr.length);
  ]])
  assert_eq(out, "20\n1\n")
end)

-- Class methods extracted and called with .call()

test("extracted class method .call works", function()
  local out = run_js([[
    class Greeter {
      greet() { return "Hello, " + this.name; }
    }
    let g = new Greeter();
    g.name = "World";
    let fn = g.greet;
    console.log(fn.call(g));
    console.log(fn.call({ name: "Other" }));
  ]])
  assert_eq(out, "Hello, World\nHello, Other\n")
end)

test("extracted class static method .call works", function()
  local out = run_js([[
    class Foo {
      static identity(x) { return x; }
    }
    let fn = Foo.identity;
    console.log(fn.call(Foo, 42));
  ]])
  assert_eq(out, "42\n")
end)

test("class expression method .call works", function()
  local out = run_js([[
    let Foo = class {
      double(x) { return x * 2; }
    };
    let f = new Foo();
    let fn = f.double;
    console.log(fn.call(f, 5));
  ]])
  assert_eq(out, "10\n")
end)

test("class with extends: extracted method .call works", function()
  local out = run_js([[
    class Animal {
      speak() { return this.name + " speaks"; }
    }
    class Dog extends Animal {
      bark() { return this.name + " barks"; }
    }
    let d = new Dog();
    d.name = "Rex";
    let fn = d.speak;
    console.log(fn.call(d));
    let fn2 = d.bark;
    console.log(fn2.call(d));
  ]])
  assert_eq(out, "Rex speaks\nRex barks\n")
end)

-- Method on extracted function still works (no regression)

test("extracted method still works with .apply", function()
  local out = run_js([[
    let arr = [1, 2];
    let push = arr.push;
    push.apply(arr, [3, 4]);
    console.log(arr.length);
    console.log(arr[2]);
    console.log(arr[3]);
  ]])
  assert_eq(out, "4\n3\n4\n")
end)

-- Chained .call (call.call) — the ultimate edge case

test("Function.prototype.call.call(fn, thisArg) works", function()
  local out = run_js([[
    function greet() { return "hi " + this.name; }
    console.log(Function.prototype.call.call(greet, { name: "test" }));
  ]])
  assert_eq(out, "hi test\n")
end)

test("Function.prototype.apply.call(fn, thisArg, args) works", function()
  local out = run_js([[
    function add(a, b) { return a + b; }
    console.log(Function.prototype.apply.call(add, null, [10, 20]));
  ]])
  assert_eq(out, "30\n")
end)

-- hasOwnProperty on extracted method itself

test("extracted method hasOwnProperty via Function.prototype chain", function()
  local out = run_js([[
    let arr = [1, 2];
    let push = arr.push;
    console.log(typeof push.call);
    console.log(push.hasOwnProperty("call") === false);
  ]])
  assert_eq(out, "function\ntrue\n")
end)

-- console methods (already wrapped, verify they still work)

test("console.log extraction and .call still works", function()
  local out = run_js([[
    let log = console.log;
    log.call(null, "extracted");
  ]])
  assert_eq(out, "extracted\n")
end)

test("console.error extraction and .call still works", function()
  local out = run_js([[
    let err = console.error;
    err.call(null, "err msg");
  ]])
  assert_eq(out, "err msg\n")
end)

-- Math methods (already wrapped, verify they still work via .call)

test("Math.max.call works", function()
  local out = run_js([[
    let m = Math.max;
    console.log(m.call(Math, 1, 5, 3));
  ]])
  assert_eq(out, "5\n")
end)

test("Math.floor.apply works", function()
  local out = run_js([[
    let f = Math.floor;
    console.log(f.apply(Math, [3.7]));
  ]])
  assert_eq(out, "3\n")
end)

-- Array.isArray, Array.from, Array.of (already wrapped)

test("Array.isArray.call works", function()
  local out = run_js([[
    let isArr = Array.isArray;
    console.log(isArr.call(Array, [1, 2]));
    console.log(isArr.call(Array, "hello"));
  ]])
  assert_eq(out, "true\nfalse\n")
end)

test("Array.of.call works", function()
  local out = run_js([[
    let makeArr = Array.of;
    let arr = makeArr.call(Array, 1, 2, 3);
    console.log(arr.length);
    console.log(arr[0]);
  ]])
  assert_eq(out, "3\n1\n")
end)

-- JSON.parse and JSON.stringify (already wrapped)

test("JSON.parse.call works", function()
  local out = run_js([[
    let parse = JSON.parse;
    let obj = parse.call(JSON, '{"a":1}');
    console.log(obj.a);
  ]])
  assert_eq(out, "1\n")
end)

test("JSON.stringify.call works", function()
  local out = run_js([[
    let stringify = JSON.stringify;
    let s = stringify.call(JSON, { x: 42 });
    console.log(s);
  ]])
  assert_eq(out, '{"x":42}\n')
end)

-- typeof on extracted methods

test("typeof extracted method is function", function()
  local out = run_js([[
    let arr = [1];
    console.log(typeof arr.push);
    let push = arr.push;
    console.log(typeof push);
    let obj = {};
    console.log(typeof obj.hasOwnProperty);
    let hop = obj.hasOwnProperty;
    console.log(typeof hop);
  ]])
  assert_eq(out, "function\nfunction\nfunction\nfunction\n")
end)
