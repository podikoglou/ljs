local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local expr_code, run_js = H.expr_code, H.run_js

-- ============================================================================
-- Unit tests — helpers emitted
-- ============================================================================

test("_ljs_ctor helper emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("local function _ljs_ctor", nil, true), "expected _ljs_ctor helper")
end)

test("_ljs_new helper emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("local function _ljs_new", nil, true), "expected _ljs_new helper")
end)

test("_ljs_instanceof helper emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("local function _ljs_instanceof", nil, true), "expected _ljs_instanceof helper")
end)

-- ============================================================================
-- Unit tests — new expression
-- ============================================================================

test("new Foo() emits _ljs_new", function()
  local code = expr_code("new Foo()")
  assert_eq(code, "_ljs_new(Foo)")
end)

test("new Foo(a, b) emits _ljs_new with args", function()
  local code = expr_code("new Foo(a, b)")
  assert_eq(code, "_ljs_new(Foo, a, b)")
end)

test("new Foo.bar() emits _ljs_new with member callee", function()
  local code = expr_code("new Foo.bar()")
  assert_eq(code, "_ljs_new(Foo.bar)")
end)

-- ============================================================================
-- Unit tests — instanceof
-- ============================================================================

test("x instanceof Foo emits _ljs_instanceof", function()
  local code = expr_code("x instanceof Foo")
  assert_eq(code, "_ljs_instanceof(x, Foo)")
end)

-- ============================================================================
-- Unit tests — FunctionDeclaration wrapping
-- ============================================================================

test("function declaration wrapped in _ljs_ctor", function()
  local code = H.transpile_ok("function foo(a) { return a; }")
  assert(
    code:find("local foo\nfoo = _ljs_ctor(function", nil, true),
    "expected two-step _ljs_ctor wrapping"
  )
end)

test("function expression wrapped in _ljs_ctor", function()
  local code = H.transpile_ok("let f = function(x) { return x; };")
  assert(code:find("_ljs_ctor(function", nil, true), "expected _ljs_ctor wrapping")
end)

test("method shorthand wrapped in _ljs_fn not _ljs_ctor", function()
  local code = H.transpile_ok("let o = { m() { return 1; } };")
  assert(
    code:find("m = _ljs_fn(function(_ljs_this)", nil, true),
    "expected _ljs_fn wrapping for method"
  )
  assert(not code:find("m = _ljs_ctor("), "should NOT be _ljs_ctor wrapped")
end)

test("arrow function wrapped in _ljs_fn not _ljs_ctor", function()
  local code = H.transpile_ok("let f = (x) => x + 1;")
  assert(code:find("local f\nf = _ljs_fn(", nil, true), "expected arrow wrapped in _ljs_fn")
end)

-- ============================================================================
-- Unit tests — typeof for constructors
-- ============================================================================

test("typeof on constructor in expression", function()
  local code = expr_code('typeof Foo === "function"')
  assert(code:find("_ljs_typeof", nil, true), "expected _ljs_typeof call")
end)

-- ============================================================================
-- Integration tests — constructors
-- ============================================================================

test("basic constructor — this assignment", function()
  local out = run_js([[
    function Foo(x) { this.x = x; }
    let f = new Foo(42);
    console.log(f.x);
  ]])
  assert_eq(out, "42\n")
end)

test("constructor prototype method", function()
  local out = run_js([[
    function Animal(name) { this.name = name; }
    Animal.prototype.getName = function() { return this.name; };
    let d = new Animal("Rex");
    console.log(d.getName());
  ]])
  assert_eq(out, "Rex\n")
end)

test("Foo.prototype.constructor === Foo", function()
  local out = run_js([[
    function Foo() {}
    console.log(Foo.prototype.constructor === Foo);
  ]])
  assert_eq(out, "true\n")
end)

test("own property shadows prototype", function()
  local out = run_js([[
    function Foo() { this.x = 1; }
    Foo.prototype.x = 10;
    let f = new Foo();
    console.log(f.x);
  ]])
  assert_eq(out, "1\n")
end)

test("delete own property reveals prototype", function()
  local out = run_js([[
    function Foo() { this.x = 1; }
    Foo.prototype.x = 10;
    let f = new Foo();
    delete f.x;
    console.log(f.x);
  ]])
  assert_eq(out, "10\n")
end)

test("constructor returns object — overrides instance", function()
  local out = run_js([[
    function Foo() { return { x: 99 }; }
    let f = new Foo();
    console.log(f.x);
  ]])
  assert_eq(out, "99\n")
end)

test("constructor returns primitive — instance returned", function()
  local out = run_js([[
    function Foo() { return 42; }
    let f = new Foo();
    console.log(typeof f);
  ]])
  assert_eq(out, "object\n")
end)

test("new without parens", function()
  local out = run_js([[
    function Foo() { this.x = 1; }
    let f = new Foo;
    console.log(f.x);
  ]])
  assert_eq(out, "1\n")
end)

-- ============================================================================
-- Integration tests — instanceof
-- ============================================================================

test("instanceof true", function()
  local out = run_js([[
    function Foo() {}
    let f = new Foo();
    console.log(f instanceof Foo);
  ]])
  assert_eq(out, "true\n")
end)

test("instanceof false — different constructor", function()
  local out = run_js([[
    function Foo() {}
    function Bar() {}
    let f = new Foo();
    console.log(f instanceof Bar);
  ]])
  assert_eq(out, "false\n")
end)

test("instanceof with prototype chain", function()
  local out = run_js([[
    function Animal() {}
    function Dog() {}
    Dog.prototype = Object.create(Animal.prototype);
    Dog.prototype.constructor = Dog;
    let d = new Dog();
    console.log(d instanceof Dog);
    console.log(d instanceof Animal);
  ]])
  assert_eq(out, "true\ntrue\n")
end)

test("null instanceof Foo — false", function()
  local out = run_js([[
    function Foo() {}
    console.log(null instanceof Foo);
  ]])
  assert_eq(out, "false\n")
end)

test("42 instanceof Foo — false", function()
  local out = run_js([[
    function Foo() {}
    console.log(42 instanceof Foo);
  ]])
  assert_eq(out, "false\n")
end)

-- ============================================================================
-- Integration tests — typeof
-- ============================================================================

test("typeof constructor is function", function()
  local out = run_js([[
    function Foo() {}
    console.log(typeof Foo);
  ]])
  assert_eq(out, "function\n")
end)

test("typeof Object is function", function()
  local out = run_js([[console.log(typeof Object);]])
  assert_eq(out, "function\n")
end)

test("typeof instance is object", function()
  local out = run_js([[
    function Foo() {}
    let f = new Foo();
    console.log(typeof f);
  ]])
  assert_eq(out, "object\n")
end)

test("typeof plain object is object", function()
  local out = run_js([[console.log(typeof {a: 1});]])
  assert_eq(out, "object\n")
end)

-- ============================================================================
-- Integration tests — runtime Object constructor
-- ============================================================================

test("new Object() creates empty object", function()
  local out = run_js([[
    let o = new Object();
    console.log(typeof o);
  ]])
  assert_eq(out, "object\n")
end)

test("Object.create still works after ctor wrapping", function()
  local out = run_js([[
    let proto = { x: 1 };
    let o = Object.create(proto);
    console.log(o.x);
  ]])
  assert_eq(out, "1\n")
end)

-- ============================================================================
-- Integration tests — 'in' operator with prototypes
-- ============================================================================

test("'in' operator walks prototype chain from constructor", function()
  local out = run_js([[
    function Foo() {}
    Foo.prototype.method = function() {};
    let f = new Foo();
    console.log("method" in f);
  ]])
  assert_eq(out, "true\n")
end)
