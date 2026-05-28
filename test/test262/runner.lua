local fm = require("test.test262.frontmatter")
local ljs = require("ljs.transpile")

local M = {}

local UNSUPPORTED_FEATURES = {
  ["async-iteration"] = true,
  ["async-functions"] = true,
  ["async"] = true,
  ["generators"] = true,
  ["BigInt"] = true,
  ["Symbol"] = true,
  ["Symbol.iterator"] = true,
  ["Symbol.asyncIterator"] = true,
  ["Symbol.matchAll"] = true,
  ["Symbol.match"] = true,
  ["Symbol.replace"] = true,
  ["Symbol.search"] = true,
  ["Symbol.split"] = true,
  ["Symbol.species"] = true,
  ["Symbol.toPrimitive"] = true,
  ["Symbol.toStringTag"] = true,
  ["Symbol.unscopables"] = true,
  ["regexp-named-groups"] = true,
  ["regexp-unicode-property-escapes"] = true,
  ["regexp-v-flag"] = true,
  ["regexp-modifiers"] = true,
  ["regexp-dotall"] = true,
  ["regexp-lookbehind"] = true,
  ["regexp-backwards-compat"] = true,
  ["Promise"] = true,
  ["Promise.prototype.finally"] = true,
  ["TypedArray"] = true,
  ["Proxy"] = true,
  ["Reflect"] = true,
  ["Reflect.construct"] = true,
  ["Map"] = true,
  ["Set"] = true,
  ["set-methods"] = true,
  ["WeakMap"] = true,
  ["WeakSet"] = true,
  ["WeakRef"] = true,
  ["FinalizationRegistry"] = true,
  ["SharedArrayBuffer"] = true,
  ["Atomics"] = true,
  ["DataView"] = true,
  ["ArrayBuffer"] = true,
  ["resizable-arraybuffer"] = true,
  ["Temporal"] = true,
  ["ShadowRealm"] = true,
  ["import-assertions"] = true,
  ["dynamic-import"] = true,
  ["import.meta"] = true,
  ["source-phase-imports"] = true,
  ["source-phase-imports-module-source"] = true,
  ["explicit-resource-management"] = true,
  ["regexp-flag-escaped"] = true,
  ["new.target"] = true,
  ["object-rest"] = true,
  ["object-spread"] = true,
  ["json-parse-with-source"] = true,
  ["uint8array-base64"] = true,
  ["Intl"] = true,
  ["IsHTMLDDA"] = true,
  ["tail-call-optimization"] = true,
  ["__proto__"] = true,
  ["ComputedPropertyNames"] = true,
  ["ComputedPropertyNamesWithAssignment"] = true,
  ["change-array-by-copy"] = true,
  ["array-find-from-last"] = true,
  ["array-grouping"] = true,
  ["iterator-helpers"] = true,
  ["class-fields-public"] = true,
  ["class-fields-private"] = true,
  ["class-fields-accessor"] = true,
  ["class-static-methods-private"] = true,
  ["class-methods-private"] = true,
  ["class-static-block"] = true,
  ["class-static-fields-public"] = true,
  ["class-static-fields-private"] = true,
  ["class"] = true,
  ["decorators"] = true,
  ["private-in"] = true,
  ["top-level-await"] = true,
  ["Error.isError"] = true,
  ["Error.cause"] = true,
  ["AggregateError"] = true,
  [" DisposableStack"] = true,
  ["AsyncDisposableStack"] = true,
  ["SuppressedError"] = true,
  ["using"] = true,
  ["await-using"] = true,
}

local UNSUPPORTED_INCLUDES = {
  ["asyncHelpers.js"] = true,
  ["atomicsHelper.js"] = true,
  ["detachArrayBuffer.js"] = true,
  ["proxyTrapsHelper.js"] = true,
  ["regExpUtils.js"] = true,
  ["resizableArrayBufferUtils.js"] = true,
  ["testAtomics.js"] = true,
  ["testTypedArray.js"] = true,
  ["testIntl.js"] = true,
  ["temporalHelpers.js"] = true,
  ["nativeFunctionMatcher.js"] = true,
  ["iteratorZipUtils.js"] = true,
  ["wellKnownIntrinsicObjects.js"] = true,
}

local HARNESS_CACHE = {}

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "cannot open: " .. path
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function load_harness(test262_dir, name)
  if HARNESS_CACHE[name] then
    return HARNESS_CACHE[name]
  end
  local path = test262_dir .. "/harness/" .. name
  local content, err = read_file(path)
  if not content then
    return nil, err
  end
  HARNESS_CACHE[name] = content
  return content
end

local SUITES = {
  "test/language/arguments-object",
  "test/language/asi",
  "test/language/block-scope",
  "test/language/comments",
  "test/language/destructuring",
  "test/language/directive-prologue",
  "test/language/eval-code",
  "test/language/expressions/addition",
  "test/language/expressions/array",
  "test/language/expressions/arrow-function",
  "test/language/expressions/assignment",
  "test/language/expressions/bitwise-and",
  "test/language/expressions/bitwise-not",
  "test/language/expressions/bitwise-or",
  "test/language/expressions/bitwise-xor",
  "test/language/expressions/call",
  "test/language/expressions/coalesce",
  "test/language/expressions/comma",
  "test/language/expressions/compound-assignment",
  "test/language/expressions/concatenation",
  "test/language/expressions/conditional",
  "test/language/expressions/delete",
  "test/language/expressions/division",
  "test/language/expressions/does-not-equals",
  "test/language/expressions/equals",
  "test/language/expressions/exponentiation",
  "test/language/expressions/function",
  "test/language/expressions/greater-than",
  "test/language/expressions/greater-than-or-equal",
  "test/language/expressions/grouping",
  "test/language/expressions/in",
  "test/language/expressions/instanceof",
  "test/language/expressions/left-shift",
  "test/language/expressions/less-than",
  "test/language/expressions/less-than-or-equal",
  "test/language/expressions/logical-and",
  "test/language/expressions/logical-assignment",
  "test/language/expressions/logical-not",
  "test/language/expressions/logical-or",
  "test/language/expressions/member-expression",
  "test/language/expressions/modulus",
  "test/language/expressions/multiplication",
  "test/language/expressions/new",
  "test/language/expressions/object",
  "test/language/expressions/postfix-decrement",
  "test/language/expressions/postfix-increment",
  "test/language/expressions/prefix-decrement",
  "test/language/expressions/prefix-increment",
  "test/language/expressions/property-accessors",
  "test/language/expressions/relational",
  "test/language/expressions/right-shift",
  "test/language/expressions/strict-does-not-equals",
  "test/language/expressions/strict-equals",
  "test/language/expressions/subtraction",
  "test/language/expressions/super",
  "test/language/expressions/template-literal",
  "test/language/expressions/this",
  "test/language/expressions/typeof",
  "test/language/expressions/unary-minus",
  "test/language/expressions/unary-plus",
  "test/language/expressions/unsigned-right-shift",
  "test/language/expressions/void",
  "test/language/function-code",
  "test/language/identifiers",
  "test/language/literals",
  "test/language/punctuators",
  "test/language/reserved-words",
  "test/language/rest-parameters",
  "test/language/source-text",
  "test/language/statementList",
  "test/language/statements/block",
  "test/language/statements/break",
  "test/language/statements/continue",
  "test/language/statements/do-while",
  "test/language/statements/empty",
  "test/language/statements/expression",
  "test/language/statements/for",
  "test/language/statements/for-in",
  "test/language/statements/for-of",
  "test/language/statements/function",
  "test/language/statements/if",
  "test/language/statements/labeled",
  "test/language/statements/return",
  "test/language/statements/switch",
  "test/language/statements/throw",
  "test/language/statements/try",
  "test/language/statements/variable",
  "test/language/statements/while",
  "test/language/types",
  "test/language/white-space",
  "test/language/line-terminators",
}

local function should_skip(meta)
  if meta.flag_set["module"] then
    return true, "module"
  end
  if meta.flag_set["async"] then
    return true, "async"
  end
  if meta.flag_set["raw"] then
    return true, "raw"
  end
  if meta.flag_set["onlyStrict"] then
    return true, "onlyStrict"
  end

  for _, feat in ipairs(meta.features) do
    if UNSUPPORTED_FEATURES[feat] then
      return true, "feature:" .. feat
    end
  end

  for _, inc in ipairs(meta.includes) do
    if UNSUPPORTED_INCLUDES[inc] then
      return true, "include:" .. inc
    end
  end

  return false
end

local function discover_tests(test262_dir, suite)
  local tests = {}
  local dir = test262_dir .. "/" .. suite
  local p = io.popen(string.format('find "%s" -name "*.js" -not -name "*_FIXTURE*" -sort 2>/dev/null', dir))
  if not p then
    return tests
  end
  for path in p:lines() do
    local rel = path:sub(#test262_dir + 2)
    table.insert(tests, { path = path, rel = rel })
  end
  p:close()
  return tests
end

local function build_test_js(test262_dir, meta, test_source)
  local parts = {}

  local sta = load_harness(test262_dir, "sta.js")
  if sta then
    table.insert(parts, sta)
  end

  local assert_h = load_harness(test262_dir, "assert.js")
  if assert_h then
    table.insert(parts, assert_h)
  end

  for _, inc in ipairs(meta.includes) do
    local content = load_harness(test262_dir, inc)
    if content then
      table.insert(parts, content)
    end
  end

  table.insert(parts, test_source)

  return table.concat(parts, "\n")
end

local function run_single_test(test262_dir, test)
  local source, err = read_file(test.path)
  if not source then
    return "error", "read: " .. err
  end

  local meta = fm.parse(source)

  local skip, reason = should_skip(meta)
  if skip then
    return "skip", reason
  end

  local js_code = build_test_js(test262_dir, meta, source)

  local lua_code, parse_err = ljs.transpile_source(js_code)
  if not lua_code then
    if meta.negative and meta.negative.phase == "parse" then
      return "pass", nil
    end
    return "parse_error", tostring(parse_err.message or parse_err)
  end

  if meta.negative and meta.negative.phase == "parse" then
    return "fail", "expected parse error but transpilation succeeded"
  end

  local fn, load_err = load(lua_code, test.rel)
  if not fn then
    return "error", "load: " .. tostring(load_err)
  end

  local ok, err = pcall(fn)
  if ok then
    if meta.negative then
      return "fail", "expected " .. meta.negative.type .. " but no error thrown"
    end
    return "pass", nil
  else
    if meta.negative then
      local err_str = tostring(err)
      if err_str:find(meta.negative.type) then
        return "pass", nil
      end
      return "fail", "expected " .. meta.negative.type .. " but got: " .. err_str:match("^[^\n]*")
    end
    return "fail", tostring(err):match("^[^\n]*")
  end
end

local function fmt_status(status)
  local colors = {
    pass = "\27[32m",
    fail = "\27[31m",
    skip = "\27[33m",
    parse_error = "\27[35m",
    error = "\27[35m",
  }
  local labels = {
    pass = "PASS",
    fail = "FAIL",
    skip = "SKIP",
    parse_error = "PARSE",
    error = "ERROR",
  }
  return (colors[status] or "") .. (labels[status] or status) .. "\27[0m"
end

function M.run(opts)
  opts = opts or {}

  local test262_dir = opts.test262_dir or "test262"
  local suites = opts.suites or SUITES
  local verbose = opts.verbose or false
  local max_fail = opts.max_fail or 0

  local total_pass = 0
  local total_fail = 0
  local total_skip = 0
  local total_parse_error = 0
  local total_error = 0
  local total_tests = 0

  print("test262 conformance suite\n")

  for _, suite in ipairs(suites) do
    local suite_pass = 0
    local suite_fail = 0
    local suite_skip = 0
    local suite_parse_error = 0
    local suite_error = 0
    local suite_failures = {}

    local tests = discover_tests(test262_dir, suite)
    if #tests == 0 then
      goto next_suite
    end

    for _, test in ipairs(tests) do
      total_tests = total_tests + 1
      local status, detail = run_single_test(test262_dir, test)

      if status == "pass" then
        suite_pass = suite_pass + 1
      elseif status == "skip" then
        suite_skip = suite_skip + 1
      elseif status == "parse_error" then
        suite_parse_error = suite_parse_error + 1
        table.insert(suite_failures, {
          rel = test.rel,
          status = status,
          detail = detail,
        })
      elseif status == "error" then
        suite_error = suite_error + 1
        table.insert(suite_failures, {
          rel = test.rel,
          status = status,
          detail = detail,
        })
      else
        suite_fail = suite_fail + 1
        table.insert(suite_failures, {
          rel = test.rel,
          status = status,
          detail = detail,
        })
      end

      if verbose then
        io.write(string.format("  %s %s\n", fmt_status(status), test.rel))
        if detail and status ~= "pass" and status ~= "skip" then
          io.write(string.format("    %s\n", detail))
        end
      end
    end

    total_pass = total_pass + suite_pass
    total_fail = total_fail + suite_fail
    total_skip = total_skip + suite_skip
    total_parse_error = total_parse_error + suite_parse_error
    total_error = total_error + suite_error

    local label = suite:gsub("^test/", "")
    local problems = suite_fail + suite_parse_error + suite_error
    if problems == 0 then
      print(string.format("  \27[32m✓\27[0m %s (%d passed, %d skipped)", label, suite_pass, suite_skip))
    else
      print(string.format(
        "  \27[31m✗\27[0m %s (%d pass, %d fail, %d parse, %d err, %d skip)",
        label, suite_pass, suite_fail, suite_parse_error, suite_error, suite_skip
      ))
      if not verbose then
        for _, f in ipairs(suite_failures) do
          io.write(string.format("    %s %s\n", fmt_status(f.status), f.rel))
          if f.detail then
            io.write(string.format("      %s\n", f.detail))
          end
        end
      end
    end

    if max_fail > 0 and (total_fail + total_parse_error + total_error) >= max_fail then
      print("\n  (stopped early: max failures reached)")
      break
    end

    ::next_suite::
  end

  local total_run = total_pass + total_fail + total_parse_error + total_error
  print("")
  print(string.format(
    "Results: \27[32m%d pass\27[0m, \27[31m%d fail\27[0m, \27[35m%d parse error\27[0m, \27[35m%d load error\27[0m, \27[33m%d skip\27[0m / %d total",
    total_pass, total_fail, total_parse_error, total_error, total_skip, total_tests
  ))
  if total_run > 0 then
    print(string.format(
      "Conformance: %.1f%% (%d/%d)",
      total_pass / total_run * 100, total_pass, total_run
    ))
  end
end

M.SUITES = SUITES
M.UNSUPPORTED_FEATURES = UNSUPPORTED_FEATURES
M.UNSUPPORTED_INCLUDES = UNSUPPORTED_INCLUDES

return M
