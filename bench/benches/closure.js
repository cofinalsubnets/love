// closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
const { bench } = require("../lib/bench");
const twice = (f) => (x) => f(f(x));
const adder = (i) => (x) => x + i;
const N = 100000;
function work() {
  let s = 0;
  for (let i = 0; i < N; i++) s += twice(adder(i))(i);
  return s;
}
bench("closure", work);
