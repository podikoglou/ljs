// Calculate areas of various shapes

const pi = 3.14159;

const circleArea = (r) => {
  return pi * r * r;
};

const rectangleArea = (w, h) => {
  return w * h;
};

const triangleArea = (base, height) => {
  return (base * height) / 2;
};

const shapes = [
  { name: "Circle (r=5)", area: circleArea(5) },
  { name: "Circle (r=10)", area: circleArea(10) },
  { name: "Rectangle (3x4)", area: rectangleArea(3, 4) },
  { name: "Triangle (6x3)", area: triangleArea(6, 3) },
];

console.log("=== Shape Areas ===");

for (const shape of shapes) {
  console.log(shape.name + " = " + shape.area);
}
