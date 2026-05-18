local transpile = require("ljs_transpile")
local parser = require("ljs_parser")
local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. " - " .. tostring(err))
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", msg or "assertion", expected, actual))
  end
end

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

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
