local cg = require("ljs_codegen")
local T = require("ljs_test")
local test, assert_eq = T.test, T.assert_eq

-- ============================================================================
-- Utilities
-- ============================================================================

test("escape_string: plain text", function()
  assert_eq(cg.escape_string("hello"), "hello")
end)

test("escape_string: special chars", function()
  assert_eq(cg.escape_string("a\nb\tc\\d\"e"), "a\\nb\\tc\\\\d\\\"e")
end)

test("escape_string: control chars", function()
  assert_eq(cg.escape_string(string.char(7)), "\\007")
end)

test("escape_string: empty", function()
  assert_eq(cg.escape_string(""), "")
end)

test("pad: levels", function()
  assert_eq(cg.pad(0), "")
  assert_eq(cg.pad(1), "  ")
  assert_eq(cg.pad(3), "      ")
end)

-- ============================================================================
-- Expressions
-- ============================================================================

test("number: integers and floats", function()
  assert_eq(cg.number(42), "42")
  assert_eq(cg.number(3.14), "3.14")
  assert_eq(cg.number(0), "0")
end)

test("string: basic", function()
  assert_eq(cg.string("hello"), '"hello"')
end)

test("string: escapes", function()
  assert_eq(cg.string("a\nb"), '"a\\nb"')
end)

test("string: empty", function()
  assert_eq(cg.string(""), '""')
end)

test("boolean", function()
  assert_eq(cg.boolean(true), "true")
  assert_eq(cg.boolean(false), "false")
end)

test("nil_val", function()
  assert_eq(cg.nil_val(), "nil")
end)

test("ident", function()
  assert_eq(cg.ident("foo"), "foo")
end)

test("binop: arithmetic and comparison", function()
  assert_eq(cg.binop("+", "a", "b"), "a + b")
  assert_eq(cg.binop("==", "x", "1"), "x == 1")
  assert_eq(cg.binop("~=", "x", "y"), "x ~= y")
end)

test("unop: not and negation", function()
  assert_eq(cg.unop("not", "x"), "not x")
  assert_eq(cg.unop("-", "x"), "-x")
end)

test("call: no args", function()
  assert_eq(cg.call("f", {}), "f()")
end)

test("call: with args", function()
  assert_eq(cg.call("f", {"a", "b"}), "f(a, b)")
end)

test("call: expression callee", function()
  assert_eq(cg.call("math.floor", {"3.14"}), "math.floor(3.14)")
end)

test("member_dot", function()
  assert_eq(cg.member_dot("obj", "prop"), "obj.prop")
end)

test("member_index: string key", function()
  assert_eq(cg.member_index("t", '"key"'), 't["key"]')
end)

test("member_index: numeric key", function()
  assert_eq(cg.member_index("t", "1"), "t[1]")
end)

test("object: empty", function()
  assert_eq(cg.object({}), "{}")
end)

test("object: with fields", function()
  assert_eq(cg.object({{key="a", value="1"}, {key="b", value="2"}}), "{a = 1, b = 2}")
end)

test("array: empty", function()
  assert_eq(cg.array({}), "{}")
end)

test("array: with elements", function()
  assert_eq(cg.array({"1", "2", "3"}), "{1, 2, 3}")
end)

-- ============================================================================
-- Statements
-- ============================================================================

test("local_decl: uninitialized", function()
  assert_eq(cg.local_decl("x", nil, 0), "local x\n")
end)

test("local_decl: with init", function()
  assert_eq(cg.local_decl("x", "42", 0), "local x = 42\n")
end)

test("local_decl: with indent", function()
  assert_eq(cg.local_decl("x", "1", 1), "  local x = 1\n")
end)

test("local_decl: multi-assign", function()
  assert_eq(cg.local_decl("ok, err", "pcall(fn)", 0), "local ok, err = pcall(fn)\n")
end)

test("local_fn", function()
  assert_eq(cg.local_fn("foo", "a, b", "  return a\n", 0), "local function foo(a, b)\n  return a\nend\n")
end)

test("local_fn: with indent", function()
  assert_eq(cg.local_fn("f", "", "    x()\n", 1), "  local function f()\n    x()\n  end\n")
end)

test("fn_expr", function()
  assert_eq(cg.fn_expr("x", "  return x\n", 0), "function(x)\n  return x\nend")
end)

test("return_stmt: with value", function()
  assert_eq(cg.return_stmt("42", 0), "return 42\n")
end)

test("return_stmt: bare", function()
  assert_eq(cg.return_stmt(nil, 0), "return\n")
end)

test("return_stmt: with indent", function()
  assert_eq(cg.return_stmt("x", 1), "  return x\n")
end)

test("break_stmt", function()
  assert_eq(cg.break_stmt(0), "break\n")
  assert_eq(cg.break_stmt(1), "  break\n")
end)

test("expr_stmt", function()
  assert_eq(cg.expr_stmt("f()", 0), "f()\n")
  assert_eq(cg.expr_stmt("x = 1", 1), "  x = 1\n")
end)

test("while_stmt", function()
  assert_eq(cg.while_stmt("x > 0", "  x = x - 1\n", 0), "while x > 0 do\n  x = x - 1\nend\n")
end)

test("for_in_stmt", function()
  assert_eq(cg.for_in_stmt("k, v", "pairs(t)", "  print(k)\n", 0), "for k, v in pairs(t) do\n  print(k)\nend\n")
end)

test("numeric_for", function()
  assert_eq(cg.numeric_for("i", "1", "10", "  print(i)\n", 0), "for i = 1, 10 do\n  print(i)\nend\n")
end)

test("if_stmt: simple", function()
  assert_eq(cg.if_stmt("x", "  y()\n", nil, nil, 0), "if x then\n  y()\nend\n")
end)

test("if_stmt: with else", function()
  assert_eq(cg.if_stmt("x", "  a()\n", nil, "  b()\n", 0), "if x then\n  a()\nelse\n  b()\nend\n")
end)

test("if_stmt: with elseif", function()
  local elseifs = {{test="y", body="  b()\n"}}
  assert_eq(cg.if_stmt("x", "  a()\n", elseifs, nil, 0), "if x then\n  a()\nelseif y then\n  b()\nend\n")
end)

test("if_stmt: with elseif and else", function()
  local elseifs = {{test="y", body="  b()\n"}}
  assert_eq(cg.if_stmt("x", "  a()\n", elseifs, "  c()\n", 0), "if x then\n  a()\nelseif y then\n  b()\nelse\n  c()\nend\n")
end)

test("if_stmt: with indent", function()
  assert_eq(cg.if_stmt("x", "    y()\n", nil, nil, 1), "  if x then\n    y()\n  end\n")
end)

-- ============================================================================
-- Compositions (realistic patterns)
-- ============================================================================

test("composition: pcall wrap for try/catch", function()
  local try_body = "    risky()\n"
  local fn = cg.fn_expr("", try_body, 1)
  local pcall_expr = cg.call("pcall", {fn})
  local decl = cg.local_decl("ok, e", pcall_expr, 0)
  local catch = cg.if_stmt("not ok", "    handleError(e)\n", nil, nil, 0)
  assert_eq(decl .. catch, "local ok, e = pcall(function()\n    risky()\n  end)\nif not ok then\n    handleError(e)\nend\n")
end)

test("composition: for..of with ipairs", function()
  local iter = cg.call("ipairs", {"items"})
  local body = "    print(item)\n"
  assert_eq(cg.for_in_stmt("_, item", iter, body, 0), "for _, item in ipairs(items) do\n    print(item)\nend\n")
end)

-- ============================================================================
-- Goto and labels
-- ============================================================================

test("goto_stmt: no indent", function()
  assert_eq(cg.goto_stmt("_continue", 0), "goto _continue\n")
end)

test("goto_stmt: with indent", function()
  assert_eq(cg.goto_stmt("_continue", 1), "  goto _continue\n")
end)

test("goto_stmt: deep indent", function()
  assert_eq(cg.goto_stmt("_continue", 3), "      goto _continue\n")
end)

test("label: no indent", function()
  assert_eq(cg.label("_continue", 0), "::_continue::\n")
end)

test("label: with indent", function()
  assert_eq(cg.label("_continue", 1), "  ::_continue::\n")
end)

test("label: deep indent", function()
  assert_eq(cg.label("_continue", 3), "      ::_continue::\n")
end)

-- ============================================================================
-- Inline statements
-- ============================================================================

test("local_inline", function()
  assert_eq(cg.local_inline("_t", "x"), "local _t = x")
end)

test("local_inline: with expression", function()
  assert_eq(cg.local_inline("_t", "obj.x"), "local _t = obj.x")
end)

test("return_inline", function()
  assert_eq(cg.return_inline("x"), "return x")
end)

test("return_inline: expression", function()
  assert_eq(cg.return_inline("_t"), "return _t")
end)

test("inline_if_return", function()
  assert_eq(cg.inline_if_return("x", "1", "0"), "if x then return 1 else return 0 end")
end)

test("inline_if_return: with expressions", function()
  assert_eq(cg.inline_if_return("a > b", "a", "b"), "if a > b then return a else return b end")
end)

-- ============================================================================
-- IIFE
-- ============================================================================

test("iife: single statement", function()
  assert_eq(cg.iife({"x = 1"}), "(function() x = 1 end)()")
end)

test("iife: multiple statements", function()
  assert_eq(
    cg.iife({"local _t = x", "x = x + 1", "return _t"}),
    "(function() local _t = x; x = x + 1; return _t end)()"
  )
end)

test("iife: two statements", function()
  assert_eq(
    cg.iife({"x = _ljs_add(x, 1)", "return x"}),
    "(function() x = _ljs_add(x, 1); return x end)()"
  )
end)

test("iife: with inline_if_return", function()
  assert_eq(
    cg.iife({cg.inline_if_return("x", "1", "0")}),
    "(function() if x then return 1 else return 0 end end)()"
  )
end)

-- ============================================================================
-- Composition: update expression patterns
-- ============================================================================

test("composition: prefix ++ IIFE", function()
  local arg = "i"
  local val = cg.call("_ljs_add", {arg, "1"})
  assert_eq(
    cg.iife({cg.binop("=", arg, val), cg.return_inline(arg)}),
    "(function() i = _ljs_add(i, 1); return i end)()"
  )
end)

test("composition: postfix ++ IIFE", function()
  local arg = "i"
  local val = cg.call("_ljs_add", {arg, "1"})
  assert_eq(
    cg.iife({cg.local_inline("_t", arg), cg.binop("=", arg, val), cg.return_inline("_t")}),
    "(function() local _t = i; i = _ljs_add(i, 1); return _t end)()"
  )
end)

test("composition: prefix -- IIFE", function()
  local arg = "i"
  local val = cg.binop("-", arg, "1")
  assert_eq(
    cg.iife({cg.binop("=", arg, val), cg.return_inline(arg)}),
    "(function() i = i - 1; return i end)()"
  )
end)

test("composition: ternary IIFE", function()
  assert_eq(
    cg.iife({cg.inline_if_return("flag", "42", "0")}),
    "(function() if flag then return 42 else return 0 end end)()"
  )
end)

T.summary()
