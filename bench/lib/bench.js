// node benchmark harness -- mirrors bench/bench.g.
// bench(name, work) auto-scales the repetition count (doubling until the run
// clears MIN_MS), then prints one line matching the other harnesses:
//     <name> node <reps> <ms> <checksum>
// work is a nullary function returning a deterministic checksum.
const MIN_MS = 200.0;

function bench(name, work) {
  let reps = 1;
  for (;;) {
    const t0 = performance.now();
    let chk;
    for (let i = 0; i < reps; i++) chk = work();
    const ms = performance.now() - t0;
    if (ms >= MIN_MS) {
      console.log(`${name} node ${reps} ${ms.toFixed(3)} ${chk}`);
      break;
    }
    reps *= 2;
  }
}

module.exports = { bench };
