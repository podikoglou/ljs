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
  assert(
    code:find("if _ljs_to_boolean(x) then\n  local _ = y\nend\n", 1, true),
    "expected if x then local _ = y end"
  )
end)

test("if/else", function()
  local code = transpile_ok("if (x) { a; } else { b; }")
  assert(
    code:find("if _ljs_to_boolean(x) then\n  local _ = a\nelse\n  local _ = b\nend\n", 1, true),
    "expected if/else"
  )
end)

test("else if flattens to elseif", function()
  local code = transpile_ok("if (x) { a; } else if (y) { b; }")
  assert(
    code:find(
      "if _ljs_to_boolean(x) then\n  local _ = a\nelseif _ljs_to_boolean(y) then\n  local _ = b\nend\n",
      1,
      true
    ),
    "expected elseif"
  )
end)

test("nested else-if chain from blocks", function()
  local code = transpile_ok("if (a) { 1; } else { if (b) { 2; } else { 3; } }")
  assert(
    code:find(
      "if _ljs_to_boolean(a) then\n  local _ = 1\nelseif _ljs_to_boolean(b) then\n  local _ = 2\nelse\n  local _ = 3\nend\n",
      1,
      true
    ),
    "expected nested elseif"
  )
end)

test("while loop", function()
  local code = transpile_ok("while (x) { y; }")
  assert(
    code:find("while _ljs_to_boolean(x) do\n  local _ = y\nend\n", 1, true),
    "expected while x do local _ = y end"
  )
end)

test("for...of", function()
  local code = transpile_ok("for (const x of arr) { console.log(x); }")
  assert(code:find("for _ljs_d"), "expected numeric for loop")
  assert(code:find("%.length"), "expected .length bound")
end)

test("for...of wraps iterable with _ljs_to_object", function()
  local code = emit_ok("for (const x of arr) { x; }")
  assert(code:find("_ljs_to_object"), "expected _ljs_to_object wrapping of iterable")
end)

test("for...of on string iterates characters", function()
  local out = run_js([[
    let r = "";
    for (let c of "abc") { r += c; }
    console.log(r);
  ]])
  assert_eq(out, "abc\n")
end)

-- ============================================================================
-- for...in transpile tests
-- ============================================================================

test("for...in with let transpiles to _ljs_for_in_keys", function()
  local code = transpile_ok("for (let key in obj) { console.log(key); }")
  assert(code:find("_ljs_for_in_keys"), "expected _ljs_for_in_keys")
end)

test("for...in with const transpiles to _ljs_for_in_keys", function()
  local code = transpile_ok("for (const k in obj) { k; }")
  assert(code:find("_ljs_for_in_keys"), "expected _ljs_for_in_keys")
end)

test("for...in with expression left transpiles to _ljs_for_in_keys (no local)", function()
  local code = transpile_ok("for (key in obj) { key; }")
  assert(code:find("_ljs_for_in_keys"), "expected _ljs_for_in_keys")
end)

test("for...in with object literal right transpiles correctly", function()
  local code = transpile_ok("for (let k in {a: 1}) { k; }")
  assert(code:find("_ljs_for_in_keys"), "expected _ljs_for_in_keys")
  assert(code:find("{a = 1}"), "expected object literal")
end)

test("for...in nested with for...of transpiles correctly", function()
  local code = transpile_ok("for (let k in obj) { for (const x of arr) { k; } }")
  assert(code:find("_ljs_for_in_keys"), "expected _ljs_for_in_keys")
  assert(code:find("%.length"), "expected numeric for loop for for..of")
end)

test("for...in with console.log uses _ljs_call_member", function()
  local code = transpile_ok("for (let k in obj) { console.log(k); }")
  assert(code:find("_ljs_for_in_keys"), "expected _ljs_for_in_keys")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member for console.log")
end)

test("for-of still transpiles correctly after for-in (regression)", function()
  local code = transpile_ok("for (const x of arr) { console.log(x); }")
  assert(code:find("%.length"), "expected numeric for loop for for..of")
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
  assert(
    code:find("while _ljs_to_boolean%(_ljs_lt%(i, 10%)%) do"),
    "expected 'while _ljs_to_boolean(_ljs_lt(i, 10)) do'"
  )
  assert(code:find("i = _ljs_add%(i, 1%)"), "expected update 'i = _ljs_add(i, 1)'")
end)

test("for with expression init transpiles correctly", function()
  local code = transpile_ok("for (i = 0; i < 5; i = i + 1) { x; }")
  assert(code:find("i = 0"), "expected 'i = 0' (no local)")
  local ecode = emit_ok("for (i = 0; i < 5; i = i + 1) { x; }")
  assert(not ecode:find("local i ="), "no local for expression init")
  assert(
    code:find("while _ljs_to_boolean%(_ljs_lt%(i, 5%)%) do"),
    "expected 'while _ljs_to_boolean(_ljs_lt(i, 5)) do'"
  )
end)

test("for with nil update transpiles correctly", function()
  local code = transpile_ok("for (let x = 1; x < 5; ) { x; }")
  assert(code:find("local x = 1"), "expected 'local x = 1'")
  assert(
    code:find("while _ljs_to_boolean%(_ljs_lt%(x, 5%)%) do"),
    "expected 'while _ljs_to_boolean(_ljs_lt(x, 5)) do'"
  )
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
  assert(
    code:find("while _ljs_to_boolean%(_ljs_lt%(x, 10%)%) do"),
    "expected 'while _ljs_to_boolean(_ljs_lt(x, 10)) do'"
  )
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
  assert(code:find("%.length"), "expected numeric for loop for for..of")
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
  assert(
    code:find("local _ = _ljs_strict_eq(x, 1)", 1, true),
    "expected local _ = _ljs_strict_eq(x, 1)"
  )
end)

test("logical NOT in body is wrapped", function()
  local code = transpile_ok("if (true) { !x; }")
  assert(code:find("local _ = not _ljs_to_boolean(x)", 1, true), "expected local _ = not ...")
end)

test("unary minus in body is wrapped", function()
  local code = transpile_ok("if (true) { -x; }")
  assert(code:find("local _ = _ljs_neg(x)", 1, true), "expected local _ = _ljs_neg...")
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

-- ============================================================================
-- for...of on arguments (#293)
-- ============================================================================

test("for...of on arguments iterates values", function()
  local out = run_js([[
    function f() {
      let r = "";
      for (let x of arguments) { r += x; }
      return r;
    }
    console.log(f(1, 2, 3));
  ]])
  assert_eq(out, "123\n")
end)

test("arguments has length and indexed access", function()
  local out = run_js([[
    function f() {
      console.log(arguments.length);
      console.log(arguments[0]);
    }
    f("a", "b");
  ]])
  assert_eq(out, "2\na\n")
end)

-- ============================================================================
-- arguments bugs: arrow inheritance, property false positives, param shadowing
-- ============================================================================

test("arrow function inherits arguments from enclosing function (#356)", function()
  local out = run_js([[
    function f() {
      const g = () => { return arguments[0]; };
      return g();
    }
    console.log(f(42));
  ]])
  assert_eq(out, "42\n")
end)

test("arrow function body does not emit local arguments preamble (#356)", function()
  local code = transpile_ok("const f = () => { return arguments[0]; };")
  assert(not code:find("local arguments"), "arrow should not emit 'local arguments' preamble")
end)

test("obj.arguments does not trigger arguments binding (#357)", function()
  local code = transpile_ok([[
    function f() {
      return obj.arguments;
    }
  ]])
  assert(
    not code:find("local arguments = _ljs_arguments"),
    "obj.arguments should not trigger arguments binding"
  )
end)

test("{arguments: x} property key does not trigger arguments binding (#357)", function()
  local code = transpile_ok([[
    function f() {
      const {arguments: a} = obj;
      return a;
    }
  ]])
  assert(
    not code:find("local arguments = _ljs_arguments"),
    "{arguments: x} should not trigger arguments binding"
  )
end)

test("obj[arguments] computed does trigger arguments binding (#357)", function()
  local code = transpile_ok([[
    function f() {
      return obj[arguments];
    }
  ]])
  assert(
    code:find("local arguments = _ljs_arguments"),
    "obj[arguments] should trigger arguments binding"
  )
end)

test("parameter named arguments shadows arguments object (#358)", function()
  local out = run_js([[
    function f(arguments) {
      return arguments;
    }
    console.log(f(99));
  ]])
  assert_eq(out, "99\n")
end)

test("parameter named arguments does not emit arguments binding (#358)", function()
  local code = transpile_ok("function f(arguments) { return arguments; }")
  assert(
    not code:find("local arguments = _ljs_arguments"),
    "param 'arguments' should not emit _ljs_arguments binding"
  )
end)
