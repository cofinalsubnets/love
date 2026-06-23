include!("../lib/bench.rs");

use std::hint::black_box;

// closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
// twice(adder(i))(i) = i + i + i = 3i, summed over [0, N). LLVM would close-form
// the Sigma 3i to a literal, so each index read is funnelled through black_box to
// force the honest O(n) loop (mirrors the Julia bench iterating opaque data).
fn twice<F: Fn(i64) -> i64>(f: F) -> impl Fn(i64) -> i64 {
    move |x| f(f(x))
}

fn adder(i: i64) -> impl Fn(i64) -> i64 {
    move |x| x + i
}

const N: i64 = 100000;

fn main() {
    bench("closure", || {
        let mut s: i64 = 0;
        for i in 0..N {
            let i = black_box(i);
            s += twice(adder(i))(i);
        }
        black_box(s)
    });
}
