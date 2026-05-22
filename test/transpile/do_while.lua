local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

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
  assert(
    code:find("until not %(_ljs_call%(shouldContinue%)%)"),
    "expected until not (_ljs_call(shouldContinue))"
  )
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
  assert(code:find("local f\nf = _ljs_ctor"), "expected two-step _ljs_ctor")
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
