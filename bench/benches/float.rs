include!("../lib/bench.rs");

// mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
// IEEE-double arithmetic in the same order as the reference.
fn mand(cx: f64, cy: f64) -> i64 {
    let mut zx = 0.0f64;
    let mut zy = 0.0f64;
    let mut it = 0i64;
    while it < 100 && zx * zx + zy * zy <= 4.0 {
        let nzx = zx * zx - zy * zy + cx;
        let nzy = 2.0 * zx * zy + cy;
        zx = nzx;
        zy = nzy;
        it += 1;
    }
    it
}

fn main() {
    bench("float", || {
        let mut s: i64 = 0;
        for px in 0..64 {
            for py in 0..64 {
                s += mand(-2.0 + px as f64 * 0.046875, -1.5 + py as f64 * 0.046875);
            }
        }
        s
    });
}
