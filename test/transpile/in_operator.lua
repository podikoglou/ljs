local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local expr_code, run_js = H.expr_code, H.run_js

-- ============================================================================
-- Unit tests — 'in' operator transpilation
-- ============================================================================

test('"x" in obj transpiles to (obj["x"] ~= nil)', function()
  assert_eq(expr_code('"x" in obj'), '(obj["x"] ~= nil)')
end)

test("0 in arr transpiles to (arr[(0) + 1] ~= nil)", function()
  assert_eq(expr_code("0 in arr"), "(arr[(0) + 1] ~= nil)")
end)

test("n in arr transpiles to (arr[(n) + 1] ~= nil)", function()
  assert_eq(expr_code("n in arr"), "(arr[(n) + 1] ~= nil)")
end)

test('"x" in obj.prop transpiles to (_ljs_to_object(obj).prop["x"] ~= nil)', function()
  assert_eq(expr_code('"x" in obj.prop'), '(_ljs_to_object(obj).prop["x"] ~= nil)')
end)

test("key in obj transpiles to (obj[(key) + 1] ~= nil)", function()
  assert_eq(expr_code("key in obj"), "(obj[(key) + 1] ~= nil)")
end)

-- ============================================================================
-- Integration tests — runtime behavior
-- ============================================================================

test('"x" in {x: 1} is true', function()
  local out = run_js('console.log("x" in {x: 1});')
  assert_eq(out, "true\n")
end)

test('"y" in {x: 1} is false', function()
  local out = run_js('console.log("y" in {x: 1});')
  assert_eq(out, "false\n")
end)

test("0 in [1, 2, 3] is true", function()
  local out = run_js("console.log(0 in [1, 2, 3]);")
  assert_eq(out, "true\n")
end)

test("3 in [1, 2, 3] is false", function()
  local out = run_js("console.log(3 in [1, 2, 3]);")
  assert_eq(out, "false\n")
end)

test('"x" in obj && "y" in obj works', function()
  local out = run_js('console.log("x" in {x: 1} && "y" in {x: 1, y: 2});')
  assert_eq(out, "true\n")
end)

test('"x" in obj || "y" in obj works', function()
  local out = run_js('console.log("x" in {x: 1} || "z" in {x: 1});')
  assert_eq(out, "true\n")
end)

test("in operator in if condition", function()
  local out = run_js([[
    let r = "no";
    if ("x" in {x: 1}) { r = "yes"; }
    console.log(r);
  ]])
  assert_eq(out, "yes\n")
end)

test("in operator in ternary", function()
  local out = run_js('console.log("x" in {x: 1} ? "yes" : "no");')
  assert_eq(out, "yes\n")
end)

test("in operator in variable init", function()
  local out = run_js([[
    let has = "x" in {x: 1};
    console.log(has);
  ]])
  assert_eq(out, "true\n")
end)

test("negated in operator", function()
  local out = run_js('console.log(!("x" in {x: 1}));')
  assert_eq(out, "false\n")
end)

test("for...in loop still works alongside in operator", function()
  local out = run_js([[
    let count = 0;
    for (let k in {a: 1, b: 2}) { count = count + 1; }
    console.log(count);
  ]])
  assert_eq(out, "2\n")
end)
