local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local exec_js = R.exec_js

local function capture_stdout(fn)
  local old = io.stdout
  local tmp = io.tmpfile()
  io.stdout = tmp
  fn()
  tmp:seek("set")
  local out = tmp:read("*a")
  tmp:close()
  io.stdout = old
  return out
end

local function capture_stderr(fn)
  local old = io.stderr
  local tmp = io.tmpfile()
  io.stderr = tmp
  fn()
  tmp:seek("set")
  local out = tmp:read("*a")
  tmp:close()
  io.stderr = old
  return out
end

-- ============================================================================
-- console.log
-- ============================================================================

test("console.log outputs string to stdout", function()
  local out = capture_stdout(function()
    exec_js("console.log('hello');")
  end)
  assert_eq(out, "hello\n")
end)

test("console.log joins multiple args with space", function()
  local out = capture_stdout(function()
    exec_js("console.log('a', 'b', 'c');")
  end)
  assert_eq(out, "a b c\n")
end)

-- ============================================================================
-- console.error
-- ============================================================================

test("console.error outputs to stderr", function()
  local out = capture_stderr(function()
    exec_js("console.error('fail');")
  end)
  assert_eq(out, "fail\n")
end)

test("console.error joins multiple args with space", function()
  local out = capture_stderr(function()
    exec_js("console.error('a', 'b');")
  end)
  assert_eq(out, "a b\n")
end)

test("console.error does not write to stdout", function()
  local out = capture_stdout(function()
    capture_stderr(function()
      exec_js("console.error('fail');")
    end)
  end)
  assert_eq(out, "")
end)

-- ============================================================================
-- console.warn
-- ============================================================================

test("console.warn outputs to stderr without Warning: prefix", function()
  local out = capture_stderr(function()
    exec_js("console.warn('caution');")
  end)
  assert_eq(out, "caution\n")
end)

test("console.warn joins multiple args with space", function()
  local out = capture_stderr(function()
    exec_js("console.warn('a', 'b');")
  end)
  assert_eq(out, "a b\n")
end)

test("console.warn does not write to stdout", function()
  local out = capture_stdout(function()
    capture_stderr(function()
      exec_js("console.warn('caution');")
    end)
  end)
  assert_eq(out, "")
end)

-- ============================================================================
-- console.info
-- ============================================================================

test("console.info outputs to stdout like log", function()
  local out = capture_stdout(function()
    exec_js("console.info('hello');")
  end)
  assert_eq(out, "hello\n")
end)

test("console.info joins multiple args with space", function()
  local out = capture_stdout(function()
    exec_js("console.info('a', 'b');")
  end)
  assert_eq(out, "a b\n")
end)

-- ============================================================================
-- console.log inspect formatting
-- ============================================================================

test("console.log formats flat array", function()
  local out = capture_stdout(function()
    exec_js("console.log([1, 2, 3]);")
  end)
  assert_eq(out, "[ 1, 2, 3 ]\n")
end)

test("console.log formats empty array", function()
  local out = capture_stdout(function()
    exec_js("console.log([]);")
  end)
  assert_eq(out, "[]\n")
end)

test("console.log formats flat object", function()
  local out = capture_stdout(function()
    exec_js("console.log({x: 1});")
  end)
  assert_eq(out, "{ x: 1 }\n")
end)

test("console.log formats empty object", function()
  local out = capture_stdout(function()
    exec_js("console.log({});")
  end)
  assert_eq(out, "{}\n")
end)

test("console.log formats nested array", function()
  local out = capture_stdout(function()
    exec_js("console.log([1, [2, 3]]);")
  end)
  assert_eq(out, "[ 1, [ 2, 3 ] ]\n")
end)

test("console.log formats nested object", function()
  local out = capture_stdout(function()
    exec_js("console.log({a: [1], b: {c: 2}});")
  end)
  local valid = out == "{ a: [ 1 ], b: { c: 2 } }\n" or out == "{ b: { c: 2 }, a: [ 1 ] }\n"
  assert(valid, "unexpected output: " .. out)
end)

test("console.log formats mixed args", function()
  local out = capture_stdout(function()
    exec_js("console.log('hello', [1, 2], 42);")
  end)
  assert_eq(out, "hello [ 1, 2 ] 42\n")
end)

test("console.log formats null", function()
  local out = capture_stdout(function()
    exec_js("console.log(null);")
  end)
  assert_eq(out, "null\n")
end)

test("console.log formats undefined", function()
  local out = capture_stdout(function()
    exec_js("console.log(undefined);")
  end)
  assert_eq(out, "undefined\n")
end)

test("console.log formats array with null and undefined", function()
  local out = capture_stdout(function()
    exec_js("console.log([null, undefined]);")
  end)
  assert_eq(out, "[ null, undefined ]\n")
end)

test("console.log quotes strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js("console.log(['a']);")
  end)
  assert_eq(out, "[ 'a' ]\n")
end)

test("console.log quotes string values inside objects", function()
  local out = capture_stdout(function()
    exec_js("console.log({x: 'a'});")
  end)
  assert_eq(out, "{ x: 'a' }\n")
end)

test("console.log does not quote top-level strings", function()
  local out = capture_stdout(function()
    exec_js("console.log('hi');")
  end)
  assert_eq(out, "hi\n")
end)

test("console.log formats anonymous function without colon", function()
  local out = capture_stdout(function()
    exec_js("console.log(function() {});")
  end)
  assert_eq(out, "[Function (anonymous)]\n")
end)

test("console.log formats named function with colon", function()
  local out = capture_stdout(function()
    exec_js("var f = function myFunc() {}; console.log(f);")
  end)
  assert_eq(out, "[Function: myFunc]\n")
end)

test("console.log formats Error using toString", function()
  local out = capture_stdout(function()
    exec_js("console.log(new Error('msg'));")
  end)
  assert_eq(out, "Error: msg\n")
end)

test("console.log formats TypeError using toString", function()
  local out = capture_stdout(function()
    exec_js("console.log(new TypeError('tmsg'));")
  end)
  assert_eq(out, "TypeError: tmsg\n")
end)

test("console.log formats Error inside array", function()
  local out = capture_stdout(function()
    exec_js("console.log([new Error('x')]);")
  end)
  assert_eq(out, "[ Error: x ]\n")
end)

test("console.log formats Error inside object", function()
  local out = capture_stdout(function()
    exec_js("console.log({e: new Error('y')});")
  end)
  assert_eq(out, "{ e: Error: y }\n")
end)

test("console.log escapes single quotes in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["it's"]);]])
  end)
  assert_eq(out, '[ "it\'s" ]\n')
end)

test("console.log escapes backslash in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["back\\slash"]);]])
  end)
  assert_eq(out, "[ 'back\\\\slash' ]\n")
end)

test("console.log escapes tab in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["tab\there"]);]])
  end)
  assert_eq(out, "[ 'tab\\there' ]\n")
end)

test("console.log escapes newline in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["multi\nline"]);]])
  end)
  assert_eq(out, "[ 'multi\\nline' ]\n")
end)

test("console.log escapes carriage return in strings", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["a\rb"]);]])
  end)
  assert_eq(out, "[ 'a\\rb' ]\n")
end)

test("console.log escapes backspace in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["a\bb"]);]])
  end)
  assert_eq(out, "[ 'a\\bb' ]\n")
end)

test("console.log escapes form feed in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["a\fb"]);]])
  end)
  assert_eq(out, "[ 'a\\fb' ]\n")
end)

test("console.log escapes backspace via hex escape in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["\x08f"]);]])
  end)
  assert_eq(out, "[ '\\bf' ]\n")
end)

test("console.log escapes form feed via hex escape in strings inside arrays", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["\x0cf"]);]])
  end)
  assert_eq(out, "[ '\\ff' ]\n")
end)

test("console.log uses backtick quotes when string has both quotes", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["it's \"here\""]);]])
  end)
  assert_eq(out, '[ `it\'s "here"` ]\n')
end)

test("console.log escapes backticks in backtick-quoted strings", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["it's \"he\x60re\x60\""]);]])
  end)
  assert_eq(out, '[ `it\'s "he\\`re\\`"` ]\n')
end)

test("console.log escapes backtick when string has single, double, and backtick", function()
  local out = capture_stdout(function()
    exec_js([[console.log(["a'b\"c`d"]);]])
  end)
  assert_eq(out, "[ `a'b\"c\\`d` ]\n")
end)

test("console.log quotes numeric string keys in objects", function()
  local out = capture_stdout(function()
    exec_js("var o = {}; o[0] = 'a'; o[1] = 'b'; o.name = 'test'; console.log(o);")
  end)
  assert_eq(out, "{ '0': 'a', '1': 'b', name: 'test' }\n")
end)

test("console.log shows numeric keys from indexed assignment", function()
  local out = capture_stdout(function()
    exec_js("var o = {name: 'test'}; o[0] = 'zero'; console.log(o);")
  end)
  assert_eq(out, "{ '0': 'zero', name: 'test' }\n")
end)

test("console.log numbers circular refs", function()
  local out = capture_stdout(function()
    exec_js("var a = {}; a.self = a; console.log(a);")
  end)
  assert_eq(out, "<ref *1> { self: [Circular *1] }\n")
end)

test("console.log numbers multiple circular refs", function()
  local out = capture_stdout(function()
    exec_js("var a = {}; var b = {}; a.ref = b; b.ref = a; console.log(a, b);")
  end)
  assert_eq(out, "<ref *1> { ref: { ref: [Circular *1] } } <ref *2> { ref: [Circular *1] }\n")
end)
