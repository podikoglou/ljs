package = "ljs"
version = "0.2.0-1"

source = {
  url = "git://github.com/podikoglou/ljs.git",
  tag = "v0.2.0",
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
    ["ljs.ast"] = "src/ljs/ast.lua",
    ["ljs.codegen"] = "src/ljs/codegen.lua",
    ["ljs.parser"] = "src/ljs/parser.lua",
    ["ljs.transpile"] = "src/ljs/transpile.lua",
    ["ljs.utf8"] = "src/ljs/utf8.lua",
    ["ljs.parser_dump"] = "src/ljs/parser_dump.lua",
    ["ljs.transpile_dump"] = "src/ljs/transpile_dump.lua",
    ["ljs.runtime.proto"] = "src/ljs/runtime/proto.lua",
    ["ljs.runtime.console"] = "src/ljs/runtime/console.lua",
    ["ljs.runtime.object"] = "src/ljs/runtime/object.lua",
    ["ljs.runtime.function"] = "src/ljs/runtime/function.lua",
    ["ljs.runtime.array"] = "src/ljs/runtime/array.lua",
    ["ljs.runtime.boolean"] = "src/ljs/runtime/boolean.lua",
    ["ljs.runtime.error"] = "src/ljs/runtime/error.lua",
    ["ljs.runtime.globals"] = "src/ljs/runtime/globals.lua",
    ["ljs.runtime.json"] = "src/ljs/runtime/json.lua",
    ["ljs.runtime.json_lib"] = "src/ljs/runtime/json_lib.lua",
    ["ljs.runtime.math"] = "src/ljs/runtime/math.lua",
    ["ljs.runtime.number"] = "src/ljs/runtime/number.lua",
    ["ljs.runtime.string"] = "src/ljs/runtime/string.lua",
  },
  install = {
    bin = {
      ["parser-dump"] = "bin/parser-dump",
      ["transpile-dump"] = "bin/transpile-dump",
    }
  }
}
