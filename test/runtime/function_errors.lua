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
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

test("direct call on null throws TypeError", function()
  local ok, err = pcall(eval_js, "(null)()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

test("direct call on undefined throws TypeError", function()
  local ok, err = pcall(eval_js, "(undefined)()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

test("direct call on string throws TypeError", function()
  local ok, err = pcall(eval_js, "('hello')()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

-- ============================================================================
-- Member call errors (#213, #217)
-- ============================================================================

test("member call on null property throws TypeError", function()
  local ok, err = pcall(eval_js, "({foo: null}).foo()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

test("member call on number property throws TypeError", function()
  local ok, err = pcall(eval_js, "({foo: 42}).foo()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

test("member call on undefined property throws TypeError", function()
  local ok, err = pcall(eval_js, "({}).foo()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function"), "expected 'is not a function' in error: " .. tostring(err))
end)

-- ============================================================================
-- Constructor errors (#216)
-- ============================================================================

test("new on number throws TypeError", function()
  local ok, err = pcall(exec_js, "var x = 5; new x()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a constructor"), "expected 'is not a constructor' in error: " .. tostring(err))
end)

test("new on null throws TypeError", function()
  local ok, err = pcall(exec_js, "var x = null; new x()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a constructor"), "expected 'is not a constructor' in error: " .. tostring(err))
end)

test("new on string throws TypeError", function()
  local ok, err = pcall(exec_js, "var x = 'string'; new x()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a constructor"), "expected 'is not a constructor' in error: " .. tostring(err))
end)

-- ============================================================================
-- Explicit this binding (#217)
-- ============================================================================

test("call non-function throws TypeError", function()
  local ok, err = pcall(eval_js, "(42).constructor.call(null, 5)()")
  assert(not ok, "expected error")
  assert(tostring(err):find("is not a function") or tostring(err):find("is not a constructor"), 
    "expected error about not being function/constructor: " .. tostring(err))
end)
