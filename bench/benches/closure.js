const { bench } = require("../lib/bench");
// closures escape into an array, then applied through it (non-inlinable). checksum = sum 3i.
const twice = (f) => (x) => f(f(x));
const adder = (i) => (x) => x + i;
const N = 100000;
function work() {
  const fns = new Array(N);
  for (let i = 0; i < N; i++) fns[i] = twice(adder(i));
  let s = 0;
  for (let i = 0; i < N; i++) s += fns[i](i);
  return s;
}
bench("closure", work);
