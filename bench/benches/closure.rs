include!("../lib/bench.rs");
// closures escape into a Vec<Box<dyn Fn>>, applied through it (dynamic dispatch, non-inlinable). checksum = sum 3i.
fn adder(i: i64) -> impl Fn(i64) -> i64 {
    move |x| x + i
}
fn twice(f: impl Fn(i64) -> i64 + 'static) -> Box<dyn Fn(i64) -> i64> {
    Box::new(move |x| f(f(x)))
}
const N: i64 = 100000;
fn main() {
    bench("closure", || {
        let fns: Vec<Box<dyn Fn(i64) -> i64>> = (0..N).map(|i| twice(adder(i))).collect();
        let mut s: i64 = 0;
        for i in 0..N {
            s += fns[i as usize](i);
        }
        s
    });
}
