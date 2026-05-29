local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq = T.test, T.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

-- ============================================================================
-- Direct call errors (#215)
-- ============================================================================

test("direct call on number throws TypeError", function()
  local ok, err = pcall(eval_js, "(5)()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

test("direct call on null throws TypeError", function()
  local ok, err = pcall(eval_js, "(null)()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

test("direct call on undefined throws TypeError", function()
  local ok, err = pcall(eval_js, "(undefined)()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

test("direct call on string throws TypeError", function()
  local ok, err = pcall(eval_js, "('hello')()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

-- ============================================================================
-- Member call errors (#213, #217)
-- ============================================================================

test("member call on null property throws TypeError", function()
  local ok, err = pcall(eval_js, "({foo: null}).foo()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

test("member call on number property throws TypeError", function()
  local ok, err = pcall(eval_js, "({foo: 42}).foo()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

test("member call on undefined property throws TypeError", function()
  local ok, err = pcall(eval_js, "({}).foo()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function"), "expected 'is not a function' in error: " .. tostring(err.message))
end)

-- ============================================================================
-- Constructor errors (#216)
-- ============================================================================

test("new on number throws TypeError", function()
  local ok, err = pcall(exec_js, "var x = 5; new x()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a constructor"), "expected 'is not a constructor' in error: " .. tostring(err.message))
end)

test("new on null throws TypeError", function()
  local ok, err = pcall(exec_js, "var x = null; new x()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a constructor"), "expected 'is not a constructor' in error: " .. tostring(err.message))
end)

test("new on string throws TypeError", function()
  local ok, err = pcall(exec_js, "var x = 'string'; new x()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a constructor"), "expected 'is not a constructor' in error: " .. tostring(err.message))
end)

-- ============================================================================
-- Explicit this binding (#217)
-- ============================================================================

test("call non-function throws TypeError", function()
  local ok, err = pcall(eval_js, "(42).constructor.call(null, 5)()")
  assert(not ok, "expected error")
  assert(err.name == "TypeError", "expected TypeError, got: " .. tostring(err.name))
  assert(err.message:find("is not a function") or err.message:find("is not a constructor"), 
    "expected error about not being function/constructor: " .. tostring(err.message))
end)

-- ============================================================================
-- instanceof checks on caught errors (#302)
-- ============================================================================

test("caught non-callable error is instanceof TypeError", function()
  assert_eq(exec_js([[try { (5)() } catch(e) { return e instanceof TypeError; }]]), true)
end)

test("caught member-call-on-null error is instanceof TypeError", function()
  assert_eq(exec_js([[try { null.foo() } catch(e) { return e instanceof TypeError; }]]), true)
end)

test("caught not-a-constructor error is instanceof TypeError", function()
  assert_eq(exec_js([[try { var x = 5; new x(); } catch(e) { return e instanceof TypeError; }]]), true)
end)

test("caught error is instanceof Error", function()
  assert_eq(exec_js([[try { (5)() } catch(e) { return e instanceof Error; }]]), true)
end)

test("caught error is not instanceof RangeError", function()
  assert_eq(exec_js([[try { (5)() } catch(e) { return e instanceof RangeError; }]]), false)
end)

test("caught error has message property", function()
  assert_eq(exec_js([[try { (5)() } catch(e) { return e.message; }]]):find("is not a function") ~= nil, true)
end)

test("caught error has name property", function()
  assert_eq(exec_js([[try { (5)() } catch(e) { return e.name; }]]), "TypeError")
end)
