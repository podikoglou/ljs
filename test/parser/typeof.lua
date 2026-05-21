local T = require("ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test = T.test
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local assert_tok = P.assert_tok

-- TYPEOF EXPRESSION TESTS
-- ============================================================================

-- Tokenizer
test("tokenize typeof", function()
  assert_tok("typeof x", 1, "typeof", "typeof")
end)

test("tokenize typeof in expression", function()
  assert_tok("typeof obj.x;", 1, "typeof", "typeof")
  assert_tok("typeof obj.x;", 2, "Identifier", "obj")
end)

-- Basic parsing
test("parse typeof identifier", function()
  assert_parse_ok("typeof x;", {
    A.expr_stmt(A.typeof_(A.id("x"))),
  })
end)

test("parse typeof member expression dot", function()
  assert_parse_ok("typeof obj.prop;", {
    A.expr_stmt(A.typeof_(A.member(A.id("obj"), A.id("prop")))),
  })
end)

test("parse typeof member expression bracket", function()
  assert_parse_ok("typeof obj[key];", {
    A.expr_stmt(A.typeof_(A.member_c(A.id("obj"), A.id("key")))),
  })
end)

test("parse typeof computed member with expression", function()
  assert_parse_ok("typeof obj[i + 1];", {
    A.expr_stmt(A.typeof_(A.member_c(A.id("obj"), A.bin("+", A.id("i"), A.num(1))))),
  })
end)

test("parse typeof nested member a.b.c", function()
  assert_parse_ok("typeof a.b.c;", {
    A.expr_stmt(A.typeof_(A.member(A.member(A.id("a"), A.id("b")), A.id("c")))),
  })
end)

test("parse typeof call result member", function()
  assert_parse_ok("typeof getObj().prop;", {
    A.expr_stmt(A.typeof_(A.member(A.call(A.id("getObj"), {}), A.id("prop")))),
  })
end)

-- typeof with various operand types
test("parse typeof number literal", function()
  assert_parse_ok("typeof 42;", {
    A.expr_stmt(A.typeof_(A.num(42))),
  })
end)

test("parse typeof string literal", function()
  assert_parse_ok('typeof "hello";', {
    A.expr_stmt(A.typeof_(A.str("hello"))),
  })
end)

test("parse typeof boolean", function()
  assert_parse_ok("typeof true;", {
    A.expr_stmt(A.typeof_(A.bool(true))),
  })
end)

test("parse typeof null", function()
  assert_parse_ok("typeof null;", {
    A.expr_stmt(A.typeof_(A.null())),
  })
end)

test("parse typeof undefined", function()
  assert_parse_ok("typeof undefined;", {
    A.expr_stmt(A.typeof_(A.undef())),
  })
end)

test("parse typeof parenthesized expression", function()
  assert_parse_ok("typeof (x);", {
    A.expr_stmt(A.typeof_(A.id("x"))),
  })
end)

test("parse typeof array literal", function()
  assert_parse_ok("typeof [1, 2];", {
    A.expr_stmt(A.typeof_(A.arr({ A.num(1), A.num(2) }))),
  })
end)

test("parse typeof object literal", function()
  assert_parse_ok("typeof {a: 1};", {
    A.expr_stmt(A.typeof_(A.obj({ A.prop(A.id("a"), A.num(1)) }))),
  })
end)

-- typeof with other unary operators
test("parse typeof !x (typeof of unary NOT)", function()
  assert_parse_ok("typeof !x;", {
    A.expr_stmt(A.typeof_(A.una("!", A.id("x")))),
  })
end)

test("parse typeof -x (typeof of unary minus)", function()
  assert_parse_ok("typeof -x;", {
    A.expr_stmt(A.typeof_(A.una("-", A.id("x")))),
  })
end)

test("parse typeof ~x (typeof of bitwise NOT)", function()
  assert_parse_ok("typeof ~x;", {
    A.expr_stmt(A.typeof_(A.una("~", A.id("x")))),
  })
end)

test("parse !typeof x (unary NOT of typeof)", function()
  assert_parse_ok("!typeof x;", {
    A.expr_stmt(A.una("!", A.typeof_(A.id("x")))),
  })
end)

test("parse -typeof x (unary minus of typeof)", function()
  assert_parse_ok("-typeof x;", {
    A.expr_stmt(A.una("-", A.typeof_(A.id("x")))),
  })
end)

test("parse ~typeof x (bitwise NOT of typeof)", function()
  assert_parse_ok("~typeof x;", {
    A.expr_stmt(A.una("~", A.typeof_(A.id("x")))),
  })
end)

-- typeof with update expressions
test("parse typeof x++ (typeof of postfix update)", function()
  assert_parse_ok("typeof x++;", {
    A.expr_stmt(A.typeof_(A.update("++", A.id("x"), false))),
  })
end)

test("parse typeof ++x (typeof of prefix update)", function()
  assert_parse_ok("typeof ++x;", {
    A.expr_stmt(A.typeof_(A.update("++", A.id("x"), true))),
  })
end)

test("parse ++typeof x (prefix increment of typeof result)", function()
  assert_parse_ok("++typeof x;", {
    A.expr_stmt(A.update("++", A.typeof_(A.id("x")), true)),
  })
end)

-- typeof in binary expressions
test("parse typeof x + 1 (typeof in arithmetic)", function()
  assert_parse_ok("typeof x + 1;", {
    A.expr_stmt(A.bin("+", A.typeof_(A.id("x")), A.num(1))),
  })
end)

test("parse typeof x === 'number' (typeof in comparison)", function()
  assert_parse_ok("typeof x === 'number';", {
    A.expr_stmt(A.bin("===", A.typeof_(A.id("x")), A.str("number"))),
  })
end)

test("parse typeof x && typeof y (typeof in logical AND)", function()
  assert_parse_ok("typeof x && typeof y;", {
    A.expr_stmt(A.bin("&&", A.typeof_(A.id("x")), A.typeof_(A.id("y")))),
  })
end)

test("parse typeof x || typeof y (typeof in logical OR)", function()
  assert_parse_ok("typeof x || typeof y;", {
    A.expr_stmt(A.bin("||", A.typeof_(A.id("x")), A.typeof_(A.id("y")))),
  })
end)

-- typeof in ternary
test("parse typeof x ? 1 : 0 (typeof in ternary condition)", function()
  assert_parse_ok("typeof x ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.typeof_(A.id("x")), A.num(1), A.num(0))),
  })
end)

test("parse flag ? typeof x : typeof y (typeof in ternary branches)", function()
  assert_parse_ok("flag ? typeof x : typeof y;", {
    A.expr_stmt(A.ternary(A.id("flag"), A.typeof_(A.id("x")), A.typeof_(A.id("y")))),
  })
end)

-- typeof in assignment
test("parse result = typeof x (typeof as assignment RHS)", function()
  assert_parse_ok("result = typeof x;", {
    A.expr_stmt(A.bin("=", A.id("result"), A.typeof_(A.id("x")))),
  })
end)

-- typeof in variable declaration
test("parse let t = typeof obj.prop (typeof in variable init)", function()
  assert_parse_ok("let t = typeof obj.prop;", {
    A.var_decl("let", {
      A.declarator(A.id("t"), A.typeof_(A.member(A.id("obj"), A.id("prop")))),
    }),
  })
end)

-- typeof in control flow
test("parse typeof in if condition", function()
  assert_parse_ok("if (typeof x) { y; }", {
    A.if_(A.typeof_(A.id("x")), A.block({ A.expr_stmt(A.id("y")) })),
  })
end)

test("parse typeof in while condition", function()
  assert_parse_ok("while (typeof x) { y; }", {
    A.while_(A.typeof_(A.id("x")), A.block({ A.expr_stmt(A.id("y")) })),
  })
end)

test("parse typeof in for init", function()
  assert_parse_ok("for (typeof x; y; z) {}", {
    A.for_(A.expr_stmt(A.typeof_(A.id("x"))), A.id("y"), A.id("z"), A.block({})),
  })
end)

test("parse typeof in return statement", function()
  assert_parse_ok("function f() { return typeof x; }", {
    A.func("f", {}, A.block({ A.ret(A.typeof_(A.id("x"))) })),
  })
end)

-- nested typeof
test("parse typeof typeof x (double typeof)", function()
  assert_parse_ok("typeof typeof x;", {
    A.expr_stmt(A.typeof_(A.typeof_(A.id("x")))),
  })
end)

test("parse typeof typeof typeof x (triple typeof)", function()
  assert_parse_ok("typeof typeof typeof x;", {
    A.expr_stmt(A.typeof_(A.typeof_(A.typeof_(A.id("x"))))),
  })
end)

-- typeof with function expression operand
test("parse typeof function expression", function()
  assert_parse_ok("typeof function() {};", {
    A.expr_stmt(A.typeof_(A.func_expr({}, A.block({})))),
  })
end)

-- typeof with arrow function operand
test("parse typeof arrow function", function()
  assert_parse_ok("typeof x => x;", {
    A.expr_stmt(A.typeof_(A.arrow({ A.id("x") }, A.block({ A.ret(A.id("x")) })))),
  })
end)

-- typeof in array element
test("parse typeof as array element", function()
  assert_parse_ok("[typeof x];", {
    A.expr_stmt(A.arr({ A.typeof_(A.id("x")) })),
  })
end)

-- typeof in object value
test("parse typeof as object property value", function()
  assert_parse_ok("({a: typeof x});", {
    A.expr_stmt(A.obj({ A.prop(A.id("a"), A.typeof_(A.id("x"))) })),
  })
end)

-- typeof in switch case
test("parse typeof in switch case", function()
  assert_parse_ok("switch (x) { case 1: typeof y; }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), { A.expr_stmt(A.typeof_(A.id("y"))) }),
    }),
  })
end)

-- typeof with call expression operand
test("parse typeof call expression", function()
  assert_parse_ok("typeof f();", {
    A.expr_stmt(A.typeof_(A.call(A.id("f"), {}))),
  })
end)

test("parse typeof call with args", function()
  assert_parse_ok("typeof f(a, b);", {
    A.expr_stmt(A.typeof_(A.call(A.id("f"), A.ids("a", "b")))),
  })
end)

-- typeof with delete interaction
test("parse typeof delete x (typeof of delete)", function()
  assert_parse_ok("typeof delete x;", {
    A.expr_stmt(A.typeof_(A.del(A.id("x")))),
  })
end)

test("parse delete typeof x (delete of typeof)", function()
  assert_parse_ok("delete typeof x;", {
    A.expr_stmt(A.del(A.typeof_(A.id("x")))),
  })
end)

-- typeof in compound assignment RHS
test("parse typeof in compound assignment RHS", function()
  assert_parse_ok("x += typeof y;", {
    A.expr_stmt(A.bin("+=", A.id("x"), A.typeof_(A.id("y")))),
  })
end)

-- typeof in bitwise expression
test("parse typeof in bitwise expression", function()
  assert_parse_ok("typeof x & typeof y;", {
    A.expr_stmt(A.bin("&", A.typeof_(A.id("x")), A.typeof_(A.id("y")))),
  })
end)

-- typeof in comparison chain
test("parse typeof in comparison chain", function()
  assert_parse_ok("typeof x < typeof y;", {
    A.expr_stmt(A.bin("<", A.typeof_(A.id("x")), A.typeof_(A.id("y")))),
  })
end)

-- precedence: typeof binds tighter than binary ops
test("parse precedence: typeof x * y (typeof x then multiply)", function()
  assert_parse_ok("typeof x * y;", {
    A.expr_stmt(A.bin("*", A.typeof_(A.id("x")), A.id("y"))),
  })
end)

test("parse precedence: typeof x ** y (typeof x then exponentiate)", function()
  assert_parse_ok("typeof x ** y;", {
    A.expr_stmt(A.bin("**", A.typeof_(A.id("x")), A.id("y"))),
  })
end)

-- typeof inside parentheses grouping
test("parse (typeof x) + y", function()
  assert_parse_ok("(typeof x) + y;", {
    A.expr_stmt(A.bin("+", A.typeof_(A.id("x")), A.id("y"))),
  })
end)

-- typeof is a keyword not an identifier
test("typeof is a keyword not an identifier", function()
  assert_tok("typeof", 1, "typeof", "typeof")
  assert_tok("typeof", 1, "typeof")
end)

-- typeof as statement without semicolon (ASI)
test("parse typeof x without semicolon (EOF)", function()
  assert_parse_ok("typeof x", {
    A.expr_stmt(A.typeof_(A.id("x"))),
  })
end)

test("parse typeof x followed by let (ASI)", function()
  assert_parse_ok("typeof x\nlet y = 1;", {
    A.expr_stmt(A.typeof_(A.id("x"))),
    A.let("y", A.num(1)),
  })
end)

-- multiple typeof in sequence as statements
test("parse multiple typeof statements", function()
  assert_parse_ok("typeof x; typeof y; typeof z;", {
    A.expr_stmt(A.typeof_(A.id("x"))),
    A.expr_stmt(A.typeof_(A.id("y"))),
    A.expr_stmt(A.typeof_(A.id("z"))),
  })
end)

-- typeof in do-while
test("parse typeof in do-while body", function()
  assert_parse_ok("do { typeof x; } while (y);", {
    A.do_while(A.block({ A.expr_stmt(A.typeof_(A.id("x"))) }), A.id("y")),
  })
end)

-- typeof with string computed member
test("parse typeof obj['key']", function()
  assert_parse_ok("typeof obj['key'];", {
    A.expr_stmt(A.typeof_(A.member_c(A.id("obj"), A.str("key")))),
  })
end)

-- typeof with number computed member
test("parse typeof arr[0]", function()
  assert_parse_ok("typeof arr[0];", {
    A.expr_stmt(A.typeof_(A.member_c(A.id("arr"), A.num(0)))),
  })
end)

-- typeof in throw
test("parse throw typeof x", function()
  assert_parse_ok("throw typeof x;", {
    A.throw(A.typeof_(A.id("x"))),
  })
end)

-- typeof with parenthesized multi-param arrow function
test("parse typeof parenthesized arrow function", function()
  assert_parse_ok("typeof (a, b) => a;", {
    A.expr_stmt(A.typeof_(A.arrow(A.ids("a", "b"), A.block({ A.ret(A.id("a")) })))),
  })
end)

-- typeof with named function expression
test("parse typeof named function expression", function()
  assert_parse_ok("typeof function foo() {};", {
    A.expr_stmt(A.typeof_(A.func_expr("foo", {}, A.block({})))),
  })
end)

-- typeof in for-of expression left
test("parse for-of with typeof expression left (syntactically accepted)", function()
  assert_parse_ok("for (typeof x of arr) {}", {
    A.for_of(A.typeof_(A.id("x")), A.id("arr"), A.block({})),
  })
end)

-- typeof in for-in expression left
test("parse for-in with typeof expression left (syntactically accepted)", function()
  assert_parse_ok("for (typeof x in obj) {}", {
    A.for_in(A.typeof_(A.id("x")), A.id("obj"), A.block({})),
  })
end)

-- common JS pattern: typeof x !== "undefined"
test("parse typeof x !== 'undefined' (common guard pattern)", function()
  assert_parse_ok("typeof x !== 'undefined';", {
    A.expr_stmt(A.bin("!==", A.typeof_(A.id("x")), A.str("undefined"))),
  })
end)

-- typeof in if with typeof guard
test("parse if typeof guard pattern", function()
  assert_parse_ok("if (typeof x === 'number') { x; }", {
    A.if_(A.bin("===", A.typeof_(A.id("x")), A.str("number")), A.block({ A.expr_stmt(A.id("x")) })),
  })
end)

-- typeof in ternary with string comparison
test("parse typeof x === 'string' ? x : '' (common pattern)", function()
  assert_parse_ok("typeof x === 'string' ? x : '';", {
    A.expr_stmt(
      A.ternary(A.bin("===", A.typeof_(A.id("x")), A.str("string")), A.id("x"), A.str(""))
    ),
  })
end)

-- typeof with + prefix (valid but weird)
test("parse +typeof x (unary plus of typeof)", function()
  assert_parse_ok("+typeof x;", {
    A.expr_stmt(A.una("+", A.typeof_(A.id("x")))),
  })
end)

-- typeof result in postfix update
test("parse typeof x-- (typeof of postfix decrement)", function()
  assert_parse_ok("typeof x--;", {
    A.expr_stmt(A.typeof_(A.update("--", A.id("x"), false))),
  })
end)

-- typeof result in prefix decrement
test("parse --typeof x (prefix decrement of typeof)", function()
  assert_parse_ok("--typeof x;", {
    A.expr_stmt(A.update("--", A.typeof_(A.id("x")), true)),
  })
end)

-- typeof in complex expression
test("parse typeof x + typeof y === 'numbernumber'", function()
  assert_parse_ok("typeof x + typeof y === 'numbernumber';", {
    A.expr_stmt(
      A.bin("===", A.bin("+", A.typeof_(A.id("x")), A.typeof_(A.id("y"))), A.str("numbernumber"))
    ),
  })
end)

-- typeof in call arguments
test("parse typeof in call argument", function()
  assert_parse_ok("f(typeof x);", {
    A.expr_stmt(A.call(A.id("f"), { A.typeof_(A.id("x")) })),
  })
end)

-- typeof in member expression object
test("parse typeof x.length (typeof then member access)", function()
  assert_parse_ok("typeof x.length;", {
    A.expr_stmt(A.typeof_(A.member(A.id("x"), A.id("length")))),
  })
end)

-- typeof in try-catch
test("parse typeof in try-catch", function()
  assert_parse_ok("try { typeof x; } catch (e) { y; }", {
    A.try_catch(
      A.block({ A.expr_stmt(A.typeof_(A.id("x"))) }),
      A.catch(A.id("e"), A.block({ A.expr_stmt(A.id("y")) }))
    ),
  })
end)

-- typeof in switch discriminant
test("parse typeof in switch discriminant", function()
  assert_parse_ok("switch (typeof x) { case 'number': break; }", {
    A.switch(A.typeof_(A.id("x")), {
      A.case(A.str("number"), { A.break_() }),
    }),
  })
end)

-- ============================================================================
-- NEGATIVE / ERROR TESTS
-- ============================================================================

test("error: typeof with no operand", function()
  assert_parse_fail("typeof", nil)
end)

test("error: typeof at end of program", function()
  assert_parse_fail("typeof;", nil)
end)

test("error: typeof followed by semicolon", function()
  assert_parse_fail("typeof ;", nil)
end)

test("error: typeof followed by closing paren", function()
  assert_parse_fail("(typeof)", nil)
end)

test("error: typeof followed by closing bracket", function()
  assert_parse_fail("[typeof]", nil)
end)

test("error: typeof followed by operator", function()
  assert_parse_fail("typeof +;", nil)
end)

test("error: typeof followed by comma", function()
  assert_parse_fail("typeof , x;", nil)
end)

test("typeof this (this is now a valid expression)", function()
  assert_parse_ok("typeof this;", {
    A.expr_stmt(A.typeof_(A.this_())),
  })
end)

-- typeof async is still banned
test("error: typeof async x (async is banned)", function()
  assert_parse_fail("typeof async x;", nil)
end)

-- typeof await is still banned
test("error: typeof await x (await is banned)", function()
  assert_parse_fail("typeof await x;", nil)
end)

test("error: typeof instanceof x (instanceof needs left operand)", function()
  assert_parse_fail("typeof instanceof x;", nil)
end)

-- ============================================================================
-- SUMMARY
-- ============================================================================

T.summary()
