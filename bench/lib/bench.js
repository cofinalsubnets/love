// node benchmark harness -- mirrors bench/bench.l.
// bench(name, work) auto-scales the repetition count (doubling until the run
// clears MIN_MS), then times that count ONCE MORE and reports the second run --
// the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
// growth), which otherwise ride on whichever power of two the doubling landed on.
// one line per bench, matching the other harnesses:
//     <name> <lang> <reps> <ms> <checksum>
// work is a nullary function returning a deterministic checksum. the same file
// serves node and deno; BENCH_LANG sets the label, default "node".
const MIN_MS = 200.0;
const LANG =
  (typeof process !== "undefined" && process.env && process.env.BENCH_LANG) ||
  (typeof Deno !== "undefined" && Deno.env.get("BENCH_LANG")) ||
  "node";

function run(work, reps) {
  const t0 = performance.now();
  let chk;
  for (let i = 0; i < reps; i++) chk = work();
  return [performance.now() - t0, chk];
}

function bench(name, work) {
  let reps = 1;
  for (;;) {
    let [ms, chk] = run(work, reps);
    if (ms >= MIN_MS) {
      [ms, chk] = run(work, reps);              // warm
      console.log(`${name} ${LANG} ${reps} ${ms.toFixed(3)} ${chk}`);
      break;
    }
    reps *= 2;
  }
}

module.exports = { bench };
