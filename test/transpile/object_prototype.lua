local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local run_js, expr_code = H.run_js, H.expr_code

-- ============================================================================
-- Unit tests — _ljs_object_prototype
-- ============================================================================

test("_ljs_object_prototype declared before helpers", function()
  local code = H.transpile_ok("let x = 1;")
  local obj_proto_pos = code:find("local _ljs_object_prototype", 1, true)
  local ctor_pos = code:find("local function _ljs_ctor", 1, true)
  assert(obj_proto_pos, "expected _ljs_object_prototype declaration")
  assert(ctor_pos, "expected _ljs_ctor definition")
  assert(obj_proto_pos < ctor_pos, "_ljs_object_prototype must come before _ljs_ctor")
end)

test("Object.prototype is _ljs_object_prototype", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("Object.prototype = _ljs_object_prototype", 1, true),
    "expected Object.prototype assignment"
  )
end)

test("_ljs_object_prototype has toString", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("_ljs_object_prototype.toString", 1, true), "expected toString method")
end)

test("_ljs_object_prototype has hasOwnProperty", function()
  local code = H.transpile_ok("let x = 1;")
  assert(
    code:find("_ljs_object_prototype.hasOwnProperty", 1, true),
    "expected hasOwnProperty method"
  )
end)

-- ============================================================================
-- Integration tests — Object.prototype methods
-- ============================================================================

test("toString returns [object Object]", function()
  local out = run_js([[
    let o = {};
    console.log(o.toString());
  ]])
  assert_eq(out, "[object Object]\n")
end)

test("hasOwnProperty returns true for own property", function()
  local out = run_js([[
    let o = { x: 1 };
    console.log(o.hasOwnProperty("x"));
    console.log(o.hasOwnProperty("y"));
  ]])
  assert_eq(out, "true\nfalse\n")
end)

test("valueOf returns the object itself", function()
  local out = run_js([[
    let o = { x: 1 };
    let v = o.valueOf();
    console.log(v === o);
  ]])
  assert_eq(out, "true\n")
end)

test("constructor instances inherit Object.prototype methods", function()
  local out = run_js([[
    function Foo(x) { this.x = x; }
    let f = new Foo(5);
    console.log(f.hasOwnProperty("x"));
    console.log(f.toString());
  ]])
  assert_eq(out, "true\n[object Object]\n")
end)

test("class instances inherit Object.prototype methods", function()
  local out = run_js([[
    class Foo {
      constructor(x) { this.x = x; }
    }
    let f = new Foo(5);
    console.log(f.hasOwnProperty("x"));
    console.log(f.toString());
  ]])
  assert_eq(out, "true\n[object Object]\n")
end)

test("Object.create(null) has no toString", function()
  local out = run_js([[
    let o = Object.create(null);
    console.log(o.toString === undefined);
  ]])
  assert_eq(out, "true\n")
end)

test("prototype chain: instance -> class proto -> Object.prototype", function()
  local out = run_js([[
    class Animal {
      constructor(name) { this.name = name; }
    }
    let a = new Animal("cat");
    console.log(a.hasOwnProperty("name"));
    console.log(a.toString());
    console.log(a.valueOf() === a);
  ]])
  assert_eq(out, "true\n[object Object]\ntrue\n")
end)

test("Object.prototype.constructor === Object", function()
  local out = run_js([[
    console.log(Object.prototype.constructor === Object);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ getter: ({}).__proto__ === Object.prototype", function()
  local out = run_js([[
    console.log(({}).__proto__ === Object.prototype);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ getter: Object.prototype.__proto__ is null", function()
  local out = run_js([[
    console.log(Object.prototype.__proto__);
  ]])
  assert_eq(out, "null\n")
end)

test("__proto__ setter: reassign prototype and inherit", function()
  local out = run_js([[
    let parent = { x: 42 };
    let obj = {};
    obj.__proto__ = parent;
    console.log(obj.x);
  ]])
  assert_eq(out, "42\n")
end)

test("__proto__ setter: set to null breaks prototype chain", function()
  local out = run_js([[
    let obj = {};
    obj.__proto__ = null;
    console.log(obj.toString === undefined);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ setter: non-object value is no-op", function()
  local out = run_js([[
    let obj = {};
    obj.__proto__ = 42;
    console.log(obj.toString === undefined);
  ]])
  assert_eq(out, "false\n")
end)

test("__proto__ computed access returns prototype", function()
  local out = run_js([[
    let obj = {};
    console.log(obj["__proto__"] === Object.prototype);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ on constructor instance", function()
  local out = run_js([[
    function Foo() {}
    let f = new Foo();
    console.log(f.__proto__ === Foo.prototype);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ getter on function returns Function.prototype", function()
  local out = run_js([[
    function foo() {}
    console.log(foo.__proto__ === Function.prototype);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ computed setter: obj[\"__proto__\"] = parent", function()
  local out = run_js([[
    let parent = { x: 99 };
    let obj = {};
    obj["__proto__"] = parent;
    console.log(obj.x);
  ]])
  assert_eq(out, "99\n")
end)

test("__proto__ assignment expression returns value", function()
  local out = run_js([[
    let parent = { x: 7 };
    let obj = {};
    let r = (obj.__proto__ = parent);
    console.log(r === parent);
  ]])
  assert_eq(out, "true\n")
end)

test("__proto__ destructuring target", function()
  local out = run_js([[
    let parent = { x: 55 };
    let obj = {};
    [obj.__proto__] = [parent];
    console.log(obj.__proto__ === parent);
  ]])
  assert_eq(out, "true\n")
end)

test("string primitive __proto__ returns String.prototype", function()
  local out = run_js([[
    console.log("hello".__proto__ === String.prototype);
  ]])
  assert_eq(out, "true\n")
end)
