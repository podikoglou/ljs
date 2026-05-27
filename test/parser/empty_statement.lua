local T = require("test.ljs_test")
local parser = require("ljs.parser")
local test, assert_eq = T.test, T.assert_eq

test("semicolon parses as empty statement", function()
  local ast, err = parser.parse(";")
  assert(ast ~= nil, "expected ast")
  assert_eq(ast.type, "Program", "expected Program")
  assert_eq(#ast.body, 1, "expected 1 statement")
  assert_eq(ast.body[1].type, "EmptyStatement", "expected EmptyStatement")
end)
