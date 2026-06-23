include!("../lib/bench.rs");

use std::hint::black_box;

// sum of squares of the odd numbers in [0, N) -- a map/filter/fold pipeline.
// checksum = 1333333330000 (< 2^53). The iterator chain would otherwise be
// scalar-evolved to a closed form, so the source index is fed through black_box.
const N: i64 = 20000;

fn main() {
    bench("polysum", || {
        (0..N)
            .map(black_box)
            .filter(|x| x % 2 == 1)
            .map(|x| x * x)
            .fold(0i64, |a, b| a + b)
    });
}
