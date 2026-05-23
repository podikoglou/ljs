local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq = T.test, T.assert_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local parser = P.parser

test("tokenize & (bitwise AND)", function()
  assert_tok("a & b", 2, "&")
end)

test("tokenize | (bitwise OR)", function()
  assert_tok("a | b", 2, "|")
end)

test("tokenize ^ (bitwise XOR)", function()
  assert_tok("a ^ b", 2, "^")
end)

test("tokenize << (left shift)", function()
  assert_tok("a << b", 2, "<<")
end)

test("tokenize >> (right shift)", function()
  assert_tok("a >> b", 2, ">>")
end)

test("tokenize >>> (unsigned right shift)", function()
  assert_tok("a >>> b", 2, ">>>")
end)

test("tokenize &= (bitwise AND assign)", function()
  assert_tok("a &= b", 2, "&=")
end)

test("tokenize |= (bitwise OR assign)", function()
  assert_tok("a |= b", 2, "|=")
end)

test("tokenize ^= (bitwise XOR assign)", function()
  assert_tok("a ^= b", 2, "^=")
end)

test("tokenize <<= (left shift assign)", function()
  assert_tok("a <<= b", 2, "<<=")
end)

test("tokenize >>= (right shift assign)", function()
  assert_tok("a >>= b", 2, ">>=")
end)

test("tokenize >>>= (unsigned right shift assign)", function()
  assert_tok("a >>>= b", 2, ">>>=")
end)

test("tokenize &&& maximal munch: && &", function()
  local tokens = parser.tokenize("&&&")
  assert(tokens)
  assert_eq(tokens[1].type, "&&")
  assert_eq(tokens[2].type, "&")
end)

test("tokenize ||| maximal munch: || |", function()
  local tokens = parser.tokenize("|||")
  assert(tokens)
  assert_eq(tokens[1].type, "||")
  assert_eq(tokens[2].type, "|")
end)

test("tokenize <<< maximal munch: << <", function()
  local tokens = parser.tokenize("<<<")
  assert(tokens)
  assert_eq(tokens[1].type, "<<")
  assert_eq(tokens[2].type, "<")
end)

test("tokenize >>>> maximal munch: >>> >", function()
  local tokens = parser.tokenize(">>>>")
  assert(tokens)
  assert_eq(tokens[1].type, ">>>")
  assert_eq(tokens[2].type, ">")
end)

test("tokenize <<<= maximal munch: << <=", function()
  local tokens = parser.tokenize("<<<=")
  assert(tokens)
  assert_eq(tokens[1].type, "<<")
  assert_eq(tokens[2].type, "<=")
end)

test("tokenize >>=> maximal munch: >>= >", function()
  local tokens = parser.tokenize(">>=>")
  assert(tokens)
  assert_eq(tokens[1].type, ">>=")
  assert_eq(tokens[2].type, ">")
end)

test("tokenize & & with space is two tokens", function()
  local tokens = parser.tokenize("& &")
  assert(tokens)
  assert_eq(tokens[1].type, "&")
  assert_eq(tokens[2].type, "&")
end)

test("tokenize | | with space is two tokens", function()
  local tokens = parser.tokenize("| |")
  assert(tokens)
  assert_eq(tokens[1].type, "|")
  assert_eq(tokens[2].type, "|")
end)

test("tokenize ^ ^ with space is two tokens", function()
  local tokens = parser.tokenize("^ ^")
  assert(tokens)
  assert_eq(tokens[1].type, "^")
  assert_eq(tokens[2].type, "^")
end)

test("tokenize < < with space is two tokens", function()
  local tokens = parser.tokenize("< <")
  assert(tokens)
  assert_eq(tokens[1].type, "<")
  assert_eq(tokens[2].type, "<")
end)

test("tokenize > > > with spaces is three tokens", function()
  local tokens = parser.tokenize("> > >")
  assert(tokens)
  assert_eq(tokens[1].type, ">")
  assert_eq(tokens[2].type, ">")
  assert_eq(tokens[3].type, ">")
end)

test("tokenize: && still tokenizes as logical AND (regression)", function()
  assert_tok("a && b", 2, "&&")
end)

test("tokenize: || still tokenizes as logical OR (regression)", function()
  assert_tok("a || b", 2, "||")
end)

test("tokenize: <= still tokenizes as LTE (regression)", function()
  assert_tok("a <= b", 2, "<=")
end)

test("tokenize: >= still tokenizes as GTE (regression)", function()
  assert_tok("a >= b", 2, ">=")
end)

test("tokenize all bitwise operators", function()
  local src = "& | ^ << >> >>> &= |= ^= <<= >>= >>>="
  assert_tok(src, 1, "&")
  assert_tok(src, 2, "|")
  assert_tok(src, 3, "^")
  assert_tok(src, 4, "<<")
  assert_tok(src, 5, ">>")
  assert_tok(src, 6, ">>>")
  assert_tok(src, 7, "&=")
  assert_tok(src, 8, "|=")
  assert_tok(src, 9, "^=")
  assert_tok(src, 10, "<<=")
  assert_tok(src, 11, ">>=")
  assert_tok(src, 12, ">>>=")
end)

test("parse bitwise AND: a & b", function()
  assert_parse_ok("a & b;", {
    A.expr_stmt(A.bin("&", A.id("a"), A.id("b"))),
  })
end)

test("parse bitwise OR: a | b", function()
  assert_parse_ok("a | b;", {
    A.expr_stmt(A.bin("|", A.id("a"), A.id("b"))),
  })
end)

test("parse bitwise XOR: a ^ b", function()
  assert_parse_ok("a ^ b;", {
    A.expr_stmt(A.bin("^", A.id("a"), A.id("b"))),
  })
end)

test("parse left shift: a << 1", function()
  assert_parse_ok("a << 1;", {
    A.expr_stmt(A.bin("<<", A.id("a"), A.num(1))),
  })
end)

test("parse right shift: a >> 1", function()
  assert_parse_ok("a >> 1;", {
    A.expr_stmt(A.bin(">>", A.id("a"), A.num(1))),
  })
end)

test("parse unsigned right shift: a >>> 1", function()
  assert_parse_ok("a >>> 1;", {
    A.expr_stmt(A.bin(">>>", A.id("a"), A.num(1))),
  })
end)

test("parse compound &= ", function()
  assert_parse_ok("x &= 1;", {
    A.expr_stmt(A.bin("&=", A.id("x"), A.num(1))),
  })
end)

test("parse compound |= ", function()
  assert_parse_ok("x |= 1;", {
    A.expr_stmt(A.bin("|=", A.id("x"), A.num(1))),
  })
end)

test("parse compound ^= ", function()
  assert_parse_ok("x ^= 1;", {
    A.expr_stmt(A.bin("^=", A.id("x"), A.num(1))),
  })
end)

test("parse compound <<= ", function()
  assert_parse_ok("x <<= 2;", {
    A.expr_stmt(A.bin("<<=", A.id("x"), A.num(2))),
  })
end)

test("parse compound >>= ", function()
  assert_parse_ok("x >>= 2;", {
    A.expr_stmt(A.bin(">>=", A.id("x"), A.num(2))),
  })
end)

test("parse compound >>>= ", function()
  assert_parse_ok("x >>>= 2;", {
    A.expr_stmt(A.bin(">>>=", A.id("x"), A.num(2))),
  })
end)

test("parse &= on member expression", function()
  assert_parse_ok("obj.x &= 1;", {
    A.expr_stmt(A.bin("&=", A.member(A.id("obj"), A.id("x")), A.num(1))),
  })
end)

test("parse |= on computed member", function()
  assert_parse_ok("arr[i] |= 1;", {
    A.expr_stmt(A.bin("|=", A.member_c(A.id("arr"), A.id("i")), A.num(1))),
  })
end)

test("parse a & b & c is left-associative", function()
  assert_parse_ok("a & b & c;", {
    A.expr_stmt(A.bin("&", A.bin("&", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse a | b | c is left-associative", function()
  assert_parse_ok("a | b | c;", {
    A.expr_stmt(A.bin("|", A.bin("|", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse a << b << c is left-associative", function()
  assert_parse_ok("a << b << c;", {
    A.expr_stmt(A.bin("<<", A.bin("<<", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse &= right-associative: x &= y &= 1", function()
  assert_parse_ok("x &= y &= 1;", {
    A.expr_stmt(A.bin("&=", A.id("x"), A.bin("&=", A.id("y"), A.num(1)))),
  })
end)

test("parse |= right-associative: x |= y |= 1", function()
  assert_parse_ok("x |= y |= 1;", {
    A.expr_stmt(A.bin("|=", A.id("x"), A.bin("|=", A.id("y"), A.num(1)))),
  })
end)

test("parse precedence: + tighter than <<", function()
  assert_parse_ok("a + b << c;", {
    A.expr_stmt(A.bin("<<", A.bin("+", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: << tighter than ===", function()
  assert_parse_ok("a << b === c;", {
    A.expr_stmt(A.bin("===", A.bin("<<", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: === tighter than &", function()
  assert_parse_ok("a === b & c;", {
    A.expr_stmt(A.bin("&", A.bin("===", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: & tighter than ^", function()
  assert_parse_ok("a & b ^ c;", {
    A.expr_stmt(A.bin("^", A.bin("&", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: ^ tighter than |", function()
  assert_parse_ok("a ^ b | c;", {
    A.expr_stmt(A.bin("|", A.bin("^", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: & tighter than |", function()
  assert_parse_ok("a & b | c;", {
    A.expr_stmt(A.bin("|", A.bin("&", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: | tighter than &&", function()
  assert_parse_ok("a | b && c;", {
    A.expr_stmt(A.bin("&&", A.bin("|", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse precedence: | tighter than ||", function()
  assert_parse_ok("a | b || c;", {
    A.expr_stmt(A.bin("||", A.bin("|", A.id("a"), A.id("b")), A.id("c"))),
  })
end)

test("parse ~a & b (unary bitwise NOT then AND)", function()
  assert_parse_ok("~a & b;", {
    A.expr_stmt(A.bin("&", A.una("~", A.id("a")), A.id("b"))),
  })
end)

test("parse a & ~b (bitwise AND then unary NOT)", function()
  assert_parse_ok("a & ~b;", {
    A.expr_stmt(A.bin("&", A.id("a"), A.una("~", A.id("b")))),
  })
end)

test("parse ~a | ~b (both sides unary NOT)", function()
  assert_parse_ok("~a | ~b;", {
    A.expr_stmt(A.bin("|", A.una("~", A.id("a")), A.una("~", A.id("b")))),
  })
end)

test("parse let x = a & b (in variable init)", function()
  assert_parse_ok("let x = a & b;", {
    A.let("x", A.bin("&", A.id("a"), A.id("b"))),
  })
end)

test("parse return a | b (in return)", function()
  assert_parse_ok("return a | b;", {
    A.ret(A.bin("|", A.id("a"), A.id("b"))),
  })
end)

test("parse if (a & b) (in condition)", function()
  assert_parse_ok("if (a & b) { y; }", {
    A.if_(A.bin("&", A.id("a"), A.id("b")), A.block({ A.expr_stmt(A.id("y")) })),
  })
end)

test("parse for (; a | b;) (in for test)", function()
  local ast = parser.parse("for (; a | b;) { y; }")
  assert(ast)
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].test.type, "BinaryExpression")
  assert_eq(ast.body[1].test.operator, "|")
end)

test("parse f(a ^ b) (as call argument)", function()
  assert_parse_ok("f(a ^ b);", {
    A.expr_stmt(A.call(A.id("f"), { A.bin("^", A.id("a"), A.id("b")) })),
  })
end)

test("parse [a << 1] (in array)", function()
  assert_parse_ok("[a << 1];", {
    A.expr_stmt(A.arr({ A.bin("<<", A.id("a"), A.num(1)) })),
  })
end)

test("parse {x: a >> 1} (in object)", function()
  assert_parse_ok("let o = {x: a >> 1};", {
    A.var_decl(
      "let",
      { A.declarator(A.id("o"), A.obj({ A.prop(A.id("x"), A.bin(">>", A.id("a"), A.num(1))) })) }
    ),
  })
end)

test("parse a | b ? 1 : 0 (bitwise in ternary test)", function()
  assert_parse_ok("a | b ? 1 : 0;", {
    A.expr_stmt(A.ternary(A.bin("|", A.id("a"), A.id("b")), A.num(1), A.num(0))),
  })
end)

test("parse x = a & b (bitwise in assignment RHS)", function()
  assert_parse_ok("x = a & b;", {
    A.expr_stmt(A.bin("=", A.id("x"), A.bin("&", A.id("a"), A.id("b")))),
  })
end)

test("parse x++ & y (postfix in bitwise)", function()
  assert_parse_ok("x++ & y;", {
    A.expr_stmt(A.bin("&", A.update("++", A.id("x"), false), A.id("y"))),
  })
end)

test("parse for with i <<= 1 update", function()
  local ast = parser.parse("for (let i = 1; i < 256; i <<= 1) {}")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "<<=")
  assert_eq(f.update.left.name, "i")
  assert_eq(f.update.right.value, 1)
end)

test("error: a & (missing right operand)", function()
  assert_parse_fail("let x = a &;", nil)
end)

test("error: & b (missing left operand)", function()
  assert_parse_fail("& b;", nil)
end)

test("error: a <<< b tokenizes as << < b, parse fails", function()
  assert_parse_fail("a <<< b;", nil)
end)

test("error: a >>>> b tokenizes as >>> > b, parse fails", function()
  assert_parse_fail("a >>>> b;", nil)
end)

test("error: a | (missing right operand)", function()
  assert_parse_fail("let x = a |;", nil)
end)

test("error: a ^ (missing right operand)", function()
  assert_parse_fail("let x = a ^;", nil)
end)

test("error: bitwise AND assign without right operand", function()
  assert_parse_fail("x &= ;", nil)
end)

test("error: left shift assign without right operand", function()
  assert_parse_fail("x <<= ;", nil)
end)

test("parse assignment", function()
  assert_parse_ok("x = 5;", {
    A.expr_stmt(A.bin("=", A.id("x"), A.num(5))),
  })
end)

test("parse compound += ", function()
  assert_parse_ok("x += 1;", {
    A.expr_stmt(A.bin("+=", A.id("x"), A.num(1))),
  })
end)

test("parse compound -=", function()
  assert_parse_ok("x -= 2;", {
    A.expr_stmt(A.bin("-=", A.id("x"), A.num(2))),
  })
end)

test("parse compound *=", function()
  assert_parse_ok("x *= 3;", {
    A.expr_stmt(A.bin("*=", A.id("x"), A.num(3))),
  })
end)

test("parse compound /=", function()
  assert_parse_ok("x /= 4;", {
    A.expr_stmt(A.bin("/=", A.id("x"), A.num(4))),
  })
end)

test("parse compound %=", function()
  assert_parse_ok("x %= 5;", {
    A.expr_stmt(A.bin("%=", A.id("x"), A.num(5))),
  })
end)

test("parse compound += on member expression", function()
  assert_parse_ok("obj.x += 1;", {
    A.expr_stmt(A.bin("+=", A.member(A.id("obj"), A.id("x")), A.num(1))),
  })
end)

test("parse compound *= on computed member", function()
  assert_parse_ok("arr[i] *= 2;", {
    A.expr_stmt(A.bin("*=", A.member_c(A.id("arr"), A.id("i")), A.num(2))),
  })
end)

test("parse compound += precedence: x += 1 + 2 means x += (1 + 2)", function()
  assert_parse_ok("x += 1 + 2;", {
    A.expr_stmt(A.bin("+=", A.id("x"), A.bin("+", A.num(1), A.num(2)))),
  })
end)

test("parse compound += right-associative: x += y += 1", function()
  assert_parse_ok("x += y += 1;", {
    A.expr_stmt(A.bin("+=", A.id("x"), A.bin("+=", A.id("y"), A.num(1)))),
  })
end)

test("parse for with i += 1 update", function()
  local ast = parser.parse("for (let i = 0; i < 10; i += 1) {}")
  assert(ast)
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "+=")
  assert_eq(f.update.left.name, "i")
  assert_eq(f.update.right.value, 1)
end)
