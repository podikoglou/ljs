local T = require("ljs_test")
local P = require("test.helpers.parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq
local assert_parse_ok, assert_parse_fail = P.assert_parse_ok, P.assert_parse_fail

-- ============================================================================
-- Method shorthand
-- ============================================================================

test("method shorthand: no params", function()
  assert_parse_ok("let o = { foo() {} };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "foo" },
                value = {
                  type = "FunctionExpression",
                  name = "foo",
                  params = {},
                  body = {
                    type = "BlockStatement",
                    body = {},
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: one param", function()
  assert_parse_ok("let o = { greet(name) { return name; } };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "greet" },
                value = {
                  type = "FunctionExpression",
                  name = "greet",
                  params = {
                    { type = "Identifier", name = "name" },
                  },
                  body = {
                    type = "BlockStatement",
                    body = {
                      {
                        type = "ReturnStatement",
                        argument = { type = "Identifier", name = "name" },
                      },
                    },
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: multiple params", function()
  assert_parse_ok("let o = { add(a, b) { return a + b; } };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "add" },
                value = {
                  type = "FunctionExpression",
                  name = "add",
                  params = {
                    { type = "Identifier", name = "a" },
                    { type = "Identifier", name = "b" },
                  },
                  body = {
                    type = "BlockStatement",
                    body = {
                      {
                        type = "ReturnStatement",
                        argument = {
                          type = "BinaryExpression",
                          operator = "+",
                          left = { type = "Identifier", name = "a" },
                          right = { type = "Identifier", name = "b" },
                        },
                      },
                    },
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: complex body", function()
  assert_parse_ok("let o = { calc(n) { let x = n * 2; return x; } };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "calc" },
                value = {
                  type = "FunctionExpression",
                  name = "calc",
                  params = {
                    { type = "Identifier", name = "n" },
                  },
                  body = {
                    type = "BlockStatement",
                    body = {
                      {
                        type = "VariableDeclaration",
                        kind = "let",
                        declarations = {
                          {
                            type = "VariableDeclarator",
                            name = { type = "Identifier", name = "x" },
                            init = {
                              type = "BinaryExpression",
                              operator = "*",
                              left = { type = "Identifier", name = "n" },
                              right = { type = "NumberLiteral", value = 2 },
                            },
                          },
                        },
                      },
                      {
                        type = "ReturnStatement",
                        argument = { type = "Identifier", name = "x" },
                      },
                    },
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: multiple methods", function()
  assert_parse_ok("let o = { a() {}, b(x) {} };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "a" },
                value = {
                  type = "FunctionExpression",
                  name = "a",
                  params = {},
                  body = { type = "BlockStatement", body = {} },
                },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "b" },
                value = {
                  type = "FunctionExpression",
                  name = "b",
                  params = { { type = "Identifier", name = "x" } },
                  body = { type = "BlockStatement", body = {} },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: mixed with regular properties", function()
  assert_parse_ok("let o = { x: 1, foo() { return 2; }, y: 3 };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "x" },
                value = { type = "NumberLiteral", value = 1 },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "foo" },
                value = {
                  type = "FunctionExpression",
                  name = "foo",
                  params = {},
                  body = {
                    type = "BlockStatement",
                    body = {
                      {
                        type = "ReturnStatement",
                        argument = { type = "NumberLiteral", value = 2 },
                      },
                    },
                  },
                },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "y" },
                value = { type = "NumberLiteral", value = 3 },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: trailing comma", function()
  assert_parse_ok("let o = { foo() {}, };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "foo" },
                value = {
                  type = "FunctionExpression",
                  name = "foo",
                  params = {},
                  body = { type = "BlockStatement", body = {} },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("method shorthand: method with arrow function value", function()
  assert_parse_ok("let o = { a: 1, go(x) { return x; } };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "a" },
                value = { type = "NumberLiteral", value = 1 },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "go" },
                value = {
                  type = "FunctionExpression",
                  name = "go",
                  params = { { type = "Identifier", name = "x" } },
                  body = {
                    type = "BlockStatement",
                    body = {
                      { type = "ReturnStatement", argument = { type = "Identifier", name = "x" } },
                    },
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

-- ============================================================================
-- Shorthand properties: { x } means { x: x }
-- ============================================================================

test("shorthand property: single", function()
  assert_parse_ok("let o = { x };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "x" },
                value = { type = "Identifier", name = "x" },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("shorthand property: multiple", function()
  assert_parse_ok("let o = { x, y };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "x" },
                value = { type = "Identifier", name = "x" },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "y" },
                value = { type = "Identifier", name = "y" },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("shorthand property: mixed with regular", function()
  assert_parse_ok("let o = { a: 1, b, c: 3 };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "a" },
                value = { type = "NumberLiteral", value = 1 },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "b" },
                value = { type = "Identifier", name = "b" },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "c" },
                value = { type = "NumberLiteral", value = 3 },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("shorthand property: trailing comma", function()
  assert_parse_ok("let o = { x, };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "x" },
                value = { type = "Identifier", name = "x" },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("shorthand property: mixed with method shorthand", function()
  assert_parse_ok("let o = { x, foo() {} };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "x" },
                value = { type = "Identifier", name = "x" },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "foo" },
                value = {
                  type = "FunctionExpression",
                  name = "foo",
                  params = {},
                  body = { type = "BlockStatement", body = {} },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("shorthand property: all three forms combined", function()
  assert_parse_ok("let o = { a: 1, b, c() { return 3; } };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "a" },
                value = { type = "NumberLiteral", value = 1 },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "b" },
                value = { type = "Identifier", name = "b" },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "c" },
                value = {
                  type = "FunctionExpression",
                  name = "c",
                  params = {},
                  body = {
                    type = "BlockStatement",
                    body = {
                      {
                        type = "ReturnStatement",
                        argument = { type = "NumberLiteral", value = 3 },
                      },
                    },
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

-- ============================================================================
-- Negative cases — method shorthand
-- ============================================================================

test("method shorthand fails: string key with parens", function()
  assert_parse_fail('let o = {"foo"() {}};', nil)
end)

test("method shorthand fails: missing body", function()
  assert_parse_fail("let o = { foo() };", nil)
end)

test("method shorthand fails: missing closing paren", function()
  assert_parse_fail("let o = { foo( { };", nil)
end)

-- ============================================================================
-- Negative cases — shorthand properties
-- ============================================================================

test("shorthand property fails: string key without colon", function()
  assert_parse_fail('let o = {"x"};', nil)
end)

-- ============================================================================
-- Negative cases — existing regression
-- ============================================================================

test("regular key:value still works: identifier keys", function()
  assert_parse_ok("let o = {a: 1, b: 2};", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "a" },
                value = { type = "NumberLiteral", value = 1 },
                computed = false,
              },
              {
                type = "Property",
                key = { type = "Identifier", name = "b" },
                value = { type = "NumberLiteral", value = 2 },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("regular key:value still works: string keys", function()
  assert_parse_ok('let o = {"key": 1};', {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "StringLiteral", value = "key" },
                value = { type = "NumberLiteral", value = 1 },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

test("empty object still works", function()
  assert_parse_ok("let o = {};", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = { type = "ObjectExpression", properties = {} },
        },
      },
    },
  })
end)

test("key:value with function expression still works", function()
  assert_parse_ok("let o = { a: function(x) { return x; } };", {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "o" },
          init = {
            type = "ObjectExpression",
            properties = {
              {
                type = "Property",
                key = { type = "Identifier", name = "a" },
                value = {
                  type = "FunctionExpression",
                  params = { { type = "Identifier", name = "x" } },
                  body = {
                    type = "BlockStatement",
                    body = {
                      { type = "ReturnStatement", argument = { type = "Identifier", name = "x" } },
                    },
                  },
                },
                computed = false,
              },
            },
          },
        },
      },
    },
  })
end)

T.summary()
