local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail
local tok, assert_tok, assert_tokenize_fail = P.tok, P.assert_tok, P.assert_tokenize_fail
local parser = P.parser
local TK = parser.TOKEN

-- SWITCH/CASE/BREAK TESTS
-- ============================================================================

test("tokenize switch/case/default/break keywords", function()
  local src = "switch case default break"
  assert_tok(src, 1, "switch", "switch")
  assert_tok(src, 2, "case", "case")
  assert_tok(src, 3, "default", "default")
  assert_tok(src, 4, "break", "break")
end)

test("tokenize 'switchboard' as Identifier (not keyword prefix)", function()
  assert_tok("switchboard", 1, "Identifier", "switchboard")
end)

test("tokenize 'caseInsensitive' as Identifier", function()
  assert_tok("caseInsensitive", 1, "Identifier", "caseInsensitive")
end)

test("tokenize 'breakdown' as Identifier", function()
  assert_tok("breakdown", 1, "Identifier", "breakdown")
end)

test("tokenize 'continue' keyword", function()
  assert_tok("continue", 1, "continue", "continue")
end)

test("tokenize 'continuation' as Identifier (not keyword prefix)", function()
  assert_tok("continuation", 1, "Identifier", "continuation")
end)

-- SwitchStatement: basic structure

test("parse minimal switch with one case + break", function()
  assert_parse_ok("switch (x) { case 1: break; }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), {
        A.break_(),
      }),
    }),
  })
end)

test("parse switch with default only", function()
  assert_parse_ok("switch (x) { default: y; }", {
    A.switch(A.id("x"), {
      A.default({
        A.expr_stmt(A.id("y")),
      }),
    }),
  })
end)

test("parse empty switch body", function()
  assert_parse_ok("switch (x) {}", {
    A.switch(A.id("x"), {}),
  })
end)

test("parse multiple cases with break", function()
  assert_parse_ok("switch (x) { case 1: a; break; case 2: b; break; }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), {
        A.expr_stmt(A.id("a")),
        A.break_(),
      }),
      A.case(A.num(2), {
        A.expr_stmt(A.id("b")),
        A.break_(),
      }),
    }),
  })
end)

test("parse case fallthrough (empty consequent)", function()
  assert_parse_ok("switch (x) { case 1: case 2: break; }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), {}),
      A.case(A.num(2), {
        A.break_(),
      }),
    }),
  })
end)

test("parse case + default + case (default in middle)", function()
  assert_parse_ok("switch (x) { case 1: a; break; default: b; break; case 2: c; break; }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), {
        A.expr_stmt(A.id("a")),
        A.break_(),
      }),
      A.default({
        A.expr_stmt(A.id("b")),
        A.break_(),
      }),
      A.case(A.num(2), {
        A.expr_stmt(A.id("c")),
        A.break_(),
      }),
    }),
  })
end)

-- SwitchStatement: discriminant expressions

test("parse switch discriminant is binary expression", function()
  local ast = parser.parse("switch (a + b) {}")
  assert(ast)
  local sw = ast.body[1]
  assert_eq(sw.type, "SwitchStatement")
  assert_eq(sw.discriminant.type, "BinaryExpression")
  assert_eq(sw.discriminant.operator, "+")
end)

test("parse switch discriminant is call expression", function()
  local ast = parser.parse("switch (f()) {}")
  assert(ast)
  local sw = ast.body[1]
  assert_eq(sw.discriminant.type, "CallExpression")
  assert_eq(sw.discriminant.callee.name, "f")
end)

test("parse switch discriminant is member expression", function()
  local ast = parser.parse("switch (obj.prop) {}")
  assert(ast)
  local sw = ast.body[1]
  assert_eq(sw.discriminant.type, "MemberExpression")
  assert_eq(sw.discriminant.object.name, "obj")
  assert_eq(sw.discriminant.property.name, "prop")
end)

test("parse switch discriminant is ternary expression", function()
  local ast = parser.parse("switch (a ? 1 : 2) {}")
  assert(ast)
  local sw = ast.body[1]
  assert_eq(sw.discriminant.type, "ConditionalExpression")
  assert_eq(sw.discriminant.test.name, "a")
end)

-- SwitchStatement: case test expressions

test("parse case test is string literal", function()
  local ast = parser.parse('switch (x) { case "hello": break; }')
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "StringLiteral")
  assert_eq(case.test.value, "hello")
end)

test("parse case test is identifier", function()
  local ast = parser.parse("switch (x) { case myVar: break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "Identifier")
  assert_eq(case.test.name, "myVar")
end)

test("parse case test is boolean", function()
  local ast = parser.parse("switch (x) { case true: break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "BooleanLiteral")
  assert_eq(case.test.value, true)
end)

test("parse case test is member expression", function()
  local ast = parser.parse("switch (x) { case obj.key: break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "MemberExpression")
  assert_eq(case.test.object.name, "obj")
  assert_eq(case.test.property.name, "key")
end)

test("parse case test is computed member", function()
  local ast = parser.parse("switch (x) { case arr[0]: break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.test.type, "MemberExpression")
  assert_eq(case.test.computed, true)
  assert_eq(case.test.object.name, "arr")
end)

-- SwitchStatement: case body variations

test("parse case body with multiple statements", function()
  local ast = parser.parse("switch (x) { case 1: a; b; c; break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(#case.consequent, 4)
  assert_eq(case.consequent[1].expression.name, "a")
  assert_eq(case.consequent[2].expression.name, "b")
  assert_eq(case.consequent[3].expression.name, "c")
  assert_eq(case.consequent[4].type, "BreakStatement")
end)

test("parse case body with variable declaration", function()
  local ast = parser.parse("switch (x) { case 1: let y = 2; break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.consequent[1].type, "VariableDeclaration")
  assert_eq(case.consequent[1].kind, "let")
  assert_eq(case.consequent[2].type, "BreakStatement")
end)

test("parse case body with if/else", function()
  local ast = parser.parse("switch (x) { case 1: if (a) { b; } break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.consequent[1].type, "IfStatement")
  assert_eq(case.consequent[1].test.name, "a")
  assert_eq(case.consequent[2].type, "BreakStatement")
end)

test("parse case body with return", function()
  local ast = parser.parse("function f(x) { switch (x) { case 1: return x; } }")
  assert(ast)
  local case = ast.body[1].body.body[1].cases[1]
  assert_eq(case.consequent[1].type, "ReturnStatement")
  assert_eq(case.consequent[1].argument.name, "x")
end)

test("parse case body with throw", function()
  local ast = parser.parse('switch (x) { case 1: throw "err"; }')
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(case.consequent[1].type, "ThrowStatement")
  assert_eq(case.consequent[1].argument.value, "err")
end)

test("parse case with empty body at end of switch", function()
  assert_parse_ok("switch (x) { case 1: }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), {}),
    }),
  })
end)

test("parse case with empty default at end", function()
  assert_parse_ok("switch (x) { default: }", {
    A.switch(A.id("x"), {
      A.default({}),
    }),
  })
end)

-- SwitchStatement: default position

test("parse default first", function()
  local ast = parser.parse("switch (x) { default: a; break; case 1: b; break; }")
  assert(ast)
  assert_eq(#ast.body[1].cases, 2)
  assert_eq(ast.body[1].cases[1].test, nil)
  assert_eq(ast.body[1].cases[2].test.value, 1)
end)

test("parse default last", function()
  local ast = parser.parse("switch (x) { case 1: a; break; default: b; break; }")
  assert(ast)
  assert_eq(#ast.body[1].cases, 2)
  assert_eq(ast.body[1].cases[1].test.value, 1)
  assert_eq(ast.body[1].cases[2].test, nil)
end)

-- BreakStatement

test("error: bare break at top level", function()
  assert_parse_fail("break;", "break")
end)

test("parse break without semicolon before }", function()
  assert_parse_ok("switch (x) { case 1: break }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), {
        A.break_(),
      }),
    }),
  })
end)

test("parse break inside while loop", function()
  local ast = parser.parse("while (true) { break; }")
  assert(ast)
  local brk = ast.body[1].body.body[1]
  assert_eq(brk.type, "BreakStatement")
end)

test("parse break inside for loop", function()
  local ast = parser.parse("for (;;) { break; }")
  assert(ast)
  local brk = ast.body[1].body.body[1]
  assert_eq(brk.type, "BreakStatement")
end)

test("parse break inside do...while", function()
  local ast = parser.parse("do { break; } while (true);")
  assert(ast)
  local brk = ast.body[1].body.body[1]
  assert_eq(brk.type, "BreakStatement")
end)

-- ContinueStatement

test("error: bare continue at top level", function()
  assert_parse_fail("continue;", "continue")
end)

test("parse continue without semicolon before }", function()
  assert_parse_ok("while (x) { continue }", {
    A.while_(
      A.id("x"),
      A.block({
        A.continue_(),
      })
    ),
  })
end)

test("parse continue inside while loop", function()
  local ast = parser.parse("while (true) { continue; }")
  assert(ast)
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside for-of loop", function()
  local ast = parser.parse("for (let x of arr) { continue; }")
  assert(ast)
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside for-in loop", function()
  local ast = parser.parse("for (let k in obj) { continue; }")
  assert(ast)
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside C-style for loop", function()
  local ast = parser.parse("for (;;) { continue; }")
  assert(ast)
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside do...while", function()
  local ast = parser.parse("do { continue; } while (true);")
  assert(ast)
  local cont = ast.body[1].body.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside nested if within loop", function()
  local ast = parser.parse("while (x) { if (a) { continue; } b; }")
  assert(ast)
  local if_stmt = ast.body[1].body.body[1]
  assert_eq(if_stmt.type, "IfStatement")
  local cont = if_stmt.consequent.body[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue inside switch within loop", function()
  local ast = parser.parse("while (x) { switch (a) { case 1: continue; } }")
  assert(ast)
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.type, "SwitchStatement")
  local cont = sw.cases[1].consequent[1]
  assert_eq(cont.type, "ContinueStatement")
end)

test("parse continue in nested loops (inner and outer)", function()
  local ast = parser.parse("while (a) { while (b) { continue; } continue; }")
  assert(ast)
  local outer = ast.body[1]
  local inner = outer.body.body[1]
  local inner_cont = inner.body.body[1]
  assert_eq(inner_cont.type, "ContinueStatement")
  local outer_cont = outer.body.body[2]
  assert_eq(outer_cont.type, "ContinueStatement")
end)

test("parse continue mixed with break in switch inside loop", function()
  local ast =
    parser.parse("while (x) { switch (a) { case 1: continue; case 2: break; default: continue; } }")
  assert(ast)
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.cases[1].consequent[1].type, "ContinueStatement")
  assert_eq(sw.cases[2].consequent[1].type, "BreakStatement")
  assert_eq(sw.cases[3].consequent[1].type, "ContinueStatement")
end)

test("parse continue after other statements", function()
  local ast = parser.parse("while (x) { a; b; continue; c; }")
  assert(ast)
  local body = ast.body[1].body.body
  assert_eq(body[1].type, "ExpressionStatement")
  assert_eq(body[2].type, "ExpressionStatement")
  assert_eq(body[3].type, "ContinueStatement")
  assert_eq(body[4].type, "ExpressionStatement")
end)

test("parse multiple continues in same loop body", function()
  local ast = parser.parse("while (x) { if (a) { continue; } if (b) { continue; } c; }")
  assert(ast)
  local body = ast.body[1].body.body
  assert_eq(body[1].consequent.body[1].type, "ContinueStatement")
  assert_eq(body[2].consequent.body[1].type, "ContinueStatement")
end)

test("error: continue as expression operand", function()
  assert_parse_fail("let x = continue;", nil)
end)

test("note: labeled continue accepted (labels ignored, same as break)", function()
  local ast = parser.parse("while (x) { continue foo; }")
  assert(ast)
  assert_eq(ast.body[1].body.body[1].type, "ContinueStatement")
end)

-- Integration

test("integration: switch after variable declaration", function()
  local ast = parser.parse("let x = 1; switch (x) { case 1: break; }")
  assert(ast)
  assert_eq(#ast.body, 2)
  assert_eq(ast.body[1].type, "VariableDeclaration")
  assert_eq(ast.body[2].type, "SwitchStatement")
end)

test("integration: switch inside function body", function()
  local ast = parser.parse("function f(x) { switch (x) { case 1: return x; default: return 0; } }")
  assert(ast)
  local fn = ast.body[1]
  assert_eq(fn.type, "FunctionDeclaration")
  local sw = fn.body.body[1]
  assert_eq(sw.type, "SwitchStatement")
  assert_eq(#sw.cases, 2)
  assert_eq(sw.cases[1].test.value, 1)
  assert_eq(sw.cases[2].test, nil)
end)

test("integration: switch inside while", function()
  local ast = parser.parse("while (cond) { switch (x) { case 1: break; } }")
  assert(ast)
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.type, "SwitchStatement")
end)

test("integration: nested switch statements", function()
  local ast = parser.parse("switch (a) { case 1: switch (b) { case 2: break; } break; }")
  assert(ast)
  local outer = ast.body[1]
  assert_eq(outer.type, "SwitchStatement")
  assert_eq(outer.cases[1].test.value, 1)
  local inner = outer.cases[1].consequent[1]
  assert_eq(inner.type, "SwitchStatement")
  assert_eq(inner.cases[1].test.value, 2)
  local brk = outer.cases[1].consequent[2]
  assert_eq(brk.type, "BreakStatement")
end)

test("integration: switch inside for loop", function()
  local ast = parser.parse("for (;;) { switch (x) { case 1: break; default: break; } }")
  assert(ast)
  local sw = ast.body[1].body.body[1]
  assert_eq(sw.type, "SwitchStatement")
  assert_eq(#sw.cases, 2)
end)

test("integration: switch with complex case body", function()
  local ast = parser.parse("switch (x) { case 1: let y = 2; if (y > 0) { y; } break; }")
  assert(ast)
  local case = ast.body[1].cases[1]
  assert_eq(#case.consequent, 3)
  assert_eq(case.consequent[1].type, "VariableDeclaration")
  assert_eq(case.consequent[2].type, "IfStatement")
  assert_eq(case.consequent[3].type, "BreakStatement")
end)

test("error: break inside if (not in loop or switch)", function()
  assert_parse_fail("if (x) { break; }", "break")
end)

test("error: continue inside if (not in loop)", function()
  assert_parse_fail("if (x) { continue; }", "continue")
end)

test("error: break inside function declaration", function()
  assert_parse_fail("function f() { break; }", "break")
end)

test("error: continue inside function declaration", function()
  assert_parse_fail("function f() { continue; }", "continue")
end)

test("error: continue inside bare switch (not in loop)", function()
  assert_parse_fail("switch (x) { case 1: continue; }", "continue")
end)

test("error: break inside function expression", function()
  assert_parse_fail("let f = function() { break; };", "break")
end)

test("error: continue inside function expression", function()
  assert_parse_fail("let f = function() { continue; };", "continue")
end)

test("error: break inside arrow function", function()
  assert_parse_fail("let f = () => { break; };", "break")
end)

test("error: continue inside arrow function", function()
  assert_parse_fail("let f = () => { continue; };", "continue")
end)

test("ok: break in while loop", function()
  assert_parse_ok("while (true) { break; }", {
    A.while_(A.bool(true), A.block({ A.break_() })),
  })
end)

test("ok: continue in while loop", function()
  assert_parse_ok("while (true) { continue; }", {
    A.while_(A.bool(true), A.block({ A.continue_() })),
  })
end)

test("ok: break in for loop", function()
  assert_parse_ok("for (;;) { break; }", {
    A.for_(nil, nil, nil, A.block({ A.break_() })),
  })
end)

test("ok: continue in for loop", function()
  assert_parse_ok("for (;;) { continue; }", {
    A.for_(nil, nil, nil, A.block({ A.continue_() })),
  })
end)

test("ok: break in do-while", function()
  assert_parse_ok("do { break; } while (true);", {
    A.do_while(A.block({ A.break_() }), A.bool(true)),
  })
end)

test("ok: continue in do-while", function()
  assert_parse_ok("do { continue; } while (true);", {
    A.do_while(A.block({ A.continue_() }), A.bool(true)),
  })
end)

test("ok: break in switch (no loop)", function()
  assert_parse_ok("switch (x) { case 1: break; }", {
    A.switch(A.id("x"), {
      A.case(A.num(1), { A.break_() }),
    }),
  })
end)

test("ok: continue in switch inside loop", function()
  assert_parse_ok("while (x) { switch (a) { case 1: continue; } }", {
    A.while_(A.id("x"), A.block({
      A.switch(A.id("a"), {
        A.case(A.num(1), { A.continue_() }),
      }),
    })),
  })
end)

test("ok: break in nested loop", function()
  assert_parse_ok("while (a) { for (;;) { break; } }", {
    A.while_(A.id("a"), A.block({
      A.for_(nil, nil, nil, A.block({ A.break_() })),
    })),
  })
end)

test("ok: break/continue inside if within loop", function()
  assert_parse_ok("while (x) { if (a) { break; } if (b) { continue; } }", {
    A.while_(A.id("x"), A.block({
      A.if_(A.id("a"), A.block({ A.break_() })),
      A.if_(A.id("b"), A.block({ A.continue_() })),
    })),
  })
end)

test("ok: break/continue reset across function boundary", function()
  local ast = parser.parse("while (x) { function f() { } break; }")
  assert(ast)
  assert_eq(#ast.body, 1)
  assert_eq(ast.body[1].type, "WhileStatement")
  assert_eq(#ast.body[1].body.body, 2)
  assert_eq(ast.body[1].body.body[1].type, "FunctionDeclaration")
  assert_eq(ast.body[1].body.body[2].type, "BreakStatement")
end)

test("ok: break in switch inside loop (both valid)", function()
  assert_parse_ok("while (x) { switch (a) { case 1: break; } }", {
    A.while_(A.id("x"), A.block({
      A.switch(A.id("a"), {
        A.case(A.num(1), { A.break_() }),
      }),
    })),
  })
end)

test("error: break in nested function inside loop", function()
  assert_parse_fail("while (x) { function f() { break; } }", "break")
end)

test("error: continue in nested function inside loop", function()
  assert_parse_fail("while (x) { function f() { continue; } }", "continue")
end)

-- parse_tokens isolation

local function tok_constructor(type, value, line, col)
  return { type = type, value = value, line = line or 1, col = col or 1 }
end

test("parse_tokens: minimal switch", function()
  local tokens = {
    tok_constructor(TK.SWITCH, "switch"),
    tok_constructor(TK.LPAREN),
    tok_constructor(TK.IDENTIFIER, "x"),
    tok_constructor(TK.RPAREN),
    tok_constructor(TK.LBRACE),
    tok_constructor(TK.CASE, "case"),
    tok_constructor(TK.NUMBER, 1),
    tok_constructor(TK.COLON),
    tok_constructor(TK.BREAK, "break"),
    tok_constructor(TK.SEMICOLON),
    tok_constructor(TK.RBRACE),
    tok_constructor(TK.EOF),
  }
  local ast = parser.parse_tokens(tokens)
  assert_table_eq(
    ast,
    A.program({
      A.switch(A.id("x"), {
        A.case(A.num(1), {
          A.break_(),
        }),
      }),
    })
  )
end)

test("parse_tokens: break statement at top level fails", function()
  local tokens = {
    tok_constructor(TK.BREAK, "break"),
    tok_constructor(TK.SEMICOLON),
    tok_constructor(TK.EOF),
  }
  local ast, err = parser.parse_tokens(tokens)
  assert(ast == nil, "expected parse failure for bare break")
  assert(err ~= nil, "expected error for bare break")
end)

test("parse_tokens: continue statement at top level fails", function()
  local tokens = {
    tok_constructor(TK.CONTINUE, "continue"),
    tok_constructor(TK.SEMICOLON),
    tok_constructor(TK.EOF),
  }
  local ast, err = parser.parse_tokens(tokens)
  assert(ast == nil, "expected parse failure for bare continue")
  assert(err ~= nil, "expected error for bare continue")
end)
