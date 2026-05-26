local T = require("test.ljs_test")
local P = require("test.helpers.parser")
local parser = require("ljs.parser")
local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq

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
