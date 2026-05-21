local T = require("ljs_test")
local H = require("test.helpers.transpile")
local test, assert_eq = T.test, T.assert_eq
local transpile_ok, run_js = H.transpile_ok, H.run_js

-- ============================================================================
-- Unit tests — exception handling
-- ============================================================================

test("throw", function()
  local code = transpile_ok('throw "error";')
  assert(code:find('error("error", 0)', 1, true), "expected error call")
end)

test("try/catch", function()
  local code = transpile_ok("try { x; } catch (e) { y; }")
  assert(code:find("pcall"), "expected pcall in output")
  assert(code:find("local ok, e"), "expected local ok, e")
  assert(code:find("if not ok then"), "expected if not ok then")
end)

test("try/catch/finally", function()
  local code = transpile_ok("try { x; } catch (e) { y; } finally { z; }")
  assert(code:find("pcall"), "expected pcall in output")
  assert(code:find("local ok, e"), "expected local ok, e")
  assert(code:find("if not ok then"), "expected if not ok then")
  assert(code:find("z"), "expected finally body in output")
end)

test("try/finally (no catch)", function()
  local code = transpile_ok("try { x; } finally { cleanup; }")
  assert(code:find("pcall"), "expected pcall in output")
  assert(code:find("local _ljs_ok, _ljs_err"), "expected local _ljs_ok, _ljs_err")
  assert(code:find("cleanup"), "expected finally body in output")
  assert(code:find("error%(_ljs_err%)"), "expected error re-throw")
end)

test("try/catch/finally integration: no error", function()
  local output = run_js([[
    let result = 0;
    try { result = 1; } catch (e) { result = 2; } finally { result = result + 10; }
    console.log(result);
  ]])
  assert(output:find("11"), "expected 11 (try + finally)")
end)

test("try/catch/finally integration: error caught", function()
  local output = run_js([[
    let result = 0;
    try { throw 1; } catch (e) { result = e; } finally { result = result + 10; }
    console.log(result);
  ]])
  assert(output:find("11"), "expected 11 (catch + finally)")
end)

test("try/finally integration: no error", function()
  local output = run_js([[
    let result = 0;
    try { result = 5; } finally { result = result * 2; }
    console.log(result);
  ]])
  assert(output:find("10"), "expected 10 (try body + finally)")
end)

test("try/finally integration: error re-thrown after finally", function()
  local output = run_js([[
    let cleaned = 0;
    try {
      try { throw 42; } finally { cleaned = 1; }
    } catch (e) {
      console.log(cleaned, e);
    }
  ]])
  assert(output:find("1"), "expected finally ran (cleaned=1)")
  assert(output:find("42"), "expected error re-thrown")
end)

test("try/catch/finally integration: catch uses error variable", function()
  local output = run_js([[
    let result = "";
    try { throw "oops"; } catch (e) { result = e; } finally { result = result + "!"; }
    console.log(result);
  ]])
  assert(output:find("oops!"), "expected oops!")
end)

test("try/catch/finally integration: nested", function()
  local output = run_js([[
    let log = "";
    try {
      try { throw "X"; } catch (a) { log = log + a; } finally { log = log + "A"; }
    } catch (b) {
      log = log + b;
    } finally {
      log = log + "B";
    }
    console.log(log);
  ]])
  assert(output:find("XAB"), "expected XAB")
end)

test("try/catch/finally integration: empty finally block", function()
  local output = run_js([[
    let result = 0;
    try { result = 1; } catch (e) { result = 2; } finally { }
    console.log(result);
  ]])
  assert(output:find("1"), "expected 1")
end)

T.summary()
