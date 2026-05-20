local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

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

T.summary()
