// rust benchmark harness -- mirrors bench/bench.l and lib/bench.py.
// bench(name, work) auto-scales the repetition count (doubling until the run
// clears MIN_MS), then times that count ONCE MORE and reports the second run --
// the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
// growth), which otherwise ride on whichever power of two the doubling landed on.
// one line per bench, matching the other harnesses:
//     <name> <lang> <reps> <ms> <checksum>
// `work` is a closure returning a deterministic i64 checksum. BENCH_LANG sets
// the column label, default "rust". This file is `include!`d by each bench, so
// it carries no `fn main`.
//
// Note on folding: rustc -O is LLVM, which constant-folds / scalar-evolves pure
// arithmetic loops to O(1) literals. Where a bench's workload would otherwise be
// closed-formed away, the bench wraps its inputs/accumulator with
// std::hint::black_box so the real O(n) loop must run.

const MIN_MS: f64 = 200.0;

#[allow(dead_code)]
fn bench<F: FnMut() -> i64>(name: &str, mut work: F) {
    fn run<F: FnMut() -> i64>(work: &mut F, reps: u64) -> (f64, i64) {
        let t0 = std::time::Instant::now();
        let mut chk: i64 = 0;
        for _ in 0..reps {
            chk = std::hint::black_box(work());
        }
        (t0.elapsed().as_secs_f64() * 1000.0, chk)
    }
    let lang = std::env::var("BENCH_LANG").unwrap_or_else(|_| "rust".to_string());
    let mut reps: u64 = 1;
    loop {
        let (ms, _) = run(&mut work, reps);
        if ms >= MIN_MS {
            let (ms, chk) = run(&mut work, reps);       // warm
            println!("{} {} {} {:.3} {}", name, lang, reps, ms, chk);
            break;
        }
        reps *= 2;
    }
}
