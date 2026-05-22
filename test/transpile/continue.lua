local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

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
