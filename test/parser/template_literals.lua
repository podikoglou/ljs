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
