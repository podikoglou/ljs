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

test("console.warn outputs to stderr with Warning: prefix", function()
  local out = capture_stderr(function()
    exec_js("console.warn('caution');")
  end)
  assert_eq(out, "Warning: caution\n")
end)

test("console.warn joins multiple args with space after prefix", function()
  local out = capture_stderr(function()
    exec_js("console.warn('a', 'b');")
  end)
  assert_eq(out, "Warning: a b\n")
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
  assert_eq(out, "{ a: [ 1 ], b: { c: 2 } }\n")
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
