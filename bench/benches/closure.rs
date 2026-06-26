include!("../lib/bench.rs");

use std::hint::black_box;

// closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
// twice(adder(i))(i) = i + i + i = 3i, summed over [0, N). APPLES-TO-APPLES with ai's
// always-on glaze (which closes this loop to 3*C(n,2) -- the loop-closer samples the
// closure-building body to 3i): only the INPUT n is opaque (black_box, so it can't fold
// to a compile-time literal / hang the rep-doubler), and LLVM is then FREE to scalar-
// evolve the Sigma 3i to its closed form just as ai does -- so both close it, an honest tie.
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
            s += twice(adder(i))(i);
        }
        s
    });
}
