local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local expr_code, run_js = H.expr_code, H.run_js

-- ============================================================================
-- Unit tests
-- ============================================================================

test("Object.create emits _ljs_call_member", function()
  local code = expr_code("Object.create(null)")
  assert(code:find("_ljs_call_member"))
end)

test("console.log emits _ljs_call_member, not _ljs_log", function()
  local code = expr_code('console.log("x")')
  assert(code:find("_ljs_call_member"))
  assert(not code:find("_ljs_log"))
end)

test("Object and console helpers always emitted", function()
  local code = H.transpile_ok("let x = 1;")
  assert(code:find("local Object = _ljs_ctor"), "expected Object init")
  assert(code:find("local console = _ljs_object"), "expected console init")
end)

-- ============================================================================
-- Integration tests: basic prototype
-- ============================================================================

test("inherited data property", function()
  local out = run_js([[
    let proto = { x: 1 };
    let o = Object.create(proto);
    console.log(o.x);
  ]])
  assert_eq(out, "1\n")
end)

test("inherited method with correct this", function()
  local out = run_js([[
    let proto = { getX() { return this.x; } };
    let o = Object.create(proto);
    o.x = 2;
    console.log(o.getX());
  ]])
  assert_eq(out, "2\n")
end)

test("own property shadows prototype", function()
  local out = run_js([[
    let proto = { x: 1 };
    let o = Object.create(proto);
    o.x = 2;
    console.log(o.x);
    console.log(proto.x);
  ]])
  assert_eq(out, "2\n1\n")
end)

test("Object.create(null) creates null-prototype object", function()
  local out = run_js([[
    let o = Object.create(null);
    o.x = 5;
    console.log(o.x);
  ]])
  assert_eq(out, "5\n")
end)

test("delete own shadow reveals prototype", function()
  local out = run_js([[
    let proto = { x: 1 };
    let o = Object.create(proto);
    o.x = 2;
    delete o.x;
    console.log(o.x);
  ]])
  assert_eq(out, "1\n")
end)

test("'in' walks prototype chain", function()
  local out = run_js([[
    let proto = { x: 1 };
    let o = Object.create(proto);
    console.log("x" in o);
  ]])
  assert_eq(out, "true\n")
end)

test("multi-level prototype chain", function()
  local out = run_js([[
    let a = { x: 1 };
    let b = Object.create(a);
    let c = Object.create(b);
    console.log(c.x);
  ]])
  assert_eq(out, "1\n")
end)

test("dynamic method addition to proto visible to children", function()
  local out = run_js([[
    let proto = { x: 1 };
    let o = Object.create(proto);
    proto.getX = function() { return this.x; };
    console.log(o.getX());
  ]])
  assert_eq(out, "1\n")
end)

test("console.log works as runtime object", function()
  local out = run_js('console.log("works");')
  assert_eq(out, "works\n")
end)

test("console.log extraction works", function()
  local out = run_js([[
    let log = console.log;
    log("extracted");
  ]])
  assert_eq(out, "extracted\n")
end)

test("console.log with multiple args", function()
  local out = run_js('console.log("a", "b");')
  assert(out:find("a") and out:find("b"))
end)
