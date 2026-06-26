include!("../lib/bench.rs");

use std::hint::black_box;

// sum of squares of the odd numbers in [0, N) -- a map/filter/fold pipeline.
// checksum = 1333333330000 (< 2^53). APPLES-TO-APPLES with ai's loop-closer: only the
// INPUT n is opaque (black_box, so it can't fold to a compile-time literal / hang the
// rep-doubler), and LLVM is then FREE to close the loop. It CAN'T -- its scalar-evolution
// punts on the data-dependent odd filter, so this stays an honest O(n) run -- while ai's
// loop-closer changes variable (k=2j+1) and DOES close it to O(1). The gap is real, not a
// handicap: measured, un-hobbled rustc -O still scales linearly in n here.
const N: i64 = 20000;

fn main() {
    bench("polysum", || {
        let n = black_box(N);
        (0..n)
            .filter(|x| x % 2 == 1)
            .map(|x| x * x)
            .fold(0i64, |a, b| a + b)
    });
}
