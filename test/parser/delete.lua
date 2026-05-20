local T = require("ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local ljs = P.ljs

-- DELETE EXPRESSION TESTS
-- ============================================================================

-- Tokenizer
test("tokenize delete", function()
  assert_tok("delete x", 1, "delete", "delete")
end)

test("tokenize delete in expression", function()
  assert_tok("delete obj.x;", 1, "delete", "delete")
  assert_tok("delete obj.x;", 2, "Identifier", "obj")
end)

-- Basic parsing
test("parse delete identifier", function()
  assert_parse_ok("delete x;", {
    A.expr_stmt(A.del(A.id("x"))),
  })
end)

test("parse delete member expression dot", function()
  assert_parse_ok("delete obj.prop;", {
    A.expr_stmt(A.del(A.member(A.id("obj"), A.id("prop")))),
  })
end)

test("parse delete member expression bracket", function()
  assert_parse_ok("delete obj[key];", {
    A.expr_stmt(A.del(A.member_c(A.id("obj"), A.id("key")))),
  })
end)

test("parse delete computed member with expression", function()
  assert_parse_ok("delete obj[i + 1];", {
    A.expr_stmt(A.del(A.member_c(A.id("obj"), A.bin("+", A.id("i"), A.num(1))))),
  })
end)

test("parse delete nested member a.b.c", function()
  assert_parse_ok("delete a.b.c;", {
    A.expr_stmt(A.del(A.member(A.member(A.id("a"), A.id("b")), A.id("c")))),
  })
end)

test("parse delete call result member", function()
  assert_parse_ok("delete getObj().prop;", {
    A.expr_stmt(A.del(A.member(A.call(A.id("getObj"), {}), A.id("prop")))),
  })
end)

-- delete with various operand types (parser doesn't enforce JS semantic rules)
test("parse delete number literal", function()
  assert_parse_ok("delete 42;", {
    A.expr_stmt(A.del(A.num(42))),
  })
end)

test("parse delete string literal", function()
  assert_parse_ok('delete "hello";', {
    A.expr_stmt(A.del(A.str("hello"))),
  })
end)

test("parse delete boolean", function()
  assert_parse_ok("delete true;", {
    A.expr_stmt(A.del(A.bool(true))),
  })
end)

test("parse delete null", function()
  assert_parse_ok("delete null;", {
    A.expr_stmt(A.del(A.null())),
  })
end)

test("parse delete undefined", function()
  assert_parse_ok("delete undefined;", {
    A.expr_stmt(A.del(A.undef())),
  })
end)

test("parse delete parenthesized expression", function()
  assert_parse_ok("delete (x);", {
    A.expr_stmt(A.del(A.id("x"))),
  })
end)

test("parse delete array literal", function()
  assert_parse_ok("delete [1, 2];", {
    A.expr_stmt(A.del(A.arr({ A.num(1), A.num(2) }))),
  })
end)

test("parse delete object literal", function()
  assert_parse_ok("delete {a: 1};", {
    A.expr_stmt(A.del(A.obj({ A.prop(A.id("a"), A.num(1)) }))),
  })
end)

-- delete with other unary operators
test("parse delete !x (delete of unary NOT)", function()
  assert_parse_ok("delete !x;", {
    A.expr_stmt(A.del(A.una("!", A.id("x")))),
  })
end)

test("parse delete -x (delete of unary minus)", function()
  assert_parse_ok("delete -x;", {
    A.expr_stmt(A.del(A.una("-", A.id("x")))),
  })
end)

test("parse delete ~x (delete of bitwise NOT)", function()
  assert_parse_ok("delete ~x;", {
    A.expr_stmt(A.del(A.una("~", A.id("x")))),
  })
end)

test("parse !delete x (unary NOT of delete)", function()
  assert_parse_ok("!delete x;", {
    A.expr_stmt(A.una("!", A.del(A.id("x")))),
  })
end)

test("parse -delete x (unary minus of delete)", function()
  assert_parse_ok("-delete x;", {
    A.expr_stmt(A.una("-", A.del(A.id("x")))),
  })
end)

test("parse ~delete x (bitwise NOT of delete)", function()
  assert_parse_ok("~delete x;", {
    A.expr_stmt(A.una("~", A.del(A.id("x")))),
  })
end)

-- delete with update expressions
test("parse delete x++ (delete of postfix update)", function()
  assert_parse_ok("delete x++;", {
    A.expr_stmt(A.del(A.update("++", A.id("x"), false))),
  })
end)

test("parse delete ++x (delete of prefix update)", function()
  assert_parse_ok("delete ++x;", {
    A.expr_stmt(A.del(A.update("++", A.id("x"), true))),
  })
end)

test("parse ++delete x (prefix increment of delete result)", function()
  assert_parse_ok("++delete x;", {
    A.expr_stmt(A.update("++", A.del(A.id("x")), true)),
  })
end)

-- delete in binary expressions
test("parse delete x + 1 (delete in arithmetic)", function()
  assert_parse_ok("delete x + 1;", {
    A.expr_stmt(A.bin("+", A.del(A.id("x")), A.num(1))),
  })
end)

test("parse delete x === true (delete in comparison)", function()
  assert_parse_ok("delete x === true;", {
    A.expr_stmt(A.bin("===", A.del(A.id("x")), A.bool(true))),
  })
end)

test("parse delete x && delete y (delete in logical AND)", function()
  assert_parse_ok("delete x && delete y;", {
    A.expr_stmt(A.bin("&&", A.del(A.id("x")), A.del(A.id("y")))),
  })
end)

test("parse delete x || delete y (delete in logical OR)", function()
  assert_parse_ok("delete x || delete y;", {
    A.expr_stmt(A.bin("||", A.del(A.id("x")), A.del(A.id("y")))),
  })
end)

-- delete in ternary
test("parse delete x ? 1 : 0 (delete in ternary condition)", function()
  assert_parse_ok("delete x ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.del(A.id("x")), A.num(1), A.num(0))),
  })
end)

test("parse flag ? delete x : delete y (delete in ternary branches)", function()
  assert_parse_ok("flag ? delete x : delete y;", {
    A.expr_stmt(A.ternary(A.id("flag"), A.del(A.id("x")), A.del(A.id("y")))),
  })
end)

-- delete in assignment
test("parse result = delete x (delete as assignment RHS)", function()
  assert_parse_ok("result = delete x;", {
    A.expr_stmt(A.bin("=", A.id("result"), A.del(A.id("x")))),
  })
end)

-- delete in variable declaration
test("parse let r = delete obj.prop (delete in variable init)", function()
  assert_parse_ok("let r = delete obj.prop;", {
    A.var_decl("let", { A.declarator(A.id("r"), A.del(A.member(A.id("obj"), A.id("prop")))) }),
  })
end)

-- delete in control flow
test("parse delete in if condition", function()
  assert_parse_ok("if (delete x) { y; }", {
    A.if_(A.del(A.id("x")), A.block({ A.expr_stmt(A.id("y")) })),
  })
end)

test("parse delete in while condition", function()
  assert_parse_ok("while (delete x) { y; }", {
    A.while_(A.del(A.id("x")), A.block({ A.expr_stmt(A.id("y")) })),
  })
end)

test("parse delete in for init", function()
  assert_parse_ok("for (delete x; y; z) {}", {
    A.for_(A.expr_stmt(A.del(A.id("x"))), A.id("y"), A.id("z"), A.block({})),
  })
end)

test("parse delete in return statement", function()
  assert_parse_ok("function f() { return delete x; }", {
    A.func("f", {}, A.block({ A.ret(A.del(A.id("x"))) })),
  })
end)

-- nested delete
test("parse delete delete x (double delete)", function()
  assert_parse_ok("delete delete x;", {
    A.expr_stmt(A.del(A.del(A.id("x")))),
  })
end)

test("parse delete delete delete x (triple delete)", function()
  assert_parse_ok("delete delete delete x;", {
    A.expr_stmt(A.del(A.del(A.del(A.id("x"))))),
  })
end)

-- delete with function expression operand
test("parse delete function expression", function()
  assert_parse_ok("delete function() {};", {
    A.expr_stmt(A.del(A.func_expr({}, A.block({})))),
  })
end)

-- delete with arrow function operand (single-param arrow is parsed by parse_identifier_or_call)
test("parse delete arrow function", function()
  assert_parse_ok("delete x => x;", {
    A.expr_stmt(A.del(A.arrow({ A.id("x") }, A.block({ A.ret(A.id("x")) })))),
  })
end)

-- delete in array element
test("parse delete as array element", function()
  assert_parse_ok("[delete x];", {
    A.expr_stmt(A.arr({ A.del(A.id("x")) })),
  })
end)

-- delete in object value
test("parse delete as object property value", function()
  assert_parse_ok("({a: delete x});", {
    A.expr_stmt(A.obj({ A.prop(A.id("a"), A.del(A.id("x"))) })),
  })
end)

-- delete in switch case
test("parse delete in switch case", function()
  assert_parse_ok("switch (x) { case 1: delete y; }", {
    A.switch(A.id("x"), { A.case(A.num(1), { A.expr_stmt(A.del(A.id("y"))) }) }),
  })
end)

-- delete with call expression operand
test("parse delete call expression", function()
  assert_parse_ok("delete f();", {
    A.expr_stmt(A.del(A.call(A.id("f"), {}))),
  })
end)

test("parse delete call with args", function()
  assert_parse_ok("delete f(a, b);", {
    A.expr_stmt(A.del(A.call(A.id("f"), { A.id("a"), A.id("b") }))),
  })
end)

-- negative / error cases
test("error: delete with no operand", function()
  assert_parse_fail("delete", nil)
end)

test("error: delete at end of program", function()
  assert_parse_fail("delete;", nil)
end)

test("error: delete followed by semicolon", function()
  assert_parse_fail("delete ;", nil)
end)

test("error: delete followed by closing paren", function()
  assert_parse_fail("(delete)", nil)
end)

test("error: delete followed by closing bracket", function()
  assert_parse_fail("[delete]", nil)
end)

test("error: delete followed by operator", function()
  assert_parse_fail("delete +;", nil)
end)

test("error: delete followed by comma", function()
  assert_parse_fail("delete , x;", nil)
end)

-- for-in with delete expression left is syntactically valid in this parser
test("parse for-in with delete expression left (syntactically accepted)", function()
  assert_parse_ok("for (delete x in obj) {}", {
    A.for_in(A.del(A.id("x")), A.id("obj"), A.block({})),
  })
end)

-- delete is not a valid identifier
test("delete is a keyword not an identifier", function()
  assert_tok("delete", 1, "delete", "delete")
  assert_tok("delete", 1, "delete") -- not "Identifier"
end)

test("delete is not banned (unlike typeof/this)", function()
  local ast, err = ljs.parse("delete x;")
  assert(ast ~= nil, "delete should parse successfully, got error: " .. tostring(err))
end)

-- delete in compound expression contexts
test("parse delete in compound assignment RHS", function()
  assert_parse_ok("x += delete y;", {
    A.expr_stmt(A.bin("+=", A.id("x"), A.del(A.id("y")))),
  })
end)

test("parse delete in bitwise expression", function()
  assert_parse_ok("delete x & delete y;", {
    A.expr_stmt(A.bin("&", A.del(A.id("x")), A.del(A.id("y")))),
  })
end)

test("parse delete in comparison chain", function()
  assert_parse_ok("delete x < delete y;", {
    A.expr_stmt(A.bin("<", A.del(A.id("x")), A.del(A.id("y")))),
  })
end)

-- precedence: delete binds tighter than binary ops but same as unary
test("parse precedence: delete x * y (delete x then multiply)", function()
  assert_parse_ok("delete x * y;", {
    A.expr_stmt(A.bin("*", A.del(A.id("x")), A.id("y"))),
  })
end)

test("parse precedence: delete x ** y (delete x then exponentiate)", function()
  assert_parse_ok("delete x ** y;", {
    A.expr_stmt(A.bin("**", A.del(A.id("x")), A.id("y"))),
  })
end)

-- delete inside parentheses grouping
test("parse (delete x) + y", function()
  assert_parse_ok("(delete x) + y;", {
    A.expr_stmt(A.bin("+", A.del(A.id("x")), A.id("y"))),
  })
end)

-- delete with this/typeof/async/await (banned keywords after delete)
-- Note: error messages from check_banned are swallowed by parse_unary_expression,
-- same as for all unary operators (e.g. !this also gives "parse error: nil")
test("error: delete this (this is banned)", function()
  assert_parse_fail("delete this;", nil)
end)

test("parse delete typeof x (typeof is now a valid unary operator)", function()
  assert_parse_ok("delete typeof x;", {
    A.expr_stmt(A.del(A.typeof_(A.id("x")))),
  })
end)

-- delete as statement without semicolon (ASI)
test("parse delete x without semicolon (EOF)", function()
  assert_parse_ok("delete x", {
    A.expr_stmt(A.del(A.id("x"))),
  })
end)

test("parse delete x followed by let (ASI)", function()
  assert_parse_ok("delete x\nlet y = 1;", {
    A.expr_stmt(A.del(A.id("x"))),
    A.let("y", A.num(1)),
  })
end)

-- multiple deletes in sequence as statements
test("parse multiple delete statements", function()
  assert_parse_ok("delete x; delete y; delete z;", {
    A.expr_stmt(A.del(A.id("x"))),
    A.expr_stmt(A.del(A.id("y"))),
    A.expr_stmt(A.del(A.id("z"))),
  })
end)

-- delete in do-while
test("parse delete in do-while body", function()
  assert_parse_ok("do { delete x; } while (y);", {
    A.do_while(A.block({ A.expr_stmt(A.del(A.id("x"))) }), A.id("y")),
  })
end)

-- delete with string computed member
test("parse delete obj['key']", function()
  assert_parse_ok("delete obj['key'];", {
    A.expr_stmt(A.del(A.member_c(A.id("obj"), A.str("key")))),
  })
end)

-- delete with number computed member
test("parse delete arr[0]", function()
  assert_parse_ok("delete arr[0];", {
    A.expr_stmt(A.del(A.member_c(A.id("arr"), A.num(0)))),
  })
end)

-- delete in throw
test("parse throw delete x is not valid (throw expects expression, delete is expr)", function()
  assert_parse_ok("throw delete x;", {
    A.throw(A.del(A.id("x"))),
  })
end)

-- for-of with delete expression left is syntactically valid in this parser
test("parse for-of with delete expression left (syntactically accepted)", function()
  assert_parse_ok("for (delete x of arr) {}", {
    A.for_of(A.del(A.id("x")), A.id("arr"), A.block({})),
  })
end)

-- ============================================================================
-- SUMMARY
-- ============================================================================

T.summary()
