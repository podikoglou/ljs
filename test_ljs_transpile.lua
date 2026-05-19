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
-- Unit tests — ternary operator
-- ============================================================================

test("ternary basic", function()
  assert_eq(expr_code("x ? 1 : 0"), "(function() if x then return 1 else return 0 end end)()")
end)

test("ternary falsy consequent correctness", function()
  assert_eq(expr_code("true ? false : 0"), "(function() if true then return false else return 0 end end)()")
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
      i = i + 1;
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
  local code = transpile_ok("for (let i = 0; i < 10; i = i + 1) { continue; }")
  assert(code:find("goto _continue"), "expected goto _continue")
  assert(code:find("::_continue::"), "expected ::_continue:: label")
end)

test("for loop with continue: label placed before update", function()
  local code = transpile_ok("for (let i = 0; i < 10; i = i + 1) { if (i === 2) { continue; } x; }")
  local label_pos = code:find("::_continue::")
  local update_pos = code:find("i = _ljs_add") or code:find("i = i %+ 1")
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
  local code = transpile_ok("for (let i = 0; i < 10; i = i + 1) { x; }")
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

-- ============================================================================
-- Integration tests — continue
-- ============================================================================

test("continue integration: skips rest of while body", function()
  local output = run_js([[
    let i = 0;
    let result = "";
    while (i < 5) {
      i = i + 1;
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
    for (let i = 0; i < 5; i = i + 1) {
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
        j = j + 1;
        if (j === 2) { continue; }
        result = result + i + ":" + j + " ";
      }
      i = i + 1;
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
      i = i + 1;
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
      i = i + 1;
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
      i = i + 1;
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
    for (let i = 0; i < 5; i = i + 1) {
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
    for (let i = 0; i < 5; i = i + 1) {
      if (i < 10) { continue; }
      result = result + i;
    }
    console.log(result);
  ]])
  assert_eq(output:gsub("%s+", ""), "")
end)

-- ============================================================================
-- Summary
-- ============================================================================

T.summary()
