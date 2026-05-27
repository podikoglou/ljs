local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local ast = require("ljs.ast")
local test = T.test
local assert_parse_ok = P.assert_parse_ok

local function spread(arg)
  return { type = ast.TYPE_SPREAD_ELEMENT, argument = arg }
end

test("parse array with single spread element [...a]", function()
  assert_parse_ok("[...a]", {
    A.expr_stmt(A.arr({ spread(A.id("a")) })),
  })
end)

test("parse array with spread and literals [1, ...a]", function()
  assert_parse_ok("[1, ...a]", {
    A.expr_stmt(A.arr({ A.num(1), spread(A.id("a")) })),
  })
end)

test("parse array with spread in middle [1, ...a, 3]", function()
  assert_parse_ok("[1, ...a, 3]", {
    A.expr_stmt(A.arr({ A.num(1), spread(A.id("a")), A.num(3) })),
  })
end)

test("parse function call with spread fn(...a)", function()
  assert_parse_ok("fn(...a)", {
    A.expr_stmt(A.call(A.id("fn"), { spread(A.id("a")) })),
  })
end)

test("parse function call with mixed args fn(1, ...a, 2)", function()
  assert_parse_ok("fn(1, ...a, 2)", {
    A.expr_stmt(A.call(A.id("fn"), { A.num(1), spread(A.id("a")), A.num(2) })),
  })
end)

test("parse new expression with spread new Fn(...a)", function()
  assert_parse_ok("new Fn(...a)", {
    A.expr_stmt(A.new_expr(A.id("Fn"), { spread(A.id("a")) })),
  })
end)

test("parse method call with spread obj.fn(...a)", function()
  assert_parse_ok("obj.fn(...a)", {
    A.expr_stmt(A.call(A.member(A.id("obj"), A.id("fn")), { spread(A.id("a")) })),
  })
end)

test("parse chained call with spread fn(...a)(...b)", function()
  assert_parse_ok("fn(...a)(...b)", {
    A.expr_stmt(A.call(
      A.call(A.id("fn"), { spread(A.id("a")) }),
      { spread(A.id("b")) }
    )),
  })
end)
