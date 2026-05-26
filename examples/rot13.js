// ROT13 cipher: rotate each letter by 13 positions in the alphabet.
// Since the alphabet has 26 letters, applying ROT13 twice returns the original text.

function rot13(str) {
  var result = "";
  for (var i = 0; i < str.length; i++) {
    var ch = str[i];
    var code = str.charCodeAt(i);
    if (code >= 65 && code <= 90) {
      result += String.fromCharCode(((code - 65 + 13) % 26) + 65);
    } else if (code >= 97 && code <= 122) {
      result += String.fromCharCode(((code - 97 + 13) % 26) + 97);
    } else {
      result += ch;
    }
  }
  return result;
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    console.log("FAIL: " + label);
    console.log("  expected: " + expected);
    console.log("  actual:   " + actual);
  } else {
    console.log("PASS: " + label);
  }
}

var inputs = [
  "Hello, World!",
  "The quick brown fox jumps over the lazy dog.",
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  "abcdefghijklmnopqrstuvwxyz",
  "Rotate by 13 places!"
];

for (var i = 0; i < inputs.length; i++) {
  var original = inputs[i];
  var encoded = rot13(original);
  var decoded = rot13(encoded);

  console.log("---");
  console.log("original: " + original);
  console.log("encoded:  " + encoded);
  console.log("decoded:  " + decoded);

  assertEqual(decoded, original, "roundtrip for: " + original);
}

console.log("---");
assertEqual(rot13("Uryyb, Jbeyq!"), "Hello, World!", "decode known ciphertext");
assertEqual(rot13(rot13("Test")), "Test", "double application is identity");
