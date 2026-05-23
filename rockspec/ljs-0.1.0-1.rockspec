package = "ljs"
version = "0.1.0-1"

source = {
  url = "git://github.com/podikoglou/ljs.git",
  tag = "v0.1.0",
}

description = {
  summary = "Parse, transpile, and run JavaScript subsets in Lua",
  detailed = [[
    ljs provides Lua libraries that parse a well-defined subset of JavaScript
    into a Lua table-based AST and transpile it to Lua source code.
    Includes a tokenizer, parser, codegen, and runtime polyfills.
  ]],
  homepage = "https://github.com/podikoglou/ljs",
  license = "MIT",
}

dependencies = {
  "lua >= 5.2",
}

build = {
  type = "builtin",
  modules = {
    ["ljs"] = "src/ljs.lua",
    ["ljs.parser"] = "src/ljs/parser.lua",
    ["ljs.codegen"] = "src/ljs/codegen.lua",
    ["ljs.transpile"] = "src/ljs/transpile.lua",
    ["ljs.parser_dump"] = "src/ljs/parser_dump.lua",
    ["ljs.transpile_dump"] = "src/ljs/transpile_dump.lua",
    ["ljs.runtime.proto"] = "src/ljs/runtime/proto.lua",
    ["ljs.runtime.console"] = "src/ljs/runtime/console.lua",
    ["ljs.runtime.object"] = "src/ljs/runtime/object.lua",
    ["ljs.runtime.function"] = "src/ljs/runtime/function.lua",
    ["ljs.runtime.array"] = "src/ljs/runtime/array.lua",
  },
}
