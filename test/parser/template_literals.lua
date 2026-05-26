local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local parser = require("ljs.parser")
local ast = require("ljs.ast")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq

local function assert_parse_ok(source, expected_body, msg)
  local result, err = parser.parse(source)
  if not result then
    error(string.format("%s: parse failed: %s", msg or source, tostring(err)))
  end
  assert_table_eq(result, { type = "Program", body = expected_body }, msg or source)
end

test("tokenize simple template literal", function()
  local tokens, err = parser.tokenize("`hello`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].type, "TemplateLiteral")
  assert_eq(tokens[1].value.quasis[1], "hello")
  assert_eq(#tokens[1].value.expression_sources, 0)
end)

test("tokenize template with one interpolation", function()
  local tokens, err = parser.tokenize("`hello ${name}`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].type, "TemplateLiteral")
  assert_eq(tokens[1].value.quasis[1], "hello ")
  assert_eq(tokens[1].value.quasis[2], "")
  assert_eq(tokens[1].value.expression_sources[1], "name")
  assert_eq(#tokens[1].value.expression_sources, 1)
end)

test("tokenize template with multiple interpolations", function()
  local tokens, err = parser.tokenize("`${a} and ${b}`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "")
  assert_eq(tokens[1].value.quasis[2], " and ")
  assert_eq(tokens[1].value.quasis[3], "")
  assert_eq(tokens[1].value.expression_sources[1], "a")
  assert_eq(tokens[1].value.expression_sources[2], "b")
end)

test("tokenize template with expression containing braces", function()
  local tokens, err = parser.tokenize("`result: ${obj[key]}`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "result: ")
  assert_eq(tokens[1].value.quasis[2], "")
  assert_eq(tokens[1].value.expression_sources[1], "obj[key]")
end)

test("tokenize multi-line template literal", function()
  local tokens, err = parser.tokenize("`line1\nline2`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "line1\nline2")
end)

test("parse multi-line template literal", function()
  assert_parse_ok("`line1\nline2`", {
    {
      type = ast.TYPE_EXPRESSION_STATEMENT,
      expression = {
        type = ast.TYPE_TEMPLATE_LITERAL,
        quasis = {
          { type = "TemplateElement", value = "line1\nline2", tail = true },
        },
        expressions = {},
      },
    },
  })
end)

test("tokenize template with escape \\n", function()
  local tokens, err = parser.tokenize("`a\\nb`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "a\nb")
end)

test("tokenize template with escape \\t", function()
  local tokens, err = parser.tokenize("`a\\tb`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "a\tb")
end)

test("tokenize template with escaped backtick", function()
  local tokens, err = parser.tokenize("`a\\`b`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "a`b")
end)

test("tokenize template with escaped backslash", function()
  local tokens, err = parser.tokenize("`a\\\\b`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "a\\b")
end)

test("tokenize template with escaped dollar sign", function()
  local tokens, err = parser.tokenize("`\\$not_expr`")
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  assert_eq(tokens[1].value.quasis[1], "$not_expr")
end)

test("parse template with escape", function()
  assert_parse_ok("`a\\nb`", {
    {
      type = ast.TYPE_EXPRESSION_STATEMENT,
      expression = {
        type = ast.TYPE_TEMPLATE_LITERAL,
        quasis = {
          { type = "TemplateElement", value = "a\nb", tail = true },
        },
        expressions = {},
      },
    },
  })
end)

test("parse template literal with interpolation", function()
  assert_parse_ok("`hello ${name}`", {
    {
      type = ast.TYPE_EXPRESSION_STATEMENT,
      expression = {
        type = ast.TYPE_TEMPLATE_LITERAL,
        quasis = {
          { type = "TemplateElement", value = "hello ", tail = false },
          { type = "TemplateElement", value = "", tail = true },
        },
        expressions = {
          { type = ast.TYPE_IDENTIFIER, name = "name" },
        },
      },
    },
  })
end)
