local T = require("ljs_test")
local H = require("ljs_test_transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js = H.transpile_ok, H.expr_code, H.run_js

-- ============================================================================
-- Unit tests — literals
-- ============================================================================

test("NumberLiteral", function()
  local code = transpile_ok("42;")
  assert_eq(code, "42\n")
end)

test("NumberLiteral float", function()
  local code = transpile_ok("3.14;")
  assert_eq(code, "3.14\n")
end)

test("NumberLiteral hex 0xFF", function()
  local code = transpile_ok("0xFF;")
  assert_eq(code, "255\n")
end)

test("NumberLiteral hex 0x1a", function()
  local code = transpile_ok("0x1a;")
  assert_eq(code, "26\n")
end)

test("NumberLiteral hex 0X0F", function()
  local code = transpile_ok("0X0F;")
  assert_eq(code, "15\n")
end)

test("NumberLiteral hex in variable", function()
  local code = transpile_ok("let x = 0xFF;")
  assert_eq(code, "local x = 255\n")
end)

test("StringLiteral", function()
  local code = transpile_ok('"hello";')
  assert_eq(code, '"hello"\n')
end)

test("BooleanLiteral true", function()
  local code = transpile_ok("true;")
  assert_eq(code, "true\n")
end)

test("BooleanLiteral false", function()
  local code = transpile_ok("false;")
  assert_eq(code, "false\n")
end)

test("NullLiteral", function()
  local code = transpile_ok("null;")
  assert_eq(code, "nil\n")
end)

-- ============================================================================
-- Unit tests — identifiers and declarations
-- ============================================================================

test("Identifier", function()
  local code = transpile_ok("x;")
  assert_eq(code, "x\n")
end)

test("let with init", function()
  local code = transpile_ok("let x = 42;")
  assert_eq(code, "local x = 42\n")
end)

test("let without init", function()
  local code = transpile_ok("let x;")
  assert_eq(code, "local x\n")
end)

test("const maps to local", function()
  local code = transpile_ok("const x = 1;")
  assert_eq(code, "local x = 1\n")
end)

test("multiple declarators", function()
  local code = transpile_ok("let a = 1, b = 2;")
  assert_eq(code, "local a = 1\nlocal b = 2\n")
end)

-- ============================================================================
-- Unit tests — operators
-- ============================================================================

test("addition uses helper", function()
  local code = expr_code("1 + 2")
  assert_eq(code, "_ljs_add(1, 2)")
end)

test("subtraction", function()
  local code = expr_code("3 - 1")
  assert_eq(code, "3 - 1")
end)

test("multiplication", function()
  local code = expr_code("3 * 2")
  assert_eq(code, "3 * 2")
end)

test("strict equality", function()
  local code = expr_code("x === 1")
  assert_eq(code, "x == 1")
end)

test("strict inequality", function()
  local code = expr_code("x !== 1")
  assert_eq(code, "x ~= 1")
end)

test("logical AND", function()
  local code = expr_code("a && b")
  assert_eq(code, "a and b")
end)

test("logical OR", function()
  local code = expr_code("a || b")
  assert_eq(code, "a or b")
end)

test("logical NOT", function()
  local code = expr_code("!x")
  assert_eq(code, "not x")
end)

test("unary minus", function()
  local code = expr_code("-x")
  assert_eq(code, "-x")
end)

test("unary plus", function()
  local code = expr_code("+x")
  assert_eq(code, "tonumber(x)")
end)

test("unary plus on string", function()
  local code = expr_code('+"5"')
  assert_eq(code, 'tonumber("5")')
end)

test("nested unary +!x", function()
  local code = expr_code("+!x")
  assert_eq(code, "tonumber(not x)")
end)

test("unary + in binary context", function()
  local code = expr_code("1 + +x")
  assert_eq(code, "_ljs_add(1, tonumber(x))")
end)

-- ============================================================================
-- Unit tests — exponentiation (**)
-- ============================================================================

test("exponentiation ** maps to ^", function()
  assert_eq(expr_code("2 ** 3"), "2 ^ 3")
end)

test("exponentiation **= desugars", function()
  assert_eq(expr_code("x **= 2"), "x = x ^ 2")
end)

test("exponentiation **= on member expression", function()
  assert_eq(expr_code("obj.x **= 2"), "obj.x = obj.x ^ 2")
end)

test("exponentiation **= on computed member", function()
  assert_eq(expr_code("arr[0] **= 2"), "arr[(0) + 1] = arr[(0) + 1] ^ 2")
end)

test("exponentiation chained right-assoc", function()
  assert_eq(expr_code("2 ** 3 ** 4"), "2 ^ 3 ^ 4")
end)

test("exponentiation no helper emitted", function()
  local code = transpile_ok("let x = 2 ** 3;")
  assert(not code:find("_ljs_pow"), "expected no _ljs_pow helper")
end)

-- ============================================================================
-- Integration tests — exponentiation (**)
-- ============================================================================

test("2 ** 3 = 8", function()
  local output = run_js("console.log(2 ** 3);")
  assert_eq(tonumber(output:match("[%d.]+")), 8)
end)

test("2 ** 0.5 ≈ sqrt(2)", function()
  local output = run_js("console.log(2 ** 0.5);")
  local val = tonumber(output:match("[%d.]+"))
  assert(val and math.abs(val - 1.4142135623731) < 1e-6, "expected sqrt(2), got " .. tostring(val))
end)

test("2 ** 3 ** 2 = 512 (right-assoc)", function()
  local output = run_js("console.log(2 ** 3 ** 2);")
  assert_eq(tonumber(output:match("[%d.]+")), 512)
end)

test("**= compound assignment", function()
  local output = run_js([[
    let x = 2;
    x **= 3;
    console.log(x);
  ]])
  assert_eq(tonumber(output:match("[%d.]+")), 8)
end)

test("2 ** -1 = 0.5", function()
  local output = run_js("console.log(2 ** -1);")
  local val = tonumber(output:match("[%d.]+"))
  assert(val and math.abs(val - 0.5) < 1e-6, "expected 0.5, got " .. tostring(val))
end)

test("exponentiation with multiplication", function()
  local output = run_js("console.log(2 * 3 ** 2);")
  assert_eq(tonumber(output:match("[%d.]+")), 18)
end)

test("exponentiation in function body", function()
  local output = run_js([[
    function power(base, exp) {
      return base ** exp;
    }
    console.log(power(2, 10));
  ]])
  assert_eq(tonumber(output:match("[%d.]+")), 1024)
end)

-- ============================================================================
-- Unit tests — compound operators (+= etc.)
-- ============================================================================

test("comparison operators", function()
  assert_eq(expr_code("a < b"), "a < b")
  assert_eq(expr_code("a > b"), "a > b")
  assert_eq(expr_code("a <= b"), "a <= b")
  assert_eq(expr_code("a >= b"), "a >= b")
end)

test("addition emits helper definition", function()
  local code = transpile_ok("let x = 1 + 2;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)

test("compound += desugars with _ljs_add", function()
  assert_eq(expr_code("x += 1"), "x = _ljs_add(x, 1)")
end)

test("compound -= desugars", function()
  assert_eq(expr_code("x -= 1"), "x = x - 1")
end)

test("compound *= desugars", function()
  assert_eq(expr_code("x *= 2"), "x = x * 2")
end)

test("compound /= desugars", function()
  assert_eq(expr_code("x /= 2"), "x = x / 2")
end)

test("compound %= desugars", function()
  assert_eq(expr_code("x %= 2"), "x = x % 2")
end)

test("compound += on member expression", function()
  assert_eq(expr_code("obj.x += 1"), "obj.x = _ljs_add(obj.x, 1)")
end)

test("compound += with string concatenation", function()
  assert_eq(expr_code('x += "hello"'), 'x = _ljs_add(x, "hello")')
end)

test("compound += emits _ljs_add helper definition", function()
  local code = transpile_ok("x += 1;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)

T.summary()
