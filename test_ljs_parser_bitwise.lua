local T = require("ljs_test")
local P = require("ljs_test_parser")
local ljs = require("ljs_parser")
local test, assert_eq = T.test, T.assert_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

-- BITWISE BINARY OPERATOR TESTS
-- ============================================================================

-- Tokenizer: basic operators

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

-- Tokenizer: compound assignment operators

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

-- Tokenizer: maximal munch

test("tokenize &&& maximal munch: && &", function()
  local tokens = ljs.tokenize("&&&")
  assert_eq(tokens[1].type, "&&")
  assert_eq(tokens[2].type, "&")
end)

test("tokenize ||| maximal munch: || |", function()
  local tokens = ljs.tokenize("|||")
  assert_eq(tokens[1].type, "||")
  assert_eq(tokens[2].type, "|")
end)

test("tokenize <<< maximal munch: << <", function()
  local tokens = ljs.tokenize("<<<")
  assert_eq(tokens[1].type, "<<")
  assert_eq(tokens[2].type, "<")
end)

test("tokenize >>>> maximal munch: >>> >", function()
  local tokens = ljs.tokenize(">>>>")
  assert_eq(tokens[1].type, ">>>")
  assert_eq(tokens[2].type, ">")
end)

test("tokenize <<<= maximal munch: << <=", function()
  local tokens = ljs.tokenize("<<<=")
  assert_eq(tokens[1].type, "<<")
  assert_eq(tokens[2].type, "<=")
end)

test("tokenize >>=> maximal munch: >>= >", function()
  local tokens = ljs.tokenize(">>=>")
  assert_eq(tokens[1].type, ">>=")
  assert_eq(tokens[2].type, ">")
end)

test("tokenize & & with space is two tokens", function()
  local tokens = ljs.tokenize("& &")
  assert_eq(tokens[1].type, "&")
  assert_eq(tokens[2].type, "&")
end)

test("tokenize | | with space is two tokens", function()
  local tokens = ljs.tokenize("| |")
  assert_eq(tokens[1].type, "|")
  assert_eq(tokens[2].type, "|")
end)

test("tokenize ^ ^ with space is two tokens", function()
  local tokens = ljs.tokenize("^ ^")
  assert_eq(tokens[1].type, "^")
  assert_eq(tokens[2].type, "^")
end)

test("tokenize < < with space is two tokens", function()
  local tokens = ljs.tokenize("< <")
  assert_eq(tokens[1].type, "<")
  assert_eq(tokens[2].type, "<")
end)

test("tokenize > > > with spaces is three tokens", function()
  local tokens = ljs.tokenize("> > >")
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

-- Parser: basic binary expressions

test("parse bitwise AND: a & b", function()
  assert_parse_ok("a & b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse bitwise OR: a | b", function()
  assert_parse_ok("a | b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse bitwise XOR: a ^ b", function()
  assert_parse_ok("a ^ b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "^",
      left = {type = "Identifier", name = "a"},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse left shift: a << 1", function()
  assert_parse_ok("a << 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<",
      left = {type = "Identifier", name = "a"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse right shift: a >> 1", function()
  assert_parse_ok("a >> 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>",
      left = {type = "Identifier", name = "a"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse unsigned right shift: a >>> 1", function()
  assert_parse_ok("a >>> 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>>",
      left = {type = "Identifier", name = "a"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

-- Parser: compound assignment

test("parse compound &= ", function()
  assert_parse_ok("x &= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse compound |= ", function()
  assert_parse_ok("x |= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse compound ^= ", function()
  assert_parse_ok("x ^= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "^=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse compound <<= ", function()
  assert_parse_ok("x <<= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}}
  })
end)

test("parse compound >>= ", function()
  assert_parse_ok("x >>= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}}
  })
end)

test("parse compound >>>= ", function()
  assert_parse_ok("x >>>= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = ">>>=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}}
  })
end)

test("parse &= on member expression", function()
  assert_parse_ok("obj.x &= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "x"},
        computed = false},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

test("parse |= on computed member", function()
  assert_parse_ok("arr[i] |= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "Identifier", name = "i"},
        computed = true},
      right = {type = "NumberLiteral", value = 1}}}
  })
end)

-- Parser: left-associativity

test("parse a & b & c is left-associative", function()
  assert_parse_ok("a & b & c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse a | b | c is left-associative", function()
  assert_parse_ok("a | b | c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse a << b << c is left-associative", function()
  assert_parse_ok("a << b << c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<",
      left = {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: compound assignment right-associativity

test("parse &= right-associative: x &= y &= 1", function()
  assert_parse_ok("x &= y &= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "&=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 1}}}}
  })
end)

test("parse |= right-associative: x |= y |= 1", function()
  assert_parse_ok("x |= y |= 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "|=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 1}}}}
  })
end)

-- Parser: precedence — arithmetic > shifts

test("parse precedence: + tighter than <<", function()
  assert_parse_ok("a + b << c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "<<",
      left = {type = "BinaryExpression", operator = "+",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: << tighter than ===", function()
  assert_parse_ok("a << b === c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "===",
      left = {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: precedence — comparison > bitwise AND

test("parse precedence: === tighter than &", function()
  assert_parse_ok("a === b & c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "BinaryExpression", operator = "===",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: precedence — & > ^ > |

test("parse precedence: & tighter than ^", function()
  assert_parse_ok("a & b ^ c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "^",
      left = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: ^ tighter than |", function()
  assert_parse_ok("a ^ b | c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "BinaryExpression", operator = "^",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: & tighter than |", function()
  assert_parse_ok("a & b | c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: precedence — | > && > ||

test("parse precedence: | tighter than &&", function()
  assert_parse_ok("a | b && c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&&",
      left = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

test("parse precedence: | tighter than ||", function()
  assert_parse_ok("a | b || c;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "||",
      left = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      right = {type = "Identifier", name = "c"}}}
  })
end)

-- Parser: bitwise with unary ~

test("parse ~a & b (unary bitwise NOT then AND)", function()
  assert_parse_ok("~a & b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse a & ~b (bitwise AND then unary NOT)", function()
  assert_parse_ok("a & ~b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "Identifier", name = "a"},
      right = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "b"}}}}
  })
end)

test("parse ~a | ~b (both sides unary NOT)", function()
  assert_parse_ok("~a | ~b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "|",
      left = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "a"}},
      right = {type = "UnaryExpression", operator = "~",
        argument = {type = "Identifier", name = "b"}}}}
  })
end)

-- Parser: bitwise in various contexts

test("parse let x = a & b (in variable init)", function()
  assert_parse_ok("let x = a & b;", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "x"},
        init = {type = "BinaryExpression", operator = "&",
          left = {type = "Identifier", name = "a"},
          right = {type = "Identifier", name = "b"}}}
    }}
  })
end)

test("parse return a | b (in return)", function()
  assert_parse_ok("return a | b;", {
    {type = "ReturnStatement",
      argument = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}}}
  })
end)

test("parse if (a & b) (in condition)", function()
  assert_parse_ok("if (a & b) { y; }", {
    {type = "IfStatement",
      test = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "BlockStatement", body = {
        {type = "ExpressionStatement", expression = {type = "Identifier", name = "y"}}
      }}}
  })
end)

test("parse for (; a | b;) (in for test)", function()
  local ast = ljs.parse("for (; a | b;) { y; }")
  assert_eq(ast.body[1].type, "ForStatement")
  assert_eq(ast.body[1].test.type, "BinaryExpression")
  assert_eq(ast.body[1].test.operator, "|")
end)

test("parse f(a ^ b) (as call argument)", function()
  assert_parse_ok("f(a ^ b);", {
    {type = "ExpressionStatement", expression = {type = "CallExpression",
      callee = {type = "Identifier", name = "f"},
      arguments = {
        {type = "BinaryExpression", operator = "^",
          left = {type = "Identifier", name = "a"},
          right = {type = "Identifier", name = "b"}}
      }}}
  })
end)

test("parse [a << 1] (in array)", function()
  assert_parse_ok("[a << 1];", {
    {type = "ExpressionStatement", expression = {type = "ArrayExpression", elements = {
      {type = "BinaryExpression", operator = "<<",
        left = {type = "Identifier", name = "a"},
        right = {type = "NumberLiteral", value = 1}}
    }}}
  })
end)

test("parse {x: a >> 1} (in object)", function()
  assert_parse_ok("let o = {x: a >> 1};", {
    {type = "VariableDeclaration", kind = "let", declarations = {
      {type = "VariableDeclarator",
        name = {type = "Identifier", name = "o"},
        init = {type = "ObjectExpression", properties = {
          {type = "Property",
            key = {type = "Identifier", name = "x"},
            value = {type = "BinaryExpression", operator = ">>",
              left = {type = "Identifier", name = "a"},
              right = {type = "NumberLiteral", value = 1}},
            computed = false}
        }}
      }
    }}
  })
end)

test("parse a | b ? 1 : 0 (bitwise in ternary test)", function()
  assert_parse_ok("a | b ? 1 : 0;", {
    {type = "ExpressionStatement", expression = {type = "ConditionalExpression",
      test = {type = "BinaryExpression", operator = "|",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}},
      consequent = {type = "NumberLiteral", value = 1},
      alternate = {type = "NumberLiteral", value = 0}}}
  })
end)

test("parse x = a & b (bitwise in assignment RHS)", function()
  assert_parse_ok("x = a & b;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "&",
        left = {type = "Identifier", name = "a"},
        right = {type = "Identifier", name = "b"}}}}
  })
end)

test("parse x++ & y (postfix in bitwise)", function()
  assert_parse_ok("x++ & y;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "&",
      left = {type = "UpdateExpression", operator = "++",
        argument = {type = "Identifier", name = "x"}, prefix = false},
      right = {type = "Identifier", name = "y"}}}
  })
end)

test("parse for with i <<= 1 update", function()
  local ast = ljs.parse("for (let i = 1; i < 256; i <<= 1) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "<<=")
  assert_eq(f.update.left.name, "i")
  assert_eq(f.update.right.value, 1)
end)

-- parse_tokens isolation tests for bitwise ops moved after TK definition

-- Bitwise negative tests

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
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 5}}
    }
  })
end)

test("parse compound += ", function()
  assert_parse_ok("x += 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 1}}
    }
  })
end)

test("parse compound -=", function()
  assert_parse_ok("x -= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "-=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse compound *=", function()
  assert_parse_ok("x *= 3;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 3}}
    }
  })
end)

test("parse compound /=", function()
  assert_parse_ok("x /= 4;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "/=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 4}}
    }
  })
end)

test("parse compound %=", function()
  assert_parse_ok("x %= 5;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "%=",
      left = {type = "Identifier", name = "x"},
      right = {type = "NumberLiteral", value = 5}}
    }
  })
end)

test("parse compound += on member expression", function()
  assert_parse_ok("obj.x += 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "obj"},
        property = {type = "Identifier", name = "x"},
        computed = false},
      right = {type = "NumberLiteral", value = 1}}
    }
  })
end)

test("parse compound *= on computed member", function()
  assert_parse_ok("arr[i] *= 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "*=",
      left = {type = "MemberExpression",
        object = {type = "Identifier", name = "arr"},
        property = {type = "Identifier", name = "i"},
        computed = true},
      right = {type = "NumberLiteral", value = 2}}
    }
  })
end)

test("parse compound += precedence: x += 1 + 2 means x += (1 + 2)", function()
  assert_parse_ok("x += 1 + 2;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "+",
        left = {type = "NumberLiteral", value = 1},
        right = {type = "NumberLiteral", value = 2}}}
    }
  })
end)

test("parse compound += right-associative: x += y += 1", function()
  assert_parse_ok("x += y += 1;", {
    {type = "ExpressionStatement", expression = {type = "BinaryExpression", operator = "+=",
      left = {type = "Identifier", name = "x"},
      right = {type = "BinaryExpression", operator = "+=",
        left = {type = "Identifier", name = "y"},
        right = {type = "NumberLiteral", value = 1}}}
    }
  })
end)

test("parse for with i += 1 update", function()
  local ast = ljs.parse("for (let i = 0; i < 10; i += 1) {}")
  local f = ast.body[1]
  assert_eq(f.type, "ForStatement")
  assert_eq(f.update.type, "BinaryExpression")
  assert_eq(f.update.operator, "+=")
  assert_eq(f.update.left.name, "i")
  assert_eq(f.update.right.value, 1)
end)

-- ============================================================================
T.summary()
