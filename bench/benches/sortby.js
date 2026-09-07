// sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
// checksum = rolling hash of the idx sequence.
const { bench } = require("../lib/bench");
const N = 5000;
function work() {
  let x = 1;
  const data = [];
  for (let i = 0; i < N; i++) { x = (16807 * x) % 2147483647; data.push([x, i]); }
  data.sort((a, b) => {
    const ma = a[0] % 4096, mb = b[0] % 4096;
    if (ma !== mb) return ma - mb;
    return a[0] - b[0];
  });
  let h = 0;
  for (const r of data) h = (h * 31 + r[1]) % 1000000007;
  return h;
}
bench("sortby", work);
