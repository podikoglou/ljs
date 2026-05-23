local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local test = T.test
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

local function class_decl(name, superClass, body)
  return { type = "ClassDeclaration", name = name, superClass = superClass, body = body }
end

local function class_expr(name, superClass, body)
  return { type = "ClassExpression", name = name, superClass = superClass, body = body }
end

local function method_def(kind, key, value, static_flag)
  return { type = "MethodDefinition", kind = kind, key = key, value = value, static = static_flag }
end

local function super_expr()
  return { type = "SuperExpression" }
end

local function ctor_fn(params, body)
  return { type = "FunctionExpression", params = params, body = body, is_method = false }
end

local function method_fn(params, body)
  return { type = "FunctionExpression", params = params, body = body, is_method = true }
end

test("class Foo {} — empty class", function()
  assert_parse_ok("class Foo {}", {
    class_decl("Foo", nil, {}),
  })
end)

test("class Foo { constructor() {} } — constructor method", function()
  assert_parse_ok("class Foo { constructor() {} }", {
    class_decl("Foo", nil, {
      method_def("constructor", A.id("constructor"), ctor_fn({}, A.block({})), false),
    }),
  })
end)

test("class Foo { method() { return 1; } } — method definition", function()
  assert_parse_ok("class Foo { method() { return 1; } }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("method"), method_fn({}, A.block({ A.ret(A.num(1)) })), false),
    }),
  })
end)

test(
  "class Foo { constructor(x) { this.x = x; } method() { return this.x; } } — constructor + method",
  function()
    assert_parse_ok("class Foo { constructor(x) { this.x = x; } method() { return this.x; } }", {
      class_decl("Foo", nil, {
        method_def(
          "constructor",
          A.id("constructor"),
          ctor_fn(
            { A.id("x") },
            A.block({
              A.expr_stmt(A.bin("=", A.member(A.this_(), A.id("x")), A.id("x"))),
            })
          ),
          false
        ),
        method_def(
          "method",
          A.id("method"),
          method_fn(
            {},
            A.block({
              A.ret(A.member(A.this_(), A.id("x"))),
            })
          ),
          false
        ),
      }),
    })
  end
)

test("class Foo { a() {} b() {} } — multiple methods", function()
  assert_parse_ok("class Foo { a() {} b() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("a"), method_fn({}, A.block({})), false),
      method_def("method", A.id("b"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("class Dog extends Animal {} — extends with identifier", function()
  assert_parse_ok("class Dog extends Animal {}", {
    class_decl("Dog", A.id("Animal"), {}),
  })
end)

test("class Foo extends a.B {} — extends with member expression", function()
  assert_parse_ok("class Foo extends a.B {}", {
    class_decl("Foo", A.member(A.id("a"), A.id("B")), {}),
  })
end)

test("class Foo { static method() { return 1; } } — static method", function()
  assert_parse_ok("class Foo { static method() { return 1; } }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("method"), method_fn({}, A.block({ A.ret(A.num(1)) })), true),
    }),
  })
end)

test("class Foo { static a() {} b() {} } — static and non-static mixed", function()
  assert_parse_ok("class Foo { static a() {} b() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("a"), method_fn({}, A.block({})), true),
      method_def("method", A.id("b"), method_fn({}, A.block({})), false),
    }),
  })
end)

test(
  "class Foo { constructor() {} static create() { return 1; } method() {} } — all three types",
  function()
    assert_parse_ok("class Foo { constructor() {} static create() { return 1; } method() {} }", {
      class_decl("Foo", nil, {
        method_def("constructor", A.id("constructor"), ctor_fn({}, A.block({})), false),
        method_def("method", A.id("create"), method_fn({}, A.block({ A.ret(A.num(1)) })), true),
        method_def("method", A.id("method"), method_fn({}, A.block({})), false),
      }),
    })
  end
)

test("super() — SuperExpression as callee of CallExpression", function()
  assert_parse_ok("super();", {
    A.expr_stmt(A.call(super_expr(), {})),
  })
end)

test("super.method() — MemberExpression with SuperExpression, then call", function()
  assert_parse_ok("super.method();", {
    A.expr_stmt(A.call(A.member(super_expr(), A.id("method")), {})),
  })
end)

test("super.method — MemberExpression with SuperExpression (no call)", function()
  assert_parse_ok("super.method;", {
    A.expr_stmt(A.member(super_expr(), A.id("method"))),
  })
end)

test("super.method().another() — chained calls on super", function()
  assert_parse_ok("super.method().another();", {
    A.expr_stmt(
      A.call(A.member(A.call(A.member(super_expr(), A.id("method")), {}), A.id("another")), {})
    ),
  })
end)

test("let F = class {} — anonymous ClassExpression", function()
  assert_parse_ok("let F = class {};", {
    A.let("F", class_expr(nil, nil, {})),
  })
end)

test("let F = class Foo {} — named ClassExpression", function()
  assert_parse_ok("let F = class Foo {};", {
    A.let("F", class_expr("Foo", nil, {})),
  })
end)

test("let F = class extends Bar {} — anonymous class expression with extends", function()
  assert_parse_ok("let F = class extends Bar {};", {
    A.let("F", class_expr(nil, A.id("Bar"), {})),
  })
end)

test('class Foo { "my method"() {} } — method with string key', function()
  assert_parse_ok('class Foo { "my method"() {} }', {
    class_decl("Foo", nil, {
      method_def("method", A.str("my method"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("class Foo { method() {} } — no constructor, only method", function()
  assert_parse_ok("class Foo { method() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("method"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("class {} — missing name in class declaration — error", function()
  assert_parse_fail("class {}", "Expected Identifier")
end)

test("class Foo { 42 } — invalid method name — error", function()
  assert_parse_fail("class Foo { 42 }", "Expected method name")
end)

-- ============================================================================
-- Keywords as class method names (IdentifierName vs Identifier)
-- ============================================================================

test("keyword 'of' as class method name", function()
  assert_parse_ok("class Foo { of() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("of"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("keyword 'in' as class method name", function()
  assert_parse_ok("class Foo { in() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("in"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("keyword 'return' as class method name", function()
  assert_parse_ok("class Foo { return() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("return"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("keyword 'throw' as class method name", function()
  assert_parse_ok("class Foo { throw() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("throw"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("keyword 'delete' as class method name", function()
  assert_parse_ok("class Foo { delete() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("delete"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("keyword 'typeof' as class method name", function()
  assert_parse_ok("class Foo { typeof() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("typeof"), method_fn({}, A.block({})), false),
    }),
  })
end)

test("keyword 'new' as class method name", function()
  assert_parse_ok("class Foo { new() {} }", {
    class_decl("Foo", nil, {
      method_def("method", A.id("new"), method_fn({}, A.block({})), false),
    }),
  })
end)
