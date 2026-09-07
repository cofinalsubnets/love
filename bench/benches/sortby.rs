include!("../lib/bench.rs");
// sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
// checksum = rolling hash of the idx sequence.
const N: usize = 5000;
fn main() {
    bench("sortby", || {
        let mut x: i64 = 1;
        let mut data: Vec<(i64, i64)> = Vec::with_capacity(N);
        for i in 0..N {
            x = (16807 * x) % 2147483647;
            data.push((x, i as i64));
        }
        data.sort_by(|a, b| (a.0 % 4096, a.0).cmp(&(b.0 % 4096, b.0)));
        let mut h: i64 = 0;
        for &(_, i) in &data {
            h = (h * 31 + i) % 1000000007;
        }
        h
    });
}
