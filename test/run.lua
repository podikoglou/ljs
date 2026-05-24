local T = require("test.ljs_test")
if arg and arg[1] == "-v" then
  T.set_verbose(true)
end

local function describe(name, mod)
  T.describe(name, function()
    require(mod)
  end)
end

describe("parser/tokenizer", "test.parser.tokenizer")
describe("parser/expressions", "test.parser.expressions")
describe("parser/statements", "test.parser.statements")
describe("parser/objects", "test.parser.objects")
describe("parser/typeof", "test.parser.typeof")
describe("parser/delete", "test.parser.delete")
describe("parser/bitwise", "test.parser.bitwise")
describe("parser/ternary", "test.parser.ternary")
describe("parser/switch", "test.parser.switch")
describe("parser/for_loops", "test.parser.for_loops")
describe("parser/do_while", "test.parser.do_while")
describe("parser/in_operator", "test.parser.in_operator")
describe("parser/class", "test.parser.class")
describe("parser/constructors", "test.parser.constructors")
describe("parser/location", "test.parser.location")
describe("parser/integration", "test.parser.integration")
describe("parser/this_expression", "test.parser.this_expression")
describe("parser/error_handling", "test.parser.error_handling")
describe("parser/member_literals", "test.parser.member_literals")

describe("transpile/basics", "test.transpile.basics")
describe("transpile/control_flow", "test.transpile.control_flow")
describe("transpile/objects_arrays", "test.transpile.objects_arrays")
describe("transpile/typeof", "test.transpile.typeof")
describe("transpile/delete", "test.transpile.delete")
describe("transpile/class", "test.transpile.class")
describe("transpile/constructors", "test.transpile.constructors")
describe("transpile/update", "test.transpile.update")
describe("transpile/this_binding", "test.transpile.this_binding")
describe("transpile/prototypes", "test.transpile.prototypes")
describe("transpile/bitwise", "test.transpile.bitwise")
describe("transpile/ternary", "test.transpile.ternary")
describe("transpile/exceptions", "test.transpile.exceptions")
describe("transpile/do_while", "test.transpile.do_while")
describe("transpile/in_operator", "test.transpile.in_operator")
describe("transpile/switch", "test.transpile.switch")
describe("transpile/integration", "test.transpile.integration")
describe("transpile/function_prototype", "test.transpile.function_prototype")
describe("transpile/object_prototype", "test.transpile.object_prototype")
describe("transpile/array_prototype", "test.transpile.array_prototype")
describe("transpile/function_objects", "test.transpile.function_objects")
describe("transpile/continue", "test.transpile.continue")
describe("transpile/member_literals", "test.transpile.member_literals")

describe("codegen", "test.codegen")

describe("public_api", "test.public_api")

T.describe("runtime/array", function()
  local ok, err = pcall(require, "test.runtime.array")
  if not ok then
    print(string.format("  \27[33m⚠\27[0m runtime/array: %s", tostring(err):match("^[^\n]*")))
  end
end)

T.describe("runtime/error", function()
  local ok, err = pcall(require, "test.runtime.error")
  if not ok then
    print(string.format("  \27[33m⚠\27[0m runtime/error: %s", tostring(err):match("^[^\n]*")))
  end
end)

T.describe("runtime/json", function()
  local ok, err = pcall(require, "test.runtime.json")
  if not ok then
    print(string.format("  \27[33m⚠\27[0m runtime/json: %s", tostring(err):match("^[^\n]*")))
  end
end)

T.describe("runtime/math", function()
  local ok, err = pcall(require, "test.runtime.math")
  if not ok then
    print(string.format("  \27[33m⚠\27[0m runtime/math: %s", tostring(err):match("^[^\n]*")))
  end
end)

T.describe("runtime/console", function()
  local ok, err = pcall(require, "test.runtime.console")
  if not ok then
    print(string.format("  \27[33m⚠\27[0m runtime/console: %s", tostring(err):match("^[^\n]*")))
  end
end)

T.summary()
