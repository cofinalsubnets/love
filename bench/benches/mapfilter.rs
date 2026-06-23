include!("../lib/bench.rs");

use std::hint::black_box;

// square every element, keep the even squares, sum them. The data is a prebuilt
// vector (0..10000); its element values are opaque to LLVM via black_box so the
// pure pipeline cannot be scalar-evolved to a closed-form literal.
// checksum = 166616670000 (< 2^53).

fn main() {
    let data: Vec<i64> = (0..10000).collect();
    bench("mapfilter", || {
        data.iter()
            .map(|&x| black_box(x))
            .map(|x| x * x)
            .filter(|x| x % 2 == 0)
            .fold(0i64, |a, b| a + b)
    });
}
