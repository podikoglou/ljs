local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local expr_code, run_js, emit_ok = H.expr_code, H.run_js, H.emit_ok

test("_ljs_ctor wrapping for class", function()
  local code = H.transpile_ok("class Foo {}")
  assert(
    code:find("local Foo = _ljs_ctor(function(_ljs_this)", nil, true),
    "expected _ljs_ctor wrapping"
  )
end)

test("constructor body emitted", function()
  local code = H.transpile_ok("class Foo { constructor(x) { this.x = x; } }")
  assert(
    code:find("local Foo = _ljs_ctor(function(_ljs_this, x)", nil, true),
    "expected ctor with params"
  )
  assert(code:find("_ljs_to_object%(_ljs_arrow_this%)%.x"), "expected this.x assignment")
end)

test("method assigned to prototype", function()
  local code = H.transpile_ok("class Foo { method() { return 1; } }")
  assert(code:find('Foo%.prototype%["method"%]'), "expected prototype assignment")
end)

test("static method assigned to constructor", function()
  local code = H.transpile_ok("class Foo { static create() { return 1; } }")
  assert(code:find('Foo%["create"%]'), "expected static on constructor")
  local ecode = emit_ok("class Foo { static create() { return 1; } }")
  assert(not ecode:find('Foo%.prototype%["create"%]'), "static should NOT be on prototype")
end)

test("extends sets up prototype chain", function()
  local code = H.transpile_ok("class Dog extends Animal {}")
  assert(
    code:find("Dog%.prototype = _ljs_object_create%(nil, Animal%.prototype%)"),
    "expected prototype chain setup"
  )
end)

test("extends restores constructor", function()
  local code = H.transpile_ok("class Dog extends Animal {}")
  assert(code:find("Dog%.prototype%.constructor = Dog"), "expected constructor restore")
end)

test("default ctor with extends forwards args", function()
  local code = H.transpile_ok("class Dog extends Animal {}")
  assert(code:find("function%(_ljs_this, %.%.%.%)"), "expected vararg params")
  assert(
    code:find("_ljs_call_this%(Animal, _ljs_arrow_this, %.%.%.%)"),
    "expected super forwarding"
  )
end)

test("super() in constructor", function()
  local code = H.transpile_ok('class Dog extends Animal { constructor() { super("Rex"); } }')
  assert(
    code:find('_ljs_call_this%(Animal, _ljs_arrow_this, "Rex"%)'),
    "expected super call via _ljs_call_this"
  )
end)

test("super.method() uses _ljs_super_call", function()
  local code = H.transpile_ok("class Dog extends Animal { speak() { return super.speak(); } }")
  assert(code:find("_ljs_super_call"), "expected _ljs_super_call")
  assert(code:find("Animal%.prototype"), "expected parent prototype reference")
end)

test("super.prop property access", function()
  local code = H.transpile_ok("class Dog extends Animal { get() { return super.x; } }")
  assert(code:find("_ljs_to_object%(Animal%.prototype%)%.x"), "expected super property access")
end)

test("basic class construct + method call", function()
  local out = run_js([[
    class Foo {
      constructor(x) { this.x = x; }
      get() { return this.x; }
    }
    let f = new Foo(42);
    console.log(f.get());
  ]])
  assert_eq(out, "42\n")
end)

test("typeof class is function", function()
  local out = run_js([[
    class Foo {}
    console.log(typeof Foo);
  ]])
  assert_eq(out, "function\n")
end)

test("Foo.prototype.constructor === Foo", function()
  local out = run_js([[
    class Foo {}
    console.log(Foo.prototype.constructor === Foo);
  ]])
  assert_eq(out, "true\n")
end)

test("instanceof own class", function()
  local out = run_js([[
    class Foo {}
    let f = new Foo();
    console.log(f instanceof Foo);
  ]])
  assert_eq(out, "true\n")
end)

test("class expression works", function()
  local out = run_js([[
    let Foo = class { constructor(x) { this.x = x; } };
    let f = new Foo(5);
    console.log(f.x);
  ]])
  assert_eq(out, "5\n")
end)

test("named class expression", function()
  local out = run_js([[
    let F = class Foo { constructor() { this.name = "test"; } };
    let f = new F();
    console.log(f.name);
  ]])
  assert_eq(out, "test\n")
end)

test("extends inherits methods", function()
  local out = run_js([[
    class Animal {
      constructor(name) { this.name = name; }
      speak() { return this.name + " speaks"; }
    }
    class Dog extends Animal {}
    let d = new Dog("Rex");
    console.log(d.speak());
  ]])
  assert_eq(out, "Rex speaks\n")
end)

test("instanceof parent class", function()
  local out = run_js([[
    class Animal {}
    class Dog extends Animal {}
    let d = new Dog();
    console.log(d instanceof Animal);
  ]])
  assert_eq(out, "true\n")
end)

test("instanceof own class with extends", function()
  local out = run_js([[
    class Animal {}
    class Dog extends Animal {}
    let d = new Dog();
    console.log(d instanceof Dog);
  ]])
  assert_eq(out, "true\n")
end)

test("override method", function()
  local out = run_js([[
    class Animal {
      constructor(name) { this.name = name; }
      speak() { return this.name + " speaks"; }
    }
    class Dog extends Animal {
      speak() { return this.name + " barks"; }
    }
    let d = new Dog("Rex");
    console.log(d.speak());
  ]])
  assert_eq(out, "Rex barks\n")
end)

test("super.method() in override", function()
  local out = run_js([[
    class Animal {
      constructor(name) { this.name = name; }
      speak() { return this.name + " speaks"; }
    }
    class Dog extends Animal {
      speak() { return super.speak() + " loudly"; }
    }
    let d = new Dog("Rex");
    console.log(d.speak());
  ]])
  assert_eq(out, "Rex speaks loudly\n")
end)

test("static method call", function()
  local out = run_js([[
    class Foo {
      static hello() { return "world"; }
    }
    console.log(Foo.hello());
  ]])
  assert_eq(out, "world\n")
end)

test("static method this is class", function()
  local out = run_js([[
    class Foo {
      static identity() { return this; }
    }
    console.log(Foo.identity() === Foo);
  ]])
  assert_eq(out, "true\n")
end)

test("three levels of inheritance", function()
  local out = run_js([[
    class Animal {
      constructor(name) { this.name = name; }
      speak() { return this.name + " speaks"; }
    }
    class Dog extends Animal {
      speak() { return super.speak() + " (dog)"; }
    }
    class Puppy extends Dog {
      speak() { return super.speak() + " (puppy)"; }
    }
    let p = new Puppy("Tiny");
    console.log(p.speak());
  ]])
  assert_eq(out, "Tiny speaks (dog) (puppy)\n")
end)

test("class with no methods — instance is object", function()
  local out = run_js([[
    class Foo {}
    let f = new Foo();
    console.log(typeof f);
  ]])
  assert_eq(out, "object\n")
end)

test("explicit super() in constructor sets properties", function()
  local out = run_js([[
    class A {
      constructor() { this.x = 1; }
    }
    class B extends A {
      constructor() { super(); }
    }
    let b = new B();
    console.log(b.x);
  ]])
  assert_eq(out, "1\n")
end)

test("explicit super() with args forwards them", function()
  local out = run_js([[
    class A {
      constructor(x) { this.x = x; }
    }
    class B extends A {
      constructor() { super(42); }
    }
    let b = new B();
    console.log(b.x);
  ]])
  assert_eq(out, "42\n")
end)

test("super() as expression returns this", function()
  local out = run_js([[
    class A { constructor() { this.x = 1; } }
    class B extends A {
      constructor() {
        const result = super();
        console.log(result === this);
      }
    }
    new B();
  ]])
  assert_eq(out, "true\n")
end)

test("super() with spread args in constructor", function()
  local code = H.transpile_ok("class B extends A { constructor() { super(...args); } }")
  assert(code:find("_ljs_call_this"), "expected _ljs_call_this for super call")
  assert(code:find("_ljs_spread_build"), "expected _ljs_spread_build for spread args")
end)

test("super() with spread args forwards correctly", function()
  local out = run_js([[
    class A { constructor(x, y) { this.sum = x + y; } }
    class B extends A { constructor() { super(...[3, 7]); } }
    let b = new B();
    console.log(b.sum);
  ]])
  assert_eq(out, "10\n")
end)

test("super() with mixed literal and spread args", function()
  local out = run_js([[
    class A { constructor(x, y, z) { this.total = x + y + z; } }
    class B extends A { constructor(a) { super(1, ...a); } }
    let b = new B([2, 3]);
    console.log(b.total);
  ]])
  assert_eq(out, "6\n")
end)

test("super() with spread and instanceof check", function()
  local out = run_js([[
    class A { constructor(x, y) { this.x = x; this.y = y; } }
    class B extends A { constructor(...args) { super(...args); } }
    let b = new B(10, 20);
    console.log(b.x, b.y, b instanceof A, b instanceof B);
  ]])
  assert_eq(out, "10 20 true true\n")
end)
