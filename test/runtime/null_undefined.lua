local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq = R.test, R.assert_eq
local eval_js, exec_js = R.eval_js, R.exec_js

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

-- ============================================================================
-- typeof null / typeof undefined (§13.5.3)
-- ============================================================================

test('typeof null === "object"', function()
  assert_eq(eval_js("typeof null"), "object")
end)

test('typeof undefined === "undefined"', function()
  assert_eq(eval_js("typeof undefined"), "undefined")
end)

-- ============================================================================
-- Strict equality (=== / !==)
-- ============================================================================

test("null === null → true", function()
  assert_eq(eval_js("null === null"), true)
end)

test("undefined === undefined → true", function()
  assert_eq(eval_js("undefined === undefined"), true)
end)

test("null === undefined → false", function()
  assert_eq(eval_js("null === undefined"), false)
end)

test("undefined === null → false", function()
  assert_eq(eval_js("undefined === null"), false)
end)

test("null !== undefined → true", function()
  assert_eq(eval_js("null !== undefined"), true)
end)

-- ============================================================================
-- Loose equality (== / !=) — requires #68
-- ============================================================================

test("null == undefined → true", function()
  assert_eq(eval_js("null == undefined"), true)
end)

test("undefined == null → true", function()
  assert_eq(eval_js("undefined == null"), true)
end)

test("null == null → true", function()
  assert_eq(eval_js("null == null"), true)
end)

test("undefined == undefined → true", function()
  assert_eq(eval_js("undefined == undefined"), true)
end)

test("null != undefined → false", function()
  assert_eq(eval_js("null != undefined"), false)
end)

-- ============================================================================
-- ToNumber coercion via + (§7.1.4)
-- ============================================================================

test("null + 1 → 1 (null coerces to +0)", function()
  assert_eq(eval_js("null + 1"), 1)
end)

test("undefined + 1 → NaN", function()
  local r = eval_js("undefined + 1")
  assert(r ~= r, "expected NaN")
end)

test("null + null → 0", function()
  assert_eq(eval_js("null + null"), 0)
end)

test("null + undefined → NaN", function()
  local r = eval_js("null + undefined")
  assert(r ~= r, "expected NaN")
end)

-- ============================================================================
-- String coercion via + (§7.1.18)
-- ============================================================================

test('null + "" → "null"', function()
  assert_eq(eval_js('null + ""'), "null")
end)

test('undefined + "" → "undefined"', function()
  assert_eq(eval_js('undefined + ""'), "undefined")
end)

test('"x" + null → "xnull"', function()
  assert_eq(eval_js('"x" + null'), "xnull")
end)

test('"x" + undefined → "xundefined"', function()
  assert_eq(eval_js('"x" + undefined'), "xundefined")
end)

-- ============================================================================
-- Console output
-- ============================================================================

test("console.log(null) prints 'null'", function()
  local out = capture_stdout(function()
    exec_js("console.log(null);")
  end)
  assert_eq(out, "null\n")
end)

test("console.log(undefined) prints 'undefined'", function()
  local out = capture_stdout(function()
    exec_js("console.log(undefined);")
  end)
  assert_eq(out, "undefined\n")
end)

test("console.log(null, undefined) prints 'null\\tundefined'", function()
  local out = capture_stdout(function()
    exec_js("console.log(null, undefined);")
  end)
  assert_eq(out, "null\tundefined\n")
end)

-- ============================================================================
-- JSON.stringify (§25.5.4.2)
-- ============================================================================

test("JSON.stringify(null) → 'null'", function()
  assert_eq(eval_js("JSON.stringify(null)"), "null")
end)

test("JSON.stringify({a: undefined}) → '{}'", function()
  assert_eq(exec_js("return JSON.stringify({a: undefined});"), "{}")
end)

test("JSON.stringify([null]) → '[null]'", function()
  assert_eq(eval_js("JSON.stringify([null])"), "[null]")
end)

-- ============================================================================
-- TypeError on member call (§7.2.1)
-- ============================================================================

test("null.toString() throws TypeError", function()
  local ok, _ = pcall(eval_js, "null.toString()")
  assert(not ok, "expected TypeError")
end)

test("undefined.toString() throws TypeError", function()
  local ok, _ = pcall(eval_js, "undefined.toString()")
  assert(not ok, "expected TypeError")
end)

-- ============================================================================
-- Identity: null and undefined are distinct
-- ============================================================================

test("null === null ? 'yes' : 'no' → 'yes'", function()
  assert_eq(eval_js("null === null ? 'yes' : 'no'"), "yes")
end)

test("undefined === undefined ? 'yes' : 'no' → 'yes'", function()
  assert_eq(eval_js("undefined === undefined ? 'yes' : 'no'"), "yes")
end)

-- ============================================================================
-- hasOwnProperty: null values preserved in tables
-- ============================================================================

test("{a: null}.hasOwnProperty('a') → true", function()
  assert_eq(exec_js("var o = {a: null}; return o.hasOwnProperty('a');"), true)
end)

-- ============================================================================
-- Storable undefined: _ljs_undefined sentinel is stored in tables
-- ============================================================================

test("{a: undefined}.hasOwnProperty('a') → true", function()
  assert_eq(exec_js("var o = {a: undefined}; return o.hasOwnProperty('a');"), true)
end)

test('"x" in {x: undefined} → true', function()
  assert_eq(exec_js('return "x" in {x: undefined};'), true)
end)

test('"x" in {x: undefined} works where missing key returns false', function()
  assert_eq(exec_js('return "y" in {x: undefined};'), false)
end)

test("0 in [undefined] → true (sentinel stored, not hole)", function()
  assert_eq(exec_js("return 0 in [undefined];"), true)
end)

test("1 in [undefined, undefined] → true", function()
  assert_eq(exec_js("return 1 in [undefined, undefined];"), true)
end)

-- ============================================================================
-- Conditional: undefined is falsy
-- ============================================================================

test("undefined is falsy", function()
  assert_eq(eval_js("undefined ? 'truthy' : 'falsy'"), "falsy")
end)

-- ============================================================================
-- Phase 3: Boundary Normalization — property reads return _ljs_undefined
-- ============================================================================

test("obj.nonexistent === undefined (property miss returns undefined)", function()
  assert_eq(exec_js("var obj = {a: 1}; return obj.nonexistent === undefined;"), true)
end)

test("obj.nonexistent == null (undefined == null)", function()
  assert_eq(exec_js("var obj = {}; return obj.nonexistent == null;"), true)
end)

test("typeof obj.nonexistent === 'undefined'", function()
  assert_eq(eval_js("typeof ({}).nonexistent"), "undefined")
end)

test("missing property stored in object creates present key", function()
  assert_eq(exec_js([[
    var obj1 = {a: 1};
    var obj2 = {};
    obj2.x = obj1.nonexistent;
    return "x" in obj2;
  ]]), true)
end)

test("arr[999] === undefined for out-of-bounds", function()
  assert_eq(exec_js("var arr = [1, 2, 3]; return arr[10] === undefined;"), true)
end)

test("Object.create(null).nonexistent === undefined", function()
  assert_eq(exec_js("var obj = Object.create(null); return obj.nonexistent === undefined;"), true)
end)

test("Object.create(null) still stores/retrieves own properties", function()
  assert_eq(exec_js("var obj = Object.create(null); obj.x = 1; return obj.x;"), 1)
end)

-- ============================================================================
-- Phase 3: Missing function args normalized to _ljs_undefined
-- ============================================================================

test("missing arg === undefined (param normalization)", function()
  assert_eq(exec_js("function f(a, b) { return b === undefined; } return f(1);"), true)
end)

test("missing arg stored in array doesn't create hole", function()
  assert_eq(exec_js([[
    var arr = [];
    function pushIt(x) { arr.push(x); }
    pushIt();
    return 0 in arr;
  ]]), true)
end)

-- ============================================================================
-- Phase 3: Default params work with undefined
-- ============================================================================

test("default param triggers for missing arg", function()
  assert_eq(exec_js("function f(a = 42) { return a; } return f();"), 42)
end)

test("default param triggers for explicit undefined", function()
  assert_eq(exec_js("function f(a = 42) { return a; } return f(undefined);"), 42)
end)

test("default param does NOT trigger for null", function()
  assert_eq(exec_js("function f(a = 42) { return a === null; } return f(null);"), true)
end)

test("default param with prior regular params", function()
  assert_eq(exec_js("function f(a, b = 10) { return a + b; } return f(5);"), 15)
end)

-- ============================================================================
-- Phase 3: Uninitialized variable declarations
-- ============================================================================

test("var x; x === undefined", function()
  assert_eq(exec_js("var x; return x === undefined;"), true)
end)

test("let y; y === undefined", function()
  assert_eq(exec_js("let y; return y === undefined;"), true)
end)

test("uninitialized var stored in array creates present element", function()
  assert_eq(exec_js([[
    var arr = [];
    var x;
    arr.push(x);
    return 0 in arr;
  ]]), true)
end)

-- ============================================================================
-- Phase 3: Bare return returns undefined
-- ============================================================================

test("bare return; returns undefined", function()
  assert_eq(exec_js("function f() { return; } return f() === undefined;"), true)
end)

test("bare return stored in array creates present element", function()
  assert_eq(exec_js([[
    function f() { return; }
    var arr = [];
    arr.push(f());
    return 0 in arr;
  ]]), true)
end)

-- ============================================================================
-- Phase 4: Runtime Returns — undefined instead of nil
-- ============================================================================

test("[].pop() === undefined", function()
  assert_eq(exec_js("return [].pop() === undefined;"), true)
end)

test("[].pop() stored in array creates present element", function()
  assert_eq(exec_js([[
    var arr = [];
    arr.push([].pop());
    return 0 in arr;
  ]]), true)
end)

test("[].shift() === undefined", function()
  assert_eq(exec_js("return [].shift() === undefined;"), true)
end)

test("[].shift() stored in array creates present element", function()
  assert_eq(exec_js([[
    var arr = [];
    arr.push([].shift());
    return 0 in arr;
  ]]), true)
end)

test("forEach returns undefined (storable)", function()
  assert_eq(exec_js([[
    var arr = [];
    arr.push([1].forEach(x => x));
    return 0 in arr;
  ]]), true)
end)

test("[1,2].at(5) === undefined (out of bounds)", function()
  assert_eq(exec_js("return [1,2].at(5) === undefined;"), true)
end)

test("[1,2,3].find(x => x > 10) === undefined (not found)", function()
  assert_eq(exec_js("return [1,2,3].find(x => x > 10) === undefined;"), true)
end)

test("find not found stored in array creates present element", function()
  assert_eq(exec_js([[
    var arr = [];
    arr.push([1].find(x => x > 10));
    return 0 in arr;
  ]]), true)
end)

test('"hello"[10] === undefined (string index OOB)', function()
  assert_eq(exec_js('return "hello"[10] === undefined;'), true)
end)

test('"hello"["10"] === undefined (string string-key OOB)', function()
  assert_eq(exec_js('return "hello"["10"] === undefined;'), true)
end)

-- ============================================================================
-- Phase 4: Rawget normalization — holes → _ljs_undefined
-- ============================================================================

test("[1,,3].find(x => x === undefined) returns undefined (hole as undefined)", function()
  assert_eq(exec_js([[
    var arr = [1, , 3];
    return arr.find(x => x === undefined) === undefined;
  ]]), true)
end)

test("[1,,3].findIndex(x => x === undefined) returns 1 (hole as undefined)", function()
  assert_eq(exec_js("return [1, , 3].findIndex(x => x === undefined);"), 1)
end)

test("[1,,3].at(1) === undefined (hole at index)", function()
  assert_eq(exec_js("return [1, , 3].at(1) === undefined;"), true)
end)

test("[,2,3].shift() === undefined (hole at first position)", function()
  assert_eq(exec_js([[
    var arr = [, 2, 3];
    var result = arr.shift();
    return result === undefined;
  ]]), true)
end)

-- ============================================================================
-- Phase 4: Iterator normalization
-- ============================================================================

test("iterator done value is undefined", function()
  assert_eq(exec_js([[
    var it = [1].values();
    it.next();
    var result = it.next();
    return result.value === undefined && result.done === true;
  ]]), true)
end)

test("iterator visits holes as undefined (values)", function()
  assert_eq(exec_js([[
    var it = [1, , 3].values();
    it.next();
    var result = it.next();
    return result.value === undefined && result.done === false;
  ]]), true)
end)

test("iterator visits holes as undefined (entries)", function()
  assert_eq(exec_js([[
    var it = [1, , 3].entries();
    it.next();
    var result = it.next();
    return result.value[1] === undefined && result.done === false;
  ]]), true)
end)

test("iterator done on exhausted array", function()
  assert_eq(exec_js([[
    var it = [].values();
    var result = it.next();
    return result.value === undefined && result.done === true;
  ]]), true)
end)

-- ============================================================================
-- Phase 4: Param normalization for runtime functions
-- ============================================================================

test("[undefined].indexOf() === 0 (missing searchElement = undefined)", function()
  assert_eq(exec_js("return [undefined].indexOf();"), 0)
end)

test("[].indexOf() === -1 (missing searchElement, not in array)", function()
  assert_eq(exec_js("return [].indexOf();"), -1)
end)

test("[1, undefined].lastIndexOf() === 1 (missing searchElement = undefined)", function()
  assert_eq(exec_js("return [1, undefined].lastIndexOf();"), 1)
end)

test("[].lastIndexOf() === -1 (missing searchElement, not in array)", function()
  assert_eq(exec_js("return [].lastIndexOf();"), -1)
end)

test("arr.fill() fills with undefined (present elements)", function()
  assert_eq(exec_js([[
    var arr = [1, 2, 3];
    arr.fill();
    return arr[0] === undefined && 0 in arr;
  ]]), true)
end)

test("arr.fill() creates present elements (not holes)", function()
  assert_eq(exec_js([[
    var arr = [1, 2, 3];
    arr.fill();
    return 0 in arr && 1 in arr && 2 in arr;
  ]]), true)
end)
