local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_js = R.test, R.assert_eq, R.assert_js
local eval_js, exec_js = R.eval_js, R.exec_js

test("string .length returns correct length", function()
  assert_js('"hello".length', 5)
end)
