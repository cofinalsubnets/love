include!("../lib/bench.rs");

use std::hint::black_box;

// closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
// twice(adder(i))(i) = i + i + i = 3i, summed over [0, N). The intent is to measure the
// closure idiom as an actual O(n) loop -- the same thing every other language's cell runs
// (ai runs the real loop here, ~0.09 ms/it; its loop-closer does NOT close this one). So we
// must stop LLVM from scalar-evolving the Sigma 3i to its closed form, which would leave a
// ~3-instruction literal that measures nothing (a 0.000 ms/it cell). black_box(N) alone is
// not enough -- it only stops the WHOLE bench folding to a constant / the rep-doubler hanging;
// SCEV still recognises the series. So black_box EACH addend, the same defence Julia's bench
// gets from iterating an opaque prebuilt vector. The closures still inline to ~zero cost --
// an honest "these closures are free here" O(n) result.
fn twice<F: Fn(i64) -> i64>(f: F) -> impl Fn(i64) -> i64 {
    move |x| f(f(x))
}

fn adder(i: i64) -> impl Fn(i64) -> i64 {
    move |x| x + i
}

const N: i64 = 100000;

fn main() {
    bench("closure", || {
        let n = black_box(N);
        let mut s: i64 = 0;
        for i in 0..n {
            s += black_box(twice(adder(i))(i));
        }
        s
    });
}
