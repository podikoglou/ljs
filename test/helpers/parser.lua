-- Parser test helpers module
local ljs = require("ljs_parser")
local T = require("ljs_test")  -- ljs_test is at root

local test, assert_eq, assert_table_eq = T.test, T.assert_eq, T.assert_table_eq

local function assert_parse_ok(source, expected_body, msg)
  local ast, err = ljs.parse(source)
  if not ast then
    error(string.format("%s: parse failed: %s", msg or source, tostring(err)))
  end
  assert_table_eq(ast, {type = "Program", body = expected_body}, msg or source)
end

local function assert_parse_fail(source, substr, msg)
  local ast, err = ljs.parse(source)
  if ast then
    error(string.format("%s: expected failure but got result", msg or source))
  end
  if substr and not string.find(tostring(err), substr, 1, true) then
    error(string.format("%s: expected error containing '%s', got '%s'", msg or source, substr, tostring(err)))
  end
end

local function tok(source, idx)
  local tokens, err = ljs.tokenize(source)
  if not tokens then error("tokenize failed: " .. tostring(err)) end
  return tokens[idx]
end

local function assert_tok(source, idx, ttype, tvalue, msg)
  local t = tok(source, idx)
  assert_eq(t.type, ttype, msg or ("token " .. idx .. " type"))
  if tvalue ~= nil then
    assert_eq(t.value, tvalue, msg or ("token " .. idx .. " value"))
  end
end

local function assert_tokenize_fail(source, substr, msg)
  local tokens, err = ljs.tokenize(source)
  if tokens then
    error(string.format("%s: expected failure but got tokens", msg or source))
  end
  if substr and not string.find(tostring(err), substr, 1, true) then
    error(string.format("%s: expected error containing '%s', got '%s'", msg or source, substr, tostring(err)))
  end
end

return {
  ljs = ljs,
  test = test,
  assert_eq = assert_eq,
  assert_table_eq = assert_table_eq,
  assert_parse_ok = assert_parse_ok,
  assert_parse_fail = assert_parse_fail,
  tok = tok,
  assert_tok = assert_tok,
  assert_tokenize_fail = assert_tokenize_fail,
}
