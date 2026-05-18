// Caesar cipher - shift letters by a fixed amount

const shift = 3;

const encode = (message) => {
  const result = "";
  // simplified: just demonstrate the structure
  return message;
};

const secret = "hello world";

console.log("Original: " + secret);
console.log("Shift:    " + shift);

const alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"];

const findIndex = (letter) => {
  let i = 0;
  for (const c of alphabet) {
    if (c === letter) {
      return i;
    }
    i = i + 1;
  }
  return -1;
};

console.log("H shifted by " + shift + " = " + alphabet[(findIndex("h") + shift) % 26]);
console.log("E shifted by " + shift + " = " + alphabet[(findIndex("e") + shift) % 26]);
console.log("L shifted by " + shift + " = " + alphabet[(findIndex("l") + shift) % 26]);
