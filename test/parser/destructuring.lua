local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local A = require("test.helpers.ast")
local ast = require("ljs.ast")
local test = T.test
local assert_parse_ok = P.assert_parse_ok
local assert_parse_fail = P.assert_parse_fail

local function obj_pattern(props)
  return { type = ast.TYPE_OBJECT_PATTERN, properties = props }
end

local function arr_pattern(elements)
  return { type = ast.TYPE_ARRAY_PATTERN, elements = elements }
end

local function rest(arg)
  return { type = ast.TYPE_REST_ELEMENT, argument = arg }
end

local function assign_pat(left, right)
  return { type = ast.TYPE_ASSIGNMENT_PATTERN, left = left, right = right }
end

local function prop(key, value, shorthand)
  return { type = ast.TYPE_PROPERTY, key = key, value = value, computed = false, shorthand = shorthand or false }
end

test("parse array destructuring: let [a, b] = [1, 2]", function()
  assert_parse_ok("let [a, b] = [1, 2];", {
    A.var_decl("let", {
      A.declarator(arr_pattern({ A.id("a"), A.id("b") }), A.arr({ A.num(1), A.num(2) })),
    }),
  })
end)

test("parse object destructuring: let {x, y} = obj", function()
  assert_parse_ok("let {x, y} = obj;", {
    A.var_decl("let", {
      A.declarator(obj_pattern({
        prop(A.id("x"), A.id("x"), true),
        prop(A.id("y"), A.id("y"), true),
      }), A.id("obj")),
    }),
  })
end)

test("parse object rename: let {x: y} = obj", function()
  assert_parse_ok("let {x: y} = obj;", {
    A.var_decl("let", {
      A.declarator(obj_pattern({
        prop(A.id("x"), A.id("y"), false),
      }), A.id("obj")),
    }),
  })
end)

test("parse default value in object pattern: let {x = 10} = obj", function()
  assert_parse_ok("let {x = 10} = obj;", {
    A.var_decl("let", {
      A.declarator(obj_pattern({
        prop(A.id("x"), assign_pat(A.id("x"), A.num(10)), true),
      }), A.id("obj")),
    }),
  })
end)

test("parse default value in array pattern: let [a = 5] = arr", function()
  assert_parse_ok("let [a = 5] = arr;", {
    A.var_decl("let", {
      A.declarator(arr_pattern({
        assign_pat(A.id("a"), A.num(5)),
      }), A.id("arr")),
    }),
  })
end)

test("parse rest in array pattern: let [a, ...rest] = arr", function()
  assert_parse_ok("let [a, ...rest] = arr;", {
    A.var_decl("let", {
      A.declarator(arr_pattern({
        A.id("a"),
        rest(A.id("rest")),
      }), A.id("arr")),
    }),
  })
end)

test("parse hole in array pattern: let [, b] = arr", function()
  assert_parse_ok("let [, b] = arr;", {
    A.var_decl("let", {
      A.declarator(arr_pattern({ nil, A.id("b") }), A.id("arr")),
    }),
  })
end)

test("parse nested destructuring: let {a: {b}} = obj", function()
  assert_parse_ok("let {a: {b}} = obj;", {
    A.var_decl("let", {
      A.declarator(obj_pattern({
        prop(A.id("a"), obj_pattern({
          prop(A.id("b"), A.id("b"), true),
        }), false),
      }), A.id("obj")),
    }),
  })
end)

test("parse nested array in object: let {a: [b]} = obj", function()
  assert_parse_ok("let {a: [b]} = obj;", {
    A.var_decl("let", {
      A.declarator(obj_pattern({
        prop(A.id("a"), arr_pattern({ A.id("b") }), false),
      }), A.id("obj")),
    }),
  })
end)

test("parse rest in object pattern: let {x, ...rest} = obj", function()
  assert_parse_ok("let {x, ...rest} = obj;", {
    A.var_decl("let", {
      A.declarator(obj_pattern({
        prop(A.id("x"), A.id("x"), true),
        rest(A.id("rest")),
      }), A.id("obj")),
    }),
  })
end)

test("object destructuring without initializer is a parse error (#175)", function()
  assert_parse_fail("let {x, y};", "Missing initializer")
end)

test("array destructuring without initializer is a parse error (#175)", function()
  assert_parse_fail("var [a, b];", "Missing initializer")
end)

test("bare array destructuring assignment: [a, b] = [1, 2] (#181)", function()
  assert_parse_ok("let a, b; [a, b] = [1, 2];", {
    A.var_decl("let", { A.declarator(A.id("a")), A.declarator(A.id("b")) }),
    A.expr_stmt(A.bin("=", arr_pattern({ A.id("a"), A.id("b") }), A.arr({ A.num(1), A.num(2) }))),
  })
end)

test("bare array destructuring with holes: [a, , b] = [1, 2, 3] (#181)", function()
  assert_parse_ok("let a, b; [a, , b] = [1, 2, 3];", {
    A.var_decl("let", { A.declarator(A.id("a")), A.declarator(A.id("b")) }),
    A.expr_stmt(A.bin("=", arr_pattern({ A.id("a"), nil, A.id("b") }), A.arr({ A.num(1), A.num(2), A.num(3) }))),
  })
end)

test("bare object destructuring assignment: ({x, y} = obj) (#181)", function()
  assert_parse_ok("let x, y; ({x, y} = {x: 1, y: 2});", {
    A.var_decl("let", { A.declarator(A.id("x")), A.declarator(A.id("y")) }),
    A.expr_stmt(A.bin("=", obj_pattern({
      prop(A.id("x"), A.id("x"), true),
      prop(A.id("y"), A.id("y"), true),
    }), A.obj({ A.prop(A.id("x"), A.num(1)), A.prop(A.id("y"), A.num(2)) }))),
  })
end)
