local T = require("test.ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, emit_ok, run_js = H.transpile_ok, H.emit_ok, H.run_js

-- ============================================================================
-- Unit tests — functions
-- ============================================================================

test("function declaration", function()
  local code = transpile_ok("function foo(a, b) { return a; }")
  assert(
    code:find("local foo\nfoo = _ljs_ctor(function(_ljs_this, a, b)", 1, true),
    "expected two-step _ljs_ctor wrapping foo"
  )
  assert(code:find("local _ljs_arrow_this = _ljs_this", 1, true), "expected _ljs_arrow_this init")
  assert(code:find("return a", 1, true), "expected return a")
end)

test("arrow function in variable", function()
  local code = transpile_ok("const f = (x) => { return x; };")
  assert(
    code:find("local f\nf = _ljs_fn(function(_ljs_this, x)", 1, true),
    "expected _ljs_fn wrapped arrow"
  )
  assert(
    code:find("local _ljs_arrow_this = _ljs_arrow_this", 1, true),
    "expected _ljs_arrow_this init"
  )
end)

test("arrow expression body", function()
  local code = transpile_ok("const f = (x) => x + 1;")
  assert(code:find("local f\nf = _ljs_fn(", 1, true), "expected _ljs_fn wrapping")
end)

-- ============================================================================
-- Unit tests — control flow
-- ============================================================================

test("if statement", function()
  local code = transpile_ok("if (x) { y; }")
  assert(code:find("if _ljs_to_boolean(x) then\n  local _ = y\nend\n", 1, true), "expected if x then local _ = y end")
end)

test("if/else", function()
  local code = transpile_ok("if (x) { a; } else { b; }")
  assert(code:find("if _ljs_to_boolean(x) then\n  local _ = a\nelse\n  local _ = b\nend\n", 1, true), "expected if/else")
end)

test("else if flattens to elseif", function()
  local code = transpile_ok("if (x) { a; } else if (y) { b; }")
  assert(code:find("if _ljs_to_boolean(x) then\n  local _ = a\nelseif _ljs_to_boolean(y) then\n  local _ = b\nend\n", 1, true), "expected elseif")
end)

test("nested else-if chain from blocks", function()
  local code = transpile_ok("if (a) { 1; } else { if (b) { 2; } else { 3; } }")
  assert(
    code:find("if _ljs_to_boolean(a) then\n  local _ = 1\nelseif _ljs_to_boolean(b) then\n  local _ = 2\nelse\n  local _ = 3\nend\n", 1, true),
    "expected nested elseif"
  )
end)

test("while loop", function()
  local code = transpile_ok("while (x) { y; }")
  assert(code:find("while _ljs_to_boolean(x) do\n  local _ = y\nend\n", 1, true), "expected while x do local _ = y end")
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
  local code = transpile_ok("for (let k in {a: 1}) { k; }")
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
  assert(code:find("{a = 1}"), "expected object literal")
end)

test("for...in nested with for...of transpiles correctly", function()
  local code = transpile_ok("for (let k in obj) { for (const x of arr) { k; } }")
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
  assert(code:find("for _, x in ipairs"), "expected for _, x in ipairs")
end)

test("for...in with console.log uses _ljs_call_member", function()
  local code = transpile_ok("for (let k in obj) { console.log(k); }")
  assert(code:find("for k, _ in pairs"), "expected for k, _ in pairs")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member for console.log")
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
end)

test("full for with let init transpiles correctly", function()
  local code = transpile_ok("for (let i = 0; i < 10; i = i + 1) { console.log(i); }")
  assert(code:find("local i = 0"), "expected 'local i = 0'")
  assert(code:find("while _ljs_to_boolean%(_ljs_lt%(i, 10%)%) do"), "expected 'while _ljs_to_boolean(_ljs_lt(i, 10)) do'")
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected update 'i = _ljs_add(i, 1)'")
end)

test("for with expression init transpiles correctly", function()
  local code = transpile_ok("for (i = 0; i < 5; i = i + 1) { x; }")
  assert(code:find("i = 0"), "expected 'i = 0' (no local)")
  local ecode = emit_ok("for (i = 0; i < 5; i = i + 1) { x; }")
  assert(not ecode:find("local i ="), "no local for expression init")
  assert(code:find("while _ljs_to_boolean%(_ljs_lt%(i, 5%)%) do"), "expected 'while _ljs_to_boolean(_ljs_lt(i, 5)) do'")
end)

test("for with nil update transpiles correctly", function()
  local code = transpile_ok("for (let x = 1; x < 5; ) { x; }")
  assert(code:find("local x = 1"), "expected 'local x = 1'")
  assert(code:find("while _ljs_to_boolean%(_ljs_lt%(x, 5%)%) do"), "expected 'while _ljs_to_boolean(_ljs_lt(x, 5)) do'")
  local ecode = emit_ok("for (let x = 1; x < 5; ) { x; }")
  assert(not ecode:find("x = _ljs_add"), "no _ljs_add update in codegen")
  assert(not ecode:find("x = x %- 1"), "no decrement update in codegen")
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
  local code = emit_ok("for (; x < 10; x = x + 1) { y; }")
  assert(not code:find("local x"), "no init")
  assert(code:find("while _ljs_to_boolean%(_ljs_lt%(x, 10%)%) do"), "expected 'while _ljs_to_boolean(_ljs_lt(x, 10)) do'")
  assert(code:find("_ljs_add%(x, 1%)"), "expected update")
end)

test("nested for loops transpile with correct indentation", function()
  local code = transpile_ok("for (;;) { for (let j = 0; j < 3; j = j + 1) { x; } }")
  assert(code:find("while true do"), "outer while true")
  assert(code:find("local j = 0"), "inner init")
  assert(code:find("while _ljs_to_boolean%(_ljs_lt%(j, 3%)%) do"), "inner while")
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
  local code = emit_ok("for (let i = 0; i < 3; i = i + 1) { x; }")
  assert(not code:find(";"), "no semicolons in Lua output")
end)

test("for(;;) scoping: let init uses local", function()
  local code = transpile_ok("for (let i = 0; i < 1; i = i + 1) { x; }")
  assert(code:find("local i = 0"), "expected 'local i = 0'")
end)

test("for(;;) scoping: expression init does not use local", function()
  local code = transpile_ok("for (i = 0; i < 1; i = i + 1) { x; }")
  local ecode = emit_ok("for (i = 0; i < 1; i = i + 1) { x; }")
  assert(not ecode:find("local i ="), "no local for expression init")
  assert(code:find("i = 0"), "expected bare 'i = 0'")
end)

test("for(;;) var init transpiles same as let", function()
  local code = transpile_ok("for (var i = 0; i < 3; i = i + 1) { x; }")
  assert(code:find("local i = 0"), "var normalized to local")
  assert(code:find("while _ljs_to_boolean%(_ljs_lt%(i, 3%)%) do"), "expected while condition")
end)

-- ============================================================================
-- Expression-only bodies — bare expressions wrapped in local _ = <expr>
-- ============================================================================

test("bare number in if body is wrapped", function()
  local code = transpile_ok("if (true) { 42; }")
  assert(code:find("local _ = 42", 1, true), "expected 'local _ = 42'")
end)

test("bare number in if/else is wrapped", function()
  local code = transpile_ok("if (true) { 42; } else { 0; }")
  assert(code:find("local _ = 42", 1, true), "expected 'local _ = 42' in then")
  assert(code:find("local _ = 0", 1, true), "expected 'local _ = 0' in else")
end)

test("bare string in if body is wrapped", function()
  local code = transpile_ok('if (true) { "hello"; }')
  assert(code:find('local _ = "hello"', 1, true), 'expected local _ = "hello"')
end)

test("bare identifier in while body is wrapped", function()
  local code = transpile_ok("while (false) { x; }")
  assert(code:find("local _ = x", 1, true), "expected 'local _ = x'")
end)

test("bare member expression in if body is wrapped", function()
  local code = transpile_ok("if (true) { obj.prop; }")
  assert(code:find("local _ = _ljs_to_object(obj).prop", 1, true), "expected local _ = member")
end)

test("strict equality in body is wrapped", function()
  local code = transpile_ok("if (true) { x === 1; }")
  assert(code:find("local _ = x == 1", 1, true), "expected local _ = x == 1")
end)

test("logical NOT in body is wrapped", function()
  local code = transpile_ok("if (true) { !x; }")
  assert(code:find("local _ = not _ljs_to_boolean(x)", 1, true), "expected local _ = not ...")
end)

test("unary minus in body is wrapped", function()
  local code = transpile_ok("if (true) { -x; }")
  assert(code:find("local _ = -_ljs_to_number(x)", 1, true), "expected local _ = -...")
end)

test("call expression in body is NOT wrapped", function()
  local code = transpile_ok("if (true) { foo(); }")
  assert(not code:find("local _ ="), "call expression should not be wrapped")
end)

test("assignment expression in body is NOT wrapped", function()
  local code = transpile_ok("if (true) { x = 1; }")
  assert(not code:find("local _ ="), "assignment should not be wrapped")
end)

test("bare expr in if body produces valid Lua (integration)", function()
  local output = run_js("if (true) { 42; } else { 0; }")
  assert_eq(output, "")
end)

test("bare expr in while body produces valid Lua (integration)", function()
  local output = run_js("let x = 0; while (x < 1) { x; x = x + 1; }")
  assert_eq(output, "")
end)
