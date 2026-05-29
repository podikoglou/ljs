local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, expr_code, run_js = H.transpile_ok, H.expr_code, H.run_js

-- ============================================================================
-- Unit tests — bitwise NOT (~)
-- ============================================================================

test("bitwise NOT basic", function()
  local code = expr_code("~x")
  assert_eq(code, "_ljs_bnot(x)")
end)

test("bitwise NOT double", function()
  local code = expr_code("~~x")
  assert_eq(code, "_ljs_bnot(_ljs_bnot(x))")
end)

test("bitwise NOT on literal", function()
  local code = expr_code("~0")
  assert_eq(code, "_ljs_bnot(0)")
end)

test("bitwise NOT on negative", function()
  local code = expr_code("~-1")
  assert_eq(code, "_ljs_bnot(-_ljs_to_number(1))")
end)

test("bitwise NOT in binary context", function()
  local code = expr_code("~x + y")
  assert_eq(code, "_ljs_add(_ljs_bnot(x), y)")
end)

test("bitwise NOT emits helper definition", function()
  local code = transpile_ok("let x = ~y;")
  assert(code:find("local function _ljs_bnot"), "expected _ljs_bnot helper in output")
end)

test("_ljs_bnot always in preamble", function()
  local code = transpile_ok("let x = 1 + 2;")
  assert(code:find("_ljs_bnot"), "expected _ljs_bnot in preamble")
end)

test("transpile.HELPERS._ljs_bnot accessible", function()
  assert(type(H.transpile.HELPERS._ljs_bnot) == "string", "expected _ljs_bnot helper string")
end)

-- ============================================================================
-- Integration tests — bitwise NOT (~)
-- ============================================================================

test("bitwise NOT ~0 = -1", function()
  local output = run_js("console.log(~0);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("bitwise NOT ~(-1) = 0", function()
  local output = run_js("console.log(~(-1));")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("bitwise NOT ~5 = -6", function()
  local output = run_js("console.log(~5);")
  assert_eq(output:gsub("%s+", ""), "-6")
end)

test("bitwise NOT ~(-6) = 5", function()
  local output = run_js("console.log(~(-6));")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("double bitwise NOT ~~5.7 truncates to int", function()
  local output = run_js("console.log(~~5.7);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("double bitwise NOT ~~3.14 truncates to int", function()
  local output = run_js("console.log(~~3.14);")
  assert_eq(output:gsub("%s+", ""), "3")
end)

test("bitwise NOT ~2147483647 = -2147483648", function()
  local output = run_js("console.log(~2147483647);")
  assert_eq(output:gsub("%s+", ""), "-2147483648")
end)

test("bitwise NOT ~(-2147483648) = 2147483647", function()
  local output = run_js("console.log(~(-2147483648));")
  assert_eq(output:gsub("%s+", ""), "2147483647")
end)

test("bitwise NOT end-to-end in variable", function()
  local output = run_js("let x = ~5; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "-6")
end)

-- ============================================================================
-- Unit tests — bitwise AND (&)
-- ============================================================================

test("bitwise AND basic", function()
  assert_eq(expr_code("a & b"), "_ljs_band(a, b)")
end)

test("bitwise AND literals", function()
  assert_eq(expr_code("5 & 3"), "_ljs_band(5, 3)")
end)

test("bitwise AND nested left-assoc", function()
  assert_eq(expr_code("a & b & c"), "_ljs_band(_ljs_band(a, b), c)")
end)

test("bitwise AND with zero", function()
  assert_eq(expr_code("x & 0"), "_ljs_band(x, 0)")
end)

-- ============================================================================
-- Unit tests — bitwise OR (|)
-- ============================================================================

test("bitwise OR basic", function()
  assert_eq(expr_code("a | b"), "_ljs_bor(a, b)")
end)

test("bitwise OR literals", function()
  assert_eq(expr_code("5 | 3"), "_ljs_bor(5, 3)")
end)

test("bitwise OR nested left-assoc", function()
  assert_eq(expr_code("a | b | c"), "_ljs_bor(_ljs_bor(a, b), c)")
end)

test("bitwise OR with zero", function()
  assert_eq(expr_code("x | 0"), "_ljs_bor(x, 0)")
end)

-- ============================================================================
-- Unit tests — bitwise XOR (^)
-- ============================================================================

test("bitwise XOR basic", function()
  assert_eq(expr_code("a ^ b"), "_ljs_bxor(a, b)")
end)

test("bitwise XOR literals", function()
  assert_eq(expr_code("5 ^ 3"), "_ljs_bxor(5, 3)")
end)

test("bitwise XOR nested left-assoc", function()
  assert_eq(expr_code("a ^ b ^ c"), "_ljs_bxor(_ljs_bxor(a, b), c)")
end)

test("bitwise XOR self", function()
  assert_eq(expr_code("x ^ x"), "_ljs_bxor(x, x)")
end)

-- ============================================================================
-- Unit tests — left shift (<<)
-- ============================================================================

test("left shift basic", function()
  assert_eq(expr_code("a << b"), "_ljs_shl(a, b)")
end)

test("left shift literal", function()
  assert_eq(expr_code("1 << 4"), "_ljs_shl(1, 4)")
end)

test("left shift nested left-assoc", function()
  assert_eq(expr_code("a << 1 << 1"), "_ljs_shl(_ljs_shl(a, 1), 1)")
end)

test("left shift by zero", function()
  assert_eq(expr_code("x << 0"), "_ljs_shl(x, 0)")
end)

-- ============================================================================
-- Unit tests — arithmetic right shift (>>)
-- ============================================================================

test("right shift basic", function()
  assert_eq(expr_code("a >> b"), "_ljs_shr(a, b)")
end)

test("right shift literal", function()
  assert_eq(expr_code("16 >> 2"), "_ljs_shr(16, 2)")
end)

test("right shift nested left-assoc", function()
  assert_eq(expr_code("a >> 1 >> 1"), "_ljs_shr(_ljs_shr(a, 1), 1)")
end)

test("right shift by zero", function()
  assert_eq(expr_code("x >> 0"), "_ljs_shr(x, 0)")
end)

-- ============================================================================
-- Unit tests — unsigned right shift (>>>)
-- ============================================================================

test("unsigned right shift basic", function()
  assert_eq(expr_code("a >>> b"), "_ljs_usr(a, b)")
end)

test("unsigned right shift literal", function()
  assert_eq(expr_code("16 >>> 2"), "_ljs_usr(16, 2)")
end)

test("unsigned right shift nested left-assoc", function()
  assert_eq(expr_code("a >>> 1 >>> 1"), "_ljs_usr(_ljs_usr(a, 1), 1)")
end)

test("unsigned right shift negative", function()
  assert_eq(expr_code("-1 >>> 0"), "_ljs_usr(-_ljs_to_number(1), 0)")
end)

-- ============================================================================
-- Unit tests — bitwise compound assignments
-- ============================================================================

test("compound &= desugars", function()
  assert_eq(expr_code("x &= 3"), "x = _ljs_band(x, 3)")
end)

test("compound |= desugars", function()
  assert_eq(expr_code("x |= 3"), "x = _ljs_bor(x, 3)")
end)

test("compound ^= desugars", function()
  assert_eq(expr_code("x ^= 3"), "x = _ljs_bxor(x, 3)")
end)

test("compound <<= desugars", function()
  assert_eq(expr_code("x <<= 2"), "x = _ljs_shl(x, 2)")
end)

test("compound >>= desugars", function()
  assert_eq(expr_code("x >>= 2"), "x = _ljs_shr(x, 2)")
end)

test("compound >>>= desugars", function()
  assert_eq(expr_code("x >>>= 1"), "x = _ljs_usr(x, 1)")
end)

-- ============================================================================
-- Unit tests — bitwise compound on member expressions
-- ============================================================================

test("compound &= on dot member", function()
  assert_eq(expr_code("obj.x &= 1"), "_ljs_to_object(obj).x = _ljs_band(_ljs_to_object(obj).x, 1)")
end)

test("compound |= on dot member", function()
  assert_eq(expr_code("obj.x |= 1"), "_ljs_to_object(obj).x = _ljs_bor(_ljs_to_object(obj).x, 1)")
end)

test("compound <<= on computed member", function()
  assert_eq(
    expr_code("arr[0] <<= 2"),
    "_ljs_to_object(arr)[(0) + 1] = _ljs_shl(_ljs_to_object(arr)[(0) + 1], 2)"
  )
end)

test("compound >>>= on computed member", function()
  assert_eq(
    expr_code("arr[0] >>>= 1"),
    "_ljs_to_object(arr)[(0) + 1] = _ljs_usr(_ljs_to_object(arr)[(0) + 1], 1)"
  )
end)

test("compound ^= on computed member", function()
  assert_eq(
    expr_code("arr[0] ^= 3"),
    "_ljs_to_object(arr)[(0) + 1] = _ljs_bxor(_ljs_to_object(arr)[(0) + 1], 3)"
  )
end)

-- ============================================================================
-- Unit tests — precedence
-- ============================================================================

test("AND binds tighter than OR", function()
  assert_eq(expr_code("a | b & c"), "_ljs_bor(a, _ljs_band(b, c))")
end)

test("AND before OR reversed", function()
  assert_eq(expr_code("a & b | c"), "_ljs_bor(_ljs_band(a, b), c)")
end)

test("XOR binds between AND and OR", function()
  assert_eq(expr_code("a ^ b | c"), "_ljs_bor(_ljs_bxor(a, b), c)")
end)

test("OR before XOR reversed", function()
  assert_eq(expr_code("a | b ^ c"), "_ljs_bor(a, _ljs_bxor(b, c))")
end)

test("AND binds tighter than XOR", function()
  assert_eq(expr_code("a & b ^ c"), "_ljs_bxor(_ljs_band(a, b), c)")
end)

test("XOR after AND reversed", function()
  assert_eq(expr_code("a ^ b & c"), "_ljs_bxor(a, _ljs_band(b, c))")
end)

test("shift binds tighter than AND", function()
  assert_eq(expr_code("a & b << c"), "_ljs_band(a, _ljs_shl(b, c))")
end)

test("shift binds tighter than OR", function()
  assert_eq(expr_code("a | b >> c"), "_ljs_bor(a, _ljs_shr(b, c))")
end)

test("shift binds tighter than XOR", function()
  assert_eq(expr_code("a ^ b << c"), "_ljs_bxor(a, _ljs_shl(b, c))")
end)

-- ============================================================================
-- Unit tests — interaction with unary ~
-- ============================================================================

test("NOT then AND", function()
  assert_eq(expr_code("~a & b"), "_ljs_band(_ljs_bnot(a), b)")
end)

test("AND then NOT", function()
  assert_eq(expr_code("~(a & b)"), "_ljs_bnot(_ljs_band(a, b))")
end)

test("NOT then OR", function()
  assert_eq(expr_code("~a | b"), "_ljs_bor(_ljs_bnot(a), b)")
end)

test("double NOT + AND", function()
  assert_eq(expr_code("~~x & y"), "_ljs_band(_ljs_bnot(_ljs_bnot(x)), y)")
end)

test("NOT of XOR", function()
  assert_eq(expr_code("~(a ^ b)"), "_ljs_bnot(_ljs_bxor(a, b))")
end)

test("NOT of shift", function()
  assert_eq(expr_code("~(a << b)"), "_ljs_bnot(_ljs_shl(a, b))")
end)

-- ============================================================================
-- Unit tests — mixed with other operators
-- ============================================================================

test("bitwise AND inside addition", function()
  assert_eq(expr_code("(a & b) + c"), "_ljs_add(_ljs_band(a, b), c)")
end)

test("addition inside bitwise AND", function()
  assert_eq(expr_code("a + (b & c)"), "_ljs_add(a, _ljs_band(b, c))")
end)

test("bitwise AND with strict equality", function()
  assert_eq(expr_code("(a & b) === c"), "local _ = _ljs_strict_eq(_ljs_band(a, b), c)")
end)

test("bitwise AND with logical AND", function()
  assert_eq(
    expr_code("(a & b) && c"),
    "(function() local _ljs_v = _ljs_band(a, b); if _ljs_to_boolean(_ljs_v) then return c else return _ljs_v end end)()"
  )
end)

test("bitwise OR with strict inequality", function()
  assert_eq(expr_code("(a | b) !== c"), "local _ = not _ljs_strict_eq(_ljs_bor(a, b), c)")
end)

test("shift inside multiplication", function()
  assert_eq(expr_code("(1 << 3) * 2"), "_ljs_mul(_ljs_shl(1, 3), 2)")
end)

test("bitwise inside ternary", function()
  local code = expr_code("c ? a & b : 0")
  assert(code:find("_ljs_band"), "expected _ljs_band in ternary")
end)

test("bitwise in variable declaration", function()
  local code = transpile_ok("let x = a & b;")
  assert(code:find("local x = _ljs_band"), "expected bitwise in variable declaration")
end)

-- ============================================================================
-- Unit tests — helper emission
-- ============================================================================

test("& emits _ljs_band helper", function()
  local code = transpile_ok("let x = a & b;")
  assert(code:find("local function _ljs_band"), "expected _ljs_band helper in output")
end)

test("| emits _ljs_bor helper", function()
  local code = transpile_ok("let x = a | b;")
  assert(code:find("local function _ljs_bor"), "expected _ljs_bor helper in output")
end)

test("^ emits _ljs_bxor helper", function()
  local code = transpile_ok("let x = a ^ b;")
  assert(code:find("local function _ljs_bxor"), "expected _ljs_bxor helper in output")
end)

test("<< emits _ljs_shl helper", function()
  local code = transpile_ok("let x = a << b;")
  assert(code:find("local function _ljs_shl"), "expected _ljs_shl helper in output")
end)

test(">> emits _ljs_shr helper", function()
  local code = transpile_ok("let x = a >> b;")
  assert(code:find("local function _ljs_shr"), "expected _ljs_shr helper in output")
end)

test(">>> emits _ljs_usr helper", function()
  local code = transpile_ok("let x = a >>> b;")
  assert(code:find("local function _ljs_usr"), "expected _ljs_usr helper in output")
end)

test("&= emits _ljs_band helper", function()
  local code = transpile_ok("x &= 3;")
  assert(code:find("local function _ljs_band"), "expected _ljs_band helper in output")
end)

test("all bitwise helpers always in preamble", function()
  local code = transpile_ok("let x = 1 + 2;")
  assert(code:find("_ljs_band"), "expected _ljs_band in preamble")
  assert(code:find("_ljs_bor"), "expected _ljs_bor in preamble")
  assert(code:find("_ljs_bxor"), "expected _ljs_bxor in preamble")
  assert(code:find("_ljs_shl"), "expected _ljs_shl in preamble")
  assert(code:find("_ljs_shr"), "expected _ljs_shr in preamble")
  assert(code:find("_ljs_usr"), "expected _ljs_usr in preamble")
  assert(code:find("_ljs_to_int32"), "expected _ljs_to_int32 in preamble")
end)

test("bitwise op also emits _ljs_to_int32", function()
  local code = transpile_ok("let x = a & b;")
  assert(code:find("local function _ljs_to_int32"), "expected _ljs_to_int32 helper in output")
end)

test("_ljs_to_int32 appears before dependent helpers", function()
  local code = transpile_ok("let x = a & b;")
  local i1 = code:find("local function _ljs_to_int32")
  local i2 = code:find("local function _ljs_band")
  assert(i1 and i2 and i1 < i2, "expected _ljs_to_int32 before _ljs_band")
end)

test("~x now also emits _ljs_to_int32", function()
  local code = transpile_ok("let x = ~y;")
  assert(code:find("local function _ljs_to_int32"), "expected _ljs_to_int32 after bnot refactor")
end)

test("multiple bitwise ops emit _ljs_to_int32 only once", function()
  local code = transpile_ok("let x = a & b; let y = c | d;")
  local count = 0
  for _ in code:gmatch("local function _ljs_to_int32") do
    count = count + 1
  end
  assert_eq(count, 1)
end)

-- ============================================================================
-- Unit tests — HELPERS registry
-- ============================================================================

test("transpile.HELPERS._ljs_to_int32 accessible", function()
  assert(
    type(H.transpile.HELPERS._ljs_to_int32) == "string",
    "expected _ljs_to_int32 helper string"
  )
end)

test("transpile.HELPERS._ljs_band accessible", function()
  assert(type(H.transpile.HELPERS._ljs_band) == "string", "expected _ljs_band helper string")
end)

test("transpile.HELPERS._ljs_bor accessible", function()
  assert(type(H.transpile.HELPERS._ljs_bor) == "string", "expected _ljs_bor helper string")
end)

test("transpile.HELPERS._ljs_bxor accessible", function()
  assert(type(H.transpile.HELPERS._ljs_bxor) == "string", "expected _ljs_bxor helper string")
end)

test("transpile.HELPERS._ljs_shl accessible", function()
  assert(type(H.transpile.HELPERS._ljs_shl) == "string", "expected _ljs_shl helper string")
end)

test("transpile.HELPERS._ljs_shr accessible", function()
  assert(type(H.transpile.HELPERS._ljs_shr) == "string", "expected _ljs_shr helper string")
end)

test("transpile.HELPERS._ljs_usr accessible", function()
  assert(type(H.transpile.HELPERS._ljs_usr) == "string", "expected _ljs_usr helper string")
end)

-- ============================================================================
-- Unit tests — statement form
-- ============================================================================

test("bitwise AND as statement", function()
  local code = transpile_ok("a & b;")
  assert(code:find("_ljs_band"), "expected _ljs_band in statement form")
  assert(code:find("_ljs_band(a, b)", 1, true), "expected direct call as statement")
end)

test("compound &= as statement", function()
  local code = transpile_ok("x &= 3;")
  assert(code:find("_ljs_band"), "expected _ljs_band in compound statement")
end)

-- ============================================================================
-- Integration tests — bitwise AND (&)
-- ============================================================================

test("5 & 3 = 1", function()
  local output = run_js("console.log(5 & 3);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("15 & 6 = 6", function()
  local output = run_js("console.log(15 & 6);")
  assert_eq(output:gsub("%s+", ""), "6")
end)

test("0xFF & 0x0F = 15", function()
  local output = run_js("console.log(0xFF & 0x0F);")
  assert_eq(output:gsub("%s+", ""), "15")
end)

test("0 & 0 = 0", function()
  local output = run_js("console.log(0 & 0);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("-1 & 0xFF = 255", function()
  local output = run_js("console.log(-1 & 0xFF);")
  assert_eq(output:gsub("%s+", ""), "255")
end)

test("-1 & -2 = -2", function()
  local output = run_js("console.log(-1 & -2);")
  assert_eq(output:gsub("%s+", ""), "-2")
end)

test("0xFFFFFFFF & 0xFF = 255", function()
  local output = run_js("console.log(0xFFFFFFFF & 0xFF);")
  assert_eq(output:gsub("%s+", ""), "255")
end)

-- ============================================================================
-- Integration tests — bitwise OR (|)
-- ============================================================================

test("5 | 3 = 7", function()
  local output = run_js("console.log(5 | 3);")
  assert_eq(output:gsub("%s+", ""), "7")
end)

test("1 | 8 = 9", function()
  local output = run_js("console.log(1 | 8);")
  assert_eq(output:gsub("%s+", ""), "9")
end)

test("0 | 0 = 0", function()
  local output = run_js("console.log(0 | 0);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("-1 | 0 = -1", function()
  local output = run_js("console.log(-1 | 0);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("-1 | -2 = -1", function()
  local output = run_js("console.log(-1 | -2);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("0xFF000000 | 0x00FFFFFF = -1", function()
  local output = run_js("console.log(0xFF000000 | 0x00FFFFFF);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

-- ============================================================================
-- Integration tests — bitwise XOR (^)
-- ============================================================================

test("5 ^ 3 = 6", function()
  local output = run_js("console.log(5 ^ 3);")
  assert_eq(output:gsub("%s+", ""), "6")
end)

test("5 ^ 5 = 0", function()
  local output = run_js("console.log(5 ^ 5);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("0 ^ 7 = 7", function()
  local output = run_js("console.log(0 ^ 7);")
  assert_eq(output:gsub("%s+", ""), "7")
end)

test("-1 ^ 0xFF = -256", function()
  local output = run_js("console.log(-1 ^ 0xFF);")
  assert_eq(output:gsub("%s+", ""), "-256")
end)

test("-1 ^ -2 = 1", function()
  local output = run_js("console.log(-1 ^ -2);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("0xFFFFFFFF ^ 0xFF = -256", function()
  local output = run_js("console.log(0xFFFFFFFF ^ 0xFF);")
  assert_eq(output:gsub("%s+", ""), "-256")
end)

-- ============================================================================
-- Integration tests — left shift (<<)
-- ============================================================================

test("1 << 4 = 16", function()
  local output = run_js("console.log(1 << 4);")
  assert_eq(output:gsub("%s+", ""), "16")
end)

test("3 << 2 = 12", function()
  local output = run_js("console.log(3 << 2);")
  assert_eq(output:gsub("%s+", ""), "12")
end)

test("1 << 0 = 1", function()
  local output = run_js("console.log(1 << 0);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 << 31 = -2147483648", function()
  local output = run_js("console.log(1 << 31);")
  assert_eq(output:gsub("%s+", ""), "-2147483648")
end)

test("1 << 30 = 1073741824", function()
  local output = run_js("console.log(1 << 30);")
  assert_eq(output:gsub("%s+", ""), "1073741824")
end)

test("0x7FFFFFFF << 1 = -2", function()
  local output = run_js("console.log(0x7FFFFFFF << 1);")
  assert_eq(output:gsub("%s+", ""), "-2")
end)

-- ============================================================================
-- Integration tests — arithmetic right shift (>>)
-- ============================================================================

test("16 >> 2 = 4", function()
  local output = run_js("console.log(16 >> 2);")
  assert_eq(output:gsub("%s+", ""), "4")
end)

test("7 >> 1 = 3", function()
  local output = run_js("console.log(7 >> 1);")
  assert_eq(output:gsub("%s+", ""), "3")
end)

test("1 >> 1 = 0", function()
  local output = run_js("console.log(1 >> 1);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("-4 >> 1 = -2 (sign-extends)", function()
  local output = run_js("console.log(-4 >> 1);")
  assert_eq(output:gsub("%s+", ""), "-2")
end)

test("-1 >> 5 = -1 (sign-extends all ones)", function()
  local output = run_js("console.log(-1 >> 5);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("-2147483648 >> 31 = -1", function()
  local output = run_js("console.log(-2147483648 >> 31);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

-- ============================================================================
-- Integration tests — unsigned right shift (>>>)
-- ============================================================================

test("16 >>> 2 = 4", function()
  local output = run_js("console.log(16 >>> 2);")
  assert_eq(output:gsub("%s+", ""), "4")
end)

test("-1 >>> 0 = 4294967295", function()
  local output = run_js("console.log(-1 >>> 0);")
  assert_eq(output:gsub("%s+", ""), "4294967295")
end)

test("-1 >>> 1 = 2147483647", function()
  local output = run_js("console.log(-1 >>> 1);")
  assert_eq(output:gsub("%s+", ""), "2147483647")
end)

test("-2 >>> 1 = 2147483647", function()
  local output = run_js("console.log(-2 >>> 1);")
  assert_eq(output:gsub("%s+", ""), "2147483647")
end)

test("-2147483648 >>> 31 = 1", function()
  local output = run_js("console.log(-2147483648 >>> 31);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

-- ============================================================================
-- Integration tests — float-to-int truncation (ToInt32 behavior)
-- ============================================================================

test("5.7 & 3.2 truncates to 5 & 3 = 1", function()
  local output = run_js("console.log(5.7 & 3.2);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("5.7 | 2.9 truncates to 5 | 2 = 7", function()
  local output = run_js("console.log(5.7 | 2.9);")
  assert_eq(output:gsub("%s+", ""), "7")
end)

test("1 << 3.9 truncates shift to 1 << 3 = 8", function()
  local output = run_js("console.log(1 << 3.9);")
  assert_eq(output:gsub("%s+", ""), "8")
end)

test("8 >> 2.1 truncates shift to 8 >> 2 = 2", function()
  local output = run_js("console.log(8 >> 2.1);")
  assert_eq(output:gsub("%s+", ""), "2")
end)

-- ============================================================================
-- Integration tests — shift count edge cases
-- ============================================================================

test("5 << 0 = 5", function()
  local output = run_js("console.log(5 << 0);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("1 << 32 wraps to 1 << 0 = 1", function()
  local output = run_js("console.log(1 << 32);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 << -1 wraps to 1 << 31 = -2147483648", function()
  local output = run_js("console.log(1 << -1);")
  assert_eq(output:gsub("%s+", ""), "-2147483648")
end)

test("5 >> 0 = 5", function()
  local output = run_js("console.log(5 >> 0);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("5 >>> 0 = 5", function()
  local output = run_js("console.log(5 >>> 0);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

-- ============================================================================
-- Integration tests — compound assignments end-to-end
-- ============================================================================

test("x &= 3 end-to-end", function()
  local output = run_js("let x = 5; x &= 3; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("x |= 3 end-to-end", function()
  local output = run_js("let x = 5; x |= 3; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "7")
end)

test("x ^= 3 end-to-end", function()
  local output = run_js("let x = 5; x ^= 3; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "6")
end)

test("x <<= 4 end-to-end", function()
  local output = run_js("let x = 1; x <<= 4; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "16")
end)

test("x >>= 2 end-to-end", function()
  local output = run_js("let x = 16; x >>= 2; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "4")
end)

test("x >>= 1 with negative preserves sign", function()
  local output = run_js("let x = -4; x >>= 1; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "-2")
end)

test("x >>>= 0 end-to-end", function()
  local output = run_js("let x = -1; x >>>= 0; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "4294967295")
end)

test("obj.x &= 6 end-to-end", function()
  local output = run_js("let o = {x: 15}; o.x &= 6; console.log(o.x);")
  assert_eq(output:gsub("%s+", ""), "6")
end)

test("arr[0] |= 2 end-to-end", function()
  local output = run_js("let a = [5]; a[0] |= 2; console.log(a[0]);")
  assert_eq(output:gsub("%s+", ""), "7")
end)

-- ============================================================================
-- Integration tests — complex expressions
-- ============================================================================

test("~(5 | 3) = -8", function()
  local output = run_js("console.log(~(5 | 3));")
  assert_eq(output:gsub("%s+", ""), "-8")
end)

test("~~(5.7 & 3.2) = 1 (truncates)", function()
  local output = run_js("console.log(~~(5.7 & 3.2));")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("0xFF & 0x0F | 0xF0 = 255", function()
  local output = run_js("console.log(0xFF & 0x0F | 0xF0);")
  assert_eq(output:gsub("%s+", ""), "255")
end)

test("(1 << 3) + 1 = 9", function()
  local output = run_js("console.log((1 << 3) + 1);")
  assert_eq(output:gsub("%s+", ""), "9")
end)

test("XOR swap pattern", function()
  local output = run_js([[
    let a = 5, b = 3;
    a = a ^ b;
    b = a ^ b;
    a = a ^ b;
    console.log(a);
    console.log(b);
  ]])
  local lines = {}
  for l in output:gmatch("[^\n]+") do
    lines[#lines + 1] = l:gsub("%s+", "")
  end
  assert_eq(lines[1], "3")
  assert_eq(lines[2], "5")
end)

test("ternary with bitwise AND", function()
  local output = run_js("console.log(true ? 5 & 3 : 0);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("bitwise in if condition", function()
  local output = run_js([[
    let x = 5;
    if (x & 1) { console.log("odd"); } else { console.log("even"); }
  ]])
  assert(output:find("odd"), "expected odd")
end)

test("bitwise in return", function()
  local output = run_js([[
    function f(x) { return x & 0xFF; }
    console.log(f(256));
  ]])
  assert_eq(output:gsub("%s+", ""), "0")
end)

-- ============================================================================
-- Integration tests — variable flow
-- ============================================================================

test("store bitwise result in variable", function()
  local output = run_js("let r = 5 & 3; console.log(r);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("bitwise through function arg", function()
  local output = run_js([[
    function f(x) { return x & 0xFF; }
    console.log(f(256));
  ]])
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("accumulate bits in loop", function()
  local output = run_js([[
    let s = 0;
    for (let i = 0; i < 4; i++) { s = s | (1 << i); }
    console.log(s);
  ]])
  assert_eq(output:gsub("%s+", ""), "15")
end)

test("byte extraction via mask", function()
  local output = run_js("let v = 0xABCD; console.log(v & 0xFF);")
  assert_eq(output:gsub("%s+", ""), "205")
end)

test("set and test a bit", function()
  local output = run_js([[
    let flags = 0;
    flags = flags | (1 << 2);
    if (flags & 4) { console.log("bit 2 set"); }
  ]])
  assert(output:find("bit 2 set"), "expected bit 2 set")
end)

test("clear a bit with AND NOT", function()
  local output = run_js([[
    let flags = 7;
    flags = flags & (~2);
    console.log(flags);
  ]])
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("toggle a bit with XOR", function()
  local output = run_js([[
    let flags = 5;
    flags = flags ^ 2;
    console.log(flags);
    flags = flags ^ 2;
    console.log(flags);
  ]])
  local lines = {}
  for l in output:gmatch("[^\n]+") do
    lines[#lines + 1] = l:gsub("%s+", "")
  end
  assert_eq(lines[1], "7")
  assert_eq(lines[2], "5")
end)

test("bitwise NOT still works after refactor", function()
  local output = run_js("console.log(~0);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("~~5.7 truncates to int after refactor", function()
  local output = run_js("console.log(~~5.7);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

-- ============================================================================
-- Integration tests — ToNumber coercion for non-number operands (#282)
-- ============================================================================

test("bitwise NOT ~null = -1", function()
  local output = run_js("console.log(~null);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("bitwise NOT ~undefined = -1", function()
  local output = run_js("console.log(~undefined);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("bitwise NOT ~true = -2", function()
  local output = run_js("console.log(~true);")
  assert_eq(output:gsub("%s+", ""), "-2")
end)

test("bitwise NOT ~false = -1", function()
  local output = run_js("console.log(~false);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("1 & null = 0", function()
  local output = run_js("console.log(1 & null);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("1 & true = 1", function()
  local output = run_js("console.log(1 & true);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 | null = 1", function()
  local output = run_js("console.log(1 | null);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 | false = 1", function()
  local output = run_js("console.log(1 | false);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 ^ null = 1", function()
  local output = run_js("console.log(1 ^ null);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 ^ true = 0", function()
  local output = run_js("console.log(1 ^ true);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("1 << null = 1", function()
  local output = run_js("console.log(1 << null);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 >> null = 1", function()
  local output = run_js("console.log(1 >> null);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 >>> null = 1", function()
  local output = run_js("console.log(1 >>> null);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 << true = 2", function()
  local output = run_js("console.log(1 << true);")
  assert_eq(output:gsub("%s+", ""), "2")
end)

test("1 >> true = 0", function()
  local output = run_js("console.log(1 >> true);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("true & true = 1", function()
  local output = run_js("console.log(true & true);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("true | false = 1", function()
  local output = run_js("console.log(true | false);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("null & null = 0", function()
  local output = run_js("console.log(null & null);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("null | null = 0", function()
  local output = run_js("console.log(null | null);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("NaN >>> 0 = 0", function()
  local output = run_js("console.log(NaN >>> 0);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("null >>> 0 = 0", function()
  local output = run_js("console.log(null >>> 0);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("true >>> 0 = 1", function()
  local output = run_js("console.log(true >>> 0);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("false >>> 0 = 0", function()
  local output = run_js("console.log(false >>> 0);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

-- ============================================================================
-- Integration tests — NaN shift operands (#300)
-- ============================================================================

test("1 << NaN = 1", function()
  local output = run_js("console.log(1 << NaN);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 >> NaN = 1", function()
  local output = run_js("console.log(1 >> NaN);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("1 >>> NaN = 1", function()
  local output = run_js("console.log(1 >>> NaN);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("NaN & 1 = 0", function()
  local output = run_js("console.log(NaN & 1);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("NaN | 1 = 1", function()
  local output = run_js("console.log(NaN | 1);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("NaN ^ 1 = 1", function()
  local output = run_js("console.log(NaN ^ 1);")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("~NaN = -1", function()
  local output = run_js("console.log(~NaN);")
  assert_eq(output:gsub("%s+", ""), "-1")
end)

test("NaN ^ 5 = 5", function()
  local output = run_js("console.log(NaN ^ 5);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("undefined ^ 5 = 5", function()
  local output = run_js("console.log(undefined ^ 5);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("5 ^ NaN = 5", function()
  local output = run_js("console.log(5 ^ NaN);")
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("NaN ^ NaN = 0", function()
  local output = run_js("console.log(NaN ^ NaN);")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("NaN ^ 255 = 255", function()
  local output = run_js("console.log(NaN ^ 255);")
  assert_eq(output:gsub("%s+", ""), "255")
end)

test("undefined ^ 0xAB = 171", function()
  local output = run_js("console.log(undefined ^ 0xAB);")
  assert_eq(output:gsub("%s+", ""), "171")
end)
