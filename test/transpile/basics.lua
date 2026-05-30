local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js, emit_ok = H.transpile_ok, H.expr_code, H.run_js, H.emit_ok

-- ============================================================================
-- Unit tests — literals
-- ============================================================================

test("NumberLiteral", function()
  assert_eq(expr_code("42;"), "local _ = 42")
end)

test("NumberLiteral float", function()
  assert_eq(expr_code("3.14;"), "local _ = 3.14")
end)

test("NumberLiteral hex 0xFF", function()
  assert_eq(expr_code("0xFF;"), "local _ = 255")
end)

test("NumberLiteral hex 0x1a", function()
  assert_eq(expr_code("0x1a;"), "local _ = 26")
end)

test("NumberLiteral hex 0X0F", function()
  assert_eq(expr_code("0X0F;"), "local _ = 15")
end)

test("NumberLiteral hex in variable", function()
  assert_eq(expr_code("let x = 0xFF;"), "local x = 255")
end)

test("StringLiteral", function()
  assert_eq(expr_code('"hello";'), 'local _ = "hello"')
end)

test("BooleanLiteral true", function()
  assert_eq(expr_code("true;"), "local _ = true")
end)

test("BooleanLiteral false", function()
  assert_eq(expr_code("false;"), "local _ = false")
end)

test("NullLiteral", function()
  assert_eq(expr_code("null;"), "local _ = _ljs_null")
end)

test("UndefinedLiteral", function()
  assert_eq(expr_code("undefined;"), "local _ = _ljs_undefined")
end)

-- ============================================================================
-- Unit tests — identifiers and declarations
-- ============================================================================

test("Identifier", function()
  assert_eq(expr_code("x;"), "local _ = x")
end)

test("let with init", function()
  assert_eq(expr_code("let x = 42;"), "local x = 42")
end)

test("let without init", function()
  assert_eq(expr_code("let x;"), "local x = _ljs_undefined")
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

test("true + 1 coerces boolean to number", function()
  local output = run_js("console.log(true + 1);")
  assert_eq(tonumber(output:match("[%d.]+")), 2)
end)

test("false + 1 coerces boolean to number", function()
  local output = run_js("console.log(false + 1);")
  assert_eq(tonumber(output:match("[%d.]+")), 1)
end)

test("true + true is 2", function()
  local output = run_js("console.log(true + true);")
  assert_eq(tonumber(output:match("[%d.]+")), 2)
end)

test("false + false is 0", function()
  local output = run_js("console.log(false + false);")
  assert_eq(tonumber(output:match("[%d.]+")), 0)
end)

test("true - 1 coerces boolean to number", function()
  local output = run_js("console.log(true - 1);")
  assert_eq(tonumber(output:match("[%d.]+")), 0)
end)

test("false * 5 coerces boolean to number", function()
  local output = run_js("console.log(false * 5);")
  assert_eq(tonumber(output:match("[%d.]+")), 0)
end)

test("true * 3 coerces boolean to number", function()
  local output = run_js("console.log(true * 3);")
  assert_eq(tonumber(output:match("[%d.]+")), 3)
end)

test("null - 1 coerces null to 0", function()
  local output = run_js("console.log(null - 1);")
  assert_eq(tonumber(output:match("-?[%d.]+")), -1)
end)

test("null * 3 coerces null to 0", function()
  local output = run_js("console.log(null * 3);")
  assert_eq(tonumber(output:match("[%d.]+")), 0)
end)

test("null / 2 coerces null to 0", function()
  local output = run_js("console.log(null / 2);")
  assert_eq(tonumber(output:match("[%d.]+")), 0)
end)

test("division uses helper", function()
  local code = expr_code("6 / 2")
  assert_eq(code, "_ljs_div(6, 2)")
end)

test("modulo uses _ljs_to_number wrapped _ljs_mod", function()
  local code = expr_code("a % b")
  assert_eq(code, "_ljs_mod(_ljs_to_number(a), _ljs_to_number(b))")
end)

test("subtraction uses helper", function()
  local code = expr_code("3 - 1")
  assert_eq(code, "_ljs_sub(3, 1)")
end)

test("multiplication uses helper", function()
  local code = expr_code("3 * 2")
  assert_eq(code, "_ljs_mul(3, 2)")
end)

test("strict equality", function()
  local code = expr_code("x === 1")
  assert_eq(code, "local _ = _ljs_strict_eq(x, 1)")
end)

test("strict inequality", function()
  local code = expr_code("x !== 1")
  assert_eq(code, "local _ = not _ljs_strict_eq(x, 1)")
end)

test("logical AND", function()
  local code = expr_code("a && b")
  assert_eq(
    code,
    "(function() local _ljs_v = a; if _ljs_to_boolean(_ljs_v) then return b else return _ljs_v end end)()"
  )
end)

test("logical OR", function()
  local code = expr_code("a || b")
  assert_eq(
    code,
    "(function() local _ljs_v = a; if _ljs_to_boolean(_ljs_v) then return _ljs_v else return b end end)()"
  )
end)

test("logical NOT", function()
  local code = expr_code("!x")
  assert_eq(code, "local _ = not _ljs_to_boolean(x)")
end)

test("unary minus", function()
  local code = expr_code("-x")
  assert_eq(code, "local _ = _ljs_neg(x)")
end)

test("unary minus -0 emits negative zero", function()
  assert_eq(expr_code("-0;"), "local _ = (-1 / math.huge)")
end)

test("unary plus uses _ljs_to_number", function()
  local code = expr_code("+x")
  assert_eq(code, "_ljs_to_number(x)")
end)

test("unary plus on string uses _ljs_to_number", function()
  local code = expr_code('+"5"')
  assert_eq(code, '_ljs_to_number("5")')
end)

test("nested unary +!x uses _ljs_to_number", function()
  local code = expr_code("+!x")
  assert_eq(code, "_ljs_to_number(not _ljs_to_boolean(x))")
end)

test("unary + in binary context uses _ljs_to_number", function()
  local code = expr_code("1 + +x")
  assert_eq(code, "_ljs_add(1, _ljs_to_number(x))")
end)

-- ============================================================================
-- Unit tests — exponentiation (**)
-- ============================================================================

test("exponentiation ** uses helper", function()
  assert_eq(expr_code("2 ** 3"), "_ljs_pow(2, 3)")
end)

test("exponentiation **= desugars with helper", function()
  assert_eq(expr_code("x **= 2"), "x = _ljs_pow(x, 2)")
end)

test("exponentiation **= on member expression", function()
  assert_eq(expr_code("obj.x **= 2"), "_ljs_to_object(obj).x = _ljs_pow(_ljs_to_object(obj).x, 2)")
end)

test("exponentiation **= on computed member", function()
  assert_eq(
    expr_code("arr[0] **= 2"),
    "_ljs_to_object(arr)[(0) + 1] = _ljs_pow(_ljs_to_object(arr)[(0) + 1], 2)"
  )
end)

test("exponentiation chained right-assoc uses helper", function()
  assert_eq(expr_code("2 ** 3 ** 4"), "_ljs_pow(2, _ljs_pow(3, 4))")
end)

test("exponentiation ** helper emitted", function()
  local code = emit_ok("let x = 2 ** 3;")
  assert(code:find("_ljs_pow"), "expected _ljs_pow helper")
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
-- Integration tests — exponentiation ±1^±Infinity and NaN edge cases (#102)
-- Per ECMA-262 §6.1.6.1.3 Number::exponentiate steps 9.2, 10.2
-- ============================================================================

test("1 ** Infinity = NaN", function()
  local output = run_js("console.log(1 ** Infinity);")
  assert_eq(output:match("%S+"), "NaN")
end)

test("1 ** -Infinity = NaN", function()
  local output = run_js("console.log(1 ** -Infinity);")
  assert_eq(output:match("%S+"), "NaN")
end)

test("(-1) ** Infinity = NaN", function()
  local output = run_js("console.log((-1) ** Infinity);")
  assert_eq(output:match("%S+"), "NaN")
end)

test("(-1) ** -Infinity = NaN", function()
  local output = run_js("console.log((-1) ** -Infinity);")
  assert_eq(output:match("%S+"), "NaN")
end)

test("1 ** NaN = NaN", function()
  local output = run_js("console.log(1 ** NaN);")
  assert_eq(output:match("%S+"), "NaN")
end)

test("regression: 2 ** 3 still = 8 after NaN edge-case fix", function()
  local output = run_js("console.log(2 ** 3);")
  assert_eq(tonumber(output:match("[%d.]+")), 8)
end)

-- ============================================================================
-- Unit tests — compound operators (+= etc.)
-- ============================================================================

test("comparison operators use helpers", function()
  assert_eq(expr_code("a < b"), "_ljs_lt(a, b)")
  assert_eq(expr_code("a > b"), "_ljs_gt(a, b)")
  assert_eq(expr_code("a <= b"), "_ljs_le(a, b)")
  assert_eq(expr_code("a >= b"), "_ljs_ge(a, b)")
end)

test("addition emits helper definition", function()
  local code = transpile_ok("let x = 1 + 2;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)

test("compound += desugars with _ljs_add", function()
  assert_eq(expr_code("x += 1"), "x = _ljs_add(x, 1)")
end)

test("compound -= desugars with helper", function()
  assert_eq(expr_code("x -= 1"), "x = _ljs_sub(x, 1)")
end)

test("compound *= desugars with helper", function()
  assert_eq(expr_code("x *= 2"), "x = _ljs_mul(x, 2)")
end)

test("compound /= desugars with helper", function()
  assert_eq(expr_code("x /= 2"), "x = _ljs_div(x, 2)")
end)

test("compound %= desugars with ToNumber", function()
  assert_eq(expr_code("x %= 2"), "x = _ljs_mod(_ljs_to_number(x), _ljs_to_number(2))")
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

-- ============================================================================
-- Integration tests — relational operators (< > <= >=) with coercion (#100)
-- Per ECMAScript Abstract Relational Comparison (§7.2.15)
-- ============================================================================

test("null < 1 coerces null to 0 → true", function()
  local output = run_js("console.log(null < 1);")
  assert_eq(output:match("%S+"), "true")
end)

test("true < 2 coerces true to 1 → true", function()
  local output = run_js("console.log(true < 2);")
  assert_eq(output:match("%S+"), "true")
end)

test("false >= 0 coerces false to 0 → true", function()
  local output = run_js("console.log(false >= 0);")
  assert_eq(output:match("%S+"), "true")
end)

test("undefined < 1 → false (NaN)", function()
  local output = run_js("console.log(undefined < 1);")
  assert_eq(output:match("%S+"), "false")
end)

test("NaN < 1 → false", function()
  local output = run_js("console.log(NaN < 1);")
  assert_eq(output:match("%S+"), "false")
end)

test('"10" > 9 coerces string to number → true', function()
  local output = run_js('console.log("10" > 9);')
  assert_eq(output:match("%S+"), "true")
end)

test('"abc" < 1 → false (NaN)', function()
  local output = run_js('console.log("abc" < 1);')
  assert_eq(output:match("%S+"), "false")
end)

test('"b" > "a" → true (lexicographic)', function()
  local output = run_js('console.log("b" > "a");')
  assert_eq(output:match("%S+"), "true")
end)

test("true > null coerces to 1 > 0 → true", function()
  local output = run_js("console.log(true > null);")
  assert_eq(output:match("%S+"), "true")
end)

test("function without return yields undefined", function()
  local output = run_js("console.log((function() {})());")
  assert_eq(output:match("%S+"), "undefined")
end)

test("arrow function without return yields undefined", function()
  local output = run_js([[
    var f = () => {};
    console.log(f());
  ]])
  assert_eq(output:match("%S+"), "undefined")
end)

test("function with explicit return still works after implicit undefined fix", function()
  local output = run_js("console.log((function() { return 42; })());")
  assert_eq(output:match("%S+"), "42")
end)

test("bare return still yields undefined", function()
  local output = run_js("console.log((function() { return; })());")
  assert_eq(output:match("%S+"), "undefined")
end)

-- ============================================================================
-- Block-scoped let (#283)
-- ============================================================================

test("block-scoped let does not leak to outer scope (#283)", function()
  local output = run_js([[
    let x = 1;
    {
      let x = 2;
    }
    console.log(x);
  ]])
  assert_eq(output:match("%S+"), "1")
end)

test("block-scoped let unit: standalone block wraps in do...end (#283)", function()
  local code = transpile_ok([[
    let x = 1;
    {
      let x = 2;
    }
  ]])
  assert(code:find("do\n", 1, true), "expected do block in output")
  assert(code:find("end\n", 1, true), "expected end block in output")
end)

-- ============================================================================
-- Chained assignment (#291)
-- Per ECMA-262 §13.15: assignment is right-associative and returns the value
-- ============================================================================

test("chained assignment a = b = 5 (#291)", function()
  local output = run_js([[
    let a, b;
    a = b = 5;
    console.log(a, b);
  ]])
  assert_eq(output:match("%S+"), "5")
end)

test("chained assignment returns value (#291)", function()
  local output = run_js([[
    let a, b;
    let c = (a = b = 42);
    console.log(a, b, c);
  ]])
  assert_eq(output:match("^%S+"), "42")
end)

-- ============================================================================
-- Chained compound assignment (#342)
-- Per ECMA-262 §13.15: = evaluates RHS then PutValue; RHS compound returns value
-- ============================================================================

test("chained compound assignment a = b += 5 (#342)", function()
  local output = run_js([[
    let a, b;
    a = b += 5;
    console.log(a, b);
  ]])
  assert_eq(output:match("^%S+"), "NaN")
end)

test("chained compound assignment returns value (#342)", function()
  local output = run_js([[
    let a, b;
    let c = (a = b += 5);
    console.log(a, b, c);
  ]])
  assert_eq(output:match("^%S+"), "NaN")
end)

test("chained compound assignment with %=", function()
  local output = run_js([[
    let a, b;
    b = 10;
    a = b %= 3;
    console.log(a, b);
  ]])
  assert_eq(output:match("^%S+"), "1")
end)

test("chained compound eval order: outer member before inner member (#389)", function()
  local output = run_js([[
    let order = [];
    function get(label) { order.push(label); return { x: 10 }; }
    get("first").x = get("second").x += 5;
    console.log(order[0] + "," + order[1]);
  ]])
  assert_eq(output:match("^%S+"), "first,second")
end)

test("chained compound eval order: ident outer, member inner (#389)", function()
  local output = run_js([[
    let order = [];
    function get(label) { order.push(label); return { x: 10 }; }
    let a;
    a = get("only").x += 5;
    console.log(order[0]);
  ]])
  assert_eq(output:match("^%S+"), "only")
end)

-- ============================================================================
-- = chain eval order (#400)
-- Per ECMA-262 §13.15.2: evaluate LHS refs left-to-right before RHS value
-- ============================================================================

test("= chain eval order: member targets before RHS value (#400)", function()
  local output = run_js([[
    let order = [];
    function get(label) { order.push(label); return { x: 0 }; }
    function val(label) { order.push(label); return 5; }
    get("A").x = get("B").x = val("C");
    console.log(order[0] + "," + order[1] + "," + order[2]);
  ]])
  assert_eq(output:match("^%S+"), "A,B,C")
end)

test("= chain eval order: member targets with compound tail (#400)", function()
  local output = run_js([[
    let order = [];
    function get(label) { order.push(label); return { x: 0 }; }
    get("A").x = get("B").x = get("C").x += 5;
    console.log(order[0] + "," + order[1] + "," + order[2]);
  ]])
  assert_eq(output:match("^%S+"), "A,B,C")
end)

test("= chain eval order: mixed ident and member (#400)", function()
  local output = run_js([[
    let order = [];
    function get(label) { order.push(label); return { x: 0 }; }
    function val(label) { order.push(label); return 5; }
    let a;
    a = get("B").x = val("C");
    console.log(order[0] + "," + order[1]);
  ]])
  assert_eq(output:match("^%S+"), "B,C")
end)

test("= chain eval order: three member targets with plain RHS (#400)", function()
  local output = run_js([[
    let order = [];
    function get(label) { order.push(label); return { x: 0 }; }
    function val(label) { order.push(label); return 5; }
    get("A").x = get("B").x = get("C").x = val("D");
    console.log(order[0] + "," + order[1] + "," + order[2] + "," + order[3]);
  ]])
  assert_eq(output:match("^%S+"), "A,B,C,D")
end)

-- ============================================================================
-- Computed member key eval order (#403)
-- Per ECMA-262 §13.15.2: key expression evaluated during LHS eval, not PutValue
-- ============================================================================

test("computed key eval order: key before RHS in = chain (#403)", function()
  local output = run_js([[
    let order = [];
    function getObj(label) { order.push(label); return {}; }
    function getKey(label) { order.push(label); return "x"; }
    getObj("A")[getKey("K")] = getObj("B").y = 5;
    console.log(order[0] + "," + order[1] + "," + order[2]);
  ]])
  assert_eq(output:match("^%S+"), "A,K,B")
end)

test("computed key eval order: both sides computed in = chain (#403)", function()
  local output = run_js([[
    let order = [];
    function getObj(label) { order.push(label); return {}; }
    function getKey(label) { order.push(label); return "x"; }
    getObj("A")[getKey("K1")] = getObj("B")[getKey("K2")] = 5;
    console.log(order[0] + "," + order[1] + "," + order[2] + "," + order[3]);
  ]])
  assert_eq(output:match("^%S+"), "A,K1,B,K2")
end)

test("computed key eval order: compound chain with computed keys (#403)", function()
  local output = run_js([[
    let order = [];
    function getObj(label) { order.push(label); return { x: 10 }; }
    function getKey(label) { order.push(label); return "x"; }
    getObj("A")[getKey("K1")] = getObj("B")[getKey("K2")] += 5;
    console.log(order[0] + "," + order[1] + "," + order[2] + "," + order[3]);
  ]])
  assert_eq(output:match("^%S+"), "A,K1,B,K2")
end)
