local T = require("test.ljs_test")
local R = require("test.helpers.runtime")
local test, assert_eq, assert_js = R.test, R.assert_eq, R.assert_js
local eval_js, exec_js, transpile_js = R.eval_js, R.exec_js, R.transpile_js

-- ============================================================================
-- Array.prototype.push
-- ============================================================================

test("push returns new length", function()
  assert_eq(exec_js("return [1, 2, 3].push(4);"), 4)
end)

test("push appends element", function()
  local arr = exec_js("let a = [1, 2]; a.push(99); return a;")
  assert_eq(arr[3], 99)
  assert_eq(arr.length, 3)
end)

test("push with multiple args", function()
  assert_eq(exec_js("return [1].push(2, 3);"), 3)
end)

-- ============================================================================
-- Array.prototype.pop
-- ============================================================================

test("pop returns last element", function()
  assert_eq(exec_js("return [10, 20, 30].pop();"), 30)
end)

test("pop reduces length", function()
  local arr = exec_js("let a = [1, 2, 3]; a.pop(); return a;")
  assert_eq(arr.length, 2)
  assert_eq(arr[2], 2)
end)

test("pop on empty returns nil", function()
  assert_eq(exec_js("return [].pop();"), nil)
end)

-- ============================================================================
-- Array constructor / literal
-- ============================================================================

test("array literal length and indexing", function()
  local arr = eval_js("[1, 2, 3]")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[3], 3)
end)

test("new Array with elements", function()
  local arr = eval_js("new Array(7, 8, 9)")
  assert_eq(arr[1], 7)
  assert_eq(arr[2], 8)
  assert_eq(arr[3], 9)
  assert_eq(arr.length, 3)
end)

-- ============================================================================
-- Object.prototype.toString
-- ============================================================================

test("toString on empty object", function()
  assert_eq(exec_js("return ({}).toString();"), "[object Object]")
end)

test("toString on object with properties", function()
  assert_eq(exec_js("return ({a: 1}).toString();"), "[object Object]")
end)

-- ============================================================================
-- Object.prototype.hasOwnProperty
-- ============================================================================

test("hasOwnProperty true for own key", function()
  assert_eq(exec_js("return ({a: 1}).hasOwnProperty('a');"), true)
end)

test("hasOwnProperty false for missing key", function()
  assert_eq(exec_js("return ({a: 1}).hasOwnProperty('b');"), false)
end)

-- ============================================================================
-- Object.create
-- ============================================================================

test("Object.create inherits properties", function()
  assert_eq(
    exec_js([[
    let proto = { greet: function() { return "hi"; } };
    return Object.create(proto).greet();
  ]]),
    "hi"
  )
end)

-- ============================================================================
-- Function.prototype.call / apply
-- ============================================================================

test("Function.prototype.call", function()
  assert_eq(exec_js("return (function() { return this.x; }).call({x: 42});"), 42)
end)

test("Function.prototype.apply", function()
  assert_eq(exec_js("return (function(a, b) { return a + b; }).apply(null, [3, 4]);"), 7)
end)

-- ============================================================================
-- Array.isArray
-- ============================================================================

test("Array.isArray on array literal", function()
  assert_eq(exec_js("return Array.isArray([1, 2, 3]);"), true)
end)

test("Array.isArray on non-array object", function()
  assert_eq(exec_js("return Array.isArray({});"), false)
end)

test("Array.isArray on string", function()
  assert_eq(exec_js("return Array.isArray('hello');"), false)
end)

test("Array.isArray on number", function()
  assert_eq(exec_js("return Array.isArray(42);"), false)
end)

test("Array.isArray on null", function()
  assert_eq(exec_js("return Array.isArray(null);"), false)
end)

test("Array.isArray on new Array", function()
  assert_eq(exec_js("return Array.isArray(new Array(1, 2));"), true)
end)

-- ============================================================================
-- Array.from
-- ============================================================================

test("Array.from on array", function()
  local arr = exec_js("return Array.from([1, 2, 3]);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("Array.from on string", function()
  local arr = exec_js("return Array.from('abc');")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], "a")
  assert_eq(arr[2], "b")
  assert_eq(arr[3], "c")
end)

test("Array.from on empty", function()
  local arr = exec_js("return Array.from([]);")
  assert_eq(arr.length, 0)
end)

test("Array.from with mapFn", function()
  local arr = exec_js("return Array.from([1, 2, 3], function(x) { return x * 2; });")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 4)
  assert_eq(arr[3], 6)
end)

test("Array.from with mapFn and thisArg", function()
  local arr = exec_js([[
    var ctx = { mult: 10 };
    return Array.from([1, 2], function(x) { return x * this.mult; }, ctx);
  ]])
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 10)
  assert_eq(arr[2], 20)
end)

-- ============================================================================
-- Array.of
-- ============================================================================

test("Array.of with args", function()
  local arr = exec_js("return Array.of(1, 2, 3);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("Array.of single arg", function()
  local arr = exec_js("return Array.of(42);")
  assert_eq(arr.length, 1)
  assert_eq(arr[1], 42)
end)

test("Array.of no args", function()
  local arr = exec_js("return Array.of();")
  assert_eq(arr.length, 0)
end)

test("Array.of with mixed types", function()
  local arr = exec_js("return Array.of(1, 'hello', true);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], "hello")
  assert_eq(arr[3], true)
end)

-- ============================================================================
-- Array.prototype.join
-- ============================================================================

test("join default separator is comma", function()
  assert_eq(exec_js("return [1, 2, 3].join();"), "1,2,3")
end)

test("join with custom separator", function()
  assert_eq(exec_js("return [1, 2, 3].join('-');"), "1-2-3")
end)

test("join empty array returns empty string", function()
  assert_eq(exec_js("return [].join();"), "")
end)

test("join single element", function()
  assert_eq(exec_js("return [42].join();"), "42")
end)

test("join with strings", function()
  assert_eq(exec_js("return ['a', 'b', 'c'].join(',');"), "a,b,c")
end)

test("join with mixed types", function()
  assert_eq(exec_js("return [1, 'two', true].join(',');"), "1,two,true")
end)

test("join with empty separator", function()
  assert_eq(exec_js("return [1, 2, 3].join('');"), "123")
end)

-- ============================================================================
-- Array.prototype.toString
-- ============================================================================

test("toString calls join with comma", function()
  assert_eq(exec_js("return [1, 2, 3].toString();"), "1,2,3")
end)

test("toString on empty array", function()
  assert_eq(exec_js("return [].toString();"), "")
end)

test("toString on single element", function()
  assert_eq(exec_js("return [42].toString();"), "42")
end)

test("toString with strings", function()
  assert_eq(exec_js("return ['a', 'b'].toString();"), "a,b")
end)

test("toString with mixed types", function()
  assert_eq(exec_js("return [1, 'two', true].toString();"), "1,two,true")
end)

test("toString falls back to Object.prototype.toString when join is null", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = null; return arr.toString();"), "[object Array]")
end)

test("toString falls back to Object.prototype.toString when join is a number", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = 42; return arr.toString();"), "[object Array]")
end)

test("toString falls back to Object.prototype.toString when join is a string", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = 'hello'; return arr.toString();"), "[object Array]")
end)

test("toString uses custom join when join is callable", function()
  assert_eq(exec_js("let arr = [1, 2, 3]; arr.join = function() { return 'custom'; }; return arr.toString();"), "custom")
end)

-- ============================================================================
-- Array .length update on index assignment (#160)
-- ============================================================================

test("index assignment beyond bounds updates length", function()
  assert_eq(exec_js("var a = []; a[5] = 1; return a.length;"), 6)
end)

test("index 0 assignment updates length", function()
  assert_eq(exec_js("var a = []; a[0] = 'x'; return a.length;"), 1)
end)

test("within-bounds assignment preserves length", function()
  assert_eq(exec_js("var a = [1, 2, 3]; a[1] = 99; return a.length;"), 3)
end)

test("multiple gap assignments", function()
  assert_eq(exec_js("var a = []; a[2] = 'a'; a[5] = 'b'; return a.length;"), 6)
end)

test("sparse array length (#191)", function()
  local arr = eval_js("[1,,3]")
  assert_eq(arr.length, 3)
end)

test("sparse array element after hole (#191)", function()
  assert_eq(exec_js("return [1,,3][2];"), 3)
end)

test("sparse array hole is undefined (#191)", function()
  assert_eq(exec_js("return [1,,3][1];"), nil)
end)

test("index assignment on new Array", function()
  assert_eq(exec_js("var a = new Array(); a[3] = 1; return a.length;"), 4)
end)

-- ============================================================================
-- Array.prototype.map
-- ============================================================================

test("map basic doubling", function()
  local arr = exec_js("return [1, 2, 3].map(function(x) { return x * 2; });")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 4)
  assert_eq(arr[3], 6)
end)

test("map with index argument", function()
  local arr = exec_js("return [10, 20, 30].map(function(x, i) { return x + i; });")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 10)
  assert_eq(arr[2], 21)
  assert_eq(arr[3], 32)
end)

test("map with array argument", function()
  local arr = exec_js("return [1, 2].map(function(x, i, a) { return x + a.length; });")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 4)
end)

test("map with thisArg", function()
  local arr = exec_js([[
    var ctx = { m: 10 };
    return [1, 2, 3].map(function(x) { return x * this.m; }, ctx);
  ]])
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 10)
  assert_eq(arr[2], 20)
  assert_eq(arr[3], 30)
end)

test("map returns new array", function()
  local arr = exec_js([=[
    var orig = [1, 2, 3];
    orig.map(function(x) { return x * 2; });
    return [orig[0], orig[1], orig[2]];
  ]=])
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("map on empty array", function()
  local arr = exec_js("return [].map(function(x) { return x; });")
  assert_eq(arr.length, 0)
end)

test("map sparse array preserves length", function()
  local arr = exec_js("return [1,,3].map(function(x) { return x * 2; });")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], nil)
  assert_eq(arr[3], 6)
end)

test("map sparse array skips holes in callback", function()
  local arr = exec_js([[
    var count = 0;
    [1,,3].map(function(x) { count++; return x; });
    return count;
  ]])
  assert_eq(arr, 2)
end)

test("map throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].map(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("map throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].map();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("map with arrow function callback", function()
  local arr = exec_js("return [1, 2, 3].map(x => x * 2);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 4)
  assert_eq(arr[3], 6)
end)

-- ============================================================================
-- Array.prototype.slice
-- ============================================================================

test("slice with start and end", function()
  local arr = exec_js("return [1, 2, 3, 4, 5].slice(1, 3);")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 3)
end)

test("slice with no args returns full copy", function()
  local arr = exec_js("return [1, 2, 3].slice();")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("slice with only start", function()
  local arr = exec_js("return [1, 2, 3, 4].slice(2);")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 4)
end)

test("slice with negative start", function()
  local arr = exec_js("return [1, 2, 3].slice(-2);")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 3)
end)

test("slice with negative end", function()
  local arr = exec_js("return [1, 2, 3, 4, 5].slice(1, -1);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 3)
  assert_eq(arr[3], 4)
end)

test("slice with both negative", function()
  local arr = exec_js("return [1, 2, 3, 4, 5].slice(-3, -1);")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 4)
end)

test("slice start beyond length returns empty", function()
  local arr = exec_js("return [1, 2, 3].slice(10);")
  assert_eq(arr.length, 0)
end)

test("slice large negative start clamped to 0", function()
  local arr = exec_js("return [1, 2, 3].slice(-100);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[3], 3)
end)

test("slice empty range start equals end", function()
  local arr = exec_js("return [1, 2, 3].slice(1, 1);")
  assert_eq(arr.length, 0)
end)

test("slice empty array", function()
  local arr = exec_js("return [].slice(0, 2);")
  assert_eq(arr.length, 0)
end)

test("slice sparse array preserves holes", function()
  local arr = exec_js("return [1,,3].slice(0, 3);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], nil)
  assert_eq(arr[3], 3)
end)

test("slice result is independent of original", function()
  local arr = exec_js([=[
    var orig = [1, 2, 3];
    var copy = orig.slice();
    orig[1] = 99;
    return [copy[1], orig[1]];
  ]=])
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 99)
end)

-- ============================================================================
-- Array.prototype.concat
-- ============================================================================

test("concat two arrays", function()
  local arr = exec_js("return [1, 2].concat([3, 4]);")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
  assert_eq(arr[4], 4)
end)

test("concat array with non-array args", function()
  local arr = exec_js("return [1, 2].concat(3, 4);")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
  assert_eq(arr[4], 4)
end)

test("concat multiple arrays", function()
  local arr = exec_js("return [].concat([1], [2], [3]);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("concat no args returns copy", function()
  local arr = exec_js("return [1, 2].concat();")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
end)

test("concat nested arrays not deeply flattened", function()
  local arr = exec_js("return [1, [2, [3]]].concat([4, [5]]);")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 1)
  assert_eq(type(arr[2]), "table")
  assert_eq(arr[3], 4)
  assert_eq(type(arr[4]), "table")
end)

test("concat with primitives", function()
  local arr = exec_js("return [].concat(1, 'hello', true);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], "hello")
  assert_eq(arr[3], true)
end)

test("concat sparse arrays preserves holes", function()
  local arr = exec_js("return [1,,3].concat([4,,6]);")
  assert_eq(arr.length, 6)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], nil)
  assert_eq(arr[3], 3)
  assert_eq(arr[4], 4)
  assert_eq(arr[5], nil)
  assert_eq(arr[6], 6)
end)

test("concat result is independent of originals", function()
  local arr = exec_js([=[
    var a = [1, 2];
    var b = [3, 4];
    var c = a.concat(b);
    a[0] = 99;
    b[0] = 88;
    return [c[0], c[1], c[2], c[3]];
  ]=])
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
  assert_eq(arr[4], 4)
end)

-- ============================================================================
-- Array.prototype.at
-- ============================================================================

test("at positive index", function()
  assert_eq(exec_js("return [1, 2, 3].at(0);"), 1)
end)

test("at positive index middle", function()
  assert_eq(exec_js("return [1, 2, 3].at(1);"), 2)
end)

test("at negative index returns last element", function()
  assert_eq(exec_js("return [1, 2, 3].at(-1);"), 3)
end)

test("at negative index second to last", function()
  assert_eq(exec_js("return [1, 2, 3].at(-2);"), 2)
end)

test("at out of bounds positive returns undefined", function()
  assert_eq(exec_js("return [1, 2, 3].at(3);"), nil)
end)

test("at out of bounds negative returns undefined", function()
  assert_eq(exec_js("return [1, 2, 3].at(-4);"), nil)
end)

test("at with no args returns first element", function()
  assert_eq(exec_js("return [1, 2, 3].at();"), 1)
end)

test("at truncates fractional index", function()
  assert_eq(exec_js("return [1, 2, 3].at(1.5);"), 2)
end)

test("at truncates negative fractional index", function()
  assert_eq(exec_js("return [1, 2, 3].at(-1.5);"), 3)
end)

test("at on empty array returns undefined", function()
  assert_eq(exec_js("return [].at(0);"), nil)
end)

test("at with NaN returns first element", function()
  assert_eq(exec_js("return [1, 2, 3].at(NaN);"), 1)
end)

test("at with Infinity returns undefined", function()
  assert_eq(exec_js("return [1, 2, 3].at(Infinity);"), nil)
end)

test("at with -Infinity returns undefined", function()
  assert_eq(exec_js("return [1, 2, 3].at(-Infinity);"), nil)
end)

test("at on sparse array hole returns undefined", function()
  assert_eq(exec_js("return [1,,3].at(1);"), nil)
end)

-- ============================================================================
-- Array.prototype.some
-- ============================================================================

test("some returns true when any element matches", function()
  assert_eq(exec_js("return [1, 2, 3].some(function(x) { return x > 2; });"), true)
end)

test("some returns false when no element matches", function()
  assert_eq(exec_js("return [1, 2, 3].some(function(x) { return x > 10; });"), false)
end)

test("some returns false for empty array", function()
  assert_eq(exec_js("return [].some(function(x) { return true; });"), false)
end)

test("some short-circuits on first match", function()
  local count = exec_js([[
    var count = 0;
    [1, 2, 3].some(function(x) { count++; return x === 2; });
    return count;
  ]])
  assert_eq(count, 2)
end)

test("some with thisArg", function()
  assert_eq(exec_js([[
    var ctx = { threshold: 3 };
    return [1, 2, 4].some(function(x) { return x > this.threshold; }, ctx);
  ]]), true)
end)

test("some skips holes in sparse array", function()
  local count = exec_js([[
    var count = 0;
    [1,,3].some(function(x) { count++; return false; });
    return count;
  ]])
  assert_eq(count, 2)
end)

test("some with index and array arguments", function()
  local result = exec_js([=[
    var indices = [];
    var lens = [];
    [10, 20].some(function(v, i, a) { indices.push(i); lens.push(a.length); return false; });
    return [indices[0], indices[1], lens[0], lens[1]];
  ]=])
  assert_eq(result[1], 0)
  assert_eq(result[2], 1)
  assert_eq(result[3], 2)
  assert_eq(result[4], 2)
end)

test("some throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].some(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("some throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].some();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("some with arrow function callback", function()
  assert_eq(exec_js("return [1, 2, 3].some(x => x > 2);"), true)
end)

test("some with callback returning 0 is falsy (#243)", function()
  assert_eq(exec_js("return [0].some(x => x);"), false)
end)

test("some with callback returning empty string is falsy (#243)", function()
  assert_eq(exec_js("return [''].some(x => x);"), false)
end)

test("some with callback returning 1 is truthy (#243)", function()
  assert_eq(exec_js("return [1].some(x => x);"), true)
end)

-- ============================================================================
-- Array.prototype.every
-- ============================================================================

test("every returns true when all elements match", function()
  assert_eq(exec_js("return [2, 4, 6].every(function(x) { return x % 2 === 0; });"), true)
end)

test("every returns false when any element fails", function()
  assert_eq(exec_js("return [2, 3, 6].every(function(x) { return x % 2 === 0; });"), false)
end)

test("every returns true for empty array", function()
  assert_eq(exec_js("return [].every(function(x) { return false; });"), true)
end)

test("every short-circuits on first mismatch", function()
  local count = exec_js([[
    var count = 0;
    [1, 2, 3].every(function(x) { count++; return x !== 2; });
    return count;
  ]])
  assert_eq(count, 2)
end)

test("every with thisArg", function()
  assert_eq(exec_js([[
    var ctx = { max: 5 };
    return [1, 2, 3].every(function(x) { return x < this.max; }, ctx);
  ]]), true)
end)

test("every skips holes in sparse array", function()
  local count = exec_js([[
    var count = 0;
    [1,,3].every(function(x) { count++; return true; });
    return count;
  ]])
  assert_eq(count, 2)
end)

test("every with index and array arguments", function()
  local result = exec_js([=[
    var indices = [];
    var lens = [];
    [10, 20].every(function(v, i, a) { indices.push(i); lens.push(a.length); return true; });
    return [indices[0], indices[1], lens[0], lens[1]];
  ]=])
  assert_eq(result[1], 0)
  assert_eq(result[2], 1)
  assert_eq(result[3], 2)
  assert_eq(result[4], 2)
end)

test("every throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].every(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("every throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].every();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("every with arrow function callback", function()
  assert_eq(exec_js("return [2, 4, 6].every(x => x % 2 === 0);"), true)
end)

test("every with callback returning 0 is falsy (#243)", function()
  assert_eq(exec_js("return [0].every(x => x);"), false)
end)

test("every with callback returning empty string is falsy (#243)", function()
  assert_eq(exec_js("return [''].every(x => x);"), false)
end)

test("every with callback returning 1 is truthy (#243)", function()
  assert_eq(exec_js("return [1].every(x => x);"), true)
end)

-- ============================================================================
-- Array.prototype.indexOf
-- ============================================================================

test("indexOf finds element", function()
  assert_eq(exec_js("return [1, 2, 3].indexOf(2);"), 1)
end)

test("indexOf returns -1 when not found", function()
  assert_eq(exec_js("return [1, 2, 3].indexOf(99);"), -1)
end)

test("indexOf finds first occurrence", function()
  assert_eq(exec_js("return [1, 2, 2, 3].indexOf(2);"), 1)
end)

test("indexOf with fromIndex", function()
  assert_eq(exec_js("return [1, 2, 3, 2].indexOf(2, 2);"), 3)
end)

test("indexOf negative fromIndex", function()
  assert_eq(exec_js("return [1, 2, 3, 4].indexOf(3, -2);"), 2)
end)

test("indexOf NaN not found", function()
  assert_eq(exec_js("return [1, NaN, 3].indexOf(NaN);"), -1)
end)

test("indexOf skips holes and finds later element", function()
  assert_eq(exec_js("return [1,,3].indexOf(3);"), 2)
end)

test("indexOf empty array returns -1", function()
  assert_eq(exec_js("return [].indexOf(1);"), -1)
end)

test("indexOf fromIndex beyond length returns -1", function()
  assert_eq(exec_js("return [1, 2, 3].indexOf(1, 10);"), -1)
end)

test("indexOf NaN fromIndex treated as 0", function()
  assert_eq(exec_js("return [1, 2, 3].indexOf(1, NaN);"), 0)
end)

test("indexOf Infinity fromIndex returns -1", function()
  assert_eq(exec_js("return [1, 2, 3].indexOf(1, Infinity);"), -1)
end)

test("indexOf -Infinity fromIndex treated as 0", function()
  assert_eq(exec_js("return [1, 2, 3].indexOf(1, -Infinity);"), 0)
end)

-- ============================================================================
-- Array.prototype.lastIndexOf
-- ============================================================================

test("lastIndexOf finds element", function()
  assert_eq(exec_js("return [1, 2, 3].lastIndexOf(2);"), 1)
end)

test("lastIndexOf returns -1 when not found", function()
  assert_eq(exec_js("return [1, 2, 3].lastIndexOf(99);"), -1)
end)

test("lastIndexOf finds last occurrence", function()
  assert_eq(exec_js("return [1, 2, 2, 3].lastIndexOf(2);"), 2)
end)

test("lastIndexOf with fromIndex", function()
  assert_eq(exec_js("return [1, 2, 3, 2].lastIndexOf(2, 2);"), 1)
end)

test("lastIndexOf negative fromIndex", function()
  assert_eq(exec_js("return [1, 2, 3, 4].lastIndexOf(4, -1);"), 3)
end)

test("lastIndexOf NaN not found", function()
  assert_eq(exec_js("return [1, NaN, 3].lastIndexOf(NaN);"), -1)
end)

test("lastIndexOf skips holes", function()
  assert_eq(exec_js("return [1,,3].lastIndexOf(3);"), 2)
end)

test("lastIndexOf empty array returns -1", function()
  assert_eq(exec_js("return [].lastIndexOf(1);"), -1)
end)

test("lastIndexOf -Infinity fromIndex returns -1", function()
  assert_eq(exec_js("return [1, 2, 3].lastIndexOf(1, -Infinity);"), -1)
end)

test("lastIndexOf Infinity fromIndex searches from end", function()
  assert_eq(exec_js("return [1, 2, 3].lastIndexOf(3, Infinity);"), 2)
end)

test("lastIndexOf NaN fromIndex starts at 0", function()
  assert_eq(exec_js("return [2, 1, 1].lastIndexOf(1, NaN);"), -1)
end)

-- ============================================================================
-- Array.prototype.includes
-- ============================================================================

test("includes finds element", function()
  assert_eq(exec_js("return [1, 2, 3].includes(2);"), true)
end)

test("includes returns false when not found", function()
  assert_eq(exec_js("return [1, 2, 3].includes(99);"), false)
end)

test("includes finds NaN via SameValueZero", function()
  assert_eq(exec_js("return [1, NaN, 3].includes(NaN);"), true)
end)

test("includes with fromIndex", function()
  assert_eq(exec_js("return [1, 2, 3].includes(1, 1);"), false)
end)

test("includes negative fromIndex", function()
  assert_eq(exec_js("return [1, 2, 3, 4].includes(3, -2);"), true)
end)

test("includes treats holes as undefined", function()
  assert_eq(exec_js("return [1,,3].includes(undefined);"), true)
end)

test("includes empty array returns false", function()
  assert_eq(exec_js("return [].includes(1);"), false)
end)

test("includes Infinity fromIndex returns false", function()
  assert_eq(exec_js("return [1, 2, 3].includes(1, Infinity);"), false)
end)

test("includes -Infinity fromIndex treated as 0", function()
  assert_eq(exec_js("return [1, 2, 3].includes(1, -Infinity);"), true)
end)

test("includes NaN fromIndex treated as 0", function()
  assert_eq(exec_js("return [1, 2, 3].includes(1, NaN);"), true)
end)

test("includes with string element", function()
  assert_eq(exec_js("return ['a', 'b', 'c'].includes('b');"), true)
end)

test("includes does not use strict equality for NaN", function()
  assert_eq(exec_js("return [NaN].includes(NaN);"), true)
end)

-- ============================================================================
-- Array.prototype.find
-- ============================================================================

test("find returns first matching element", function()
  assert_eq(exec_js("return [1, 2, 3].find(function(x) { return x > 1; });"), 2)
end)

test("find returns nil when nothing matches", function()
  assert_eq(exec_js("return [1, 2, 3].find(function(x) { return x > 10; });"), nil)
end)

test("find with index argument", function()
  assert_eq(exec_js("return [10, 20, 30].find(function(x, i) { return i === 1; });"), 20)
end)

test("find with array argument", function()
  assert_eq(exec_js("return [1, 2, 3].find(function(x, i, a) { return x === a[2]; });"), 3)
end)

test("find with thisArg", function()
  assert_eq(exec_js([[
    var ctx = { threshold: 2 };
    return [1, 2, 3].find(function(x) { return x > this.threshold; }, ctx);
  ]]), 3)
end)

test("find throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].find(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("find throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].find();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("find with arrow function callback", function()
  assert_eq(exec_js("return [1, 2, 3].find(x => x > 1);"), 2)
end)

test("find with callback returning 0 is falsy (#243)", function()
  assert_eq(exec_js("return [0, 1].find(x => x);"), 1)
end)

test("find with callback returning empty string is falsy (#243)", function()
  assert_eq(exec_js("return ['', 'a'].find(x => x);"), "a")
end)

test("find with all falsy elements returns nil (#243)", function()
  assert_eq(exec_js("return [0].find(x => x);"), nil)
end)

test("find does not skip holes", function()
  assert_eq(exec_js([=[
    var found = false;
    [1,,3].find(function(x) { if (x === undefined) found = true; return false; });
    return found;
  ]=]), true)
end)

test("find on empty array returns nil", function()
  assert_eq(exec_js("return [].find(function() { return true; });"), nil)
end)

-- ============================================================================
-- Array.prototype.findIndex
-- ============================================================================

test("findIndex returns index of first match", function()
  assert_eq(exec_js("return [1, 2, 3].findIndex(function(x) { return x > 1; });"), 1)
end)

test("findIndex returns -1 when nothing matches", function()
  assert_eq(exec_js("return [1, 2, 3].findIndex(function(x) { return x > 10; });"), -1)
end)

test("findIndex with index argument", function()
  assert_eq(exec_js("return [10, 20, 30].findIndex(function(x, i) { return i === 1; });"), 1)
end)

test("findIndex with array argument", function()
  assert_eq(exec_js("return [1, 2, 3].findIndex(function(x, i, a) { return x === a[2]; });"), 2)
end)

test("findIndex with thisArg", function()
  assert_eq(exec_js([[
    var ctx = { threshold: 2 };
    return [1, 2, 3].findIndex(function(x) { return x > this.threshold; }, ctx);
  ]]), 2)
end)

test("findIndex throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].findIndex(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("findIndex throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].findIndex();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("findIndex with arrow function callback", function()
  assert_eq(exec_js("return [1, 2, 3].findIndex(x => x > 1);"), 1)
end)

test("findIndex with callback returning 0 is falsy (#243)", function()
  assert_eq(exec_js("return [0, 1].findIndex(x => x);"), 1)
end)

test("findIndex with callback returning empty string is falsy (#243)", function()
  assert_eq(exec_js("return ['', 'a'].findIndex(x => x);"), 1)
end)

test("findIndex with all falsy elements returns -1 (#243)", function()
  assert_eq(exec_js("return [0].findIndex(x => x);"), -1)
end)

test("findIndex does not skip holes", function()
  assert_eq(exec_js([=[
    var found = false;
    [1,,3].findIndex(function(x) { if (x === undefined) found = true; return false; });
    return found;
  ]=]), true)
end)

test("findIndex on empty array returns -1", function()
  assert_eq(exec_js("return [].findIndex(function() { return true; });"), -1)
end)

-- ============================================================================
-- Array.prototype.forEach
-- ============================================================================

test("forEach basic iteration", function()
  local result = exec_js([=[
    var result = [];
    [1, 2, 3].forEach(function(x) { result.push(x * 2); });
    return result;
  ]=])
  assert_eq(result.length, 3)
  assert_eq(result[1], 2)
  assert_eq(result[2], 4)
  assert_eq(result[3], 6)
end)

test("forEach with index argument", function()
  local result = exec_js([=[
    var result = [];
    [10, 20, 30].forEach(function(x, i) { result.push(i); });
    return result;
  ]=])
  assert_eq(result.length, 3)
  assert_eq(result[1], 0)
  assert_eq(result[2], 1)
  assert_eq(result[3], 2)
end)

test("forEach with array argument", function()
  local result = exec_js([=[
    var result = [];
    [1, 2].forEach(function(x, i, a) { result.push(a.length); });
    return result;
  ]=])
  assert_eq(result.length, 2)
  assert_eq(result[1], 2)
  assert_eq(result[2], 2)
end)

test("forEach with thisArg", function()
  local result = exec_js([[
    var ctx = { mult: 10 };
    var result = [];
    [1, 2, 3].forEach(function(x) { result.push(x * this.mult); }, ctx);
    return result;
  ]])
  assert_eq(result.length, 3)
  assert_eq(result[1], 10)
  assert_eq(result[2], 20)
  assert_eq(result[3], 30)
end)

test("forEach returns undefined", function()
  assert_eq(exec_js("return [1, 2, 3].forEach(function() {});"), nil)
end)

test("forEach on empty array does nothing", function()
  local result = exec_js([=[
    var count = 0;
    [].forEach(function() { count++; });
    return count;
  ]=])
  assert_eq(result, 0)
end)

test("forEach skips holes in sparse array", function()
  local result = exec_js([=[
    var result = [];
    [1,,3].forEach(function(x) { result.push(x); });
    return result;
  ]=])
  assert_eq(result.length, 2)
  assert_eq(result[1], 1)
  assert_eq(result[2], 3)
end)

test("forEach throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].forEach(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("forEach throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].forEach();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("forEach with arrow function callback", function()
  local result = exec_js([=[
    var result = [];
    [1, 2, 3].forEach(x => result.push(x * 2));
    return result;
  ]=])
  assert_eq(result.length, 3)
  assert_eq(result[1], 2)
  assert_eq(result[2], 4)
  assert_eq(result[3], 6)
end)

-- ============================================================================
-- Array.prototype.filter
-- ============================================================================

test("filter basic filtering", function()
  local arr = exec_js("return [1, 2, 3, 4].filter(function(x) { return x > 2; });")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 4)
end)

test("filter with index argument", function()
  local arr = exec_js("return [10, 20, 30].filter(function(x, i) { return i > 0; });")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 20)
  assert_eq(arr[2], 30)
end)

test("filter with array argument", function()
  local arr = exec_js("return [1, 2, 3].filter(function(x, i, a) { return x >= a.length; });")
  assert_eq(arr.length, 1)
  assert_eq(arr[1], 3)
end)

test("filter with thisArg", function()
  local arr = exec_js([[
    var ctx = { threshold: 2 };
    return [1, 2, 3, 4].filter(function(x) { return x > this.threshold; }, ctx);
  ]])
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 4)
end)

test("filter returns new array", function()
  local arr = exec_js([=[
    var orig = [1, 2, 3];
    var filtered = orig.filter(function(x) { return x > 1; });
    return [orig.length, filtered.length];
  ]=])
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 2)
end)

test("filter on empty array", function()
  local arr = exec_js("return [].filter(function(x) { return true; });")
  assert_eq(arr.length, 0)
end)

test("filter skips holes in sparse array", function()
  local result = exec_js([=[
    var result = [];
    [1,,3].filter(function(x) { result.push(x); return true; });
    return result;
  ]=])
  assert_eq(result.length, 2)
  assert_eq(result[1], 1)
  assert_eq(result[2], 3)
end)

test("filter throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].filter(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("filter throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].filter();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("filter with arrow function callback", function()
  local arr = exec_js("return [1, 2, 3, 4].filter(x => x % 2 === 0);")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 4)
end)

test("filter uses _ljs_to_boolean for callback result (#243)", function()
  local arr = exec_js("return [0, 1, '', 'a', null, 2].filter(x => x);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], "a")
  assert_eq(arr[3], 2)
end)

-- ============================================================================
-- Array.prototype.reduce
-- ============================================================================

test("reduce basic sum", function()
  assert_eq(exec_js("return [1, 2, 3].reduce(function(acc, x) { return acc + x; });"), 6)
end)

test("reduce with initialValue", function()
  assert_eq(exec_js("return [1, 2, 3].reduce(function(acc, x) { return acc + x; }, 10);"), 16)
end)

test("reduce with index argument", function()
  assert_eq(exec_js("return [10, 20, 30].reduce(function(acc, x, i) { return acc + i; }, 0);"), 3)
end)

test("reduce with array argument", function()
  assert_eq(exec_js("return [1, 2, 3].reduce(function(acc, x, i, a) { return a.length; }, 0);"), 3)
end)

test("reduce on empty array with initialValue returns initialValue", function()
  assert_eq(exec_js("return [].reduce(function() {}, 42);"), 42)
end)

test("reduce on single element without initialValue returns element", function()
  assert_eq(exec_js("return [7].reduce(function() {});"), 7)
end)

test("reduce throws TypeError on empty array without initialValue", function()
  local ok, err = pcall(exec_js, "return [].reduce(function() {});")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("reduce skips holes in sparse array", function()
  assert_eq(exec_js("return [1,,3].reduce(function(acc, x) { return acc + x; });"), 4)
end)

test("reduce throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].reduce(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("reduce throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].reduce();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("reduce with arrow function callback", function()
  assert_eq(exec_js("return [1, 2, 3].reduce((acc, x) => acc + x);"), 6)
end)

test("reduce sparse array finds first present element as initial accumulator", function()
  assert_eq(exec_js("return [,2,3].reduce(function(acc, x) { return acc + x; });"), 5)
end)

-- ============================================================================
-- Array.prototype.flat
-- ============================================================================

test("flat basic flatten one level", function()
  local arr = exec_js("return [1, [2, 3], 4].flat();")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
  assert_eq(arr[4], 4)
end)

test("flat with depth 2", function()
  local arr = exec_js("return [1, [2, [3]]].flat(2);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("flat default depth is 1", function()
  local arr = exec_js("return [1, [2, [3]]].flat();")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(type(arr[3]), "table")
end)

test("flat with depth 0 returns shallow copy", function()
  local arr = exec_js("return [1, [2, 3]].flat(0);")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 1)
  assert_eq(type(arr[2]), "table")
end)

test("flat deeply nested with Infinity", function()
  local arr = exec_js("return [1, [2, [3, [4]]]].flat(Infinity);")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
  assert_eq(arr[4], 4)
end)

test("flat on empty array", function()
  local arr = exec_js("return [].flat();")
  assert_eq(arr.length, 0)
end)

test("flat skips holes in sparse array", function()
  local arr = exec_js("return [1,,3].flat();")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 3)
end)

test("flat negative depth treated as 0", function()
  local arr = exec_js("return [1, [2, 3]].flat(-1);")
  assert_eq(arr.length, 2)
  assert_eq(type(arr[2]), "table")
end)

test("flat returns new array", function()
  local arr = exec_js([=[
    var orig = [1, [2, 3]];
    var flat = orig.flat();
    return [orig.length, flat.length];
  ]=])
  assert_eq(arr[1], 2)
  assert_eq(arr[2], 3)
end)

-- ============================================================================
-- Array.prototype.flatMap
-- ============================================================================

test("flatMap basic map and flatten", function()
  local arr = exec_js("return [1, 2, 3].flatMap(function(x) { return [x, x * 2]; });")
  assert_eq(arr.length, 6)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 2)
  assert_eq(arr[4], 4)
  assert_eq(arr[5], 3)
  assert_eq(arr[6], 6)
end)

test("flatMap with non-array return values", function()
  local arr = exec_js("return [1, 2, 3].flatMap(function(x) { return x; });")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("flatMap with thisArg", function()
  local arr = exec_js([[
    var ctx = { mult: 10 };
    return [1, 2].flatMap(function(x) { return [x * this.mult]; }, ctx);
  ]])
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 10)
  assert_eq(arr[2], 20)
end)

test("flatMap with index argument", function()
  local arr = exec_js("return [10, 20].flatMap(function(x, i) { return [x, i]; });")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 10)
  assert_eq(arr[2], 0)
  assert_eq(arr[3], 20)
  assert_eq(arr[4], 1)
end)

test("flatMap on empty array", function()
  local arr = exec_js("return [].flatMap(function(x) { return [x]; });")
  assert_eq(arr.length, 0)
end)

test("flatMap skips holes in sparse array", function()
  local arr = exec_js("return [1,,3].flatMap(function(x) { return [x]; });")
  assert_eq(arr.length, 2)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 3)
end)

test("flatMap throws TypeError on non-function", function()
  local ok, err = pcall(exec_js, "return [].flatMap(42);")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("flatMap throws TypeError on missing callback", function()
  local ok, err = pcall(exec_js, "return [].flatMap();")
  assert(not ok, "expected TypeError")
  assert(tostring(err):find("TypeError"), "expected TypeError in: " .. tostring(err))
end)

test("flatMap with arrow function callback", function()
  local arr = exec_js("return [1, 2, 3].flatMap(x => [x, x * 2]);")
  assert_eq(arr.length, 6)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 2)
  assert_eq(arr[4], 4)
  assert_eq(arr[5], 3)
  assert_eq(arr[6], 6)
end)

-- ============================================================================
-- Array.prototype.reverse
-- ============================================================================

test("reverse basic", function()
  local arr = exec_js("return [1, 2, 3].reverse();")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 1)
end)

test("reverse returns same reference", function()
  local arr = exec_js([=[
    var a = [1, 2, 3];
    var r = a.reverse();
    return a === r;
  ]=])
  assert_eq(arr, true)
end)

test("reverse empty array", function()
  local arr = exec_js("return [].reverse();")
  assert_eq(arr.length, 0)
end)

test("reverse single element", function()
  local arr = exec_js("return [42].reverse();")
  assert_eq(arr.length, 1)
  assert_eq(arr[1], 42)
end)

test("reverse even length", function()
  local arr = exec_js("return [1, 2, 3, 4].reverse();")
  assert_eq(arr.length, 4)
  assert_eq(arr[1], 4)
  assert_eq(arr[2], 3)
  assert_eq(arr[3], 2)
  assert_eq(arr[4], 1)
end)

test("reverse sparse array", function()
  local arr = exec_js("return [1,,3].reverse();")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 3)
  assert_eq(arr[2], nil)
  assert_eq(arr[3], 1)
end)

-- ============================================================================
-- Array.prototype.fill
-- ============================================================================

test("fill basic", function()
  local arr = exec_js("return [1, 2, 3].fill(0);")
  assert_eq(arr.length, 3)
  assert_eq(arr[1], 0)
  assert_eq(arr[2], 0)
  assert_eq(arr[3], 0)
end)

test("fill with start", function()
  local arr = exec_js("return [1, 2, 3, 4].fill(0, 2);")
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 0)
  assert_eq(arr[4], 0)
end)

test("fill with start and end", function()
  local arr = exec_js("return [1, 2, 3, 4, 5].fill(0, 1, 3);")
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 0)
  assert_eq(arr[3], 0)
  assert_eq(arr[4], 4)
  assert_eq(arr[5], 5)
end)

test("fill with negative start", function()
  local arr = exec_js("return [1, 2, 3, 4, 5].fill(0, -3);")
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 0)
  assert_eq(arr[4], 0)
  assert_eq(arr[5], 0)
end)

test("fill with negative end", function()
  local arr = exec_js("return [1, 2, 3, 4, 5].fill(0, 1, -1);")
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 0)
  assert_eq(arr[3], 0)
  assert_eq(arr[4], 0)
  assert_eq(arr[5], 5)
end)

test("fill returns same reference", function()
  local arr = exec_js([=[
    var a = [1, 2, 3];
    var r = a.fill(0);
    return a === r;
  ]=])
  assert_eq(arr, true)
end)

test("fill on empty array", function()
  local arr = exec_js("return [].fill(0);")
  assert_eq(arr.length, 0)
end)

-- ============================================================================
-- Code generation checks
-- ============================================================================

test("member call emits _ljs_call_member", function()
  local code = transpile_js("arr.push(1);")
  assert(code:find("_ljs_call_member"), "expected _ljs_call_member in output")
end)

test("new emits _ljs_new", function()
  local code = transpile_js("new Array(1, 2);")
  assert(code:find("_ljs_new"), "expected _ljs_new in output")
end)
