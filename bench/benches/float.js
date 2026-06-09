// mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
const { bench } = require("../lib/bench");
function mand(cx, cy) {
  let zx = 0.0, zy = 0.0, it = 0;
  while (it < 100 && zx * zx + zy * zy <= 4.0) {
    const nzx = zx * zx - zy * zy + cx;
    const nzy = 2.0 * zx * zy + cy;
    zx = nzx; zy = nzy; it++;
  }
  return it;
}
function work() {
  let s = 0;
  for (let px = 0; px < 64; px++)
    for (let py = 0; py < 64; py++)
      s += mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875);
  return s;
}
bench("float", work);
