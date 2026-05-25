local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js, emit_ok = H.transpile_ok, H.expr_code, H.run_js, H.emit_ok

-- ============================================================================
-- Unit tests — literals
-- ============================================================================

test("NumberLiteral", function()
  assert_eq(expr_code("42;"), "42")
end)

test("NumberLiteral float", function()
  assert_eq(expr_code("3.14;"), "3.14")
end)

test("NumberLiteral hex 0xFF", function()
  assert_eq(expr_code("0xFF;"), "255")
end)

test("NumberLiteral hex 0x1a", function()
  assert_eq(expr_code("0x1a;"), "26")
end)

test("NumberLiteral hex 0X0F", function()
  assert_eq(expr_code("0X0F;"), "15")
end)

test("NumberLiteral hex in variable", function()
  assert_eq(expr_code("let x = 0xFF;"), "local x = 255")
end)

test("StringLiteral", function()
  assert_eq(expr_code('"hello";'), '"hello"')
end)

test("BooleanLiteral true", function()
  assert_eq(expr_code("true;"), "true")
end)

test("BooleanLiteral false", function()
  assert_eq(expr_code("false;"), "false")
end)

test("NullLiteral", function()
  assert_eq(expr_code("null;"), "_ljs_null")
end)

-- ============================================================================
-- Unit tests — identifiers and declarations
-- ============================================================================

test("Identifier", function()
  assert_eq(expr_code("x;"), "x")
end)

test("let with init", function()
  assert_eq(expr_code("let x = 42;"), "local x = 42")
end)

test("let without init", function()
  assert_eq(expr_code("let x;"), "local x")
end)

test("const maps to local", function()
  assert_eq(expr_code("const x = 1;"), "local x = 1")
end)

test("multiple declarators", function()
  local code = transpile_ok("let a = 1, b = 2;")
  assert(code:find("local a = 1\nlocal b = 2\n", 1, true), "expected local a = 1; local b = 2")
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
  assert_eq(code, "not _ljs_to_boolean(x)")
end)

test("unary minus", function()
  local code = expr_code("-x")
  assert_eq(code, "-x")
end)

test("unary minus -0 emits negative zero", function()
  assert_eq(expr_code("-0;"), "(-1 / math.huge)")
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
  assert_eq(code, "tonumber(not _ljs_to_boolean(x))")
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
  assert_eq(expr_code("obj.x **= 2"), "_ljs_to_object(obj).x = _ljs_to_object(obj).x ^ 2")
end)

test("exponentiation **= on computed member", function()
  assert_eq(
    expr_code("arr[0] **= 2"),
    "_ljs_to_object(arr)[(0) + 1] = _ljs_to_object(arr)[(0) + 1] ^ 2"
  )
end)

test("exponentiation chained right-assoc", function()
  assert_eq(expr_code("2 ** 3 ** 4"), "2 ^ 3 ^ 4")
end)

test("exponentiation no helper emitted", function()
  local code = emit_ok("let x = 2 ** 3;")
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
  assert_eq(expr_code("obj.x += 1"), "_ljs_to_object(obj).x = _ljs_add(_ljs_to_object(obj).x, 1)")
end)

test("compound += with string concatenation", function()
  assert_eq(expr_code('x += "hello"'), 'x = _ljs_add(x, "hello")')
end)

test("compound += emits _ljs_add helper definition", function()
  local code = transpile_ok("x += 1;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)
