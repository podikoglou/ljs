local T = require("ljs_test")
local H = require("ljs_test_transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok = H.transpile_ok

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

T.summary()
