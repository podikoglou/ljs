local T = require("ljs_test")
local H = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq = T.test, T.assert_eq
local assert_parse_ok = H.assert_parse_ok

test("this as primary expression", function()
  assert_parse_ok("this;", {
    A.expr_stmt(A.this_()),
  })
end)

test("this in member expression", function()
  assert_parse_ok("this.x;", {
    A.expr_stmt(A.member(A.this_(), A.id("x"))),
  })
end)

test("this in method call", function()
  assert_parse_ok("this.method();", {
    A.expr_stmt(A.call(A.member(A.this_(), A.id("method")), {})),
  })
end)

test("this in binary expression", function()
  assert_parse_ok("this + 1;", {
    A.expr_stmt(A.bin("+", A.this_(), A.num(1))),
  })
end)

test("this in assignment", function()
  assert_parse_ok("let x = this;", { A.let("x", A.this_()) })
end)

test("typeof this", function()
  assert_parse_ok("typeof this;", {
    A.expr_stmt(A.typeof_(A.this_())),
  })
end)

test("this in return statement", function()
  assert_parse_ok("function f() { return this; }", {
    A.func("f", {}, A.block({ A.ret(A.this_()) })),
  })
end)
