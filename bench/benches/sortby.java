import java.util.Arrays;
// sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
// checksum = rolling hash of the idx sequence.
class Main {
    static final int N = 5000;
    static long work() {
        long x = 1;
        long[][] data = new long[N][2];
        for (int i = 0; i < N; i++) {
            x = (16807 * x) % 2147483647;
            data[i][0] = x; data[i][1] = i;
        }
        Arrays.sort(data, (a, b) -> {
            long ma = a[0] % 4096, mb = b[0] % 4096;
            if (ma != mb) return Long.compare(ma, mb);
            return Long.compare(a[0], b[0]);
        });
        long h = 0;
        for (long[] r : data) h = (h * 31 + r[1]) % 1000000007;
        return h;
    }
    public static void main(String[] a) {
        Bench.bench("sortby", Main::work);
    }
}
