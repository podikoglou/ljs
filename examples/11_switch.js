// Adapted from mquickjs test_loop.js
// Tests: switch (break, continue, fallthrough, default), do-while, for-in, nested try/catch/finally

// switch with break
function test_switch() {
  var s = "";
  for (var i = 0; i < 3; i++) {
    var a = "?";
    switch (i) {
      case 0:
        a = "a";
        break;
      case 1:
        a = "b";
        break;
      default:
        a = "c";
        break;
    }
    s += a;
  }
  console.log(s);
}

// switch with continue (fallthrough into continue from case 2)
function test_switch_continue() {
  var s = "";
  for (var i = 0; i < 4; i++) {
    var a = "?";
    switch (i) {
      case 0:
        a = "a";
        break;
      case 1:
        a = "b";
        break;
      case 2:
        continue;
      default:
        a = "" + i;
        break;
    }
    s += a;
  }
  console.log(s);
}

// do-while
function test_do_while() {
  var i = 0;
  var c = 0;
  do {
    c++;
    i++;
  } while (i < 3);
  console.log(c);
  console.log(i);
}

// for-in over object keys
function test_for_in() {
  var keys = "";
  for (var k in {x: 1, y: 2, z: 3}) {
    keys += k;
  }
  console.log(keys);
}

// for-in with continue and break
function test_for_in_ctrl() {
  var keys = "";
  for (var k in {x: 1, y: 2, z: 3}) {
    if (k === "y") continue;
    keys += k;
  }
  console.log(keys);

  keys = "";
  for (var k in {x: 1, y: 2, z: 3}) {
    if (k === "z") break;
    keys += k;
  }
  console.log(keys);
}

// try/catch/finally
function test_try() {
  var s = "";
  try {
    s += "t";
  } catch (e) {
    s += "c";
  } finally {
    s += "f";
  }
  console.log(s);
}

function test_try_catch() {
  var s = "";
  try {
    s += "t";
    throw "c";
  } catch (e) {
    s += e;
  } finally {
    s += "f";
  }
  console.log(s);
}

// nested try/catch/finally
function test_nested_try() {
  var s = "";
  try {
    try {
      s += "t";
      throw "a";
    } catch (e) {
      s += e;
    } finally {
      s += "f";
    }
  } catch (e) {
    s += "X";
  } finally {
    s += "g";
  }
  console.log(s);
}

// try/catch/finally inside for-in
function test_try_for_in() {
  var s = "";
  for (var k in {x: 1, y: 2}) {
    try {
      s += k;
      throw "a";
    } catch (e) {
      s += e;
    } finally {
      s += "f";
    }
  }
  console.log(s);
}

test_switch();
test_switch_continue();
test_do_while();
test_for_in();
test_for_in_ctrl();
test_try();
test_try_catch();
test_nested_try();
test_try_for_in();
