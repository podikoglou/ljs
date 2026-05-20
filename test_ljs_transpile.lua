local transpile = require("ljs_transpile")
local parser = require("ljs_parser")
local T = require("ljs_test")
local test, assert_eq = T.test, T.assert_eq

-- Unit test helpers

local function transpile_ast(ast)
  local code, err = transpile.transpile(ast)
  if not code then error("transpile failed: " .. tostring(err)) end
  return code
end

local function transpile_ok(src)
  local ast, err = parser.parse(src)
  if not ast then error("parse failed: " .. tostring(err)) end
  return transpile_ast(ast)
end

local function expr_code(src)
  local ast, err = parser.parse(src)
  if not ast then error("parse failed: " .. tostring(err)) end
  local code, err2 = transpile.transpile(ast)
  if not code then error("transpile failed: " .. tostring(err2)) end
  code = code:gsub("\n$", "")
  local last_line = code:match("([^\n]*)$")
  return last_line
end

-- Integration test helpers

local function run_lua_source(code)
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  f:write(code)
  f:close()
  local pipe = io.popen("lua " .. tmp .. " 2>&1", "r")
  local output = pipe:read("*a")
  pipe:close()
  os.remove(tmp)
  return output
end

local function run_js(js)
  return run_lua_source(transpile_ok(js))
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then error("cannot open: " .. path) end
  local content = f:read("*a")
  f:close()
  return content
end

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
  assert_eq(code, "_ljs_bnot(-1)")
end)

test("bitwise NOT in binary context", function()
  local code = expr_code("~x + y")
  assert_eq(code, "_ljs_add(_ljs_bnot(x), y)")
end)

test("bitwise NOT emits helper definition", function()
  local code = transpile_ok("let x = ~y;")
  assert(code:find("local function _ljs_bnot"), "expected _ljs_bnot helper in output")
end)

test("no _ljs_bnot when unused", function()
  local code = transpile_ok("let x = 1 + 2;")
  assert(not code:find("_ljs_bnot"), "expected no _ljs_bnot")
end)

test("transpile.HELPERS._ljs_bnot accessible", function()
  assert(type(transpile.HELPERS._ljs_bnot) == "string", "expected _ljs_bnot helper string")
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
  assert_eq(expr_code("-1 >>> 0"), "_ljs_usr(-1, 0)")
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
  assert_eq(expr_code("obj.x &= 1"), "obj.x = _ljs_band(obj.x, 1)")
end)

test("compound |= on dot member", function()
  assert_eq(expr_code("obj.x |= 1"), "obj.x = _ljs_bor(obj.x, 1)")
end)

test("compound <<= on computed member", function()
  assert_eq(expr_code("arr[0] <<= 2"), "arr[(0) + 1] = _ljs_shl(arr[(0) + 1], 2)")
end)

test("compound >>>= on computed member", function()
  assert_eq(expr_code("arr[0] >>>= 1"), "arr[(0) + 1] = _ljs_usr(arr[(0) + 1], 1)")
end)

test("compound ^= on computed member", function()
  assert_eq(expr_code("arr[0] ^= 3"), "arr[(0) + 1] = _ljs_bxor(arr[(0) + 1], 3)")
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
  assert_eq(expr_code("(a & b) === c"), "_ljs_band(a, b) == c")
end)

test("bitwise AND with logical AND", function()
  assert_eq(expr_code("(a & b) && c"), "_ljs_band(a, b) and c")
end)

test("bitwise OR with strict inequality", function()
  assert_eq(expr_code("(a | b) !== c"), "_ljs_bor(a, b) ~= c")
end)

test("shift inside multiplication", function()
  assert_eq(expr_code("(1 << 3) * 2"), "_ljs_shl(1, 3) * 2")
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

test("no bitwise helpers when unused", function()
  local code = transpile_ok("let x = 1 + 2;")
  assert(not code:find("_ljs_band"), "expected no _ljs_band")
  assert(not code:find("_ljs_bor"), "expected no _ljs_bor")
  assert(not code:find("_ljs_bxor"), "expected no _ljs_bxor")
  assert(not code:find("_ljs_shl"), "expected no _ljs_shl")
  assert(not code:find("_ljs_shr"), "expected no _ljs_shr")
  assert(not code:find("_ljs_usr"), "expected no _ljs_usr")
  assert(not code:find("_ljs_to_int32"), "expected no _ljs_to_int32")
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
  for _ in code:gmatch("local function _ljs_to_int32") do count = count + 1 end
  assert_eq(count, 1)
end)

-- ============================================================================
-- Unit tests — HELPERS registry
-- ============================================================================

test("transpile.HELPERS._ljs_to_int32 accessible", function()
  assert(type(transpile.HELPERS._ljs_to_int32) == "string", "expected _ljs_to_int32 helper string")
end)

test("transpile.HELPERS._ljs_band accessible", function()
  assert(type(transpile.HELPERS._ljs_band) == "string", "expected _ljs_band helper string")
end)

test("transpile.HELPERS._ljs_bor accessible", function()
  assert(type(transpile.HELPERS._ljs_bor) == "string", "expected _ljs_bor helper string")
end)

test("transpile.HELPERS._ljs_bxor accessible", function()
  assert(type(transpile.HELPERS._ljs_bxor) == "string", "expected _ljs_bxor helper string")
end)

test("transpile.HELPERS._ljs_shl accessible", function()
  assert(type(transpile.HELPERS._ljs_shl) == "string", "expected _ljs_shl helper string")
end)

test("transpile.HELPERS._ljs_shr accessible", function()
  assert(type(transpile.HELPERS._ljs_shr) == "string", "expected _ljs_shr helper string")
end)

test("transpile.HELPERS._ljs_usr accessible", function()
  assert(type(transpile.HELPERS._ljs_usr) == "string", "expected _ljs_usr helper string")
end)

-- ============================================================================
-- Unit tests — statement form
-- ============================================================================

test("bitwise AND as statement", function()
  local code = transpile_ok("a & b;")
  assert(code:find("_ljs_band"), "expected _ljs_band in statement form")
  assert(not code:find("function%("), "no IIFE in statement form")
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
  for l in output:gmatch("[^\n]+") do lines[#lines + 1] = l:gsub("%s+", "") end
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
  for l in output:gmatch("[^\n]+") do lines[#lines + 1] = l:gsub("%s+", "") end
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

-- ============================================================================
-- Unit tests — update expressions (++/--)
-- ============================================================================

test("i++ expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = i++;")
  assert(code:find("local _t = i"), "expected save of old value")
  assert(code:find("return _t"), "expected return of old value")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected increment")
end)

test("++i expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = ++i;")
  assert(not code:find("local _t"), "no temp for prefix")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected increment")
  assert(code:find("return i"), "expected return of new value")
end)

test("i-- expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = i--;")
  assert(code:find("local _t = i"), "expected save of old value")
  assert(code:find("i = i %- 1"), "expected decrement")
  assert(code:find("return _t"), "expected return of old value")
end)

test("--i expression form transpiles to IIFE", function()
  local code = transpile_ok("let x = --i;")
  assert(not code:find("local _t"), "no temp for prefix")
  assert(code:find("i = i %- 1"), "expected decrement")
  assert(code:find("return i"), "expected return of new value")
end)

test("i++ as statement emits plain assignment", function()
  local code = transpile_ok("i++;")
  assert(not code:find("function%("), "no IIFE in statement form")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected plain assignment")
end)

test("--i as statement emits plain assignment", function()
  local code = transpile_ok("--i;")
  assert(not code:find("function%("), "no IIFE in statement form")
  assert(code:find("i = i %- 1"), "expected plain assignment")
end)

test("i++ emits _ljs_add helper", function()
  local code = transpile_ok("i++;")
  assert(code:find("_ljs_add"), "expected _ljs_add helper in output")
end)

test("--i does not emit _ljs_add helper", function()
  local code = transpile_ok("--i;")
  assert(not code:find("_ljs_add"), "no _ljs_add helper needed for --")
end)

test("for with i++ update emits _ljs_add helper", function()
  local code = transpile_ok("for (let i = 0; i < 10; i++) { x; }")
  assert(code:find("_ljs_add"), "expected _ljs_add helper")
  assert(code:find("while i < 10 do"), "expected while condition")
end)

test("for with --i update does not emit _ljs_add", function()
  local code = transpile_ok("for (let i = 10; i > 0; --i) { x; }")
  assert(not code:find("_ljs_add"), "no _ljs_add for --i")
end)

-- ============================================================================
-- Integration tests — update expressions (++/--)
-- ============================================================================

test("i++ in for loop produces correct count", function()
  local output = run_js([[
    let result = "";
    for (let i = 0; i < 3; i++) {
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "012")
end)

test("i-- decrements correctly", function()
  local output = run_js([[
    let x = 5;
    x--;
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "4")
end)

test("postfix i++ returns old value", function()
  local output = run_js([[
    let x = 5;
    console.log(x++);
  ]])
  assert_eq(output:gsub("%s+", ""), "5")
end)

test("prefix ++i returns new value", function()
  local output = run_js([[
    let x = 5;
    console.log(++x);
  ]])
  assert_eq(output:gsub("%s+", ""), "6")
end)

-- ============================================================================
-- Unit tests — ternary operator
-- ============================================================================

test("ternary basic", function()
  assert_eq(expr_code("x ? 1 : 0"), ";(function() if x then return 1 else return 0 end end)()")
end)

test("ternary falsy consequent correctness", function()
  assert_eq(expr_code("true ? false : 0"), ";(function() if true then return false else return 0 end end)()")
end)

test("ternary in variable init", function()
  local code = transpile_ok("let x = a ? 1 : 0;")
  assert_eq(code, "local x = (function() if a then return 1 else return 0 end end)()\n")
end)

test("ternary nested", function()
  local code = expr_code("a ? b ? 1 : 2 : 3")
  assert(code:find("function%("), "expected IIFE in nested ternary")
end)

test("ternary in function return", function()
  local code = transpile_ok("function f(x) { return x ? 1 : 0; }")
  assert(code:find("return %(function%("), "expected IIFE in return")
end)

test("ternary integration: truthy branch", function()
  local output = run_lua_source("local a = true\nlocal x = (function() if a then return 1 else return 0 end end)()\nprint(x)\n")
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("ternary integration: falsy branch", function()
  local output = run_lua_source("local a = false\nlocal x = (function() if a then return 1 else return 0 end end)()\nprint(x)\n")
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("ternary integration: falsy consequent is not or'd away", function()
  local output = run_lua_source("local x = (function() if true then return false else return 0 end end)()\nprint(tostring(x))\n")
  assert_eq(output:gsub("%s+", ""), "false")
end)

test("ternary integration: end-to-end via transpile", function()
  local output = run_js("let a = true; let x = a ? 42 : 0; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "42")
end)

test("ternary integration: end-to-end falsy", function()
  local output = run_js("let a = false; let x = a ? 42 : 99; console.log(x);")
  assert_eq(output:gsub("%s+", ""), "99")
end)

test("ternary integration: side effects in untaken branch don't execute", function()
  local output = run_js(
    "let count = 0;" ..
    "function inc() { count = count + 1; return count; }" ..
    "let result = true ? 42 : inc();" ..
    "console.log(count);"
  )
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("ternary integration: side effects in taken branch do execute", function()
  local output = run_js(
    "let count = 0;" ..
    "function inc() { count = count + 1; return count; }" ..
    "let result = false ? 42 : inc();" ..
    "console.log(count);"
  )
  assert_eq(output:gsub("%s+", ""), "1")
end)

-- ============================================================================
-- Unit tests — functions
-- ============================================================================

test("function declaration", function()
  local code = transpile_ok("function foo(a, b) { return a; }")
  assert_eq(code, "local function foo(a, b)\n  return a\nend\n")
end)

test("arrow function in variable", function()
  local code = transpile_ok("const f = (x) => { return x; };")
  assert_eq(code, "local function f(x)\n  return x\nend\n")
end)

test("arrow expression body", function()
  local code = transpile_ok("const f = (x) => x + 1;")
  assert(code:find("local function f"), "expected local function f")
end)

-- ============================================================================
-- Unit tests — control flow
-- ============================================================================

test("if statement", function()
  local code = transpile_ok("if (x) { y; }")
  assert_eq(code, "if x then\n  y\nend\n")
end)

test("if/else", function()
  local code = transpile_ok("if (x) { a; } else { b; }")
  assert_eq(code, "if x then\n  a\nelse\n  b\nend\n")
end)

test("else if flattens to elseif", function()
  local code = transpile_ok("if (x) { a; } else if (y) { b; }")
  assert_eq(code, "if x then\n  a\nelseif y then\n  b\nend\n")
end)

test("nested else-if chain from blocks", function()
  local code = transpile_ok("if (a) { 1; } else { if (b) { 2; } else { 3; } }")
  assert_eq(code, "if a then\n  1\nelseif b then\n  2\nelse\n  3\nend\n")
end)

test("while loop", function()
  local code = transpile_ok("while (x) { y; }")
  assert_eq(code, "while x do\n  y\nend\n")
end)

test("for...of", function()
  local code = transpile_ok("for (const x of arr) { console.log(x); }")
  assert(code:find("for _, x in ipairs"), "expected for _, x in ipairs")
end)

-- ============================================================================
-- for...in transpile tests
-- ============================================================================

test("for...in with let transpiles to pairs", function()
  local code = transpile_ok("for (let key in obj) { console.log(key); }")
  assert(code:find("for key, _ in pairs"), "expected for key, _ in pairs")
end)

test("for...in with const transpiles to pairs", function()
  local code = transpile_ok("for (const k in obj) { k; }")
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
end)

test("for...in with expression left transpiles to pairs (no local)", function()
  local code = transpile_ok("for (key in obj) { key; }")
  assert(code:find("for key, _ in pairs"), "expected for key, _ in pairs")
end)

test("for...in with object literal right transpiles correctly", function()
  local code = transpile_ok('for (let k in {a: 1}) { k; }')
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
  assert(code:find("{a = 1}"), "expected object literal")
end)

test("for...in nested with for...of transpiles correctly", function()
  local code = transpile_ok("for (let k in obj) { for (const x of arr) { k; } }")
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
  assert(code:find("for _, x in ipairs"), "expected for _, x in ipairs")
end)

test("for...in with console.log uses helper", function()
  local code = transpile_ok("for (let k in obj) { console.log(k); }")
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
  assert(code:find("_ljs_log"), "expected _ljs_log helper")
end)

test("for-of still transpiles correctly after for-in (regression)", function()
  local code = transpile_ok("for (const x of arr) { console.log(x); }")
  assert(code:find("for _, x in ipairs"), "expected for _, x in ipairs")
end)

-- ============================================================================
-- C-style for(;;) transpile tests
-- ============================================================================

test("for(;;) transpiles to while true", function()
  local code = transpile_ok("for (;;) { x; }")
  assert(code:find("while true do"), "expected 'while true do'")
  assert(not code:find("_ljs_add"), "no _ljs_add helper needed")
end)

test("full for with let init transpiles correctly", function()
  local code = transpile_ok("for (let i = 0; i < 10; i = i + 1) { console.log(i); }")
  assert(code:find("local i = 0"), "expected 'local i = 0'")
  assert(code:find("while i < 10 do"), "expected 'while i < 10 do'")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected update 'i = _ljs_add(i, 1)'")
end)

test("for with expression init transpiles correctly", function()
  local code = transpile_ok("for (i = 0; i < 5; i = i + 1) { x; }")
  assert(code:find("i = 0"), "expected 'i = 0' (no local)")
  assert(not code:find("local i"), "no local for expression init")
  assert(code:find("while i < 5 do"), "expected 'while i < 5 do'")
end)

test("for with nil update transpiles correctly", function()
  local code = transpile_ok("for (let x = 1; x < 5; ) { x; }")
  assert(code:find("local x = 1"), "expected 'local x = 1'")
  assert(code:find("while x < 5 do"), "expected 'while x < 5 do'")
  local _, n = code:gsub("x = ", "")
  assert_eq(n, 1, "only the init assignment, no update")
end)

test("for with nil init+nil test transpiles correctly", function()
  local code = transpile_ok("for (;; x = x + 1) { y; }")
  assert(code:find("while true do"), "expected 'while true do'")
  assert(code:find("_ljs_add%(x, 1%)"), "expected update before end")
end)

test("for with nil test transpiles to while true", function()
  local code = transpile_ok("for (let x = 1; ; ) { x; }")
  assert(code:find("local x = 1"), "expected init")
  assert(code:find("while true do"), "expected 'while true do'")
end)

test("for with nil init transpiles correctly", function()
  local code = transpile_ok("for (; x < 10; x = x + 1) { y; }")
  assert(not code:find("local x"), "no init")
  assert(code:find("while x < 10 do"), "expected 'while x < 10 do'")
  assert(code:find("_ljs_add%(x, 1%)"), "expected update")
end)

test("nested for loops transpile with correct indentation", function()
  local code = transpile_ok("for (;;) { for (let j = 0; j < 3; j = j + 1) { x; } }")
  assert(code:find("while true do"), "outer while true")
  assert(code:find("local j = 0"), "inner init")
  assert(code:find("while j < 3 do"), "inner while")
end)

test("for-of still transpiles correctly (regression)", function()
  local code = transpile_ok("for (const x of arr) { console.log(x); }")
  assert(code:find("for _, x in ipairs"), "expected for _, x in ipairs")
end)

test("for update placed at end of body", function()
  local code = transpile_ok("for (let i = 0; i < 2; i = i + 1) { f(i); }")
  local body_start = code:find("do\n")
  local update_pos = code:find("i = _ljs_add")
  local end_pos = code:find("end", update_pos)
  assert(update_pos ~= nil, "expected update")
  assert(end_pos ~= nil, "expected end after update")
  assert(update_pos < end_pos, "update should come before end")
end)

test("for with no semicolons in Lua output", function()
  local code = transpile_ok("for (let i = 0; i < 3; i = i + 1) { x; }")
  assert(not code:find(";"), "no semicolons in Lua output")
end)

test("for(;;) scoping: let init uses local", function()
  local code = transpile_ok("for (let i = 0; i < 1; i = i + 1) { x; }")
  assert(code:find("local i = 0"), "expected 'local i = 0'")
end)

test("for(;;) scoping: expression init does not use local", function()
  local code = transpile_ok("for (i = 0; i < 1; i = i + 1) { x; }")
  assert(not code:find("local i"), "no local for expression init")
  assert(code:find("i = 0"), "expected bare 'i = 0'")
end)

test("for(;;) var init transpiles same as let", function()
  local code = transpile_ok("for (var i = 0; i < 3; i = i + 1) { x; }")
  assert(code:find("local i = 0"), "var normalized to local")
  assert(code:find("while i < 3 do"), "expected while condition")
end)

-- ============================================================================
-- Unit tests — objects and arrays
-- ============================================================================

test("empty object", function()
  local code = expr_code("({});")
  assert_eq(code, "{}")
end)

test("object with identifier keys", function()
  local code = expr_code("({a: 1, b: 2});")
  assert_eq(code, "{a = 1, b = 2}")
end)

test("object with string keys", function()
  local code = expr_code('({"key": 1});')
  assert_eq(code, '{["key"] = 1}')
end)

test("empty array", function()
  local code = expr_code("[]")
  assert_eq(code, "{}")
end)

test("array with elements", function()
  local code = expr_code("[1, 2, 3]")
  assert_eq(code, "{1, 2, 3}")
end)

test("dot access", function()
  local code = expr_code("obj.prop")
  assert_eq(code, "obj.prop")
end)

test("computed string key no offset", function()
  local code = expr_code('obj["key"]')
  assert_eq(code, 'obj["key"]')
end)

test("computed expression key adds offset", function()
  local code = expr_code("arr[i]")
  assert_eq(code, "arr[(i) + 1]")
end)

-- ============================================================================
-- Unit tests — console.log
-- ============================================================================

test("console.log uses helper", function()
  local code = transpile_ok("console.log(x);")
  assert(code:find("_ljs_log%(x%)"), "expected _ljs_log(x)")
  assert(code:find("local function _ljs_log"), "expected _ljs_log helper definition")
end)

test("console.log with multiple args", function()
  local code = transpile_ok('console.log("a", "b");')
  assert(code:find('_ljs_log%("a", "b"%)'), "expected _ljs_log with multiple args")
end)

-- ============================================================================
-- Unit tests — exception handling
-- ============================================================================

test("throw", function()
  local code = transpile_ok('throw "error";')
  assert_eq(code, 'error("error", 0)\n')
end)

test("try/catch", function()
  local code = transpile_ok("try { x; } catch (e) { y; }")
  assert(code:find("pcall"), "expected pcall in output")
  assert(code:find("local ok, e"), "expected local ok, e")
  assert(code:find("if not ok then"), "expected if not ok then")
end)

-- ============================================================================
-- Unit tests — helpers emission
-- ============================================================================

test("no helpers when unused", function()
  local code = transpile_ok("let x = 1;")
  assert(not code:find("_ljs_"), "expected no helpers")
end)

test("_ljs_add only when + used", function()
  local code = transpile_ok("let x = 1 * 2;")
  assert(not code:find("_ljs_add"), "expected no _ljs_add")
end)

test("transpile.HELPERS accessible", function()
  assert(type(transpile.HELPERS) == "table", "expected HELPERS table")
  assert(type(transpile.HELPERS._ljs_add) == "string", "expected _ljs_add helper")
  assert(type(transpile.HELPERS._ljs_log) == "string", "expected _ljs_log helper")
end)

-- ============================================================================
-- Unit tests — BUILTINS registry
-- ============================================================================

test("transpile.BUILTINS accessible", function()
  assert(type(transpile.BUILTINS) == "table", "expected BUILTINS table")
  assert(type(transpile.BUILTINS.console) == "table", "expected console entry")
  assert(type(transpile.BUILTINS.console.log) == "table", "expected console.log entry")
  assert_eq(transpile.BUILTINS.console.log.helper, "_ljs_log", "console.log helper name")
end)

test("shadowed console.log does not emit helper", function()
  local code = transpile_ok("let console = {}; console.log(x);")
  assert(not code:find("_ljs_log"), "shadowed console.log should not use helper")
  assert(code:find("console%.log"), "should emit plain member call")
end)

-- ============================================================================
-- Integration tests — example programs
-- ============================================================================

test("fibonacci produces correct output", function()
  local js = read_file("examples/01_fibonacci.js")
  local output = run_js(js)
  assert(output:find("fib%(0%) = 0"), "expected fib(0) = 0")
  assert(output:find("fib%(1%) = 1"), "expected fib(1) = 1")
  assert(output:find("fib%(10%) = 55"), "expected fib(10) = 55")
end)

test("fizzbuzz produces correct output", function()
  local js = read_file("examples/02_fizzbuzz.js")
  local output = run_js(js)
  assert(output:find("FizzBuzz"), "expected FizzBuzz")
  assert(output:find("Fizz"), "expected Fizz")
  assert(output:find("Buzz"), "expected Buzz")
end)

test("shapes produces correct output", function()
  local js = read_file("examples/03_shapes.js")
  local output = run_js(js)
  assert(output:find("Shape Areas"), "expected Shape Areas header")
  assert(output:find("Circle %(r=5%) = 78%.539"), "expected Circle area")
  assert(output:find("Rectangle %(3x4%) = 12"), "expected Rectangle area")
end)

test("caesar produces correct output", function()
  local js = read_file("examples/04_caesar.js")
  local output = run_js(js)
  assert(output:find("Original: hello world"), "expected Original line")
  assert(output:find("H shifted by 3 = k"), "expected H shifted")
end)

test("factorial produces correct output", function()
  local js = read_file("examples/05_factorial.js")
  local output = run_js(js)
  assert(output:find("5%! ="), "expected 5!")
  assert(output:find("120"), "expected 120")
  assert(output:find("3628800"), "expected 3628800")
end)

test("loops produces correct output", function()
  local js = read_file("examples/06_loops.js")
  local output = run_js(js)
  assert(output:find("for%.%.of sum:%s*150"), "expected for..of sum 150")
  assert(output:find("for%(;%;%) sum:%s*150"), "expected for(;;) sum 150")
  assert(output:find("while sum:%s*150"), "expected while sum 150")
end)

test("strcat produces correct output", function()
  local js = read_file("examples/07_strcat.js")
  local output = run_js(js)
  assert(output:find("alpha beta gamma"), "expected concatenated string")
  assert(output:find("alpha alpha alpha alpha alpha"), "expected repeated string")
  assert(output:find("x: 42, y: 7"), "expected mixed concatenation")
end)

test("trycatch produces correct output", function()
  local js = read_file("examples/08_trycatch.js")
  local output = run_js(js)
  assert(output:find("caught:%s*5"), "expected caught: 5")
  assert(output:find("error:%s*too big"), "expected error: too big")
  assert(output:find("10/2 ="), "expected 10/2 result")
  assert(output:find("caught:%s*division by zero"), "expected division by zero")
end)

test("arrows produces correct output", function()
  local js = read_file("examples/09_arrows.js")
  local output = run_js(js)
  assert(output:find("double%(5%):%s*10"), "expected double(5): 10")
  assert(output:find("add%(3, 4%):%s*7"), "expected add(3, 4): 7")
  assert(output:find("apply%(double, 7%):%s*14"), "expected apply(double, 7): 14")
  assert(output:find("sum:%s*15"), "expected sum: 15")
  assert(output:find("add5%(3%):%s*8"), "expected add5(3): 8")
  assert(output:find("add5%(10%):%s*15"), "expected add5(10): 15")
end)

-- ============================================================================
-- Unit tests — switch/case/break
-- ============================================================================

test("switch basic with break", function()
  local code = transpile_ok("switch (x) { case 1: a; break; }")
  assert(code:find("local _ljs_sw = x"), "expected _ljs_sw local")
  assert(code:find("for _ = 1, 1 do"), "expected for loop wrapper")
  assert(code:find("_ljs_matched or _ljs_sw == 1"), "expected case guard")
  assert(code:find("_ljs_matched = true"), "expected matched flag set")
  assert(code:find("break"), "expected break")
end)

test("switch with default", function()
  local code = transpile_ok("switch (x) { case 1: a; break; default: b; break; }")
  assert(code:find("_ljs_sw == 1"), "expected case 1 guard")
  assert(code:find("if true then"), "expected default wrapped in if true")
end)

test("switch with fallthrough", function()
  local code = transpile_ok("switch (x) { case 1: case 2: a; break; }")
  local _, n = code:gsub("_ljs_matched = true", "")
  assert_eq(n, 2, "both cases should set matched flag")
end)

test("empty switch", function()
  local code = transpile_ok("switch (x) {}")
  assert(code:find("local _ljs_sw = x"), "expected _ljs_sw local")
  assert(code:find("for _ = 1, 1 do"), "expected for loop wrapper")
end)

test("switch default only", function()
  local code = transpile_ok("switch (x) { default: y; }")
  assert(code:find("if true then"), "expected default wrapped in if true")
  assert(code:find("y"), "expected default body")
end)

test("break statement emits Lua break", function()
  local code = transpile_ok("switch (x) { case 1: break; }")
  assert(code:find("break\n"), "expected Lua break")
end)

test("break inside while loop (not switch)", function()
  local code = transpile_ok("while (true) { break; }")
  assert(code:find("break\n"), "expected Lua break in while")
end)

test("nested switch uses same variable names (shadowing)", function()
  local code = transpile_ok("switch (a) { case 1: switch (b) { case 2: break; } break; }")
  local _, n = code:gsub("local _ljs_sw", "")
  assert_eq(n, 2, "expected two _ljs_sw declarations (shadowing)")
end)

-- ============================================================================
-- Integration tests — switch/case
-- ============================================================================

test("switch integration: matches correct case", function()
  local output = run_js([[
    let x = 2;
    switch (x) {
      case 1: console.log("one"); break;
      case 2: console.log("two"); break;
      case 3: console.log("three"); break;
    }
  ]])
  assert_eq(output:gsub("%s+", ""), "two")
end)

test("switch integration: default runs when no match", function()
  local output = run_js([[
    let x = 99;
    switch (x) {
      case 1: console.log("one"); break;
      default: console.log("other"); break;
    }
  ]])
  assert_eq(output:gsub("%s+", ""), "other")
end)

test("switch integration: fallthrough", function()
  local output = run_js([[
    let x = 1;
    let result = "";
    switch (x) {
      case 1: result = result + "a";
      case 2: result = result + "b"; break;
      case 3: result = result + "c"; break;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "ab")
end)

test("switch integration: no fallthrough when break present", function()
  local output = run_js([[
    let x = 2;
    let result = "";
    switch (x) {
      case 1: result = result + "a"; break;
      case 2: result = result + "b"; break;
      case 3: result = result + "c"; break;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "b")
end)

test("switch integration: string cases", function()
  local output = run_js([[
    let x = "hello";
    switch (x) {
      case "hello": console.log("hi"); break;
      case "bye": console.log("cya"); break;
    }
  ]])
  assert_eq(output:gsub("%s+", ""), "hi")
end)

test("switch integration: nested switch", function()
  local output = run_js([[
    let a = 1;
    let b = 2;
    switch (a) {
      case 1:
        switch (b) {
          case 1: console.log("1-1"); break;
          case 2: console.log("1-2"); break;
        }
        break;
      case 2: console.log("2"); break;
    }
  ]])
  assert_eq(output:gsub("%s+", ""), "1-2")
end)

test("switch integration: default in middle", function()
  local output = run_js([[
    let x = 5;
    switch (x) {
      case 1: console.log("one"); break;
      default: console.log("other"); break;
      case 2: console.log("two"); break;
    }
  ]])
  assert_eq(output:gsub("%s+", ""), "other")
end)

test("switch integration: switch inside while with break", function()
  local output = run_js([[
    let i = 0;
    while (i < 3) {
      switch (i) {
        case 1: console.log("one"); break;
        default: console.log("other"); break;
      }
      i++;
    }
  ]])
  assert(output:find("other"), "expected other for i=0")
  assert(output:find("one"), "expected one for i=1")
end)

-- ============================================================================
-- Unit tests — continue
-- ============================================================================

test("continue in while emits goto _continue with label", function()
  local code = transpile_ok("while (true) { continue; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("continue in for-of emits goto _continue with label", function()
  local code = transpile_ok("for (let x of arr) { continue; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("continue in for-in emits goto _continue with label", function()
  local code = transpile_ok("for (let k in obj) { continue; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("continue in C-style for emits goto _continue with label", function()
  local code = transpile_ok("for (let i = 0; i < 10; i++) { continue; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("for loop with continue: label placed before update", function()
  local code = transpile_ok("for (let i = 0; i < 10; i++) { if (i === 2) { continue; } x; }")
  local label_pos = code:find("::_continue::")
  local update_pos = code:find("i = _ljs_add") or code:find("i = i %- 1")
  assert(label_pos, "expected ::_continue:: label")
  assert(update_pos, "expected update expression")
  assert(label_pos < update_pos, "label should come before update")
end)

test("while loop without continue has no label", function()
  local code = transpile_ok("while (true) { x; }")
  assert(not code:find("::_continue::"), "unexpected ::_continue:: label")
  assert(not code:find("goto _continue"), "unexpected goto _continue")
end)

test("for loop without continue has no label", function()
  local code = transpile_ok("for (let i = 0; i < 10; i++) { x; }")
  assert(not code:find("::_continue::"), "unexpected ::_continue:: label")
end)

test("continue inside nested if in while", function()
  local code = transpile_ok("while (x) { if (a) { continue; } b; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("multiple continues in same loop produce one label", function()
  local code = transpile_ok("while (x) { if (a) { continue; } if (b) { continue; } c; }")
  local _, goto_count = code:gsub("goto _continue", "")
  assert_eq(goto_count, 2, "expected 2 goto _continue")
  local _, label_count = code:gsub("::_continue::", "")
  assert_eq(label_count, 1, "expected exactly 1 ::_continue:: label")
end)

test("continue inside switch inside while", function()
  local code = transpile_ok("while (x) { switch (a) { case 1: continue; } b; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("nested loops each get own label via lexical scoping", function()
  local code = transpile_ok([[
    while (a) {
      while (b) {
        if (c) { continue; }
        d;
      }
      if (e) { continue; }
      f;
    }
  ]])
  local _, label_count = code:gsub("::_continue::", "")
  assert_eq(label_count, 2, "expected 2 ::_continue:: labels (one per loop)")
  local _, goto_count = code:gsub("goto _continue", "")
  assert_eq(goto_count, 2, "expected 2 goto _continue")
end)

test("continue as last statement in loop body", function()
  local code = transpile_ok("while (x) { a; continue; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("continue in for-of nested inside while", function()
  local code = transpile_ok("while (a) { for (let x of b) { continue; } continue; }")
  local _, label_count = code:gsub("::_continue::", "")
  assert_eq(label_count, 2, "expected 2 labels (one per loop)")
  local _, goto_count = code:gsub("goto _continue", "")
  assert_eq(goto_count, 2, "expected 2 gotos")
end)

test("for-of without continue has no label", function()
  local code = transpile_ok("for (let x of arr) { x; }")
  assert(not code:find("::_continue::"), "unexpected ::_continue:: label")
end)

test("for-in without continue has no label", function()
  local code = transpile_ok("for (let k in obj) { k; }")
  assert(not code:find("::_continue::"), "unexpected ::_continue:: label")
end)

-- ============================================================================
-- Integration tests — continue
-- ============================================================================

test("continue integration: skips rest of while body", function()
  local output = run_js([[
    let i = 0;
    let result = "";
    while (i < 5) {
      i++;
      if (i === 3) { continue; }
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "1245")
end)

test("continue integration: for-of skip element", function()
  local output = run_js([[
    let result = "";
    for (let x of [1, 2, 3, 4]) {
      if (x === 2 || x === 4) { continue; }
      result = result + x;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "13")
end)

test("continue integration: C-style for update still runs", function()
  local output = run_js([[
    let result = "";
    for (let i = 0; i < 5; i++) {
      if (i === 2) { continue; }
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "0134")
end)

test("continue integration: for-in skip key", function()
  local output = run_js([[
    let result = "";
    let obj = {a: 1, b: 2, c: 3};
    for (let k in obj) {
      if (k === "b") { continue; }
      result = result + k;
    }
    console.log(result);
  ]])
  assert(not output:find("b"), "b should be skipped")
  assert(output:find("a"), "expected a")
  assert(output:find("c"), "expected c")
end)

test("continue integration: nested loops independent", function()
  local output = run_js([[
    let result = "";
    let i = 0;
    while (i < 3) {
      let j = 0;
      while (j < 3) {
        j++;
        if (j === 2) { continue; }
        result = result + i + ":" + j + " ";
      }
      i++;
    }
    console.log(result);
  ]])
  assert(not output:find(":2"), "j=2 should be skipped in all iterations")
  assert(output:find("0:1"), "expected 0:1")
  assert(output:find("0:3"), "expected 0:3")
  assert(output:find("1:1"), "expected 1:1")
  assert(output:find("2:3"), "expected 2:3")
end)

test("continue integration: inside switch inside while", function()
  local output = run_js([[
    let result = "";
    let i = 0;
    while (i < 4) {
      i++;
      switch (i) {
        case 2: continue;
        default: result = result + i;
      }
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "134")
end)

test("continue integration: continue and break in same loop", function()
  local output = run_js([[
    let result = "";
    let i = 0;
    while (i < 10) {
      i++;
      if (i === 3) { continue; }
      if (i === 6) { break; }
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "1245")
end)

test("continue integration: continue as only statement in loop", function()
  local output = run_js([[
    let count = 0;
    let i = 0;
    while (i < 5) {
      i++;
      if (i < 10) { continue; }
      count = count + 1;
    }
    console.log(count);
  ]])
  assert_eq(output:gsub("%s+", ""), "0")
end)

test("continue integration: continue inside deeply nested if", function()
  local output = run_js([[
    let result = "";
    for (let i = 0; i < 5; i++) {
      if (i > 0) {
        if (i === 3) {
          continue;
        }
      }
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "0124")
end)

test("continue integration: C-style for with continue hitting every iteration", function()
  local output = run_js([[
    let result = "";
    for (let i = 0; i < 5; i++) {
      if (i < 10) { continue; }
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "")
end)

test("continue integration: continue and break in for-of", function()
  local output = run_js([[
    let result = "";
    for (let x of [1, 2, 3, 4, 5]) {
      if (x === 2) { continue; }
      if (x === 5) { break; }
      result = result + x;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "134")
end)

test("continue integration: for-of inside while with continue in both", function()
  local output = run_js([[
    let result = "";
    let i = 0;
    while (i < 3) {
      i++;
      if (i === 2) { continue; }
      for (let x of [10, 20]) {
        if (x === 10) { continue; }
        result = result + i + ":" + x + " ";
      }
    }
    console.log(result);
  ]])
  assert(not output:find(":10"), "x=10 should be skipped")
  assert(not output:find("2:"), "i=2 should be skipped")
  assert(output:find("1:20"), "expected 1:20")
  assert(output:find("3:20"), "expected 3:20")
end)

-- ============================================================================
-- Unit tests — do...while transpile
-- ============================================================================

test("do-while basic with braces", function()
  local code = transpile_ok("do { x = x + 1; } while (x < 10);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(x < 10%)"), "expected until not (x < 10)")
end)

test("do-while without braces", function()
  local code = transpile_ok("do x = x + 1; while (x < 10);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(x < 10%)"), "expected until not (x < 10)")
end)

test("do-while with true condition", function()
  local code = transpile_ok("do { x; } while (true);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(true%)"), "expected until not (true)")
end)

test("do-while with false condition", function()
  local code = transpile_ok("do { x; } while (false);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(false%)"), "expected until not (false)")
end)

test("do-while with number as condition", function()
  local code = transpile_ok("do { x; } while (1);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(1%)"), "expected until not (1)")
end)

test("do-while with identifier condition", function()
  local code = transpile_ok("do { x; } while (done);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(done%)"), "expected until not (done)")
end)

test("do-while with logical condition (parens essential)", function()
  local code = transpile_ok("do { y; } while (a && b);")
  assert(code:find("until not %(a and b%)"), "expected until not (a and b) with parens")
end)

test("do-while with unary negation condition", function()
  local code = transpile_ok("do { y; } while (!done);")
  assert(code:find("until not %(not done%)"), "expected until not (not done)")
end)

test("do-while with comparison condition", function()
  local code = transpile_ok("do { y; } while (a + b > 0);")
  assert(code:find("until not %("), "expected until not (...)")
end)

test("do-while with strict inequality condition", function()
  local code = transpile_ok("do { y; } while (x !== 0);")
  assert(code:find("until not %(x ~= 0%)"), "expected until not (x ~= 0)")
end)

test("do-while with call expression condition", function()
  local code = transpile_ok("do { y; } while (shouldContinue());")
  assert(code:find("until not %(shouldContinue%(%)%)"), "expected until not (shouldContinue())")
end)

test("do-while with member expression condition", function()
  local code = transpile_ok("do { y; } while (obj.active);")
  assert(code:find("until not %(obj%.active%)"), "expected until not (obj.active)")
end)

test("do-while with ternary condition", function()
  local code = transpile_ok("do { y; } while (flag ? true : false);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %("), "expected until not (...)")
end)

test("do-while empty body", function()
  local code = transpile_ok("do {} while (cond);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(cond%)"), "expected until not (cond)")
end)

test("do-while body with multiple statements", function()
  local code = transpile_ok("do { x = x + 1; y = y + 1; } while (x < 10);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(x < 10%)"), "expected until not (x < 10)")
end)

-- ============================================================================
-- do-while break tests
-- ============================================================================

test("break inside do-while", function()
  local code = transpile_ok("do { break; } while (true);")
  assert(code:find("break\n"), "expected Lua break")
end)

test("conditional break inside do-while", function()
  local code = transpile_ok("do { if (x > 5) { break; } x = x + 1; } while (x < 10);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("break"), "expected break")
end)

-- ============================================================================
-- do-while continue tests
-- ============================================================================

test("continue in do-while emits goto _continue with label", function()
  local code = transpile_ok("do { continue; } while (x);")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("do-while without continue has no label", function()
  local code = transpile_ok("do { x; } while (y);")
  assert(not code:find("::_continue::"), "unexpected ::_continue:: label")
  assert(not code:find("goto _continue"), "unexpected goto _continue")
end)

test("multiple continues in do-while produce one label", function()
  local code = transpile_ok("do { if (a) { continue; } if (b) { continue; } c; } while (x);")
  local _, goto_count = code:gsub("goto _continue", "")
  assert_eq(goto_count, 2, "expected 2 goto _continue")
  local _, label_count = code:gsub("::_continue::", "")
  assert_eq(label_count, 1, "expected exactly 1 ::_continue:: label")
end)

test("continue and break together in do-while", function()
  local code = transpile_ok("do { if (a) { continue; } if (b) { break; } c; } while (x);")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
  assert(code:find("break"), "expected break")
end)

-- ============================================================================
-- do-while nesting tests
-- ============================================================================

test("nested do-while loops", function()
  local code = transpile_ok("do do { x; } while (a); while (b);")
  local _, count = code:gsub("repeat", "")
  assert_eq(count, 2, "expected 2 repeat")
end)

test("do-while inside while", function()
  local code = transpile_ok("while (a) { do { x; } while (b); }")
  assert(code:find("while a do"), "expected while a do")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(b%)"), "expected until not (b)")
end)

test("while inside do-while", function()
  local code = transpile_ok("do while (a) { x; } while (b);")
  assert(code:find("repeat"), "expected outer repeat")
  assert(code:find("while a do"), "expected inner while a do")
  assert(code:find("until not %(b%)"), "expected until not (b)")
end)

test("do-while inside for loop", function()
  local code = transpile_ok("for (;;) { do { x; } while (b); }")
  assert(code:find("while true do"), "expected outer while true do")
  assert(code:find("repeat"), "expected inner repeat")
end)

test("do-while inside if", function()
  local code = transpile_ok("if (a) { do { x; } while (b); }")
  assert(code:find("if a then"), "expected if a then")
  assert(code:find("repeat"), "expected repeat")
end)

test("do-while inside function", function()
  local code = transpile_ok("function f() { do { x; } while (b); }")
  assert(code:find("local function f"), "expected local function f")
  assert(code:find("repeat"), "expected repeat")
end)

test("multiple do-while in sequence", function()
  local code = transpile_ok("do { a; } while (x); do { b; } while (y);")
  local _, count = code:gsub("repeat", "")
  assert_eq(count, 2, "expected 2 repeat")
  assert(code:find("until not %(x%)"), "expected until not (x)")
  assert(code:find("until not %(y%)"), "expected until not (y)")
end)

-- ============================================================================
-- do-while edge cases / weird bodies
-- ============================================================================

test("do-while body is throw", function()
  local code = transpile_ok("do throw e; while (false);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("error"), "expected error for throw")
end)

test("do-while body is return", function()
  local code = transpile_ok("function f() { do return x; while (b); }")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("return"), "expected return")
end)

test("do-while body is if statement", function()
  local code = transpile_ok("do if (a) { x; } while (b);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("until not %(b%)"), "expected until not (b)")
end)

test("do-while body is while loop", function()
  local code = transpile_ok("do while (a) { x; } while (b);")
  assert(code:find("repeat"), "expected outer repeat")
  assert(code:find("while a do"), "expected inner while")
end)

test("do-while body is variable declaration", function()
  local code = transpile_ok("do let x = 1; while (b);")
  assert(code:find("repeat"), "expected repeat")
  assert(code:find("local x"), "expected local x")
end)

test("do-while body is update expression", function()
  local code = transpile_ok("do x++; while (y < 10);")
  assert(code:find("repeat"), "expected repeat")
end)

test("do-while with no semicolons in Lua output", function()
  local code = transpile_ok("do { x = x + 1; } while (x < 10);")
  assert(not code:find(";"), "no semicolons in Lua output")
end)

-- ============================================================================
-- do-while indentation tests
-- ============================================================================

test("do-while indented inside function", function()
  local code = transpile_ok("function f() { do { x; } while (b); }")
  assert(code:find("  repeat"), "expected repeat indented")
  assert(code:find("  until"), "expected until indented")
end)

test("nested do-while indentation", function()
  local code = transpile_ok("do do { x; } while (a); while (b);")
  local inner = code:find("repeat")
  local outer = code:find("repeat", inner + 1)
  assert(inner ~= nil, "expected inner repeat")
  assert(outer ~= nil, "expected outer repeat")
end)

-- ============================================================================
-- Integration tests — do-while
-- ============================================================================

test("do-while integration: body runs once with false condition", function()
  local output = run_js([[
    let x = 0;
    do { x = x + 1; } while (false);
    console.log(x);
  ]])
  assert_eq(output:gsub("%s+", ""), "1")
end)

test("do-while integration: basic counting", function()
  local output = run_js([[
    let i = 0;
    do { i = i + 1; } while (i < 3);
    console.log(i);
  ]])
  assert_eq(output:gsub("%s+", ""), "3")
end)

test("do-while integration: break exits loop", function()
  local output = run_js([[
    let i = 0;
    do {
      i = i + 1;
      if (i === 2) { break; }
    } while (i < 10);
    console.log(i);
  ]])
  assert_eq(output:gsub("%s+", ""), "2")
end)

test("do-while integration: continue skips to condition", function()
  local output = run_js([[
    let i = 0;
    let result = "";
    do {
      i = i + 1;
      if (i === 3) { continue; }
      result = result + i;
    } while (i < 5);
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "1245")
end)

test("do-while integration: accumulator pattern", function()
  local output = run_js([[
    let sum = 0;
    let i = 1;
    do {
      sum = sum + i;
      i = i + 1;
    } while (i <= 5);
    console.log(sum);
  ]])
  assert_eq(output:gsub("%s+", ""), "15")
end)

test("do-while integration: nested do-while", function()
  local output = run_js([[
    let result = "";
    let i = 0;
    do {
      let j = 0;
      do {
        result = result + i + ":" + j + " ";
        j = j + 1;
      } while (j < 2);
      i = i + 1;
    } while (i < 2);
    console.log(result);
  ]])
  assert(output:find("0:0"), "expected 0:0")
  assert(output:find("0:1"), "expected 0:1")
  assert(output:find("1:0"), "expected 1:0")
  assert(output:find("1:1"), "expected 1:1")
end)

test("do-while integration: while(false) vs do-while(false)", function()
  local output = run_js([[
    let x = 0;
    while (false) { x = 1; }
    let y = 0;
    do { y = 1; } while (false);
    console.log(x + "," + y);
  ]])
  assert_eq(output:gsub("%s+", ""), "0,1")
end)

test("do-while integration: continue inside switch inside do-while", function()
  local output = run_js([[
    let i = 0;
    let result = "";
    do {
      i = i + 1;
      switch (i) {
        case 2: continue;
      }
      result = result + i;
    } while (i < 4);
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "134")
end)

test("do-while integration: break and continue together", function()
  local output = run_js([[
    let i = 0;
    let result = "";
    do {
      i = i + 1;
      if (i === 3) { continue; }
      if (i === 7) { break; }
      result = result + i;
    } while (i < 20);
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "12456")
end)

-- ============================================================================
-- Summary
-- ============================================================================

T.summary()
