local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_table_eq = T.test, T.assert_table_eq
local assert_parse_ok = P.assert_parse_ok

test("parse let declaration", function()
  assert_parse_ok("let x = 1;", {
    A.var_decl("let", { A.declarator(A.id("x"), A.num(1)) }),
  })
end)

test("parse const declaration", function()
  assert_parse_ok("const y = 2;", {
    A.var_decl("const", { A.declarator(A.id("y"), A.num(2)) }),
  })
end)

test("parse var declaration preserves kind", function()
  assert_parse_ok("var z = 3;", {
    A.var_decl("var", { A.declarator(A.id("z"), A.num(3)) }),
  })
end)

test("parse multiple declarators", function()
  assert_parse_ok("let a = 1, b = 2;", {
    A.var_decl("let", {
      A.declarator(A.id("a"), A.num(1)),
      A.declarator(A.id("b"), A.num(2)),
    }),
  })
end)

test("parse variable without initializer", function()
  assert_parse_ok("let x;", {
    A.var_decl("let", { A.declarator(A.id("x")) }),
  })
end)

test("parse function declaration", function()
  assert_parse_ok("function add(a, b) { return a + b; }", {
    A.func(
      "add",
      A.ids("a", "b"),
      A.block({
        A.ret(A.bin("+", A.id("a"), A.id("b"))),
      })
    ),
  })
end)

test("parse if/else", function()
  assert_parse_ok("if (x) { y; } else { z; }", {
    A.if_(A.id("x"), A.block({ A.expr_stmt(A.id("y")) }), A.block({ A.expr_stmt(A.id("z")) })),
  })
end)

test("parse while", function()
  assert_parse_ok("while (x) { y; }", {
    A.while_(A.id("x"), A.block({ A.expr_stmt(A.id("y")) })),
  })
end)

test("parse empty source produces empty Program", function()
  local ast = P.parser.parse("")
  assert_table_eq(ast, A.program({}))
end)

test("parse whitespace-only source produces empty Program", function()
  local ast = P.parser.parse("   \n  \t  \n  ")
  assert_table_eq(ast, A.program({}))
end)

test("parse var multi-declarator preserves kind", function()
  assert_parse_ok("var a, b = 2;", {
    A.var_decl("var", {
      A.declarator(A.id("a")),
      A.declarator(A.id("b"), A.num(2)),
    }),
  })
end)
